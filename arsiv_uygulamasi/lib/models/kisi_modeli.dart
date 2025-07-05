import 'base_model.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Kişi modeli - optimize edilmiş ve basitleştirilmiş
class KisiModeli extends BaseModel {
  int? id;
  String ad;
  String soyad;
  String? kullaniciAdi;
  String? sifre;
  String? kullaniciTipi;
  DateTime olusturmaTarihi;
  DateTime guncellemeTarihi;
  bool aktif;

  KisiModeli({
    this.id,
    required this.ad,
    required this.soyad,
    this.kullaniciAdi,
    this.sifre,
    this.kullaniciTipi,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.aktif = true,
  });

  /// Map'ten model oluştur
  factory KisiModeli.fromMap(Map<String, dynamic> map) {
    return KisiModeli(
      id: map['id'],
      ad: map['ad'],
      soyad: map['soyad'],
      kullaniciAdi: map['kullanici_adi'],
      sifre: map['sifre'],
      kullaniciTipi: map['kullanici_tipi'],
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      aktif: map['aktif'] == 1,
    );
  }

  /// JSON'dan model oluştur
  factory KisiModeli.fromJson(Map<String, dynamic> json) =>
      KisiModeli.fromMap(json);

  /// Model'i Map'e dönüştür
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'soyad': soyad,
      'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
      'kullanici_tipi': kullaniciTipi,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'aktif': aktif ? 1 : 0,
    };
  }

  /// Model'i kopyala
  KisiModeli copyWith({
    int? id,
    String? ad,
    String? soyad,
    String? kullaniciAdi,
    String? sifre,
    String? kullaniciTipi,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    bool? aktif,
  }) {
    return KisiModeli(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      kullaniciAdi: kullaniciAdi ?? this.kullaniciAdi,
      sifre: sifre ?? this.sifre,
      kullaniciTipi: kullaniciTipi ?? this.kullaniciTipi,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      aktif: aktif ?? this.aktif,
    );
  }

  /// Yardımcı getter'lar
  String get tamAd => '$ad $soyad';
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get formatliGuncellemeTarihi =>
      YardimciFonksiyonlar.tarihFormatla(guncellemeTarihi);
  String get zamanFarki =>
      YardimciFonksiyonlar.zamanFarkiFormatla(guncellemeTarihi);

  /// Model'in geçerli olup olmadığını kontrol et
  @override
  bool isValid() => ad.trim().isNotEmpty && soyad.trim().isNotEmpty;

  /// Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KisiModeli && other.ad == ad && other.soyad == soyad;
  }

  @override
  int get hashCode => ad.hashCode ^ soyad.hashCode;

  @override
  String toString() => 'KisiModeli{id: $id, tamAd: $tamAd}';
}
