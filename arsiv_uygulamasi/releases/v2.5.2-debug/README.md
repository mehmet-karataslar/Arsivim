# Arşivim v2.5.2-DEBUG - Debug Keystore Uyumlu Sürüm

## 🎯 **ÖZEL UYUMLULUK SÜRÜMÜ**
Bu sürüm, **Android Debug keystore** ile imzalanmış eski uygulamalarla **tamamen uyumludur**.

## 🔑 **İmza Bilgileri (Uyumlu)**
```
Certificate #1:
Owner: C=US, O=Android, CN=Android Debug
SHA1: 6D:93:39:1D:7D:72:DE:A2:1A:2D:DB:EF:5A:ED:A3:2E:CC:2B:5D:D4
SHA256: C2:8F:BF:C9:51:C4:CF:2E:FE:28:A5:6B:6F:48:64:77:7A:5C:7A:E5:0A:81:EC:36:8A:B3:CE:22:4B:64:90:55
Valid: 2025-2055 (30 yıl)
```

## 📦 **İndirme Dosyaları**

| Platform | Dosya | Boyut | Açıklama |
|----------|-------|-------|----------|
| 🤖 **Android** | `Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk` | 29.9 MB | **ESKİ DEBUG VERİLERİNİZİ KORUR** |
| 🖥️ **Windows ZIP** | `Arsivcim-v2.5.2-DEBUG-windows-x64.zip` | 15.0 MB | Taşınabilir sürüm |
| 🖥️ **Windows EXE** | `windows/arsiv_uygulamasi.exe` | - | Direkt çalıştırılabilir |

## ✅ **Garanti: Çakışma Yok!**

### **Bu Sürüm Kesinlikle Uyumludur Çünkü:**
- ✅ **Aynı Application ID**: `com.example.arsiv_uygulamasi`
- ✅ **Aynı İmza Anahtarı**: Android Debug Keystore
- ✅ **Aynı SHA1 Hash**: `6D:93:39:1D:7D:72:DE:A2:1A:2D:DB:EF:5A:ED:A3:2E:CC:2B:5D:D4`
- ✅ **Yüksek Version Code**: 25 (güncelleme olarak algılanır)

## 🚀 **v2.5.2-DEBUG Yenilikleri**

### 🔧 **Çözülen Ana Sorun**
- **İmza Çakışması**: Debug keystore kullanılarak tamamen çözüldü
- **Güncelleme Garantisi**: Version code 25 ile kesin güncelleme
- **Veri Korunması**: Aynı uygulama kimliği ile eski veriler korunur

### 🔧 **Teknik Özellikler**
- **İmza Türü**: Android Debug Keystore (otomatik)
- **Application ID**: `com.example.arsiv_uygulamasi`
- **Version Code**: 25
- **Version Name**: 2.5.2
- **Target SDK**: 35 (Android 15)
- **Min SDK**: 23 (Android 6.0)
- **Build Type**: Release (debug keystore ile)

### 📱 **Yeni Özellikler**
- ✅ **QR Scanner**: `simple_barcode_scanner` entegrasyonu
- ✅ **Android 15 Desteği**: API 35 uyumluluğu
- ✅ **Güncellenen Paketler**: Tüm dependencies güncel
- ✅ **ARM64 Optimize**: Modern telefonlar için optimize

## 📋 **Kurulum Talimatları**

### 🎯 **ADIM 1: İndirin**
```bash
Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk (29.9 MB)
```

### 🎯 **ADIM 2: Kurun (Çakışma Garantisi Yok)**
1. APK dosyasına dokunun
2. **"Güncelle"** seçeneğini seçin
3. Kurulum otomatik tamamlanacak
4. ✅ **Verileriniz korunacak**

### ⚠️ **Önemli: Eski Uygulamayı SİLMEYİN**
- Eski uygulamayı **kaldırmayın**
- Sadece **güncelleme** yapın
- Verileriniz **otomatik korunur**

## 🔍 **Teknik Doğrulama**

### **İmza Kontrolü (Eğer Test Etmek İsterseniz):**
```bash
# APK imza bilgilerini kontrol etmek için:
keytool -printcert -jarfile Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk
```

**Beklenen Çıktı:**
```
Owner: C=US, O=Android, CN=Android Debug
SHA1: 6D:93:39:1D:7D:72:DE:A2:1A:2D:DB:EF:5A:ED:A3:2E:CC:2B:5D:D4
```

## 🖥️ **Windows Kurulum**

### **Taşınabilir Sürüm:**
1. `Arsivcim-v2.5.2-DEBUG-windows-x64.zip` dosyasını indirin
2. İstediğiniz klasöre çıkarın  
3. `arsiv_uygulamasi.exe` dosyasını çalıştırın

## 🎉 **Sonuç**

Bu sürüm, eski debug keystore ile imzalanmış uygulamanızla **%100 uyumludur**:

| ✅ **OLACAK** | ❌ **OLMAYACAK** |
|--------------|-----------------|
| Uygulama güncellenir | Çakışma hatası |
| Eski veriler korunur | Veri kaybı |
| Aynı kullanıcı profili | Yeni kurulum zorunluluğu |
| Yeni özellikler aktif | Paket çakışması |

## 📞 **Destek**

Bu sürüm özellikle **debug keystore uyumluluğu** için hazırlandı. Eğer hala sorun yaşarsanız:

1. **İmza SHA1**'inizi kontrol edin
2. **Version Code**'un 25 olduğunu doğrulayın  
3. GitHub Issues'da rapor edin

---

**🔐 Bu sürüm, eski debug keystore imzalı uygulamanızla kesin uyumluluk garantisi verir!** 