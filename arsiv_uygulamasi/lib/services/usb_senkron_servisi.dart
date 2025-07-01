import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import '../models/belge_modeli.dart';
import '../models/senkron_log_modeli.dart';
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

class SenkronCihazi {
  final String id;
  final String ad;
  final String ip;
  final String mac;
  final String platform;
  final DateTime sonGorulen;
  final bool aktif;
  final int belgeSayisi;
  final int toplamBoyut;

  SenkronCihazi({
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

  factory SenkronCihazi.fromJson(Map<String, dynamic> json) {
    return SenkronCihazi(
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
  List<SenkronCihazi> _bulunanCihazlar = [];
  SenkronCihazi? _bagliBulunanCihaz;
  SenkronIstatistik? _aktifSenkronIstatistik;

  // Discovery progress tracking
  int _toplamIPSayisi = 0;
  int _kontrollEdilmisIPSayisi = 0;

  // Stream controllers
  final StreamController<CihazDurumu> _cihazDurumuController =
      StreamController<CihazDurumu>.broadcast();
  final StreamController<UsbSenkronDurumu> _senkronDurumuController =
      StreamController<UsbSenkronDurumu>.broadcast();
  final StreamController<List<SenkronCihazi>> _cihazlarController =
      StreamController<List<SenkronCihazi>>.broadcast();
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
  List<SenkronCihazi> get bulunanCihazlar => _bulunanCihazlar;
  SenkronCihazi? get bagliBulunanCihaz => _bagliBulunanCihaz;
  SenkronIstatistik? get aktifSenkronIstatistik => _aktifSenkronIstatistik;

  // Streams
  Stream<CihazDurumu> get cihazDurumuStream => _cihazDurumuController.stream;
  Stream<UsbSenkronDurumu> get senkronDurumuStream =>
      _senkronDurumuController.stream;
  Stream<List<SenkronCihazi>> get cihazlarStream => _cihazlarController.stream;
  Stream<SenkronIstatistik?> get istatistikStream =>
      _istatistikController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<double> get discoveryProgressStream =>
      _discoveryProgressController.stream;

  // CIHAZ KEŞFI VE BAĞLANTI
  Future<void> cihazAramayaBasla() async {
    _discoveryIptalEdildi = false; // İptal flag'ini sıfırla
    _cihazDurumuGuncelle(CihazDurumu.ARANYOR);
    _logEkle('Cihaz arama başlatıldı...');

    try {
      // HTTP sunucusunu arka planda başlat (eğer çalışmıyorsa)
      if (!_httpSunucu.calisiyorMu) {
        _logEkle('HTTP sunucusu başlatılıyor...');
        // Ana thread'i bloke etmemek için arka planda başlat
        _httpSunucu
            .sunucuyuBaslat()
            .then((_) {
              _logEkle(
                'HTTP sunucusu başlatıldı - Cihaz ID: ${_httpSunucu.cihazId}',
              );
            })
            .catchError((error) {
              _logEkle('HTTP sunucusu başlatma hatası: $error');
            });

        // Sunucunun başlaması için kısa bir bekleme
        await Future.delayed(const Duration(milliseconds: 500));
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

      // Discovery'yi arka planda başlat
      _discoveryBaslatArkaPlan(wifiIP);

      // 15 saniye ara (batch'ler için biraz daha uzun)
      _discoveryTimer = Timer(const Duration(seconds: 15), () {
        cihazAramayiDurdur();
      });
    } catch (e) {
      _logEkle('Cihaz arama hatası: $e');
      _cihazDurumuGuncelle(CihazDurumu.BAGLI_DEGIL);
    }
  }

  // Discovery'yi arka planda çalıştır
  void _discoveryBaslatArkaPlan(String localIP) {
    Future.microtask(() async {
      await _discoveryBaslat(localIP);
    });
  }

  Future<void> _discoveryBaslat(String localIP) async {
    _logEkle('Discovery protokolü başlatılıyor...');

    try {
      // UDP broadcast ile cihazları ara
      final parts = localIP.split('.');
      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}';

      // Önce yaygın IP aralıklarını kontrol et (daha hızlı sonuç için)
      final oncelikliIPler = [
        '$networkBase.1', // Router
        '$networkBase.2', // Yaygın cihaz IP'si
        '$networkBase.10', // Yaygın cihaz IP'si
        '$networkBase.100', // Yaygın cihaz IP'si
        '$networkBase.101', // Yaygın cihaz IP'si
        '$networkBase.102', // Yaygın cihaz IP'si
      ];

      // Progress tracking başlat
      _kontrollEdilmisIPSayisi = 0;
      _toplamIPSayisi = oncelikliIPler.length;

      // Öncelikli IP'leri hızlıca kontrol et
      for (final ip in oncelikliIPler) {
        if (_discoveryIptalEdildi) break; // İptal kontrolü

        if (ip != localIP) {
          // Her IP kontrolünü arka planda yap
          _cihazKontrolEtArkaPlan(ip);
          _kontrollEdilmisIPSayisi++;
          _discoveryProgressController.add(
            _kontrollEdilmisIPSayisi / _toplamIPSayisi,
          );
          // UI'ın responsiveness için bekleme
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Batch halinde IP taraması yap (aynı anda maksimum 5 istek)
      const batchSize = 5; // Daha küçük batch boyutu
      final allIPs = <String>[];

      for (int i = 1; i <= 254; i++) {
        final targetIP = '$networkBase.$i';
        if (targetIP != localIP && !oncelikliIPler.contains(targetIP)) {
          allIPs.add(targetIP);
        }
      }

      // Toplam IP sayısını güncelle
      _toplamIPSayisi += allIPs.length;

      // Batch'ler halinde işle
      for (int i = 0; i < allIPs.length; i += batchSize) {
        if (_discoveryIptalEdildi) break; // İptal kontrolü

        final batch = allIPs.skip(i).take(batchSize).toList();

        // Her batch'i arka planda çalıştır
        for (final ip in batch) {
          if (_discoveryIptalEdildi) break; // İptal kontrolü
          _cihazKontrolEtArkaPlan(ip);
        }

        // Progress güncelle
        _kontrollEdilmisIPSayisi += batch.length;
        _discoveryProgressController.add(
          _kontrollEdilmisIPSayisi / _toplamIPSayisi,
        );

        // UI'ın donmasını engellemek için uzun bekleme
        await Future.delayed(const Duration(milliseconds: 200));

        // İptal kontrolü
        if (_discoveryTimer == null || _discoveryIptalEdildi) break;
      }
    } catch (e) {
      _logEkle('Discovery hatası: $e');
    }
  }

  // Cihaz kontrolünü arka planda yap
  void _cihazKontrolEtArkaPlan(String ip) {
    Future.microtask(() async {
      await _cihazKontrolEt(ip);
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
          final cihaz = SenkronCihazi.fromJson({
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

  void _cihazBulundu(SenkronCihazi cihaz) {
    _logEkle('Cihaz bulundu: ${cihaz.ad} (${cihaz.ip})');

    // Listede varsa güncelle, yoksa ekle
    final index = _bulunanCihazlar.indexWhere((c) => c.id == cihaz.id);
    if (index >= 0) {
      _bulunanCihazlar[index] = cihaz;
    } else {
      _bulunanCihazlar.add(cihaz);
    }

    _cihazlarController.add(_bulunanCihazlar);

    if (_cihazDurumu == CihazDurumu.ARANYOR) {
      _cihazDurumuGuncelle(CihazDurumu.BULUNDU);
    }
  }

  void cihazAramayiDurdur() {
    _discoveryIptalEdildi = true; // İptal flag'ini set et
    _discoveryTimer?.cancel();
    _discoveryTimer = null;

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

  Future<bool> cihazaBaglan(SenkronCihazi cihaz) async {
    _cihazDurumuGuncelle(CihazDurumu.BAGLANIYOR);
    _logEkle('${cihaz.ad} cihazına bağlanılıyor...');

    try {
      // Önce ping testi
      final pingResponse = await http
          .get(
            Uri.parse('http://${cihaz.ip}:$SENKRON_PORTU/ping'),
            headers: {'User-Agent': 'Arsivim-Client'},
          )
          .timeout(const Duration(seconds: 5));

      if (pingResponse.statusCode != 200) {
        throw Exception('Ping başarısız: ${pingResponse.statusCode}');
      }

      // Bağlantı kurma isteği gönder
      final connectResponse = await http
          .post(
            Uri.parse('http://${cihaz.ip}:$SENKRON_PORTU/connect'),
            headers: {
              'User-Agent': 'Arsivim-Client',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'clientId': _httpSunucu.cihazId,
              'clientName': 'Arşivim Cihazı',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (connectResponse.statusCode == 200) {
        final responseData = json.decode(connectResponse.body);
        final token = responseData['token'] as String?;

        if (token != null) {
          // Token'ı cihaz bilgisine ekle (geçici olarak)
          final updatedCihaz = SenkronCihazi(
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

          _bagliBulunanCihaz = updatedCihaz;
          _cihazDurumuGuncelle(CihazDurumu.BAGLI);
          _logEkle('${cihaz.ad} cihazına başarıyla bağlanıldı');
          _logEkle('Güvenlik token alındı');

          return true;
        } else {
          throw Exception('Token alınamadı');
        }
      } else {
        throw Exception(
          'Bağlantı kurma başarısız: ${connectResponse.statusCode}',
        );
      }
    } catch (e) {
      _logEkle('Bağlantı hatası: $e');
      _cihazDurumuGuncelle(CihazDurumu.BULUNDU);
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
