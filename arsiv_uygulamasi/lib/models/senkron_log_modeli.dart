class SenkronLogModeli {
  final int? id;
  final int? belgeId;
  final String islemTipi;
  final String kaynakCihaz;
  final String hedefCihaz;
  final DateTime islemTarihi;
  final String durum;
  final String? hataMesaji;

  SenkronLogModeli({
    this.id,
    this.belgeId,
    required this.islemTipi,
    required this.kaynakCihaz,
    required this.hedefCihaz,
    required this.islemTarihi,
    required this.durum,
    this.hataMesaji,
  });

  factory SenkronLogModeli.fromMap(Map<String, dynamic> map) {
    return SenkronLogModeli(
      id: map['id'],
      belgeId: map['belge_id'],
      islemTipi: map['islem_tipi'] ?? '',
      kaynakCihaz: map['kaynak_cihaz'] ?? '',
      hedefCihaz: map['hedef_cihaz'] ?? '',
      islemTarihi: DateTime.parse(
        map['islem_tarihi'] ?? DateTime.now().toIso8601String(),
      ),
      durum: map['durum'] ?? 'BEKLEMEDE',
      hataMesaji: map['hata_mesaji'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'belge_id': belgeId,
      'islem_tipi': islemTipi,
      'kaynak_cihaz': kaynakCihaz,
      'hedef_cihaz': hedefCihaz,
      'islem_tarihi': islemTarihi.toIso8601String(),
      'durum': durum,
      'hata_mesaji': hataMesaji,
    };
  }
}
