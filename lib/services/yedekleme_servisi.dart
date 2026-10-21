import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models/kategori_modeli.dart';
import '../models/backup_overview.dart';
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
  Future<BackupRecord> kisiVeKategoriYedeklemeYap(
    List<int> kisiIds,
    String hedefKlasorYolu, {
    Map<int, List<int>>? kategoriSecimi,
    Function(double progress, String operation)? onProgress,
  }) async {
    try {
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

      final selectedDocuments = <int, List<BelgeModeli>>{};
      for (final kisi in yedeklenecekKisiler) {
        final filter =
            kategoriSecimi == null
                ? null
                : (kategoriSecimi[kisi.id!] ?? <int>[]);
        selectedDocuments[kisi.id!] =
            (await _veriTabani.kisiBelgeleriniGetir(
              kisi.id!,
            )).where((document) => backupIncludes(document, filter)).toList();
      }
      final toplamBelgeSayisi = selectedDocuments.values.fold<int>(
        0,
        (sum, docs) => sum + docs.length,
      );
      if (toplamBelgeSayisi == 0) {
        throw Exception('Seçimle eşleşen belge bulunamadı.');
      }
      final output = await Directory(
        hedefKlasorYolu,
      ).createTemp('Arsiv-Yedek-');
      hedefKlasorYolu = output.path;

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
        final kisiBelgeleri = selectedDocuments[kisi.id!]!;

        // Belgeleri kategorilere göre grupla - sadece seçilen kategoriler
        final kategorilereGoreGruplar = <int, List<BelgeModeli>>{};
        final filter =
            kategoriSecimi == null
                ? null
                : (kategoriSecimi[kisi.id!] ?? <int>[]);
        final secilenKategoriler = filter ?? <int>[];

        for (final belge in kisiBelgeleri) {
          final matches =
              belge.tumKategoriIds.where(secilenKategoriler.contains).toList();
          final kategoriId =
              matches.isNotEmpty
                  ? matches.first
                  : (belge.kategoriId ?? belge.tumKategoriIds.firstOrNull ?? 0);

          // Eğer kategori seçimi yapılmışsa, sadece seçilen kategorileri dahil et
          if (!backupIncludes(belge, filter)) {
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
            for (final k in kisiler.where(
              (k) =>
                  yedeklenecekKisiler.any((p) => p.id == k.id) ||
                  manifest.any(
                    (b) => BelgeModeli.idsCoz(b['kisi_ids']).contains(k.id),
                  ),
            ))
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
      if (hatalar.isNotEmpty) {
        throw Exception(
          '${hatalar.length} dosya yedeklenemedi. Ayrintilar: $hedefKlasorYolu/manifest.json',
        );
      }
      // Yedekleme tamamlandı
      final time = DateTime.now();
      await HomePreferences.recordBackup(time);
      onProgress?.call(1.0, 'Yedekleme başarıyla tamamlandı!');
      return BackupRecord(
        time: time,
        path: hedefKlasorYolu,
        people: yedeklenecekKisiler.length,
        categories:
            kategoriSecimi == null
                ? manifest
                    .expand((b) {
                      final ids = BelgeModeli.fromMap(b).tumKategoriIds;
                      return ids.isEmpty ? [0] : ids;
                    })
                    .toSet()
                    .length
                : kategoriSecimi.values.expand((ids) => ids).toSet().length,
        documents: manifest.map((b) => b['id']).toSet().length,
        bytes: manifest.fold<int>(
          0,
          (sum, b) => sum + (b['dosya_boyutu'] as int),
        ),
      );
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
    if (kaynakDosyaYolu.isEmpty) {
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
