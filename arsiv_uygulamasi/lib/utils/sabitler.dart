// Uygulama sabitleri
class Sabitler {
  // Veritabanı
  static const String VERITABANI_ADI = 'arsiv.db';
  static const int VERITABANI_VERSIYONU = 7;

  // Dosya yolları
  static const String BELGELER_KLASORU = 'Belgeler';
  static const String GECICI_KLASOR = 'temp';
  static const String YEDEK_KLASOR = 'backup';

  // Senkronizasyon
  static const int MAKSIMUM_DOSYA_BOYUTU = 100 * 1024 * 1024; // 100MB
  static const int SENKRON_TIMEOUT = 30000; // 30 saniye
  static const int CAKISMA_COZUM_TIMEOUT = 60000; // 1 dakika

  // Desteklenen dosya tipleri
  static const List<String> DESTEKLENEN_DOSYA_TIPLERI = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'mp3',
    'wav',
    'mp4',
    'avi',
    'mov',
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
  ];

  // USB cihaz kodları
  static const String USB_PERMISSION_ACTION =
      'com.arsiv.uygulamasi.USB_PERMISSION';
  static const String USB_DEVICE_ATTACHED =
      'android.hardware.usb.action.USB_DEVICE_ATTACHED';
  static const String USB_DEVICE_DETACHED =
      'android.hardware.usb.action.USB_DEVICE_DETACHED';

  // Tema sabitleri
  static const String TEMA_TERCIHI_ANAHTARI = 'tema_tercihi';
  static const String OZEL_TEMA_ANAHTARI = 'ozel_tema';

  // Log sabitleri
  static const String LOG_DOSYASI = 'arsiv_logs.txt';
  static const int MAKSIMUM_LOG_BOYUTU = 10 * 1024 * 1024; // 10MB

  // Güncelleme sabitleri
  static const String GUNCELLEME_KONTROL_URL = 'https://api.arsiv.app/version';
  static const String INDIRME_URL_BASE = 'https://releases.arsiv.app/';

  // Cache ayarları
  static const int CACHE_SURESI_DAKIKA = 10; // 10 dakika
  static const int MAKSIMUM_BELGE_CACHE = 50; // Maksimum 50 belge
  static const int MAKSIMUM_DOSYA_BOYUTU_MB =
      10; // 10MB üzeri dosyalar cache'lenmez

  // Performans ayarları
  static const int SAYFA_BOYUTU = 20; // Pagination için
  static const int MINIMUM_ARAMA_UZUNLUGU = 2; // Minimum arama karakter sayısı
}
