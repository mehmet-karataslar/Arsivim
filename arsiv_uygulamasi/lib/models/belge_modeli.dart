import '../utils/yardimci_fonksiyonlar.dart';

// Senkronizasyon durumu enum'u
enum SenkronDurumu {
  SENKRONIZE,
  BEKLEMEDE,
  CAKISMA,
  HATA,
  YEREL_DEGISIM,
  UZAK_DEGISIM,
}

// Belge veri yapısı ve iş mantığı
class BelgeModeli {
  int? id;
  String dosyaAdi;
  String orijinalDosyaAdi;
  String dosyaYolu;
  int dosyaBoyutu;
  String dosyaTipi;
  String dosyaHash;
  int? kategoriId;
  int? kisiId;
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
    this.baslik,
    this.aciklama,
    this.etiketler,
    required this.olusturmaTarihi,
    required this.guncellemeTarihi,
    this.sonErisimTarihi,
    this.aktif = true,
    this.senkronDurumu = SenkronDurumu.YEREL_DEGISIM,
  });

  // JSON'dan model oluşturma
  factory BelgeModeli.fromJson(Map<String, dynamic> json) {
    return BelgeModeli(
      id: json['id'],
      dosyaAdi: json['dosya_adi'],
      orijinalDosyaAdi: json['orijinal_dosya_adi'],
      dosyaYolu: json['dosya_yolu'],
      dosyaBoyutu: json['dosya_boyutu'],
      dosyaTipi: json['dosya_tipi'],
      dosyaHash: json['dosya_hash'],
      kategoriId: json['kategori_id'],
      kisiId: json['kisi_id'],
      baslik: json['baslik'],
      aciklama: json['aciklama'],
      etiketler:
          json['etiketler'] != null
              ? List<String>.from(json['etiketler'].split(','))
              : null,
      olusturmaTarihi: DateTime.parse(json['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(json['guncelleme_tarihi']),
      sonErisimTarihi:
          json['son_erisim_tarihi'] != null
              ? DateTime.parse(json['son_erisim_tarihi'])
              : null,
      aktif: json['aktif'] == 1,
      senkronDurumu: SenkronDurumu.values[json['senkron_durumu'] ?? 0],
    );
  }

  // Model'den JSON'a dönüştürme
  Map<String, dynamic> toJson() {
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
      'baslik': baslik,
      'aciklama': aciklama,
      'etiketler': etiketler?.join(','),
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'son_erisim_tarihi': sonErisimTarihi?.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'senkron_durumu': senkronDurumu.index,
    };
  }

  // Veritabanı için Map
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
      'baslik': baslik,
      'aciklama': aciklama,
      'etiketler': etiketler?.join(','),
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi.toIso8601String(),
      'son_erisim_tarihi': sonErisimTarihi?.toIso8601String(),
      'aktif': aktif ? 1 : 0,
      'senkron_durumu': senkronDurumu.index,
    };
  }

  // Map'ten model oluşturma
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
      baslik: map['baslik'],
      aciklama: map['aciklama'],
      etiketler:
          map['etiketler'] != null
              ? List<String>.from(map['etiketler'].split(','))
              : null,
      olusturmaTarihi: DateTime.parse(map['olusturma_tarihi']),
      guncellemeTarihi: DateTime.parse(map['guncelleme_tarihi']),
      sonErisimTarihi:
          map['son_erisim_tarihi'] != null
              ? DateTime.parse(map['son_erisim_tarihi'])
              : null,
      aktif: map['aktif'] == 1,
      senkronDurumu: SenkronDurumu.values[map['senkron_durumu'] ?? 0],
    );
  }

  // Kopyalama metodu
  BelgeModeli copyWith({
    int? id,
    String? dosyaAdi,
    String? orijinalDosyaAdi,
    String? dosyaYolu,
    int? dosyaBoyutu,
    String? dosyaTipi,
    String? dosyaHash,
    int? kategoriId,
    int? kisiId,
    String? baslik,
    String? aciklama,
    List<String>? etiketler,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    DateTime? sonErisimTarihi,
    bool? aktif,
    SenkronDurumu? senkronDurumu,
  }) {
    return BelgeModeli(
      id: id ?? this.id,
      dosyaAdi: dosyaAdi ?? this.dosyaAdi,
      orijinalDosyaAdi: orijinalDosyaAdi ?? this.orijinalDosyaAdi,
      dosyaYolu: dosyaYolu ?? this.dosyaYolu,
      dosyaBoyutu: dosyaBoyutu ?? this.dosyaBoyutu,
      dosyaTipi: dosyaTipi ?? this.dosyaTipi,
      dosyaHash: dosyaHash ?? this.dosyaHash,
      kategoriId: kategoriId ?? this.kategoriId,
      kisiId: kisiId ?? this.kisiId,
      baslik: baslik ?? this.baslik,
      aciklama: aciklama ?? this.aciklama,
      etiketler: etiketler ?? this.etiketler,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      sonErisimTarihi: sonErisimTarihi ?? this.sonErisimTarihi,
      aktif: aktif ?? this.aktif,
      senkronDurumu: senkronDurumu ?? this.senkronDurumu,
    );
  }

  // Yardımcı getter'lar
  String get formatliDosyaBoyutu =>
      YardimciFonksiyonlar.dosyaBoyutuFormatla(dosyaBoyutu);
  String get dosyaTipiSimgesi =>
      YardimciFonksiyonlar.dosyaTipiSimgesi(dosyaTipi);
  String get formatliOlusturmaTarihi =>
      YardimciFonksiyonlar.tarihFormatla(olusturmaTarihi);
  String get formatliGuncellemeTarihi =>
      YardimciFonksiyonlar.tarihFormatla(guncellemeTarihi);
  String get zamanFarki => YardimciFonksiyonlar.zamanFarki(guncellemeTarihi);

  // Hash doğrulama
  static bool hashGecerliMi(String hash) {
    return YardimciFonksiyonlar.hashGecerliMi(hash);
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BelgeModeli && other.dosyaHash == dosyaHash;
  }

  @override
  int get hashCode => dosyaHash.hashCode;

  @override
  String toString() {
    return 'BelgeModeli{id: $id, dosyaAdi: $dosyaAdi, dosyaTipi: $dosyaTipi, dosyaBoyutu: $dosyaBoyutu}';
  }
}
