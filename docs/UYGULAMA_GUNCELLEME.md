# Uygulama içinden güncelleme — 2.6.3

## Kullanıcı akışı

Profil → **Güncellemeleri kontrol et** → **Güncellemeyi indir** → **Güncellemeyi kur**.
Yüklü sürüm, yeni sürüm, sürüm notları, indirme yüzdesi ve anlaşılır hata mesajları
aynı bölümde gösterilir. İndirme iptal edilebilir ve yeniden başlatılabilir.
Sekme değiştirildiğinde indirme sürer. Bu bir işletim sistemi arka plan indirme
servisi değildir: uygulama kapatılırsa veya Android süreci sonlandırırsa yeniden
indirmek gerekir. İndirme sırasında uygulamayı açık tutun.

İlk geçişte 2.6.3 APK ve Windows kurulum EXE'si bir kez elle kurulur. Önceki
sürümlerde bu düğme bulunmaz. Sonraki sürümler bu ekran üzerinden alınır.

### Android

`Arsivim-v2.6.3-android.apk`, mevcut 2.6.0/2.6.1/2.6.2 **Arşivim Yeni** uygulamasının
üzerine kurulur. Uygulamayı kaldırmayın veya verilerini temizlemeyin.
Android ilk kullanımda bu uygulamaya bilinmeyen uygulama yükleme izni ister.
Açılan ayarlarda izin verip Profil'e dönün ve **Güncellemeyi kur** düğmesine
yeniden basın. Sistem ekranında **Güncelle** onayı gerekir; sessiz kurulum yapılmaz.

APK kimliği `com.mehmetkarataslar.arsivim`, sürüm kodu ve imza Android tarafında
da doğrulanır. Eski 2.5.2 uygulaması ayrı kimliktedir; otomatik veri aktarımı yoktur.

### Windows

Müşteriye **Arsivim-v2.6.3-windows-x64-setup.exe** verilir. Tek dosyalık bu paket
uygulamayı, Flutter/eklenti DLL'lerini, SQLite'ı, Visual C++ çalışma DLL'lerini ve
`data/` kaynaklarını içerir. Flutter, Visual Studio veya ayrı derleyici kurulmaz.
Windows 10/11 x64 ve Windows'un .NET Framework 4.x çalışma ortamı kullanılır.
Windows ARM64 ve diğer sistemler bu dağıtımın doğrulanmış hedefleri değildir.

1. İşlemlerinizi kaydedin, aktarımları tamamlayın ve Arşivim'i kapatın.
2. Kurulum EXE'sini açıp **Kur / Güncelle** düğmesine basın.
3. **Arşivim'i aç** düğmesini veya oluşturulan masaüstü/Başlat kısayolunu kullanın.

Kurulum kullanıcıya özel `%LOCALAPPDATA%\Programs\Arsivim` konumundadır;
yönetici yetkisi istemez. Eski taşınabilir ZIP kopyasının yerine yeni kısayolu
kullanın. Aynı Windows kullanıcısının Belgeler klasöründeki mevcut arşiv korunur.
Program açıkken kurulum başlamaz; uygulama zorla sonlandırılmaz. Paket önce ayrı
bir geçici klasöre hazırlanır, mevcut program `.previous` klasörüne taşınır.
Yeni program klasörünü yerine taşıma işlemi başarısız olursa eski klasör geri
getirilir. Bu, elektrik kesintisine karşı tam işlem günlüğü veya veritabanı
sürüm düşürme desteği değildir. Arşiv yedekleri uygulamanın Yedekleme bölümündedir.

Windows paketi Authenticode sertifikasıyla imzalanmamıştır; Windows indirme
itibarına bağlı uyarı gösterebilir. Uygulama içinden indirmede GitHub SHA-256
doğrulaması uygulanır. Bu kontrol yayıncı sertifikasının yerine geçmez.

## Her yeni yayında

1. `pubspec.yaml` içindeki hem sürüm adını hem sürüm kodunu artırın. Yalnızca
   `+build` artırımı yeni sürüm sayılmaz; örneğin `2.6.4+30` kullanın.
2. Android kalıcı yayın anahtarını ve uygulama kimliğini değiştirmeyin.
3. `flutter build apk --release` ve
   `./scripts/Test-AndroidRelease.ps1 -CandidateApk ./build/app/outputs/flutter-apk/app-release.apk`
   çalıştırın. Önceki APK ile `Test-ApkUpgrade.ps1` kontrolünü de çalıştırın.
4. `./scripts/Build-WindowsInstaller.ps1` çalıştırın. Betik sürüm eşleşmesini,
   Flutter dosyalarını ve müşteri çalışma bağımlılıklarını kontrol eder. Ek
   kurulum derleyicisi indirilmez; mevcut Windows .NET derleyicisi kullanılır.
5. GitHub Releases'te `v2.6.4` gibi **kararlı** bir yayın hazırlayın. APK'yı
   `Arsivim-v2.6.4-android.apk`, kurulum EXE'sini
   `Arsivim-v2.6.4-windows-x64-setup.exe` adıyla ekleyin. Harfler ve adlar birebir
   eşleşmelidir. Ham uygulama EXE'si veya ZIP, güncelleyici tarafından kurulmaz.
6. İki paket de yüklendikten ve GitHub `digest: sha256:…` alanları oluştuktan sonra
   taslağı yayımlayın ve **Latest** olarak işaretleyin. Kaynak kod deposuna dosya
   eklemek tek başına yeterli değildir. Yayın notları uygulamada görüntülenir.

Kaynak: `https://api.github.com/repos/mehmet-karataslar/Arsivim/releases/latest`.
Herkese açık yayınlara kimlik doğrulamasız erişilir; uygulamaya GitHub erişim
anahtarı gömülmez. Taslak/ön yayın, eksik platform paketi, yanlış indirme adresi,
eksik SHA-256 ve boyut uyuşmazlıkları kuruluma geçmez. Bozuk/eksik dosyalar silinir.

## Doğrulama

- `flutter test --no-pub test/app_update_test.dart test/theme_test.dart`
- `flutter analyze --no-pub lib/services/app_update_service.dart lib/widgets/profile/profile_update.dart lib/screens/profil_ekrani.dart test/app_update_test.dart`
- `./scripts/Test-WindowsInstaller.ps1 -InstallerPath <üretilen-setup.exe>`
- Android/Windows release derlemesi ve APK kimlik/imza/sürüm karşılaştırması.

Windows kurulum regresyonları yalnızca çalışma alanındaki geçici test klasörüne
kurar; gerçek müşteri arşivini açmaz. Gerçek Android cihazındaki izin ekranı ve
kurulum onayı ile temiz Windows bilgisayarındaki ilk açılış ayrıca müşteri kabul
testi olarak yapılmalıdır. Yerel test sonucu bu cihaz testlerinin yerine geçmez.

2.6.3 paketleri: [GitHub Releases](https://github.com/mehmet-karataslar/Arsivim/releases/tag/v2.6.3).
İlk kurulum için bu yayındaki APK ve Windows kurulum EXE'sini kullanın.
