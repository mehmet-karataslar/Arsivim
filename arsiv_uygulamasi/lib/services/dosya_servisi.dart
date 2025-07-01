import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/belge_modeli.dart';
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
        type: FileType.custom,
        allowedExtensions:
            izinVerilenUzantilar ?? Sabitler.DESTEKLENEN_DOSYA_TIPLERI,
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
    PlatformFile platformFile,
  ) async {
    try {
      if (platformFile.path == null) {
        throw Exception('Dosya yolu bulunamadı');
      }

      File kaynak = File(platformFile.path!);
      if (!await kaynak.exists()) {
        throw Exception('Kaynak dosya bulunamadı');
      }

      // Hedef klasörü oluştur
      Directory belgelerKlasoru = await _belgelerKlasorunu();

      // Benzersiz dosya adı oluştur
      String dosyaUzantisi = path.extension(platformFile.name);
      String temelAd = path.basenameWithoutExtension(platformFile.name);
      String guvenliTemelAd = YardimciFonksiyonlar.guvenliDosyaAdi(temelAd);
      String yeniDosyaAdi = YardimciFonksiyonlar.benzersizDosyaAdi(
        guvenliTemelAd,
        dosyaUzantisi.substring(1),
      );

      String hedefYol = path.join(belgelerKlasoru.path, yeniDosyaAdi);

      // Dosyayı kopyala
      File hedefDosya = await kaynak.copy(hedefYol);

      // Hash hesapla
      Uint8List dosyaBytes = await hedefDosya.readAsBytes();
      String dosyaHash = sha256.convert(dosyaBytes).toString();

      // Belge modeli oluştur
      DateTime simdi = DateTime.now();
      BelgeModeli belge = BelgeModeli(
        dosyaAdi: yeniDosyaAdi,
        orijinalDosyaAdi: platformFile.name,
        dosyaYolu: hedefYol,
        dosyaBoyutu: platformFile.size,
        dosyaTipi: dosyaUzantisi.substring(1).toLowerCase(),
        dosyaHash: dosyaHash,
        olusturmaTarihi: simdi,
        guncellemeTarihi: simdi,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      return belge;
    } catch (e) {
      throw Exception('Dosya işlenirken hata oluştu: $e');
    }
  }

  // Belgeler klasörünü al/oluştur
  Future<Directory> _belgelerKlasorunu() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    Directory belgelerDir = Directory(
      path.join(appDir.path, Sabitler.BELGELER_KLASORU),
    );

    if (!await belgelerDir.exists()) {
      await belgelerDir.create(recursive: true);
    }

    return belgelerDir;
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
      print('Dosya silinirken hata: $e');
      return false;
    }
  }

  // Hash'e göre dosya bul
  Future<String?> hashtenDosyaBul(String hash) async {
    try {
      Directory belgelerDir = await _belgelerKlasorunu();
      List<FileSystemEntity> dosyalar = await belgelerDir.list().toList();

      for (FileSystemEntity entity in dosyalar) {
        if (entity is File) {
          Uint8List bytes = await entity.readAsBytes();
          String dosyaHash = sha256.convert(bytes).toString();
          if (dosyaHash == hash) {
            return entity.path;
          }
        }
      }
      return null;
    } catch (e) {
      print('Hash arama hatası: $e');
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
      Uint8List bytes = await dosya.readAsBytes();
      return sha256.convert(bytes).toString();
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
}
