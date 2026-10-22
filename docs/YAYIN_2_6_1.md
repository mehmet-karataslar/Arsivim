# Arşivim 2.6.1 — Android ilk açılış düzeltmesi

Android'in yeni SQLite veritabanına otomatik eklediği `android_metadata` dil tablosu, 2.6.0 sürümünde yanlışlıkla mevcut arşiv sayılıyordu. Veritabanı sürümü henüz 0 olduğundan koruma kontrolü “Surumu belirsiz veritabani otomatik degistirilemez” hatasıyla açılışı durduruyordu.

2.6.1 bu sistem tablosunu ilk kurulum kontrolünden ayırır. Gerçek kullanıcı tabloları bulunan sürümsüz bir veritabanı hâlâ değiştirilmeden reddedilir. Veritabanı şeması 12 olarak kalır; düzeltme veritabanını silmez veya sıfırlamaz.

## Güncelleme

1. `Arsivim-v2.6.1-android.apk` dosyasını indirin ve açın.
2. Android'in **Arşivim Yeni** için sunduğu **Güncelle** seçeneğini kullanın. Önceki uygulamayı kaldırmayın, uygulama verilerini temizlemeyin.
3. Uygulamayı yeniden açın. Boş veritabanının ilk kurulumu tamamlanır; varsa mevcut arşiv olağan açılış kontrollerinden geçer.

Paket kimliği `com.mehmetkarataslar.arsivim`, sürüm `2.6.1+27` ve imza 2.6.0 ile aynıdır. Yalnızca sürüm numarası artırılmıştır. Eski **Arşivim 2.5.2** farklı uygulamadır; bu güncelleme onu değiştirmez ve verilerini otomatik taşımaz.

Bu yayın Android düzeltmesidir. Windows'ta [2.6.0 paketini](https://github.com/mehmet-karataslar/Arsivim/releases/tag/v2.6.0) kullanmaya devam edin. İlk eşleştirme ve veri aktarımı için [2.6.0 geçiş rehberi](YAYIN_2_6_0.md) geçerlidir.

## Doğrulama

- Android'in `android_metadata(locale TEXT)` tablosunu içeren boş veritabanıyla bildirilen hata yeniden üretildi.
- Düzeltmeden sonra ilk oluşturma, tekrar açılış ve dil kaydının korunması test edildi.
- Aynı sistem tablosuyla birlikte gerçek kullanıcı verisi bulunan sürümsüz veritabanının reddedildiği, sürüm ve belge kayıtlarının korunduğu test edildi.
- Veritabanı geçiş test paketi: 14 test geçti.

APK'nın imzası ve sürümü ile 2.6.0 üzerine paket güncelleme uyumluluğu yayın öncesinde doğrulanır. Bu kontroller cihazda kurulum ve açılış testinin yerine geçmez.
