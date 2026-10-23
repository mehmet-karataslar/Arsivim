# Arşivim 2.6.3 — uygulama içinden güncelleme

Sürüm: `2.6.3+29`. Veritabanı şeması: `12`.

## Yenilikler

- Profil'e **Güncellemeleri kontrol et**, indirme ilerlemesi, iptal ve kurulum adımları eklendi.
- Yeni kararlı sürümler GitHub Releases üzerinden kontrol edilir. İndirilen paketlerin boyutu ve SHA-256 özeti kurulumdan önce doğrulanır.
- Windows için gerekli uygulama dosyalarını, DLL'leri, SQLite ve Visual C++ çalışma dosyalarını içeren tek kurulum EXE'si hazırlandı. Flutter veya Visual Studio kurulması gerekmez.

## İlk geçiş

Bu özelliğin çalışması için 2.6.3 sürümünü **bir kez aşağıdaki dosyalardan kurun**. Sonraki sürümleri Profil'den kontrol edip indirebilirsiniz.

### Android

**Arsivim-v2.6.3-android.apk** dosyasını açıp mevcut **Arşivim Yeni** uygulamasını güncelleyin. Uygulamayı kaldırmayın veya verilerini temizlemeyin.

Uygulama kimliği ve imzası 2.6.0/2.6.1/2.6.2 ile aynıdır; sürüm kodu 29'dur. Sonraki uygulama içi kurulumda Android kaynak izni ve **Güncelle** onayı isteyebilir. Eski 2.5.2 uygulaması ayrı kimliktedir.

### Windows

**Arsivim-v2.6.3-windows-x64-setup.exe** dosyasını indirin. İşlemlerinizi kaydedin, aktarımları tamamlayın ve Arşivim'i kapatın. Kurulumda **Kur / Güncelle**, ardından **Arşivim'i aç** düğmesine basın.

Kurulum masaüstü ve Başlat menüsü kısayollarını oluşturur. Bundan sonra eski ZIP klasöründeki EXE yerine bu kısayolu kullanın. Aynı Windows kullanıcısının mevcut arşivi korunur. Kurulum yönetici yetkisi istemez; Windows 10/11 x64 hedeflenir.

Windows EXE'si Authenticode sertifikasıyla imzalanmamıştır; Windows indirme itibarına bağlı uyarı gösterebilir.

## Doğrulama ve kullanım notları

- 26 Flutter testi ve 46 Windows kurulum/bağımlılık kontrolü geçti; değişen Dart dosyalarında analiz hatası yok.
- Android yayın imzası ve 2.6.2 üzerine paket yükseltme uyumu doğrulandı. Android ve Windows release derlemeleri başarılı.
- Gerçek müşteri cihazında kurulum/onay ve temiz Windows ilk açılış testi yapılmadı.
- İndirme sırasında uygulamayı açık tutun; diğer sekmeleri kullanabilirsiniz. Kurulum son adımı kullanıcı onayı gerektirir.
- SHA-256 özetleri `SHA256SUMS.txt`, kaynak commit ve doğrulama kapsamı `release-manifest.json` içindedir.

Ayrıntılı kullanım rehberi: [UYGULAMA_GUNCELLEME.md](https://github.com/mehmet-karataslar/Arsivim/blob/master/docs/UYGULAMA_GUNCELLEME.md).
