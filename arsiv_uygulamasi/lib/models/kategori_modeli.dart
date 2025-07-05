import 'base_model.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Kategori modeli - optimize edilmiş ve basitleştirilmiş
class KategoriModeli extends BaseModel {
  int? id;
  String kategoriAdi;
  String renkKodu;
  String simgeKodu;
  String? aciklama;
  DateTime olusturmaTarihi;
  bool aktif;
  int? belgeSayisi;

  KategoriModeli({
    this.id,
    required this.kategoriAdi,
    this.renkKodu = '#2196F3',
    this.simgeKodu = 'folder',
    this.aciklama,
    required this.olusturmaTarihi,
    this.aktif = true,
    this.belgeSayisi = 0,
  });

  /// Map'ten model oluştur
  factory KategoriModeli.fromMap(Map<String, dynamic> map) {
    return KategoriModeli(
      id: map['id'],
      kategoriAdi: map['kategori_adi'],
      renkKodu: map['renk_kodu'] ?? '#2196F3',
      simgeKodu: map['simge_kodu'] ?? 'folder',
      aciklama: map['aciklama'],
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      aktif: map['aktif'] == 1,
      belgeSayisi: map['belge_sayisi'] ?? 0,
    );
  }

  /// JSON'dan model oluştur
  factory KategoriModeli.fromJson(Map<String, dynamic> json) =>
      KategoriModeli.fromMap(json);

  /// Model'i Map'e dönüştür
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kategori_adi': kategoriAdi,
      'renk_kodu': renkKodu,
      'simge_kodu': simgeKodu,
      'aciklama': aciklama,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'belge_sayisi': belgeSayisi,
    };
  }

  /// Model'i kopyala
  KategoriModeli copyWith({
    int? id,
    String? kategoriAdi,
    String? renkKodu,
    String? simgeKodu,
    String? aciklama,
    DateTime? olusturmaTarihi,
    bool? aktif,
    int? belgeSayisi,
  }) {
    return KategoriModeli(
      id: id ?? this.id,
      kategoriAdi: kategoriAdi ?? this.kategoriAdi,
      renkKodu: renkKodu ?? this.renkKodu,
      simgeKodu: simgeKodu ?? this.simgeKodu,
      aciklama: aciklama ?? this.aciklama,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      aktif: aktif ?? this.aktif,
      belgeSayisi: belgeSayisi ?? this.belgeSayisi,
    );
  }

  /// Yardımcı getter'lar
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get zamanFarki =>
      YardimciFonksiyonlar.zamanFarkiFormatla(olusturmaTarihi);
  String get ad => kategoriAdi; // Alias for kategoriAdi

  /// Model'in geçerli olup olmadığını kontrol et
  @override
  bool isValid() =>
      kategoriAdi.trim().isNotEmpty &&
      renkKodu.isNotEmpty &&
      simgeKodu.isNotEmpty;

  /// Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KategoriModeli &&
        other.id == id &&
        other.kategoriAdi == kategoriAdi;
  }

  @override
  int get hashCode => Object.hash(id, kategoriAdi);

  @override
  String toString() =>
      'KategoriModeli{id: $id, kategoriAdi: $kategoriAdi, belgeSayisi: $belgeSayisi}';

  /// Varsayılan kategoriler
  static List<KategoriModeli> ontanimliKategoriler() {
    final simdi = DateTime.now();
    return [
      KategoriModeli(
        kategoriAdi: 'Belgeler',
        renkKodu: '#2196F3',
        simgeKodu: 'description',
        aciklama: 'Genel belgeler ve dökümanlar',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Resimler',
        renkKodu: '#4CAF50',
        simgeKodu: 'image',
        aciklama: 'Fotoğraflar ve resimler',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Videolar',
        renkKodu: '#FF9800',
        simgeKodu: 'videocam',
        aciklama: 'Video dosyaları',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Müzik',
        renkKodu: '#9C27B0',
        simgeKodu: 'music_note',
        aciklama: 'Ses dosyaları',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Arşiv',
        renkKodu: '#607D8B',
        simgeKodu: 'archive',
        aciklama: 'Sıkıştırılmış dosyalar',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Okul',
        renkKodu: '#3F51B5',
        simgeKodu: 'school',
        aciklama: 'Eğitim ve okul belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'İş',
        renkKodu: '#795548',
        simgeKodu: 'work',
        aciklama: 'İş ve meslek belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Ev',
        renkKodu: '#E91E63',
        simgeKodu: 'home',
        aciklama: 'Ev ve aile belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Hastane',
        renkKodu: '#F44336',
        simgeKodu: 'local_hospital',
        aciklama: 'Sağlık ve tıbbi belgeler',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Resmi',
        renkKodu: '#009688',
        simgeKodu: 'business',
        aciklama: 'Resmi kurum belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Mali',
        renkKodu: '#4CAF50',
        simgeKodu: 'account_balance',
        aciklama: 'Mali ve finansal belgeler',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Hukuki',
        renkKodu: '#FF5722',
        simgeKodu: 'gavel',
        aciklama: 'Hukuki ve yasal belgeler',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Sigorta',
        renkKodu: '#00BCD4',
        simgeKodu: 'security',
        aciklama: 'Sigorta belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Kişisel',
        renkKodu: '#673AB7',
        simgeKodu: 'person',
        aciklama: 'Kişisel belgeler',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Seyahat',
        renkKodu: '#FF9800',
        simgeKodu: 'flight',
        aciklama: 'Seyahat belgeleri',
        olusturmaTarihi: simdi,
      ),
      KategoriModeli(
        kategoriAdi: 'Hobi',
        renkKodu: '#8BC34A',
        simgeKodu: 'sports_esports',
        aciklama: 'Hobi ve ilgi alanları',
        olusturmaTarihi: simdi,
      ),
    ];
  }
}
