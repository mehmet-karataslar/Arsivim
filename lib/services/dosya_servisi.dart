import 'log_servisi.dart';
import 'package:flutter/foundation.dart' show compute;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/belge_modeli.dart';
import 'depolama_konumu_servisi.dart';
import 'scan_image_compression.dart';
import '../utils/sabitler.dart';
import '../utils/yardimci_fonksiyonlar.dart';

// Dosya işlemleri servisi
class DosyaServisi {
  static final DosyaServisi _instance = DosyaServisi._internal();
  factory DosyaServisi() => _instance;
  DosyaServisi._internal();

  // Dosya seçme
  Future<List<PlatformFile>?> dosyaSec({
    List<String>? izinVerilenUzantilar,
    bool cokluSecim = false,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: izinVerilenUzantilar == null ? FileType.any : FileType.custom,
        allowedExtensions: izinVerilenUzantilar,
        allowMultiple: cokluSecim,
      );

      if (result != null) {
        return result.files;
      }
      return null;
    } catch (e) {
      throw Exception('Dosya seçilirken hata oluştu: $e');
    }
  }

  // Dosya kopyalama ve hash hesaplama
  Future<BelgeModeli> dosyaKopyalaVeHashHesapla(
    PlatformFile platformFile, {
    Directory? outputDirectory,
  }) async {
    Directory? yeniKlasor;
    var tamamlandi = false;
    try {
      if (platformFile.path == null) {
        throw Exception('Dosya yolu bulunamadı');
      }

      File kaynak = File(platformFile.path!);
      if (!await kaynak.exists()) {
        throw Exception('Kaynak dosya bulunamadı');
      }

      // Hedef klasörü oluştur
      Directory belgelerKlasoru = outputDirectory ?? await _belgelerKlasorunu();
      await belgelerKlasoru.create(recursive: true);
      yeniKlasor = await belgelerKlasoru.createTemp('eklenen-');

      // Benzersiz dosya adı oluştur
      String dosyaUzantisi = path.extension(platformFile.name);
      String temelAd = path.basenameWithoutExtension(platformFile.name);
      String guvenliTemelAd = YardimciFonksiyonlar.guvenliDosyaAdi(temelAd);
      String yeniDosyaAdi = YardimciFonksiyonlar.benzersizDosyaAdi(
        guvenliTemelAd,
        dosyaUzantisi.isEmpty ? '' : dosyaUzantisi.substring(1),
      );

      String hedefYol = path.join(yeniKlasor.path, yeniDosyaAdi);

      // Dosyayı kopyala
      File hedefDosya = await kaynak.copy(hedefYol);

      // Hash hesapla
      String dosyaHash =
          (await sha256.bind(hedefDosya.openRead()).first).toString();
      if (await kaynak.length() != await hedefDosya.length() ||
          await dosyaHashiHesapla(kaynak.path) != dosyaHash) {
        throw StateError(
          'Kaynak dosya kopyalama sırasında değişti. Yeniden deneyin.',
        );
      }

      // Belge modeli oluştur
      DateTime simdi = DateTime.now();
      BelgeModeli belge = BelgeModeli(
        dosyaAdi: yeniDosyaAdi,
        orijinalDosyaAdi: platformFile.name,
        dosyaYolu: hedefYol,
        dosyaBoyutu: await hedefDosya.length(),
        dosyaTipi:
            dosyaUzantisi.isEmpty
                ? ''
                : dosyaUzantisi.substring(1).toLowerCase(),
        dosyaHash: dosyaHash,
        olusturmaTarihi: simdi,
        guncellemeTarihi: simdi,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      tamamlandi = true;
      return belge;
    } catch (e) {
      throw Exception('Dosya işlenirken hata oluştu: $e');
    } finally {
      if (!tamamlandi && yeniKlasor != null && await yeniKlasor.exists()) {
        await yeniKlasor.delete(recursive: true);
      }
    }
  }

  // Belgeler klasörünü al/oluştur
  Future<Directory> _belgelerKlasorunu() async {
    return await DepolamaKonumuServisi.instance.belgelerKlasoru();
  }

  // Dosya var mı kontrolü
  Future<bool> dosyaVarMi(String dosyaYolu) async {
    return await File(dosyaYolu).exists();
  }

  // Dosya sil
  Future<bool> dosyaSil(String dosyaYolu) async {
    try {
      File dosya = File(dosyaYolu);
      if (await dosya.exists()) {
        await dosya.delete();
        return true;
      }
      return false;
    } catch (e) {
      LogServisi.instance.error('Dosya silinirken hata: $e');
      return false;
    }
  }

  // Hash'e göre dosya bul
  Future<String?> hashtenDosyaBul(String hash) async {
    try {
      Directory belgelerDir = await _belgelerKlasorunu();
      await for (final entity in belgelerDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          String dosyaHash =
              (await sha256.bind(entity.openRead()).first).toString();
          if (dosyaHash == hash) {
            return entity.path;
          }
        }
      }
      return null;
    } catch (e) {
      LogServisi.instance.error('Hash arama hatası: $e');
      return null;
    }
  }

  // Dosya boyutunu al
  Future<int> dosyaBoyutuAl(String dosyaYolu) async {
    try {
      File dosya = File(dosyaYolu);
      if (await dosya.exists()) {
        return await dosya.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Belgeler klasörü boyutunu hesapla
  Future<int> toplamKlasorBoyutu() async {
    try {
      Directory belgelerDir = await _belgelerKlasorunu();
      int toplamBoyut = 0;

      await for (FileSystemEntity entity in belgelerDir.list(recursive: true)) {
        if (entity is File) {
          toplamBoyut += await entity.length();
        }
      }

      return toplamBoyut;
    } catch (e) {
      return 0;
    }
  }

  // Belgeler klasörü yolunu al
  Future<String> belgelerKlasoruYolu() async {
    Directory dir = await _belgelerKlasorunu();
    return dir.path;
  }

  // Dosya tipine göre filtrele
  List<String> dosyaTipineGoreFiltrele(List<String> dosyaTipleri) {
    return dosyaTipleri
        .where(
          (tip) =>
              Sabitler.DESTEKLENEN_DOSYA_TIPLERI.contains(tip.toLowerCase()),
        )
        .toList();
  }

  // Geçici dosya oluştur
  Future<File> geciciDosyaOlustur(String icerik, String dosyaAdi) async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = path.join(tempDir.path, dosyaAdi);
    File tempFile = File(tempPath);
    await tempFile.writeAsString(icerik);
    return tempFile;
  }

  // Dosya hash'ini hesapla
  static Future<String> dosyaHashiHesapla(String dosyaYolu) async {
    try {
      File dosya = File(dosyaYolu);
      return (await sha256.bind(dosya.openRead()).first).toString();
    } catch (e) {
      throw Exception('Hash hesaplanamadı: $e');
    }
  }

  // Dosya bilgilerini al
  Future<Map<String, dynamic>> dosyaBilgileriAl(String dosyaYolu) async {
    try {
      File dosya = File(dosyaYolu);
      FileStat stat = await dosya.stat();

      return {
        'boyut': stat.size,
        'olusturma_tarihi': stat.changed,
        'degisiklik_tarihi': stat.modified,
        'erisim_tarihi': stat.accessed,
        'tip': stat.type.toString(),
        'mod': stat.mode,
      };
    } catch (e) {
      throw Exception('Dosya bilgileri alınamadı: $e');
    }
  }

  // Taranan fotoğrafları PDF'e dönüştür ve kaydet
  Future<BelgeModeli> tarananFotograflariPdfYap(
    List<String> fotografYollari,
    String pdfAdi, {
    Directory? outputDirectory,
    List<int>? quarterTurns,
    List<bool>? compressedPages,
    Directory? pageCopiesDirectory,
  }) async {
    try {
      if (quarterTurns != null &&
          quarterTurns.length != fotografYollari.length) {
        throw ArgumentError('Sayfa yönleri eksik.');
      }
      if (compressedPages != null &&
          compressedPages.length != fotografYollari.length) {
        throw ArgumentError('Sayfa sıkıştırma bilgisi eksik.');
      }
      final pdfBytes = await compute(_scanPdfBytes, {
        'paths': fotografYollari,
        'turns': quarterTurns ?? List.filled(fotografYollari.length, 0),
        'compressed':
            compressedPages ?? List.filled(fotografYollari.length, false),
        'copies': pageCopiesDirectory?.path,
      });

      // Hedef klasörü oluştur
      Directory belgelerKlasoru = outputDirectory ?? await _belgelerKlasorunu();

      await belgelerKlasoru.create(recursive: true);

      // Benzersiz PDF dosya adı oluştur
      String temelAd = path.basenameWithoutExtension(pdfAdi);
      String guvenliTemelAd = YardimciFonksiyonlar.guvenliDosyaAdi(temelAd);
      String yeniDosyaAdi = YardimciFonksiyonlar.benzersizDosyaAdi(
        guvenliTemelAd,
        'pdf',
      );

      String hedefYol = path.join(belgelerKlasoru.path, yeniDosyaAdi);

      // PDF'i kaydet
      File pdfDosyasi = File(hedefYol);
      await pdfDosyasi.writeAsBytes(pdfBytes);

      // Hash hesapla
      String dosyaHash = sha256.convert(pdfBytes).toString();

      // Belge modeli oluştur
      DateTime simdi = DateTime.now();
      BelgeModeli belge = BelgeModeli(
        dosyaAdi: yeniDosyaAdi,
        orijinalDosyaAdi: pdfAdi,
        dosyaYolu: hedefYol,
        dosyaBoyutu: pdfBytes.length,
        dosyaTipi: 'pdf',
        dosyaHash: dosyaHash,
        olusturmaTarihi: simdi,
        guncellemeTarihi: simdi,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      return belge;
    } catch (e) {
      throw Exception('PDF oluşturulurken hata oluştu: $e');
    }
  }

  // Taranan fotoğraf dosyasını işle ve kopyala (eskiden kalma - artık kullanmıyoruz)
  Future<BelgeModeli> tarananFotografiIsle(
    String dosyaYolu,
    String orijinalAd,
  ) async {
    try {
      File kaynak = File(dosyaYolu);
      if (!await kaynak.exists()) {
        throw Exception('Kaynak dosya bulunamadı');
      }

      // Hedef klasörü oluştur
      Directory belgelerKlasoru = await _belgelerKlasorunu();

      // Benzersiz dosya adı oluştur
      String dosyaUzantisi = path.extension(orijinalAd);
      String temelAd = path.basenameWithoutExtension(orijinalAd);
      String guvenliTemelAd = YardimciFonksiyonlar.guvenliDosyaAdi(temelAd);
      String yeniDosyaAdi = YardimciFonksiyonlar.benzersizDosyaAdi(
        guvenliTemelAd,
        dosyaUzantisi.substring(1),
      );

      String hedefYol = path.join(belgelerKlasoru.path, yeniDosyaAdi);

      // Dosyayı kopyala
      File hedefDosya = await kaynak.copy(hedefYol);

      // Dosya boyutunu al
      int dosyaBoyutu = await hedefDosya.length();

      // Hash hesapla
      Uint8List dosyaBytes = await hedefDosya.readAsBytes();
      String dosyaHash = sha256.convert(dosyaBytes).toString();

      // Belge modeli oluştur
      DateTime simdi = DateTime.now();
      BelgeModeli belge = BelgeModeli(
        dosyaAdi: yeniDosyaAdi,
        orijinalDosyaAdi: orijinalAd,
        dosyaYolu: hedefYol,
        dosyaBoyutu: dosyaBoyutu,
        dosyaTipi: dosyaUzantisi.substring(1).toLowerCase(),
        dosyaHash: dosyaHash,
        olusturmaTarihi: simdi,
        guncellemeTarihi: simdi,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      return belge;
    } catch (e) {
      throw Exception('Taranan fotoğraf işlenirken hata oluştu: $e');
    }
  }

  // Senkronizasyon dosyasını kaydet
  Future<String> senkronDosyasiKaydet(
    String dosyaAdi,
    Uint8List dosyaBytes,
  ) async {
    try {
      // Hedef klasörü oluştur
      Directory belgelerKlasoru = await _belgelerKlasorunu();

      // Dosya adını güvenli hale getir
      String dosyaUzantisi = path.extension(dosyaAdi);
      String temelAd = path.basenameWithoutExtension(dosyaAdi);
      String guvenliTemelAd = YardimciFonksiyonlar.guvenliDosyaAdi(temelAd);

      // Benzersiz dosya adı oluştur
      String yeniDosyaAdi = YardimciFonksiyonlar.benzersizDosyaAdi(
        guvenliTemelAd,
        dosyaUzantisi.isNotEmpty ? dosyaUzantisi.substring(1) : '',
      );

      String hedefYol = path.join(belgelerKlasoru.path, yeniDosyaAdi);

      // Dosyayı kaydet
      File hedefDosya = File(hedefYol);
      await hedefDosya.writeAsBytes(dosyaBytes);

      return hedefYol;
    } catch (e) {
      LogServisi.instance.error('❌ Senkronizasyon dosyası kaydetme hatası: $e');
      throw Exception('Senkronizasyon dosyası kaydedilemedi: $e');
    }
  }
}

// Image decoding and PDF compression run off the UI isolate on mobile/desktop.
Future<Uint8List> _scanPdfBytes(Map<String, dynamic> request) async {
  final paths = request['paths'] as List<String>;
  final turns = request['turns'] as List<int>;
  final compressed = request['compressed'] as List<bool>;
  final copies = request['copies'] as String?;
  final pdf = pw.Document(compress: true);
  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    final file = File(path);
    if (!await file.exists()) throw StateError('Taranan sayfa bulunamadı.');
    final source = await file.readAsBytes();
    final bytes =
        compressed[i] ? source : ScanImageCompression.compress(source);
    if (copies != null) {
      await File('$copies/page-$i.jpg').writeAsBytes(bytes, flush: true);
    }
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build:
            (_) => pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Transform.rotateBox(
                  angle: -(turns[i] % 4) * math.pi / 2,
                  unconstrained: true,
                  child: pw.Image(
                    pw.MemoryImage(bytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ),
      ),
    );
  }
  if (paths.isEmpty) throw StateError('Taranan sayfa yok.');
  return pdf.save();
}
