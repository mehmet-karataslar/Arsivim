# Arşivim 2.6.0 dağıtımı

Bu sürüm Windows arşivini koruyarak yükseltmek ve Android'de yeni uygulama kimliğiyle ayrı kurulum yapmak için hazırlanmıştır. Telefonun eski uygulaması kendiliğinden güncellenmez veya kaldırılmaz.

## Android

- Sürüm: `2.6.0+26`.
- Yeni uygulama kimliği: `com.mehmetkarataslar.arsivim`.
- Telefonda görünen ad: **Arşivim Yeni**.
- Eski uygulama kimliği `com.example.arsiv_uygulamasi` ile yan yana kurulabilir.
- Yeni uygulama eski uygulamanın özel veritabanını kendiliğinden okuyamaz. Arşiv, yeni Windows sürümüyle eşleştirme ve aktarım yapıldıktan sonra kullanılabilir.
- İlk açılıştan önce eski Arşivim'i Android uygulama ayarlarından **Durdurmaya zorla** ile kapatın; **verileri temizle/kaldır** seçeneğini kullanmayın. Eski ve yeni sürüm aynı telefonda 8080 aktarım portunu kullandığından aynı anda açık çalıştırılmamalıdır. Eski uygulamayı sadece arka plana almak portu serbest bırakmayabilir.
- Kalıcı imzanın herkese açık özeti `android/release-identity.json`, sertifikası `android/release-certificate.pem` içindedir. Bunlar özel anahtar değildir.
- Gerçek anahtar ve parolalar Git dışında `private-signing/android/` altında saklanır. İkinci yerel kopya `D:\Arsivim-Imza-Yedegi\android-2026` konumundadır. İki kopya aynı bilgisayardadır; bilgisayar kaybına karşı ayrıca kullanıcıya ait bağımsız bir ortamda saklanmalıdır.
- `android/key.properties` yerel anahtara işaret eder. Release derlemesi bu dosya olmadan durur. Sonraki sürümlerde aynı anahtar kullanılmalı ve `pubspec.yaml` sürüm kodu artırılmalıdır.

Derleme ve yayın denetimi:

```powershell
flutter build apk --release --no-pub
./scripts/Test-AndroidRelease.ps1 -CandidateApk build/app/outputs/flutter-apk/app-release.apk
```

Sonraki **aynı kimlikli** sürümlerin üzerine kurulum denetimi:

```powershell
./scripts/Test-ApkUpgrade.ps1 -PreviousApk onceki-yeni-kimlikli.apk -CandidateApk sonraki.apk
./scripts/Inspect-InstalledAndroid.ps1 -CandidateApk sonraki.apk
```

Eski telefon uygulamasını incelemek için `Inspect-InstalledAndroid.ps1` komutuna ayrıca `-PackageName com.example.arsiv_uygulamasi` verilmelidir. Eski APK ile bu yeni APK'nın üzerine kurulum kontrolünden geçmemesi beklenen davranıştır.

## Windows

Windows ZIP'i EXE, bütün DLL dosyaları ve `data/` klasörünü içerir. Yalnızca EXE'yi ayırarak kullanmayın. ZIP'i bütünüyle ayrı bir sürüm klasörüne çıkarın ve içindeki `arsiv_uygulamasi.exe` dosyasını çalıştırın.

Önce eski uygulamayı kapatın ve mevcut veritabanı ile belge/fotoğraf dosyalarını yedekleyin. Aynı Windows kullanıcısının Belgeler klasöründeki mevcut `arsiv.db` kullanılmaya devam eder. Şema 12 geçişi öncesi bağımsız DB yedeği alınır; eski tablo içerikleri doğrulanır. Belge dosyaları ayrı olduğundan bu otomatik DB yedeği tek başına tam arşiv yedeği değildir.

Yeni sürüm açıldıktan sonra eski EXE'yi aynı arşiv üzerinde çalıştırmayın. Yeni sürümler eşzamanlı açılmayı engeller; önceden dağıtılmış eski sürümün tüm davranışları geriye dönük değiştirilemez.

```powershell
flutter build windows --release --no-pub
```

## Geçiş sırası

1. Mevcut Windows arşivini ve telefona özel kayıtları koruyun.
2. Windows'ta yeni sürümü açıp arşivin bulunduğunu doğrulayın.
3. Android APK'yı yeni uygulama olarak kurun; eski uygulamayı kaldırmadan durdurun ve yenisini açın.
4. Aynı arşiv hesabıyla yeni eşleştirmeyi tamamlayın ve Windows'tan aktarın. Eski aktarım protokolüyle devam etmeyin.
5. Kişi/kategori kayıtlarını, belge bağlantılarını, sayıları ve dosya içeriklerini iki cihazda karşılaştırın. Yalnızca telefonda bulunan kayıtları ayrıca dahil edin.
6. Eski uygulamanın kaldırılmasını ancak gerçek veri aktarımı ve açılış kontrolleri tamamlandıktan sonra değerlendirin.

Bu yayın paketleri hazırlanmış dağıtımlardır; kullanıcı cihazlarına kurulum veya gerçek arşivin taşınması yayın işlemiyle otomatik yapılmaz. Oturumlar, cihaz güven anahtarları ve bütün geçmiş tabloları belge aktarımıyla birebir klonlanmış sayılmaz.
