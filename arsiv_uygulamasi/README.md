# Arşivim - Kişisel Belge Arşiv Uygulaması

Arşivim, kişisel belgelerinizi dijital ortamda organize etmenizi ve güvenle saklamanızı sağlayan kapsamlı bir Flutter uygulamasıdır.

## 🚀 Özellikler

### 📄 Belge Yönetimi
- **Belge Ekleme**: Kamera veya dosya seçici ile belge ekleme
- **QR Kod Desteği**: Belgeleri QR kod ile hızlı erişim
- **Kategori Sistemi**: Belgelerinizi kategorilere ayırarak organize edin
- **Arama Fonksiyonu**: Belge adı, içerik veya kategoriye göre arama

### 👥 Kişi Yönetimi
- **Kişi Profilleri**: Belgeler için kişi atama ve profil yönetimi
- **Profil Fotoğrafları**: Kişiler için profil fotoğrafı ekleme
- **Otomatik Eşleştirme**: Belge senkronizasyonu sırasında kişi otomatik eşleştirme

### 🔄 Senkronizasyon
- **Cihazlar Arası Senkronizasyon**: HTTP sunucu üzerinden belge paylaşımı
- **QR Kod Bağlantı**: Cihazları QR kod ile hızlı eşleştirme
- **Otomatik Kişi/Kategori Oluşturma**: Eksik kişi ve kategorileri otomatik oluşturma
- **Büyük Dosya Desteği**: Büyük belgelerin güvenli transferi

### 🎨 Kategori Sistemi
- **Varsayılan Kategoriler**: 16 hazır kategori (Kimlik, Eğitim, Sağlık, vb.)
- **Özel Kategoriler**: Kendi kategorilerinizi oluşturma
- **Renk ve İkon Desteği**: Kategoriler için özelleştirilebilir görsel öğeler

### 🔐 Güvenlik
- **Yerel Depolama**: Belgeler cihazınızda güvenle saklanır
- **Hash Kontrolü**: Belge bütünlüğü için hash doğrulama
- **Şifreli Transfer**: Senkronizasyon sırasında güvenli veri transferi

## 📱 Desteklenen Platformlar

- **Android**: APK dosyası ile kurulum
- **Windows**: EXE dosyası ile kurulum
- **iOS**: (Geliştirme aşamasında)
- **macOS**: (Geliştirme aşamasında)
- **Linux**: (Geliştirme aşamasında)

## 🔧 Kurulum

### Android
1. [Releases](releases/) klasöründen en son APK dosyasını indirin
2. APK dosyasını Android cihazınıza yükleyin
3. Bilinmeyen kaynaklardan kuruluma izin verin
4. Uygulamayı başlatın

### Windows
1. [Releases](releases/) klasöründen Windows ZIP dosyasını indirin
2. ZIP dosyasını çıkartın
3. `arsiv_uygulamasi.exe` dosyasını çalıştırın

## 🏗️ Geliştirme

### Gereksinimler
- Flutter SDK (^3.7.2)
- Dart SDK
- Android Studio / VS Code
- Git

### Kurulum
```bash
# Projeyi klonlayın
git clone https://github.com/yourusername/arsiv_uygulamasi.git

# Proje dizinine gidin
cd arsiv_uygulamasi

# Bağımlılıkları yükleyin
flutter pub get

# Uygulamayı çalıştırın
flutter run
```

### Build Komutları
```bash
# Android APK
flutter build apk --release

# Windows EXE
flutter build windows --release

# iOS (macOS gerekli)
flutter build ios --release
```

## 📦 Sürüm Geçmişi

### v2.4.0 (Mevcut)
- ✅ Otomatik kişi oluşturma sırasında profil fotoğrafı çekme
- ✅ Büyük dosya transferi sırasında kişi adlarının korunması
- ✅ Belge senkronizasyonu geliştirmeleri
- ✅ Sadece belge senkronizasyonu - kişi ve kategoriler otomatik yönetim

### v2.3.0
- ✅ Senkronizasyon sistemi büyük iyileştirmeler
- ✅ QR kod tabanlı cihaz eşleştirme
- ✅ Kategori filtreleme optimizasyonu
- ✅ Progress dialog yeniden yapılandırma

## 🤝 Katkıda Bulunma

1. Bu projeyi fork edin
2. Yeni bir branch oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik eklendi'`)
4. Branch'inizi push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request oluşturun

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakınız.

## 📞 İletişim

- **Geliştirici**: [GitHub Profili](https://github.com/yourusername)
- **E-posta**: your.email@example.com
- **Issues**: [GitHub Issues](https://github.com/yourusername/arsiv_uygulamasi/issues)

## 🙏 Teşekkürler

Bu proje aşağıdaki açık kaynak projeleri kullanmaktadır:
- Flutter Framework
- SQLite (sqflite)
- QR Code Scanner (mobile_scanner)
- File Picker
- Ve diğer tüm bağımlılıklar

---

**Arşivim** ile belgelerinizi dijital dünyada güvenle organize edin! 📁✨
