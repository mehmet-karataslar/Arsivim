import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models/kategori_modeli.dart';
import '../models/belge_modeli.dart';
import '../services/veritabani_servisi.dart';
import 'home_preferences.dart';

class YedeklemeServisi {
  final VeriTabaniServisi _veriTabani;
  YedeklemeServisi({VeriTabaniServisi? veriTabani})
    : _veriTabani = veriTabani ?? VeriTabaniServisi();

  /// Kişi ve kategori bazında yedekleme yapar
  /// [kisiIds] - Yedeklenecek kişi ID'leri
  /// [hedefKlasorYolu] - Yedekleme yapılacak klasör yolu
  /// [kategoriSecimi] - Kişi bazında seçilen kategori ID'leri (kisiId -> kategoriIds)
  /// [onProgress] - İlerleme callback'i (0.0 - 1.0 arası ve işlem açıklaması)
  Future<void> kisiVeKategoriYedeklemeYap(
    List<int> kisiIds,
    String hedefKlasorYolu, {
    Map<int, List<int>>? kategoriSecimi,
    Function(double progress, String operation)? onProgress,
  }) async {
    try {
      final output = await Directory(
        hedefKlasorYolu,
      ).createTemp('Arsiv-Yedek-');
      hedefKlasorYolu = output.path;
      final hatalar = <String>[];
      final manifest = <Map<String, dynamic>>[];
      // Kişi ve kategori verilerini getir
      final kisiler = await _veriTabani.kisileriGetir();
      final kategoriler = await _veriTabani.kategorileriGetir();

      // Yedeklenecek kişileri filtrele
      final yedeklenecekKisiler =
          kisiler.where((k) => kisiIds.contains(k.id)).toList();

      if (yedeklenecekKisiler.isEmpty) {
        throw Exception('Yedeklenecek kişi bulunamadı');
      }

      // Toplam işlem sayısını hesapla
      int toplamBelgeSayisi = 0;
      for (final kisi in yedeklenecekKisiler) {
        final belgeSayisi = await _veriTabani.kisiBelgeSayisi(kisi.id!);
        toplamBelgeSayisi += belgeSayisi;
      }

      int islenenBelgeSayisi = 0;

      // Her kişi için işlem yap
      for (final kisi in yedeklenecekKisiler) {
        onProgress?.call(
          toplamBelgeSayisi == 0 ? 0 : islenenBelgeSayisi / toplamBelgeSayisi,
          'Kişi hazırlanıyor: ${kisi.tamAd}',
        );

        // Kişi klasörünü oluştur
        final kisiKlasoruAdi = '${kisi.id}_${_temizleKlasorAdi(kisi.tamAd)}';
        final kisiKlasoruYolu = path.join(hedefKlasorYolu, kisiKlasoruAdi);

        await Directory(kisiKlasoruYolu).create(recursive: true);

        // Kişinin belgelerini getir
        final kisiBelgeleri = await _veriTabani.kisiBelgeleriniGetir(kisi.id!);

        // Belgeleri kategorilere göre grupla - sadece seçilen kategoriler
        final kategorilereGoreGruplar = <int, List<BelgeModeli>>{};
        final secilenKategoriler = kategoriSecimi?[kisi.id!] ?? [];

        for (final belge in kisiBelgeleri) {
          final kategoriId = belge.kategoriId ?? 0;

          // Eğer kategori seçimi yapılmışsa, sadece seçilen kategorileri dahil et
          if (secilenKategoriler.isNotEmpty &&
              !secilenKategoriler.contains(kategoriId)) {
            continue;
          }

          if (!kategorilereGoreGruplar.containsKey(kategoriId)) {
            kategorilereGoreGruplar[kategoriId] = [];
          }
          kategorilereGoreGruplar[kategoriId]!.add(belge);
        }

        // Her kategori için klasör oluştur ve belgeleri kopyala
        for (final kategoriId in kategorilereGoreGruplar.keys) {
          final kategoriAdi =
              kategoriler
                  .firstWhere(
                    (k) => k.id == kategoriId,
                    orElse:
                        () => KategoriModeli(
                          kategoriAdi: 'Kategorisiz',
                          renkKodu: '#757575',
                          simgeKodu: 'default',
                          olusturmaTarihi: DateTime.now(),
                        ),
                  )
                  .kategoriAdi;

          final kategoriKlasoruAdi =
              '${kategoriId}_${_temizleKlasorAdi(kategoriAdi)}';
          final kategoriKlasoruYolu = path.join(
            kisiKlasoruYolu,
            kategoriKlasoruAdi,
          );

          await Directory(kategoriKlasoruYolu).create(recursive: true);

          // Kategorideki belgeleri kopyala
          final kategoriBelgeleri = kategorilereGoreGruplar[kategoriId]!;
          for (final belge in kategoriBelgeleri) {
            try {
              onProgress?.call(
                islenenBelgeSayisi / toplamBelgeSayisi,
                'Kopyalanıyor: ${belge.baslik}',
              );

              final copied = await _belgeyiKopyala(belge, kategoriKlasoruYolu);
              manifest.add({
                ...belge.toMap(),
                'dosya_yolu': path.relative(copied, from: hedefKlasorYolu),
              });
              islenenBelgeSayisi++;
            } catch (e) {
              print('Belge kopyalanırken hata: ${belge.baslik} - $e');
              hatalar.add('${belge.orijinalDosyaAdi}: $e');
              // Hata durumunda da sayacı artır
              islenenBelgeSayisi++;
            }
          }
        }
      }

      await File(path.join(hedefKlasorYolu, 'manifest.json')).writeAsString(
        jsonEncode({
          'surum': 1,
          'tamamlandi': hatalar.isEmpty,
          'belgeler': manifest,
          'hatalar': hatalar,
          'kisiler': [
            for (final k in yedeklenecekKisiler)
              {
                'id': k.id,
                'ad': k.ad,
                'soyad': k.soyad,
                'kullanici_adi': k.kullaniciAdi,
              },
          ],
          'kategoriler': kategoriler.map((k) => k.toMap()).toList(),
        }),
        flush: true,
      );
      if (hatalar.isNotEmpty)
        throw Exception(
          '${hatalar.length} dosya yedeklenemedi. Ayrintilar: $hedefKlasorYolu/manifest.json',
        );
      // Yedekleme tamamlandı
      await HomePreferences.recordBackup(DateTime.now());
      onProgress?.call(1.0, 'Yedekleme başarıyla tamamlandı!');
    } catch (e) {
      throw Exception('Yedekleme sırasında hata oluştu: $e');
    }
  }

  /// Belgeyi hedef klasöre kopyalar
  Future<String> _belgeyiKopyala(
    BelgeModeli belge,
    String hedefKlasorYolu,
  ) async {
    // Kaynak dosya yolunu bul
    final kaynakDosyaYolu = belge.dosyaYolu;
    if (kaynakDosyaYolu == null || kaynakDosyaYolu.isEmpty) {
      throw Exception('Belge dosya yolu bulunamadı: ${belge.baslik}');
    }

    final kaynakDosya = File(kaynakDosyaYolu);
    if (!await kaynakDosya.exists()) {
      throw Exception('Kaynak dosya bulunamadı: $kaynakDosyaYolu');
    }

    // Hedef dosya adını oluştur
    final dosyaUzantisi = path.extension(kaynakDosyaYolu);
    final temizBaslik = _temizleDosyaAdi(belge.baslik ?? 'Belge');
    final hedefDosyaAdi = '$temizBaslik$dosyaUzantisi';
    final hedefDosyaYolu = path.join(hedefKlasorYolu, hedefDosyaAdi);

    // Aynı isimde dosya varsa numara ekle
    String finalHedefYolu = hedefDosyaYolu;
    int sayac = 1;
    while (await File(finalHedefYolu).exists()) {
      final dosyaAdiBase = path.basenameWithoutExtension(hedefDosyaAdi);
      finalHedefYolu = path.join(
        hedefKlasorYolu,
        '${dosyaAdiBase}_$sayac$dosyaUzantisi',
      );
      sayac++;
    }

    // Dosyayı kopyala
    if (await kaynakDosya.length() != belge.dosyaBoyutu ||
        (await sha256.bind(kaynakDosya.openRead()).first).toString() !=
            belge.dosyaHash) {
      throw Exception('Kaynak dosya boyutu veya hash kayitla uyusmuyor.');
    }
    final copy = await kaynakDosya.copy(finalHedefYolu);
    if (await copy.length() != belge.dosyaBoyutu ||
        (await sha256.bind(copy.openRead()).first).toString() !=
            belge.dosyaHash) {
      throw Exception('Yedek kopyasi dogrulanamadi.');
    }
    return copy.path;
  }

  /// Klasör adını temizler (geçersiz karakterleri kaldırır)
  String _temizleKlasorAdi(String ad) {
    // Windows ve diğer işletim sistemlerinde geçersiz karakterleri kaldır
    return ad
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Geçersiz karakterler
        .replaceAll(RegExp(r'\s+'), ' ') // Çoklu boşlukları tek boşluğa
        .trim();
  }

  /// Dosya adını temizler (geçersiz karakterleri kaldırır)
  String _temizleDosyaAdi(String ad) {
    // Windows ve diğer işletim sistemlerinde geçersiz karakterleri kaldır
    return ad
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Geçersiz karakterler
        .replaceAll(RegExp(r'\s+'), ' ') // Çoklu boşlukları tek boşluğa
        .trim();
  }
}
