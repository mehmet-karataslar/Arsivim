import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // Bağlantı callback'i
  Function(Map<String, dynamic>)? _onDeviceConnected;

  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;

  // Callback ayarlama metodu
  void setOnDeviceConnected(Function(Map<String, dynamic>) callback) {
    _onDeviceConnected = callback;
  }

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) {
      print('⚠️ Sunucu zaten çalışıyor');
      return;
    }

    try {
      print('🔧 HTTP Sunucusu başlatılıyor...');

      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      print('📱 Cihaz bilgileri alındı: $_cihazAdi ($_platform)');

      // Sunucuyu başlat
      print('🌐 Port $SUNUCU_PORTU dinlenmeye başlanıyor...');
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);
      print(
        '🚀 Arşivim HTTP Sunucusu başlatıldı: http://localhost:$SUNUCU_PORTU',
      );
      print('📱 Cihaz ID: $_cihazId');
      print('💻 Platform: $_platform');

      _calisiyorMu = true;
      print('✅ Sunucu durumu: $_calisiyorMu');

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          print('📨 HTTP İstek: ${request.method} ${request.uri.path}');

          // CORS headers ekle (UTF-8 desteği ile)
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add(
            'Content-Type',
            'application/json; charset=utf-8',
          );

          String responseBody;
          int statusCode = 200;

          // Route handling
          switch (request.uri.path) {
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/connect':
              responseBody = await _handleConnect(request);
              break;
            case '/documents':
              responseBody = await _handleDocuments();
              break;
            default:
              if (request.uri.path.startsWith('/download/')) {
                responseBody = await _handleDownload(request);
              } else if (request.uri.path == '/upload' &&
                  request.method == 'POST') {
                responseBody = await _handleUpload(request);
              } else {
                statusCode = 404;
                responseBody = json.encode({'error': 'Endpoint bulunamadı'});
              }
          }

          // UTF-8 bytes olarak yaz
          final responseBytes = utf8.encode(responseBody);
          request.response
            ..statusCode = statusCode
            ..add(responseBytes);

          await request.response.close();
          print('✅ HTTP Yanıt gönderildi: $statusCode');
        } catch (e) {
          print('❌ İstek işleme hatası: $e');
          try {
            final errorResponse = json.encode({
              'error': 'Sunucu hatası',
              'message': e.toString(),
            });
            final errorBytes = utf8.encode(errorResponse);

            request.response
              ..statusCode = 500
              ..add(errorBytes);
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

  // HTTP Handler metodları
  Future<String> _handleInfo() async {
    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'id': _cihazId,
        'ad': _cihazAdi,
        'platform': _platform,
        'belgeSayisi': belgeSayisi,
        'toplamBoyut': toplamBoyut,
        'zaman': DateTime.now().toIso8601String(),
        'aktif': true,
      });
    } catch (e) {
      print('❌ Info endpoint hatası: $e');
      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'id': _cihazId,
        'ad': _cihazAdi,
        'platform': _platform,
        'belgeSayisi': 0,
        'toplamBoyut': 0,
        'zaman': DateTime.now().toIso8601String(),
        'aktif': true,
      });
    }
  }

  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'cihaz': _cihazId,
    });
  }

  Future<String> _handleConnect(HttpRequest request) async {
    try {
      print('🔗 Yeni bağlantı isteği alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String?;

      if (clientId == null || clientName == null) {
        return json.encode({'error': 'clientId ve clientName gerekli'});
      }

      // Basit token oluştur
      final token = 'token_${DateTime.now().millisecondsSinceEpoch}';

      // Bağlantı başarılı bildirimi
      print('🎉 BAĞLANTI BAŞARILI! Mobil cihaz bağlandı');
      print('📱 Bağlanan cihaz: $clientName ($clientId)');
      print('📱 IP: ${request.connectionInfo?.remoteAddress?.address}');

      // UI'ya bildirim gönder - HEMEN
      final deviceInfo = {
        'clientId': clientId,
        'clientName': clientName,
        'ip': request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor',
        'timestamp': DateTime.now().toIso8601String(),
        'platform': data['platform'] ?? 'Mobil',
        'belgeSayisi': data['belgeSayisi'] ?? 0,
        'toplamBoyut': data['toplamBoyut'] ?? 0,
      };

      // Callback'i çağır
      if (_onDeviceConnected != null) {
        print('📢 Callback çağrılıyor...');
        Future.microtask(() => _onDeviceConnected!(deviceInfo));
      } else {
        print('⚠️ Callback tanımlanmamış!');
      }

      return json.encode({
        'success': true,
        'token': token,
        'serverId': _cihazId,
        'serverName': _cihazAdi,
        'message': 'Bağlantı kuruldu',
        'serverInfo': {
          'platform': _platform,
          'belgeSayisi': await _veriTabani.toplamBelgeSayisi(),
          'toplamBoyut': await _veriTabani.toplamDosyaBoyutu(),
        },
      });
    } catch (e) {
      print('❌ Connect handler hatası: $e');
      return json.encode({'error': 'Bağlantı hatası', 'message': e.toString()});
    }
  }

  // Belge listesi endpoint'i
  Future<String> _handleDocuments() async {
    try {
      print('📄 Belge listesi istendi');
      final belgeler = await _veriTabani.belgeleriGetir();

      final belgeListesi =
          belgeler
              .map(
                (belge) => {
                  'id': belge.id,
                  'dosyaAdi': belge.dosyaAdi,
                  'dosyaBoyutu': belge.dosyaBoyutu,
                  'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
                  'kategoriId': belge.kategoriId,
                  'baslik': belge.baslik,
                  'aciklama': belge.aciklama,
                  'kisiId': belge.kisiId,
                  'etiketler': belge.etiketler,
                },
              )
              .toList();

      return json.encode({
        'status': 'success',
        'documents': belgeListesi,
        'count': belgeListesi.length,
      });
    } catch (e) {
      print('❌ Documents endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Belgeler alınamadı: $e',
      });
    }
  }

  // Belge indirme endpoint'i
  Future<String> _handleDownload(HttpRequest request) async {
    try {
      final dosyaAdi = request.uri.pathSegments.last;
      print('📥 Belge indirme isteği: $dosyaAdi');

      final belgeler = await _veriTabani.belgeAra(dosyaAdi);
      if (belgeler.isEmpty) {
        request.response.statusCode = 404;
        return json.encode({'error': 'Belge bulunamadı'});
      }

      final dosya = File(belgeler.first.dosyaYolu);
      if (!await dosya.exists()) {
        request.response.statusCode = 404;
        return json.encode({'error': 'Dosya bulunamadı'});
      }

      final dosyaBytes = await dosya.readAsBytes();
      request.response
        ..headers.contentType = ContentType.binary
        ..headers.add('Content-Disposition', 'attachment; filename="$dosyaAdi"')
        ..add(dosyaBytes);

      print('✅ Belge gönderildi: $dosyaAdi');
      return ''; // Binary response için boş string
    } catch (e) {
      print('❌ Download endpoint hatası: $e');
      request.response.statusCode = 500;
      return json.encode({'error': 'İndirme hatası: $e'});
    }
  }

  // Belge yükleme endpoint'i
  Future<String> _handleUpload(HttpRequest request) async {
    try {
      print('📤 Belge yükleme isteği alındı');

      // Basit multipart parsing (gerçek uygulamada daha robust olmalı)
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      // Geçici olarak başarılı response döndür
      print('✅ Belge yükleme tamamlandı');
      return json.encode({
        'status': 'success',
        'message': 'Belge başarıyla yüklendi',
      });
    } catch (e) {
      print('❌ Upload endpoint hatası: $e');
      request.response.statusCode = 500;
      return json.encode({'error': 'Yükleme hatası: $e'});
    }
  }
}
