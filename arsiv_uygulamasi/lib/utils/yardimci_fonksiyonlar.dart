import 'dart:io';
import 'sabitler.dart';

// Genel yardımcı fonksiyonlar
class YardimciFonksiyonlar {
  // Dosya boyutu formatlaması
  static String dosyaBoyutuFormatla(int boyut) {
    if (boyut < 1024) return '$boyut B';
    if (boyut < 1024 * 1024) return '${(boyut / 1024).toStringAsFixed(1)} KB';
    if (boyut < 1024 * 1024 * 1024)
      return '${(boyut / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(boyut / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Dosya tipi kontrolü
  static bool desteklenenDosyaTipiMi(String dosyaYolu) {
    String uzanti = dosyaYolu.split('.').last.toLowerCase();
    return Sabitler.DESTEKLENEN_DOSYA_TIPLERI.contains(uzanti);
  }

  // Güvenli dosya adı oluşturma
  static String guvenliDosyaAdi(String dosyaAdi) {
    return dosyaAdi.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  // Tarih formatlaması
  static String tarihFormatla(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  // Hash doğrulama
  static bool hashGecerliMi(String hash) {
    return hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash);
  }

  // Dosya uzantısı alma
  static String dosyaUzantisi(String dosyaYolu) {
    return dosyaYolu.split('.').last.toLowerCase();
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
}
