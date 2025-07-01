import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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

        final yerelBelge = yerelBelgeler.firstWhere(
          (belge) => belge.dosyaAdi == uzakBelge['dosyaAdi'],
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

        if (yerelBelge.dosyaAdi.isEmpty) {
          // Yeni belge - indir
          await _downloadDocument(uzakBelge, bagliBulunanCihaz.ip);
          yeniBelgeSayisi++;
          _addLog('📥 Yeni belge eklendi: ${uzakBelge['dosyaAdi']}');
        } else {
          // Mevcut belge - tarih kontrolü
          final uzakTarih = DateTime.parse(uzakBelge['olusturmaTarihi']);
          if (uzakTarih.isAfter(yerelBelge.olusturmaTarihi)) {
            await _downloadDocument(uzakBelge, bagliBulunanCihaz.ip);
            guncellenmisBelgeSayisi++;
            _addLog('🔄 Belge güncellendi: ${uzakBelge['dosyaAdi']}');
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

        final uzakBelgeVar = uzakBelgeler.any(
          (uzakBelge) => uzakBelge['dosyaAdi'] == yerelBelge.dosyaAdi,
        );

        if (!uzakBelgeVar) {
          await _uploadDocument(yerelBelge, bagliBulunanCihaz.ip);
          gonderilmiBelgeSayisi++;
          _addLog('📤 Belge gönderildi: ${yerelBelge.dosyaAdi}');
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
    String ip,
  ) async {
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

        // Veritabanına ekle
        final veriTabani = VeriTabaniServisi();
        final yeniBelge = BelgeModeli(
          dosyaAdi: dosyaAdi,
          orijinalDosyaAdi: belgeData['dosyaAdi'] ?? dosyaAdi,
          dosyaYolu: yeniDosyaYolu,
          dosyaBoyutu: response.bodyBytes.length,
          dosyaTipi: belgeData['dosyaTipi'] ?? 'unknown',
          dosyaHash: belgeData['dosyaHash'] ?? '',
          olusturmaTarihi: DateTime.parse(belgeData['olusturmaTarihi']),
          guncellemeTarihi: DateTime.now(),
          kategoriId: belgeData['kategoriId'] ?? 1,
          baslik: belgeData['baslik'],
          aciklama: belgeData['aciklama'],
          kisiId: belgeData['kisiId'],
          etiketler:
              belgeData['etiketler'] != null
                  ? List<String>.from(belgeData['etiketler'])
                  : null,
        );

        await veriTabani.belgeEkle(yeniBelge);

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

      // Belge metadata'sını ekle
      request.fields['metadata'] = json.encode({
        'dosyaAdi': belge.dosyaAdi,
        'kategoriId': belge.kategoriId,
        'baslik': belge.baslik,
        'aciklama': belge.aciklama,
        'kisiId': belge.kisiId,
        'etiketler': belge.etiketler,
        'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
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
        final mevcutKategori = yerelKategoriler.any(
          (yerel) => yerel.kategoriAdi == uzakKategori['kategoriAdi'],
        );

        if (!mevcutKategori) {
          // Yeni kategori modeli oluştur
          final yeniKategori = KategoriModeli(
            kategoriAdi: uzakKategori['kategoriAdi'],
            renkKodu: uzakKategori['renkKodu'] ?? '#2196F3',
            simgeKodu: uzakKategori['simgeKodu'] ?? 'folder',
            ustKategoriId: uzakKategori['ustKategoriId'],
            aciklama: uzakKategori['aciklama'],
            olusturmaTarihi: DateTime.parse(uzakKategori['olusturmaTarihi']),
            aktif: uzakKategori['aktif'] ?? true,
          );

          await veriTabani.kategoriEkle(yeniKategori);
          eklenenKategoriSayisi++;
          _addLog('📋 Kategori eklendi: ${uzakKategori['kategoriAdi']}');
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
    onLogMessage?.call(message);
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
