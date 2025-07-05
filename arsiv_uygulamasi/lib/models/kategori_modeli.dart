import '../utils/yardimci_fonksiyonlar.dart';

// Kategori yapısı ve yönetimi
class KategoriModeli {
  int? id;
  String kategoriAdi;
  String renkKodu;
  String simgeKodu;
  String? aciklama;
  DateTime olusturmaTarihi;
  bool aktif;
  int? belgeSayisi; // Bu kategorideki belge sayısı

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

  // JSON'dan model oluşturma
  factory KategoriModeli.fromJson(Map<String, dynamic> json) {
    return KategoriModeli(
      id: json['id'],
      kategoriAdi: json['kategori_adi'],
      renkKodu: json['renk_kodu'] ?? '#2196F3',
      simgeKodu: json['simge_kodu'] ?? 'folder',
      aciklama: json['aciklama'],
      olusturmaTarihi: DateTime.parse(json['olusturma_tarihi']),
      aktif: json['aktif'] == 1,
      belgeSayisi: json['belge_sayisi'] ?? 0,
    );
  }

  // Model'den JSON'a dönüştürme
  Map<String, dynamic> toJson() {
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

  // Veritabanı için Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kategori_adi': kategoriAdi,
      'renk_kodu': renkKodu,
      'simge_kodu': simgeKodu,
      'aciklama': aciklama,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
    };
  }

  // Map'ten model oluşturma
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

  // Kopyalama metodu
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

  // Yardımcı getter'lar
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get zamanFarki => YardimciFonksiyonlar.zamanFarki(olusturmaTarihi);

  /// Alias for kategoriAdi
  String get ad => kategoriAdi;

  // Öntanımlı kategoriler
  static List<KategoriModeli> ontanimliKategoriler() {
    DateTime simdi = DateTime.now();

    return [
      // Genel Kategoriler
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

      // Yaşam Alanları
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

      // Finansal ve Yasal
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

      // Özel Kategoriler
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

  // Kategori doğrulama
  bool gecerliMi() {
    return kategoriAdi.trim().isNotEmpty &&
        renkKodu.isNotEmpty &&
        simgeKodu.isNotEmpty;
  }

  // Eşitlik kontrolü
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
  String toString() {
    return 'KategoriModeli{id: $id, kategoriAdi: $kategoriAdi, belgeSayisi: $belgeSayisi}';
  }
}
