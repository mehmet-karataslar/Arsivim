import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/belge_modeli.dart';

/// SADELEŞTİRİLMİŞ Hash karşılaştırma utilities
/// Sadece gerekli temel hash işlemleri
class HashComparator {
  static final HashComparator _instance = HashComparator._internal();
  static HashComparator get instance => _instance;
  HashComparator._internal();

  /// Dosya hash'i hesapla
  Future<String> calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';

      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      return '';
    }
  }

  /// İki dosyayı hash ile karşılaştır
  Future<bool> compareFiles(String filePath1, String filePath2) async {
    try {
      final hash1 = await calculateFileHash(filePath1);
      final hash2 = await calculateFileHash(filePath2);

      return hash1.isNotEmpty && hash2.isNotEmpty && hash1 == hash2;
    } catch (e) {
      return false;
    }
  }

  /// Belge metadata hash'i oluştur
  String generateMetadataHash(BelgeModeli belge) {
    final metadata = {
      'dosyaAdi': belge.dosyaAdi,
      'dosyaBoyutu': belge.dosyaBoyutu,
      'baslik': belge.baslik ?? '',
      'kategoriId': belge.kategoriId,
      'kisiId': belge.kisiId,
    };

    final jsonString = json.encode(metadata);
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  /// Hash geçerlilik kontrolü
  bool isValidHash(String hash) {
    if (hash.isEmpty || hash.length != 64) return false;

    // SHA-256 hash sadece hex karakterler içermeli (0-9, a-f, A-F)
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(hash);
  }

  /// Bytes'tan hash hesapla
  String calculateBytesHash(Uint8List bytes) {
    try {
      return sha256.convert(bytes).toString();
    } catch (e) {
      return '';
    }
  }
}
