# 🚀 Arşivim v2.5.1 Release

**Release Date:** 19 Temmuz 2025  
**Version Code:** 10  
**Build Type:** Production Release

---

## 📱 **İndirme Linkleri**

### Android (APK)
- **Dosya:** `Arsivcim-v2.5.1-android.apk`
- **Boyut:** ~45MB
- **Min SDK:** Android 5.0+ (API 21)
- **Version Code:** 10 (v2.4.0'dan güncelleme garanti)

### Windows (ZIP Package)
- **Dosya:** `Arsivcim-v2.5.1-windows-x64.zip`
- **Boyut:** ~14MB
- **İçerik:** EXE + Tüm DLL bağımlılıkları
- **Hedef:** Windows 10/11 64-bit

---

## 🔧 **Bu Sürümde Yapılan Değişiklikler**

### ❌ **Kaldırılan Özellikler**
- **Faturalar Sistemi** tamamen kaldırıldı
- **Vergiler Sistemi** tamamen kaldırıldı  
- **Takvim/Aktivite Sistemi** kaldırıldı
- **Invoice & Tax Models** silindi
- **Calendar Activity Service** kaldırıldı

### 🗂️ **Navigation Güncellemeleri**
- Ana ekran tab yapısı sadeleştirildi
- Fatura ve Vergi sekmeleri kaldırıldı
- Calendar kartları ana ekrandan çıkarıldı

### 🔧 **Teknik İyileştirmeler**
- **Version Code:** 2 → 10 (güncelleme garantisi)
- **Database Version:** 9 → 10
- Fatura/vergi tablolarını migration'dan kaldırıldı
- Notification Service düzeltildi
- Kullanılmayan import'lar temizlendi

### 🛡️ **Güvenlik & Performans**
- Production keystore ile imzalandı
- Tree-shaking optimization (~98.5% font optimizasyonu)
- Gereksiz widget'lar kaldırıldı

---

## 📊 **Sistem Gereksinimleri**

### Android
- **İşletim Sistemi:** Android 5.0+ (API 21)
- **RAM:** Minimum 2GB
- **Depolama:** 100MB serbest alan
- **İzinler:** Dosya erişimi, kamera, bildirimler

### Windows  
- **İşletim Sistemi:** Windows 10/11 64-bit
- **RAM:** Minimum 4GB
- **Depolama:** 200MB serbest alan

---

## 🔄 **v2.4.0'dan Güncelleme Notları**

⚠️ **ÖNEMLI:** Bu sürüm güncelleme sorununu çözer

### Güncelleme Nedenleri:
1. **Version Code Conflict:** v2.4.0 (code: ~4) → v2.5.1 (code: 10)
2. **Keystore Uyumluluğu:** Production keystore ile imzalandı
3. **Veri Koruma:** Mevcut belgeler ve veriler korunacak

### Güncelleme Adımları:
1. Mevcut veri yedeği önerilir (güvenlik için)
2. Eski APK'yı silmeden yeni APK'yı kur
3. Sistem otomatik olarak güncelleme yapacak
4. Tüm belgeler ve ayarlar korunacak

---

## 🐛 **Bilinen Sorunlar**

- **Paket Uyarıları:** 20 paket güncellemesi mevcut (uyumluluk nedeniyle ertelendi)
- **Minor:** Bazı info-level analiz uyarıları (production'ı etkilemez)

---

## 📞 **Destek**

Sorunlar için GitHub Issues bölümünü kullanın. 