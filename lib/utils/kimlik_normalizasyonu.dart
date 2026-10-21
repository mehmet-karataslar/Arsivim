import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Kimlik karsilastirmasi icindir; gorunen ad ve parola degistirilmez.
class KimlikNormalizasyonu {
  static String metin(String value) => unorm.nfc(
    unorm
        .nfc(value)
        .trim()
        .replaceAll(RegExp(r'\s+', unicode: true), ' ')
        .replaceAll('\u0130', 'i')
        .replaceAll('I', '\u0131')
        .toLowerCase(),
  );

  static String? kullanici(Object? value) =>
      value is String && value.trim().isNotEmpty ? metin(value) : null;

  static bool ayniKisi(Map<String, dynamic> a, Map<String, dynamic> b) =>
      metin(a['ad'] as String) == metin(b['ad'] as String) &&
      metin(a['soyad'] as String) == metin(b['soyad'] as String) &&
      kullanici(a['kullanici_adi']) == kullanici(b['kullanici_adi']);
}
