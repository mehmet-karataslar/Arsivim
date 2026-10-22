# Arşivim 2.6.2 — Android ve Windows

Sürüm: `2.6.2+28`. Veritabanı şeması: `12`.

## Değişiklikler

- Ana sayfadaki canlı arama tüm arşivde çalışır ve sonuçlar sayfalanır.
- Arama; dosya adı, uzantı, kişi ve kategori bilgilerini kapsar. Türkçe I/İ/ı/i ve Almanca umlaut/ß eşleştirmeleri genişletildi.
- Wi-Fi/hotspot adres seçimi, QR adreslerinin güncelliği ve iki yönlü bağlantı doğrulaması iyileştirildi. Ekrandaki eski bağlantı kaydı doğrulanmadan bağlı kabul edilmez.
- Ağ sunucusu açılışta otomatik başlatılmaz; senkronizasyon bağlantısı açıldığında çalışır.
- Android depolama izni sürüme göre istenir. Bildirim başlatma ve hata kayıtları düzenlendi.
- 2.6.1'deki Android ilk veritabanı açılış düzeltmesi korunur.

## Android güncellemesi

`Arsivim-v2.6.2-android.apk` dosyasını açıp **Arşivim Yeni → Güncelle** seçeneğini kullanın. Mevcut uygulamayı kaldırmayın veya verilerini temizlemeyin.

Uygulama kimliği `com.mehmetkarataslar.arsivim` ve kalıcı imza 2.6.0/2.6.1 ile aynıdır. Sürüm kodu 28'e yükseltildi. Güncelleme mevcut uygulama verilerini kullanır; veritabanını sıfırlamaz. Eski Arşivim 2.5.2 ayrı uygulamadır ve arşivi kendiliğinden aktarılmaz.

## Windows güncellemesi

1. Mevcut arşivin veritabanı ve belge/fotoğraf dosyalarını yedekleyin, eski EXE'yi kapatın.
2. `Arsivim-v2.6.2-windows-x64.zip` dosyasını ayrı bir klasöre bütünüyle çıkarın.
3. İçindeki `arsiv_uygulamasi.exe` dosyasını çalıştırın. DLL'leri ve `data/` klasörünü EXE'den ayırmayın.

Aynı Windows kullanıcısının Belgeler klasöründeki mevcut arşiv kullanılmaya devam eder. Yeni veritabanı şema artışı yoktur. Önceki sürümlerden şema 12'ye geçiş için mevcut yedekleme ve içerik koruma kontrolleri geçerlidir.

## Bağlantı ve doğrulama

Telefon ve bilgisayarı 2.6.2'ye güncelleyin. Aynı yerel ağda senkronizasyon bağlantısını açın; yeni QR oluşturup eşleştirin. İki cihazda uygulamayı ön planda tutun. Eski 2.5.2 uygulamasıyla aynı telefonda eşzamanlı aktarım başlatmayın; aynı portu kullanır.

Yayın dosyalarının SHA-256 özetleri `SHA256SUMS.txt`, kaynak commit ve doğrulama sonuçları `release-manifest.json` dosyasındadır. Paketler kullanıcı verisi, özel imza anahtarı veya parola içermez. Yayın işlemi cihazlara kurulum yapmaz; gerçek cihazlarda açılış ve aktarım ayrıca doğrulanmalıdır.
