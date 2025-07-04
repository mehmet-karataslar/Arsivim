import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_cihazi.dart';
import 'yardimci_fonksiyonlar.dart';

/// Senkronizasyon yardımcı fonksiyonları
class SenkronUtils {
  /// Dosya benzerlik karşılaştırması
  static double calculateFileSimilarity(BelgeModeli file1, BelgeModeli file2) {
    double score = 0.0;
    int totalChecks = 0;

    // Dosya adı benzerliği
    totalChecks++;
    if (file1.dosyaAdi == file2.dosyaAdi) {
      score += 1.0;
    } else if (file1.dosyaAdi.toLowerCase() == file2.dosyaAdi.toLowerCase()) {
      score += 0.8;
    } else {
      final similarity = _calculateStringSimilarity(
        file1.dosyaAdi,
        file2.dosyaAdi,
      );
      score += similarity * 0.6;
    }

    // Orijinal dosya adı benzerliği
    totalChecks++;
    if (file1.orijinalDosyaAdi == file2.orijinalDosyaAdi) {
      score += 1.0;
    } else {
      final similarity = _calculateStringSimilarity(
        file1.orijinalDosyaAdi,
        file2.orijinalDosyaAdi,
      );
      score += similarity * 0.8;
    }

    // Dosya boyutu benzerliği
    totalChecks++;
    if (file1.dosyaBoyutu == file2.dosyaBoyutu) {
      score += 1.0;
    } else {
      final sizeDiff = (file1.dosyaBoyutu - file2.dosyaBoyutu).abs();
      final avgSize = (file1.dosyaBoyutu + file2.dosyaBoyutu) / 2;
      if (avgSize > 0) {
        final similarity = 1.0 - (sizeDiff / avgSize);
        score += max(0.0, similarity);
      }
    }

    // Dosya tipi benzerliği
    totalChecks++;
    if (file1.dosyaTipi == file2.dosyaTipi) {
      score += 1.0;
    }

    // Hash benzerliği (en önemli)
    totalChecks++;
    if (file1.dosyaHash.isNotEmpty && file2.dosyaHash.isNotEmpty) {
      if (file1.dosyaHash == file2.dosyaHash) {
        score += 2.0; // Hash eşleşmesi çok önemli
      }
    }

    return score / (totalChecks + 1); // Hash için +1 extra weight
  }

  /// String benzerliği hesaplama (Levenshtein distance)
  static double _calculateStringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final maxLength = max(a.length, b.length);
    return 1.0 - (matrix[a.length][b.length] / maxLength);
  }

  /// Transfer hızı hesaplama
  static double calculateTransferSpeed(int bytes, Duration duration) {
    if (duration.inMilliseconds == 0) return 0.0;
    return bytes / (duration.inMilliseconds / 1000.0); // bytes/second
  }

  /// ETA hesaplama
  static Duration calculateETA(int remainingBytes, double transferSpeed) {
    if (transferSpeed <= 0) return Duration.zero;
    final seconds = remainingBytes / transferSpeed;
    return Duration(seconds: seconds.round());
  }

  /// Dosya öncelik hesaplama
  static int calculateFilePriority(BelgeModeli belge) {
    int priority = 0;

    // Dosya boyutu (küçük dosyalar öncelikli)
    if (belge.dosyaBoyutu < 1024 * 1024) {
      // 1MB'den küçük
      priority += 3;
    } else if (belge.dosyaBoyutu < 10 * 1024 * 1024) {
      // 10MB'den küçük
      priority += 2;
    } else {
      priority += 1;
    }

    // Dosya tipi (önemli dosyalar öncelikli)
    switch (belge.dosyaTipi.toLowerCase()) {
      case 'pdf':
      case 'doc':
      case 'docx':
        priority += 3;
        break;
      case 'txt':
      case 'rtf':
        priority += 2;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        priority += 1;
        break;
      default:
        priority += 0;
    }

    // Güncellik (yeni dosyalar öncelikli)
    final daysSinceUpdate =
        DateTime.now().difference(belge.guncellemeTarihi).inDays;
    if (daysSinceUpdate < 1) {
      priority += 3;
    } else if (daysSinceUpdate < 7) {
      priority += 2;
    } else if (daysSinceUpdate < 30) {
      priority += 1;
    }

    return priority;
  }

  /// Batch işlem optimizasyonu
  static List<List<T>> createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  /// Optimal batch boyutu hesaplama
  static int calculateOptimalBatchSize(int totalItems, int maxConcurrency) {
    if (totalItems <= maxConcurrency) return 1;

    // Her batch'de en az 1, en fazla 10 item olsun
    final batchSize = (totalItems / maxConcurrency).ceil();
    return max(1, min(10, batchSize));
  }

  /// Dosya yolu normalize etme
  static String normalizePath(String path) {
    return path.replaceAll(RegExp(r'[/\\]+'), Platform.pathSeparator);
  }

  /// Güvenli dosya adı oluşturma
  static String createSafeFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last;
    final baseName = originalName.split('.').first;

    // Geçersiz karakterleri temizle
    final safeName = baseName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    return '${safeName}_$timestamp.$extension';
  }

  /// Checksum hesaplama
  static String calculateChecksum(List<int> data) {
    return sha256.convert(data).toString();
  }

  /// Dosya metadata çıkarma
  static Map<String, dynamic> extractFileMetadata(File file) {
    final stat = file.statSync();
    return {
      'size': stat.size,
      'created': stat.changed.toIso8601String(),
      'modified': stat.modified.toIso8601String(),
      'accessed': stat.accessed.toIso8601String(),
      'path': file.path,
      'extension': file.path.split('.').last.toLowerCase(),
    };
  }

  /// Senkronizasyon istatistikleri
  static SyncStatistics calculateSyncStatistics(List<BelgeModeli> files) {
    int totalSize = 0;
    int totalFiles = files.length;
    final typeCount = <String, int>{};
    DateTime? oldestFile;
    DateTime? newestFile;

    for (final file in files) {
      totalSize += file.dosyaBoyutu;

      // Dosya tipi sayısı
      typeCount[file.dosyaTipi] = (typeCount[file.dosyaTipi] ?? 0) + 1;

      // En eski ve en yeni dosya
      if (oldestFile == null || file.olusturmaTarihi.isBefore(oldestFile)) {
        oldestFile = file.olusturmaTarihi;
      }
      if (newestFile == null || file.olusturmaTarihi.isAfter(newestFile)) {
        newestFile = file.olusturmaTarihi;
      }
    }

    return SyncStatistics(
      totalFiles: totalFiles,
      totalSize: totalSize,
      averageSize: totalFiles > 0 ? totalSize / totalFiles : 0,
      typeDistribution: typeCount,
      oldestFile: oldestFile,
      newestFile: newestFile,
    );
  }

  /// Cihaz bilgileri karşılaştırması
  static bool devicesAreCompatible(
    SenkronCihazi device1,
    SenkronCihazi device2,
  ) {
    // Platform kontrolü
    if (device1.platform != device2.platform) {
      // Cross-platform sync için ek kontroller
      if (!_isCrossPlatformSupported(device1.platform, device2.platform)) {
        return false;
      }
    }

    // Aktiflik kontrolü
    if (!device1.aktif || !device2.aktif) {
      return false;
    }

    // Son görülme kontrolü (24 saat)
    final now = DateTime.now();
    if (now.difference(device1.sonGorulen).inHours > 24 ||
        now.difference(device2.sonGorulen).inHours > 24) {
      return false;
    }

    return true;
  }

  /// Cross-platform destek kontrolü
  static bool _isCrossPlatformSupported(String platform1, String platform2) {
    const supportedPlatforms = ['android', 'ios', 'windows', 'linux', 'macos'];
    return supportedPlatforms.contains(platform1.toLowerCase()) &&
        supportedPlatforms.contains(platform2.toLowerCase());
  }

  /// Conflict severity hesaplama
  static ConflictSeverity calculateConflictSeverity(
    BelgeModeli localFile,
    Map<String, dynamic> remoteFile,
  ) {
    int severity = 0;

    // Dosya boyutu farkı
    final remoteSize = remoteFile['dosyaBoyutu'] ?? 0;
    final sizeDiff = (localFile.dosyaBoyutu - remoteSize).abs();
    if (sizeDiff > 0) {
      severity +=
          (sizeDiff / max(localFile.dosyaBoyutu, remoteSize) * 10).round();
    }

    // Zaman farkı
    final remoteTime = DateTime.parse(
      remoteFile['guncellemeTarihi'] ?? remoteFile['olusturmaTarihi'],
    );
    final timeDiff =
        localFile.guncellemeTarihi.difference(remoteTime).inMinutes.abs();
    if (timeDiff > 5) {
      severity += min(5, timeDiff ~/ 60); // Her saat için 1 puan
    }

    // Hash farkı
    final remoteHash = remoteFile['dosyaHash'] ?? '';
    if (localFile.dosyaHash.isNotEmpty && remoteHash.isNotEmpty) {
      if (localFile.dosyaHash != remoteHash) {
        severity += 5; // Hash farkı önemli
      }
    }

    if (severity <= 2) return ConflictSeverity.low;
    if (severity <= 7) return ConflictSeverity.medium;
    return ConflictSeverity.high;
  }

  /// Unique ID oluşturma
  static String generateUniqueId([String? prefix]) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(99999);
    return '${prefix ?? 'sync'}_${timestamp}_$random';
  }

  /// Dosya backup oluşturma
  static Future<String?> createBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final backupPath =
          '${filePath}.backup.${DateTime.now().millisecondsSinceEpoch}';
      await file.copy(backupPath);
      return backupPath;
    } catch (e) {
      return null;
    }
  }

  /// Temporary file oluşturma
  static Future<String> createTempFile(String extension) async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'sync_temp_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final tempPath = '${tempDir.path}${Platform.pathSeparator}$fileName';

    final tempFile = File(tempPath);
    await tempFile.create();

    return tempPath;
  }

  /// Cleanup temp files
  static Future<void> cleanupTempFiles(String pattern) async {
    try {
      final tempDir = Directory.systemTemp;
      final files =
          await tempDir
              .list()
              .where(
                (entity) => entity is File && entity.path.contains(pattern),
              )
              .toList();

      for (final file in files) {
        try {
          await file.delete();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

/// Senkronizasyon istatistikleri
class SyncStatistics {
  final int totalFiles;
  final int totalSize;
  final double averageSize;
  final Map<String, int> typeDistribution;
  final DateTime? oldestFile;
  final DateTime? newestFile;

  SyncStatistics({
    required this.totalFiles,
    required this.totalSize,
    required this.averageSize,
    required this.typeDistribution,
    this.oldestFile,
    this.newestFile,
  });

  String get formattedTotalSize =>
      YardimciFonksiyonlar.dosyaBoyutuFormatla(totalSize);
  String get formattedAverageSize =>
      YardimciFonksiyonlar.dosyaBoyutuFormatla(averageSize.round());

  Duration? get dateRange {
    if (oldestFile == null || newestFile == null) return null;
    return newestFile!.difference(oldestFile!);
  }

  @override
  String toString() {
    return 'SyncStatistics(files: $totalFiles, size: $formattedTotalSize, avg: $formattedAverageSize)';
  }
}

/// Conflict severity enum
enum ConflictSeverity { low, medium, high }

/// Conflict severity uzantıları
extension ConflictSeverityExtension on ConflictSeverity {
  String get displayName {
    switch (this) {
      case ConflictSeverity.low:
        return 'Düşük';
      case ConflictSeverity.medium:
        return 'Orta';
      case ConflictSeverity.high:
        return 'Yüksek';
    }
  }

  String get description {
    switch (this) {
      case ConflictSeverity.low:
        return 'Otomatik çözülebilir';
      case ConflictSeverity.medium:
        return 'Dikkat gerekli';
      case ConflictSeverity.high:
        return 'Manuel müdahale gerekli';
    }
  }
}
