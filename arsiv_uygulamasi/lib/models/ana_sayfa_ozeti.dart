import 'belge_modeli.dart';

class SonBelgeOzeti {
  const SonBelgeOzeti({required this.belge, this.kategori, this.kisi});
  final BelgeModeli belge;
  final String? kategori;
  final String? kisi;

  factory SonBelgeOzeti.fromMap(Map<String, dynamic> map) => SonBelgeOzeti(
    belge: BelgeModeli.fromMap(map),
    kategori: map['kategori_adi'] as String?,
    kisi: [
      map['kisi_ad'],
      map['kisi_soyad'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
  );
}

class AnaSayfaOzeti {
  const AnaSayfaOzeti({
    required this.belgeSayisi,
    required this.dosyaBoyutu,
    required this.sonBelgeler,
    this.kategoriSayisi = 0,
    this.sonYedekleme,
    this.turBoyutlari = const {},
  });
  final int belgeSayisi;
  final int dosyaBoyutu;
  final List<SonBelgeOzeti> sonBelgeler;
  final int kategoriSayisi;
  final DateTime? sonYedekleme;
  final Map<String, int> turBoyutlari;
}
