/// Base model class - ortak metodlar için
/// Tüm modeller bu class'tan türetilir
abstract class BaseModel {
  /// Model'i Map'e dönüştür (veritabanı için)
  Map<String, dynamic> toMap();

  /// Model'i JSON'a dönüştür (API için)
  Map<String, dynamic> toJson() => toMap();

  /// Model'in geçerli olup olmadığını kontrol et
  bool isValid() => true;

  /// Model'in hash kodunu döndür
  @override
  int get hashCode;

  /// Model'in string temsilini döndür
  @override
  String toString();

  /// Model'leri karşılaştır
  @override
  bool operator ==(Object other);
}
