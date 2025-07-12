import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';

class HttpSunucuServisi {
  static const int SUNUCU_PORTU = 8080;
  static const String UYGULAMA_KODU = 'arsivim';

  // Timeout ayarları
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 30);
  static const Duration CONNECTION_TIMEOUT = Duration(minutes: 5);
  static const Duration KEEPALIVE_TIMEOUT = Duration(minutes: 2);

  // Dosya boyutu limitleri (güncellenmiş)
  static const int MAX_FILE_SIZE_MOBILE = 10 * 1024 * 1024; // 10MB
  static const int MAX_FILE_SIZE_DESKTOP = 50 * 1024 * 1024; // 50MB
  static const int MAX_PROFILE_PHOTO_SIZE = 5 * 1024 * 1024; // 5MB
  static const int BATCH_SIZE = 10; // Batch processing boyutu

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
  Timer? _cleanupTimer;

  // Manuel IP override özelliği
  String? _manuelIP;

  // Callback fonksiyonları
  Function(String)? onConnectionReceived;
  Function(String)? onDeviceConnected;
  Function(String, Map<String, dynamic>)? onDeviceDisconnected;
  Function(Map<String, dynamic>)? _onQRLoginRequest;

  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;
  String? get cihazAdi => _cihazAdi;
  String? get platform => _platform;
  int get port => SUNUCU_PORTU;

  // Manuel IP ayarlama
  void setManuelIP(String? ip) {
    _manuelIP = ip;
    print('🔧 Manuel IP ayarlandı: $ip');
  }

  String? get manuelIP => _manuelIP;

  // QR Login callback ayarlama
  void setOnQRLoginRequest(Function(Map<String, dynamic>) callback) {
    _onQRLoginRequest = callback;
    print('📱 QR Login callback ayarlandı');
  }

  // Baglanti callback'leri
  Function(Map<String, dynamic>)? _onDeviceConnected;
  Function(Map<String, dynamic>)? _onDeviceDisconnected;

  // Bagli cihazlar listesi
  final List<Map<String, dynamic>> _bagliCihazlar = [];

  List<Map<String, dynamic>> get bagliCihazlar =>
      List.unmodifiable(_bagliCihazlar);

  // Callback'leri ayarla
  void baglantiCallbackleri({
    Function(Map<String, dynamic>)? onDeviceConnected,
    Function(String, Map<String, dynamic>)? onDeviceDisconnected,
  }) {
    _onDeviceConnected = onDeviceConnected;
    // Disconnection callback'ini wrap ediyoruz
    if (onDeviceDisconnected != null) {
      _onDeviceDisconnected = (deviceInfo) {
        final deviceId = deviceInfo['device_id'] as String? ?? 'unknown';
        onDeviceDisconnected(deviceId, deviceInfo);
      };
    }
    print('📡 HTTP sunucu callback\'leri ayarlandı');
  }

  // Callback ayarlama metodlari
  void setOnDeviceConnected(Function(Map<String, dynamic>) callback) {
    _onDeviceConnected = callback;
  }

  void setOnDeviceDisconnected(Function(Map<String, dynamic>) callback) {
    _onDeviceDisconnected = callback;
  }

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) {
      print('⚠️ Sunucu zaten çalışıyor');
      return;
    }

    try {
      print('🚀 HTTP Sunucusu başlatılıyor...');

      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      print('✅ Cihaz bilgileri alındı: $_cihazAdi ($_platform)');

      // Sunucuyu başlat
      print('🔌 Port $SUNUCU_PORTU dinlenmeye başlanıyor...');
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);

      // Sunucu timeout ayarları
      _sunucu!.idleTimeout = KEEPALIVE_TIMEOUT;

      print(
        '✅ Arsivim HTTP Sunucusu başlatıldı: http://localhost:$SUNUCU_PORTU',
      );

      // IP adresi alındı
      final realIP = await getRealIPAddress();
      print('🌐 Gerçek IP adresi: $realIP');

      print('🆔 Cihaz ID: $_cihazId');
      print('💻 Platform: $_platform');

      _calisiyorMu = true;
      print('✅ Sunucu durumu: $_calisiyorMu');

      // Cleanup timer başlat
      _startCleanupTimer();

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          print('📨 HTTP İstek: ${request.method} ${request.uri.path}');

          // Request timeout kontrolü (HttpServer kendi timeout yönetimi yapıyor)

          // CORS headers ekle
          _addCORSHeaders(request.response);

          // OPTIONS request için CORS preflight
          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
            await request.response.close();
            return;
          }

          String responseBody;
          int statusCode = 200;

          // Route handling - Tüm endpoint'ler eklendi
          switch (request.uri.path) {
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/connect':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleConnect,
              );
              break;
            case '/disconnect':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDisconnect,
              );
              break;
            case '/status':
              responseBody = await _handleStatus();
              break;
            case '/devices':
              responseBody = await _handleDevices();
              break;
            case '/device-connected':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDeviceConnected,
              );
              break;
            case '/device-disconnected':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDeviceDisconnected,
              );
              break;
            // Senkronizasyon endpoint'leri
            case '/sync/belgeler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncBelgeler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveBelgeler(request);
              } else {
                statusCode = 405;
                responseBody = _createErrorResponse(
                  'Method not allowed',
                  'Only GET and POST methods are supported',
                );
              }
              break;
            case '/sync/belgeler-kapsamli':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleReceiveBelgelerKapsamli,
              );
              break;
            case '/sync/kisiler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncKisiler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveKisiler(request);
              } else {
                statusCode = 405;
                responseBody = _createErrorResponse(
                  'Method not allowed',
                  'Only GET and POST methods are supported',
                );
              }
              break;
            case '/sync/receive_kisiler':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleReceiveKisiler,
              );
              break;
            case '/sync/kategoriler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncKategoriler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveKategoriler(request);
              } else {
                statusCode = 405;
                responseBody = _createErrorResponse(
                  'Method not allowed',
                  'Only GET and POST methods are supported',
                );
              }
              break;
            case '/sync/receive_kategoriler':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleReceiveKategoriler,
              );
              break;
            case '/sync/bekleyen':
              responseBody = await _handleBekleyenSenkronlar();
              break;
            case '/sync/status':
              responseBody = await _handleSyncStatus();
              break;
            case '/auth/qr-login':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleQRLogin,
              );
              break;
            default:
              statusCode = 404;
              responseBody = _createErrorResponse(
                'Endpoint bulunamadı',
                'Belirtilen endpoint mevcut değil: ${request.uri.path}',
              );
          }

          // Response gönder
          await _sendResponse(request.response, responseBody, statusCode);
          print('✅ HTTP Yanıt gönderildi: $statusCode');
        } catch (e, stackTrace) {
          print('❌ İstek işleme hatası: $e');
          print('📍 Stack trace: $stackTrace');
          await _sendErrorResponse(
            request.response,
            'Sunucu hatası',
            e.toString(),
          );
        }
      });
    } catch (e, stackTrace) {
      print('❌ Sunucu başlatma hatası: $e');
      print('📍 Stack trace: $stackTrace');
      throw Exception('HTTP sunucusu başlatılamadı: $e');
    }
  }

  Future<void> sunucuyuDurdur() async {
    try {
      print('🛑 HTTP Sunucusu durduruluyor...');

      // Cleanup timer'ı durdur
      _cleanupTimer?.cancel();
      _cleanupTimer = null;

      // Sunucuyu durdur
      final sunucu = _sunucu;
      if (sunucu != null) {
        await sunucu.close(force: true);
        _sunucu = null;
      }

      _calisiyorMu = false;
      _bagliCihazlar.clear();

      print('✅ Arsivim HTTP Sunucusu durduruldu');
    } catch (e) {
      print('❌ Sunucu durdurma hatası: $e');
    }
  }

  // Cleanup timer başlat
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _cleanupConnections();
    });
  }

  // Bağlantı temizleme
  void _cleanupConnections() {
    try {
      final now = DateTime.now();
      final removedDevices = <Map<String, dynamic>>[];

      _bagliCihazlar.removeWhere((device) {
        final lastSeenStr = device['last_seen'] as String?;
        if (lastSeenStr == null) return true;

        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) return true;

        final isTimedOut = now.difference(lastSeen) > CONNECTION_TIMEOUT;
        if (isTimedOut) {
          removedDevices.add(device);
        }
        return isTimedOut;
      });

      // Timeout olan cihazlar için bildirim gönder
      for (final device in removedDevices) {
        print('⏰ Cihaz timeout nedeniyle kaldırıldı: ${device['device_name']}');
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': device['device_id'],
            'device_name': device['device_name'],
            'reason': 'Connection timeout',
            'timestamp': DateTime.now().toIso8601String(),
          };
          _onDeviceDisconnected!(disconnectionInfo);
        }
      }
    } catch (e) {
      print('❌ Cleanup hatası: $e');
    }
  }

  // CORS headers ekle
  void _addCORSHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
    response.headers.add('Content-Type', 'application/json; charset=utf-8');
  }

  // HTTP method validasyonu
  Future<String> _handleMethodValidation(
    HttpRequest request,
    String allowedMethod,
    Function(HttpRequest) handler,
  ) async {
    if (request.method != allowedMethod) {
      return _createErrorResponse(
        'Method not allowed',
        'Only $allowedMethod method is supported for this endpoint',
      );
    }
    return await handler(request);
  }

  // Error response oluştur
  String _createErrorResponse(String error, String message) {
    return json.encode({
      'success': false,
      'error': error,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Response gönder
  Future<void> _sendResponse(
    HttpResponse response,
    String body,
    int statusCode,
  ) async {
    try {
      final responseBytes = utf8.encode(body);
      response
        ..statusCode = statusCode
        ..add(responseBytes);
      await response.close();
    } catch (e) {
      print('❌ Response gönderme hatası: $e');
    }
  }

  // Error response gönder
  Future<void> _sendErrorResponse(
    HttpResponse response,
    String error,
    String message,
  ) async {
    try {
      final errorResponse = _createErrorResponse(error, message);
      await _sendResponse(response, errorResponse, 500);
    } catch (e) {
      print('❌ Error response gönderme hatası: $e');
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
      final cihazId = _cihazId ?? 'unknown-device';
      final bytes = utf8.encode(cihazId);
      final digest = sha256.convert(bytes);
      _cihazId = digest.toString().substring(0, 16);
    } catch (e) {
      print('❌ Cihaz bilgisi alınamadı: $e');
      _cihazAdi = 'Arsivim Cihazı';
      _platform = Platform.operatingSystem;
      _cihazId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // HTTP Handler metodları
  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _cihazId,
      'device_name': _cihazAdi,
      'platform': _platform,
      'server_version': '2.0.0',
    });
  }

  Future<String> _handleInfo() async {
    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();
      final serverIP = await getRealIPAddress();

      return json.encode({
        'success': true,
        'app': UYGULAMA_KODU,
        'version': '2.0.0',
        'device_id': _cihazId,
        'device_name': _cihazAdi,
        'platform': _platform,
        'document_count': belgeSayisi,
        'total_size': toplamBoyut,
        'server_ip': serverIP,
        'server_port': SUNUCU_PORTU,
        'timestamp': DateTime.now().toIso8601String(),
        'server_running': true,
        'connected_devices': _bagliCihazlar.length,
        'max_file_size': _getMaxFileSize(),
      });
    } catch (e) {
      print('❌ Info endpoint hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Info alınamadı',
        'message': e.toString(),
        'app': UYGULAMA_KODU,
        'version': '2.0.0',
        'device_id': _cihazId,
        'device_name': _cihazAdi,
        'platform': _platform,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Maksimum dosya boyutunu platform'a göre döndür
  int _getMaxFileSize() {
    return Platform.isAndroid || Platform.isIOS
        ? MAX_FILE_SIZE_MOBILE
        : MAX_FILE_SIZE_DESKTOP;
  }

  // Connection handler methods
  Future<String> _handleConnect(HttpRequest request) async {
    try {
      print('🔗 Bağlantı isteği alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final platform = data['platform'] as String?;
      final clientIP =
          request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor';

      if (deviceId == null || deviceName == null) {
        return _createErrorResponse(
          'Missing parameters',
          'device_id ve device_name gerekli',
        );
      }

      // Cihaz zaten bağlı mı kontrol et
      final mevcutCihazIndex = _bagliCihazlar.indexWhere(
        (device) => device['device_id'] == deviceId,
      );

      if (mevcutCihazIndex != -1) {
        // Mevcut cihazın bilgilerini güncelle
        _bagliCihazlar[mevcutCihazIndex].addAll({
          'last_seen': DateTime.now().toIso8601String(),
          'status': 'connected',
          'online': true,
          'ip': clientIP,
          'platform': platform ?? _bagliCihazlar[mevcutCihazIndex]['platform'],
        });
        print('🔄 Mevcut cihaz bilgileri güncellendi: $deviceName ($deviceId)');

        // Güncelleme için UI bildirimini gönder
        if (_onDeviceConnected != null) {
          print('🔄 UI\'ya cihaz güncelleme bildirimi gönderiliyor...');
          Future.microtask(
            () => _onDeviceConnected!(_bagliCihazlar[mevcutCihazIndex]),
          );
        }
      } else {
        // Yeni cihaz ekle
        final yeniCihaz = {
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platform ?? 'Unknown',
          'ip': clientIP,
          'connected_at': DateTime.now().toIso8601String(),
          'last_seen': DateTime.now().toIso8601String(),
          'status': 'connected',
          'connection_type': 'incoming',
          'online': true,
        };

        _bagliCihazlar.add(yeniCihaz);
        print('➕ Yeni cihaz eklendi: $deviceName ($deviceId)');

        // UI'ya bildirim gönder
        if (_onDeviceConnected != null) {
          print('📱 UI\'ya yeni cihaz bağlantı bildirimi gönderiliyor...');
          Future.microtask(() => _onDeviceConnected!(yeniCihaz));
        }
      }

      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'success': true,
        'message': 'Bağlantı kuruldu',
        'server_device_id': _cihazId,
        'server_device_name': _cihazAdi,
        'server_ip': serverIP,
        'server_port': SUNUCU_PORTU,
        'server_info': {
          'platform': _platform,
          'document_count': belgeSayisi,
          'total_size': toplamBoyut,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Connect handler hatası: $e');
      return _createErrorResponse('Bağlantı hatası', e.toString());
    }
  }

  Future<String> _handleDisconnect(HttpRequest request) async {
    try {
      print('🔌 Bağlantı kesme isteği alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final reason = data['reason'] as String?;

      if (deviceId == null) {
        return _createErrorResponse('Missing parameter', 'device_id gerekli');
      }

      // Cihazı listeden kaldır
      final removedDevice = _bagliCihazlar.firstWhere(
        (device) => device['device_id'] == deviceId,
        orElse: () => <String, dynamic>{},
      );

      if (removedDevice.isNotEmpty) {
        _bagliCihazlar.removeWhere((device) => device['device_id'] == deviceId);
        print(
          '🔌 Cihaz bağlantısı kesildi: ${removedDevice['device_name']} ($deviceId)',
        );
        print('📝 Sebep: ${reason ?? 'Belirtilmedi'}');

        // UI'ya bildirim gönder
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': deviceId,
            'device_name': removedDevice['device_name'],
            'reason': reason ?? 'Bağlantı kesildi',
            'timestamp': DateTime.now().toIso8601String(),
          };
          print('📢 UI\'ya bağlantı kesme bildirimi gönderiliyor...');
          Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
        }

        return json.encode({
          'success': true,
          'message': 'Bağlantı kesildi',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        return _createErrorResponse(
          'Device not found',
          'Belirtilen cihaz bağlı cihazlar listesinde yok',
        );
      }
    } catch (e) {
      print('❌ Disconnect handler hatası: $e');
      return _createErrorResponse('Bağlantı kesme hatası', e.toString());
    }
  }

  Future<String> _handleStatus() async {
    try {
      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'success': true,
        'status': 'running',
        'server_info': {
          'device_id': _cihazId,
          'device_name': _cihazAdi,
          'platform': _platform,
          'ip': serverIP,
          'port': SUNUCU_PORTU,
          'document_count': belgeSayisi,
          'total_size': toplamBoyut,
        },
        'connected_devices': _bagliCihazlar.length,
        'uptime': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Status handler hatası: $e');
      return _createErrorResponse('Status alınamadı', e.toString());
    }
  }

  Future<String> _handleDevices() async {
    try {
      // Bağlı cihazların son görülme zamanlarını kontrol et (cleanup timer zaten yapıyor ama extra kontrol)
      final now = DateTime.now();
      final removedDevices = <Map<String, dynamic>>[];

      _bagliCihazlar.removeWhere((device) {
        final lastSeenStr = device['last_seen'] as String?;
        if (lastSeenStr == null) return true;

        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) return true;

        final isTimedOut = now.difference(lastSeen) > CONNECTION_TIMEOUT;
        if (isTimedOut) {
          removedDevices.add(device);
        }
        return isTimedOut;
      });

      // Timeout olan cihazlar için bildirim gönder
      for (final device in removedDevices) {
        print('⏰ Cihaz timeout nedeniyle kaldırıldı: ${device['device_name']}');
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': device['device_id'],
            'device_name': device['device_name'],
            'reason': 'Connection timeout',
            'timestamp': DateTime.now().toIso8601String(),
          };
          Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
        }
      }

      return json.encode({
        'success': true,
        'devices': _bagliCihazlar,
        'total_count': _bagliCihazlar.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Devices handler hatası: $e');
      return _createErrorResponse('Cihaz listesi alınamadı', e.toString());
    }
  }

  Future<String> _handleDeviceConnected(HttpRequest request) async {
    try {
      print('📱 Cihaz bağlantı bildirimi alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final platform = data['platform'] as String?;
      final clientIP =
          request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor';

      if (deviceId == null || deviceName == null) {
        return _createErrorResponse(
          'Missing parameters',
          'device_id ve device_name gerekli',
        );
      }

      print('🆕 YENİ CİHAZ BAĞLANDI!');
      print('📱 Cihaz: $deviceName ($deviceId)');
      print('💻 Platform: $platform');
      print('🌐 IP: $clientIP');

      // UI'ya bildirim gönder
      final deviceInfo = {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform ?? 'Unknown',
        'ip': clientIP,
        'timestamp': DateTime.now().toIso8601String(),
        'connection_type': 'incoming',
      };

      // Callback'i çağır
      if (_onDeviceConnected != null) {
        print('📢 UI\'ya bağlantı bildirimi gönderiliyor...');
        Future.microtask(() => _onDeviceConnected!(deviceInfo));
      } else {
        print('⚠️ Device connected callback tanımlanmamış!');
      }

      return json.encode({
        'success': true,
        'message': 'Bağlantı bildirimi alındı',
        'server_device_id': _cihazId,
        'server_device_name': _cihazAdi,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Device connected handler hatası: $e');
      return _createErrorResponse('Bağlantı bildirimi hatası', e.toString());
    }
  }

  Future<String> _handleDeviceDisconnected(HttpRequest request) async {
    try {
      print('📱 Cihaz bağlantı kesme bildirimi alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final message = data['message'] as String?;

      if (deviceId == null) {
        return _createErrorResponse('Missing parameter', 'device_id gerekli');
      }

      print('🔌 Cihaz bağlantısı kesildi: $deviceId');
      print('📝 Mesaj: $message');

      // UI'ya bildirim gönder
      final disconnectionInfo = {
        'device_id': deviceId,
        'message': message ?? 'Bağlantı kesildi',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Callback'i çağır
      if (_onDeviceDisconnected != null) {
        print('📢 UI\'ya bağlantı kesme bildirimi gönderiliyor...');
        Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
      } else {
        print('⚠️ Device disconnected callback tanımlanmamış!');
      }

      return json.encode({
        'success': true,
        'message': 'Bağlantı kesme bildirimi alındı',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Device disconnected handler hatası: $e');
      return _createErrorResponse(
        'Bağlantı kesme bildirimi hatası',
        e.toString(),
      );
    }
  }

  // IP adresini gerçek zamanlı al
  Future<String?> getRealIPAddress() async {
    try {
      print('🔍 Network interface\'leri taranıyor...');
      final interfaces = await NetworkInterface.list();

      String? bestIP;
      int bestPriority = 0;

      for (final interface in interfaces) {
        print(
          '🔗 Interface: ${interface.name}, addresses: ${interface.addresses.length}',
        );

        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            print('📍 Address: ${addr.address}, Interface: ${interface.name}');

            int priority = 0;
            final interfaceName = interface.name.toLowerCase();

            // Virtual interface'leri atla
            if (interfaceName.contains('virtual') ||
                interfaceName.contains('vmware') ||
                interfaceName.contains('vbox') ||
                interfaceName.contains('virtualbox') ||
                interfaceName.contains('docker') ||
                interfaceName.contains('hyper-v')) {
              print('⚠️ Virtual interface atlandı: ${interface.name}');
              continue;
            }

            // Wi-Fi interface'leri en yüksek öncelik
            if (interfaceName.contains('wi-fi') ||
                interfaceName.contains('wlan') ||
                interfaceName.contains('wireless')) {
              priority = 100;
            }
            // Ethernet ikinci öncelik
            else if (interfaceName.contains('ethernet') ||
                interfaceName.contains('eth')) {
              priority = 80;
            }
            // Diğer interface'ler
            else {
              priority = 50;
            }

            // 192.168.x.x ağları extra puan (ev/ofis ağları)
            if (addr.address.startsWith('192.168.')) {
              priority += 30;
            }
            // 10.x.x.x ağları da geçerli ama daha az puan
            else if (addr.address.startsWith('10.')) {
              priority += 20;
            }
            // 172.16-31.x.x ağları
            else if (addr.address.startsWith('172.')) {
              final parts = addr.address.split('.');
              if (parts.length >= 2) {
                final second = int.tryParse(parts[1]);
                if (second != null && second >= 16 && second <= 31) {
                  priority += 15;
                }
              }
            }

            if (priority > bestPriority) {
              bestPriority = priority;
              bestIP = addr.address;
              print(
                '✅ Yeni en iyi IP: ${addr.address} (Öncelik: $priority, Interface: ${interface.name})',
              );
            }
          }
        }
      }

      if (bestIP != null) {
        print('🌐 En iyi IP seçildi: $bestIP (Öncelik: $bestPriority)');
        return bestIP;
      }

      print('❌ Uygun IP adresi bulunamadı');
    } catch (e) {
      print('❌ IP adresi alınamadı: $e');
    }

    return null;
  }

  // Utility metodları
  void clearConnectedDevices() {
    _bagliCihazlar.clear();
    print('🧹 Bağlı cihazlar listesi temizlendi');
  }

  void updateDeviceLastSeen(String deviceId) {
    final device = _bagliCihazlar.firstWhere(
      (device) => device['device_id'] == deviceId,
      orElse: () => <String, dynamic>{},
    );

    if (device.isNotEmpty) {
      device['last_seen'] = DateTime.now().toIso8601String();
      print('⏰ Cihaz son görülme zamanı güncellendi: $deviceId');
    }
  }

  // Senkronizasyon Handler Metodları

  /// Bekleyen senkronizasyon belgelerini döndür (GET)
  Future<String> _handleSyncBelgeler() async {
    try {
      print('📄 Senkronizasyon bekleyen belgeler istendi');

      final belgeler = await _veriTabani.belgeleriGetir(limit: 50);
      final bekleyenBelgeler =
          belgeler
              .where(
                (belge) =>
                    belge.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                    belge.senkronDurumu == SenkronDurumu.YEREL_DEGISIM,
              )
              .toList();

      print('📊 ${bekleyenBelgeler.length} bekleyen belge bulundu');

      final belgelerJson = <Map<String, dynamic>>[];

      // Batch processing ile belgeleri hazırla
      for (int i = 0; i < bekleyenBelgeler.length; i += BATCH_SIZE) {
        final batch = bekleyenBelgeler.skip(i).take(BATCH_SIZE).toList();

        for (final belge in batch) {
          final belgeMap = belge.toMap();

          // Dosya boyutu kontrolü ve dosya okuma
          try {
            final dosyaFile = File(belge.dosyaYolu);
            if (await dosyaFile.exists()) {
              final dosyaBytes = await dosyaFile.readAsBytes();
              final maxFileSize = _getMaxFileSize();

              if (dosyaBytes.length > maxFileSize) {
                print(
                  '⚠️ Büyük dosya atlanıyor: ${belge.dosyaAdi} (${dosyaBytes.length} bytes, limit: $maxFileSize)',
                );
                belgeMap['dosya_icerigi'] = null;
                belgeMap['buyuk_dosya'] = true;
                belgeMap['dosya_boyutu'] = dosyaBytes.length;
                belgeMap['dosya_hash_kontrol'] = belge.dosyaHash;
              } else if (dosyaBytes.isNotEmpty) {
                belgeMap['dosya_icerigi'] = base64Encode(dosyaBytes);
                belgeMap['buyuk_dosya'] = false;
                belgeMap['dosya_boyutu'] = dosyaBytes.length;
                belgeMap['dosya_hash_kontrol'] = belge.dosyaHash;
                print(
                  '📄 Belge hazırlandı: ${belge.dosyaAdi} (${dosyaBytes.length} bytes)',
                );
              } else {
                print('⚠️ Dosya boş: ${belge.dosyaAdi}');
                belgeMap['dosya_icerigi'] = null;
                belgeMap['buyuk_dosya'] = false;
                belgeMap['dosya_boyutu'] = 0;
              }
            } else {
              print('❌ Dosya mevcut değil: ${belge.dosyaYolu}');
              belgeMap['dosya_icerigi'] = null;
              belgeMap['buyuk_dosya'] = false;
              belgeMap['dosya_boyutu'] = 0;
              belgeMap['dosya_mevcut_degil'] = true;
            }
          } catch (e) {
            print('❌ Dosya okuma hatası: ${belge.dosyaAdi} - $e');
            belgeMap['dosya_icerigi'] = null;
            belgeMap['buyuk_dosya'] = false;
            belgeMap['dosya_boyutu'] = 0;
            belgeMap['dosya_okuma_hatasi'] = e.toString();
          }

          belgelerJson.add(belgeMap);
        }

        // Batch aralarında kısa bekleme
        await Future.delayed(Duration.zero);
      }

      return json.encode({
        'success': true,
        'belgeler': belgelerJson,
        'toplam': bekleyenBelgeler.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Belge senkronizasyonu hatası: $e');
      return _createErrorResponse('Belgeler alınamadı', e.toString());
    }
  }

  /// Gelen belgeleri al ve kaydet (POST)
  Future<String> _handleReceiveBelgeler(HttpRequest request) async {
    try {
      print('📥 Belge senkronizasyonu alınıyor');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final belgelerData = data['belgeler'] as List<dynamic>;
      int basariliSayisi = 0;
      int hataliSayisi = 0;

      // Batch processing ile belgeleri kaydet
      for (int i = 0; i < belgelerData.length; i += BATCH_SIZE) {
        final batch = belgelerData.skip(i).take(BATCH_SIZE).toList();

        for (final belgeData in batch) {
          try {
            // Belge modelini oluştur
            final belge = BelgeModeli.fromMap(belgeData);

            // Belge zaten mevcut mu kontrol et
            final mevcutBelge = await _veriTabani.belgeBulHash(belge.dosyaHash);
            if (mevcutBelge != null) {
              print('⏭️ Belge zaten mevcut: ${belge.dosyaAdi}');
              continue;
            }

            // Dosya içeriğini kaydet
            if (belgeData['dosya_icerigi'] != null &&
                belgeData['dosya_icerigi'].toString().isNotEmpty) {
              try {
                final dosyaBytes = base64Decode(belgeData['dosya_icerigi']);

                if (dosyaBytes.isNotEmpty) {
                  // Hash doğrulaması
                  final hesaplananHash = sha256.convert(dosyaBytes).toString();
                  final beklenenHash =
                      belgeData['dosya_hash_kontrol'] ?? belge.dosyaHash;

                  if (hesaplananHash != beklenenHash) {
                    print(
                      '❌ Hash uyumsuzluğu: ${belge.dosyaAdi} (beklenen: $beklenenHash, hesaplanan: $hesaplananHash)',
                    );
                    hataliSayisi++;
                    continue;
                  }

                  final dosyaYolu = await _dosyaServisi.senkronDosyasiKaydet(
                    belge.dosyaAdi,
                    dosyaBytes,
                  );

                  // Dosya yolunu güncelle
                  final yeniBelge = belge.copyWith(
                    dosyaYolu: dosyaYolu,
                    senkronDurumu: SenkronDurumu.SENKRONIZE,
                  );

                  // Veritabanına kaydet
                  await _veriTabani.belgeEkle(yeniBelge);
                  basariliSayisi++;
                  print(
                    '✅ Belge kaydedildi: ${belge.dosyaAdi} (${dosyaBytes.length} bytes)',
                  );
                } else {
                  print('⚠️ Belge içeriği boş: ${belge.dosyaAdi}');
                  hataliSayisi++;
                }
              } catch (e) {
                print('❌ Belge decode/kaydetme hatası: ${belge.dosyaAdi} - $e');
                hataliSayisi++;
              }
            } else if (belgeData['buyuk_dosya'] == true) {
              print('📋 Büyük dosya metadata kaydediliyor: ${belge.dosyaAdi}');
              // Büyük dosyalar için sadece metadata kaydet
              final metadataBelge = belge.copyWith(
                dosyaYolu: '', // Boş dosya yolu
                senkronDurumu:
                    SenkronDurumu.BEKLEMEDE, // Dosya içeriği beklemede
              );
              await _veriTabani.belgeEkle(metadataBelge);
              basariliSayisi++;
            } else {
              print('⚠️ Belge içeriği bulunamadı: ${belge.dosyaAdi}');
              hataliSayisi++;
            }
          } catch (e) {
            print('❌ Belge işleme hatası: $e');
            hataliSayisi++;
          }
        }

        // Batch aralarında kısa bekleme
        await Future.delayed(Duration.zero);
      }

      return json.encode({
        'success': true,
        'message': 'Belge senkronizasyonu tamamlandı',
        'basarili': basariliSayisi,
        'hatali': hataliSayisi,
        'toplam': belgelerData.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Belge alma hatası: $e');
      return _createErrorResponse('Belgeler kaydedilemedi', e.toString());
    }
  }

  /// Kapsamlı belge senkronizasyonu (Dependency-Aware)
  Future<String> _handleReceiveBelgelerKapsamli(HttpRequest request) async {
    try {
      print('📥 Kapsamlı belge senkronizasyonu alınıyor');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final belgelerData = data['belgeler'] as List<dynamic>;
      final kisilerData = data['kisiler'] as List<dynamic>;
      final kategorilerData = data['kategoriler'] as List<dynamic>;

      int belgelerEklendi = 0;
      int kisilerEklendi = 0;
      int kategorilerEklendi = 0;
      int hatalar = 0;

      // Batch processing ile sıralı işlem
      try {
        // 1. Önce kategorileri ekle
        for (int i = 0; i < kategorilerData.length; i += BATCH_SIZE) {
          final batch = kategorilerData.skip(i).take(BATCH_SIZE).toList();

          for (final kategoriData in batch) {
            try {
              final kategori = KategoriModeli.fromMap(kategoriData);

              // Kategori zaten var mı kontrol et
              final mevcutKategori = await _veriTabani.kategoriBulAd(
                kategori.ad,
              );
              if (mevcutKategori == null) {
                // Kategori ID'sini korumak için özel ekleme
                final eskiTarihliKategori = kategori.copyWith(
                  olusturmaTarihi: DateTime.now().subtract(
                    const Duration(days: 2),
                  ),
                );
                await _veriTabani.kategoriEkleIdIle(eskiTarihliKategori);
                kategorilerEklendi++;
                print('✅ Kategori eklendi: ${kategori.ad}');
              } else {
                print('⏭️ Kategori zaten mevcut: ${kategori.ad}');
              }
            } catch (e) {
              print('❌ Kategori ekleme hatası: $e');
              hatalar++;
            }
          }
          await Future.delayed(Duration.zero);
        }

        // 2. Sonra kişileri ekle
        for (int i = 0; i < kisilerData.length; i += BATCH_SIZE) {
          final batch = kisilerData.skip(i).take(BATCH_SIZE).toList();

          for (final kisiData in batch) {
            try {
              final kisi = KisiModeli.fromMap(kisiData);

              // Kişi zaten var mı kontrol et
              final mevcutKisi = await _veriTabani.kisiBulAdSoyad(
                kisi.ad,
                kisi.soyad,
              );
              if (mevcutKisi == null) {
                // Kişi ID'sini korumak için özel ekleme
                final eskiTarihliKisi = kisi.copyWith(
                  olusturmaTarihi: DateTime.now().subtract(
                    const Duration(days: 2),
                  ),
                );
                await _veriTabani.kisiEkleIdIle(eskiTarihliKisi);
                kisilerEklendi++;
                print('✅ Kişi eklendi: ${kisi.ad} ${kisi.soyad}');
              } else {
                print('⏭️ Kişi zaten mevcut: ${kisi.ad} ${kisi.soyad}');
              }
            } catch (e) {
              print('❌ Kişi ekleme hatası: $e');
              hatalar++;
            }
          }
          await Future.delayed(Duration.zero);
        }

        // 3. Son olarak belgeleri ekle
        for (int i = 0; i < belgelerData.length; i += BATCH_SIZE) {
          final batch = belgelerData.skip(i).take(BATCH_SIZE).toList();

          for (final belgeData in batch) {
            try {
              final belge = BelgeModeli.fromMap(belgeData);

              // Kişi ID'sini doğru şekilde eşleştir
              int? dogruKisiId;
              if (belgeData['kisi_ad'] != null &&
                  belgeData['kisi_soyad'] != null) {
                final kisiAd = belgeData['kisi_ad'] as String;
                final kisiSoyad = belgeData['kisi_soyad'] as String;

                final mevcutKisi = await _veriTabani.kisiBulAdSoyad(
                  kisiAd,
                  kisiSoyad,
                );
                if (mevcutKisi != null) {
                  dogruKisiId = mevcutKisi.id;
                  print(
                    '👤 Kişi eşleştirildi: $kisiAd $kisiSoyad (ID: $dogruKisiId)',
                  );
                } else {
                  print(
                    '⚠️ Kişi bulunamadı: $kisiAd $kisiSoyad - Eski ID korunuyor',
                  );
                  dogruKisiId = belge.kisiId;
                }
              } else {
                dogruKisiId = belge.kisiId;
              }

              // Kategori ID'sini doğru şekilde eşleştir
              int? dogruKategoriId;
              if (belgeData['kategori_adi'] != null) {
                final kategoriAdi = belgeData['kategori_adi'] as String;

                final mevcutKategori = await _veriTabani.kategoriBulAd(
                  kategoriAdi,
                );
                if (mevcutKategori != null) {
                  dogruKategoriId = mevcutKategori.id;
                  print(
                    '📁 Kategori eşleştirildi: $kategoriAdi (ID: $dogruKategoriId)',
                  );
                } else {
                  print(
                    '⚠️ Kategori bulunamadı: $kategoriAdi - Eski ID korunuyor',
                  );
                  dogruKategoriId = belge.kategoriId;
                }
              } else {
                dogruKategoriId = belge.kategoriId;
              }

              // Dosya içeriğini kaydet
              if (belgeData['dosya_icerigi'] != null) {
                final dosyaBytes = base64Decode(belgeData['dosya_icerigi']);
                final dosyaYolu = await _dosyaServisi.senkronDosyasiKaydet(
                  belge.dosyaAdi,
                  dosyaBytes,
                );

                // Belgeyi doğru kişi ve kategori ID'leri ile güncelle
                final yeniBelge = belge.copyWith(
                  dosyaYolu: dosyaYolu,
                  kisiId: dogruKisiId,
                  kategoriId: dogruKategoriId,
                  senkronDurumu: SenkronDurumu.SENKRONIZE,
                );

                // Belge zaten var mı kontrol et
                final mevcutBelge = await _veriTabani.belgeBulHash(
                  belge.dosyaHash,
                );
                if (mevcutBelge == null) {
                  await _veriTabani.belgeEkle(yeniBelge);
                  belgelerEklendi++;
                  print(
                    '✅ Belge kaydedildi: ${belge.dosyaAdi} (Kişi: $dogruKisiId, Kategori: $dogruKategoriId)',
                  );
                } else {
                  print('⏭️ Belge zaten mevcut: ${belge.dosyaAdi}');
                  // Mevcut belgenin kişi/kategori bilgilerini güncelle
                  final guncellenmisBelge = mevcutBelge.copyWith(
                    kisiId: dogruKisiId,
                    kategoriId: dogruKategoriId,
                    baslik: belge.baslik,
                    aciklama: belge.aciklama,
                    etiketler: belge.etiketler,
                    guncellemeTarihi: DateTime.now(),
                  );
                  await _veriTabani.belgeGuncelle(guncellenmisBelge);
                  print('🔄 Belge metadata güncellendi: ${belge.dosyaAdi}');
                }
              } else {
                print('⚠️ Belge içeriği bulunamadı: ${belge.dosyaAdi}');
                hatalar++;
              }
            } catch (e) {
              print('❌ Belge kaydetme hatası: $e');
              hatalar++;
            }
          }
          await Future.delayed(Duration.zero);
        }

        print('📊 Kapsamlı senkronizasyon tamamlandı:');
        print('   • Kategoriler: $kategorilerEklendi');
        print('   • Kişiler: $kisilerEklendi');
        print('   • Belgeler: $belgelerEklendi');
        print('   • Hatalar: $hatalar');
      } catch (e) {
        print('❌ Senkronizasyon hatası: $e');
        throw e;
      }

      return json.encode({
        'success': true,
        'message': 'Kapsamlı senkronizasyon tamamlandı',
        'sonuc': {
          'kategoriler_eklendi': kategorilerEklendi,
          'kisiler_eklendi': kisilerEklendi,
          'belgeler_eklendi': belgelerEklendi,
          'hatalar': hatalar,
        },
        'toplam': {
          'kategoriler': kategorilerData.length,
          'kisiler': kisilerData.length,
          'belgeler': belgelerData.length,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kapsamlı senkronizasyon hatası: $e');
      return _createErrorResponse(
        'Kapsamlı senkronizasyon başarısız',
        e.toString(),
      );
    }
  }

  /// Bekleyen senkronizasyon kişilerini döndür (GET)
  Future<String> _handleSyncKisiler() async {
    try {
      print('👤 Senkronizasyon bekleyen kişiler istendi');

      final kisiler = await _veriTabani.kisileriGetir();
      // Sadece son 6 saatte oluşturulan kişileri bekleyen olarak kabul et
      final altiSaatOnce = DateTime.now().subtract(const Duration(hours: 6));
      final bekleyenKisiler =
          kisiler
              .where((kisi) => kisi.olusturmaTarihi.isAfter(altiSaatOnce))
              .toList();

      print('📊 ${bekleyenKisiler.length} bekleyen kişi bulundu');

      final kisilerJson = <Map<String, dynamic>>[];

      // Batch processing ile kişileri hazırla
      for (int i = 0; i < bekleyenKisiler.length; i += BATCH_SIZE) {
        final batch = bekleyenKisiler.skip(i).take(BATCH_SIZE).toList();

        for (final kisi in batch) {
          final kisiMap = kisi.toMap();

          // Profil fotoğrafını dahil et - standardize key naming
          if (kisi.profilFotografi != null &&
              kisi.profilFotografi!.isNotEmpty) {
            try {
              final profilFile = File(kisi.profilFotografi!);
              if (await profilFile.exists()) {
                final dosyaBytes = await profilFile.readAsBytes();
                if (dosyaBytes.isNotEmpty &&
                    dosyaBytes.length <= MAX_PROFILE_PHOTO_SIZE) {
                  kisiMap['profil_fotografi_icerigi'] = base64Encode(
                    dosyaBytes,
                  );
                  kisiMap['profil_fotografi_dosya_adi'] = path.basename(
                    kisi.profilFotografi!,
                  );
                  print(
                    '📸 Profil fotoğrafı dahil edildi: ${kisi.ad} ${kisi.soyad} (${dosyaBytes.length} bytes)',
                  );
                } else {
                  print(
                    '⚠️ Profil fotoğrafı çok büyük veya boş: ${kisi.ad} ${kisi.soyad}',
                  );
                  kisiMap['profil_fotografi_icerigi'] = null;
                  kisiMap['profil_fotografi_dosya_adi'] = null;
                }
              } else {
                print(
                  '⚠️ Profil fotoğrafı dosyası mevcut değil: ${kisi.profilFotografi}',
                );
                kisiMap['profil_fotografi_icerigi'] = null;
                kisiMap['profil_fotografi_dosya_adi'] = null;
              }
            } catch (e) {
              print(
                '❌ Profil fotoğrafı okuma hatası: ${kisi.ad} ${kisi.soyad} - $e',
              );
              kisiMap['profil_fotografi_icerigi'] = null;
              kisiMap['profil_fotografi_dosya_adi'] = null;
            }
          } else {
            kisiMap['profil_fotografi_icerigi'] = null;
            kisiMap['profil_fotografi_dosya_adi'] = null;
          }

          kisilerJson.add(kisiMap);
        }

        await Future.delayed(Duration.zero);
      }

      return json.encode({
        'success': true,
        'kisiler': kisilerJson,
        'toplam': bekleyenKisiler.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kişi senkronizasyonu hatası: $e');
      return _createErrorResponse('Kişiler alınamadı', e.toString());
    }
  }

  /// Kişileri al ve karşı tarafa kaydet (POST) - Standardized key naming
  Future<String> _handleReceiveKisiler(HttpRequest request) async {
    try {
      print('👥 Kişi senkronizasyonu alınıyor');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final kisilerData = data['kisiler'] as List<dynamic>;
      int basariliSayisi = 0;
      int hataliSayisi = 0;
      int guncellenmisSayisi = 0;

      print('📦 ${kisilerData.length} kişi verisi alındı');

      // Batch processing ile kişileri kaydet
      for (int i = 0; i < kisilerData.length; i += BATCH_SIZE) {
        final batch = kisilerData.skip(i).take(BATCH_SIZE).toList();

        for (final kisiData in batch) {
          try {
            final kisi = KisiModeli.fromMap(kisiData);

            // Profil fotoğrafını kaydet - standardized key naming
            if (kisiData['profil_fotografi_icerigi'] != null) {
              try {
                final profilBytes = base64Decode(
                  kisiData['profil_fotografi_icerigi'],
                );

                // Dosya boyutu kontrolü
                if (profilBytes.length > MAX_PROFILE_PHOTO_SIZE) {
                  print('⚠️ Profil fotoğrafı çok büyük: ${kisi.tamAd}');
                  await _saveKisiWithoutPhoto(kisi);
                  basariliSayisi++;
                  continue;
                }

                final dosyaAdi = '${kisi.ad}_${kisi.soyad}_profil.jpg';
                final profilYolu = await _dosyaServisi.senkronDosyasiKaydet(
                  dosyaAdi,
                  profilBytes,
                );

                // Profil fotoğrafı yolunu güncelle
                final yeniKisi = kisi.copyWith(
                  profilFotografi: profilYolu,
                  guncellemeTarihi: DateTime.now(),
                  // Senkronizasyon sırasında gelen kişileri bekleyen listesinden çıkarmak için
                  olusturmaTarihi: DateTime.now().subtract(
                    const Duration(days: 2),
                  ),
                );

                // Kişi zaten var mı kontrol et
                final mevcutKisi = await _veriTabani.kisiBulAdSoyad(
                  kisi.ad,
                  kisi.soyad,
                );

                if (mevcutKisi == null) {
                  await _veriTabani.kisiEkle(yeniKisi);
                  basariliSayisi++;
                  print('✅ Yeni kişi eklendi: ${kisi.tamAd}');
                } else {
                  final guncellenmisKisi = yeniKisi.copyWith(id: mevcutKisi.id);
                  await _veriTabani.kisiGuncelle(guncellenmisKisi);
                  guncellenmisSayisi++;
                  print('🔄 Kişi güncellendi: ${kisi.tamAd}');
                }
              } catch (e) {
                print('⚠️ Profil fotoğrafı kaydedilemedi: $e');
                await _saveKisiWithoutPhoto(kisi);
                basariliSayisi++;
              }
            } else {
              await _saveKisiWithoutPhoto(kisi);
              basariliSayisi++;
            }
          } catch (e) {
            print('❌ Kişi kaydedilemedi: $e');
            hataliSayisi++;
          }
        }

        await Future.delayed(Duration.zero);
      }

      print('📊 Kişi senkronizasyon sonucu:');
      print('   • Başarılı: $basariliSayisi');
      print('   • Güncellenen: $guncellenmisSayisi');
      print('   • Hatalı: $hataliSayisi');

      return json.encode({
        'success': true,
        'message': 'Kişi senkronizasyonu tamamlandı',
        'basarili': basariliSayisi,
        'guncellenen': guncellenmisSayisi,
        'hatali': hataliSayisi,
        'toplam': kisilerData.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kişi senkronizasyon hatası: $e');
      return _createErrorResponse('Kişiler kaydedilemedi', e.toString());
    }
  }

  /// Profil fotoğrafı olmadan kişiyi kaydet
  Future<void> _saveKisiWithoutPhoto(KisiModeli kisi) async {
    try {
      final mevcutKisi = await _veriTabani.kisiBulAdSoyad(kisi.ad, kisi.soyad);

      if (mevcutKisi == null) {
        final yeniKisi = kisi.copyWith(
          olusturmaTarihi: DateTime.now().subtract(const Duration(days: 2)),
          guncellemeTarihi: DateTime.now(),
        );
        await _veriTabani.kisiEkle(yeniKisi);
        print('✅ Yeni kişi eklendi (profil fotoğrafı yok): ${kisi.tamAd}');
      } else {
        final guncellenmisKisi = kisi.copyWith(
          id: mevcutKisi.id,
          guncellemeTarihi: DateTime.now(),
        );
        await _veriTabani.kisiGuncelle(guncellenmisKisi);
        print('🔄 Kişi güncellendi (profil fotoğrafı yok): ${kisi.tamAd}');
      }
    } catch (e) {
      print('❌ Kişi kaydetme hatası: $e');
    }
  }

  /// Bekleyen senkronizasyon kategorilerini döndür (GET)
  Future<String> _handleSyncKategoriler() async {
    try {
      print('📁 Senkronizasyon bekleyen kategoriler istendi');

      final kategoriler = await _veriTabani.kategorileriGetir();

      // Kategori optimizasyonu: Sadece bugünden itibaren eklenen kategorileri bekleyen olarak kabul et
      // Mevcut 16 kategori her iki sistemde de var, onları senkronize etmeye gerek yok
      final bugun = DateTime.now();
      final bugunBaslangic = DateTime(bugun.year, bugun.month, bugun.day);

      final bekleyenKategoriler =
          kategoriler
              .where(
                (kategori) => kategori.olusturmaTarihi.isAfter(bugunBaslangic),
              )
              .toList();

      print(
        '📊 ${bekleyenKategoriler.length} bekleyen kategori bulundu (sadece bugün eklenenler)',
      );
      print(
        '📅 Kategori filtresi: ${bugunBaslangic.toIso8601String()} sonrası',
      );

      final kategorilerJson =
          bekleyenKategoriler.map((kategori) => kategori.toMap()).toList();

      return json.encode({
        'success': true,
        'kategoriler': kategorilerJson,
        'toplam': bekleyenKategoriler.length,
        'filtre_tarihi': bugunBaslangic.toIso8601String(),
        'aciklama': 'Sadece bugün eklenen kategoriler dahil edildi',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kategori senkronizasyonu hatası: $e');
      return _createErrorResponse('Kategoriler alınamadı', e.toString());
    }
  }

  /// Gelen kategorileri al ve kaydet (POST)
  Future<String> _handleReceiveKategoriler(HttpRequest request) async {
    try {
      print('📥 Kategori senkronizasyonu alınıyor');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final kategorilerData = data['kategoriler'] as List<dynamic>;
      int basariliSayisi = 0;
      int hataliSayisi = 0;
      int guncellenmisSayisi = 0;

      // Batch processing ile kategorileri kaydet
      for (int i = 0; i < kategorilerData.length; i += BATCH_SIZE) {
        final batch = kategorilerData.skip(i).take(BATCH_SIZE).toList();

        for (final kategoriData in batch) {
          try {
            final kategori = KategoriModeli.fromMap(kategoriData);

            // Kategori zaten var mı kontrol et
            final mevcutKategori = await _veriTabani.kategoriBulAd(kategori.ad);

            if (mevcutKategori == null) {
              // Yeni kategori ekle - senkronizasyondan gelen kategorileri bekleyen listesinden çıkarmak için
              final eskiTarihliKategori = kategori.copyWith(
                olusturmaTarihi: DateTime.now().subtract(
                  const Duration(days: 2),
                ),
              );
              await _veriTabani.kategoriEkle(eskiTarihliKategori);
              basariliSayisi++;
              print('✅ Kategori kaydedildi: ${kategori.ad}');
            } else {
              // Mevcut kategoriyi güncelle
              final guncellenmisKategori = kategori.copyWith(
                id: mevcutKategori.id,
                kategoriAdi: kategori.kategoriAdi,
                renkKodu: kategori.renkKodu,
                simgeKodu: kategori.simgeKodu,
                aciklama: kategori.aciklama,
                // Eski tarih vererek bekleyen listesinden çıkar
                olusturmaTarihi: DateTime.now().subtract(
                  const Duration(days: 2),
                ),
              );
              await _veriTabani.kategoriGuncelle(guncellenmisKategori);
              guncellenmisSayisi++;
              print('🔄 Kategori güncellendi: ${kategori.ad}');
            }
          } catch (e) {
            print('❌ Kategori kaydetme hatası: $e');
            hataliSayisi++;
          }
        }

        await Future.delayed(Duration.zero);
      }

      return json.encode({
        'success': true,
        'message': 'Kategori senkronizasyonu tamamlandı',
        'basarili': basariliSayisi,
        'guncellenen': guncellenmisSayisi,
        'hatali': hataliSayisi,
        'toplam': kategorilerData.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kategori alma hatası: $e');
      return _createErrorResponse('Kategoriler kaydedilemedi', e.toString());
    }
  }

  /// Bekleyen senkronizasyonların özet bilgisini döndür
  Future<String> _handleBekleyenSenkronlar() async {
    try {
      print('📋 Bekleyen senkronizasyonlar sorgulandı');

      final belgeler = await _veriTabani.belgeleriGetir();
      final bekleyenBelgeler =
          belgeler
              .where(
                (belge) =>
                    belge.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                    belge.senkronDurumu == SenkronDurumu.YEREL_DEGISIM,
              )
              .length;

      final kisiler = await _veriTabani.kisileriGetir();
      final altiSaatOnce = DateTime.now().subtract(const Duration(hours: 6));
      final bekleyenKisiler =
          kisiler
              .where((kisi) => kisi.olusturmaTarihi.isAfter(altiSaatOnce))
              .length;

      final kategoriler = await _veriTabani.kategorileriGetir();

      // Kategori optimizasyonu: Sadece bugünden itibaren eklenen kategorileri bekleyen olarak kabul et
      // Mevcut 16 kategori her iki sistemde de var, onları senkronize etmeye gerek yok
      final bugun = DateTime.now();
      final bugunBaslangic = DateTime(bugun.year, bugun.month, bugun.day);

      final bekleyenKategoriler =
          kategoriler
              .where(
                (kategori) => kategori.olusturmaTarihi.isAfter(bugunBaslangic),
              )
              .length;

      return json.encode({
        'success': true,
        'bekleyen_belgeler': bekleyenBelgeler,
        'bekleyen_kisiler': bekleyenKisiler,
        'bekleyen_kategoriler': bekleyenKategoriler,
        'toplam_bekleyen':
            bekleyenBelgeler + bekleyenKisiler + bekleyenKategoriler,
        'kategori_filtre_aciklama': 'Sadece bugün eklenen kategoriler dahil',
        'kategori_filtre_tarihi': bugunBaslangic.toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Bekleyen senkronizasyon sorgu hatası: $e');
      return _createErrorResponse(
        'Bekleyen senkronizasyonlar sorgulanamadı',
        e.toString(),
      );
    }
  }

  /// Senkronizasyon durumu bilgisini döndür
  Future<String> _handleSyncStatus() async {
    try {
      print('📊 Senkronizasyon durumu sorgulandı');

      final belgeler = await _veriTabani.belgeleriGetir();
      final senkronizeDurumlari = <String, int>{};

      for (final durum in SenkronDurumu.values) {
        senkronizeDurumlari[durum.toString()] =
            belgeler.where((belge) => belge.senkronDurumu == durum).length;
      }

      final toplamBelgeSayisi = belgeler.length;
      final senkronizeBelgeSayisi =
          belgeler
              .where((belge) => belge.senkronDurumu == SenkronDurumu.SENKRONIZE)
              .length;

      return json.encode({
        'success': true,
        'toplam_belge': toplamBelgeSayisi,
        'senkronize_belge': senkronizeBelgeSayisi,
        'senkronizasyon_orani':
            toplamBelgeSayisi > 0
                ? (senkronizeBelgeSayisi / toplamBelgeSayisi * 100).round()
                : 0,
        'durum_detaylari': senkronizeDurumlari,
        'bagli_cihaz_sayisi': _bagliCihazlar.length,
        'sunucu_aktif': _calisiyorMu,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Senkronizasyon durumu sorgu hatası: $e');
      return _createErrorResponse(
        'Senkronizasyon durumu sorgulanamadı',
        e.toString(),
      );
    }
  }

  /// QR Login endpoint'i
  Future<String> _handleQRLogin(HttpRequest request) async {
    try {
      print('📱 QR Login isteği alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final kullaniciAdi = data['kullanici_adi'] as String?;
      final token = data['token'] as String?;
      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final platform = data['platform'] as String?;
      final userInfo = data['user_info'] as Map<String, dynamic>?;

      print('📊 QR Login verileri:');
      print('  - Kullanıcı: $kullaniciAdi');
      print('  - Token: $token');
      print('  - Device ID: $deviceId');
      print('  - Device Name: $deviceName');
      print('  - Platform: $platform');
      print('  - User Info: ${userInfo != null ? 'Mevcut' : 'Yok'}');

      if (kullaniciAdi == null || token == null) {
        print('❌ Eksik veri: kullanici_adi ve token gerekli');
        return _createErrorResponse(
          'Missing parameters',
          'kullanici_adi ve token gerekli',
        );
      }

      // Kullanıcı bilgilerini kontrol et ve gerekirse otomatik kayıt yap
      if (userInfo != null) {
        print('👤 Kullanıcı bilgileri kontrol ediliyor...');
        await _ensureUserExists(userInfo);
      }

      // QR Login callback'ini çağır
      if (_onQRLoginRequest != null) {
        print('🔑 QR Login callback çağırılıyor: $kullaniciAdi');

        _onQRLoginRequest!({
          'kullanici_adi': kullaniciAdi,
          'token': token,
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platform,
          'user_info': userInfo,
        });

        print('✅ QR Login callback çağırıldı');
      } else {
        print('❌ QR Login callback tanımlanmamış!');
      }

      return json.encode({
        'success': true,
        'message': 'QR Login isteği alındı',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ QR Login handler hatası: $e');
      return _createErrorResponse('QR Login hatası', e.toString());
    }
  }

  /// Kullanıcı adı ile kullanıcı getir
  Future<KisiModeli?> _getUserByUsername(String kullaniciAdi) async {
    try {
      final db = await _veriTabani.database;
      final result = await db.query(
        'kisiler',
        where: 'kullanici_adi = ? AND aktif = ?',
        whereArgs: [kullaniciAdi, 1],
      );

      if (result.isNotEmpty) {
        return KisiModeli.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('❌ Kullanıcı getir hatası: $e');
      return null;
    }
  }

  /// Kullanıcının var olduğundan emin ol, yoksa otomatik kayıt yap
  Future<void> _ensureUserExists(Map<String, dynamic> userInfo) async {
    try {
      final kullaniciAdi = userInfo['kullanici_adi'] as String?;
      if (kullaniciAdi == null) return;

      print('🔍 Kullanıcı kontrol ediliyor: $kullaniciAdi');

      final existingUser = await _getUserByUsername(kullaniciAdi);

      if (existingUser == null) {
        print('➕ Kullanıcı bulunamadı, otomatik kayıt yapılıyor...');

        final yeniKullanici = KisiModeli(
          ad: userInfo['ad'] ?? 'Bilinmeyen',
          soyad: userInfo['soyad'] ?? 'Kullanıcı',
          kullaniciAdi: kullaniciAdi,
          sifre: null, // QR login için şifre gerekmez
          kullaniciTipi: userInfo['kullanici_tipi'] ?? 'kullanici',
          profilFotografi: userInfo['profil_fotografi'],
          olusturmaTarihi: DateTime.now(),
          guncellemeTarihi: DateTime.now(),
          aktif: true,
        );

        await _veriTabani.kisiEkle(yeniKullanici);
        print('✅ Kullanıcı otomatik kayıt edildi: $kullaniciAdi');

        await _registerDevice(kullaniciAdi, userInfo);
      } else {
        print('✅ Kullanıcı mevcut: $kullaniciAdi');

        final guncelKullanici = existingUser.copyWith(
          ad: userInfo['ad'] ?? existingUser.ad,
          soyad: userInfo['soyad'] ?? existingUser.soyad,
          profilFotografi:
              userInfo['profil_fotografi'] ?? existingUser.profilFotografi,
          guncellemeTarihi: DateTime.now(),
        );

        await _veriTabani.kisiGuncelle(guncelKullanici);
        print('✅ Kullanıcı bilgileri güncellendi: $kullaniciAdi');

        await _registerDevice(kullaniciAdi, userInfo);
      }
    } catch (e) {
      print('❌ Kullanıcı kontrol/kayıt hatası: $e');
    }
  }

  /// Cihaz bilgilerini kaydet (çoklu cihaz desteği için)
  Future<void> _registerDevice(
    String kullaniciAdi,
    Map<String, dynamic> userInfo,
  ) async {
    try {
      final deviceId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
      final deviceName = userInfo['device_name'] ?? 'Bilinmeyen Cihaz';
      final platform = userInfo['platform'] ?? 'unknown';

      print('📱 Cihaz kaydediliyor: $deviceName ($platform)');

      print('✅ Cihaz kaydedildi: $kullaniciAdi -> $deviceName');

      // Çoklu cihaz desteği için cihaz bilgilerini sakla
      _bagliCihazlar.add({
        'device_id': deviceId,
        'kullanici_adi': kullaniciAdi,
        'device_name': deviceName,
        'platform': platform,
        'connection_time': DateTime.now().toIso8601String(),
        'last_seen': DateTime.now().toIso8601String(),
        'connection_type': 'qr_login',
      });
    } catch (e) {
      print('❌ Cihaz kayıt hatası: $e');
    }
  }
}
