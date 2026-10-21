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

### Profil ve renk paletleri

Gezinme menüsündeki **Profil** sekmesi hesap bilgilerini ve görünüm tercihlerini
aynı sayfada toplar. Varsayılan orman yeşiline ek olarak arduvaz mavisi, petrol,
mürdüm ve toprak paletleri bulunur. Seçim cihazda saklanır, yeniden açılışta
yüklenir ve Profil içinden varsayılan yeşile döndürülebilir.

Tema altyapısı `lib/theme/app_palette.dart`, `lib/theme/app_theme.dart` ve
`lib/providers/theme_controller.dart` içinde tutulur. Yeni sayfalar ana renk,
zemin, metin ve çerçeveler için `Theme.of(context).colorScheme` kullanmalıdır:
`primary/onPrimary`, `primaryContainer/onPrimaryContainer`,
`surface/onSurface`, `onSurfaceVariant` ve `outlineVariant`.
Açılış gibi koyu marka yüzeyleri `BrandColors` tema uzantısından alınır.
Kategori renkleri kullanıcı verisidir; tema seçimi bu verileri değiştirmez.

Bu aşamada açık zeminli renk paletleri desteklenir. Ana sayfa, Belgeler, Kategoriler, Profil, ortak tema,
gezinme ve açılış renkleri entegredir; diğer sayfalardaki sabit renkler,
sayfa sayfa yapılacak tasarım çalışmasında taşınacaktır. Hesap bölümü mevcut
oturum bilgilerini gösterir; hesap düzenleme kontrolleri ayrıca eklenebilir.

Doğrulama: `flutter test --no-pub test/theme_test.dart`.
Windows'ta görsel önizlemeler için
`flutter test --no-pub --dart-define=CAPTURE_THEME_PREVIEW=true test/theme_test.dart`
komutu `artifacts/theme/` altında mobil ve masaüstü PNG çıktıları oluşturur.

### Ortak arayüz bileşenleri ve ana sayfa

- `lib/widgets/common/`: `AppCard` ortak kart yüzeyi, `AppStatCard` bilgi kartı,
  `AppActionCard` işlem kartı, `AppSectionHeader` bölüm başlığı, `AppHeader`
  üst çubuk ve `AdaptiveCardLayout` genişlik/yazı boyutuna uyumlu kart yerleşimi.
  Kartlar sabit yükseklik veya platform türüne göre boyutlandırılmaz.
- `lib/widgets/home/`: özet, hızlı işlemler, son belgeler ve veritabanı bilgi
  penceresi. Bu bileşenler veri sorgulamaz; veriyi ve işlem callback'lerini alır.
- `lib/models/ana_sayfa_ozeti.dart`: ana sayfanın veri modeli.
- `lib/screens/ana_ekran.dart`: veri yükleme ve gezinme. Yenilemeler aynı devam
  eden isteği paylaşır, yüklenmiş içerik korunur, hata halinde tekrar denenebilir.
  Son belge sorgusu beş kayıtla sınırlıdır; iç içe kaydırılan listeler ve sürekli
  animasyonlar kullanılmaz. Tema değişikliği veri sorgusunu yeniden başlatmaz.

Yeni sayfalarda aynı kart bileşenleri ve `ColorScheme` rolleri kullanılmalıdır.
Profil bölüm kartları da `AppCard` kullanır. Ana sayfa ve ortak bileşen testleri:
`flutter test --no-pub test/home_test.dart test/theme_test.dart`.
Windows'ta örnek verili görseller:
`flutter test --no-pub --dart-define=CAPTURE_HOME_PREVIEW=true test/home_test.dart`.
Çıktılar `artifacts/home/` klasörüne yazılır. Widget testleri taşma ve etkileşimleri
doğrular; gerçek cihazda kare süresi ölçümü yerine geçmez.

### Belge ekleme ve düzenleme

- `DocumentEditorScreen` ortak düzeni; `widgets/document_editor/` kaynak, dosya
  bilgileri, detaylar, aramalı bağlantı seçimi, canlı özet ve alt işlemleri içerir.
  Masaüstü yan menüsü mevcut uygulama kabuğuna döner. Mobilde başlık ortalanır,
  dış bölüm kartları kaldırılır; kayıt işlemleri ve alt gezinme erişilebilir kalır.
  Dosya Seç / Fotoğraf Seç tüm genişliklerde iki sütundur. Mobilde alttaki
  tekrar dosya seçimi alanı, ayrı dosya türü bölümü ve yinelenen özet kaldırılır;
  tür ve boyut dosya satırında görünür. Masaüstü sürükle-bırak alanı korunur. Mobil kişi/kategori
  seçimi ekranın %95 yüksekliğinde, aramalı ve kaydırılabilir alt panelde açılır;
  seçim sayacı, seçilenler filtresi, temizleme ve sabit uygulama düğmesi bulunur.
- `DocumentEditorController` dosya kuyruğu, seçimler, kayıt ve taslak durumunu;
  `DocumentEditorRepository` atomik düzenleme, ilişki doğrulama ve taslak kayıtlarını
  yönetir. Taslaklar hesap ve belgeye göre ayrılır; kaynak dosyaları referanslarıyla
  saklar. Kaynak taşınmış/silinmişse yeniden seçim istenir. Çoklu eklemede başlıklar
  dosya adlarından üretilir; diğer alanlar seçilen dosyaların tamamına uygulanır.
- Sürükle-bırak, dosya/fotoğraf seçimi ve mobil PDF taraması kullanılabilir.
  [desktop_drop 0.6.1](https://pub.dev/packages/desktop_drop/versions/0.6.1)
  mevcut Flutter sürümüyle uyumlu olacak şekilde sabitlendi. PDF sıkıştırması
  ayrı isolate üzerinde çalışır. Sürekli animasyon veya form yazarken DB sorgusu yoktur.
- Şema 11: `kisi_ids` / `kategori_ids` ek bağlantıları saklar; eski `kisi_id` /
  `kategori_id` birincil bağlantıları korunur. Filtreler ve kategori/kişi ayrıntıları
  tüm bağlantıları kullanır; toplam belge ve depolama hesabında çift sayım yapılmaz.
  Yedek manifesti çoklu bağlantıları ve ilgili kişi kimliklerini içerir.
- Aktarım protokolü 3 çoklu referansları metadata hash'ine dahil eder ve hedefin
  yerel kimliklerine çevirir. İki cihaz da güncellenmelidir; eski alıcıya sessizce
  eksik bağlantı gönderilmez. HTTP yol adları geriye dönük olarak `/sync/v2` kalır.
- Düzenlemede başka işlemde değişen kayıt üzerine yazılmaz. Yinelenen dosyada yeni
  kopya temizlenir; mevcut belge korunur. Kısmi ekleme hatasında başarılı dosyalar
  tekrar kuyruğa alınmaz ve kalan dosyalar formda gösterilir.

### Referans tasarımlar ve mobil yerleşim

#### Sayfa envanteri ve tasarım durumu — 21 Ekim 2026

Envanterde 18 sayfa girişi bulunuyor. Ekleme ve düzenleme girişleri ortak
`DocumentEditorScreen` ekranını kullanıyor. Ekleme/düzenleme modları ve ekran içi
iletişim kutuları ayrı sayfa olarak sayılmadı. Yeni sayfanın ayrıntılı tasarımına
kullanıcının seçimiyle geçilir; ortak mobil başlık ve gezinme düzeltmeleri tüm
ana sekmelere uygulanır.

| Sayfa | Kaynak | Durum |
| --- | --- | --- |
| Ana Sayfa / uygulama kabuğu | `lib/screens/ana_ekran.dart` | Referans tasarımı ve sade mobil görünüm uygulandı |
| Belgeler | `lib/screens/belgeler_ekrani.dart` | Referans tasarımı, mobil arama/filtre ve ortak belge kartları uygulandı |
| Kategoriler | `lib/screens/kategoriler_ekrani.dart` | Referans tasarımı ve uyarlanabilir kart düzeni uygulandı |
| Profil | `lib/screens/profil_ekrani.dart` | Hesap ve kalıcı tema tercihleri modüler; mobil bölüm çerçeveleri ve hesap sorgusu denetlendi |
| Kişiler | `lib/screens/kisiler_ekrani.dart` | Referans kart düzeni, seçime bağlı ayrıntı paneli ve mobil alt panel uygulandı |
| Senkronizasyon | `lib/screens/senkronizasyon_ekrani.dart` | Referans panel düzeni, gerçek sunucu/aktarım kontrolleri ve sade mobil görünüm uygulandı |
| Yedekleme | `lib/screens/yedekleme_ekrani.dart` | Referans düzen, kişi/kategori seçimi, canlı özet ve kalıcı işlem geçmişi uygulandı; yalnızca bilgisayarda |
| Yeni belge ekle | `lib/screens/yeni_belge_ekle_ekrani.dart` | Referans form, canlı özet, taslak ve çoklu bağlantılar uygulandı |
| Belge düzenle | `lib/screens/belge_duzenle_ekrani.dart` | Ortak form, mevcut dosyayı koruma ve çoklu bağlantılar uygulandı |
| Kişi ekle / düzenle | `lib/screens/kisi_ekle_ekrani.dart` | İki mod aynı ekran; bekliyor |
| Kişinin belgeleri | `lib/screens/kisi_belgeleri_ekrani.dart` | Çağıran ekran kalmadı; Kişiler artık ortak Belgeler sayfasını kişi filtresiyle açıyor. Eski kod korunuyor |
| Açılış | `lib/screens/splash_screen.dart` | Tema renkleri bağlı; tam tasarım denetimi bekliyor |
| Giriş | `lib/screens/auth/login_screen.dart` | Bekliyor |
| Kayıt | `lib/screens/auth/register_screen.dart` | Bekliyor |
| QR bağlantı | `lib/widgets/qr_generator_widget.dart` (`QRConnectionScreen`) | Çağıran ekran kalmadı; Senkronizasyon kendi süre kontrollü QR panelini ve büyütme penceresini kullanıyor. Eski kod korunuyor |
| QR tarayıcı | `lib/widgets/qr_scanner_widget.dart` (`QRScannerScreen`) | Bekliyor |
| Belge tarayıcı | `lib/screens/tarayici_ekrani.dart` | Kod var; `lib/` içinde ekranı açan çağrı bulunamadı |
| Senkron belgeler | `lib/screens/senkron_belgeler_ekrani.dart` | Kod var; `lib/` içinde ekranı açan çağrı bulunamadı |

Güncel ayrım: 7 ana sayfa ve 2 belge formunun tasarımı yenilendi, 5 ekranın ayrıntılı tasarımı
bekliyor. Kalan 4 eski ekran sınıfını açan bir çağrı bulunmuyor; bunlar aktif
ekranlarla aynı iş listesinde değerlendirilmemeli. Yeni ekran eklenmeden veya
eski kod kaldırılmadan önce kullanım kararı verilmelidir.

Sayfa içi denetim parçaları: kategori düzenleme ve filtreleme, belge filtreleri
ve işlem onayları, kişi seçimi, yedekleme klasörü seçimi, aktarım durumu ve
sonuçları, hesap doğrulama/hata iletileri. Çağrısı bulunamayan ekranlar silinmedi;
erişim ve kullanım kararı verilmeden tamamlanmış sayılmaz.

Ana sayfa, Belgeler, Kategoriler ve Kişiler aynı `WorkspaceToolbar`, `AppSidebar`,
`AppCard`, `ToneButton`, `MetricGrid` ve `ViewModeSwitch` bileşenlerini kullanır.
Masaüstünde sol gezinme, mobilde altı hedefli, simge ve ad içeren alt menü bulunur. Yedekleme yalnızca
bilgisayar görünümünde sunulur; mobil hızlı işlemlerden de kaldırılır. Dar alanda
Senkronizasyon etiketi Senkron olarak kısalır; büyük erişilebilirlik yazısında
menü yazıyı küçültmeden yatay kayar. Seçili sekmenin
adı mobilde üst çubukta ortalanır. Bilgi kartlarının gösterildiği ekranlarda
kartlar genişliğe ve yazı ölçeğine göre iki veya dört sütun olur.
600 pikselin altında ve 1100 pikselden dar, 500 pikselden kısa yatay ekranlarda
kartların dışındaki yatay sayfa boşluğu kaldırılır (`WorkspaceLayout`).
`SectionSurface` mobilde kart listesini ikinci bir kart çerçevesine almaz.
Metinler ve kontroller kendi iç boşluklarını korur. Depolama kartları yalnızca
gerçek kullanılan alanı gösterir; varsayılan kota veya doluluk yüzdesi yoktur.

Mobil Ana Sayfa ve Belgeler'de özet kartları, hızlı işlem panelleri ve yatay
uzantı filtreleri gösterilmez. `MobileWorkspaceToolbar` aramayı ve açılır filtre
kontrolünü, `MobileWorkspace` sağ alttaki ekleme düğmesini paylaşır.
Kategoriler ve Kişiler de mobilde bu bileşenleri kullanır; özetler ve yan
paneller kaldırılır, filtreler açılır kapanır. Kartlar iki sütun halinde
ek yerleşim çerçevesi olmadan gösterilir.
`DocumentFilterPanel` kişi, kategori, tür, tarih, boyut ve sıralamayı tek formda
toplar; iptal değişiklikleri uygulamaz. Ana Sayfa'nın tür filtresi son belgeler
üzerindedir; arama gönderildiğinde tüm arşivin sonuçları Belgeler'de açılır.
`DocumentActions` dört işlemi tek satırda tutar; büyük erişilebilirlik yazısında
dar düğmeler açıklamalı simgelere geçer. Kart başlığı iki satırla, kişi/kategori/
tarih ayrı ve taşmayan satırlarla gösterilir; tam metin açıklamada korunur.

- `lib/providers/documents_controller.dart`: 280 ms arama gecikmesi, eski istek
  sonuçlarının elenmesi, 25 kayıtlık sayfalama ve hata/yenileme durumu.
- `lib/services/document_repository.dart`: tüm aktif arşiv üzerinde parametreli
  arama, tür/kişi/kategori/tarih/boyut filtreleri, sıralama ve toplu istatistik.
- `lib/widgets/documents/`: hızlı filtreler, filtre penceresi ve işlem geçmişi.
  `DocumentTile` ana sayfada da kullanılan aç/paylaş/düzenle/sil kartıdır.
- `lib/providers/categories_controller.dart` ve `lib/services/category_repository.dart`:
  kategori araması, sıralama, gruplama, yıldızlar ve tek sorguda belge sayıları.
  Kategori okumaları kendiliğinden yeni kategori eklemez.
- `lib/widgets/categories/`: kategori kartı, düzenleme formu, filtreler, sağ
  paneller ve mevcut onaylı toplu işlemler birbirinden ayrı bileşenlerdir.

- `lib/widgets/profile/`: hesap, görünüm tercihleri, palet kartı ve bölüm yüzeyi
  ayrı bileşenlerdir. Tema değişirken hesap doğrulama sorgusu tekrarlanmaz.
- `lib/widgets/people/`: kişi kartı, avatar, filtreler ve ayrıntı paneli.
  Masaüstünde seçilen kişinin paneli sağda; dar ekranlarda alt panelde açılır.
- `PeopleRepository`: sayılar ve kategoriler iki toplu sorguyla okunur. Panel
  seçili kişinin son 10 belgesini, açıklaması olan son 20 belgesini ve gerçek
  dosya konumlarını gösterir. Klasörler sanal klasör, Notlar ayrı kişi notu
  değildir. Geçmiş verisi olmayan artış yüzdeleri veya grafikler üretilmez.
- `PeopleController`: arama/filtre/sıralama bellekte; kart satırları ihtiyaç
  oldukça oluşturulur. Hızlı seçimlerde eski yanıt yeni kişinin paneline yazılmaz.
  Kişi silme mevcut pasife alma davranışını korur; belgeleri silmez.

Kişiler önizlemeleri örnek test verileriyle üretilir:
`flutter test --dart-define=CAPTURE_PEOPLE_PREVIEW=true test/people_test.dart`.
Çıktılar `artifacts/people/` altında 390 ve 1672 piksel PNG dosyalarıdır.

Senkronizasyon sayfası `widgets/sync/` altında durum, seçenekler, kontroller,
cihaz/QR, istatistik ve geçmiş bileşenlerine ayrılır. `SyncRepository` aktif belge
sayılarını SQL ile toplar; bugünkü farklı dosyaları doğrulanmış `aktarim_gecmisi`
kayıtlarından yerel gün sınırlarıyla hesaplar. Son 30 kayıt gösterilir. İlk
aktarımı olmayan arşiv için geçmiş veya başarı yüzdesi üretilmez. Son yedekleme
Ana Sayfa ile aynı başarılı yedek kaydından okunur. Ağ alanı yerel IP'yi gösterir;
Wi-Fi adı veya ağ değiştirme işlevi taklit edilmez.

`SyncController` seçim/işlem/yükleme durumunu, `SyncGateway` mevcut doğrulanmış
aktarım servisine bağlantıyı yönetir. Sunucu düğmesi HTTP sunucusunu gerçekten
başlatır/durdurur. Başlat seçili cihazlara, Tümünü bağlı cihazlara tüm aktif
belgeleri gönderir. Hızlı senkron yalnızca bekleyen yerel değişiklikleri gönderir;
yeni cihazın tam arşivini kurmak için tüm belgeler kullanılmalıdır. Durdur,
devam eden dosyanın tamamlanmasını bekler ve kalan dosya/cihaz sırasını keser.

QR oluşturma mevcut yönetici doğrulamasını, tarama hesap eşleştirme onayını
korur; kod süresi dolunca gösterilmez. Sürekli animasyon veya 10/15 saniyelik
tüm arşiv taraması yoktur. Gelen dosya, bağlantı ve sunucu olayları yenilemeyi
birleştirir; uygulamaya dönüş ve elle yenileme de desteklenir. İşlemler sürerken
son yüklenen içerik ekranda kalır. Mobilde ayrıntılı istatistikler açılır bölümde,
kontroller iki sütundadır. Örnek verili önizleme:
`flutter test --dart-define=CAPTURE_SYNC_PREVIEW=true test/sync_test.dart`;
çıktılar `artifacts/sync/` altına yazılır. Ağ geçidi testlerde taklit edilir;
widget önizlemesi gerçek iki cihaz arasındaki aktarım testi değildir.

Kategori yıldızları, grupları ve bu ekrandaki düzenleme zamanları cihazda
saklanan görünüm tercihleridir; cihazlar arasında senkronize edilmez. Son
güncelleme, kayıtlı kategori düzenlemesi ile kategori belgelerinin güncelleme
tarihinden hesaplanır. Belge etkinlik geçmişi başarılı açma/paylaşma/düzenleme
işlemleriyle oluşur ve son 100 kayıtla sınırlıdır. Paylaşım sonucu platformda
doğrulanamıyorsa paylaşılmış gibi gösterilmez. Eski işlemler için yapay geçmiş
üretilmez. Son yedekleme yalnızca başarıyla tamamlanan yeni yedeklerden kaydedilir.

Kontroller: `flutter test`. Windows'ta örnek verili ekran görüntüleri için:

```powershell
flutter test --dart-define=CAPTURE_HOME_PREVIEW=true --dart-define=CAPTURE_DOCUMENTS_PREVIEW=true --dart-define=CAPTURE_CATEGORIES_PREVIEW=true
```

Görseller sırasıyla `artifacts/home/`, `artifacts/documents/` ve
`artifacts/categories/` altında oluşturulur. Bunlar widget önizlemeleridir;
yerel dosya açma, işletim sistemi paylaşım penceresi ve gerçek telefondaki
performans ayrıca cihaz üzerinde denenmelidir.

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

### Yedekleme ekranı

`BackupController` seçimleri ve ilerlemeyi, `BackupRepository` veri ve işlem geçmişini yönetir.
`widgets/backup/` altındaki hedef, seçim, özet, bilgi kartları ve geçmiş bölümleri ayrı bileşenlerdir.
Kişiler ve kategoriler arama/seçim için bir defa yüklenir; kartlar 24 kayıtlık gruplarla açılır.
Birden fazla kişi/kategori bağlantısı hesaba katılır. Belge sayısı benzersiz belgeleri,
tahmini boyut kişi klasörlerine yazılacak kopyaları gösterir. Boş kategori seçimi hiçbir
belgeyi dahil etmez. Kategorisiz belgeler ayrı bir seçenekle yedeklenebilir.
Mevcut servis ZIP üretmez: doğrulanan dosyalar ve bağlantı bilgilerini içeren `manifest.json`
yeni bir klasöre yazılır. Son 50 işlem yerelde saklanır; eksik/bozuk dosya başarı sayılmaz.
Mobil gezinme ve hızlı işlemlerde Yedekleme hedefi bulunmaz.

Kontrol: `flutter test test/backup_test.dart test/guvenli_aktarim_test.dart`.

Senkronizasyonda QR gösterme/büyütme tek düğmededir. Geçerli eşleştirme kodu
aynı sayfada yeniden açıldığında yeni bilet üretilmez ve şifre tekrar istenmez.
Kullanılmış, süresi dolmuş, sunucusu durmuş veya oturumu değişmiş bir kod tekrar
kullanılmaz; yeni kod için yönetici doğrulaması gerekir. Mobildeki QR tarama
akışı ayrı bir işlem olarak korunur.

Belge ekleme kaynağı **Dosya Seç / Fotoğraf Çek** olarak sunulur. Fotoğraf Çek,
Android/iOS yerel belge tarayıcısını açar; sayfalar gözden geçirildikten sonra
tek PDF olarak forma eklenir. Android'de tarama başına en fazla 100 sayfa vardır.
Fotoğraf seçme için ayrı kart yoktur; mevcut görseller Dosya Seç ile alınabilir.
Masaüstü sürükle-bırak korunur, mobil kamera tarayıcısı bilgisayarda devre dışıdır.
PDF üretimi arka plan isolate'ında çalışır; Belgeyi kaydet işlemi PDF'yi arşive
kopyalar ve seçili çoklu kişi/kategori bağlantılarıyla kaydeder.
