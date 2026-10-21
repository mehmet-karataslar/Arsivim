import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'veritabani_servisi.dart';
import 'http_sunucu_servisi.dart';
import '../utils/timestamp_manager.dart';
import '../utils/network_optimizer.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../widgets/senkronizasyon_progress_dialog.dart';
import 'log_servisi.dart';
import 'guvenli_aktarim_servisi.dart';
import 'aktarim_http.dart';
import 'depolama_konumu_servisi.dart';
import 'auth_servisi.dart';
import 'arsiv_hesap_servisi.dart';

class SenkronizasyonYoneticiServisi {
  static final SenkronizasyonYoneticiServisi _instance =
      SenkronizasyonYoneticiServisi._internal();
  static SenkronizasyonYoneticiServisi get instance => _instance;
  SenkronizasyonYoneticiServisi._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final LogServisi _logServisi = LogServisi.instance;
  final NetworkOptimizer _networkOptimizer = NetworkOptimizer.instance;

  final ValueNotifier<int> changes = ValueNotifier(0);
  void _changed() => changes.value++;
  void initializeConnections() => _httpSunucuCallbackleriKur();
  bool get transferRunning => _aktarimSuruyor;
  bool _stopRequested = false;
  void requestStop() {
    if (_aktarimSuruyor) {
      _stopRequested = true;
      _changed();
    }
  }
  Future<void> setServerRunning(bool running) async {
    if (_aktarimSuruyor) throw StateError('Aktarım sürerken sunucu durdurulamaz.');
    if (running) {
      await _httpSunucu.sunucuyuBaslat();
    } else {
      await tumBaglantilarinKes();
      await _httpSunucu.sunucuyuDurdur();
    }
    _sunucuCalisiyorMu = _httpSunucu.calisiyorMu;
    _durum = _sunucuCalisiyorMu ? 'Sunucu Aktif' : 'Sunucu Kapalı';
    _changed();
    onStatusChanged?.call(_durum);
  }

  // Durumlar
  bool _sunucuCalisiyorMu = false;
  bool _senkronizasyonAktif = false;
  bool _otomatikBaglantiKes = true; // Otomatik bağlantı kesme özelliği
  String _durum = 'Hazır';
  String _sonSenkronizasyon = 'Henüz yapılmadı';
  int _bekleyenDosyaSayisi = 0;
  int _senkronizeDosyaSayisi = 0;
  List<Map<String, dynamic>> _bagliCihazlar = [];

  /// Mobilde cache boyutunu sınırla
  int get _maxCacheSize => Platform.isAndroid || Platform.isIOS ? 10 : 50;

  // Getters
  bool get sunucuCalisiyorMu => _httpSunucu.calisiyorMu;
  bool get senkronizasyonAktif => _senkronizasyonAktif;
  bool get otomatikBaglantiKes => _otomatikBaglantiKes;
  String get durum => _durum;
  String get sonSenkronizasyon => _sonSenkronizasyon;
  int get bekleyenDosyaSayisi => _bekleyenDosyaSayisi;
  int get senkronizeDosyaSayisi => _senkronizeDosyaSayisi;
  List<Map<String, dynamic>> get bagliCihazlar =>
      List.unmodifiable(_bagliCihazlar);

  // Setters
  set otomatikBaglantiKes(bool value) => _otomatikBaglantiKes = value;

  // Event callbacks
  Function(String)? onStatusChanged;
  Function()? onDeviceListChanged;
  Function(String)? onSuccess;
  Function(String)? onError;
  Function(String, Map<String, dynamic>)? onDeviceConnected;

  // Progress stream kontrolcüsü
  StreamController<SenkronizasyonIlerleme>? _progressController;

  // HTTP sunucu callback'lerini kur
  void _httpSunucuCallbackleriKur() {
    _httpSunucu.baglantiCallbackleri(
      onDeviceConnected: (deviceInfo) {
        print('📱 PC\'ye yeni cihaz bağlandı: ${deviceInfo['device_name']}');

        // Cihaz bilgilerini düzgün format'a getir
        final formattedDeviceInfo = {
          'name': deviceInfo['device_name'] ?? 'Bilinmeyen Cihaz',
          'ip': deviceInfo['ip'] ?? 'Bilinmeyen IP',
          'platform': deviceInfo['platform'] ?? 'Bilinmeyen Platform',
          'device_id': deviceInfo['device_id'] ?? 'unknown',
          'connected_at': DateTime.now(),
          'connection_type': 'incoming',
          'status': 'connected',
          'online': true,
          'timestamp': DateTime.now().toIso8601String(),
        };

        print('📋 Formatlanmış cihaz bilgisi: $formattedDeviceInfo');

        // Cihazı listeye ekle
        final existingIndex = _bagliCihazlar.indexWhere(
          (device) => device['device_id'] == formattedDeviceInfo['device_id'],
        );

        if (existingIndex != -1) {
          // Mevcut cihazı güncelle
          _bagliCihazlar[existingIndex] = formattedDeviceInfo;
          print('🔄 Mevcut cihaz güncellendi: ${formattedDeviceInfo['name']}');
        } else {
          // Yeni cihaz ekle
          _bagliCihazlar.add(formattedDeviceInfo);
          print('➕ Yeni cihaz eklendi: ${formattedDeviceInfo['name']}');

          // Mobilde cache limitini aş
          _temizleCacheMemory();
        }

        // UI'yı güncelle
        _changed();
        onDeviceListChanged?.call();
        onDeviceConnected?.call(
          formattedDeviceInfo['name'],
          formattedDeviceInfo,
        );

        // Senkronizasyon log kaydı
        _logServisi.syncLog(
          'Cihaz Bağlandı: ${formattedDeviceInfo['name']}',
          'success',
          {
            'ip': formattedDeviceInfo['ip'],
            'platform': formattedDeviceInfo['platform'],
            'device_id': formattedDeviceInfo['device_id'],
          },
        );

        // Başarı mesajı göster
        onSuccess?.call(
          '✅ ${formattedDeviceInfo['name']} bağlandı!\n'
          'IP: ${formattedDeviceInfo['ip']}\n'
          'Platform: ${formattedDeviceInfo['platform']}',
        );
      },
      onDeviceDisconnected: (deviceId, disconnectionInfo) {
        print('📱 Cihaz ayrıldı: $deviceId');

        // Cihazı listeden çıkar
        final removedDevice = _bagliCihazlar.firstWhere(
          (device) => device['device_id'] == deviceId,
          orElse: () => <String, dynamic>{},
        );

        _bagliCihazlar.removeWhere((device) => device['device_id'] == deviceId);

        // UI'yı güncelle
        _changed();
        onDeviceListChanged?.call();

        // Senkronizasyon log kaydı
        if (removedDevice.isNotEmpty) {
          _logServisi.syncLog(
            'Cihaz Bağlantısı Kesildi: ${removedDevice['device_name']}',
            'disconnected',
            {
              'ip': removedDevice['ip'],
              'platform': removedDevice['platform'],
              'device_id': removedDevice['device_id'],
            },
          );
        }

        // Bildirim göster
        if (removedDevice.isNotEmpty) {
          onSuccess?.call(
            '👋 ${removedDevice['device_name']} bağlantısı kesildi',
          );
        }
      },
    );
  }

  Future<void> verileriYukle() async {
    try {
      // HTTP sunucu callback'lerini kur
      _httpSunucuCallbackleriKur();

      // Sunucu durumu
      _sunucuCalisiyorMu = _httpSunucu.calisiyorMu;

      // Senkronizasyon istatistikleri
      final belgeler = await _veriTabani.belgeleriGetir(
        limit: null,
        offset: null,
      );
      _bekleyenDosyaSayisi =
          belgeler
              .where(
                (b) =>
                    b.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                    b.senkronDurumu == SenkronDurumu.YEREL_DEGISIM,
              )
              .length;
      _senkronizeDosyaSayisi =
          belgeler
              .where((b) => b.senkronDurumu == SenkronDurumu.SENKRONIZE)
              .length;

      // Son senkronizasyon zamanı
      _sonSenkronizasyon = TimestampManager.instance
          .formatHumanReadableTimestamp(
            DateTime.now().subtract(const Duration(hours: 2)),
          );

      _durum = _sunucuCalisiyorMu ? 'Sunucu Aktif' : 'Sunucu Kapalı';
      onStatusChanged?.call(_durum);

      // Senkronizasyon verilerini yükleme log kaydı
      _logServisi.syncLog('Senkronizasyon Veriler Yüklendi', 'initialized', {
        'bekleyen_dosya_sayisi': _bekleyenDosyaSayisi,
        'senkronize_dosya_sayisi': _senkronizeDosyaSayisi,
        'sunucu_durumu': _sunucuCalisiyorMu ? 'aktif' : 'kapalı',
      });
    } catch (e) {
      _durum = 'Hata: $e';
      onError?.call(_durum);
    }
  }

  void sunucuToggle() {
    _sunucuCalisiyorMu = !_sunucuCalisiyorMu;
    _durum = _sunucuCalisiyorMu ? 'Sunucu Aktif' : 'Sunucu Kapalı';

    // Sunucu toggle log kaydı
    _logServisi.syncLog(
      _sunucuCalisiyorMu ? 'Sunucu Başlatıldı' : 'Sunucu Durduruldu',
      _sunucuCalisiyorMu ? 'started' : 'stopped',
    );

    onStatusChanged?.call(_durum);
    onSuccess?.call(
      _sunucuCalisiyorMu ? 'Sunucu başlatıldı' : 'Sunucu durduruldu',
    );
  }

  void senkronizasyonToggle() {
    _senkronizasyonAktif = !_senkronizasyonAktif;
    onStatusChanged?.call(_durum);
    onSuccess?.call(
      _senkronizasyonAktif
          ? 'Senkronizasyon başlatıldı'
          : 'Senkronizasyon durduruldu',
    );
  }

  void hizliSenkronizasyon() {
    // Hızlı senkronizasyon log kaydı
    _logServisi.syncLog('Hızlı Senkronizasyon', 'started');
    onSuccess?.call('Hızlı senkronizasyon başlatıldı');
  }

  Future<String> connectionDataOlustur() async {
    final bilet = await _httpSunucu.hesapEslesmesi.biletOlustur();
    if (!_httpSunucu.calisiyorMu) await _httpSunucu.sunucuyuBaslat();
    final ip = await _getRealIPAddress();
    print('📱 Connection data IP adresi: $ip');

    final connectionInfo = {
      ...bilet,
      'type': 'arsivim_connection',
      'transfer_version': GuvenliAktarimServisi.surum,
      'transfer_token': _httpSunucu.aktarimAnahtari,
      'version': '1.0',
      'device_id': _httpSunucu.cihazId ?? 'unknown',
      'device_name':
          Platform.isWindows || Platform.isLinux || Platform.isMacOS
              ? 'PC-Arşivim'
              : 'Mobile-Arşivim',
      'ip': ip,
      'port': 8080,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'platform': Platform.operatingSystem,
      'server_status': _sunucuCalisiyorMu,
    };

    return json.encode(connectionInfo);
  }

  Future<String> _getRealIPAddress() async {
    // HTTP sunucu servisinden gerçek IP adresini al
    final realIP = await _httpSunucu.getRealIPAddress();
    if (realIP == null)
      throw AktarimHatasi('AG', 'Yerel ag adresi bulunamadi.');
    return realIP;
  }

  Future<bool> yeniCihazBagla(Map<String, dynamic> connectionInfo) async {
    try {
      await AuthServisi.instance.hesapTanitim(yeniDogrulama: true);
      if (connectionInfo['account_version'] != 1 ||
          connectionInfo['pair_ticket'] is! String ||
          connectionInfo['pair_expires'] is! int ||
          DateTime.now().millisecondsSinceEpoch >=
              connectionInfo['pair_expires']) {
        throw HesapHatasi(
          'Hesap eslestirme kodu eski veya suresi dolmus. Iki cihazda yeni QR kullanin.',
        );
      }
      await (await AuthServisi.instance.hesapServisi).baglantiKontrol(
        AuthServisi.instance.currentUser!.id!,
        Map<String, dynamic>.from(connectionInfo['account'] as Map),
      );
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
    final token = connectionInfo['transfer_token'];
    if (connectionInfo['transfer_version'] != GuvenliAktarimServisi.surum ||
        token is! String ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(token)) {
      onError?.call('Iki cihazi da guncelleyip yeni QR koduyla eslestirin.');
      return false;
    }
    final ip = connectionInfo['ip'];
    if (ip is! String ||
        InternetAddress.tryParse(ip)?.type != InternetAddressType.IPv4 ||
        connectionInfo['port'] != 8080) {
      onError?.call('QR kodundaki ag adresi veya port gecersiz.');
      return false;
    }
    if (!_httpSunucu.calisiyorMu) await _httpSunucu.sunucuyuBaslat();
    _httpSunucu.eslesmisAnahtarlar[ip] = token;
    final deviceName = connectionInfo['device_name'] ?? 'Bilinmeyen Cihaz';
    final deviceId = connectionInfo['device_id'];
    final deviceIP = connectionInfo['ip'];
    final devicePort = connectionInfo['port'] ?? 8080;
    final pcPlatform =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    print('🔗 Yeni cihaz bağlantısı başlatılıyor:');
    print('  Device Name: $deviceName');
    print('  Device ID: $deviceId');
    print('  Device IP: $deviceIP');
    print('  Device Port: $devicePort');
    print('  PC Platform: $pcPlatform');

    // Aynı cihaz zaten bağlı mı kontrol et
    bool alreadyConnected = _bagliCihazlar.any(
      (cihaz) => cihaz['device_id'] == deviceId,
    );

    if (!alreadyConnected) {
      try {
        // Gerçek bağlantı testi yap
        bool connectionSuccessful = await _testConnection(deviceIP, devicePort);

        if (connectionSuccessful) {
          // Karşı tarafa bağlantı bildirimini gönder
          await _notifyConnection(deviceIP, devicePort, connectionInfo);

          // Yerel listeye ekle
          final newDevice = {
            'name': deviceName,
            'ip': deviceIP,
            'platform': connectionInfo['platform'] ?? 'Unknown',
            'connected_at': DateTime.now(),
            'device_id': deviceId,
            'connection_type': pcPlatform ? 'incoming' : 'outgoing',
            'status': 'connected',
            'online': true,
          };

          _bagliCihazlar.add(newDevice);

          _changed();
        onDeviceListChanged?.call();
          onDeviceConnected?.call(deviceName, newDevice);
          verileriYukle();

          return true;
        } else {
          _httpSunucu.eslesmisAnahtarlar.remove(ip);
          onError?.call('$deviceName cihazına bağlanılamadı');
          return false;
        }
      } catch (e) {
        _httpSunucu.eslesmisAnahtarlar.remove(ip);
        _httpSunucu.hesapEslesmesi.baglantiKes(ip);
        onError?.call('Bağlantı hatası: $e');
        return false;
      }
    } else {
      onError?.call('Bu cihaz zaten bağlı: $deviceName');
      return false;
    }
  }

  Future<bool> _testConnection(String ip, int port) async {
    try {
      _logServisi.info('🔍 Bağlantı testi başlatılıyor: http://$ip:$port/ping');

      // Network optimizer ile connection test
      final networkTestResult = await _networkOptimizer.testConnection(
        ip,
        port: port,
      );

      if (networkTestResult) {
        _logServisi.info('✅ Bağlantı testi başarılı: $ip:$port');
        return true;
      }

      // Fallback: Manual resilient request
      final response = await _networkOptimizer.resilientRequest(
        method: 'GET',
        url: 'http://$ip:$port/ping',
        headers: {'Connection': 'keep-alive'},
        maxRetries: 2,
        timeout: const Duration(seconds: 10),
      );

      final success = response.statusCode == 200;
      _logServisi.info(
        success
            ? '✅ Bağlantı testi sonucu: ${response.statusCode}'
            : '❌ Bağlantı testi başarısız: ${response.statusCode}',
      );

      return success;
    } catch (e) {
      _logServisi.error('❌ Bağlantı testi başarısız: $e');
      return false;
    }
  }

  Future<void> _notifyConnection(
    String ip,
    int port,
    Map<String, dynamic> connectionInfo,
  ) async {
    final session = AuthServisi.instance.sessionGeneration;
    final result = await AktarimHttp.jsonIstek(
      Uri.parse('http://$ip:$port/sync/v2/pair'),
      _httpSunucu.eslesmisAnahtarlar[ip]!,
      body: {
        'account_version': 1,
        'pair_ticket': connectionInfo['pair_ticket'],
        'account': await AuthServisi.instance.hesapTanitim(yeniDogrulama: true),
        'reverse_token': _httpSunucu.aktarimAnahtari,
        'device_id': _httpSunucu.cihazId,
        'device_name': _httpSunucu.cihazAdi ?? 'Arsivim',
        'platform': Platform.operatingSystem,
      },
    );
    if (result['success'] != true)
      throw AktarimHatasi(
        'ESLESME',
        result['error'] as String? ?? 'Cihaz eslestirilemedi.',
      );
    if (result['account_version'] != 1 ||
        session != AuthServisi.instance.sessionGeneration) {
      throw HesapHatasi(
        'Hesap oturumu veya karsi surum degisti. Yeniden eslestirin.',
      );
    }
    final remote = Map<String, dynamic>.from(result['account'] as Map);
    final expected = connectionInfo['account'] as Map;
    if (remote['arsiv_id'] != expected['arsiv_id'] ||
        remote['yonetici_id'] != expected['yonetici_id']) {
      throw HesapHatasi('QR hesabi ile karsi cihaz hesabi uyusmuyor.');
    }
    await _httpSunucu.hesapEslesmesi.karsiCihazaBaglanildi(ip, remote);
  }

  // PC tarafında gelen bağlantı bildirimini işle
  void handleIncomingConnection(Map<String, dynamic> deviceInfo) {
    final deviceName = deviceInfo['device_name'] ?? 'Bilinmeyen Cihaz';
    final deviceId = deviceInfo['device_id'];

    // Aynı cihaz zaten bağlı mı kontrol et
    bool alreadyConnected = _bagliCihazlar.any(
      (cihaz) => cihaz['device_id'] == deviceId,
    );

    if (!alreadyConnected) {
      final newDevice = {
        'name': deviceName,
        'ip': 'incoming', // Gelen bağlantı için
        'platform': deviceInfo['platform'] ?? 'Unknown',
        'connected_at': DateTime.now(),
        'device_id': deviceId,
        'connection_type': 'incoming',
        'status': 'connected',
        'online': true,
      };

      _bagliCihazlar.add(newDevice);

      _changed();
        onDeviceListChanged?.call();
      onDeviceConnected?.call(deviceName, newDevice);
      onSuccess?.call('$deviceName cihazı bağlandı');
    }
  }

  void cihazBaglantisiniKes(int index) {
    if (index >= 0 && index < _bagliCihazlar.length) {
      final device = _bagliCihazlar[index];

      // Karşı tarafa bağlantı kesimi bildirimini gönder
      _notifyDisconnection(device);

      _bagliCihazlar.removeAt(index);
      _changed();
        onDeviceListChanged?.call();
      onSuccess?.call('Cihaz bağlantısı kesildi');
    }
  }

  Future<void> _notifyDisconnection(Map<String, dynamic> device) async {
    final token = _httpSunucu.eslesmisAnahtarlar.remove(device['ip']);
    if (device['ip'] is String)
      _httpSunucu.hesapEslesmesi.baglantiKes(device['ip']);
    try {
      if (device['ip'] != null && device['ip'] != 'incoming') {
        _logServisi.info(
          '📡 Bağlantı kesimi bildirimi gönderiliyor: ${device['name']}',
        );

        final disconnectInfo = {
          'type': 'disconnection_notification',
          'device_id': _httpSunucu.cihazId,
          'message': 'Bağlantı kesildi',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        if (token != null) {
          await AktarimHttp.jsonIstek(
            Uri.parse('http://${device['ip']}:8080/sync/v2/disconnect'),
            token,
            body: disconnectInfo,
          );
        }

        _logServisi.info(
          '✅ Bağlantı kesimi bildirimi gönderildi: ${device['name']}',
        );
      }
    } catch (e) {
      _logServisi.warning('⚠️ Bağlantı kesimi bildirimi gönderilemedi: $e');
    }
  }

  void cihazaSenkronBaslat(Map<String, dynamic> cihaz) {
    // Async operasyonu Future.microtask ile çalıştır
    Future.microtask(() => cihazlaSenkronizasyonBaslat(cihaz));
  }

  Future<bool> qrKoduTarandi(String qrData) async {
    try {
      final connectionInfo = json.decode(qrData);

      if (connectionInfo['type'] == 'arsivim_connection') {
        print('✅ Geçerli Arşivim QR kodu, bağlantı başlatılıyor...');
        print(
          '📋 Bağlantı bilgileri: ${connectionInfo['device_name']} - ${connectionInfo['ip']}:${connectionInfo['port']}',
        );

        final success = await yeniCihazBagla(connectionInfo);

        if (success) {
          print('✅ Cihaz başarıyla bağlandı!');
          print('📊 Toplam bağlı cihaz sayısı: ${_bagliCihazlar.length}');

          onSuccess?.call(
            'Cihaz başarıyla bağlandı: ${connectionInfo['device_name']}',
          );
          return true;
        } else {
          print('❌ Cihaz bağlantısı başarısız!');
          onError?.call('Cihaz bağlantısı başarısız');
          return false;
        }
      } else {
        print('❌ Geçersiz QR kod formatı: ${connectionInfo['type']}');
        onError?.call('Geçersiz QR kod formatı');
        return false;
      }
    } catch (e) {
      print('❌ QR kod okunamadı: $e');
      onError?.call('QR kod okunamadı: $e');
      return false;
    }
  }

  // Senkronizasyon İşlemleri

  /// Bekleyen senkronizasyon verilerini getir
  Future<Map<String, dynamic>> bekleyenSenkronlariGetir() async {
    final belgeler = await _veriTabani.belgeleriGetir(
      limit: null,
      offset: null,
    );
    final kisiler = await _veriTabani.kisileriGetir();
    final kategoriler = await _veriTabani.kategorileriGetir();
    return {
      'bekleyen_belgeler': belgeler,
      'bekleyen_kisiler': kisiler,
      'bekleyen_kategoriler': kategoriler,
      'toplam_bekleyen': belgeler.length + kisiler.length + kategoriler.length,
    };
  }

  /// Progress stream oluştur
  Stream<SenkronizasyonIlerleme> createProgressStream() {
    _progressController?.close();
    _progressController = StreamController<SenkronizasyonIlerleme>();
    return _progressController!.stream;
  }

  /// Progress bildirimini gönder
  void _sendProgress(SenkronizasyonIlerleme ilerleme) {
    _progressController?.add(ilerleme);
  }

  Future<int?> Function(String mesaj, List<Map<String, dynamic>> adaylar)?
  onKisiSecimi;
  final List<Map<String, dynamic>> sonAktarimSonuclari = [];
  bool _aktarimSuruyor = false;

  Future<bool> belgeleriSenkronEtProgress(
    String hedefIP, {
    List<BelgeModeli>? belgeler,
  }) => belgeleriSenkronEt(hedefIP, belgeler: belgeler);

  Future<String> _aktarimAnahtari(String ip) async {
    await _httpSunucu.hesapEslesmesi.yetkiKontrol(ip);
    final token = _httpSunucu.eslesmisAnahtarlar[ip];
    if (token == null)
      throw AktarimHatasi(
        'ESLESME',
        'Iki cihazi da guncelleyip QR koduyla yeniden eslestirin.',
      );
    final result = await AktarimHttp.jsonIstek(
      Uri.parse('http://$ip:8080/sync/v2/capabilities'),
      token,
    );
    if (result['surum'] != GuvenliAktarimServisi.surum ||
        result['success'] != true) {
      throw AktarimHatasi(
        'SURUM',
        'Karsi cihaz guvenli aktarimi desteklemiyor veya eslesme suresi doldu.',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _onKontrol(
    String ip,
    String token,
    Map<String, dynamic> paket,
  ) async {
    await _httpSunucu.hesapEslesmesi.yetkiKontrol(ip);
    var result = await AktarimHttp.jsonIstek(
      Uri.parse('http://$ip:8080/sync/v2/prepare'),
      token,
      body: paket,
    );
    if (result['kod'] == 'KISI_SECIMI' && onKisiSecimi != null) {
      final secim = await onKisiSecimi!(
        result['error'] as String,
        (result['adaylar'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList(),
      );
      if (secim != null) {
        paket['hedef_kisi_id'] = secim;
        result = await AktarimHttp.jsonIstek(
          Uri.parse('http://$ip:8080/sync/v2/prepare'),
          token,
          body: paket,
        );
      }
    }
    return result;
  }

  Future<bool> belgeleriSenkronEt(
    String hedefIP, {
    List<BelgeModeli>? belgeler,
  }) async {
    if (_aktarimSuruyor) {
      onError?.call('Bir aktarim zaten devam ediyor.');
      return false;
    }
    _aktarimSuruyor = true;
    _stopRequested = false;
    _changed();
    sonAktarimSonuclari.clear();
    var basarili = 0;
    try {
      final token = await _aktarimAnahtari(hedefIP);
      // Senkron durumu bir cihaz icin onaydir; yeni hedef icin tum belgeler denetlenir.
      belgeler ??= await _veriTabani.belgeleriGetir(limit: null, offset: null);
      final db = await _veriTabani.database;
      final servis = GuvenliAktarimServisi(
        db,
        await DepolamaKonumuServisi.instance.belgelerKlasoru(),
      );
      for (var i = 0; i < belgeler.length; i++) {
        if (_stopRequested) break;
        final belge = belgeler[i];
        _sendProgress(
          SenkronizasyonIlerleme(
            asama: SenkronizasyonAsamasi.belgelerGonderiliyor,
            aciklama: belge.orijinalDosyaAdi,
            toplamIslem: belgeler.length,
            tamamlananIslem: i,
          ),
        );
        try {
          final paket = await servis.paketOlustur(belge.id!);
          final kontrol = await _onKontrol(hedefIP, token, paket);
          if (kontrol['success'] != true) {
            throw AktarimHatasi(
              kontrol['kod'] as String? ?? 'KONTROL',
              kontrol['error'] as String? ?? 'On kontrol basarisiz.',
            );
          }
          await _httpSunucu.hesapEslesmesi.yetkiKontrol(hedefIP);
          final yanit = await AktarimHttp.gonder(
            Uri.parse('http://$hedefIP:8080/sync/v2/file'),
            token,
            paket,
            File(belge.dosyaYolu),
          );
          if (!GuvenliAktarimServisi.onayGecerli(paket, yanit)) {
            throw AktarimHatasi(
              yanit['kod'] as String? ?? 'ONAY',
              yanit['error'] as String? ??
                  'Alici dogrulanmis dosya onayi vermedi.',
            );
          }
          await servis.gonderimiOnayla(belge.id!, paket, yanit);
          basarili++;
          sonAktarimSonuclari.add({
            'dosya': belge.orijinalDosyaAdi,
            'durum': yanit['durum'],
            'hash': belge.dosyaHash,
          });
        } catch (e) {
          sonAktarimSonuclari.add({
            'dosya': belge.orijinalDosyaAdi,
            'durum': 'hata',
            'mesaj': e.toString(),
          });
        }
      }
      final hatalar = sonAktarimSonuclari.length - basarili;
      final stopped = _stopRequested && sonAktarimSonuclari.length < belgeler.length;
      final mesaj = stopped
          ? 'Aktarım durduruldu. $basarili dosya doğrulandı; kalan dosyalar gönderilmedi.'
          : '$basarili dosya doğrulandı, $hatalar dosya aktarılamadı.';
      final logs = await DepolamaKonumuServisi.instance.logKlasoru();
      await File(
        path.join(
          logs.path,
          'aktarim-${DateTime.now().microsecondsSinceEpoch}.json',
        ),
      ).writeAsString(
        jsonEncode({'hedef': hedefIP, 'sonuclar': sonAktarimSonuclari}),
        flush: true,
      );
      _sendProgress(
        SenkronizasyonIlerleme(
          asama:
              hatalar == 0 && !stopped
                  ? SenkronizasyonAsamasi.tamamlandi
                  : SenkronizasyonAsamasi.hata,
          aciklama: mesaj,
          toplamIslem: belgeler.length,
          tamamlananIslem: basarili,
          hataMesaji:
              hatalar == 0
                  ? null
                  : sonAktarimSonuclari
                      .where((r) => r['durum'] == 'hata')
                      .take(5)
                      .map((r) => '${r['dosya']}: ${r['mesaj']}')
                      .join('\n'),
        ),
      );
      if (hatalar == 0) {
        onSuccess?.call(mesaj);
      } else {
        onError?.call(
          '$mesaj\n${sonAktarimSonuclari.where((r) => r['durum'] == 'hata').take(3).map((r) => '${r['dosya']}: ${r['mesaj']}').join('\n')}',
        );
      }
      if (hatalar == 0 && !stopped && _otomatikBaglantiKes) {
        await _otomatikBaglantiKes_Func(hedefIP);
      }
      return hatalar == 0 && !stopped;
    } catch (e) {
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.hata,
          aciklama: 'Aktarim tamamlanamadi',
          hataMesaji: e.toString(),
        ),
      );
      onError?.call(e.toString());
      return false;
    } finally {
      _aktarimSuruyor = false;
      _changed();
    }
  }

  Future<bool> kisileriSenkronEt(
    String hedefIP, {
    List<KisiModeli>? kisiler,
  }) async => _referanslariGonder(
    hedefIP,
    'kisi',
    (kisiler ?? await _veriTabani.kisileriGetir()).map((k) => k.id!).toList(),
  );

  Future<bool> kategorileriSenkronEt(
    String hedefIP, {
    List<KategoriModeli>? kategoriler,
  }) async => _referanslariGonder(
    hedefIP,
    'kategori',
    (kategoriler ?? await _veriTabani.kategorileriGetir())
        .map((k) => k.id!)
        .toList(),
  );

  Future<bool> _referanslariGonder(String ip, String tur, List<int> ids) async {
    try {
      final token = await _aktarimAnahtari(ip);
      final servis = GuvenliAktarimServisi(
        await _veriTabani.database,
        await DepolamaKonumuServisi.instance.belgelerKlasoru(),
      );
      for (final id in ids) {
        await _httpSunucu.hesapEslesmesi.yetkiKontrol(ip);
        final paket = await servis.referansPaketi(tur, id);
        var result = await AktarimHttp.jsonIstek(
          Uri.parse('http://$ip:8080/sync/v2/entity'),
          token,
          body: paket,
        );
        if (result['kod'] == 'KISI_SECIMI' && onKisiSecimi != null) {
          final secim = await onKisiSecimi!(
            result['error'] as String,
            (result['adaylar'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList(),
          );
          if (secim != null) {
            paket['hedef_kisi_id'] = secim;
            result = await AktarimHttp.jsonIstek(
              Uri.parse('http://$ip:8080/sync/v2/entity'),
              token,
              body: paket,
            );
          }
        }
        if (result['success'] != true ||
            result['metadata_hash'] != paket['metadata_hash']) {
          throw AktarimHatasi(
            'REFERANS',
            result['error'] as String? ?? 'Kayit aktarimi dogrulanamadi.',
          );
        }
      }
      onSuccess?.call('${ids.length} $tur kaydi dogrulandi.');
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  Future<bool> tumSenkronizasyonuBaslat(String hedefIP) =>
      belgeleriSenkronEt(hedefIP);

  Future<bool> tumSistemiSenkronEt(String hedefIP) async {
    final kisiler = await kisileriSenkronEt(hedefIP);
    final kategoriler = await kategorileriSenkronEt(hedefIP);
    final belgeler = await belgeleriSenkronEt(hedefIP);
    return kisiler && kategoriler && belgeler;
  }

  /// Otomatik bağlantı kesme işlemi
  Future<void> _otomatikBaglantiKes_Func(String hedefIP) async {
    try {
      print('🔌 Otomatik bağlantı kesme başlatılıyor...');

      // Bağlı cihazlardan IP'si eşleşen cihazı bul
      final cihaz = _bagliCihazlar.firstWhere(
        (device) => device['ip'] == hedefIP,
        orElse: () => <String, dynamic>{},
      );

      if (cihaz.isNotEmpty) {
        await cihazBaglantiKes(cihaz['device_id']);
        onSuccess?.call('✅ Bağlantı otomatik olarak kesildi');
      }
    } catch (e) {
      print('❌ Otomatik bağlantı kesme hatası: $e');
    }
  }

  /// Manuel bağlantı kesme
  Future<bool> cihazBaglantiKes(String deviceId) async {
    try {
      print('🔌 Cihaz bağlantısı kesiliyor: $deviceId');

      // Cihazı bağlı cihazlar listesinden çıkar
      final removedDevice = _bagliCihazlar.firstWhere(
        (device) => device['device_id'] == deviceId,
        orElse: () => <String, dynamic>{},
      );

      if (removedDevice.isEmpty) {
        onError?.call('Cihaz bulunamadı');
        return false;
      }

      // Listeden kaldır
      _bagliCihazlar.removeWhere((device) => device['device_id'] == deviceId);
      await _notifyDisconnection(removedDevice);

      // UI'yı güncelle
      _changed();
        onDeviceListChanged?.call();

      // Log kaydı
      _logServisi.syncLog(
        'Manuel Bağlantı Kesildi: ${removedDevice['name']}',
        'disconnected',
        {
          'ip': removedDevice['ip'],
          'platform': removedDevice['platform'],
          'device_id': removedDevice['device_id'],
          'disconnect_type': 'manual',
        },
      );

      onSuccess?.call('👋 ${removedDevice['name']} bağlantısı kesildi');
      return true;
    } catch (e) {
      print('❌ Cihaz bağlantısı kesme hatası: $e');
      onError?.call('Bağlantı kesme hatası: $e');
      return false;
    }
  }

  /// Tüm bağlantıları kes
  Future<bool> tumBaglantilarinKes() async {
    try {
      print('🔌 Tüm bağlantılar kesiliyor...');

      final bagliBaglantiSayisi = _bagliCihazlar.length;

      if (bagliBaglantiSayisi == 0) {
        onSuccess?.call('Bağlı cihaz yok');
        return true;
      }

      final devices = List<Map<String, dynamic>>.from(_bagliCihazlar);
      final notifications = devices.map(_notifyDisconnection).toList();
      _httpSunucu.eslesmisAnahtarlar.clear();
      _httpSunucu.hesapEslesmesi.temizle();
      // Tüm cihazları kaldır
      _bagliCihazlar.clear();
      await Future.wait(notifications);

      // UI'yı güncelle
      _changed();
        onDeviceListChanged?.call();

      // Log kaydı
      _logServisi.syncLog('Tüm Bağlantılar Kesildi', 'disconnected', {
        'disconnected_count': bagliBaglantiSayisi,
        'disconnect_type': 'manual_all',
      });

      onSuccess?.call('🔌 $bagliBaglantiSayisi cihazın bağlantısı kesildi');
      return true;
    } catch (e) {
      print('❌ Tüm bağlantıları kesme hatası: $e');
      onError?.call('Bağlantı kesme hatası: $e');
      return false;
    }
  }

  /// Belirli bir cihazla senkronizasyon başlat
  Future<bool> cihazlaSenkronizasyonBaslat(Map<String, dynamic> cihaz) async {
    try {
      final cihazIP = cihaz['ip'] as String;
      final cihazAdi = cihaz['name'] as String;

      if (cihazIP == 'incoming') {
        onError?.call('Gelen bağlantı cihazlarına senkronizasyon gönderilemez');
        return false;
      }

      print('🔄 $cihazAdi ile senkronizasyon başlatılıyor...');
      onSuccess?.call('$cihazAdi ile senkronizasyon başlatıldı...');

      final basarili = await tumSenkronizasyonuBaslat(cihazIP);

      if (basarili) {
        onSuccess?.call('$cihazAdi ile senkronizasyon tamamlandı');
      } else {
        onError?.call('$cihazAdi ile senkronizasyon başarısız');
      }

      return basarili;
    } catch (e) {
      print('❌ Cihaz senkronizasyonu hatası: $e');
      onError?.call('Cihaz senkronizasyonu hatası: $e');
      return false;
    }
  }

  /// Cache memory temizleme (mobilde performance için)
  void _temizleCacheMemory() {
    // Bağlı cihazlar listesini sınırla
    if (_bagliCihazlar.length > _maxCacheSize) {
      // Eski cihazları kaldır (5 dakikadan eski olanlar)
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
      _bagliCihazlar.removeWhere((cihaz) {
        final connectedAt = cihaz['connected_at'] as DateTime?;
        return connectedAt != null && connectedAt.isBefore(cutoffTime);
      });

      // Hala çok fazlaysa en eskilerini kaldır
      if (_bagliCihazlar.length > _maxCacheSize) {
        _bagliCihazlar.sort((a, b) {
          final aTime = a['connected_at'] as DateTime? ?? DateTime.now();
          final bTime = b['connected_at'] as DateTime? ?? DateTime.now();
          return bTime.compareTo(aTime); // Yeni olanları başa al
        });
        _bagliCihazlar = _bagliCihazlar.take(_maxCacheSize).toList();
      }
    }
  }

  void dispose() {
    onKisiSecimi = null;
    onStatusChanged = null;
    onDeviceListChanged = null;
    onSuccess = null;
    onError = null;
    onDeviceConnected = null;
    _progressController?.close();
    _progressController = null;
  }
}
