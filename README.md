# 📁 Arşivim - Kişisel Belge Arşiv Uygulaması

## 📦 Hemen İndir (v2.4.0)

<div align="center">

[![Android APK](https://img.shields.io/badge/Android-APK-brightgreen?style=for-the-badge&logo=android&logoColor=white)](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivcim-v2.4.0.apk)
[![Windows EXE](https://img.shields.io/badge/Windows-EXE-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivcim-v2.4.0-windows-x64.zip)

**📱 Android APK: 38.3 MB** | **💻 Windows x64: 12 MB (ZIP)**

[📋 En güncel sürüm v2.4.0 ]

</div>

---

## 🌟 Proje Hakkında

**Arşivim**, kişisel belgelerinizi organize etmek, kategorilere ayırmak, kişilere göre gruplamak ve cihazlar arasında senkronize etmek için geliştirilmiş modern bir Flutter uygulamasıdır. Hem mobil hem de masaüstü platformlarda çalışır.

## ✨ Özellikler

### 📋 Belge Yönetimi
- **Çoklu Dosya Desteği**: PDF, DOC, DOCX, TXT, JPG, PNG, MP4, ZIP vb. 20+ dosya formatı
- **Akıllı Kategorizasyon**: Öntanımlı 16 kategori + özel kategori oluşturma
- **Kişi Bazlı Organizasyon**: Belgeleri kişilere göre gruplandırma
- **Etiketleme Sistemi**: Belgeler için özel etiketler
- **Gelişmiş Arama**: Dosya adı, başlık, açıklama, kategori ve kişi adına göre arama

### 🔄 Senkronizasyon
- **Cihazlar Arası Senkronizasyon**: Wi-Fi üzerinden mobil-PC arasında otomatik senkronizasyon
- **QR Kod Bağlantısı**: Hızlı cihaz eşleştirmesi için QR kod tarama
- **Çakışma Çözümü**: Dosya hash'i ile akıllı çakışma tespiti ve çözümü
- **HTTP Sunucusu**: PC'de otomatik HTTP sunucusu başlatma

### 💾 Yedekleme
- **Kişi Bazlı Yedekleme**: Seçilen kişilerin belgelerini yedekleme
- **Kategori Seçimi**: Kişi başına kategori seçimi ile özelleştirilebilir yedekleme
- **Klasör Yapısı**: Kişi → Kategori → Belgeler hiyerarşik yapısı
- **İlerleme Takibi**: Gerçek zamanlı yedekleme durumu

### 🎨 Modern Arayüz
- **Material Design**: Modern ve kullanıcı dostu arayüz
- **Responsive Tasarım**: Mobil ve masaüstü için optimize edilmiş
- **Animasyonlar**: Akıcı geçişler ve geri bildirimler
- **Çoklu Görünüm**: Liste ve kompakt görünüm modları

## 🔧 Teknolojiler

### Framework & Dil
- **Flutter**: Cross-platform uygulama geliştirme
- **Dart**: Modern programlama dili

### Veritabanı
- **SQLite**: Yerel veri depolama
- **sqflite**: Flutter SQLite paketi
- **sqflite_common_ffi**: Masaüstü SQLite desteği

### Güvenlik
- **SHA-256 Hashing**: Dosya bütünlüğü kontrolü
- **Crypto**: Şifreleme ve hash işlemleri

### Dosya İşlemleri
- **file_picker**: Dosya seçimi
- **path_provider**: Sistem klasörlerine erişim
- **open_filex**: Dosya açma
- **share_plus**: Dosya paylaşma

### Network & Senkronizasyon
- **HTTP Server**: Dart:io ile yerleşik HTTP sunucusu
- **connectivity_plus**: Network durumu kontrolü
- **network_info_plus**: Network bilgisi alma

### UI/UX
- **mobile_scanner**: QR kod tarama
- **qr_flutter**: QR kod oluşturma
- **Material Design**: Modern UI komponentleri

## 🗄️ Veritabanı Yapısı

### Tablolar

#### `belgeler` - Ana belge bilgileri
```sql
CREATE TABLE belgeler (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dosya_adi TEXT NOT NULL,
  orijinal_dosya_adi TEXT NOT NULL,
  dosya_yolu TEXT NOT NULL,
  dosya_boyutu INTEGER NOT NULL,
  dosya_tipi TEXT NOT NULL,
  dosya_hash TEXT UNIQUE NOT NULL,
  kategori_id INTEGER,
  kisi_id INTEGER,
  baslik TEXT,
  aciklama TEXT,
  etiketler TEXT,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  son_erisim_tarihi TEXT,
  aktif INTEGER DEFAULT 1,
  senkron_durumu INTEGER DEFAULT 0,
  FOREIGN KEY (kategori_id) REFERENCES kategoriler(id),
  FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
);
```

#### `kategoriler` - Belge kategorileri
```sql
CREATE TABLE kategoriler (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kategori_adi TEXT NOT NULL UNIQUE,
  ust_kategori_id INTEGER,
  renk_kodu TEXT DEFAULT '#2196F3',
  simge_kodu TEXT DEFAULT 'folder',
  aciklama TEXT,
  olusturma_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  FOREIGN KEY (ust_kategori_id) REFERENCES kategoriler(id)
);
```

#### `kisiler` - Kişi bilgileri
```sql
CREATE TABLE kisiler (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad TEXT NOT NULL,
  soyad TEXT NOT NULL,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1
);
```

#### `senkron_logları` - Senkronizasyon geçmişi
```sql
CREATE TABLE senkron_logları (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  belge_id INTEGER,
  islem_tipi TEXT NOT NULL,
  kaynak_cihaz TEXT NOT NULL,
  hedef_cihaz TEXT NOT NULL,
  islem_tarihi TEXT NOT NULL,
  durum TEXT DEFAULT 'BEKLEMEDE',
  hata_mesaji TEXT,
  FOREIGN KEY (belge_id) REFERENCES belgeler(id)
);
```

### Öntanımlı Kategoriler
- 📄 **Resmi Belgeler**: Kimlik, pasaport, ehliyet
- 🎓 **Eğitim**: Diploma, sertifika, transkript
- 🏥 **Sağlık**: Rapor, reçete, tahlil
- 💼 **İş**: CV, iş sözleşmesi, maaş bordrosu
- 🏠 **Ev**: Kira sözleşmesi, fatura, tapu
- 🚗 **Araç**: Ruhsat, sigorta, muayene
- 💰 **Finansal**: Banka ekstreleri, kredi kartı
- 🛡️ **Sigorta**: Kasko, hayat sigortası
- 📚 **Kitap/Dergi**: PDF kitaplar, dergiler
- 🎵 **Müzik**: MP3, WAV dosyaları
- 🎬 **Video**: MP4, AVI dosyaları
- 📸 **Fotoğraf**: JPG, PNG dosyaları
- 📦 **Arşiv**: ZIP, RAR dosyaları
- 📄 **Metin**: TXT, RTF dosyaları
- 📊 **Tablo**: Excel, CSV dosyaları
- 📂 **Diğer**: Kategorisiz dosyalar

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler
- Flutter SDK 3.7.2+
- Dart 3.7.2+
- Android Studio / VS Code
- Platform-specific gereksinimler (Android SDK, Xcode vb.)

### Adımlar
1. **Projeyi klonlayın**
   ```bash
   git clone https://github.com/username/arsiv_uygulamasi.git
   cd arsiv_uygulamasi
   ```

2. **Bağımlılıkları yükleyin**
   ```bash
   flutter pub get
   ```

3. **Uygulamayı çalıştırın**
   ```bash
   flutter run
   ```

### Platform Özellikleri
- **Android**: Kamera izni gerekli (QR kod tarama)
- **iOS**: Kamera ve fotoğraf erişimi
- **Windows/Linux/macOS**: Dosya sistemi erişimi

## 📱 Kullanım

### Belge Ekleme
1. Ana sayfada **+** butonuna tıklayın
2. Dosya seçin (kamera veya galeriden)
3. Kategori ve kişi seçin
4. Başlık, açıklama ve etiketler ekleyin
5. Kaydet butonuna tıklayın

### Senkronizasyon
1. **PC'de**: Uygulama otomatik HTTP sunucusu başlatır
2. **Mobilde**: Senkronizasyon sekmesine gidin
3. **QR Kod**: PC'deki QR kodu tarayın
4. **Manuel**: IP adresini girerek bağlanın
5. Senkronizasyon otomatik başlar

### Yedekleme (Sadece PC)
1. Yedekleme sekmesine gidin
2. Yedeklenecek kişileri seçin
3. Her kişi için kategorileri seçin
4. Hedef klasörü belirleyin
5. Yedekleme başlat

## 🏗️ Proje Yapısı

```
lib/
├── main.dart                    # Ana uygulama giriş noktası
├── models/                      # Veri modelleri
│   ├── belge_modeli.dart       # Belge veri yapısı
│   ├── kategori_modeli.dart    # Kategori veri yapısı
│   ├── kisi_modeli.dart        # Kişi veri yapısı
│   └── senkron_*.dart          # Senkronizasyon modelleri
├── services/                    # İş mantığı servisleri
│   ├── veritabani_servisi.dart # SQLite veritabanı işlemleri
│   ├── dosya_servisi.dart      # Dosya yönetimi
│   ├── http_sunucu_servisi.dart # HTTP sunucu
│   ├── senkron_manager.dart    # Senkronizasyon yönetimi
│   └── yedekleme_servisi.dart  # Yedekleme işlemleri
├── screens/                     # Uygulama ekranları
│   ├── ana_ekran.dart          # Ana dashboard
│   ├── belgeler_ekrani.dart    # Belge listesi
│   ├── kategoriler_ekrani.dart # Kategori yönetimi
│   ├── kisiler_ekrani.dart     # Kişi yönetimi
│   └── senkron_ekrani.dart     # Senkronizasyon
├── widgets/                     # UI bileşenleri
│   ├── belge_karti_widget.dart # Belge kartı
│   ├── qr_scanner_widget.dart  # QR kod tarayıcı
│   └── senkron_*.dart          # Senkronizasyon UI
└── utils/                       # Yardımcı fonksiyonlar
    ├── sabitler.dart           # Uygulama sabitleri
    └── yardimci_fonksiyonlar.dart # Genel yardımcılar
```

## 🔧 Konfigürasyon

### Desteklenen Dosya Formatları
```dart
const List<String> DESTEKLENEN_DOSYA_TIPLERI = [
  'pdf', 'doc', 'docx', 'txt', 'rtf',
  'jpg', 'jpeg', 'png', 'gif', 'bmp',
  'mp3', 'wav', 'mp4', 'avi', 'mov',
  'zip', 'rar', '7z', 'tar', 'gz'
];
```

### Senkronizasyon Ayarları
```dart
const int SENKRON_PORTU = 8080;
const int MAKSIMUM_DOSYA_BOYUTU = 100 * 1024 * 1024; // 100MB
const int SENKRON_TIMEOUT = 30000; // 30 saniye
```

## 🛡️ Güvenlik

- **Dosya Bütünlüğü**: SHA-256 hash ile dosya doğrulama
- **Yerel Depolama**: Tüm veriler cihazda saklanır
- **Güvenli Senkronizasyon**: HTTP üzerinden şifrelenmiş transfer
- **Çakışma Önleme**: Hash tabanlı çakışma tespiti

## 📄 Lisans

Bu proje MIT Lisansı ile lisanslanmıştır.

## 👥 Katkıda Bulunma

1. Bu projeyi fork edin
2. Yeni bir branch oluşturun (`git checkout -b feature/AmazingFeature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Branch'inizi push edin (`git push origin feature/AmazingFeature`)
5. Pull Request oluşturun

## 🐛 Hata Bildirimi

Herhangi bir hata veya öneriniz varsa, lütfen [Issues](https://github.com/username/arsiv_uygulamasi/issues) sayfasından bildiriniz.

## 📧 İletişim

- **Email**: mehmetkarataslar@gmail.com
- **GitHub**: [@mehmet-karataslar](https://github.com/umehmet-karataslar)

---

**Arşivim** ile belgelerinizi organize edin, güvenli bir şekilde saklayın ve cihazlar arasında senkronize edin! 🚀 
