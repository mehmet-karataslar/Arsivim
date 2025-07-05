import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'veritabani_servisi.dart';
import 'http_sunucu_servisi.dart';
import 'dosya_servisi.dart';
import '../utils/timestamp_manager.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../widgets/senkronizasyon_progress_dialog.dart';
import 'log_servisi.dart';

class SenkronizasyonYoneticiServisi {
  static final SenkronizasyonYoneticiServisi _instance =
      SenkronizasyonYoneticiServisi._internal();
  static SenkronizasyonYoneticiServisi get instance => _instance;
  SenkronizasyonYoneticiServisi._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final LogServisi _logServisi = LogServisi.instance;

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
  bool get sunucuCalisiyorMu => _sunucuCalisiyorMu;
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
      final belgeler = await _veriTabani.belgeleriGetir();
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
    final ip = await _getRealIPAddress();
    print('📱 Connection data IP adresi: $ip');

    final connectionInfo = {
      'type': 'arsivim_connection',
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

    print('📋 Connection info: ${json.encode(connectionInfo)}');
    return json.encode(connectionInfo);
  }

  Future<String> _getRealIPAddress() async {
    // HTTP sunucu servisinden gerçek IP adresini al
    final realIP = await _httpSunucu.getRealIPAddress();
    return realIP ?? '192.168.1.100'; // Fallback IP
  }

  Future<bool> yeniCihazBagla(Map<String, dynamic> connectionInfo) async {
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
          await _notifyConnection(deviceIP, devicePort, deviceName);

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

          onDeviceListChanged?.call();
          onDeviceConnected?.call(deviceName, newDevice);
          verileriYukle();

          return true;
        } else {
          onError?.call('$deviceName cihazına bağlanılamadı');
          return false;
        }
      } catch (e) {
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
      print('🔍 Bağlantı testi başlatılıyor: http://$ip:$port/ping');
      final response = await http
          .get(
            Uri.parse('http://$ip:$port/ping'),
            headers: {'Connection': 'keep-alive'},
          )
          .timeout(const Duration(seconds: 5));

      print('✅ Bağlantı testi sonucu: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Bağlantı testi başarısız: $e');
      return false;
    }
  }

  Future<void> _notifyConnection(String ip, int port, String deviceName) async {
    try {
      print('📡 $deviceName\'e bağlantı bildirimi gönderiliyor...');

      final myInfo = {
        'type': 'connection_notification',
        'device_id': _httpSunucu.cihazId,
        'device_name':
            Platform.isWindows || Platform.isLinux || Platform.isMacOS
                ? 'PC-Arşivim'
                : 'Mobile-Arşivim',
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Yeni cihaz bağlandı',
      };

      print('📋 Gönderilen bilgi: ${json.encode(myInfo)}');

      final response = await http
          .post(
            Uri.parse('http://$ip:$port/device-connected'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(myInfo),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Bağlantı bildirimi $deviceName\'e gönderildi');
        final responseData = json.decode(response.body);
        print('📋 Hedef cihazın cevabı: ${responseData['message']}');
      } else {
        print('❌ Bağlantı bildirimi hatası: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Bağlantı bildirimi gönderilemedi: $e');
    }
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
      onDeviceListChanged?.call();
      onSuccess?.call('Cihaz bağlantısı kesildi');
    }
  }

  Future<void> _notifyDisconnection(Map<String, dynamic> device) async {
    try {
      if (device['ip'] != null && device['ip'] != 'incoming') {
        final disconnectInfo = {
          'type': 'disconnection_notification',
          'device_id': _httpSunucu.cihazId,
          'message': 'Bağlantı kesildi',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        await http
            .post(
              Uri.parse('http://${device['ip']}:8080/device-disconnected'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(disconnectInfo),
            )
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      print('Bağlantı kesimi bildirimi gönderilemedi: $e');
    }
  }

  void cihazaSenkronBaslat(Map<String, dynamic> cihaz) {
    // Async operasyonu Future.microtask ile çalıştır
    Future.microtask(() => cihazlaSenkronizasyonBaslat(cihaz));
  }

  Future<bool> qrKoduTarandi(String qrData) async {
    try {
      print('📷 QR kod tarandı (Yönetici): $qrData');
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
    try {
      final belgeler = await _veriTabani.belgeleriGetir();
      final bekleyenBelgeler =
          belgeler
              .where(
                (belge) =>
                    belge.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                    belge.senkronDurumu == SenkronDurumu.YEREL_DEGISIM,
              )
              .toList();

      final kisiler = await _veriTabani.kisileriGetir();
      // TÜM KİŞİLERİ BEKLEYENCİ OLARAK GÖNDER - Transfer sorunu çözümü
      final bekleyenKisiler = kisiler; // Tüm kişiler senkronize edilsin

      final kategoriler = await _veriTabani.kategorileriGetir();
      // TÜM KATEGORİLERİ BEKLEYENCİ OLARAK GÖNDER - Transfer sorunu çözümü
      final bekleyenKategoriler =
          kategoriler; // Tüm kategoriler senkronize edilsin

      return {
        'bekleyen_belgeler': bekleyenBelgeler,
        'bekleyen_kisiler': bekleyenKisiler,
        'bekleyen_kategoriler': bekleyenKategoriler,
        'toplam_bekleyen':
            bekleyenBelgeler.length +
            bekleyenKisiler.length +
            bekleyenKategoriler.length,
      };
    } catch (e) {
      print('❌ Bekleyen senkronizasyonlar getirilemedi: $e');
      throw Exception('Bekleyen senkronizasyonlar getirilemedi: $e');
    }
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

  /// Belgeleri hedef cihaza senkronize et (Progress desteği ile)
  Future<bool> belgeleriSenkronEtProgress(
    String hedefIP, {
    List<BelgeModeli>? belgeler,
  }) async {
    try {
      print('📄 Gelişmiş belge senkronizasyonu başlatılıyor...');

      // Eğer belgeler verilmemişse, bekleyen belgeleri al
      if (belgeler == null) {
        final bekleyenler = await bekleyenSenkronlariGetir();
        belgeler = bekleyenler['bekleyen_belgeler'] as List<BelgeModeli>;
      }

      if (belgeler.isEmpty) {
        _sendProgress(
          SenkronizasyonIlerleme(
            asama: SenkronizasyonAsamasi.tamamlandi,
            aciklama: 'Senkronize edilecek belge yok',
          ),
        );
        onSuccess?.call('Senkronize edilecek belge yok');
        return true;
      }

      // 1. Bağımlılık analizi
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.bagimlilikAnaliz,
          aciklama: 'Belge bağımlılıkları analiz ediliyor...',
          toplamIslem: 4,
          tamamlananIslem: 1,
        ),
      );

      final dependencyPaketi = await _belgeBagimlilikCozumle(belgeler);

      print('📊 Bağımlılık analizi tamamlandı:');
      print('   • Belgeler: ${dependencyPaketi['belgeler'].length}');
      print('   • Kişiler: ${dependencyPaketi['kisiler'].length}');
      print('   • Kategoriler: ${dependencyPaketi['kategoriler'].length}');

      // 2. Kategoriler gönderiliyor
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.kategorilerGonderiliyor,
          aciklama: 'Kategoriler hazırlanıyor...',
          toplamIslem: 4,
          tamamlananIslem: 2,
        ),
      );

      // 3. Kişiler gönderiliyor
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.kisilerGonderiliyor,
          aciklama: 'Kişiler hazırlanıyor...',
          toplamIslem: 4,
          tamamlananIslem: 3,
        ),
      );

      // 4. Belgeler gönderiliyor
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.belgelerGonderiliyor,
          aciklama: 'Belgeler ve dosyalar gönderiliyor...',
          toplamIslem: 4,
          tamamlananIslem: 4,
        ),
      );

      // Dependency-aware senkronizasyon paketi oluştur
      final senkronPaketi = await _senkronizasyonPaketiOlustur(
        dependencyPaketi,
      );

      // Hedef cihaza gönder
      final response = await http
          .post(
            Uri.parse('http://$hedefIP:8080/sync/belgeler-kapsamli'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(senkronPaketi),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          // Senkronize edilen belgelerin durumunu güncelle
          for (final belge in belgeler) {
            final guncellenmis = belge.copyWith(
              senkronDurumu: SenkronDurumu.SENKRONIZE,
            );
            await _veriTabani.belgeGuncelle(guncellenmis);
          }

          final sonuc = responseData['sonuc'];

          // Başarı progress'i gönder
          _sendProgress(
            SenkronizasyonIlerleme(
              asama: SenkronizasyonAsamasi.tamamlandi,
              aciklama: 'Senkronizasyon başarıyla tamamlandı!',
              toplamIslem: 4,
              tamamlananIslem: 4,
              detaylar: {
                'kategoriler_eklendi': sonuc['kategoriler_eklendi'] ?? 0,
                'kisiler_eklendi': sonuc['kisiler_eklendi'] ?? 0,
                'belgeler_eklendi': sonuc['belgeler_eklendi'] ?? 0,
                'hatalar': sonuc['hatalar'] ?? 0,
              },
            ),
          );

          onSuccess?.call(
            'Senkronizasyon tamamlandı!\n'
            '• ${sonuc['belgeler_eklendi']} belge eklendi\n'
            '• ${sonuc['kisiler_eklendi']} kişi eklendi\n'
            '• ${sonuc['kategoriler_eklendi']} kategori eklendi',
          );
          return true;
        } else {
          _sendProgress(
            SenkronizasyonIlerleme(
              asama: SenkronizasyonAsamasi.hata,
              aciklama: 'Senkronizasyon hatası oluştu',
              hataMesaji: responseData['error'],
            ),
          );
          onError?.call('Senkronizasyon hatası: ${responseData['error']}');
          return false;
        }
      } else {
        _sendProgress(
          SenkronizasyonIlerleme(
            asama: SenkronizasyonAsamasi.hata,
            aciklama: 'Sunucu hatası',
            hataMesaji: 'HTTP ${response.statusCode}',
          ),
        );
        onError?.call('Senkronizasyon başarısız: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Belge senkronizasyonu hatası: $e');
      _sendProgress(
        SenkronizasyonIlerleme(
          asama: SenkronizasyonAsamasi.hata,
          aciklama: 'Beklenmeyen hata oluştu',
          hataMesaji: e.toString(),
        ),
      );
      onError?.call('Belge senkronizasyonu hatası: $e');
      return false;
    }
  }

  /// Belgeleri hedef cihaza senkronize et (Dependency-Aware)
  Future<bool> belgeleriSenkronEt(
    String hedefIP, {
    List<BelgeModeli>? belgeler,
  }) async {
    try {
      print('📄 Gelişmiş belge senkronizasyonu başlatılıyor...');

      // Eğer belgeler verilmemişse, bekleyen belgeleri al
      if (belgeler == null) {
        final bekleyenler = await bekleyenSenkronlariGetir();
        belgeler = bekleyenler['bekleyen_belgeler'] as List<BelgeModeli>;
      }

      if (belgeler.isEmpty) {
        onSuccess?.call('Senkronize edilecek belge yok');
        return true;
      }

      // 1. Belge bağımlılıklarını çözümle
      final dependencyPaketi = await _belgeBagimlilikCozumle(belgeler);

      print('📊 Bağımlılık analizi tamamlandı:');
      print('   • Belgeler: ${dependencyPaketi['belgeler'].length}');
      print('   • Kişiler: ${dependencyPaketi['kisiler'].length}');
      print('   • Kategoriler: ${dependencyPaketi['kategoriler'].length}');

      // 2. Dependency-aware senkronizasyon paketi oluştur
      final senkronPaketi = await _senkronizasyonPaketiOlustur(
        dependencyPaketi,
      );

      // 3. Hedef cihaza gönder
      final response = await http
          .post(
            Uri.parse('http://$hedefIP:8080/sync/belgeler-kapsamli'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(senkronPaketi),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          // Senkronize edilen belgelerin durumunu güncelle
          for (final belge in belgeler) {
            final guncellenmis = belge.copyWith(
              senkronDurumu: SenkronDurumu.SENKRONIZE,
            );
            await _veriTabani.belgeGuncelle(guncellenmis);
          }

          final sonuc = responseData['sonuc'];

          // Senkronizasyon log kaydı - başarı
          _logServisi.syncLog('Belgeler Senkronize Edildi', 'success', {
            'belgeler_eklendi': sonuc['belgeler_eklendi'] ?? 0,
            'kisiler_eklendi': sonuc['kisiler_eklendi'] ?? 0,
            'kategoriler_eklendi': sonuc['kategoriler_eklendi'] ?? 0,
            'hedef_ip': hedefIP,
            'belge_sayisi': belgeler.length,
          });

          onSuccess?.call(
            'Senkronizasyon tamamlandı!\n'
            '• ${sonuc['belgeler_eklendi']} belge eklendi\n'
            '• ${sonuc['kisiler_eklendi']} kişi eklendi\n'
            '• ${sonuc['kategoriler_eklendi']} kategori eklendi',
          );
          return true;
        } else {
          // Senkronizasyon log kaydı - hata
          _logServisi.syncLog('Belgeler Senkronize Edilemedi', 'error', {
            'error': responseData['error'],
            'hedef_ip': hedefIP,
            'belge_sayisi': belgeler.length,
          });
          onError?.call('Senkronizasyon hatası: ${responseData['error']}');
          return false;
        }
      } else {
        // Senkronizasyon log kaydı - HTTP hatası
        _logServisi.syncLog('Senkronizasyon Sunucu Hatası', 'error', {
          'status_code': response.statusCode,
          'hedef_ip': hedefIP,
          'belge_sayisi': belgeler.length,
        });
        onError?.call('Senkronizasyon başarısız: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Belge senkronizasyonu hatası: $e');
      onError?.call('Belge senkronizasyonu hatası: $e');
      return false;
    }
  }

  /// Belge bağımlılıklarını çözümle (kişi ve kategori)
  Future<Map<String, dynamic>> _belgeBagimlilikCozumle(
    List<BelgeModeli> belgeler,
  ) async {
    print('🔍 Belge bağımlılıkları analiz ediliyor...');

    final gerekliKisiIdleri = <int>{};
    final gerekliKategoriIdleri = <int>{};

    // Belgelerin bağımlılıklarını topla
    for (final belge in belgeler) {
      if (belge.kisiId != null) {
        gerekliKisiIdleri.add(belge.kisiId!);
      }
      if (belge.kategoriId != null) {
        gerekliKategoriIdleri.add(belge.kategoriId!);
      }
    }

    print('📋 Gerekli kişi ID\'leri: ${gerekliKisiIdleri.toList()}');
    print('📋 Gerekli kategori ID\'leri: ${gerekliKategoriIdleri.toList()}');

    // Kişi ve kategori verilerini al
    final kisiler = <KisiModeli>[];
    final kategoriler = <KategoriModeli>[];

    // Kişileri getir
    for (final kisiId in gerekliKisiIdleri) {
      try {
        final kisi = await _veriTabani.kisiGetir(kisiId);
        if (kisi != null) {
          kisiler.add(kisi);
          print('👤 Kişi eklendi: ${kisi.ad} ${kisi.soyad}');
        } else {
          print('⚠️ Kişi bulunamadı: ID $kisiId');
        }
      } catch (e) {
        print('❌ Kişi getirme hatası: $e');
      }
    }

    // Kategorileri getir
    for (final kategoriId in gerekliKategoriIdleri) {
      try {
        final kategori = await _veriTabani.kategoriGetir(kategoriId);
        if (kategori != null) {
          kategoriler.add(kategori);
          print('📁 Kategori eklendi: ${kategori.ad}');
        } else {
          print('⚠️ Kategori bulunamadı: ID $kategoriId');
        }
      } catch (e) {
        print('❌ Kategori getirme hatası: $e');
      }
    }

    return {
      'belgeler': belgeler,
      'kisiler': kisiler,
      'kategoriler': kategoriler,
    };
  }

  /// Senkronizasyon paketi oluştur
  Future<Map<String, dynamic>> _senkronizasyonPaketiOlustur(
    Map<String, dynamic> dependencyPaketi,
  ) async {
    print('📦 Senkronizasyon paketi oluşturuluyor...');

    final belgeler = dependencyPaketi['belgeler'] as List<BelgeModeli>;
    final kisiler = dependencyPaketi['kisiler'] as List<KisiModeli>;
    final kategoriler = dependencyPaketi['kategoriler'] as List<KategoriModeli>;

    // Belgeleri hazırla (dosya içeriği ile)
    final belgelerJson = [];
    for (final belge in belgeler) {
      final belgeMap = belge.toMap();

      // Dosya içeriğini base64 olarak ekle
      try {
        final dosyaBytes = File(belge.dosyaYolu).readAsBytesSync();
        belgeMap['dosya_icerigi'] = base64Encode(dosyaBytes);
        print(
          '📄 Belge hazırlandı: ${belge.dosyaAdi} (${dosyaBytes.length} bytes)',
        );
      } catch (e) {
        print('⚠️ Dosya okunamadı: ${belge.dosyaAdi} - $e');
        belgeMap['dosya_icerigi'] = null;
      }

      belgelerJson.add(belgeMap);
    }

    // Kişileri hazırla
    final kisilerJson = kisiler.map((kisi) => kisi.toMap()).toList();

    // Kategorileri hazırla
    final kategorilerJson =
        kategoriler.map((kategori) => kategori.toMap()).toList();

    return {
      'belgeler': belgelerJson,
      'kisiler': kisilerJson,
      'kategoriler': kategorilerJson,
      'timestamp': DateTime.now().toIso8601String(),
      'dependency_resolution': true,
    };
  }

  /// Kişileri hedef cihaza senkronize et
  Future<bool> kisileriSenkronEt(
    String hedefIP, {
    List<KisiModeli>? kisiler,
  }) async {
    try {
      print('👤 Kişi senkronizasyonu başlatılıyor...');

      // Eğer kişiler verilmemişse, bekleyen kişileri al
      if (kisiler == null) {
        final bekleyenler = await bekleyenSenkronlariGetir();
        kisiler =
            (bekleyenler['bekleyen_kisiler'] as List<dynamic>?)
                ?.cast<KisiModeli>() ??
            [];
      }

      if (kisiler.isEmpty) {
        onSuccess?.call('Senkronize edilecek kişi yok');
        return true;
      }

      final kisilerJson = kisiler.map((kisi) => kisi.toMap()).toList();

      final response = await http
          .post(
            Uri.parse('http://$hedefIP:8080/sync/kisiler'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'kisiler': kisilerJson,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          onSuccess?.call('${responseData['basarili']} kişi senkronize edildi');
          return true;
        } else {
          onError?.call(
            'Kişi senkronizasyonu hatası: ${responseData['error']}',
          );
          return false;
        }
      } else {
        onError?.call('Kişi senkronizasyonu başarısız: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Kişi senkronizasyonu hatası: $e');
      onError?.call('Kişi senkronizasyonu hatası: $e');
      return false;
    }
  }

  /// Kategorileri hedef cihaza senkronize et
  Future<bool> kategorileriSenkronEt(
    String hedefIP, {
    List<KategoriModeli>? kategoriler,
  }) async {
    try {
      print('📁 Kategori senkronizasyonu başlatılıyor...');

      // Eğer kategoriler verilmemişse, bekleyen kategorileri al
      if (kategoriler == null) {
        final bekleyenler = await bekleyenSenkronlariGetir();
        kategoriler =
            (bekleyenler['bekleyen_kategoriler'] as List<dynamic>?)
                ?.cast<KategoriModeli>() ??
            [];
      }

      if (kategoriler.isEmpty) {
        onSuccess?.call('Senkronize edilecek kategori yok');
        return true;
      }

      final kategorilerJson =
          kategoriler.map((kategori) => kategori.toMap()).toList();

      final response = await http
          .post(
            Uri.parse('http://$hedefIP:8080/sync/kategoriler'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'kategoriler': kategorilerJson,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          onSuccess?.call(
            '${responseData['basarili']} kategori senkronize edildi',
          );
          return true;
        } else {
          onError?.call(
            'Kategori senkronizasyonu hatası: ${responseData['error']}',
          );
          return false;
        }
      } else {
        onError?.call(
          'Kategori senkronizasyonu başarısız: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Kategori senkronizasyonu hatası: $e');
      onError?.call('Kategori senkronizasyonu hatası: $e');
      return false;
    }
  }

  /// Tüm verileri hedef cihaza senkronize et (Dependency-Aware)
  Future<bool> tumSenkronizasyonuBaslat(String hedefIP) async {
    try {
      print('🔄 Kapsamlı senkronizasyon başlatılıyor...');
      onSuccess?.call('Senkronizasyon başlatıldı...');

      final bekleyenler = await bekleyenSenkronlariGetir();

      // Bekleyen belgeleri al
      final belgeler = bekleyenler['bekleyen_belgeler'] as List<BelgeModeli>;

      if (belgeler.isEmpty) {
        onSuccess?.call('Senkronize edilecek belge yok');
        return true;
      }

      // Yeni dependency-aware belge senkronizasyonu
      // Bu sistem otomatik olarak ilgili kişi ve kategorileri de gönderir
      final belgeBasarisi = await belgeleriSenkronEt(
        hedefIP,
        belgeler: belgeler,
      );

      if (belgeBasarisi) {
        onSuccess?.call('Kapsamlı senkronizasyon başarıyla tamamlandı');
        print(
          '✅ Senkronizasyon tamamlandı - belgeler, kişiler ve kategoriler dahil',
        );

        // Otomatik bağlantı kesme özelliği
        if (_otomatikBaglantiKes) {
          await Future.delayed(
            const Duration(seconds: 2),
          ); // Kullanıcı mesajını görsün
          await _otomatikBaglantiKes_Func(hedefIP);
        }

        return true;
      } else {
        onError?.call('Senkronizasyon başarısız');
        return false;
      }
    } catch (e) {
      print('❌ Kapsamlı senkronizasyon hatası: $e');
      onError?.call('Senkronizasyon hatası: $e');
      return false;
    }
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

      // UI'yı güncelle
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

      // Tüm cihazları kaldır
      _bagliCihazlar.clear();

      // UI'yı güncelle
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
    onStatusChanged = null;
    onDeviceListChanged = null;
    onSuccess = null;
    onError = null;
    onDeviceConnected = null;
    _progressController?.close();
    _progressController = null;
  }
}
