import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import '../models/belge_modeli.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'http_sunucu_servisi.dart';

enum UsbSenkronDurumu {
  BEKLEMEDE,
  DEVAM_EDIYOR,
  TAMAMLANDI,
  HATA,
  IPTAL_EDILDI,
}

enum CihazDurumu {
  BAGLI_DEGIL,
  ARANYOR,
  BULUNDU,
  BAGLANIYOR,
  BAGLI,
  SENKRON_EDILIYOR,
}

class USBSenkronCihazi {
  final String id;
  final String ad;
  final String ip;
  final String mac;
  final String platform;
  final DateTime sonGorulen;
  final bool aktif;
  final int belgeSayisi;
  final int toplamBoyut;

  USBSenkronCihazi({
    required this.id,
    required this.ad,
    required this.ip,
    required this.mac,
    required this.platform,
    required this.sonGorulen,
    required this.aktif,
    required this.belgeSayisi,
    required this.toplamBoyut,
  });

  factory USBSenkronCihazi.fromJson(Map<String, dynamic> json) {
    return USBSenkronCihazi(
      id: json['id'] ?? '',
      ad: json['ad'] ?? '',
      ip: json['ip'] ?? '',
      mac: json['mac'] ?? '',
      platform: json['platform'] ?? '',
      sonGorulen: DateTime.parse(
        json['sonGorulen'] ?? DateTime.now().toIso8601String(),
      ),
      aktif: json['aktif'] ?? false,
      belgeSayisi: json['belgeSayisi'] ?? 0,
      toplamBoyut: json['toplamBoyut'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ad': ad,
      'ip': ip,
      'mac': mac,
      'platform': platform,
      'sonGorulen': sonGorulen.toIso8601String(),
      'aktif': aktif,
      'belgeSayisi': belgeSayisi,
      'toplamBoyut': toplamBoyut,
    };
  }
}

class SenkronIstatistik {
  final int toplamDosya;
  final int aktarilanDosya;
  final int hataliDosya;
  final int toplamBoyut;
  final int aktarilanBoyut;
  final DateTime baslangicZamani;
  final Duration gecenSure;
  final double ilerlemeYuzdesi;

  SenkronIstatistik({
    required this.toplamDosya,
    required this.aktarilanDosya,
    required this.hataliDosya,
    required this.toplamBoyut,
    required this.aktarilanBoyut,
    required this.baslangicZamani,
    required this.gecenSure,
    required this.ilerlemeYuzdesi,
  });
}

class UsbSenkronServisi {
  static const int SENKRON_PORTU = 8080;
  static const String DISCOVERY_MESSAGE = 'ARSIVIM_DISCOVERY';
  static const String DISCOVERY_RESPONSE = 'ARSIVIM_DEVICE';

  static UsbSenkronServisi? _instance;
  static UsbSenkronServisi get instance => _instance ??= UsbSenkronServisi._();
  UsbSenkronServisi._();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  // State management
  CihazDurumu _cihazDurumu = CihazDurumu.BAGLI_DEGIL;
  UsbSenkronDurumu _senkronDurumu = UsbSenkronDurumu.BEKLEMEDE;
  List<USBSenkronCihazi> _bulunanCihazlar = [];
  USBSenkronCihazi? _bagliBulunanCihaz;
  SenkronIstatistik? _aktifSenkronIstatistik;

  // Discovery progress tracking
  int _toplamIPSayisi = 0;
  int _kontrollEdilmisIPSayisi = 0;

  // Stream controllers
  final StreamController<CihazDurumu> _cihazDurumuController =
      StreamController<CihazDurumu>.broadcast();
  final StreamController<UsbSenkronDurumu> _senkronDurumuController =
      StreamController<UsbSenkronDurumu>.broadcast();
  final StreamController<List<USBSenkronCihazi>> _cihazlarController =
      StreamController<List<USBSenkronCihazi>>.broadcast();
  final StreamController<SenkronIstatistik?> _istatistikController =
      StreamController<SenkronIstatistik?>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<double> _discoveryProgressController =
      StreamController<double>.broadcast();

  // Timers ve kontrol flag'leri
  Timer? _discoveryTimer;
  Timer? _senkronTimer;
  bool _discoveryIptalEdildi = false;

  // Getters
  CihazDurumu get cihazDurumu => _cihazDurumu;
  UsbSenkronDurumu get senkronDurumu => _senkronDurumu;
  List<USBSenkronCihazi> get bulunanCihazlar => _bulunanCihazlar;
  USBSenkronCihazi? get bagliBulunanCihaz => _bagliBulunanCihaz;
  SenkronIstatistik? get aktifSenkronIstatistik => _aktifSenkronIstatistik;

  // Streams
  Stream<CihazDurumu> get cihazDurumuStream => _cihazDurumuController.stream;
  Stream<UsbSenkronDurumu> get senkronDurumuStream =>
      _senkronDurumuController.stream;
  Stream<List<USBSenkronCihazi>> get cihazlarStream =>
      _cihazlarController.stream;
  Stream<SenkronIstatistik?> get istatistikStream =>
      _istatistikController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<double> get discoveryProgressStream =>
      _discoveryProgressController.stream;

  // CIHAZ KEŞFI VE BAĞLANTI
  Future<void> cihazAramayaBasla() async {
    _discoveryIptalEdildi = false; // İptal flag'ini sıfırla
    _currentIPIndex = 0; // Index'i sıfırla
    _ipListesi.clear(); // Listeyi temizle
    _bulunanCihazlar.clear(); // Önceki cihazları temizle
    _cihazDurumuGuncelle(CihazDurumu.ARANYOR);
    _logEkle('Cihaz arama başlatıldı...');

    try {
      // HTTP sunucusunu kontrol et
      if (!_httpSunucu.calisiyorMu) {
        _logEkle('HTTP sunucusu başlatılması gerekiyor...');
        try {
          await _httpSunucu.sunucuyuBaslat();
          _logEkle(
            'HTTP sunucusu başlatıldı - Cihaz ID: ${_httpSunucu.cihazId}',
          );
        } catch (error) {
          _logEkle('HTTP sunucusu başlatma hatası: $error');
          throw Exception('HTTP sunucusu başlatılamadı');
        }
      }

      // Network bağlantısını kontrol et
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('İnternet bağlantısı bulunamadı');
      }

      // Wi-Fi IP adresini al
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) {
        throw Exception('Wi-Fi IP adresi alınamadı');
      }

      _logEkle('Yerel IP: $wifiIP');
      _logEkle('Sunucu portu: $SENKRON_PORTU');

      // Discovery'yi başlat
      _logEkle('IP taraması başlatılıyor: $wifiIP');
      _discoveryBaslatArkaPlan(wifiIP);

      // 60 saniye ara (daha geniş IP aralığı için daha uzun)
      _discoveryTimer = Timer(const Duration(seconds: 60), () {
        _logEkle('Cihaz arama zaman aşımı');
        cihazAramayiDurdur();
      });
    } catch (e) {
      _logEkle('Cihaz arama hatası: $e');
      _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
    }
  }

  // Discovery'yi arka planda çalıştır
  void _discoveryBaslatArkaPlan(String localIP) {
    _logEkle('Timer tabanlı IP taraması başlatılıyor...');

    // Ana thread'i hiç bloke etmemek için Timer kullan - daha yavaş tarama
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_discoveryIptalEdildi) {
        _logEkle('Discovery iptal edildi, timer durduruluyor');
        timer.cancel();
        return;
      }

      // Sadece bir IP kontrol et ve çık
      _discoveryBaslatHizli(localIP, timer);
    });
  }

  int _currentIPIndex = 0;
  List<String> _ipListesi = [];

  void _discoveryBaslatHizli(String localIP, Timer timer) {
    if (_ipListesi.isEmpty) {
      // IP listesini oluştur
      final parts = localIP.split('.');
      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';

      _logEkle('IP listesi oluşturuluyor: $networkBase.x');

      // Öncelikli IP'ler (router, gateway, yaygın IP'ler)
      _ipListesi = [
        '$networkBase.1', // Gateway
        '$networkBase.2', // Router
        '$networkBase.10', // Yaygın IP
        '$networkBase.100', // Yaygın IP
        '$networkBase.101', // Yaygın IP
        '$networkBase.102', // Yaygın IP
        '$networkBase.20', // Android cihazlar
        '$networkBase.30', // iOS cihazlar
        '$networkBase.50', // Laptop'lar
      ];

      // Diğer IP'ler (daha geniş aralık - 1-254 arası)
      for (int i = 3; i <= 254; i++) {
        if (![1, 2, 10, 20, 30, 50, 100, 101, 102].contains(i)) {
          _ipListesi.add('$networkBase.$i');
        }
      }

      _toplamIPSayisi = _ipListesi.length;
      _kontrollEdilmisIPSayisi = 0;
      _logEkle('${_ipListesi.length} IP adresi taranacak');
    }

    // Tek IP kontrol et
    if (_currentIPIndex < _ipListesi.length) {
      final ip = _ipListesi[_currentIPIndex];
      if (ip != localIP) {
        _logEkle(
          'IP kontrol ediliyor: $ip (${_currentIPIndex + 1}/${_ipListesi.length})',
        );
        _cihazKontrolEtHizli(ip);
      }

      _currentIPIndex++;
      _kontrollEdilmisIPSayisi++;

      // Progress güncelle
      final progress = _kontrollEdilmisIPSayisi / _toplamIPSayisi;
      _discoveryProgressController.add(progress);

      // Tamamlandı mı?
      if (_currentIPIndex >= _ipListesi.length) {
        _logEkle('IP taraması tamamlandı');
        timer.cancel();
        _discoveryTamamlandi();
      }
    } else {
      _logEkle('IP taraması sona erdi');
      timer.cancel();
      _discoveryTamamlandi();
    }
  }

  void _discoveryTamamlandi() {
    if (_bulunanCihazlar.isEmpty) {
      _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
      _logEkle('Cihaz arama tamamlandı - Hiç cihaz bulunamadı');
    } else {
      _cihazDurumuGuncelle(CihazDurumu.BULUNDU);
      _logEkle(
        'Cihaz arama tamamlandı - ${_bulunanCihazlar.length} cihaz bulundu',
      );
    }
  }

  // Cihaz kontrolünü arka planda yap
  void _cihazKontrolEtArkaPlan(String ip) {
    Future.microtask(() async {
      await _cihazKontrolEt(ip);
    });
  }

  // Hızlı cihaz kontrolü (non-blocking)
  void _cihazKontrolEtHizli(String ip) {
    if (_discoveryIptalEdildi) return;

    // HTTP isteğini arka planda yap - daha uzun timeout
    http
        .get(
          Uri.parse('http://$ip:$SENKRON_PORTU/info'),
          headers: {
            'User-Agent': 'Arsivim-Client',
            'Connection': 'close',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 2)) // Timeout'u artırdık
        .then((response) {
          if (_discoveryIptalEdildi) return;

          if (response.statusCode == 200) {
            _logEkle('✅ Cihaz yanıtı alındı: $ip');
            try {
              final data = json.decode(response.body);
              if (data['app'] == 'arsivim') {
                final cihaz = USBSenkronCihazi.fromJson({
                  ...data,
                  'ip': ip,
                  'mac': '', // MAC adresi şimdilik boş
                  'sonGorulen': DateTime.now().toIso8601String(),
                });

                _cihazBulundu(cihaz);
              } else {
                _logEkle('⚠️ Uyumlu olmayan cihaz: $ip');
              }
            } catch (e) {
              _logEkle('❌ JSON parse hatası ($ip): $e');
            }
          } else {
            _logEkle('⚠️ HTTP ${response.statusCode} yanıtı: $ip');
          }
        })
        .catchError((e) {
          // Sadece gerçek hataları logla
          if (e.toString().contains('Connection refused') ||
              e.toString().contains('No route to host')) {
            // Bu normal, çoğu IP'de servis yok
          } else if (e.toString().contains('TimeoutException')) {
            _logEkle('⏱️ Timeout: $ip');
          } else {
            _logEkle('❌ Bağlantı hatası ($ip): $e');
          }
        });
  }

  Future<void> _cihazKontrolEt(String ip) async {
    if (_discoveryIptalEdildi) return; // İptal edilmişse çık

    try {
      // HTTP request ile cihazı kontrol et (çok kısa timeout)
      final response = await http
          .get(
            Uri.parse('http://$ip:$SENKRON_PORTU/info'),
            headers: {
              'User-Agent': 'Arsivim-Client',
              'Connection': 'close', // Bağlantıyı hızlıca kapat
            },
          )
          .timeout(const Duration(milliseconds: 500)); // Çok kısa timeout

      if (_discoveryIptalEdildi) return; // İstek sonrası tekrar kontrol

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['app'] == 'arsivim') {
          final cihaz = USBSenkronCihazi.fromJson({
            ...data,
            'ip': ip,
            'sonGorulen': DateTime.now().toIso8601String(),
          });

          _cihazBulundu(cihaz);
        }
      }
    } catch (e) {
      // Sessizce devam et - çoğu IP'de cihaz olmayacak
      // Timeout ve connection error'ları normal
    }
  }

  void _cihazBulundu(USBSenkronCihazi cihaz) {
    _logEkle('Cihaz bulundu: ${cihaz.ad} (${cihaz.ip})');

    // Mevcut cihazlar listesinde var mı kontrol et
    final mevcutIndex = _bulunanCihazlar.indexWhere((c) => c.id == cihaz.id);

    if (mevcutIndex >= 0) {
      // Mevcutsa güncelle
      _bulunanCihazlar[mevcutIndex] = cihaz;
    } else {
      // Yoksa ekle
      _bulunanCihazlar.add(cihaz);
    }

    // Stream'i güncelle
    _cihazlarController.add(List.from(_bulunanCihazlar));

    // Durumu güncelle
    if (_cihazDurumu == CihazDurumu.ARANYOR) {
      _cihazDurumuGuncelle(CihazDurumu.BULUNDU);
    }
  }

  void cihazAramayiDurdur() {
    _discoveryIptalEdildi = true; // İptal flag'ini set et
    _discoveryTimer?.cancel();
    _discoveryTimer = null;

    // State'i sıfırla
    _currentIPIndex = 0;
    _ipListesi.clear();

    if (_bulunanCihazlar.isEmpty) {
      _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
      _logEkle('Cihaz arama durduruldu - Hiç cihaz bulunamadı');
    } else {
      _cihazDurumuGuncelle(CihazDurumu.BULUNDU);
      _logEkle(
        'Cihaz arama tamamlandı - ${_bulunanCihazlar.length} cihaz bulundu',
      );
    }
  }

  // Manuel IP ile bağlantı deneme
  Future<bool> manuelBaglantiDene(String ipPort) async {
    try {
      // IP:Port formatını kontrol et ve düzelt
      String ip;
      int port = 8080; // varsayılan port

      // Girdiyi temizle
      String cleanInput = ipPort.trim();

      if (cleanInput.contains(':')) {
        final parts = cleanInput.split(':');
        ip = parts[0].trim();
        // Son kısmı port olarak al (eğer birden fazla : varsa)
        if (parts.length > 1) {
          port = int.tryParse(parts.last.trim()) ?? 8080;
        }
      } else {
        ip = cleanInput;
      }

      _logEkle('🔍 Manuel bağlantı test ediliyor: $ip:$port');

      // HTTP isteği gönder
      final response = await http
          .get(
            Uri.parse('http://$ip:$port/info'),
            headers: {
              'User-Agent': 'Arsivim-Client',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['app'] == 'arsivim') {
          _logEkle('✅ Cihaz doğrulandı: ${data['ad']}');

          // Bağlı cihaz olarak kaydet
          final cihaz = USBSenkronCihazi.fromJson({
            ...data,
            'ip': ip,
            'mac': '',
            'sonGorulen': DateTime.now().toIso8601String(),
          });

          // Şimdi bağlantı kurma isteği gönder
          try {
            _logEkle('🔗 Bağlantı kurma isteği gönderiliyor...');
            final connectResponse = await http
                .post(
                  Uri.parse('http://$ip:$port/connect'),
                  headers: {
                    'User-Agent': 'Arsivim-Client',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'clientId': _httpSunucu.cihazId,
                    'clientName': 'Arşivim Mobil',
                    'platform': 'Mobil',
                    'belgeSayisi': await _veriTabani.toplamBelgeSayisi(),
                    'toplamBoyut': await _veriTabani.toplamDosyaBoyutu(),
                  }),
                )
                .timeout(const Duration(seconds: 10));

            if (connectResponse.statusCode == 200) {
              final connectData = json.decode(connectResponse.body);
              _logEkle('✅ Bağlantı kuruldu: ${connectData['message']}');

              // Server bilgilerini güncelle
              if (connectData['serverInfo'] != null) {
                final serverInfo = connectData['serverInfo'];
                final updatedCihaz = USBSenkronCihazi(
                  id: cihaz.id,
                  ad: cihaz.ad,
                  ip: cihaz.ip,
                  mac: cihaz.mac,
                  platform: cihaz.platform,
                  sonGorulen: cihaz.sonGorulen,
                  aktif: cihaz.aktif,
                  belgeSayisi: serverInfo['belgeSayisi'] ?? cihaz.belgeSayisi,
                  toplamBoyut: serverInfo['toplamBoyut'] ?? cihaz.toplamBoyut,
                );
                _bagliBulunanCihaz = updatedCihaz;
                _cihazDurumuGuncelle(CihazDurumu.BAGLI);
                _logEkle('🎉 BAĞLANTI BAŞARILI! Cihaz: ${updatedCihaz.ad}');
                _basariBildirimiGonder(updatedCihaz);
                return true;
              }
            } else {
              _logEkle(
                '⚠️ Bağlantı kurma yanıtı: ${connectResponse.statusCode}',
              );
            }
          } catch (e) {
            _logEkle('⚠️ Bağlantı kurma hatası: $e');
            // Yine de devam et, info endpoint'i çalışıyor
          }

          // Eğer connect başarısız olduysa veya serverInfo yoksa, basit bağlantı kur
          _bagliBulunanCihaz = cihaz;
          _cihazDurumuGuncelle(CihazDurumu.BAGLI);
          _logEkle('🎉 BAĞLANTI BAŞARILI! Cihaz: ${cihaz.ad}');

          // Başarı bildirimi gönder
          _basariBildirimiGonder(cihaz);

          return true;
        } else {
          _logEkle('⚠️ Uyumlu olmayan uygulama');
          return false;
        }
      } else {
        _logEkle('❌ HTTP hatası: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logEkle('❌ Bağlantı hatası: $e');
      return false;
    }
  }

  // Bağlantı başarı bildirimi
  void _basariBildirimiGonder(USBSenkronCihazi cihaz) {
    _logEkle('🔔 Bildirim: ${cihaz.ad} cihazı ile bağlantı kuruldu!');
    _logEkle('📊 Cihaz Bilgileri:');
    _logEkle('   • Platform: ${cihaz.platform}');
    _logEkle('   • IP: ${cihaz.ip}');
    _logEkle('   • Belge Sayısı: ${cihaz.belgeSayisi}');
    _logEkle('   • Toplam Boyut: ${_formatFileSize(cihaz.toplamBoyut)}');
  }

  // Dosya boyutu formatlama
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<bool> cihazaBaglan(USBSenkronCihazi cihaz) async {
    _logEkle('Cihaza bağlanıyor: ${cihaz.ad} (${cihaz.ip})');
    _cihazDurumuGuncelle(CihazDurumu.BAGLANIYOR);

    try {
      // Bağlantı testi
      final response = await http
          .get(Uri.parse('http://${cihaz.ip}:$SENKRON_PORTU/ping'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _bagliBulunanCihaz = cihaz;
        _cihazDurumuGuncelle(CihazDurumu.BAGLI);
        _logEkle('Bağlantı başarılı: ${cihaz.ad}');

        // Cihaz durumunu güncelle
        final updatedCihaz = USBSenkronCihazi(
          id: cihaz.id,
          ad: cihaz.ad,
          ip: cihaz.ip,
          mac: cihaz.mac,
          platform: cihaz.platform,
          sonGorulen: DateTime.now(),
          aktif: true,
          belgeSayisi: cihaz.belgeSayisi,
          toplamBoyut: cihaz.toplamBoyut,
        );

        // Listeyi güncelle
        final index = _bulunanCihazlar.indexWhere((c) => c.id == cihaz.id);
        if (index >= 0) {
          _bulunanCihazlar[index] = updatedCihaz;
          _cihazlarController.add(List.from(_bulunanCihazlar));
        }

        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logEkle('Bağlantı hatası: $e');
      _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
      return false;
    }
  }

  void cihazBaglantisiniKes() {
    _bagliBulunanCihaz = null;
    _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
    _senkronDurumuGuncelle(UsbSenkronDurumu.BEKLEMEDE);
    _logEkle('Cihaz bağlantısı kesildi');
  }

  // SENKRONIZASYON İŞLEMLERİ
  Future<void> senkronizasyonBaslat({bool tamSenkron = false}) async {
    if (_bagliBulunanCihaz == null) {
      throw Exception('Bağlı cihaz bulunamadı');
    }

    _senkronDurumuGuncelle(UsbSenkronDurumu.DEVAM_EDIYOR);
    _cihazDurumuGuncelle(CihazDurumu.SENKRON_EDILIYOR);
    _logEkle('Senkronizasyon başlatıldı...');

    try {
      // Yerel değişiklikleri al (şimdilik boş liste)
      final yerelDegisiklikler = <String>[];

      // Uzak cihazdan değişiklikleri al
      final uzakDegisiklikler = await _uzakDegisiklikleriAl();

      // Senkronizasyon istatistiklerini başlat
      final toplamDosya = yerelDegisiklikler.length + uzakDegisiklikler.length;
      _aktifSenkronIstatistik = SenkronIstatistik(
        toplamDosya: toplamDosya,
        aktarilanDosya: 0,
        hataliDosya: 0,
        toplamBoyut: 0,
        aktarilanBoyut: 0,
        baslangicZamani: DateTime.now(),
        gecenSure: Duration.zero,
        ilerlemeYuzdesi: 0.0,
      );
      _istatistikController.add(_aktifSenkronIstatistik);

      // Yerel değişiklikleri uzak cihaza gönder
      await _yerelDegisiklikleriGonder(yerelDegisiklikler);

      // Uzak değişiklikleri al
      await _uzakDegisiklikleriIndir(uzakDegisiklikler);

      _senkronDurumuGuncelle(UsbSenkronDurumu.TAMAMLANDI);
      _cihazDurumuGuncelle(CihazDurumu.BAGLI);
      _logEkle('Senkronizasyon tamamlandı');
    } catch (e) {
      _logEkle('Senkronizasyon hatası: $e');
      _senkronDurumuGuncelle(UsbSenkronDurumu.HATA);
      _cihazDurumuGuncelle(CihazDurumu.BAGLI);
    }
  }

  Future<List<String>> _uzakDegisiklikleriAl() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://${_bagliBulunanCihaz!.ip}:$SENKRON_PORTU/changes',
            ),
            headers: {'User-Agent': 'Arsivim-Client'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['changes'] ?? []);
      } else {
        throw Exception('Uzak değişiklikler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      _logEkle('Uzak değişiklikler alma hatası: $e');
      return [];
    }
  }

  Future<void> _yerelDegisiklikleriGonder(List<String> hashler) async {
    for (final hash in hashler) {
      try {
        // Hash ile belge getir (şimdilik simüle et)
        // final belge = await _veriTabani.hashIleBelgeGetir(hash);
        // if (belge != null) {
        //   await _dosyaGonder(belge);
        //   _istatistikGuncelle(basarili: true);
        // }
      } catch (e) {
        _logEkle('Dosya gönderme hatası ($hash): $e');
        _istatistikGuncelle(basarili: false);
      }
    }
  }

  Future<void> _uzakDegisiklikleriIndir(List<String> hashler) async {
    for (final hash in hashler) {
      try {
        await _dosyaIndir(hash);
        _istatistikGuncelle(basarili: true);
      } catch (e) {
        _logEkle('Dosya indirme hatası ($hash): $e');
        _istatistikGuncelle(basarili: false);
      }
    }
  }

  Future<void> _dosyaGonder(BelgeModeli belge) async {
    final dosya = File(belge.dosyaYolu);
    if (!await dosya.exists()) {
      throw Exception('Dosya bulunamadı: ${belge.dosyaYolu}');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://${_bagliBulunanCihaz!.ip}:$SENKRON_PORTU/upload'),
    );

    request.headers['User-Agent'] = 'Arsivim-Client';
    request.fields['metadata'] = json.encode(belge.toMap());
    request.files.add(
      await http.MultipartFile.fromPath('file', belge.dosyaYolu),
    );

    final response = await request.send().timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Dosya gönderme başarısız: ${response.statusCode}');
    }

    // Senkron durumunu güncelle (şimdilik yorum satırı)
    // await _veriTabani.senkronDurumunuGuncelle(
    //   belge.id!,
    //   'TAMAMLANDI',
    // );
  }

  Future<void> _dosyaIndir(String hash) async {
    final response = await http
        .get(
          Uri.parse(
            'http://${_bagliBulunanCihaz!.ip}:$SENKRON_PORTU/download/$hash',
          ),
          headers: {'User-Agent': 'Arsivim-Client'},
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      // Metadata'yı al
      final metadataResponse = await http.get(
        Uri.parse(
          'http://${_bagliBulunanCihaz!.ip}:$SENKRON_PORTU/metadata/$hash',
        ),
        headers: {'User-Agent': 'Arsivim-Client'},
      );

      if (metadataResponse.statusCode == 200) {
        final metadata = json.decode(metadataResponse.body);
        final belge = BelgeModeli.fromMap(metadata);

        // Dosyayı kaydet (şimdilik yorum satırı)
        // await _dosyaServisi.dosyaEkle(response.bodyBytes, belge.dosyaAdi);
      }
    } else {
      throw Exception('Dosya indirme başarısız: ${response.statusCode}');
    }
  }

  void _istatistikGuncelle({required bool basarili}) {
    if (_aktifSenkronIstatistik == null) return;

    final yeniIstatistik = SenkronIstatistik(
      toplamDosya: _aktifSenkronIstatistik!.toplamDosya,
      aktarilanDosya:
          _aktifSenkronIstatistik!.aktarilanDosya + (basarili ? 1 : 0),
      hataliDosya: _aktifSenkronIstatistik!.hataliDosya + (basarili ? 0 : 1),
      toplamBoyut: _aktifSenkronIstatistik!.toplamBoyut,
      aktarilanBoyut: _aktifSenkronIstatistik!.aktarilanBoyut,
      baslangicZamani: _aktifSenkronIstatistik!.baslangicZamani,
      gecenSure: DateTime.now().difference(
        _aktifSenkronIstatistik!.baslangicZamani,
      ),
      ilerlemeYuzdesi:
          _aktifSenkronIstatistik!.toplamDosya > 0
              ? ((_aktifSenkronIstatistik!.aktarilanDosya +
                          _aktifSenkronIstatistik!.hataliDosya +
                          1) /
                      _aktifSenkronIstatistik!.toplamDosya) *
                  100
              : 0.0,
    );

    _aktifSenkronIstatistik = yeniIstatistik;
    _istatistikController.add(_aktifSenkronIstatistik);
  }

  void senkronizasyonuIptalEt() {
    _senkronTimer?.cancel();
    _senkronTimer = null;
    _senkronDurumuGuncelle(UsbSenkronDurumu.IPTAL_EDILDI);
    _cihazDurumuGuncelle(CihazDurumu.BAGLI);
    _logEkle('Senkronizasyon iptal edildi');
  }

  // YARDIMCI METODLAR
  void _cihazDurumuGuncelle(CihazDurumu yeniDurum) {
    _cihazDurumu = yeniDurum;
    _cihazDurumuController.add(_cihazDurumu);
  }

  void _senkronDurumuGuncelle(UsbSenkronDurumu yeniDurum) {
    _senkronDurumu = yeniDurum;
    _senkronDurumuController.add(_senkronDurumu);
  }

  void _logEkle(String mesaj) {
    final zaman = DateTime.now().toLocal().toString().substring(11, 19);
    final logMesaj = '[$zaman] $mesaj';
    print(logMesaj); // Debug için
    _logController.add(logMesaj);
  }

  // TEMIZLIK
  void dispose() {
    _discoveryTimer?.cancel();
    _senkronTimer?.cancel();
    _cihazDurumuController.close();
    _senkronDurumuController.close();
    _cihazlarController.close();
    _istatistikController.close();
    _logController.close();
    _discoveryProgressController.close();
  }
}
