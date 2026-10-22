# Arşivim sürüm geçişi denetimi

Tarih: 22 Ekim 2026. Hedef geliştirme sürümü: **2.6.0+26**, SQLite şeması **12**, aktarım protokolü **3**.

## Sonuç ve yayın kararı

**Sonraki karar — 2.6.0 ayrı Android kurulumu:** Kullanıcı yeni uygulama kimliği, kalıcı yeni imza ve GitHub dağıtımı istedi. Yeni kimlik `com.mehmetkarataslar.arsivim`, görünen ad `Arşivim Yeni`; yayın sertifikası `android/release-identity.json` dosyasında kayıtlıdır. Bu paket eski `com.example.arsiv_uygulamasi` uygulamasının üzerine kurulum için değildir. Aşağıdaki eski anahtar uyuşmazlığı tespitleri eski kimliği koruyarak güncelleme seçeneği için geçerlidir. Yeni dağıtım ve geçiş adımları [2.6.0 yayın rehberinde](YAYIN_2_6_0.md). Özel anahtar proje içindeki Git dışı klasöre ve D: sürücüsündeki ikinci yerel kopyaya kaydedildi. Gerçek cihazlara kurulum ve veri aktarımı ayrı adım olarak bekliyor.

Windows'ta mevcut arşivin aynı Windows kullanıcısı altında devam etmesi destekleniyor. Android'de ise **debug anahtarı kullanmak uygundur, fakat eski APK ile aynı anahtar gerekir**. Bu bilgisayarın mevcut debug anahtarı GitHub'daki son APK'nın anahtarıyla eşleşmiyor. Yeni APK derlenebiliyor; bu, telefondaki eski sürümün üzerine kurulabileceği anlamına gelmiyor. Şimdilik telefon güncellemesi yayıma hazır kabul edilmemeli.

GitHub'a yeni kod/paket yüklemek cihazları kendiliğinden güncellemez. Projede otomatik güncelleme servisi veya Windows kurulum programı yok. APK elle güncellenir; Windows uygulaması bütün çalışma klasörüyle dağıtılır.

Kullanıcının doğruladığı bilgi: tek kullanıcı var, telefonda GitHub'dan indirilmiş **2.5.2** kullanılıyor. Telefon bağlandıktan sonra kurulu APK doğrudan okunarak **2.5.2 / versionCode 12 / sertifika B** olduğu doğrulandı. Bu paket, önce referans alınan `DEBUG-COMPATIBLE` (25/A) veya `UPDATE` (20/B) paketiyle aynı sürüm kodunda değildir. Güncellemede cihazdan alınan gerçek APK esas alınmalı.

## 1. İncelenen GitHub paketleri

Depo: [mehmet-karataslar/Arsivim](https://github.com/mehmet-karataslar/Arsivim). Denetim sırasında GitHub Releases API'si boş liste döndürdü. Dağıtımlar `arsiv_uygulamasi/releases/` ve `releases/` altında Git dosyaları olarak bulunuyor. Yereldeki sekiz eski APK'nın Git blob kimlikleri GitHub ağacındaki kimliklerle eşleştirildi; kökteki v2.0.0 APK ayrıca Git içeriğinden alındı. APK'lar `aapt dump badging` ve `apksigner verify --print-certs` ile incelendi.

Tüm APK'larda uygulama kimliği `com.example.arsiv_uygulamasi`.

| Paket/dosya | APK içindeki sürüm | versionCode | Sertifika |
| --- | --- | ---: | --- |
| `releases/Arsivcim-v2.0.0-android.apk` | **1.0.0** | 1 | A |
| `Arsivcim-v2.3.0.apk` | 2.3.0 | 6 | A |
| `Arsivcim-v2.4.0.apk` | 2.4.0 | 7 | A |
| `v2.4.10/Arsivcim-v2.4.10-android-FRESH.apk` | 2.4.10 | 11 | B |
| `v2.5.0/arsiv_uygulamasi_v2.5.0.apk` | 2.5.0 | **1** | A |
| `v2.5.0/arsiv_uygulamasi_v2.5.1_SIGNED.apk` | 2.5.1 | 2 | B |
| `v2.5.1/Arsivcim-v2.5.1-android.apk` | 2.5.1 | 10 | B |
| `v2.5.2/Arsivcim-v2.5.2-UPDATE.apk` | 2.5.2 | 20 | B |
| `v2.5.2-debug/Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk` | 2.5.2 | 25 | A |
| Bağlı telefondan alınan gerçek kurulu APK | 2.5.2 | **12** | **B** |
| Bu bilgisayardaki yeni debug derlemesi | 2.6.0 | 26 | **C** |

Sertifikaların SHA-256 özetleri (bunlar herkese açık sertifika bilgileridir, özel anahtar değildir):

- A: `c28fbfc951c4cf2efe28a56b6f4864777a5c7ae50a81ec368ab3ce224b649055`
- B: `dbf4aef381eeeed9e284fc534cc109e1ef529ad58b53ffba79bd5ab59852f381`
- C: `c3cdbc9c12db990e06d78ff5f8688c2332f17e07397f446d3181f6e48aff8f9b`

Önemli sonuçlar:

- “DEBUG-COMPATIBLE” bütün eski APK'larla uyumlu değil: A grubuyla aynı imzaya sahip, B grubuyla değil.
- “Yeni sürüm adı” tek başına yükseltme kanıtı değil: örneğin 2.5.0 paketinin kodu 1'e gerilemiş.
- v2.0.0 dosya adı ile gerçek uygulama sürümü farklı.
- Yeni bilgisayarda yeni oluşturulan debug anahtarı eskisiyle aynı değildir. APK içinden eski özel anahtar elde edilemez.
- Proje, Masaüstü, İndirilenler, Belgeler ve `.android` içinde yapılan dosya aramasında yalnızca mevcut debug anahtarı bulundu. Bu, diğer disklerde/yedeklerde anahtar olmadığı anlamına gelmez.

Windows tarafında yedi ZIP incelendi: EXE, Flutter DLL ve `data/app.so` içeriyorlar; arşiv veritabanı içermiyorlar. Eski EXE kaynaklarında `2.4.0+7`, `2.4.10+11`, `2.5.0+1`, `2.5.1+10`, `2.5.2+12` sürümleri görüldü. **Yalnızca EXE değiştirmek yeterli değil**: yeni `data/` ve bütün DLL dosyaları birlikte kullanılmalı.

## 2. Veri nerede, nasıl devam ediyor?

| Bileşen | Eski yapı | Yeni yapı / geçiş |
| --- | --- | --- |
| Windows veritabanı | Windows Belgeler klasöründe `arsiv.db` | Aynı konum; EXE klasöründen bağımsız |
| Android veritabanı | Uygulamanın özel Documents alanında `arsiv.db` | İzin varsa `/storage/emulated/0/Documents/Arsiv/arsiv.db`; doğrulanmış kopyalama ve konum işareti |
| Belge dosyaları | Veritabanında dosya yolu ve SHA-256; içerik ayrı dosyada | Dosya yolları korunur; Android taşımada dosyalar doğrulanıp yeni yola bağlanır |
| SQLite şeması | Son arşivlenmiş kaynak etiketi: 10 | Önceki geliştirme: 11; güvenli geçişle 12 |
| Kişi/kategori bağlantısı | `kisi_id`, `kategori_id` | Birincil bağlantılar korunur; `kisi_ids`, `kategori_ids` ek bağlantıları saklar |
| Kişi bilgileri | Kimlik, ad, kullanıcı adı, parola özeti, fotoğraf | Aynı kimlikler; e-posta/telefon/adres ek sütunlar |
| Oturum/hesap | Eski kullanıcı/parola ve oturum tercihleri | İlk girişte eski parola doğrulanır; tek arşiv yöneticisi ayrı tabloda tutulur |
| Cihazlar arası aktarım | Eski HTTP/QR akışı | Protokol 3, hesap ve cihaz doğrulaması; iki taraf da güncellenmeli |

**Yeni veritabanı açıp eski kayıtları terk etmek normal güncelleme davranışı değildir.** Mevcut veritabanı aynı dosyada yükseltilir; Android konum değişiminde doğrulanmış kopya yeni yetkili arşiv olur ve eski kaynak korunur. İki konumda belirsiz arşiv varsa otomatik birleştirme yapılmaz. Aktif açık arşive izin yoksa eski kopyaya sessiz geçiş yapılmaz.

Uygulama verileri sadece `arsiv.db` değildir: belge içerikleri, profil fotoğrafları, taslak dosyalar, cihaz tercihleri ve cihaz güven bilgilerinin ayrı saklama yerleri bulunur. Yeni kişi fotoğrafları uygulamanın Documents alanındaki `profile_photos` altında olabilir. Bu yüzden yalnızca `Belgeler/` klasörünü veya yalnızca DB dosyasını kopyalamak tam yedek sayılmaz.

Eski oturum yeni güvenlik biçiminde değilse yeniden giriş istenir; **bu, hesap veya belge silinmesi değildir**. Başarılı girişten sonra eski SHA-256 parola özeti PBKDF2 biçimine yükseltilir. Şifre aynı kalır, saklama biçimi değişir. Kullanıcı tek olsa da arşivdeki kişi kayıtları ayrı varlıklardır; kişiler silinmez.

Eski ve yeni sürümü aynı arşiv üzerinde dönüşümlü kullanmayın. Eski uygulama yeni parola biçimini ve çoklu bağlantıları bilmez. Yeni uygulama, kendisinden daha yeni şemayı açmayı reddeder; bu kontrol eski APK/EXE'ye geriye dönük olarak eklenemez.

## 3. Bulunan hatalar ve yapılan düzeltmeler

| Bulgu | Etki | Durum |
| --- | --- | --- |
| Android sürümü Gradle'da 25, pubspec'te 12 olarak ayrı tutuluyordu | Aynı sürüm numarasıyla farklı paketler | Gradle artık Flutter sürüm alanlarını kullanıyor; hedef `2.6.0+26` |
| Yükseltme hataları yakalanıp yok sayılabiliyordu | Eksik şema başarılı sanılabiliyordu | Hatalar dışarı taşınıyor; sqflite işlemi şema ve `user_version` ile geri alıyor |
| Yedek aynı DB içinde geçici üç tabloydu; hata yok sayılıyor ve ardından siliniyordu | Bağımsız kurtarma noktası yoktu | İşlem başlamadan ayrı DB yedeği, bütünlük ve SHA-256 kaydı |
| Bütünlük doğrulaması yalnızca sayıları yazdırıyordu | Aynı sayıda farklı/eksik içerik fark edilmiyordu | Bütün eski tablolardaki sütun değerleri ve tekrar sayıları karşılaştırılıyor; pasif kayıtlar dahil |
| `ALTER TABLE ... ADD COLUMN ... UNIQUE` kullanılıyordu | SQLite eski kişi şemasını yükseltemiyordu | Sütun ayrı ekleniyor, uygun kayıtlarda benzersiz indeks oluşturuluyor; eski çakışan kişiler silinmiyor |
| Sütun ekleme `onOpen` sırasında işlem dışında yapılıyordu | Yarım geçiş kalabiliyordu | Şema 12 geçişine alındı; mevcut şema açılırken yalnızca doğrulanıyor |
| Eksik ana tablo otomatik boş oluşturuluyordu | Hasarlı arşiv boşmuş gibi görünebiliyordu | Başlangıç duruyor, mevcut dosya korunuyor |
| `VACUUM INTO` eski Android SQLite sürümlerinde yok | Yedekleme/geçiş açılamıyordu | SQLite 3.27 öncesi için tutarlı okuma işlemiyle tablo, indeks, trigger ve sıra değerlerini koruyan alternatif |
| Çoklu bağlantı sorguları isteğe bağlı JSON1 uzantısına bağlıydı | Bazı eski Android SQLite motorlarında belge listeleme/sayım hatası | Tamsayı kimlik listeleri temel SQLite metin işlevleriyle sorgulanıyor; birincil bağlantı, tam kimlik eşleşmesi ve tek belge sayımı korunuyor |
| Yeni açık konum işareti DB oluşmadan yazılıyordu | Yarım ilk açılıştan sonra kalıcı erişim hatası | Yeni kurulum işareti DB açıldıktan sonra kaydediliyor |
| Konum hazırlama hatası Future içinde kalıyordu | Aynı süreçte izin düzeldikten sonra tekrar denenemiyordu | Başarısız hazırlık temizleniyor; yeniden deneme mümkün |
| Açık arşiv var, işaret yok ve yazma izni yok | Boş özel arşive geçme riski | Mevcut açık arşiv tespit edildiğinde işlem duruyor |
| Birden fazla Windows kopyası aynı DB'ye erişebiliyordu | Eski/yeni süreçler aynı anda çalışabiliyordu | Yeni runner oturum mutex'i kullanıyor; eski runner'ın açık penceresi de başlangıçta tanınıyor |
| Paket dosya adı güvenilir uyumluluk kanıtı sayılıyordu | Yanlış imzalı APK yayımlanabiliyordu | İmza doğrulayan, uygulama kimliğini ve artan kodu karşılaştıran komut eklendi |
| Paket kontrolü telefonun API/ABI bilgilerini değerlendirmiyordu | İmza doğru olsa bile cihazda kurulamayacak paket onaylanabiliyordu | İsteğe bağlı cihaz API/ABI denetimi eklendi; telefon inceleme komutu ikisini de okuyup denetime aktarır. Eksik cihaz bilgisiyle cihaz kontrolü başarılı sayılmaz |

Windows kilidinin sınırı: yeni sürümler birbirini engeller ve yeni sürüm açılırken görünen eski pencereyi tanır. Zaten dağıtılmış eski EXE, yeni sürümden sonra tekrar başlatılırsa eski kod yeni mutex'i tanımaz. Güncellemede bütün eski kopyalar kapatılmalıdır.

## 4. Doğrulama

- Son arşivlenmiş kaynaktaki `v2.5.2-debug-final` / `5d94850` etiketi üzerinden `_onCreate` SQL ifadeleri `test/fixtures/legacy_v10.sql` içine alındı. Paketlerin kaynak commit'iyle yeniden üretilebilir bağlantısı geçmişte kaydedilmemiş; bu fixture her tarihsel APK'nın şemasını kesin olarak kanıtlamaz.
- v10 → v12: kayıt kimlikleri, tarihleri, parolaları, birincil bağlantıları, pasif kayıtlar ve dosya yolları korundu.
- v11 → v12: çoklu bağlantılar, hesap ve cihaz güven tabloları korundu.
- Şema hatası, yedek klasörü oluşturma hatası, eksik ana tablo ve daha yeni DB senaryoları güvenli şekilde reddedildi.
- Aynı kayıt sayısında içerik değişikliği saptandı ve işlem geri alındı.
- WAL verisi, eski SQLite için alternatif yedekleme, trigger ve AUTOINCREMENT sıra değerleri test edildi.
- Android izin reddi, konum işareti ve yeniden deneme senaryoları dosya sistemi testleriyle denetlendi.
- Hesap/parola geçişi ve güvenli aktarım dahil odak test grubu: **75 test geçti**.
- Tam test paketi (`flutter test --no-pub`): **477 test geçti**. Geçiş dışındaki ekran, belge düzenleme, tarama, yedekleme ve aktarım regresyonları da bu çalıştırmaya dahil.
- Ardından yapılan JSON1 bağımlılığını kaldırma değişikliği için bağlantı, belge, kişi, düzenleme, senkronizasyon ve aktarım odak grubunda **35 test geçti**. 477 testlik önceki tam çalıştırma bu son değişiklikten önceydi.
- Üretilen gerçek sorgular resmi Windows SQLite **3.9.2** motorunda ayrıca denendi: 150 örnek belge için 33 kimlik filtresi ve 33 ilişkili sayım doğru sonuç verdi. Bu DLL JSON1 içerdiğinden test sırasında SQLite authorizer ile JSON erişimi engellendi ve eski `json_each` sorgusunun reddedildiği doğrulandı. Bu, gerçek Android cihaz testi değildir. Sonuç: `artifacts/upgrade-audit/sqlite-legacy-link-result.json`.
- Yerel gerçek Windows arşivi salt okunur denetlendi: **68 belge, 4 kişi, 16 kategori**, `integrity_check=ok`; aktif belgelerde **0 eksik dosya, 0 boyut/özet uyuşmazlığı**, birincil bağlantılarda **0 sahipsiz referans**.
- Gerçek DB'nin ayrı SQLite yedeği üzerinde v11 → v12 provası yapıldı; tüm mevcut tablo kayıtları aynı kaldı. Bu provayı da içeren geçiş grubu: **13 test geçti**. Kullanılan özel kopya `artifacts/upgrade-audit/` altında, Git dışında tutuluyor. Asıl DB yükseltilmedi.
- Android debug ve Windows release derlemeleri başarılı. Android paketi `2.6.0 / 26`, sertifika C olarak okundu.
- Yeni Windows EXE'sinde oturum mutex'i varken ikinci süreç başarı koduyla DB açmadan çıktı; asıl DB'nin dosya özeti değişmedi. Eski runner sınıf/adıyla oluşturulan gizli test penceresinde de aynı sonuç alındı. Gerçek arşivle normal ilk açılış yapılmadı.
- APK kontrolü A → A ve artan kod örneğini kabul etti. Son derleme, GitHub'daki **her iki 2.5.2 paketiyle** karşılaştırıldı; A → C ve B → C imza uyuşmazlıkları reddedildi. Telefona kurulum yapılmadı.
- `scripts/Test-ApkUpgradeRegression.ps1`: gerçek arşiv APK'larıyla **9 senaryo geçti**. Paket kontrolü ile cihaz kontrolünün ayrı raporlanması, minimum API sınırı, birden fazla cihaz ABI'sinden birinin eşleşmesi, uyumsuz ABI, eksik/geçersiz cihaz bilgisi ve aynı sürüm kodunun reddi denetlendi. Telefon özellikleri bu testte örnek girdilerdir; gerçek telefon bağlı değildir.

Bu sonuçlar gerçek telefondaki kurulum denemesinin, eski Android çalışma zamanı denetiminin veya donanım kamera testinin yerine geçmez. Flutter hedefinin mevcut alt sınırı API 24'tür; tarihsel pakette API 23 vardı. Telefon API/ABI uyumluluğu da cihazda kontrol edilmelidir. Çoklu bağlantı sorguları artık JSON1 gerektirmiyor; saklanan biçim uygulamanın ürettiği JSON tamsayı listeleridir.

## 5. Uygulanacak sıra

### Bağlı telefonda yapılan salt okunur inceleme

22 Ekim 2026'da ADB üzerinden model `23117RA68G`, Android **16 / API 36**, desteklenen ABI'ler `arm64-v8a, armeabi-v7a, armeabi` olarak okundu. Kurulu paketin uygulama kimliği değişmemiş. Yeni APK'nın minimum API 24 ve işlemci koşulları bu cihazla uyumlu; kontrolün tek ret nedeni **B → C imza uyuşmazlığı**.

Kurulu APK'nın SHA-256 dosya özeti: `da0f977dad977605ee3a4d2829081a1b32e32e8f81bad7a8ae091070a990f288`. Paket ve cihaz bilgileri `artifacts/upgrade-audit/device-66eb1f09616742fa86450d83982bfd1b/` altında saklandı; bu klasör Git dışında. APK kopyası veri yedeği değildir.

Telefondaki APK, İndirilenler'deki `Arsivim-2.5.2/Arsivim-2.5.2/arsiv_uygulamasi/releases/v2.5.2/Arsivcim-v2.5.2-android.apk` dosyasıyla SHA-256 düzeyinde birebir eşleşti. Aynı kaynak arşivindeki şema sabiti 10; bu kaynak bilgisi, telefondaki DB'nin doğrudan okunması anlamına gelmez.

Kullanıcı telefonda **2 belge ve 1 kişi** bulunduğunu, APK'yı bu bilgisayarda ürettiğini belirtti. Kurulu sertifikanın DN alanı `CN=Arsivim App, OU=Development, O=Arsivim, L=Istanbul, ST=Istanbul, C=TR`; eski yayın notlarında anahtar adı `arsivim-release-key.keystore`. Kullanıcı klasöründe ve D: sürücüsünde anahtar dosyası araması ile Masaüstü/Belgeler/İndirilenler altındaki 30 ZIP'in dosya listesi incelendi; bu anahtar bulunamadı. Parolalar veya anahtar içerikleri rapora alınmadı. Bu arama silinmiş dosyaları, erişilemeyen konumları ve tüm olası yedek ortamlarını kapsamaz.

`run-as` isteği Android tarafından **package not debuggable** hatasıyla reddedildi. Dolayısıyla özel uygulama veritabanı bu yolla okunamadı. Kontrol edilen `/sdcard/Documents/Arsiv`, `/sdcard/Arsiv`, `/sdcard/Arsivcim`, uygulamaya ait harici `Android/data/.../files`, `/sdcard/Download/Arsiv` ve `/sdcard/Documents/arsiv.db` yolları bulunmadı. Bu, telefonda belge olmadığı veya başka bir konumda yedek bulunmadığı anlamına gelmez.

Telefona paket kurulmadı; uygulama kaldırılmadı, durdurulmadı, veri temizlenmedi veya değiştirilmedi. Telefonun gerçek kayıtları ve DB şeması henüz doğrulanmadı. Aynı B sertifikasının özel anahtarı veya mevcut uygulamanın desteklediği, ayrıca doğrulanacak tam dışa aktarım yolu gerekiyor. Yerel Git geçmişinde `.keystore`, `.jks` ve `key.properties` dosya adlarıyla bir anahtar kaydı bulunmadı.

Eski uygulamanın kaynak kodundaki GET aktarım uçları ayrıca incelendi: belge uç noktası en fazla 50 kayıt arasından bekleyen/değişmiş belgeleri, kişi uç noktası son 6 saatte oluşturulan kişileri, kategori uç noktası bugünkü kategorileri seçiyor. Bu nedenle bu uçlar genel bir tam yedek mekanizması sayılamaz. USB üzerinden geçici port yönlendirmesiyle `/sync/status` okuma denemesi 30 saniyede zaman aşımına uğradı; veri alınamadı ve yönlendirme kaldırıldı. Arşivim o sırada ön planda değildi. Uygulama açıkken yeniden okuma, alınan kayıt ve dosyaların ayrıca doğrulanması bekleniyor.

**Sonraki deneme başarılı, fakat kopya eksik:** Uygulama açıkken yapılan salt okunur GET istekleriyle 1 kişi ve 2 belge kaydı alındı; durum uç noktası hem önce hem sonra 2 belge bildirdi. `phone-export-5cf4d899b351416ebe3f547e3907a323/` altında JSON kayıtları ve bir fotoğrafın 961411 baytlık içeriği saklandı. Fotoğrafın boyutu ve SHA-256 özeti kaynak kayıtla eşleşti. İkinci belge 31717976 baytlık MP4; eski mobil aktarım kodu 10 MB üzerindeki içeriği göndermediği için yalnızca kayıt bilgisi alındı. Kategori uç noktası zaman filtresi nedeniyle 0 kayıt döndürdü. Kullanıcıdan Yedekleme ekranıyla belge dosyalarını dışarı alması istendi; video ve kategori bilgileri henüz doğrulanmış değil. Bu sonuç tam DB yedeği veya güvenli kaldırma izni değildir. Geçici USB port yönlendirmesi işlem sonunda kaldırıldı.

Kullanıcının isteğiyle proje kökünde `ARSIVIM_IMZA_BILGILERI.txt` oluşturuldu. Bu dosya eski keystore adını, sertifika bilgilerini, paket kimliğini ve mevcut kopyalama durumunu içerir; gerçek keystore veya parola içermez.

**Video kurtarma ve gerçek kayıt provası tamamlandı:** Kullanıcı, kurulu sürümde Yedekleme sayfasının görünmediğini bildirdi; bu, eski kaynak dosyasında bir sayfa bulunmasının kurulu APK'da erişilebilir olduğunu kanıtlamadığını gösterdi. Telefonun gerçek ekranından video kartındaki **Paylaş → İndir** kullanıldı. Video `/sdcard/Download/` altında oluşturulan kopyadan USB ile alındı; 31717976 bayt ve `d21c6c274430f2ff25d95b74ad4d20b784c51bd1eef327f3013ab323bc777e55` SHA-256 değeri eski kayıtla eşleşti. Her iki belgenin dosyası artık doğrulanmış kopyada mevcut.

`test/phone_export_compatibility_test.dart`, özel dışa aktarım dizini açıkça verildiğinde çalıştırıldı ve geçti. Test yeni şema 12 ile **ayrı geçici DB** oluşturdu; gerçek kişi ve belge kayıtlarının modellerde okunup yazılmasını, aktarılan alanların korunmasını, iki dosyanın hash/boyutunu, bir kişiyle iki belgenin bağlantısını, telefon kartlarında görülen 5/Arşiv ve 15/Seyahat kategori eşleşmelerini ve SQLite bütünlüğünü denetledi. Bu test telefondaki orijinal DB'nin şema geçişi veya gerçek cihazda geri yükleme testi değildir; diğer kategori bilgilerini yeniden elde ettiğini iddia etmez.

Doğrulanmış kayıt ve dosyalar `artifacts/upgrade-audit/Arsivim-Telefon-Kurtarma-2026-10-22.zip` içinde toplandı. ZIP yeniden açılıp CRC, dosya boyutları ve SHA-256 değerleri denetlendi; yanındaki `.zip.sha256` dosyası arşivin özetini içeriyor. Paket özel kişi/giriş verisi içerir ve Git dışında tutulur. **Tam SQLite yedeği veya uygulamanın otomatik içe aktaracağı bir paket değildir.** Eski uygulama kaldırılmadı, yeni uygulama kurulmadı.

**Bilgisayarı kaynak alarak yeni Android kimliğine geçiş önerisinin kontrolü:** Kullanıcı bilgisayardaki arşivi yeni telefon uygulamasına aktarmayı önerdi. Yerel `Documents/arsiv.db` salt okunur açılarak 68 belge kaydı sayıldı; telefondan kurtarılan JPG ve MP4'ün SHA-256 değerleriyle eşleşen bilgisayar kaydı bulunmadı. Dolayısıyla yalnızca bilgisayardaki mevcut arşivi aktarmak, telefondaki bu iki dosyanın birebir kopyasını içermez. Yeni kimlikle ayrı telefon kurulumu yapılırsa kurtarılan iki kayıt/dosya da ayrıca korunup aktarılmalı. Yeni imza anahtarı bundan sonraki sürümler için sabit tutulup yedeklenmeli; Windows ve Android aynı yeni aktarım protokolünde olmalı. Bu plan henüz gerçek cihazda uygulanmadı.

### Kalan uygulama adımları

1. **Telefonu tanı:** USB hata ayıklama yetkisi verilmiş telefon bağlanınca aşağıdaki inceleme komutuyla kurulu APK'yı oku. Komut uygulamayı/verileri değiştirmez. Çıkan APK sadece uygulama kodudur, veri yedeği değildir.

   ```powershell
   ./scripts/Inspect-InstalledAndroid.ps1 -CandidateApk build/app/outputs/flutter-apk/app-debug.apk
   ```

   Komut kurulu APK'nın yanında `device-platform.json` dosyasına Android API ve ABI listesini kaydeder; aday paketin minimum API ve işlemci listesiyle karşılaştırır. Tek başına `Test-ApkUpgrade.ps1` cihaz bilgisi verilmeden çalıştırılırsa çıktıda `checkedScope=package-only` yazar. Cihaz denetimi için `-DeviceSdk` ve `-DeviceAbis` birlikte gereklidir. Bu kontroller kurulum/ilk açılış ve gerçek veri geçişi provasının yerine geçmez.

2. **Aynı anahtarı bul:** Eski bilgisayardaki `.android/debug.keystore` veya eski APK'yı imzalayan diğer keystore kullanılmalı. Telefonda okunan sertifika esas alınır; yalnızca 2.5.2 sürüm adına bakarak A veya B seçilemez. Yeni anahtar üretmek bu sorunu çözmez. Anahtarı Git'e koyma. Projedeki `android/key.properties` üzerinden `storeFile`, `storePassword`, `keyAlias`, `keyPassword` tanımlanabilir; dosya yolu Android proje köküne göre çözülür. Anahtar tanımlandığında debug ve release aynı mevcut-kurulum anahtarını kullanır. Dosya yoksa yerel debug anahtarıyla geliştirme yapılabilir; yayın kontrolü bunun eski kuruluma uyup uymadığını ayrıca reddeder.

3. **Tam veri yedeği al:** Güncellemeden önce DB'nin tutarlı SQLite yedeğini ve referans verdiği bütün belge/fotoğraf dosyalarını ayrı hedefe al; kayıt sayıları ve dosya hash'lerini doğrula. Uygulamadaki kategori/kişi yedeği seçilmiş dosyalar ve manifest üretir; tam hesap/uygulama geri yükleme sistemi değildir. Genel geri yükleme arayüzü henüz yoktur. Telefonun verilerine erişmeden tam telefon yedeği alındığı söylenemez.

4. **Kopyada prova:** Telefonda kullanılan DB kopyasında da aynı geçiş testini yap; eski kayıtlar, fotoğraflar ve dosya hash'leri değişmemeli. Şema 10 örneği veya bilgisayar kopyası tek başına telefonun verileri için yeterli kanıt değildir.

5. **Windows:** Eski uygulamayı kapat. Yeni release klasörünün **tamamını** ayrı sürüm klasörüne aç; aynı Windows kullanıcısıyla çalıştır. Belgeler klasöründeki `arsiv.db`, `Belgeler`, fotoğraf ve destek dosyalarını silme. OneDrive/Windows kullanıcı değişimi veya Belgeler klasörü taşınması varsa gerçek sistem Belgeler yolu ayrıca doğrulanmalı. Eski EXE'yi yeniden açma.

6. **Android:** Paket kimliği, sertifika, daha yüksek versionCode ve cihaz API/ABI şartları doğrulanınca mevcut uygulama üzerine güncelle. **Kaldır/yükle veya veri temizleme yapma.** Eski anahtar bulunamazsa doğrudan güncelleme mümkün değil; önce tam dışa aktarım ve ayrı ortamda geri yükleme provası hazırlanmalı. Veriler doğrulanmadan kaldırma önerilmez.

   ```powershell
   ./scripts/Build-AndroidUpdate.ps1 `
     -PreviousApk releases/v2.5.2-debug/Arsivcim-v2.5.2-DEBUG-COMPATIBLE.apk `
     -Mode debug
   ```

   Bu komut derler ve paket kimliği/sürüm/imza kontrolünü çalıştırır. Başarısız kontrol çıktısı yayımlanacak paket olarak kullanılmamalı. Doğrudan `flutter build` bu ek denetimi çalıştırmaz.

7. **İlk açılış:** Gerekirse eski kullanıcı adı/parola ile giriş yap. Sayılar, örnek belgeler, fotoğraflar ve çoklu bağlantılar kontrol edilir. Hata halinde uygulama verilerini sıfırlama; geçiş yedeğini ve hata kaydını koru.

8. **İki cihazı birlikte geçir:** Yeni aktarım protokolü eski alıcıya sessizce veri göndermemeli. İki taraf güncellendikten sonra yeni QR ile eşleştir; önce bir belgeyi iki yönde deneyip sayıları/hash'leri karşılaştır. Tek cihazı güncelleyip diğerinin eski senkronizasyon akışıyla devam etmesini bekleme.

9. **Geri dönüş:** Eski uygulamayı yeni DB'ye bağlamak yerine, önce bütün yeni verileri ayrıca koru. Gerekiyorsa uygulama kapalıyken geçiş öncesi DB ve onun dosya yerleşimi ayrı doğrulanmış kopyadan geri getirilir. Geçişten sonra yapılan yeni değişiklikler eski yedekte yoktur. Yalnızca EXE/APK sürümünü geriye almak güvenilir geri dönüş değildir.

## 6. Kalan yayın koşulları

- Kurulu telefon paketinin kesin sürüm/sertifika/API/ABI bilgisi **doğrulandı: 2.5.2+12, B, API 36, ARM desteği**. Bu aşama tamam; aşağıdaki veri ve kurulum koşulları devam ediyor.
- Eski anahtarın bulunması **veya** verileri doğrulanmış alternatif dışa aktarım/geri yükleme yolu.
- Telefona ait tam yedek ve bu DB üzerinde yükseltme provası.
- Gerçek cihazda kaldırmadan kurulum, ilk giriş, izinler, dosya açma ve iki yönlü aktarım kontrolü.
- Yeni Windows paketiyle gerçek arşiv üzerinde ilk açılışın yedek sonrası kontrollü yapılması.
- Geçiş yedeklerinin saklama/geri yükleme arayüzü ve depolama alanı yönetimi ayrı geliştirme konusu; mevcut yedekler kendiliğinden silinmiyor.

Bu koşullar karşılanmadan “tüm eski sürümler sorunsuz güncellenir, veri kaybı olmaz” garantisi verilmez.

Teknik dayanaklar: [Android uygulama imzalama ve güncelleme](https://developer.android.com/studio/publish/app-signing), [sqflite transaction davranışı](https://pub.dev/packages/sqflite), [SQLite ALTER TABLE kısıtları](https://www.sqlite.org/lang_altertable.html), [Android SQLite sürümleri](https://developer.android.com/reference/android/database/sqlite/package-summary), [SQLite JSON desteği](https://www.sqlite.org/json1.html), [SQLite 3.9.2](https://www.sqlite.org/releaselog/3_9_2.html).
