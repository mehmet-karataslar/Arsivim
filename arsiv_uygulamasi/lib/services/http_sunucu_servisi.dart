import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';

class HttpSunucuServisi {
  static const int SUNUCU_PORTU = 8080;
  static const String UYGULAMA_KODU = 'arsivim';

  static HttpSunucuServisi? _instance;
  static HttpSunucuServisi get instance => _instance ??= HttpSunucuServisi._();
  HttpSunucuServisi._();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();

  HttpServer? _sunucu;
  String? _cihazId;
  String? _cihazAdi;
  String? _platform;
  bool _calisiyorMu = false;

  // Güvenlik için basit token sistemi
  final Map<String, DateTime> _aktifTokenlar = {};
  final Duration _tokenGecerlilikSuresi = const Duration(hours: 1);

  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) return;

    try {
      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();

      // Router oluştur
      final router = Router();

      // Ana info endpoint
      router.get('/info', _infoHandler);

      // Ping endpoint
      router.get('/ping', _pingHandler);

      // Bağlantı kurma endpoint'i
      router.post('/connect', _connectHandler);

      // Değişiklikler endpoint'i
      router.get('/changes', _changesHandler);

      // Dosya upload endpoint'i
      router.post('/upload', _uploadHandler);

      // Dosya download endpoint'i
      router.get('/download/<fileId>', _downloadHandler);

      // Sunucuyu başlat
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);
      print(
        '🚀 Arşivim HTTP Sunucusu başlatıldı: http://localhost:$SUNUCU_PORTU',
      );
      print('📱 Cihaz ID: $_cihazId');
      print('💻 Platform: $_platform');

      _calisiyorMu = true;

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          final headers = <String, String>{};
          request.headers.forEach((name, values) {
            headers[name] = values.join(',');
          });

          final response = await router.call(
            Request(
              request.method,
              request.uri,
              body: request,
              headers: headers,
            ),
          );

          request.response
            ..statusCode = response.statusCode
            ..headers.contentType = ContentType.json;

          final body = await response.readAsString();
          request.response.write(body);

          await request.response.close();
        } catch (e) {
          print('❌ İstek işleme hatası: $e');
          try {
            request.response
              ..statusCode = 500
              ..write(
                json.encode({
                  'error': 'Sunucu hatası',
                  'message': e.toString(),
                }),
              );
            await request.response.close();
          } catch (closeError) {
            print('❌ Response kapatma hatası: $closeError');
          }
        }
      });
    } catch (e) {
      print('❌ Sunucu başlatma hatası: $e');
      throw Exception('HTTP sunucusu başlatılamadı: $e');
    }
  }

  Future<void> sunucuyuDurdur() async {
    if (_sunucu != null) {
      await _sunucu!.close();
      _sunucu = null;
      _calisiyorMu = false;
      _aktifTokenlar.clear();
      print('🛑 Arşivim HTTP Sunucusu durduruldu');
    }
  }

  Future<void> _cihazBilgileriniAl() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cihazAdi = '${androidInfo.brand} ${androidInfo.model}';
        _platform = 'Android ${androidInfo.version.release}';
        _cihazId = androidInfo.id;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cihazAdi = windowsInfo.computerName;
        _platform = 'Windows';
        _cihazId = windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cihazAdi = linuxInfo.name;
        _platform = 'Linux';
        _cihazId =
            linuxInfo.machineId ??
            'linux-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cihazAdi = macInfo.computerName;
        _platform = 'macOS';
        _cihazId =
            macInfo.systemGUID ??
            'mac-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _cihazAdi = 'Bilinmeyen Cihaz';
        _platform = Platform.operatingSystem;
        _cihazId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Cihaz ID'sini hash'le (güvenlik için)
      final bytes = utf8.encode(_cihazId!);
      final digest = sha256.convert(bytes);
      _cihazId = digest.toString().substring(0, 16);
    } catch (e) {
      print('⚠️ Cihaz bilgisi alınamadı: $e');
      _cihazAdi = 'Arşivim Cihazı';
      _platform = Platform.operatingSystem;
      _cihazId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Ana bilgi endpoint'i
  Response _infoHandler(Request request) {
    final belgeSayisi = _veriTabani.toplamBelgeSayisi();
    final toplamBoyut = _veriTabani.toplamDosyaBoyutu();

    return Response.ok(
      json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'id': _cihazId,
        'ad': _cihazAdi,
        'platform': _platform,
        'belgeSayisi': belgeSayisi,
        'toplamBoyut': toplamBoyut,
        'zaman': DateTime.now().toIso8601String(),
        'aktif': true,
      }),
    );
  }

  // Ping endpoint'i
  Response _pingHandler(Request request) {
    return Response.ok(
      json.encode({
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
        'cihaz': _cihazId,
      }),
    );
  }

  // Bağlantı kurma endpoint'i
  Future<Response> _connectHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body);

      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String?;

      if (clientId == null || clientName == null) {
        return Response.badRequest(
          body: json.encode({'error': 'clientId ve clientName gerekli'}),
        );
      }

      // Token oluştur
      final token = _tokenOlustur(clientId);

      return Response.ok(
        json.encode({
          'success': true,
          'token': token,
          'serverId': _cihazId,
          'serverName': _cihazAdi,
          'message': 'Bağlantı kuruldu',
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'error': 'Bağlantı kurma hatası',
          'message': e.toString(),
        }),
      );
    }
  }

  // Değişiklikler endpoint'i
  Future<Response> _changesHandler(Request request) async {
    try {
      // Token kontrolü
      final token = request.headers['authorization']?.replaceFirst(
        'Bearer ',
        '',
      );
      if (!_tokenGecerliMi(token)) {
        return Response.forbidden(json.encode({'error': 'Geçersiz token'}));
      }

      // Son değişiklikleri al (örnek implementasyon)
      final changes = await _veriTabani.degismisHashleriGetir();

      return Response.ok(
        json.encode({
          'changes': changes,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'error': 'Değişiklikler alınamadı',
          'message': e.toString(),
        }),
      );
    }
  }

  // Dosya upload endpoint'i
  Future<Response> _uploadHandler(Request request) async {
    try {
      // Token kontrolü
      final token = request.headers['authorization']?.replaceFirst(
        'Bearer ',
        '',
      );
      if (!_tokenGecerliMi(token)) {
        return Response.forbidden(json.encode({'error': 'Geçersiz token'}));
      }

      // TODO: Multipart form data ile dosya upload implementasyonu
      return Response.ok(
        json.encode({
          'success': true,
          'message': 'Dosya upload özelliği yakında eklenecek',
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': 'Upload hatası', 'message': e.toString()}),
      );
    }
  }

  // Dosya download endpoint'i
  Future<Response> _downloadHandler(Request request, String fileId) async {
    try {
      // Token kontrolü
      final token = request.headers['authorization']?.replaceFirst(
        'Bearer ',
        '',
      );
      if (!_tokenGecerliMi(token)) {
        return Response.forbidden(json.encode({'error': 'Geçersiz token'}));
      }

      // TODO: Dosya download implementasyonu
      return Response.ok(
        json.encode({
          'success': true,
          'message': 'Dosya download özelliği yakında eklenecek',
          'fileId': fileId,
        }),
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'error': 'Download hatası',
          'message': e.toString(),
        }),
      );
    }
  }

  // Token oluşturma
  String _tokenOlustur(String clientId) {
    final now = DateTime.now();
    final tokenData = '$clientId:${_cihazId}:${now.millisecondsSinceEpoch}';
    final bytes = utf8.encode(tokenData);
    final digest = sha256.convert(bytes);
    final token = digest.toString();

    _aktifTokenlar[token] = now.add(_tokenGecerlilikSuresi);

    // Eski tokenları temizle
    _aktifTokenlar.removeWhere((token, expiry) => expiry.isBefore(now));

    return token;
  }

  // Token geçerlilik kontrolü
  bool _tokenGecerliMi(String? token) {
    if (token == null) return false;

    final expiry = _aktifTokenlar[token];
    if (expiry == null) return false;

    if (expiry.isBefore(DateTime.now())) {
      _aktifTokenlar.remove(token);
      return false;
    }

    return true;
  }

  void dispose() {
    sunucuyuDurdur();
  }
}
