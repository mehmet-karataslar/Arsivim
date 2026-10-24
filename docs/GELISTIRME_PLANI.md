# Arşivim geliştirme planı

Plan tarihi: 23 Ekim 2026

## Karar ve kapsam

Kullanıcı ilk altı geliştirmeye ek olarak sekiz yeni ürün özelliğini de onayladı.
Plan toplam 14 maddeden oluşuyor. İlk altı maddenin sırası korunuyor; yeni
özellikler kullanıcının seçtiği sırayla 7–14. maddelerde yer alıyor. Maddeler
birer birer uygulanacak. Bu belgeye kaydedilmeleri uygulamalarının başladığı
anlamına gelmez; şu anda 14 madde de bekliyor.

Bu liste dışında öneri olarak konuşulan özellikler, kullanıcı seçmeden
onaylanmış uygulama kapsamına eklenmeyecek. Maddeler arasındaki ilişkiler
uygulama sırasında ortak veri modelleriyle ele alınacak; aynı bilgi için
birbirinden kopuk yapılar oluşturulmayacak.

## 1. Uygulama içinde belge önizlemesi ve ayrıntı paneli

Durum: Bekliyor.

- PDF ve desteklenen görselleri uygulama içinde önizleme.
- Masaüstünde belge listesinin yanında ayrıntı paneli; mobilde tam ekran görünüm.
- Başlık, açıklama, etiketler ve bağlı bütün kişi/kategorileri gösterme.
- PDF sayfa geçişi ve yakınlaştırma.
- Desteklenmeyen dosyalar için mevcut harici uygulamayla açma seçeneği.
- Dosya bulunamadığında anlaşılır hata ve izlenecek adım.

Tamamlanma ölçütü: Kullanıcı desteklenen bir belgeyi uygulamadan ayrılmadan
inceleyebiliyor; çoklu bağlantıları görebiliyor ve belge listesine konumunu
kaybetmeden dönebiliyor.

## 2. OCR ve belge içeriğinde arama

Durum: Bekliyor.

- Metin içeren PDF'lerden metin çıkarma; taranmış PDF ve görsellerde OCR.
- Belge kaydını engellemeyen arka plan iş kuyruğu ve işlem durumu.
- Mevcut aramaya belge içeriğini dahil etme; eşleşen metni ve sayfayı gösterme.
- İşlenemeyen belgelerde tekrar deneme ve mevcut belgeyi kullanmaya devam etme.
- İlk aşamada cihaz üzerinde işleme; harici servise belge göndermek ayrı karar.
- Belge değiştiğinde arama indeksini yenileme; silindiğinde görünürlüğünü kaldırma.

Tamamlanma ölçütü: Kullanıcı dosya adını bilmediği bir belgeyi içindeki metinle
bulabiliyor ve eşleşmenin bulunduğu sayfaya erişebiliyor. Desteklenen platformlar,
diller ve dosya sınırları uygulama öncesinde netleştirilecek.

## 3. Ana sayfayı kişisel bir çalışma alanına dönüştürmek

Durum: Bekliyor.

- Belge favorileri ve sabitlenen belgeler.
- Son açılan belgeler ve devam edilebilen taslaklar.
- Kaydedilebilir arama/filtreler ve hızlı erişim koleksiyonları.
- Ana sayfa bölümlerinin görünürlüğü ve sırasını kişiselleştirme.
- Veri olmayan bölümlerde anlaşılır, işleme yönlendiren boş durumlar.

Tamamlanma ölçütü: Kullanıcı sık kullandığı belgeye, kaydettiği filtreye veya yarım
kalan işine ana sayfadan ulaşabiliyor; tercihler yeniden açılışta korunuyor.

## 4. Belge tarihleri, geçerlilik süreleri ve hatırlatmalar

Durum: Bekliyor.

- Oluşturulma/güncellenme zamanından ayrı belge tarihi ve son geçerlilik tarihi.
- İsteğe bağlı hatırlatma tarihi ve belgeye bağlı bildirim.
- Yaklaşan ve geçmiş tarihleri gösteren görünüm; tarihe göre filtreleme.
- Bildirimden ilgili belgeye erişim.
- Tarih değişikliğinde veya silmede eski hatırlatmayı güncelleme/iptal etme.
- Platform desteği, saat dilimi, izin reddi ve uygulama kapalıyken davranışı
  platform bazında tanımlama ve doğrulama.

Tamamlanma ölçütü: Kullanıcı belgeye süre tanımlayabiliyor, yaklaşan tarihleri
görebiliyor ve desteklenen platformlarda planladığı bildirimi alabiliyor.

## 5. Senkronizasyonu adımlı hale getirmek ve çakışmaları çözdürmek

Durum: Bekliyor.

- Ana akış: Cihaz seç → Farkları incele → Aktar → Sonucu gör.
- Benzer aktarım komutlarını sadeleştirme; teknik bağlantı ayrıntılarını gelişmiş
  ayarlarda sunma.
- Çakışan kayıtların içerik, bilgi ve bağlantı farklarını karşılaştırma.
- Uygun çakışma türlerinde yerel kaydı kullanma, uzak kaydı kullanma veya iki
  kopyayı koruma; kimlik belirsizliklerinde açık eşleştirme akışı.
- Üzerine yazılacak içeriği koruma ve işlem sonucunu izlenebilir kaydetme.
- Mevcut güvenilir cihaz, bütünlük doğrulama ve aktarım korumalarını sürdürme.

Tamamlanma ölçütü: Kullanıcı hangi yönde ne aktarılacağını anlayabiliyor,
desteklenen çakışmaları bilinçli şekilde çözebiliyor ve sonuçta atlanan/başarısız
kayıtları görebiliyor. Eski cihazlarla protokol uyumluluğu açıkça ele alınacak.

## 6. Tasarım sistemini tamamlamak ve eski kodları sadeleştirmek

Durum: Bekliyor.

- Giriş/kayıt, iletişim kutuları ve kalan ekranları ortak tasarım bileşenlerine
  ve tema renklerine taşıma.
- Koyu tema ve erişilebilirlik kontrolleri.
- Kamera ve bildirim gibi izinleri ihtiyaç duyulan akışta isteme.
- Kullanılmayan ekran ve bileşenleri çağrı/kullanım denetimi sonrasında temizleme.
- Büyük servisleri sorumluluklarına göre aşamalı bölme.
- Analiz bulgularını azaltma ve ilgili davranışları regresyon kontrolleriyle koruma.

Tamamlanma ölçütü: Aktif ekranlar ortak tasarım dilini izliyor, açık/koyu tema
okunabilir çalışıyor ve kod sadeleştirmesi mevcut işlevleri bozmuyor.

## 7. Yaşam olaylarına özel dosyalar

Durum: Bekliyor.

- Taşınma, yeni araç, vize başvurusu ve ev tadilatı gibi işler için çalışma
  dosyaları oluşturma.
- Farklı kişi ve kategorilerdeki mevcut belgeleri kopyalamadan aynı çalışma
  dosyasına bağlama; bir belgeyi birden fazla dosyada kullanabilme.
- Dosyaya notlar, yapılacaklar ve gerekli belge kontrol listesi ekleme.
- Tamamlanan, eksik ve bekleyen işleri açıkça gösterme.
- İlgili belgelerden önizlemeye erişim; ana sayfadan devam edebilme.

Tamamlanma ölçütü: Kullanıcı örneğin bir taşınmanın belgelerini, notlarını ve
eksiklerini tek çalışma dosyasında yönetebiliyor; belge bağlantısını kaldırmak
arşivdeki asıl belgeyi silmiyor.

## 8. Ev, araç ve eşya envanteri

Durum: Bekliyor.

- Ev, araç, bilgisayar ve benzeri varlıklar için envanter kayıtları oluşturma.
- Varlık türüne uygun satın alma bilgileri, seri numarası ve açıklamalar.
- Fatura, garanti belgesi, servis belgeleri ve fotoğrafları varlığa bağlama.
- Tarihli bakım/servis geçmişi ve ilgili belgeleri birlikte görüntüleme.
- Uygun garanti ve bakım tarihlerini 4. maddedeki hatırlatma altyapısıyla
  ilişkilendirme.
- Satış veya taşınma için seçilen varlıkların envanter listesini dışa aktarma.

Tamamlanma ölçütü: Kullanıcı bir varlıktan satın alma bilgisine, belgelerine ve
servis geçmişine ulaşabiliyor; seçtiği varlıklar için envanter listesi çıkarabiliyor.

## 9. Başvuru ve teslim paketi hazırlama

Durum: Bekliyor.

- Arşivdeki belgelerden isimlendirilmiş, yeniden açılabilir paketler hazırlama.
- Belgelerin sırasını ve pakette kullanılacak dosya adlarını düzenleme.
- Gerekli belge kontrol listesiyle eksikleri gösterme.
- İçerik listesi ve isteğe bağlı kapak sayfası hazırlama.
- ZIP dışa aktarımı; desteklenen PDF ve görsellerden birleşik PDF oluşturma.
- Kaynak belgeleri değiştirmeden paylaşılabilir kopyalar üretme; eksik veya
  dönüştürülemeyen dosyaları kullanıcıya açıkça bildirme.

Tamamlanma ölçütü: Kullanıcı örneğin okul kayıt belgelerini sıralayıp eksiklerini
kontrol ederek içerik listeli bir paket oluşturabiliyor ve dışa aktarabiliyor.

## 10. Dışarıdan belge kabul eden Gelen Kutusu

Durum: Bekliyor.

- Desteklenen mobil platformlarda başka uygulamaların paylaş menüsünden
  Arşivim'e dosya kabul etme.
- Masaüstünde kullanıcı tarafından seçilen klasörü izleyerek yeni dosyaları
  Gelen Kutusu'na alma.
- Belgeleri kalıcı olarak sınıflandırmadan önce bekleyenler listesinde saklama.
- Başlık, kişi ve kategori bilgilerini tamamlayıp arşivleme.
- Yinelenen dosyaları tespit etme; uygulama yeniden açıldığında bekleyenleri koruma.
- İzlenen klasörü değiştirme/durdurma; kaynak dosyaları silmeden veya taşımadan
  dosyanın sahipliğini ve içe aktarma durumunu yönetme.

Tamamlanma ölçütü: Kullanıcı bir dosyayı desteklenen paylaşım veya klasör izleme
akışından alabiliyor, daha sonra sınıflandırıp arşivleyebiliyor; aynı dosya
yeniden algılandığında sessizce birden fazla kayıt oluşmuyor. Uygulama kapalıyken
klasör izlemenin destek kapsamı uygulama öncesinde netleştirilecek.

## 11. Belgeler arasında anlamlı bağlantılar

Durum: Bekliyor.

- Belgeler arasında fatura, tercüme, ek ve cevap gibi türlendirilmiş ilişkiler.
- İlişkinin yönünü ve karşılığını anlaşılır biçimde gösterme.
- Önizleme/ayrıntı panelinde ilişkili belgelere doğrudan erişim.
- Teklif → sipariş → fatura → servis tutanağı gibi zincirleri gezebilme.
- Kendine bağlantı ve aynı ilişkinin yinelenmesi için doğrulama.
- İlişki kaldırma veya belge silme durumlarında diğer belgelerin korunması.

Tamamlanma ölçütü: Kullanıcı bir belgeden onun eki, cevabı veya tercümesine
ulaşabiliyor; bağlantı türü ve yönü iki belge tarafından da doğru okunuyor.

## 12. Belge türüne göre özel bilgi alanları

Durum: Bekliyor.

- Kullanıcının belge türleri ve bu türlere ait alanlar tanımlayabilmesi.
- Metin, sayı, tutar/para birimi, tarih ve seçim gibi uygun alan türleri.
- Faturada firma ve tutar, diplomada okul ve bölüm, servis kaydında yapılan işlem
  gibi tür bazlı formlar.
- Özel alanlara göre arama, filtreleme ve rapor/dışa aktarım.
- Alan veya belge türü değiştiğinde mevcut değerleri koruyan geçiş davranışı.
- OCR altyapısı hazır olduğunda desteklenen alanlara doldurma önerileri; önerileri
  kullanıcının inceleyip uygulaması.

Tamamlanma ölçütü: Kullanıcı yeni bir belge türü ve alanlarını tanımlayabiliyor,
belgeye değer girebiliyor ve bu değerlerle ilgili kayıtları bulup raporlayabiliyor.

## 13. Başvuru, talep ve işlem takibi

Durum: Bekliyor.

- Hazırlanıyor, gönderildi, yanıt bekleniyor ve tamamlandı durumlarıyla süreç
  kayıtları oluşturma.
- Başvuru belgesi, gönderim makbuzu ve cevap gibi belgeleri aynı sürece bağlama.
- Tarihli durum değişiklikleri, işlem notları ve sıradaki adımı kaydetme.
- Sonraki adımların tarihlerini 4. maddedeki hatırlatmalarla ilişkilendirme.
- 7. maddedeki çalışma dosyaları ve 9. maddedeki teslim paketleriyle bağlantı;
  ortak belge ve kontrol listesi yapılarından yararlanma.

Tamamlanma ölçütü: Kullanıcı bir garanti başvurusu gibi sürecin mevcut aşamasını,
geçmiş işlemlerini, ilgili belgelerini ve sıradaki adımını tek yerden takip
edebiliyor. Gönderildi durumu kullanıcı kaydıdır; dışarıya otomatik gönderim
veya teslim doğrulaması anlamına gelmez.

## 14. Fiziksel belgelerin yerini takip etme

Durum: Bekliyor.

- Oda → dolap → klasör → bölüm gibi hiyerarşik fiziksel konumlar tanımlama.
- Dijital belgelere asıl nüshalarının fiziksel konumunu bağlama.
- Klasör ve kutular için QR etiketleri oluşturma ve yazdırılabilir çıktı hazırlama.
- Etiketi tarayarak yetkili yerel arşivde ilgili konumun belgelerini açma.
- Belgenin aslının kime, ne zaman verildiğini ve iade durumunu kaydetme.
- Konum değişikliklerini ve teslim/iade hareketlerini izleme; QR etiketlerine
  belge içeriği veya hesap erişim bilgisi koymama.

Tamamlanma ölçütü: Kullanıcı dijital belgeden aslının yerini veya kimde olduğunu
öğrenebiliyor; bir klasörün QR etiketinden o konumdaki belgelere erişebiliyor ve
teslim/iade kaydı tutabiliyor.

## Her madde için ortak çalışma kuralları

- Başlamadan önce güncel kod ve mevcut kullanıcı değişiklikleri yeniden incelenir.
- Mevcut arşivler korunur; şema değişikliklerinde geçiş ve kurtarma davranışı
  doğrulanır.
- Yeni kalıcı alanların yedekleme, geri yükleme olanakları ve senkronizasyonla
  ilişkisi aynı madde kapsamında değerlendirilir.
- Mobil ve masaüstü akışları ayrı doğrulanır; desteklenmeyen özellik açıkça belirtilir.
- İlgili testler ve görsel/etkileşim kontrolleri sonrasında bu belgedeki durum,
  yapılan değişiklikler ve kalan sınırlamalar güncellenir.
