import 'dart:convert';
import 'base_model.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Senkronizasyon durumu enum'u
enum SenkronDurumu {
  SENKRONIZE,
  BEKLEMEDE,
  CAKISMA,
  HATA,
  YEREL_DEGISIM,
  UZAK_DEGISIM,
}

/// Belge modeli - optimize edilmiş ve basitleştirilmiş
class BelgeModeli extends BaseModel {
  static const _degismedi = Object();
  int? id;
  String dosyaAdi;
  String orijinalDosyaAdi;
  String dosyaYolu;
  int dosyaBoyutu;
  String dosyaTipi;
  String dosyaHash;
  int? kategoriId;
  int? kisiId;
  List<int> kategoriIds;
  List<int> kisiIds;
  List<int> get tumKategoriIds =>
      {
        ...[kategoriId].whereType<int>(),
        ...kategoriIds,
      }.toList();
  List<int> get tumKisiIds =>
      {
        ...[kisiId].whereType<int>(),
        ...kisiIds,
      }.toList();
  String? baslik;
  String? aciklama;
  List<String>? etiketler;
  DateTime olusturmaTarihi;
  DateTime guncellemeTarihi;
  DateTime? sonErisimTarihi;
  bool aktif;
  SenkronDurumu senkronDurumu;

  BelgeModeli({
    this.id,
    required this.dosyaAdi,
    required this.orijinalDosyaAdi,
    required this.dosyaYolu,
    required this.dosyaBoyutu,
    required this.dosyaTipi,
    required this.dosyaHash,
    this.kategoriId,
    this.kisiId,
    this.kategoriIds = const [],
    this.kisiIds = const [],
    this.baslik,
    this.aciklama,
    this.etiketler,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.sonErisimTarihi,
    this.aktif = true,
    this.senkronDurumu = SenkronDurumu.YEREL_DEGISIM,
  });

  /// Map'ten model oluştur
  factory BelgeModeli.fromMap(Map<String, dynamic> map) {
    return BelgeModeli(
      id: map['id'],
      dosyaAdi: map['dosya_adi'],
      orijinalDosyaAdi: map['orijinal_dosya_adi'],
      dosyaYolu: map['dosya_yolu'],
      dosyaBoyutu: map['dosya_boyutu'],
      dosyaTipi: map['dosya_tipi'],
      dosyaHash: map['dosya_hash'],
      kategoriId: map['kategori_id'],
      kisiId: map['kisi_id'],
      kategoriIds: idsCoz(map['kategori_ids']),
      kisiIds: idsCoz(map['kisi_ids']),
      baslik: map['baslik'],
      aciklama: map['aciklama'],
      etiketler: etiketleriCoz(map['etiketler']),
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      sonErisimTarihi:
          map['son_erisim_tarihi'] != null
              ? DateTime.parse(map['son_erisim_tarihi'])
              : null,
      aktif: map['aktif'] == 1,
      senkronDurumu:
          map['senkron_durumu'] is int &&
                  map['senkron_durumu'] >= 0 &&
                  map['senkron_durumu'] < SenkronDurumu.values.length
              ? SenkronDurumu.values[map['senkron_durumu']]
              : SenkronDurumu.BEKLEMEDE,
    );
  }

  /// JSON'dan model oluştur
  factory BelgeModeli.fromJson(Map<String, dynamic> json) =>
      BelgeModeli.fromMap(json);

  /// Model'i Map'e dönüştür
  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dosya_adi': dosyaAdi,
      'orijinal_dosya_adi': orijinalDosyaAdi,
      'dosya_yolu': dosyaYolu,
      'dosya_boyutu': dosyaBoyutu,
      'dosya_tipi': dosyaTipi,
      'dosya_hash': dosyaHash,
      'kategori_id': kategoriId,
      'kisi_id': kisiId,
      'kategori_ids': jsonEncode(tumKategoriIds),
      'kisi_ids': jsonEncode(tumKisiIds),
      'baslik': baslik,
      'aciklama': aciklama,
      'etiketler': etiketler == null ? null : jsonEncode(etiketler),
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'son_erisim_tarihi': sonErisimTarihi?.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'senkron_durumu': senkronDurumu.index,
    };
  }

  /// Model'i kopyala
  static List<String> etiketleriCoz(dynamic value) {
    if (value == null || value == '') return [];
    if (value is List) return value.cast<String>();
    if (value is! String) throw const FormatException('Etiket yapisi gecersiz');
    if (value.trimLeft().startsWith('[')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List && decoded.every((v) => v is String)) {
          return decoded.cast<String>();
        }
      } on FormatException {
        // Eski CSV etiketleri '[' ile baslayabilir.
      }
    }
    return value.split(',');
  }

  static List<int> idsCoz(dynamic value) {
    if (value == null) return [];
    final decoded = value is String ? jsonDecode(value) : value;
    return (decoded as List).cast<int>().where((id) => id > 0).toSet().toList();
  }

  BelgeModeli copyWith({
    Object? id = _degismedi,
    String? dosyaAdi,
    String? orijinalDosyaAdi,
    String? dosyaYolu,
    int? dosyaBoyutu,
    String? dosyaTipi,
    String? dosyaHash,
    Object? kategoriId = _degismedi,
    Object? kisiId = _degismedi,
    List<int>? kategoriIds,
    List<int>? kisiIds,
    Object? baslik = _degismedi,
    Object? aciklama = _degismedi,
    Object? etiketler = _degismedi,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    Object? sonErisimTarihi = _degismedi,
    bool? aktif,
    SenkronDurumu? senkronDurumu,
  }) {
    return BelgeModeli(
      id: identical(id, _degismedi) ? this.id : id as int?,
      dosyaAdi: dosyaAdi ?? this.dosyaAdi,
      orijinalDosyaAdi: orijinalDosyaAdi ?? this.orijinalDosyaAdi,
      dosyaYolu: dosyaYolu ?? this.dosyaYolu,
      dosyaBoyutu: dosyaBoyutu ?? this.dosyaBoyutu,
      dosyaTipi: dosyaTipi ?? this.dosyaTipi,
      dosyaHash: dosyaHash ?? this.dosyaHash,
      kategoriId:
          identical(kategoriId, _degismedi)
              ? this.kategoriId
              : kategoriId as int?,
      kisiId: identical(kisiId, _degismedi) ? this.kisiId : kisiId as int?,
      kategoriIds:
          kategoriIds ??
          (identical(kategoriId, _degismedi)
              ? this.kategoriIds
              : this.kategoriIds.where((id) => id != this.kategoriId).toList()),
      kisiIds:
          kisiIds ??
          (identical(kisiId, _degismedi)
              ? this.kisiIds
              : this.kisiIds.where((id) => id != this.kisiId).toList()),
      baslik: identical(baslik, _degismedi) ? this.baslik : baslik as String?,
      aciklama:
          identical(aciklama, _degismedi) ? this.aciklama : aciklama as String?,
      etiketler:
          identical(etiketler, _degismedi)
              ? this.etiketler
              : etiketler as List<String>?,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      sonErisimTarihi:
          identical(sonErisimTarihi, _degismedi)
              ? this.sonErisimTarihi
              : sonErisimTarihi as DateTime?,
      aktif: aktif ?? this.aktif,
      senkronDurumu: senkronDurumu ?? this.senkronDurumu,
    );
  }

  /// Yardımcı getter'lar
  String get formatliDosyaBoyutu =>
      YardimciFonksiyonlar.dosyaBoyutuFormatla(dosyaBoyutu);
  String get dosyaTipiSimgesi =>
      YardimciFonksiyonlar.dosyaTipiSimgesi(dosyaTipi);
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get formatliGuncellemeTarihi =>
      YardimciFonksiyonlar.tarihFormatla(guncellemeTarihi);
  String get zamanFarki =>
      YardimciFonksiyonlar.zamanFarkiFormatla(guncellemeTarihi);

  /// Model'in geçerli olup olmadığını kontrol et
  @override
  bool isValid() =>
      dosyaAdi.isNotEmpty && dosyaYolu.isNotEmpty && dosyaHash.isNotEmpty;

  /// Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BelgeModeli && other.dosyaHash == dosyaHash;
  }

  @override
  int get hashCode => dosyaHash.hashCode;

  @override
  String toString() =>
      'BelgeModeli{id: $id, dosyaAdi: $dosyaAdi, dosyaTipi: $dosyaTipi}';
}
