import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';

class SenkronManager {
  static final SenkronManager _instance = SenkronManager._internal();
  static SenkronManager get instance => _instance;
  SenkronManager._internal();

  // Progress tracking için callback'ler
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  // Gerçek senkronizasyon işlemi
  Future<Map<String, int>> performSynchronization(
    SenkronCihazi bagliBulunanCihaz,
  ) async {
    int yeniBelgeSayisi = 0;
    int guncellenmisBelgeSayisi = 0;
    int gonderilmiBelgeSayisi = 0;

    try {
      // Progress başlangıcı
      _updateProgress(0.0, 'Senkronizasyon başlatılıyor...');
      _addLog('🔄 Senkronizasyon başlatıldı');

      // 1. Yerel verileri al (10%)
      _updateProgress(0.1, 'Yerel veriler kontrol ediliyor...');
      _addLog('📊 Yerel veriler kontrol ediliyor...');
      final veriTabani = VeriTabaniServisi();
      final yerelBelgeler = await veriTabani.belgeleriGetir();
      final yerelKategoriler = await veriTabani.kategorileriGetir();
      final yerelKisiler = await veriTabani.kisileriGetir();
      _addLog('📁 Yerel belge sayısı: ${yerelBelgeler.length}');
      _addLog('📋 Yerel kategori sayısı: ${yerelKategoriler.length}');
      _addLog('👤 Yerel kişi sayısı: ${yerelKisiler.length}');

      // 2. Uzak cihazdan kategorileri al (15%)
      _updateProgress(0.15, 'Uzak cihazdan kategoriler alınıyor...');
      _addLog('📋 Uzak cihazdan kategoriler alınıyor...');
      final uzakKategoriler = await _getRemoteCategories(bagliBulunanCihaz.ip);
      _addLog('📁 Uzak kategori sayısı: ${uzakKategoriler.length}');

      // 3. Uzak cihazdan kişileri al (17%)
      _updateProgress(0.17, 'Uzak cihazdan kişiler alınıyor...');
      _addLog('👥 Uzak cihazdan kişiler alınıyor...');
      final uzakKisiler = await _getRemotePeople(bagliBulunanCihaz.ip);
      _addLog('👤 Uzak kişi sayısı: ${uzakKisiler.length}');

      // 4. Uzak cihazdan belgeleri al (20%)
      _updateProgress(0.2, 'Uzak cihazdan belgeler alınıyor...');
      _addLog('📥 Uzak cihazdan belgeler alınıyor...');
      final uzakBelgeler = await _getRemoteDocuments(bagliBulunanCihaz.ip);
      _addLog('📁 Uzak belge sayısı: ${uzakBelgeler.length}');

      // 5. Kategorileri senkronize et (22%)
      _updateProgress(0.22, 'Kategoriler senkronize ediliyor...');
      _addLog('📋 Kategoriler senkronize ediliyor...');
      await _syncCategories(uzakKategoriler, yerelKategoriler);

      // 6. Kişileri senkronize et (25%)
      _updateProgress(0.25, 'Kişiler senkronize ediliyor...');
      _addLog('👥 Kişiler senkronize ediliyor...');
      await _syncPeople(uzakKisiler, yerelKisiler);

      // 7. Toplam işlem sayısını hesapla
      final toplamIslem = uzakBelgeler.length + yerelBelgeler.length;
      int tamamlananIslem = 0;

      // 8. Karşılaştırma ve senkronizasyon (30-80%)
      _updateProgress(0.3, 'Belgeler karşılaştırılıyor...');
      _addLog('🔍 Belgeler karşılaştırılıyor...');

      // Uzak belgelerden indirme
      for (int i = 0; i < uzakBelgeler.length; i++) {
        final uzakBelge = uzakBelgeler[i];
        _updateProgress(
          0.3 + (tamamlananIslem / toplamIslem) * 0.5,
          'İndiriliyor: ${uzakBelge['dosyaAdi']}',
        );

        // Dosya hash'ine göre karşılaştır (aynı dosya farklı adda olabilir)
        final yerelBelge = yerelBelgeler.firstWhere(
          (belge) =>
              belge.dosyaHash == uzakBelge['dosyaHash'] &&
              uzakBelge['dosyaHash'] != null &&
              uzakBelge['dosyaHash'].isNotEmpty,
          orElse: () {
            // Hash eşleşmezse, dosya boyutu ve orijinal dosya adı ile kontrol et
            return yerelBelgeler.firstWhere(
              (belge) =>
                  belge.dosyaBoyutu == uzakBelge['dosyaBoyutu'] &&
                  belge.orijinalDosyaAdi == uzakBelge['orijinalDosyaAdi'],
              orElse:
                  () => BelgeModeli(
                    dosyaAdi: '',
                    orijinalDosyaAdi: '',
                    dosyaYolu: '',
                    dosyaBoyutu: 0,
                    dosyaTipi: '',
                    dosyaHash: '',
                    olusturmaTarihi: DateTime.now(),
                    guncellemeTarihi: DateTime.now(),
                    kategoriId: 1,
                  ),
            );
          },
        );

        if (yerelBelge.dosyaAdi.isEmpty) {
          // Yeni belge - indir
          try {
            await _downloadDocument(uzakBelge, bagliBulunanCihaz.ip);
            yeniBelgeSayisi++;
            _addLog('📥 Yeni belge eklendi: ${uzakBelge['dosyaAdi']}');
          } catch (e) {
            _addLog('❌ Yeni belge indirme başarısız: ${uzakBelge['dosyaAdi']}');
          }
        } else {
          // Aynı dosya tespit edildi - log mesajı
          if (yerelBelge.dosyaHash == uzakBelge['dosyaHash']) {
            _addLog('🔍 Aynı dosya hash ile tespit edildi:');
            _addLog('   • Yerel: ${yerelBelge.dosyaAdi}');
            _addLog('   • Uzak: ${uzakBelge['dosyaAdi']}');
          } else {
            _addLog('🔍 Aynı dosya boyut/adı ile tespit edildi:');
            _addLog(
              '   • Yerel: ${yerelBelge.dosyaAdi} (${yerelBelge.dosyaBoyutu} bytes)',
            );
            _addLog(
              '   • Uzak: ${uzakBelge['dosyaAdi']} (${uzakBelge['dosyaBoyutu']} bytes)',
            );
          }
          // Mevcut belge - GÜNCELLEME TARİHİ kontrolü (conflict resolution)
          try {
            final uzakGuncellemeStr =
                uzakBelge['guncellemeTarihi'] ?? uzakBelge['olusturmaTarihi'];
            final uzakGuncellemeTarihi =
                uzakGuncellemeStr != null
                    ? DateTime.parse(uzakGuncellemeStr)
                    : DateTime.now();
            final yerelGuncellemeTarihi = yerelBelge.guncellemeTarihi;

            _addLog('📅 Tarih kontrolü: ${uzakBelge['dosyaAdi']}');
            _addLog('   • Uzak güncelleme: ${uzakGuncellemeTarihi.toString()}');
            _addLog(
              '   • Yerel güncelleme: ${yerelGuncellemeTarihi.toString()}',
            );

            if (uzakGuncellemeTarihi.isAfter(yerelGuncellemeTarihi)) {
              _addLog('⬇️ Uzak versiyon daha güncel - metadata güncelleniyor');
              try {
                // Aynı dosya ise sadece metadata'yı güncelle, dosyayı tekrar indirme
                await _updateDocumentMetadata(
                  yerelBelge,
                  uzakBelge,
                  bagliBulunanCihaz.ip,
                );
                guncellenmisBelgeSayisi++;
                _addLog(
                  '🔄 Belge metadata güncellendi: ${yerelBelge.dosyaAdi}',
                );
              } catch (e) {
                _addLog(
                  '❌ Belge metadata güncelleme başarısız: ${uzakBelge['dosyaAdi']}',
                );
              }
            } else if (yerelGuncellemeTarihi.isAfter(uzakGuncellemeTarihi)) {
              _addLog('⬆️ Yerel versiyon daha güncel - gönderilecek');
              // Upload kısmında işlenecek
            } else {
              _addLog('✅ Versiyonlar aynı: ${uzakBelge['dosyaAdi']}');
            }
          } catch (e) {
            _addLog('⚠️ Tarih karşılaştırma hatası: $e');
            _addLog('📥 Güvenli mod: belge indiriliyor');
            try {
              await _downloadDocument(
                uzakBelge,
                bagliBulunanCihaz.ip,
                isUpdate: true,
              );
              guncellenmisBelgeSayisi++;
              _addLog(
                '🔄 Güvenli mod belge indirildi: ${uzakBelge['dosyaAdi']}',
              );
            } catch (downloadError) {
              _addLog(
                '❌ Güvenli mod belge indirme başarısız: ${uzakBelge['dosyaAdi']}',
              );
            }
          }
        }

        tamamlananIslem++;
        _updateProgress(0.3 + (tamamlananIslem / toplamIslem) * 0.5, null);
      }

      // 9. Yerel belgeleri uzak cihaza gönder (80-95%)
      _updateProgress(0.8, 'Yerel belgeler gönderiliyor...');
      _addLog('📤 Yerel belgeler gönderiliyor...');

      for (int i = 0; i < yerelBelgeler.length; i++) {
        final yerelBelge = yerelBelgeler[i];
        _updateProgress(
          0.8 + (i / yerelBelgeler.length) * 0.15,
          'Gönderiliyor: ${yerelBelge.dosyaAdi}',
        );

        // Uzak belgede aynı dosya var mı? (Hash değerine göre karşılaştır)
        final uzakBelge = uzakBelgeler.firstWhere(
          (uzakBelge) =>
              uzakBelge['dosyaHash'] == yerelBelge.dosyaHash &&
              yerelBelge.dosyaHash.isNotEmpty &&
              uzakBelge['dosyaHash'] != null &&
              uzakBelge['dosyaHash'].isNotEmpty,
          orElse: () {
            // Hash eşleşmezse, dosya boyutu ve orijinal dosya adı ile kontrol et
            return uzakBelgeler.firstWhere(
              (uzakBelge) =>
                  uzakBelge['dosyaBoyutu'] == yerelBelge.dosyaBoyutu &&
                  uzakBelge['orijinalDosyaAdi'] == yerelBelge.orijinalDosyaAdi,
              orElse: () => <String, dynamic>{},
            );
          },
        );

        if (uzakBelge.isEmpty) {
          // Uzakta yok - gönder
          _addLog('📤 Yeni belge gönderiliyor: ${yerelBelge.dosyaAdi}');
          try {
            await _uploadDocument(yerelBelge, bagliBulunanCihaz.ip);
            gonderilmiBelgeSayisi++;
            _addLog('📤 Belge gönderildi: ${yerelBelge.dosyaAdi}');
          } catch (e) {
            _addLog('❌ Yeni belge gönderme başarısız: ${yerelBelge.dosyaAdi}');
          }
        } else {
          // Aynı dosya tespit edildi - log mesajı
          if (yerelBelge.dosyaHash == uzakBelge['dosyaHash']) {
            _addLog('🔍 Upload: Aynı dosya hash ile tespit edildi:');
            _addLog('   • Yerel: ${yerelBelge.dosyaAdi}');
            _addLog('   • Uzak: ${uzakBelge['dosyaAdi']}');
          } else {
            _addLog('🔍 Upload: Aynı dosya boyut/adı ile tespit edildi:');
            _addLog(
              '   • Yerel: ${yerelBelge.dosyaAdi} (${yerelBelge.dosyaBoyutu} bytes)',
            );
            _addLog(
              '   • Uzak: ${uzakBelge['dosyaAdi']} (${uzakBelge['dosyaBoyutu']} bytes)',
            );
          }
          // Uzakta var - güncelleme tarihi kontrolü
          try {
            final yerelGuncellemeTarihi = yerelBelge.guncellemeTarihi;
            final uzakGuncellemeStr =
                uzakBelge['guncellemeTarihi'] ?? uzakBelge['olusturmaTarihi'];
            final uzakGuncellemeTarihi =
                uzakGuncellemeStr != null
                    ? DateTime.parse(uzakGuncellemeStr)
                    : DateTime.now();

            _addLog('📅 Upload tarih kontrolü: ${yerelBelge.dosyaAdi}');
            _addLog(
              '   • Yerel güncelleme: ${yerelGuncellemeTarihi.toString()}',
            );
            _addLog('   • Uzak güncelleme: ${uzakGuncellemeTarihi.toString()}');

            if (yerelGuncellemeTarihi.isAfter(uzakGuncellemeTarihi)) {
              _addLog('⬆️ Yerel versiyon daha güncel - gönderiliyor');
              try {
                await _uploadDocument(yerelBelge, bagliBulunanCihaz.ip);
                gonderilmiBelgeSayisi++;
                _addLog(
                  '🔄 Belge güncelleme gönderildi: ${yerelBelge.dosyaAdi}',
                );
              } catch (e) {
                _addLog(
                  '❌ Belge güncelleme gönderme başarısız: ${yerelBelge.dosyaAdi}',
                );
              }
            } else {
              _addLog('✅ Uzak versiyon güncel: ${yerelBelge.dosyaAdi}');
            }
          } catch (e) {
            _addLog('⚠️ Upload tarih karşılaştırma hatası: $e');
            _addLog('📤 Güvenli mod: belge gönderiliyor');
            try {
              await _uploadDocument(yerelBelge, bagliBulunanCihaz.ip);
              gonderilmiBelgeSayisi++;
              _addLog(
                '🔄 Güvenli mod belge gönderildi: ${yerelBelge.dosyaAdi}',
              );
            } catch (uploadError) {
              _addLog(
                '❌ Güvenli mod belge gönderme başarısız: ${yerelBelge.dosyaAdi}',
              );
            }
          }
        }
      }

      // 10. Senkronizasyon tamamlandı (100%)
      _updateProgress(1.0, 'Senkronizasyon tamamlanıyor...');
      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('✅ Senkronizasyon tamamlandı!');
      _addLog('📊 Sonuçlar:');
      _addLog('   • Yeni belgeler: $yeniBelgeSayisi');
      _addLog('   • Güncellenen belgeler: $guncellenmisBelgeSayisi');
      _addLog('   • Gönderilen belgeler: $gonderilmiBelgeSayisi');
      _addLog('   • Kategoriler ve kişiler de senkronize edildi');

      return {
        'yeni': yeniBelgeSayisi,
        'guncellenen': guncellenmisBelgeSayisi,
        'gonderilen': gonderilmiBelgeSayisi,
      };
    } catch (e) {
      _addLog('❌ Senkronizasyon hatası: $e');
      rethrow;
    }
  }

  // Uzak cihazdan belge listesi al
  Future<List<Map<String, dynamic>>> _getRemoteDocuments(String ip) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$ip:8080/documents'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['documents'] ?? []);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Uzak belgeler alınamadı: $e');
      return [];
    }
  }

  // Uzak cihazdan belge indir
  Future<void> _downloadDocument(
    Map<String, dynamic> belgeData,
    String ip, {
    bool isUpdate = false,
  }) async {
    try {
      final dosyaAdi = belgeData['dosyaAdi'];
      _addLog('📥 İndiriliyor: $dosyaAdi');

      // Belge içeriğini al
      final response = await http
          .get(Uri.parse('http://$ip:8080/download/$dosyaAdi'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Dosyayı belgeler klasörüne kaydet
        final dosyaServisi = DosyaServisi();
        final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
        final yeniDosyaYolu = '$belgelerKlasoru/$dosyaAdi';

        // Dosyayı yaz
        final dosya = File(yeniDosyaYolu);
        await dosya.writeAsBytes(response.bodyBytes);

        // Dosya hash'ini hesapla
        final dosyaHashi = sha256.convert(response.bodyBytes).toString();
        _addLog('🔐 Dosya hash hesaplandı: ${dosyaHashi.substring(0, 16)}...');

        // Veritabanına ekle - KİŞİ EŞLEŞTİRMESİ İLE
        final veriTabani = VeriTabaniServisi();

        // Aynı hash'e sahip dosya var mı kontrol et
        final mevcutBelgeler = await veriTabani.belgeleriGetir();
        final ayniHashBelge = mevcutBelgeler.firstWhere(
          (b) => b.dosyaHash == dosyaHashi && b.dosyaHash.isNotEmpty,
          orElse:
              () => BelgeModeli(
                dosyaAdi: '',
                orijinalDosyaAdi: '',
                dosyaYolu: '',
                dosyaBoyutu: 0,
                dosyaTipi: '',
                dosyaHash: '',
                olusturmaTarihi: DateTime.now(),
                guncellemeTarihi: DateTime.now(),
                kategoriId: 1,
              ),
        );

        if (ayniHashBelge.dosyaAdi.isNotEmpty) {
          // Aynı dosya bulundu - sadece metadata'yı güncelle
          _addLog(
            '🔍 Aynı hash\'e sahip dosya bulundu: ${ayniHashBelge.dosyaAdi}',
          );
          _addLog('💾 Duplicate dosya önlendi, metadata güncelleniyor...');

          // Dosyayı diskten sil (gereksiz)
          await dosya.delete();
          _addLog('🗑️ Duplicate dosya diskten silindi');

          // Sadece metadata'yı güncelle
          await _updateDocumentMetadata(ayniHashBelge, belgeData, ip);
          return; // İşlemi burada sonlandır
        }

        // Kişi ID'sini eşleştir (ad-soyad kombinasyonuna göre)
        int? eslestirilenKisiId;
        if (belgeData['kisiId'] != null) {
          try {
            // Uzak cihazdan gelen kişi listesinden bu ID'ye sahip kişiyi bul
            final uzakKisiler = await _getRemotePeople(ip);
            final uzakKisi = uzakKisiler.firstWhere(
              (k) => k['id'] == belgeData['kisiId'],
              orElse: () => <String, dynamic>{},
            );

            if (uzakKisi.isNotEmpty) {
              // Yerel veritabanında aynı ad-soyad kombinasyonuna sahip kişiyi ara
              final yerelKisiler = await veriTabani.kisileriGetir();
              final eslestirilenKisi = yerelKisiler.firstWhere(
                (k) => k.ad == uzakKisi['ad'] && k.soyad == uzakKisi['soyad'],
                orElse:
                    () => KisiModeli(
                      ad: '',
                      soyad: '',
                      olusturmaTarihi: DateTime.now(),
                      guncellemeTarihi: DateTime.now(),
                    ),
              );

              if (eslestirilenKisi.ad.isNotEmpty) {
                eslestirilenKisiId = eslestirilenKisi.id;
                _addLog('👤 Kişi eşleştirildi: ${eslestirilenKisi.tamAd}');
              } else {
                // Kişi yoksa ekle
                final yeniKisi = KisiModeli(
                  ad: uzakKisi['ad'],
                  soyad: uzakKisi['soyad'],
                  olusturmaTarihi: DateTime.parse(uzakKisi['olusturmaTarihi']),
                  guncellemeTarihi: DateTime.parse(
                    uzakKisi['guncellemeTarihi'],
                  ),
                  aktif: uzakKisi['aktif'] ?? true,
                );

                final kisiId = await veriTabani.kisiEkle(yeniKisi);
                eslestirilenKisiId = kisiId;
                _addLog('👤 Yeni kişi eklendi: ${yeniKisi.tamAd}');
              }
            }
          } catch (e) {
            _addLog('⚠️ Kişi eşleştirme hatası: $e');
            eslestirilenKisiId = null;
          }
        }

        final yeniBelge = BelgeModeli(
          dosyaAdi: dosyaAdi,
          orijinalDosyaAdi: belgeData['dosyaAdi'] ?? dosyaAdi,
          dosyaYolu: yeniDosyaYolu,
          dosyaBoyutu: response.bodyBytes.length,
          dosyaTipi: belgeData['dosyaTipi'] ?? 'unknown',
          dosyaHash: dosyaHashi, // Hesaplanan hash kullan
          olusturmaTarihi: DateTime.parse(belgeData['olusturmaTarihi']),
          guncellemeTarihi: DateTime.now(),
          kategoriId: belgeData['kategoriId'] ?? 1,
          baslik: belgeData['baslik'],
          aciklama: belgeData['aciklama'],
          kisiId: eslestirilenKisiId, // Eşleştirilen kişi ID'si
          etiketler:
              belgeData['etiketler'] != null
                  ? List<String>.from(belgeData['etiketler'])
                  : null,
        );

        if (isUpdate) {
          // Mevcut belgeyi bul ve güncelle
          final mevcutBelgeler = await veriTabani.belgeleriGetir();
          final mevcutBelge = mevcutBelgeler.firstWhere(
            (b) => b.dosyaAdi == dosyaAdi,
            orElse:
                () => BelgeModeli(
                  dosyaAdi: '',
                  orijinalDosyaAdi: '',
                  dosyaYolu: '',
                  dosyaBoyutu: 0,
                  dosyaTipi: '',
                  dosyaHash: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                  kategoriId: 1,
                  baslik: '',
                  aciklama: '',
                ),
          );

          if (mevcutBelge.dosyaAdi.isNotEmpty) {
            // Mevcut belgeyi güncelle (ID'yi koru)
            final guncellenmisBelge = yeniBelge.copyWith(id: mevcutBelge.id);
            await veriTabani.belgeGuncelle(guncellenmisBelge);
            _addLog('🔄 Mevcut belge güncellendi: $dosyaAdi');
          } else {
            // Belge bulunamadı, yeni ekle
            await veriTabani.belgeEkle(yeniBelge);
            _addLog('📥 Yeni belge eklendi: $dosyaAdi');
          }
        } else {
          // Normal ekleme
          await veriTabani.belgeEkle(yeniBelge);
        }

        // Kişi bilgilerini log'a ekle
        String logMesaji = '✅ İndirildi: $dosyaAdi';
        if (yeniBelge.kisiId != null) {
          try {
            final kisi = await veriTabani.kisiGetir(yeniBelge.kisiId!);
            if (kisi != null) {
              logMesaji += ' (${kisi.tamAd})';
            }
          } catch (e) {
            // Kişi bulunamadıysa sessizce devam et
          }
        }
        if (yeniBelge.baslik != null && yeniBelge.baslik!.isNotEmpty) {
          logMesaji += ' - ${yeniBelge.baslik}';
        }
        _addLog(logMesaji);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ İndirme hatası (${belgeData['dosyaAdi']}): $e');
      rethrow; // Hatayı üst seviyeye fırlat
    }
  }

  // Yerel belgeyi uzak cihaza yükle
  Future<void> _uploadDocument(BelgeModeli belge, String ip) async {
    try {
      _addLog('📤 Yükleniyor: ${belge.dosyaAdi}');

      // Dosya içeriğini oku
      final dosya = File(belge.dosyaYolu);
      if (!await dosya.exists()) {
        throw Exception('Dosya bulunamadı: ${belge.dosyaYolu}');
      }

      final dosyaBytes = await dosya.readAsBytes();

      // Multipart request oluştur
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://$ip:8080/upload'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          dosyaBytes,
          filename: belge.dosyaAdi,
        ),
      );

      // Kişi bilgilerini al
      String? kisiAd;
      String? kisiSoyad;
      if (belge.kisiId != null) {
        try {
          final veriTabani = VeriTabaniServisi();
          final kisi = await veriTabani.kisiGetir(belge.kisiId!);
          if (kisi != null) {
            kisiAd = kisi.ad;
            kisiSoyad = kisi.soyad;
          }
        } catch (e) {
          _addLog('⚠️ Kişi bilgisi alınamadı: $e');
        }
      }

      // Belge metadata'sını ekle (kişi ad-soyad ile)
      request.fields['metadata'] = json.encode({
        'dosyaAdi': belge.dosyaAdi,
        'kategoriId': belge.kategoriId,
        'baslik': belge.baslik,
        'aciklama': belge.aciklama,
        'kisiId': belge.kisiId,
        'kisiAd': kisiAd, // Kişi adı
        'kisiSoyad': kisiSoyad, // Kişi soyadı
        'etiketler': belge.etiketler,
        'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
        'guncellemeTarihi':
            belge.guncellemeTarihi
                .toIso8601String(), // CONFLICT RESOLUTION için
      });

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        _addLog('✅ Yüklendi: ${belge.dosyaAdi}');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Yükleme hatası (${belge.dosyaAdi}): $e');
      rethrow; // Hatayı üst seviyeye fırlat
    }
  }

  // Uzak cihazdan kategorileri al
  Future<List<Map<String, dynamic>>> _getRemoteCategories(String ip) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$ip:8080/categories'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['categories'] ?? []);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Uzak kategoriler alınamadı: $e');
      return [];
    }
  }

  // Uzak cihazdan kişileri al
  Future<List<Map<String, dynamic>>> _getRemotePeople(String ip) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$ip:8080/people'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['people'] ?? []);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Uzak kişiler alınamadı: $e');
      return [];
    }
  }

  // Kategorileri senkronize et
  Future<void> _syncCategories(
    List<Map<String, dynamic>> uzakKategoriler,
    List<dynamic> yerelKategoriler,
  ) async {
    try {
      final veriTabani = VeriTabaniServisi();
      int eklenenKategoriSayisi = 0;

      // Uzak kategorileri kontrol et ve eksik olanları ekle
      for (final uzakKategori in uzakKategoriler) {
        // Null kontrolü yap
        final uzakKategoriAdi =
            uzakKategori['ad'] ?? uzakKategori['kategoriAdi'];
        if (uzakKategoriAdi == null || uzakKategoriAdi.isEmpty) {
          _addLog('⚠️ Geçersiz uzak kategori adı: $uzakKategori');
          continue;
        }

        final mevcutKategori = yerelKategoriler.any((yerel) {
          try {
            return yerel.kategoriAdi == uzakKategoriAdi;
          } catch (e) {
            _addLog('⚠️ Yerel kategori kontrolü hatası: $e');
            return false;
          }
        });

        if (!mevcutKategori) {
          // Yeni kategori modeli oluştur (null kontrolü ile)
          final yeniKategori = KategoriModeli(
            kategoriAdi: uzakKategoriAdi,
            renkKodu: uzakKategori['renkKodu'] ?? '#2196F3',
            simgeKodu: uzakKategori['simgeKodu'] ?? 'folder',
            ustKategoriId: uzakKategori['ustKategoriId'],
            aciklama: uzakKategori['aciklama'] ?? '',
            olusturmaTarihi: DateTime.parse(
              uzakKategori['olusturmaTarihi'] ??
                  DateTime.now().toIso8601String(),
            ),
            aktif: uzakKategori['aktif'] ?? true,
          );

          await veriTabani.kategoriEkle(yeniKategori);
          eklenenKategoriSayisi++;
          _addLog('📋 Kategori eklendi: $uzakKategoriAdi');
        }
      }

      _addLog('✅ Kategoriler senkronize edildi: $eklenenKategoriSayisi yeni');
    } catch (e) {
      _addLog('❌ Kategori senkronizasyon hatası: $e');
    }
  }

  // Kişileri senkronize et
  Future<void> _syncPeople(
    List<Map<String, dynamic>> uzakKisiler,
    List<dynamic> yerelKisiler,
  ) async {
    try {
      final veriTabani = VeriTabaniServisi();
      int eklenenKisiSayisi = 0;

      // Uzak kişileri kontrol et ve eksik olanları ekle
      for (final uzakKisi in uzakKisiler) {
        final mevcutKisi = yerelKisiler.any(
          (yerel) =>
              yerel.ad == uzakKisi['ad'] && yerel.soyad == uzakKisi['soyad'],
        );

        if (!mevcutKisi) {
          // Yeni kişi modeli oluştur
          final yeniKisi = KisiModeli(
            ad: uzakKisi['ad'],
            soyad: uzakKisi['soyad'],
            olusturmaTarihi: DateTime.parse(uzakKisi['olusturmaTarihi']),
            guncellemeTarihi: DateTime.parse(uzakKisi['guncellemeTarihi']),
            aktif: uzakKisi['aktif'] ?? true,
          );

          await veriTabani.kisiEkle(yeniKisi);
          eklenenKisiSayisi++;
          _addLog('👤 Kişi eklendi: ${uzakKisi['ad']} ${uzakKisi['soyad']}');
        }
      }

      _addLog('✅ Kişiler senkronize edildi: $eklenenKisiSayisi yeni');
    } catch (e) {
      _addLog('❌ Kişi senkronizasyon hatası: $e');
    }
  }

  // Helper metodlar
  void _updateProgress(double progress, String? operation) {
    onProgressUpdate?.call(progress);
    if (operation != null) {
      onOperationUpdate?.call(operation);
    }
  }

  void _addLog(String message) {
    print('🔄 SYNC: $message'); // Console'a da yazdır
    onLogMessage?.call(message);
  }

  // Aynı dosya için sadece metadata'yı güncelle (dosyayı indirme)
  Future<void> _updateDocumentMetadata(
    BelgeModeli yerelBelge,
    Map<String, dynamic> uzakBelge,
    String ip,
  ) async {
    try {
      final veriTabani = VeriTabaniServisi();

      // Kişi ID'sini eşleştir
      int? eslestirilenKisiId;
      if (uzakBelge['kisiId'] != null) {
        try {
          final uzakKisiler = await _getRemotePeople(ip);
          final uzakKisi = uzakKisiler.firstWhere(
            (k) => k['id'] == uzakBelge['kisiId'],
            orElse: () => <String, dynamic>{},
          );

          if (uzakKisi.isNotEmpty) {
            final yerelKisiler = await veriTabani.kisileriGetir();
            final eslestirilenKisi = yerelKisiler.firstWhere(
              (k) => k.ad == uzakKisi['ad'] && k.soyad == uzakKisi['soyad'],
              orElse:
                  () => KisiModeli(
                    ad: '',
                    soyad: '',
                    olusturmaTarihi: DateTime.now(),
                    guncellemeTarihi: DateTime.now(),
                  ),
            );

            if (eslestirilenKisi.ad.isNotEmpty) {
              eslestirilenKisiId = eslestirilenKisi.id;
            }
          }
        } catch (e) {
          _addLog('⚠️ Metadata kişi eşleştirme hatası: $e');
        }
      }

      // Güncellenen belge modelini oluştur
      final guncelBelge = yerelBelge.copyWith(
        baslik: uzakBelge['baslik'],
        aciklama: uzakBelge['aciklama'],
        kisiId: eslestirilenKisiId ?? yerelBelge.kisiId,
        kategoriId: uzakBelge['kategoriId'] ?? yerelBelge.kategoriId,
        etiketler:
            uzakBelge['etiketler'] != null
                ? List<String>.from(uzakBelge['etiketler'])
                : yerelBelge.etiketler,
        guncellemeTarihi: DateTime.parse(
          uzakBelge['guncellemeTarihi'] ?? uzakBelge['olusturmaTarihi'],
        ),
      );

      // Veritabanında güncelle
      await veriTabani.belgeGuncelle(guncelBelge);

      _addLog('📝 Metadata güncellendi: ${yerelBelge.dosyaAdi}');
      _addLog('   • Başlık: ${uzakBelge['baslik'] ?? 'Yok'}');
      _addLog('   • Açıklama: ${uzakBelge['aciklama'] ?? 'Yok'}');
    } catch (e) {
      _addLog('❌ Metadata güncelleme hatası: $e');
      rethrow;
    }
  }

  // Callback'leri ayarla
  void setCallbacks({
    Function(double)? onProgress,
    Function(String)? onOperation,
    Function(String)? onLog,
  }) {
    onProgressUpdate = onProgress;
    onOperationUpdate = onOperation;
    onLogMessage = onLog;
  }
}
