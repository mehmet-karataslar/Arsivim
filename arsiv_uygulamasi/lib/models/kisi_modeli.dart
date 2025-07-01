import '../utils/yardimci_fonksiyonlar.dart';

// Kişi modeli
class KisiModeli {
  int? id;
  String ad;
  String soyad;
  DateTime olusturmaTarihi;
  DateTime guncellemeTarihi;
  bool aktif;

  KisiModeli({
    this.id,
    required this.ad,
    required this.soyad,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.aktif = true,
  });

  // JSON'dan model oluşturma
  factory KisiModeli.fromJson(Map<String, dynamic> json) {
    return KisiModeli(
      id: json['id'],
      ad: json['ad'],
      soyad: json['soyad'],
      olusturmaTarihi: DateTime.parse(json['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(json['guncelleme_tarihi']),
      aktif: json['aktif'] == 1,
    );
  }

  // Model'den JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ad': ad,
      'soyad': soyad,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
    };
  }

  // Veritabanı için Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'soyad': soyad,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
    };
  }

  // Map'ten model oluşturma
  factory KisiModeli.fromMap(Map<String, dynamic> map) {
    return KisiModeli(
      id: map['id'],
      ad: map['ad'],
      soyad: map['soyad'],
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      aktif: map['aktif'] == 1,
    );
  }

  // Kopyalama metodu
  KisiModeli copyWith({
    int? id,
    String? ad,
    String? soyad,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    bool? aktif,
  }) {
    return KisiModeli(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      aktif: aktif ?? this.aktif,
    );
  }

  // Yardımcı getter'lar
  String get tamAd => '$ad $soyad';
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get formatliGuncellemeTarihi =>
      YardimciFonksiyonlar.tarihFormatla(guncellemeTarihi);
  String get zamanFarki => YardimciFonksiyonlar.zamanFarki(guncellemeTarihi);

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KisiModeli && other.ad == ad && other.soyad == soyad;
  }

  @override
  int get hashCode => ad.hashCode ^ soyad.hashCode;

  @override
  String toString() {
    return 'KisiModeli{id: $id, tamAd: $tamAd}';
  }
}
