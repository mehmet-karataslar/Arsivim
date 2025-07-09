import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
// import '../utils/sabitler.dart';
// import '../utils/network_optimizer.dart';
// import '../utils/timestamp_manager.dart';
// import 'senkronizasyon_yonetici_servisi.dart';

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
      print('Sunucu zaten calisiyor');
      return;
    }

    try {
      print('HTTP Sunucusu baslatiliyor...');

      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      print('Cihaz bilgileri alindi: $_cihazAdi ($_platform)');

      // Sunucuyu baslat
      print('Port $SUNUCU_PORTU dinlenmeye baslaniyor...');
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);
      print('Arsivim HTTP Sunucusu baslatildi: http://localhost:$SUNUCU_PORTU');

      // IP adresi alındı
      final realIP = await getRealIPAddress();
      print('🌐 Gerçek IP adresi: $realIP');

      print('Cihaz ID: $_cihazId');
      print('Platform: $_platform');

      _calisiyorMu = true;
      print('Sunucu durumu: $_calisiyorMu');

      // Istekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          print('HTTP Istek: ${request.method} ${request.uri.path}');

          // CORS headers ekle
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add(
            'Access-Control-Allow-Methods',
            'GET, POST, PUT, DELETE, OPTIONS',
          );
          request.response.headers.add(
            'Access-Control-Allow-Headers',
            'Content-Type, Authorization',
          );
          request.response.headers.add(
            'Content-Type',
            'application/json; charset=utf-8',
          );

          // OPTIONS request icin CORS preflight
          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
            await request.response.close();
            return;
          }

          String responseBody;
          int statusCode = 200;

          // Route handling - Yeni endpoint'ler eklendi
          switch (request.uri.path) {
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/connect':
              if (request.method == 'POST') {
                responseBody = await _handleConnect(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/disconnect':
              if (request.method == 'POST') {
                responseBody = await _handleDisconnect(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/status':
              responseBody = await _handleStatus();
              break;
            case '/devices':
              responseBody = await _handleDevices();
              break;
            case '/device-connected':
              if (request.method == 'POST') {
                responseBody = await _handleDeviceConnected(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/device-disconnected':
              if (request.method == 'POST') {
                responseBody = await _handleDeviceDisconnected(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            // Senkronizasyon endpoint'leri
            case '/sync/belgeler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncBelgeler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveBelgeler(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/belgeler-kapsamli':
              if (request.method == 'POST') {
                responseBody = await _handleReceiveBelgelerKapsamli(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/kisiler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncKisiler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveKisiler(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/kategoriler':
              if (request.method == 'GET') {
                responseBody = await _handleSyncKategoriler();
              } else if (request.method == 'POST') {
                responseBody = await _handleReceiveKategoriler(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/bekleyen':
              responseBody = await _handleBekleyenSenkronlar();
              break;
            case '/sync/status':
              responseBody = await _handleSyncStatus();
              break;
            case '/auth/qr-login':
              if (request.method == 'POST') {
                responseBody = await _handleQRLogin(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            default:
              statusCode = 404;
              responseBody = json.encode({'error': 'Endpoint bulunamadi'});
          }

          // Response gonder
          final responseBytes = utf8.encode(responseBody);
          request.response
            ..statusCode = statusCode
            ..add(responseBytes);

          await request.response.close();
          print('HTTP Yanit gonderildi: $statusCode');
        } catch (e) {
          print('Istek isleme hatasi: $e');
          try {
            final errorResponse = json.encode({
              'error': 'Sunucu hatasi',
              'message': e.toString(),
            });
            final errorBytes = utf8.encode(errorResponse);

            request.response
              ..statusCode = 500
              ..add(errorBytes);
            await request.response.close();
          } catch (closeError) {
            print('Response kapatma hatasi: $closeError');
          }
        }
      });
    } catch (e) {
      print('Sunucu baslatma hatasi: $e');
      throw Exception('HTTP sunucusu baslatilamadi: $e');
    }
  }

  Future<void> sunucuyuDurdur() async {
    final sunucu = _sunucu;
    if (sunucu != null) {
      await sunucu.close();
      _sunucu = null;
      _calisiyorMu = false;
      _bagliCihazlar.clear();
      print('Arsivim HTTP Sunucusu durduruldu');
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

      // Cihaz ID'sini hash'le (guvenlik icin)
      final cihazId = _cihazId ?? 'unknown-device';
      final bytes = utf8.encode(cihazId);
      final digest = sha256.convert(bytes);
      _cihazId = digest.toString().substring(0, 16);
    } catch (e) {
      print('Cihaz bilgisi alinamadi: $e');
      _cihazAdi = 'Arsivim Cihazi';
      _platform = Platform.operatingSystem;
      _cihazId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // HTTP Handler metodlari
  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _cihazId,
      'device_name': _cihazAdi,
      'platform': _platform,
    });
  }

  Future<String> _handleInfo() async {
    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();
      final serverIP = await getRealIPAddress();

      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
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
      });
    } catch (e) {
      print('Info endpoint hatasi: $e');
      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'device_id': _cihazId,
        'device_name': _cihazAdi,
        'platform': _platform,
        'document_count': 0,
        'total_size': 0,
        'server_ip': null,
        'server_port': SUNUCU_PORTU,
        'timestamp': DateTime.now().toIso8601String(),
        'server_running': true,
        'connected_devices': 0,
      });
    }
  }

  Future<String> _handleConnect(HttpRequest request) async {
    try {
      print('Baglanti istegi alindi');

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
        return json.encode({
          'success': false,
          'error': 'device_id ve device_name gerekli',
        });
      }

      // Cihaz zaten bagli mi kontrol et
      final mevcutCihaz = _bagliCihazlar.firstWhere(
        (device) => device['device_id'] == deviceId,
        orElse: () => <String, dynamic>{},
      );

      if (mevcutCihaz.isNotEmpty) {
        // Mevcut cihazin bilgilerini guncelle
        mevcutCihaz['last_seen'] = DateTime.now().toIso8601String();
        mevcutCihaz['status'] = 'connected';
        mevcutCihaz['online'] = true;
        print('Mevcut cihaz bilgileri guncellendi: $deviceName');
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
        print('Yeni cihaz eklendi: $deviceName ($deviceId)');

        // UI'ya bildirim gonder
        if (_onDeviceConnected != null) {
          print('UI\'ya baglanti bildirimi gonderiliyor...');
          Future.microtask(() => _onDeviceConnected!(yeniCihaz));
        }
      }

      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'success': true,
        'message': 'Baglanti kuruldu',
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
      print('Connect handler hatasi: $e');
      return json.encode({
        'success': false,
        'error': 'Baglanti hatasi',
        'message': e.toString(),
      });
    }
  }

  Future<String> _handleDisconnect(HttpRequest request) async {
    try {
      print('Baglanti kesme istegi alindi');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final reason = data['reason'] as String?;

      if (deviceId == null) {
        return json.encode({'success': false, 'error': 'device_id gerekli'});
      }

      // Cihazi listeden kaldir
      final removedDevice = _bagliCihazlar.firstWhere(
        (device) => device['device_id'] == deviceId,
        orElse: () => <String, dynamic>{},
      );

      if (removedDevice.isNotEmpty) {
        _bagliCihazlar.removeWhere((device) => device['device_id'] == deviceId);
        print(
          'Cihaz baglantisi kesildi: ${removedDevice['device_name']} ($deviceId)',
        );
        print('Sebep: ${reason ?? 'Belirtilmedi'}');

        // UI'ya bildirim gonder
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': deviceId,
            'device_name': removedDevice['device_name'],
            'reason': reason ?? 'Baglanti kesildi',
            'timestamp': DateTime.now().toIso8601String(),
          };
          print('UI\'ya baglanti kesme bildirimi gonderiliyor...');
          Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
        }

        return json.encode({
          'success': true,
          'message': 'Baglanti kesildi',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        return json.encode({
          'success': false,
          'error': 'Cihaz bulunamadi',
          'message': 'Belirtilen cihaz bagli cihazlar listesinde yok',
        });
      }
    } catch (e) {
      print('Disconnect handler hatasi: $e');
      return json.encode({
        'success': false,
        'error': 'Baglanti kesme hatasi',
        'message': e.toString(),
      });
    }
  }

  Future<String> _handleStatus() async {
    try {
      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
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
      print('Status handler hatasi: $e');
      return json.encode({
        'status': 'error',
        'error': 'Status alinamadi',
        'message': e.toString(),
      });
    }
  }

  Future<String> _handleDevices() async {
    try {
      // Bagli cihazlarin son gorulme zamanlarini kontrol et
      final now = DateTime.now();
      final timeoutDuration = Duration(minutes: 5);

      _bagliCihazlar.removeWhere((device) {
        final lastSeen = DateTime.parse(device['last_seen']);
        final isTimedOut = now.difference(lastSeen) > timeoutDuration;

        if (isTimedOut) {
          print('Cihaz timeout nedeniyle kaldirildi: ${device['device_name']}');
          // UI'ya bildirim gonder
          if (_onDeviceDisconnected != null) {
            final disconnectionInfo = {
              'device_id': device['device_id'],
              'device_name': device['device_name'],
              'reason': 'Timeout',
              'timestamp': DateTime.now().toIso8601String(),
            };
            Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
          }
        }

        return isTimedOut;
      });

      return json.encode({
        'success': true,
        'devices': _bagliCihazlar,
        'total_count': _bagliCihazlar.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Devices handler hatasi: $e');
      return json.encode({
        'success': false,
        'error': 'Cihaz listesi alinamadi',
        'message': e.toString(),
        'devices': [],
      });
    }
  }

  Future<String> _handleDeviceConnected(HttpRequest request) async {
    try {
      print('Cihaz baglanti bildirimi alindi');

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
        return json.encode({'error': 'device_id ve device_name gerekli'});
      }

      print('YENI CIHAZ BAGLANDI!');
      print('Cihaz: $deviceName ($deviceId)');
      print('Platform: $platform');
      print('IP: $clientIP');

      // UI'ya bildirim gonder
      final deviceInfo = {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform ?? 'Unknown',
        'ip': clientIP,
        'timestamp': DateTime.now().toIso8601String(),
        'connection_type': 'incoming',
      };

      // Callback'i cagir
      if (_onDeviceConnected != null) {
        print('UI\'ya baglanti bildirimi gonderiliyor...');
        Future.microtask(() => _onDeviceConnected!(deviceInfo));
      } else {
        print('Device connected callback tanimlanmamis!');
      }

      return json.encode({
        'status': 'success',
        'message': 'Baglanti bildirimi alindi',
        'server_device_id': _cihazId,
        'server_device_name': _cihazAdi,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Device connected handler hatasi: $e');
      return json.encode({
        'error': 'Baglanti bildirimi hatasi',
        'message': e.toString(),
      });
    }
  }

  Future<String> _handleDeviceDisconnected(HttpRequest request) async {
    try {
      print('Cihaz baglanti kesme bildirimi alindi');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final message = data['message'] as String?;

      if (deviceId == null) {
        return json.encode({'error': 'device_id gerekli'});
      }

      print('Cihaz baglantisi kesildi: $deviceId');
      print('Mesaj: $message');

      // UI'ya bildirim gonder
      final disconnectionInfo = {
        'device_id': deviceId,
        'message': message ?? 'Baglanti kesildi',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Callback'i cagir
      if (_onDeviceDisconnected != null) {
        print('UI\'ya baglanti kesme bildirimi gonderiliyor...');
        Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
      } else {
        print('Device disconnected callback tanimlanmamis!');
      }

      return json.encode({
        'status': 'success',
        'message': 'Baglanti kesme bildirimi alindi',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Device disconnected handler hatasi: $e');
      return json.encode({
        'error': 'Baglanti kesme bildirimi hatasi',
        'message': e.toString(),
      });
    }
  }

  // IP adresini gercek zamanli al
  Future<String?> getRealIPAddress() async {
    try {
      print('🔍 Network interface\'leri taraniyor...');
      final interfaces = await NetworkInterface.list();

      String? bestIP;
      int bestPriority = 0;

      for (final interface in interfaces) {
        print(
          'Interface: ${interface.name}, addresses: ${interface.addresses.length}',
        );

        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            print(
              '  📍 Address: ${addr.address}, Interface: ${interface.name}',
            );

            int priority = 0;
            final interfaceName = interface.name.toLowerCase();

            // Virtual interface'leri atla
            if (interfaceName.contains('virtual') ||
                interfaceName.contains('vmware') ||
                interfaceName.contains('vbox') ||
                interfaceName.contains('virtualbox') ||
                interfaceName.contains('docker') ||
                interfaceName.contains('hyper-v')) {
              print('  ⚠️  Virtual interface atlandı: ${interface.name}');
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
                '  ✅ Yeni en iyi IP: ${addr.address} (Öncelik: $priority, Interface: ${interface.name})',
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

  // Utility metodlari
  void clearConnectedDevices() {
    _bagliCihazlar.clear();
    print('Bagli cihazlar listesi temizlendi');
  }

  void updateDeviceLastSeen(String deviceId) {
    final device = _bagliCihazlar.firstWhere(
      (device) => device['device_id'] == deviceId,
      orElse: () => <String, dynamic>{},
    );

    if (device.isNotEmpty) {
      device['last_seen'] = DateTime.now().toIso8601String();
      print('Cihaz son gorulme zamani guncellendi: $deviceId');
    }
  }

  // Senkronizasyon Handler Metodlari

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

      for (final belge in bekleyenBelgeler) {
        final belgeMap = belge.toMap();

        // Dosya boyutu kontrolü - 10MB üzeri dosyalar için farklı strateji
        try {
          final dosyaBytes = File(belge.dosyaYolu).readAsBytesSync();

          if (dosyaBytes.length > 10 * 1024 * 1024) {
            // 10MB
            print(
              '⚠️ Büyük dosya atlanıyor: ${belge.dosyaAdi} (${dosyaBytes.length} bytes)',
            );
            belgeMap['dosya_icerigi'] = null;
            belgeMap['buyuk_dosya'] = true;
            belgeMap['dosya_boyutu'] = dosyaBytes.length;
          } else {
            belgeMap['dosya_icerigi'] = base64Encode(dosyaBytes);
            belgeMap['buyuk_dosya'] = false;
          }
        } catch (e) {
          print('⚠️ Dosya okunamadı: ${belge.dosyaAdi} - $e');
          belgeMap['dosya_icerigi'] = null;
          belgeMap['buyuk_dosya'] = false;
        }

        belgelerJson.add(belgeMap);
      }

      return json.encode({
        'success': true,
        'belgeler': belgelerJson,
        'toplam': bekleyenBelgeler.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Belge senkronizasyonu hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Belgeler alınamadı',
        'message': e.toString(),
      });
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

      for (final belgeData in belgelerData) {
        try {
          // Belge modelini oluştur
          final belge = BelgeModeli.fromMap(belgeData);

          // Dosya içeriğini kaydet
          if (belgeData['dosya_icerigi'] != null) {
            final dosyaBytes = base64Decode(belgeData['dosya_icerigi']);
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
            print('✅ Belge kaydedildi: ${belge.dosyaAdi}');
          } else {
            print('⚠️ Belge içeriği bulunamadı: ${belge.dosyaAdi}');
            hataliSayisi++;
          }
        } catch (e) {
          print('❌ Belge kaydetme hatası: $e');
          hataliSayisi++;
        }
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
      return json.encode({
        'success': false,
        'error': 'Belgeler kaydedilemedi',
        'message': e.toString(),
      });
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

      // Transaction kullanmadan sıralı işlem (veritabanı kilit sorunu çözümü)
      try {
        // 1. Önce kategorileri ekle
        for (final kategoriData in kategorilerData) {
          try {
            final kategori = KategoriModeli.fromMap(kategoriData);

            // Kategori zaten var mı kontrol et
            final mevcutKategori = await _veriTabani.kategoriBulAd(kategori.ad);
            if (mevcutKategori == null) {
              // Kategori ID'sini korumak için özel ekleme
              // Alan tarafta kaydedilen kategorilerin tarihini eski yap
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

        // 2. Sonra kişileri ekle
        for (final kisiData in kisilerData) {
          try {
            final kisi = KisiModeli.fromMap(kisiData);

            // Kişi zaten var mı kontrol et
            final mevcutKisi = await _veriTabani.kisiBulAdSoyad(
              kisi.ad,
              kisi.soyad,
            );
            if (mevcutKisi == null) {
              // Kişi ID'sini korumak için özel ekleme
              // Alan tarafta kaydedilen kişilerin tarihini eski yap
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

        // 3. Son olarak belgeleri ekle
        for (final belgeData in belgelerData) {
          try {
            // Belge modelini oluştur
            final belge = BelgeModeli.fromMap(belgeData);

            // Dosya içeriğini kaydet
            if (belgeData['dosya_icerigi'] != null) {
              final dosyaBytes = base64Decode(belgeData['dosya_icerigi']);
              final dosyaYolu = await _dosyaServisi.senkronDosyasiKaydet(
                belge.dosyaAdi,
                dosyaBytes,
              );

              // Dosya yolunu güncelle
              final yeniBelge = belge.copyWith(
                dosyaYolu: dosyaYolu,
                senkronDurumu: SenkronDurumu.SENKRONIZE,
              );

              // Belge zaten var mı kontrol et
              final mevcutBelge = await _veriTabani.belgeBulHash(
                belge.dosyaHash,
              );
              if (mevcutBelge == null) {
                // Veritabanına kaydet
                await _veriTabani.belgeEkle(yeniBelge);
                belgelerEklendi++;
                print('✅ Belge kaydedildi: ${belge.dosyaAdi}');
              } else {
                print('⏭️ Belge zaten mevcut: ${belge.dosyaAdi}');
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
      return json.encode({
        'success': false,
        'error': 'Kapsamlı senkronizasyon başarısız',
        'message': e.toString(),
      });
    }
  }

  /// Bekleyen senkronizasyon kişilerini döndür (GET)
  Future<String> _handleSyncKisiler() async {
    try {
      print('👤 Senkronizasyon bekleyen kişiler istendi');

      final kisiler = await _veriTabani.kisileriGetir();
      // Yeni eklenen kişileri filtrele (örneğin son 24 saat)
      final bekleyenKisiler =
          kisiler
              .where(
                (kisi) => kisi.olusturmaTarihi.isAfter(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              )
              .toList();

      print('📊 ${bekleyenKisiler.length} bekleyen kişi bulundu');

      final kisilerJson = <Map<String, dynamic>>[];

      for (final kisi in bekleyenKisiler) {
        final kisiMap = kisi.toMap();

        // Profil fotoğrafını dahil et
        if (kisi.profilFotografi != null && kisi.profilFotografi!.isNotEmpty) {
          try {
            final dosyaBytes = File(kisi.profilFotografi!).readAsBytesSync();
            kisiMap['profil_fotografi_icerigi'] = base64Encode(dosyaBytes);
            print('📸 Profil fotoğrafı dahil edildi: ${kisi.ad} ${kisi.soyad}');
          } catch (e) {
            print(
              '⚠️ Profil fotoğrafı okunamadı: ${kisi.ad} ${kisi.soyad} - $e',
            );
            kisiMap['profil_fotografi_icerigi'] = null;
          }
        } else {
          kisiMap['profil_fotografi_icerigi'] = null;
        }

        kisilerJson.add(kisiMap);
      }

      return json.encode({
        'success': true,
        'kisiler': kisilerJson,
        'toplam': bekleyenKisiler.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kişi senkronizasyonu hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Kişiler alınamadı',
        'message': e.toString(),
      });
    }
  }

  /// Gelen kişileri al ve kaydet (POST)
  Future<String> _handleReceiveKisiler(HttpRequest request) async {
    try {
      print('📥 Kişi senkronizasyonu alınıyor');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final kisilerData = data['kisiler'] as List<dynamic>;
      int basariliSayisi = 0;
      int hataliSayisi = 0;
      int mevcutSayisi = 0;

      for (final kisiData in kisilerData) {
        try {
          final kisi = KisiModeli.fromMap(kisiData);

          // Profil fotoğrafını kaydet
          String? profilFotografiYolu;
          if (kisiData['profil_fotografi_icerigi'] != null) {
            try {
              final dosyaBytes = base64Decode(
                kisiData['profil_fotografi_icerigi'],
              );

              // Profil fotoğrafı dizinini oluştur
              final appDir = await getApplicationDocumentsDirectory();
              final profilePhotosDir = Directory(
                '${appDir.path}/profile_photos',
              );
              if (!await profilePhotosDir.exists()) {
                await profilePhotosDir.create(recursive: true);
              }

              final dosyaAdi =
                  'profile_${kisi.ad}_${kisi.soyad}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final savedPath = '${profilePhotosDir.path}/$dosyaAdi';

              // Dosyayı kaydet
              final file = File(savedPath);
              await file.writeAsBytes(dosyaBytes);
              profilFotografiYolu = savedPath;

              print(
                '📸 Profil fotoğrafı kaydedildi: ${kisi.ad} ${kisi.soyad} -> $savedPath',
              );
            } catch (e) {
              print(
                '⚠️ Profil fotoğrafı kaydedilemedi: ${kisi.ad} ${kisi.soyad} - $e',
              );
            }
          }

          // Kişi modelini profil fotoğrafı yolu ile güncelle
          final guncellenmiKisi = kisi.copyWith(
            profilFotografi: profilFotografiYolu ?? kisi.profilFotografi,
          );

          // Kişi zaten var mı kontrol et (ad-soyad kombinasyonu)
          final mevcutKisi = await _veriTabani.kisiBulAdSoyad(
            guncellenmiKisi.ad,
            guncellenmiKisi.soyad,
          );

          if (mevcutKisi == null) {
            // Kişi ID'sini korumak için özel ekleme
            // Alan tarafta kaydedilen kişilerin tarihini eski yap (bekleyen sıradan çıkar)
            final eskiTarihliKisi = guncellenmiKisi.copyWith(
              olusturmaTarihi: DateTime.now().subtract(const Duration(days: 2)),
            );
            await _veriTabani.kisiEkleIdIle(eskiTarihliKisi);
            basariliSayisi++;
            print(
              '✅ Kişi kaydedildi: ${guncellenmiKisi.ad} ${guncellenmiKisi.soyad}',
            );
          } else {
            // Kişi mevcut, güncelle
            final guncelKisi = guncellenmiKisi.copyWith(
              id: mevcutKisi.id, // Mevcut kişinin ID'sini koru
              olusturmaTarihi: DateTime.now().subtract(const Duration(days: 2)),
            );
            await _veriTabani.kisiGuncelle(guncelKisi);
            mevcutSayisi++;
            print(
              '🔄 Kişi güncellendi: ${guncellenmiKisi.ad} ${guncellenmiKisi.soyad}',
            );
          }
        } catch (e) {
          print('❌ Kişi kaydetme hatası: $e');
          hataliSayisi++;
        }
      }

      return json.encode({
        'success': true,
        'message': 'Kişi senkronizasyonu tamamlandı',
        'basarili': basariliSayisi,
        'guncellenen': mevcutSayisi,
        'hatali': hataliSayisi,
        'toplam': kisilerData.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kişi alma hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Kişiler kaydedilemedi',
        'message': e.toString(),
      });
    }
  }

  /// Bekleyen senkronizasyon kategorilerini döndür (GET)
  Future<String> _handleSyncKategoriler() async {
    try {
      print('📁 Senkronizasyon bekleyen kategoriler istendi');

      final kategoriler = await _veriTabani.kategorileriGetir();
      // Yeni eklenen kategorileri filtrele (örneğin son 24 saat)
      final bekleyenKategoriler =
          kategoriler
              .where(
                (kategori) => kategori.olusturmaTarihi.isAfter(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              )
              .toList();

      print('📊 ${bekleyenKategoriler.length} bekleyen kategori bulundu');

      final kategorilerJson =
          bekleyenKategoriler.map((kategori) => kategori.toMap()).toList();

      return json.encode({
        'success': true,
        'kategoriler': kategorilerJson,
        'toplam': bekleyenKategoriler.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kategori senkronizasyonu hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Kategoriler alınamadı',
        'message': e.toString(),
      });
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

      for (final kategoriData in kategorilerData) {
        try {
          final kategori = KategoriModeli.fromMap(kategoriData);
          // Alan tarafta kaydedilen kategorilerin tarihini eski yap (bekleyen sıradan çıkar)
          final eskiTarihliKategori = kategori.copyWith(
            olusturmaTarihi: DateTime.now().subtract(const Duration(days: 2)),
          );
          await _veriTabani.kategoriEkle(eskiTarihliKategori);
          basariliSayisi++;
          print('✅ Kategori kaydedildi: ${kategori.ad}');
        } catch (e) {
          print('❌ Kategori kaydetme hatası: $e');
          hataliSayisi++;
        }
      }

      return json.encode({
        'success': true,
        'message': 'Kategori senkronizasyonu tamamlandı',
        'basarili': basariliSayisi,
        'hatali': hataliSayisi,
        'toplam': kategorilerData.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Kategori alma hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Kategoriler kaydedilemedi',
        'message': e.toString(),
      });
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
      final bekleyenKisiler =
          kisiler
              .where(
                (kisi) => kisi.olusturmaTarihi.isAfter(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              )
              .length;

      final kategoriler = await _veriTabani.kategorileriGetir();
      final bekleyenKategoriler =
          kategoriler
              .where(
                (kategori) => kategori.olusturmaTarihi.isAfter(
                  DateTime.now().subtract(const Duration(days: 1)),
                ),
              )
              .length;

      return json.encode({
        'success': true,
        'bekleyen_belgeler': bekleyenBelgeler,
        'bekleyen_kisiler': bekleyenKisiler,
        'bekleyen_kategoriler': bekleyenKategoriler,
        'toplam_bekleyen':
            bekleyenBelgeler + bekleyenKisiler + bekleyenKategoriler,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Bekleyen senkronizasyon sorgu hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Bekleyen senkronizasyonlar sorgulanamadı',
        'message': e.toString(),
      });
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
      return json.encode({
        'success': false,
        'error': 'Senkronizasyon durumu sorgulanamadı',
        'message': e.toString(),
      });
    }
  }

  /// QR Login endpoint'i
  Future<String> _handleQRLogin(HttpRequest request) async {
    try {
      print('📱 QR Login istegi alindi');

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
      print('  - Kullanici: $kullaniciAdi');
      print('  - Token: $token');
      print('  - Device ID: $deviceId');
      print('  - Device Name: $deviceName');
      print('  - Platform: $platform');
      print('  - User Info: ${userInfo != null ? 'Mevcut' : 'Yok'}');

      if (kullaniciAdi == null || token == null) {
        print('❌ Eksik veri: kullanici_adi ve token gerekli');
        return json.encode({
          'success': false,
          'error': 'kullanici_adi ve token gerekli',
        });
      }

      // Kullanıcı bilgilerini kontrol et ve gerekirse otomatik kayıt yap
      if (userInfo != null) {
        print('👤 Kullanıcı bilgileri kontrol ediliyor...');
        await _ensureUserExists(userInfo);
      }

      // QR Login callback'ini çağır
      if (_onQRLoginRequest != null) {
        print('🔑 QR Login callback çağırılıyor: $kullaniciAdi');

        // Callback'i hemen çağır, microtask kullanma
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
      return json.encode({
        'success': false,
        'error': 'QR Login hatası',
        'message': e.toString(),
      });
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

      // Kullanıcı var mı kontrol et
      final existingUser = await _getUserByUsername(kullaniciAdi);

      if (existingUser == null) {
        print('➕ Kullanıcı bulunamadı, otomatik kayıt yapılıyor...');

        // Yeni kullanıcı oluştur
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

        // Cihaz bilgilerini kaydet
        await _registerDevice(kullaniciAdi, userInfo);
      } else {
        print('✅ Kullanıcı mevcut: $kullaniciAdi');

        // Mevcut kullanıcının bilgilerini güncelle (profil fotoğrafı vs.)
        final guncelKullanici = existingUser.copyWith(
          ad: userInfo['ad'] ?? existingUser.ad,
          soyad: userInfo['soyad'] ?? existingUser.soyad,
          profilFotografi:
              userInfo['profil_fotografi'] ?? existingUser.profilFotografi,
          guncellemeTarihi: DateTime.now(),
        );

        await _veriTabani.kisiGuncelle(guncelKullanici);
        print('✅ Kullanıcı bilgileri güncellendi: $kullaniciAdi');

        // Cihaz bilgilerini kaydet
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

      // Cihaz bilgilerini log olarak kaydet (şimdilik)
      // Daha sonra ayrı bir cihaz tablosu oluşturulabilir
      print('✅ Cihaz kaydedildi: $kullaniciAdi -> $deviceName');

      // Gelecekte burada cihaz tablosuna kayıt yapılabilir:
      // await _veriTabani.cihazEkle(deviceId, kullaniciAdi, deviceName, platform);

      // Çoklu cihaz desteği için cihaz bilgilerini sakla
      _bagliCihazlar.add({
        'device_id': deviceId,
        'kullanici_adi': kullaniciAdi,
        'device_name': deviceName,
        'platform': platform,
        'connection_time': DateTime.now().toIso8601String(),
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Cihaz kayıt hatası: $e');
    }
  }
}
