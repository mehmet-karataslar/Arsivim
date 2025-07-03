import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'sabitler.dart';

/// Yardımcı fonksiyonlar sınıfı
class YardimciFonksiyonlar {
  /// Dosya boyutunu okunabilir formata çevir
  static String dosyaBoyutuFormatla(int boyut) {
    if (boyut < 1024) {
      return '$boyut B';
    } else if (boyut < 1024 * 1024) {
      return '${(boyut / 1024).toStringAsFixed(1)} KB';
    } else if (boyut < 1024 * 1024 * 1024) {
      return '${(boyut / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(boyut / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Dosya hash değeri hesapla (SHA-256)
  static Future<String> dosyaHashHesapla(String dosyaYolu) async {
    try {
      final file = File(dosyaYolu);
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Hash hesaplama hatası: $e');
      return '';
    }
  }

  /// Dosya hash değeri hesapla (byte array için)
  static String bytesHashHesapla(Uint8List bytes) {
    try {
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Hash hesaplama hatası: $e');
      return '';
    }
  }

  /// Tarih formatla
  static String tarihFormatla(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}/${tarih.month.toString().padLeft(2, '0')}/${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}';
  }

  /// Kısa tarih formatla
  static String kisaTarihFormatla(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}/${tarih.month.toString().padLeft(2, '0')}/${tarih.year}';
  }

  /// Zaman farkını hesapla ve formatla
  static String zamanFarkiFormatla(DateTime tarih) {
    final now = DateTime.now();
    final difference = now.difference(tarih);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return kisaTarihFormatla(tarih);
    }
  }

  /// Dosya uzantısını al
  static String dosyaUzantisiAl(String dosyaAdi) {
    final lastDot = dosyaAdi.lastIndexOf('.');
    if (lastDot != -1 && lastDot < dosyaAdi.length - 1) {
      return dosyaAdi.substring(lastDot + 1).toLowerCase();
    }
    return '';
  }

  /// Dosya adından uzantısız isimi al
  static String dosyaAdiBazAl(String dosyaAdi) {
    final lastDot = dosyaAdi.lastIndexOf('.');
    if (lastDot != -1) {
      return dosyaAdi.substring(0, lastDot);
    }
    return dosyaAdi;
  }

  /// Güvenli dosya adı oluştur
  static String guvenliDosyaAdi(String dosyaAdi) {
    // Geçersiz karakterleri temizle
    String temiz = dosyaAdi.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    // Çok uzunsa kısalt
    if (temiz.length > 255) {
      final uzanti = dosyaUzantisiAl(temiz);
      final baz = dosyaAdiBazAl(temiz);
      final maksimumBaz = 255 - uzanti.length - 1;
      temiz = '${baz.substring(0, maksimumBaz)}.$uzanti';
    }

    return temiz;
  }

  /// Klasör yolu oluştur
  static Future<bool> klasorOlustur(String yol) async {
    try {
      final directory = Directory(yol);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return true;
    } catch (e) {
      print('Klasör oluşturma hatası: $e');
      return false;
    }
  }

  /// Dosya var mı kontrol et
  static Future<bool> dosyaVarMi(String yol) async {
    try {
      return await File(yol).exists();
    } catch (e) {
      return false;
    }
  }

  /// Klasör var mı kontrol et
  static Future<bool> klasorVarMi(String yol) async {
    try {
      return await Directory(yol).exists();
    } catch (e) {
      return false;
    }
  }

  /// Dosya kopyala
  static Future<bool> dosyaKopyala(String kaynakYol, String hedefYol) async {
    try {
      final kaynakDosya = File(kaynakYol);
      final hedefDosya = File(hedefYol);

      // Hedef klasörü oluştur
      final hedefKlasor = hedefDosya.parent;
      if (!await hedefKlasor.exists()) {
        await hedefKlasor.create(recursive: true);
      }

      await kaynakDosya.copy(hedefYol);
      return true;
    } catch (e) {
      print('Dosya kopyalama hatası: $e');
      return false;
    }
  }

  /// Dosya taşı
  static Future<bool> dosyaTasi(String kaynakYol, String hedefYol) async {
    try {
      final kaynakDosya = File(kaynakYol);
      final hedefDosya = File(hedefYol);

      // Hedef klasörü oluştur
      final hedefKlasor = hedefDosya.parent;
      if (!await hedefKlasor.exists()) {
        await hedefKlasor.create(recursive: true);
      }

      await kaynakDosya.rename(hedefYol);
      return true;
    } catch (e) {
      print('Dosya taşıma hatası: $e');
      return false;
    }
  }

  /// Dosya sil
  static Future<bool> dosyaSil(String yol) async {
    try {
      final dosya = File(yol);
      if (await dosya.exists()) {
        await dosya.delete();
      }
      return true;
    } catch (e) {
      print('Dosya silme hatası: $e');
      return false;
    }
  }

  /// String'i temizle ve normalize et
  static String stringTemizle(String? input) {
    if (input == null || input.isEmpty) return '';

    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Çoklu boşlukları tek boşluk yap
        .replaceAll(
          RegExp(r'[^\w\s\-_.,!?()]', unicode: true),
          '',
        ) // Özel karakterleri temizle
        .substring(
          0,
          input.length > 1000 ? 1000 : input.length,
        ); // Maksimum uzunluk
  }

  /// URL validate et
  static bool urlGecerliMi(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// IP adresi validate et
  static bool ipAdresGecerliMi(String ip) {
    final ipRegex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  /// Port numarası validate et
  static bool portGecerliMi(int port) {
    return port >= 1 && port <= 65535;
  }

  /// Unique ID oluştur
  static String uniqueIdOlustur() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecond}';
  }

  /// Random string oluştur
  static String randomStringOlustur(int uzunluk) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;

    return List.generate(uzunluk, (index) {
      return chars[(random + index) % chars.length];
    }).join();
  }

  /// Liste güvenli erişim
  static T? listeGuvenliErisim<T>(List<T> liste, int index) {
    if (index >= 0 && index < liste.length) {
      return liste[index];
    }
    return null;
  }

  /// Map güvenli erişim
  static T? mapGuvenliErisim<T>(Map<String, dynamic> map, String key) {
    try {
      return map[key] as T?;
    } catch (e) {
      return null;
    }
  }

  /// Retry logic with exponential backoff
  static Future<T?> yenidenDene<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) {
          print('Maksimum deneme sayısına ulaşıldı: $e');
          return null;
        }

        final delay = Duration(
          milliseconds: initialDelay.inMilliseconds * (attempt + 1),
        );
        print(
          'Deneme ${attempt + 1} başarısız, ${delay.inMilliseconds}ms sonra tekrar denenecek',
        );
        await Future.delayed(delay);
      }
    }
    return null;
  }

  // Dosya tipi kontrolü
  static bool desteklenenDosyaTipiMi(String dosyaYolu) {
    String uzanti = dosyaYolu.split('.').last.toLowerCase();
    return Sabitler.DESTEKLENEN_DOSYA_TIPLERI.contains(uzanti);
  }

  // Dosya adı (uzantısız)
  static String dosyaAdiUzantisiz(String dosyaYolu) {
    String dosyaAdi = dosyaYolu.split(Platform.pathSeparator).last;
    int nokta = dosyaAdi.lastIndexOf('.');
    return nokta > 0 ? dosyaAdi.substring(0, nokta) : dosyaAdi;
  }

  // Benzersiz dosya adı oluşturma
  static String benzersizDosyaAdi(String temelAd, String uzanti) {
    DateTime simdi = DateTime.now();
    String timestamp = '${simdi.millisecondsSinceEpoch}';
    return '${temelAd}_$timestamp.$uzanti';
  }

  // Dosya tipi simgesi
  static String dosyaTipiSimgesi(String dosyaTipi) {
    switch (dosyaTipi.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'txt':
      case 'rtf':
        return '📃';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return '🖼️';
      case 'mp3':
      case 'wav':
        return '🎵';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '🎬';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return '📦';
      default:
        return '📄';
    }
  }

  // Zaman farkı hesaplama
  static String zamanFarki(DateTime tarih) {
    Duration fark = DateTime.now().difference(tarih);

    if (fark.inDays > 365) {
      return '${(fark.inDays / 365).floor()} yıl önce';
    } else if (fark.inDays > 30) {
      return '${(fark.inDays / 30).floor()} ay önce';
    } else if (fark.inDays > 0) {
      return '${fark.inDays} gün önce';
    } else if (fark.inHours > 0) {
      return '${fark.inHours} saat önce';
    } else if (fark.inMinutes > 0) {
      return '${fark.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  // Alias metod - geriye uyumluluk için
  static String zamanFarkiHesapla(DateTime tarih) {
    return zamanFarki(tarih);
  }

  // Dosya yolu temizleme
  static String dosyaYoluTemizle(String yol) {
    return yol.replaceAll(RegExp(r'[/\\]+'), Platform.pathSeparator);
  }

  /// Hash geçerlilik kontrolü
  static bool hashGecerliMi(String hash) {
    if (hash.isEmpty) return false;

    // SHA-256 hash 64 karakter uzunluğunda olmalı
    if (hash.length != 64) return false;

    // Sadece hex karakterler içermeli (0-9, a-f, A-F)
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(hash);
  }
}
