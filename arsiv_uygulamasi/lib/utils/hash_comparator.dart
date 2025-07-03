import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/belge_modeli.dart';

/// Hash karşılaştırma algoritmaları ve gelişmiş karşılaştırma utilities
class HashComparator {
  static final HashComparator _instance = HashComparator._internal();
  static HashComparator get instance => _instance;
  HashComparator._internal();

  /// Çoklu hash algoritması ile karşılaştırma
  Future<HashComparisonResult> compareFiles(
    String filePath1,
    String filePath2, {
    List<HashAlgorithm> algorithms = const [HashAlgorithm.sha256],
  }) async {
    try {
      final file1 = File(filePath1);
      final file2 = File(filePath2);

      // Dosya varlık kontrolü
      if (!await file1.exists() || !await file2.exists()) {
        return HashComparisonResult(
          isMatch: false,
          error: 'Dosyalardan biri veya ikisi bulunamadı',
        );
      }

      // Boyut kontrolü (hızlı pre-check)
      final size1 = await file1.length();
      final size2 = await file2.length();

      if (size1 != size2) {
        return HashComparisonResult(
          isMatch: false,
          sizeDifference: (size1 - size2).abs(),
          details: 'Dosya boyutları farklı: $size1 vs $size2',
        );
      }

      // Hash hesaplama ve karşılaştırma
      final results = <HashAlgorithm, HashResult>{};
      bool overallMatch = true;

      for (final algorithm in algorithms) {
        final hash1 = await _calculateHash(filePath1, algorithm);
        final hash2 = await _calculateHash(filePath2, algorithm);

        final isMatch = hash1 == hash2;
        if (!isMatch) overallMatch = false;

        results[algorithm] = HashResult(
          hash1: hash1,
          hash2: hash2,
          isMatch: isMatch,
        );
      }

      return HashComparisonResult(
        isMatch: overallMatch,
        hashResults: results,
        details:
            overallMatch
                ? 'Tüm hash değerleri eşleşiyor'
                : 'Hash değerleri farklı',
      );
    } catch (e) {
      return HashComparisonResult(
        isMatch: false,
        error: 'Hash karşılaştırma hatası: $e',
      );
    }
  }

  /// Belge modelleri arası hash karşılaştırması
  Future<DocumentHashComparisonResult> compareDocuments(
    BelgeModeli doc1,
    BelgeModeli doc2,
  ) async {
    final results = <String, dynamic>{};

    // Stored hash karşılaştırması
    final storedHashMatch =
        doc1.dosyaHash.isNotEmpty &&
        doc2.dosyaHash.isNotEmpty &&
        doc1.dosyaHash == doc2.dosyaHash;

    results['storedHashMatch'] = storedHashMatch;

    // Dosya varsa gerçek hash karşılaştırması
    if (await File(doc1.dosyaYolu).exists() &&
        await File(doc2.dosyaYolu).exists()) {
      final fileComparison = await compareFiles(doc1.dosyaYolu, doc2.dosyaYolu);
      results['fileHashMatch'] = fileComparison.isMatch;
      results['fileComparison'] = fileComparison;
    }

    // Metadata hash karşılaştırması
    final metadataHash1 = generateMetadataHash(doc1);
    final metadataHash2 = generateMetadataHash(doc2);
    results['metadataHashMatch'] = metadataHash1 == metadataHash2;

    // Content signature karşılaştırması
    final contentSignature1 = generateContentSignature(doc1);
    final contentSignature2 = generateContentSignature(doc2);
    results['contentSignatureMatch'] = contentSignature1 == contentSignature2;

    final overallMatch =
        storedHashMatch &&
        (results['fileHashMatch'] ?? true) &&
        results['metadataHashMatch'] == true;

    return DocumentHashComparisonResult(
      isMatch: overallMatch,
      storedHashMatch: storedHashMatch,
      metadataHashMatch: results['metadataHashMatch'],
      contentSignatureMatch: results['contentSignatureMatch'],
      details: results,
    );
  }

  /// Batch hash karşılaştırması
  Future<BatchHashComparisonResult> compareBatch(
    List<String> filePaths1,
    List<String> filePaths2, {
    Function(int current, int total)? onProgress,
  }) async {
    if (filePaths1.length != filePaths2.length) {
      throw ArgumentError('Dosya listelerinin boyutları eşit olmalı');
    }

    final results = <String, HashComparisonResult>{};
    int matchCount = 0;
    int totalCount = filePaths1.length;

    for (int i = 0; i < totalCount; i++) {
      onProgress?.call(i + 1, totalCount);

      final comparison = await compareFiles(filePaths1[i], filePaths2[i]);
      results['${i}_${filePaths1[i]}_vs_${filePaths2[i]}'] = comparison;

      if (comparison.isMatch) matchCount++;
    }

    return BatchHashComparisonResult(
      totalFiles: totalCount,
      matchingFiles: matchCount,
      mismatchedFiles: totalCount - matchCount,
      results: results,
    );
  }

  /// Gelişmiş dosya fingerprint oluşturma
  Future<FileFingerprint> createFileFingerprint(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('Dosya bulunamadı', filePath);
      }

      final stat = await file.stat();
      final bytes = await file.readAsBytes();

      // Çoklu hash hesaplama
      final md5Hash = md5.convert(bytes).toString();
      final sha1Hash = sha1.convert(bytes).toString();
      final sha256Hash = sha256.convert(bytes).toString();

      // Dosya başlık analizi
      final header = bytes.take(1024).toList();
      final headerHash = sha256.convert(header).toString();

      // Dosya kuyruk analizi
      final footer =
          bytes.length > 1024
              ? bytes.skip(bytes.length - 1024).toList()
              : bytes;
      final footerHash = sha256.convert(footer).toString();

      // Block-level hashing (dosyayı bloklara böl)
      final blockHashes = _calculateBlockHashes(bytes);

      return FileFingerprint(
        filePath: filePath,
        fileSize: stat.size,
        modifiedTime: stat.modified,
        md5Hash: md5Hash,
        sha1Hash: sha1Hash,
        sha256Hash: sha256Hash,
        headerHash: headerHash,
        footerHash: footerHash,
        blockHashes: blockHashes,
      );
    } catch (e) {
      throw Exception('Fingerprint oluşturma hatası: $e');
    }
  }

  /// Block-level hash hesaplama
  List<String> _calculateBlockHashes(Uint8List bytes, {int blockSize = 4096}) {
    final hashes = <String>[];

    for (int i = 0; i < bytes.length; i += blockSize) {
      final end = (i + blockSize < bytes.length) ? i + blockSize : bytes.length;
      final block = bytes.sublist(i, end);
      final blockHash = sha256.convert(block).toString();
      hashes.add(blockHash);
    }

    return hashes;
  }

  /// Hash algoritması ile hash hesaplama
  Future<String> _calculateHash(
    String filePath,
    HashAlgorithm algorithm,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    switch (algorithm) {
      case HashAlgorithm.md5:
        return md5.convert(bytes).toString();
      case HashAlgorithm.sha1:
        return sha1.convert(bytes).toString();
      case HashAlgorithm.sha256:
        return sha256.convert(bytes).toString();
      case HashAlgorithm.sha512:
        return sha512.convert(bytes).toString();
    }
  }

  /// Metadata hash oluşturma
  String generateMetadataHash(BelgeModeli belge) {
    final metadata = {
      'dosyaAdi': belge.dosyaAdi,
      'orijinalDosyaAdi': belge.orijinalDosyaAdi,
      'dosyaBoyutu': belge.dosyaBoyutu,
      'dosyaTipi': belge.dosyaTipi,
      'baslik': belge.baslik ?? '',
      'aciklama': belge.aciklama ?? '',
      'kategoriId': belge.kategoriId,
      'kisiId': belge.kisiId,
    };

    final jsonString = json.encode(metadata);
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  /// Content signature oluşturma (metadata + partial content)
  String generateContentSignature(BelgeModeli belge) {
    final signature = {
      'dosyaAdi': belge.dosyaAdi,
      'dosyaBoyutu': belge.dosyaBoyutu,
      'dosyaHash': belge.dosyaHash,
      'olusturmaTarihi': belge.olusturmaTarihi.millisecondsSinceEpoch,
      'guncellemeTarihi': belge.guncellemeTarihi.millisecondsSinceEpoch,
    };

    final jsonString = json.encode(signature);
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  /// Incremental hash verification
  Future<bool> verifyIncrementalHash(
    String filePath,
    String expectedHash, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      final bytes = await file.readAsBytes();

      // Progress tracking during read
      if (onProgress != null) {
        onProgress(1.0);
      }

      final calculatedHash = sha256.convert(bytes).toString();
      return calculatedHash == expectedHash;
    } catch (e) {
      return false;
    }
  }

  /// Hash collision detection
  Future<bool> detectHashCollision(List<String> filePaths) async {
    final hashes = <String, String>{};

    for (final filePath in filePaths) {
      final hash = await _calculateHash(filePath, HashAlgorithm.sha256);

      if (hashes.containsKey(hash)) {
        // Collision detected - same hash, different files
        return true;
      }

      hashes[hash] = filePath;
    }

    return false;
  }

  /// Fuzzy hash karşılaştırması (similarity)
  double calculateSimilarity(String hash1, String hash2) {
    if (hash1 == hash2) return 1.0;
    if (hash1.isEmpty || hash2.isEmpty) return 0.0;

    // Hamming distance for same-length hashes
    if (hash1.length == hash2.length) {
      int differences = 0;
      for (int i = 0; i < hash1.length; i++) {
        if (hash1[i] != hash2[i]) differences++;
      }
      return 1.0 - (differences / hash1.length);
    }

    // For different length hashes, use a simple approach
    final minLength = hash1.length < hash2.length ? hash1.length : hash2.length;
    int matches = 0;

    for (int i = 0; i < minLength; i++) {
      if (hash1[i] == hash2[i]) matches++;
    }

    return matches / minLength;
  }
}

/// Hash algoritmaları
enum HashAlgorithm { md5, sha1, sha256, sha512 }

/// Hash karşılaştırma sonucu
class HashComparisonResult {
  final bool isMatch;
  final Map<HashAlgorithm, HashResult>? hashResults;
  final int? sizeDifference;
  final String? details;
  final String? error;

  HashComparisonResult({
    required this.isMatch,
    this.hashResults,
    this.sizeDifference,
    this.details,
    this.error,
  });

  @override
  String toString() {
    return 'HashComparisonResult(isMatch: $isMatch, details: $details)';
  }
}

/// Tekil hash sonucu
class HashResult {
  final String hash1;
  final String hash2;
  final bool isMatch;

  HashResult({required this.hash1, required this.hash2, required this.isMatch});
}

/// Belge hash karşılaştırma sonucu
class DocumentHashComparisonResult {
  final bool isMatch;
  final bool storedHashMatch;
  final bool metadataHashMatch;
  final bool contentSignatureMatch;
  final Map<String, dynamic> details;

  DocumentHashComparisonResult({
    required this.isMatch,
    required this.storedHashMatch,
    required this.metadataHashMatch,
    required this.contentSignatureMatch,
    required this.details,
  });
}

/// Batch hash karşılaştırma sonucu
class BatchHashComparisonResult {
  final int totalFiles;
  final int matchingFiles;
  final int mismatchedFiles;
  final Map<String, HashComparisonResult> results;

  BatchHashComparisonResult({
    required this.totalFiles,
    required this.matchingFiles,
    required this.mismatchedFiles,
    required this.results,
  });

  double get matchPercentage =>
      totalFiles > 0 ? matchingFiles / totalFiles : 0.0;

  @override
  String toString() {
    return 'BatchHashComparisonResult(total: $totalFiles, matching: $matchingFiles, rate: ${(matchPercentage * 100).toStringAsFixed(1)}%)';
  }
}

/// Dosya parmak izi
class FileFingerprint {
  final String filePath;
  final int fileSize;
  final DateTime modifiedTime;
  final String md5Hash;
  final String sha1Hash;
  final String sha256Hash;
  final String headerHash;
  final String footerHash;
  final List<String> blockHashes;

  FileFingerprint({
    required this.filePath,
    required this.fileSize,
    required this.modifiedTime,
    required this.md5Hash,
    required this.sha1Hash,
    required this.sha256Hash,
    required this.headerHash,
    required this.footerHash,
    required this.blockHashes,
  });

  /// Fingerprint karşılaştırması
  bool matches(FileFingerprint other) {
    return sha256Hash == other.sha256Hash &&
        fileSize == other.fileSize &&
        headerHash == other.headerHash &&
        footerHash == other.footerHash;
  }

  /// Kısmi eşleşme kontrolü
  double partialMatch(FileFingerprint other) {
    double score = 0.0;
    int checks = 0;

    // Boyut kontrolü
    checks++;
    if (fileSize == other.fileSize) score += 1.0;

    // Hash kontrolleri
    checks++;
    if (sha256Hash == other.sha256Hash) score += 1.0;

    checks++;
    if (headerHash == other.headerHash) score += 1.0;

    checks++;
    if (footerHash == other.footerHash) score += 1.0;

    // Block hash benzerliği
    checks++;
    final blockSimilarity = _calculateBlockSimilarity(other);
    score += blockSimilarity;

    return score / checks;
  }

  /// Block benzerlik hesaplama
  double _calculateBlockSimilarity(FileFingerprint other) {
    if (blockHashes.isEmpty || other.blockHashes.isEmpty) return 0.0;

    final minBlocks =
        blockHashes.length < other.blockHashes.length
            ? blockHashes.length
            : other.blockHashes.length;

    int matches = 0;
    for (int i = 0; i < minBlocks; i++) {
      if (blockHashes[i] == other.blockHashes[i]) {
        matches++;
      }
    }

    return matches / minBlocks;
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileSize': fileSize,
      'modifiedTime': modifiedTime.toIso8601String(),
      'md5Hash': md5Hash,
      'sha1Hash': sha1Hash,
      'sha256Hash': sha256Hash,
      'headerHash': headerHash,
      'footerHash': footerHash,
      'blockHashes': blockHashes,
    };
  }

  @override
  String toString() {
    return 'FileFingerprint(path: $filePath, size: $fileSize, sha256: ${sha256Hash.substring(0, 16)}...)';
  }
}
