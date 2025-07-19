# 📁 Arşivim - Kişisel Belge Arşiv Uygulaması

## 📦 Hemen İndir (v2.5.1)

<div align="center">

[![Android APK](https://img.shields.io/badge/Android-APK-brightgreen?style=for-the-badge&logo=android&logoColor=white)](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivim-v2.5.1-Android-SIGNED.apk)
[![Windows EXE](https://img.shields.io/badge/Windows-EXE-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivim-v2.5.1-Windows.zip)

**📱 Android APK: 44 MB** | **💻 Windows ZIP: 37 MB**

[📋 Tüm Sürümler](https://github.com/mehmet-karataslar/Arsivim/releases) | [📖 Kurulum Rehberi](arsiv_uygulamasi/releases/README.md)

</div>

---

## 🌟 Proje Hakkında

**Arşivim**, kişisel belgelerinizi organize etmek, kategorilere ayırmak, kişilere göre gruplamak ve cihazlar arasında senkronize etmek için geliştirilmiş modern bir Flutter uygulamasıdır. Hem mobil hem de masaüstü platformlarda çalışır.

## ✨ Özellikler

### 📋 Belge Yönetimi
- **Çoklu Dosya Desteği**: PDF, DOC, DOCX, TXT, JPG, PNG, MP4, ZIP vb. 20+ dosya formatı
- **✨ Belge Düzenleme (YENİ)**: Başlık, açıklama, kategori, kişi ve etiket düzenleme
- **Akıllı Kategorizasyon**: Öntanımlı 16 kategori + özel kategori oluşturma
- **Kişi Bazlı Organizasyon**: Belgeleri kişilere göre gruplandırma
- **Etiketleme Sistemi**: Belgeler için özel etiketler
- **Gelişmiş Arama**: Dosya adı, başlık, açıklama, kategori ve kişi adına göre arama

### 🔄 Senkronizasyon
- **Cihazlar Arası Senkronizasyon**: Wi-Fi üzerinden mobil-PC arasında otomatik senkronizasyon
- **QR Kod Bağlantısı**: Hızlı cihaz eşleştirmesi için QR kod tarama
- **Çakışma Çözümü**: Dosya hash'i ile akıllı çakışma tespiti ve çözümü
- **HTTP Sunucusu**: PC'de otomatik HTTP sunucusu başlatma

### 💾 Yedekleme & Veri Koruma
- **🔒 Gelişmiş Veri Koruma (YENİ)**: Otomatik backup sistemi ile veri güvenliği
- **Güvenli Migration**: Hiçbir veri kaybedilmez, güvenli veritabanı güncellemeleri
- **Kişi Bazlı Yedekleme**: Seçilen kişilerin belgelerini yedekleme
- **Kategori Seçimi**: Kişi başına kategori seçimi ile özelleştirilebilir yedekleme
- **Klasör Yapısı**: Kişi → Kategori → Belgeler hiyerarşik yapısı

### 📊 Fatura & Vergi Sistemi
- **Fatura Yönetimi**: Gelen/giden fatura kayıtları
- **Vergi Takibi**: Gelir/gider vergi hesaplamaları
- **Ödeme Durumu**: Fatura ödeme takibi ve hatırlatıcılar
- **Raporlama**: Dönemsel finansal raporlar

### 📅 Takvim & Hatırlatıcı
- **Etkinlik Planlaması**: Belge işlemleri için takvim entegrasyonu
- **Hatırlatıcı Sistemi**: Önemli tarihlerde bildirimler
- **Bildirim Yönetimi**: Özelleştirilebilir bildirim ayarları

### 👥 Kişi Yönetimi
- **Kişi Profilleri**: Belgeler için kişi atama ve profil yönetimi
- **Profil Fotoğrafları**: Kişiler için profil fotoğrafı ekleme
- **Kullanıcı Sistemi**: Farklı kullanıcı tipleri ve yetkilendirme
- **Otomatik Eşleştirme**: Belge senkronizasyonu sırasında kişi otomatik eşleştirme

### 🎨 Modern Arayüz
- **Material Design**: Modern ve kullanıcı dostu arayüz
- **Responsive Tasarım**: Mobil ve masaüstü için optimize edilmiş
- **Animasyonlar**: Akıcı geçişler ve geri bildirimler
- **Çoklu Görünüm**: Liste ve kompakt görünüm modları

### 🔐 Güvenlik & Performans
- **Dosya Bütünlüğü**: SHA-256 hash ile dosya doğrulama
- **Yerel Depolama**: Tüm veriler cihazda güvenli şekilde saklanır
- **🆕 APK Güncellemesi**: Production signing ile sorunsuz güncellemeler (v2.5.1+)
- **Güvenli Senkronizasyon**: HTTP üzerinden şifrelenmiş transfer
- **Çakışma Önleme**: Hash tabanlı çakışma tespiti

## 📱 Desteklenen Platformlar

- **Android**: APK dosyası ile kurulum (Android 5.0+)
- **Windows**: Portable ZIP paketi (Windows 10/11 64-bit)
- **iOS**: (Geliştirme aşamasında)
- **macOS**: (Geliştirme aşamasında)
- **Linux**: (Geliştirme aşamasında)

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
- **device_info_plus**: Cihaz bilgisi alma

### UI/UX
- **mobile_scanner**: QR kod tarama
- **qr_flutter**: QR kod oluşturma
- **flutter_local_notifications**: Yerel bildirimler
- **Material Design**: Modern UI komponentleri

## 🗄️ Veritabanı Yapısı

### Ana Tablolar

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
  versiyon_numarasi INTEGER DEFAULT 1,
  metadata_hash TEXT,
  son_metadata_guncelleme TEXT,
  FOREIGN KEY (kategori_id) REFERENCES kategoriler(id),
  FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
);
```

#### `kategoriler` - Belge kategorileri
```sql
CREATE TABLE kategoriler (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kategori_adi TEXT NOT NULL UNIQUE,
  renk_kodu TEXT DEFAULT '#2196F3',
  simge_kodu TEXT DEFAULT 'folder',
  aciklama TEXT,
  olusturma_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  belge_sayisi INTEGER DEFAULT 0
);
```

#### `kisiler` - Kişi bilgileri
```sql
CREATE TABLE kisiler (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ad TEXT NOT NULL,
  soyad TEXT NOT NULL,
  kullanici_adi TEXT UNIQUE,
  sifre TEXT,
  kullanici_tipi TEXT DEFAULT 'NORMAL',
  profil_fotografi TEXT,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1
);
```

#### `invoices` - Fatura sistemi
```sql
CREATE TABLE invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kisi_id INTEGER NOT NULL,
  invoice_number TEXT NOT NULL UNIQUE,
  issue_date TEXT NOT NULL,
  due_date TEXT NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'PENDING',
  invoice_type TEXT NOT NULL DEFAULT 'INCOMING',
  supplier_name TEXT,
  customer_name TEXT,
  currency TEXT NOT NULL DEFAULT 'EUR',
  net_amount REAL NOT NULL,
  tax_amount REAL NOT NULL,
  tax_rate REAL NOT NULL DEFAULT 19.0,
  gross_amount REAL NOT NULL,
  description TEXT,
  notes TEXT,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
);
```

#### `taxes` - Vergi sistemi
```sql
CREATE TABLE taxes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kisi_id INTEGER NOT NULL,
  tax_year INTEGER NOT NULL,
  tax_period TEXT NOT NULL,
  tax_period_start TEXT NOT NULL,
  tax_period_end TEXT NOT NULL,
  tax_status TEXT NOT NULL DEFAULT 'DRAFT',
  tax_type TEXT NOT NULL,
  tax_category TEXT NOT NULL,
  calculated_amount REAL NOT NULL DEFAULT 0.0,
  paid_amount REAL NOT NULL DEFAULT 0.0,
  remaining_amount REAL NOT NULL DEFAULT 0.0,
  submission_deadline TEXT,
  payment_deadline TEXT,
  tax_office TEXT,
  tax_number TEXT,
  notes TEXT,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
);
```

#### `activities` - Takvim etkinlikleri
```sql
CREATE TABLE activities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  activity_date TEXT NOT NULL,
  start_time TEXT,
  end_time TEXT,
  location TEXT,
  category_color TEXT DEFAULT '#2196F3',
  is_completed INTEGER DEFAULT 0,
  priority INTEGER DEFAULT 1,
  kisi_id INTEGER,
  belge_id INTEGER,
  olusturma_tarihi TEXT NOT NULL,
  guncelleme_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  FOREIGN KEY (kisi_id) REFERENCES kisiler(id),
  FOREIGN KEY (belge_id) REFERENCES belgeler(id)
);
```

#### `reminders` - Hatırlatıcı sistemi
```sql
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  activity_id INTEGER NOT NULL,
  reminder_time TEXT NOT NULL,
  reminder_type TEXT NOT NULL DEFAULT 'NOTIFICATION',
  is_sent INTEGER DEFAULT 0,
  message TEXT,
  olusturma_tarihi TEXT NOT NULL,
  aktif INTEGER DEFAULT 1,
  FOREIGN KEY (activity_id) REFERENCES activities(id)
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

### Gereksinimler
- Flutter SDK 3.7.2+
- Dart 3.7.2+
- Android Studio / VS Code
- Platform-specific gereksinimler (Android SDK, Xcode vb.)

### Geliştirme İçin Adımlar
1. **Projeyi klonlayın**
   ```bash
   git clone https://github.com/mehmet-karataslar/Arsivim.git
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

## 📱 Son Kullanıcı Kurulumu

### **📱 Android**
1. **[Arsivim-v2.5.1-Android-SIGNED.apk](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivim-v2.5.1-Android-SIGNED.apk)** dosyasını indirin
2. **Bilinmeyen kaynaklardan kurulum**u etkinleştirin
3. APK dosyasına dokunarak kurulumu başlatın
4. ⚠️ **v2.5.0'dan güncelleme:** Eski sürümü kaldırın, yeni APK'yı kurun
5. ✅ **v2.5.1+ güncellemeler:** Direkt APK ile güncellenebilir

### **💻 Windows**
1. **[Arsivim-v2.5.1-Windows.zip](https://github.com/mehmet-karataslar/Arsivim/blob/master/arsiv_uygulamasi/releases/Arsivim-v2.5.1-Windows.zip)** dosyasını indirin
2. ZIP'i istediğiniz klasöre çıkartın  
3. `Arsivim-v2.5.1.exe` dosyasına çift tıklayın
4. Windows Defender uyarısı: "Daha fazla bilgi" → "Yine de çalıştır"

## 📱 Kullanım

### Belge Ekleme
1. Ana sayfada **+** butonuna tıklayın
2. Dosya seçin (kamera veya galeriden)
3. Kategori ve kişi seçin
4. Başlık, açıklama ve etiketler ekleyin
5. Kaydet butonuna tıklayın

### Belge Düzenleme (Yeni!)
1. Belge kartında **Düzenle** butonuna tıklayın
2. Başlık, açıklama, kategori, kişi düzenleyin
3. Etiket ekleyin/çıkarın
4. Değişiklikleri kaydedin

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
├── main.dart                           # Ana uygulama giriş noktası
├── models/                             # Veri modelleri
│   ├── belge_modeli.dart              # Belge veri yapısı
│   ├── kategori_modeli.dart           # Kategori veri yapısı
│   ├── kisi_modeli.dart               # Kişi veri yapısı
│   ├── invoice_modeli.dart            # Fatura veri yapısı
│   ├── tax_modeli.dart                # Vergi veri yapısı
│   ├── activity_modeli.dart           # Takvim etkinlik modeli
│   └── reminder_modeli.dart           # Hatırlatıcı modeli
├── services/                           # İş mantığı servisleri
│   ├── veritabani_servisi.dart        # SQLite veritabanı işlemleri
│   ├── dosya_servisi.dart             # Dosya yönetimi
│   ├── http_sunucu_servisi.dart       # HTTP sunucu
│   ├── senkronizasyon_yonetici_servisi.dart # Senkronizasyon yönetimi
│   ├── notification_service.dart      # Bildirim servisi
│   ├── auth_servisi.dart              # Kimlik doğrulama
│   └── cache_servisi.dart             # Önbellek yönetimi
├── screens/                           # Uygulama ekranları
│   ├── ana_ekran.dart                 # Ana dashboard
│   ├── belgeler_ekrani.dart           # Belge listesi
│   ├── belge_duzenle_ekrani.dart      # Belge düzenleme (YENİ)
│   ├── kategoriler_ekrani.dart        # Kategori yönetimi
│   ├── kisiler_ekrani.dart            # Kişi yönetimi
│   ├── senkronizasyon_ekrani.dart     # Senkronizasyon
│   ├── fatura_ekrani.dart             # Fatura yönetimi
│   ├── vergi_ekrani.dart              # Vergi takibi
│   ├── takvim_ekrani.dart             # Takvim görünümü
│   └── auth/                          # Kimlik doğrulama ekranları
├── widgets/                           # UI bileşenleri
│   ├── belge_karti_widget.dart        # Belge kartı
│   ├── qr_scanner_widget.dart         # QR kod tarayıcı
│   ├── senkronizasyon_kontrolleri.dart # Senkron UI
│   └── profil_fotografi_widget.dart   # Profil fotoğrafı widget
├── providers/                         # State yönetimi
│   └── app_state_manager.dart         # Uygulama durumu
└── utils/                             # Yardımcı fonksiyonlar
    ├── sabitler.dart                  # Uygulama sabitleri
    ├── tema_renkleri.dart             # Tema yapılandırması
    └── yardimci_fonksiyonlar.dart     # Genel yardımcılar
```

### Build Komutları
```bash
# Android APK (Production Signed)
flutter build apk --release

# Windows EXE
flutter build windows --release

# Temizleme
flutter clean && flutter pub get
```

## 📦 Sürüm Geçmişi

### 🎉 v2.5.1 (Mevcut) - 19 Temmuz 2025
**🚨 Kritik Güncelleme: APK Güncelleme Sorunu Çözüldü**

#### ✨ **Yeni Özellikler:**
- **Belge Düzenleme Sistemi**: Tam özellikli belge düzenleme sayfası
- **Gelişmiş Veri Koruma**: Otomatik backup ve güvenli migration
- **Fatura & Vergi Sistemi**: Finansal takip araçları
- **Takvim & Hatırlatıcı**: Etkinlik planlaması ve bildirimler

#### 🔐 **Android Signing Fix:**
- **Production Release Key**: Kalıcı keystore ile proper signing
- **Sorunsuz Güncellemeler**: "Paket geçersiz" hatası çözüldü
- **v2.5.1+ Uyumluluk**: Gelecek güncellemeler sorunsuz

#### 🛠️ **Teknik İyileştirmeler:**
- Null güvenlik kontrolleri
- Form validasyonu
- UI/UX iyileştirmeleri
- Performance optimizasyonu

### v2.5.0 - 15 Temmuz 2025
- ✅ Senkronizasyon tab'ı bilgisayar versiyonunda
- ✅ Scanner özelliği mobil platformda
- ✅ Unified navigation sistemi
- ✅ Database bütünlük kontrolü

### v2.4.0
- ✅ Otomatik kişi oluşturma sırasında profil fotoğrafı çekme
- ✅ Büyük dosya transferi sırasında kişi adlarının korunması
- ✅ Belge senkronizasyonu geliştirmeleri
- ✅ Sadece belge senkronizasyonu - kişi ve kategoriler otomatik yönetim

### v2.3.0
- ✅ Senkronizasyon sistemi büyük iyileştirmeler
- ✅ QR kod tabanlı cihaz eşleştirme
- ✅ Kategori filtreleme optimizasyonu
- ✅ Progress dialog yeniden yapılandırma

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
- **Production Signing**: Android APK'lar güvenli keystore ile imzalanır

## 👥 Katkıda Bulunma

1. Bu projeyi fork edin
2. Yeni bir branch oluşturun (`git checkout -b feature/AmazingFeature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Branch'inizi push edin (`git push origin feature/AmazingFeature`)
5. Pull Request oluşturun

## 🐛 Hata Bildirimi

Herhangi bir hata veya öneriniz varsa, lütfen [Issues](https://github.com/mehmet-karataslar/Arsivim/issues) sayfasından bildiriniz.

### Hata raporu için:
- **Cihaz bilgileri** (işletim sistemi, sürüm)
- **Uygulama sürümü** 
- **Hatanın detaylı açıklaması**
- **Ekran görüntüsü** (mümkünse)

## 📄 Lisans

Bu proje MIT Lisansı ile lisanslanmıştır.

## 📧 İletişim

- **Email**: mehmetkarataslar@gmail.com
- **GitHub**: [@mehmet-karataslar](https://github.com/mehmet-karataslar)
- **Issues**: [GitHub Issues](https://github.com/mehmet-karataslar/Arsivim/issues)
- **Releases**: [GitHub Releases](https://github.com/mehmet-karataslar/Arsivim/releases)

## 🙏 Teşekkürler

Bu proje aşağıdaki açık kaynak teknolojileri kullanmaktadır:

### Core Technologies
- **Flutter Framework** - Google
- **Dart Programming Language** - Google
- **SQLite** - Veritabanı

### Flutter Packages
- **sqflite & sqflite_common_ffi** - SQLite desteği
- **mobile_scanner** - QR kod tarama
- **qr_flutter** - QR kod oluşturma
- **file_picker** - Dosya seçimi
- **path_provider** - Sistem klasörleri
- **share_plus** - Dosya paylaşma
- **connectivity_plus** - Network durumu
- **device_info_plus** - Cihaz bilgileri
- **crypto** - Hash işlemleri
- **flutter_local_notifications** - Bildirimler

### Development Tools
- **Android Studio** - IDE
- **VS Code** - Editor
- **Git** - Version control

---

## 🚀 **Arşivim ile belgelerinizi organize edin, güvenli bir şekilde saklayın ve cihazlar arasında senkronize edin!**

*Güvenli arşivleme deneyiminin tadını çıkarın! 📁✨*

---

**Son Güncelleme:** 19 Temmuz 2025  
**Mevcut Sürüm:** v2.5.1+2  
**Geliştirici:** [@mehmet-karataslar](https://github.com/mehmet-karataslar)
