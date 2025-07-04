import 'dart:io';
import 'dart:convert';

/// Zaman damgası yönetimi ve synchronization timing utilities
class TimestampManager {
  static final TimestampManager _instance = TimestampManager._internal();
  static TimestampManager get instance => _instance;
  TimestampManager._internal();

  // Timezone offset cache
  Duration? _timezoneOffset;
  DateTime? _lastServerSync;
  Duration _serverTimeDrift = Duration.zero;

  /// UTC zaman damgası oluştur
  DateTime createUtcTimestamp() {
    return DateTime.now().toUtc();
  }

  /// Server ile senkronize zaman damgası
  DateTime createSyncedTimestamp() {
    final now = DateTime.now().toUtc();
    return now.add(_serverTimeDrift);
  }

  /// Timestamp'i normalize et (UTC'ye çevir)
  DateTime normalizeTimestamp(DateTime timestamp) {
    if (timestamp.isUtc) {
      return timestamp;
    }
    return timestamp.toUtc();
  }

  /// İki timestamp arasındaki farkı hesapla
  Duration calculateTimeDifference(DateTime timestamp1, DateTime timestamp2) {
    final normalizedTime1 = normalizeTimestamp(timestamp1);
    final normalizedTime2 = normalizeTimestamp(timestamp2);
    return normalizedTime1.difference(normalizedTime2);
  }

  /// Timestamp'leri karşılaştır (tolerance ile)
  TimestampComparisonResult compareTimestamps(
    DateTime timestamp1,
    DateTime timestamp2, {
    Duration tolerance = const Duration(seconds: 5),
  }) {
    final difference = calculateTimeDifference(timestamp1, timestamp2);
    final absDifference = Duration(
      microseconds: difference.inMicroseconds.abs(),
    );

    if (absDifference <= tolerance) {
      return TimestampComparisonResult(
        isEqual: true,
        difference: difference,
        withinTolerance: true,
      );
    }

    return TimestampComparisonResult(
      isEqual: false,
      difference: difference,
      withinTolerance: false,
      isNewer: timestamp1.isAfter(timestamp2),
    );
  }

  /// Server zaman senkronizasyonu
  Future<ServerSyncResult> syncWithServer(String serverUrl) async {
    try {
      final startTime = DateTime.now().toUtc();

      // Server'dan zaman bilgisi al
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$serverUrl/time'));
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      final responseTime = DateTime.now().toUtc();

      if (response.statusCode == 200) {
        final responseBody =
            await response.transform(const Utf8Decoder()).join();
        final serverTimeStr = responseBody.trim().replaceAll('"', '');
        final serverTime = DateTime.parse(serverTimeStr).toUtc();

        // Round-trip time hesapla
        final roundTripTime = responseTime.difference(startTime);
        final estimatedServerTime = serverTime.add(
          Duration(microseconds: roundTripTime.inMicroseconds ~/ 2),
        );

        // Time drift hesapla
        _serverTimeDrift = estimatedServerTime.difference(responseTime);
        _lastServerSync = responseTime;

        return ServerSyncResult(
          success: true,
          serverTime: serverTime,
          localTime: responseTime,
          timeDrift: _serverTimeDrift,
          roundTripTime: roundTripTime,
        );
      } else {
        return ServerSyncResult(
          success: false,
          error: 'Server yanıt hatası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ServerSyncResult(success: false, error: 'Server sync hatası: $e');
    }
  }

  /// Timezone bilgilerini al ve cache'le
  Duration getTimezoneOffset() {
    if (_timezoneOffset == null) {
      final now = DateTime.now();
      final utcNow = now.toUtc();
      _timezoneOffset = now.difference(utcNow);
    }
    return _timezoneOffset!;
  }

  /// Relative timestamp oluştur (X dakika önce gibi)
  String formatRelativeTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks hafta önce';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce';
    }
  }

  /// Precise timestamp formatting
  String formatPreciseTimestamp(DateTime timestamp) {
    return timestamp.toIso8601String();
  }

  /// Human readable timestamp
  String formatHumanReadableTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Timestamp validation
  bool isValidTimestamp(DateTime timestamp) {
    // Reasonable date range check (1970 - 2100)
    final minDate = DateTime(1970);
    final maxDate = DateTime(2100);

    return timestamp.isAfter(minDate) && timestamp.isBefore(maxDate);
  }

  /// Conflict timeline analizi
  ConflictTimeline analyzeConflictTimeline(
    DateTime localTimestamp,
    DateTime remoteTimestamp,
  ) {
    final difference = calculateTimeDifference(localTimestamp, remoteTimestamp);
    final absDifference = Duration(
      microseconds: difference.inMicroseconds.abs(),
    );

    ConflictSeverity severity;
    ConflictResolutionStrategy strategy;

    if (absDifference <= const Duration(minutes: 1)) {
      severity = ConflictSeverity.low;
      strategy = ConflictResolutionStrategy.useLatest;
    } else if (absDifference <= const Duration(hours: 1)) {
      severity = ConflictSeverity.medium;
      strategy = ConflictResolutionStrategy.requireManual;
    } else {
      severity = ConflictSeverity.high;
      strategy = ConflictResolutionStrategy.requireManual;
    }

    return ConflictTimeline(
      localTimestamp: localTimestamp,
      remoteTimestamp: remoteTimestamp,
      timeDifference: difference,
      severity: severity,
      recommendedStrategy: strategy,
      isLocalNewer: localTimestamp.isAfter(remoteTimestamp),
    );
  }

  /// Sync window hesaplama
  SyncWindow calculateSyncWindow(List<DateTime> timestamps) {
    if (timestamps.isEmpty) {
      return SyncWindow(
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        duration: Duration.zero,
        totalFiles: 0,
      );
    }

    final sortedTimestamps = List<DateTime>.from(timestamps)
      ..sort((a, b) => a.compareTo(b));

    final startTime = sortedTimestamps.first;
    final endTime = sortedTimestamps.last;
    final duration = endTime.difference(startTime);

    return SyncWindow(
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      totalFiles: timestamps.length,
    );
  }

  /// Optimum sync zamanı önerisi
  DateTime suggestOptimalSyncTime(List<DateTime> recentSyncTimes) {
    if (recentSyncTimes.isEmpty) {
      return DateTime.now().toUtc();
    }

    // Son sync'lerden ortalama interval hesapla
    final intervals = <Duration>[];
    for (int i = 1; i < recentSyncTimes.length; i++) {
      intervals.add(recentSyncTimes[i].difference(recentSyncTimes[i - 1]));
    }

    if (intervals.isEmpty) {
      return DateTime.now().toUtc().add(const Duration(hours: 1));
    }

    // Ortalama interval hesapla
    final totalMicroseconds = intervals
        .map((d) => d.inMicroseconds)
        .reduce((a, b) => a + b);
    final averageInterval = Duration(
      microseconds: totalMicroseconds ~/ intervals.length,
    );

    // Son sync'den ortalama interval sonra öner
    return recentSyncTimes.last.add(averageInterval);
  }

  /// Backup timestamp oluştur
  String createBackupTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  /// Timestamp'den epoch seconds
  int toEpochSeconds(DateTime timestamp) {
    return timestamp.millisecondsSinceEpoch ~/ 1000;
  }

  /// Epoch seconds'dan timestamp
  DateTime fromEpochSeconds(int epochSeconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    );
  }

  /// Sync state timing analizi
  SyncTimingAnalysis analyzeSyncTiming(
    DateTime syncStartTime,
    DateTime syncEndTime,
    int processedFiles,
    int totalBytes,
  ) {
    final duration = syncEndTime.difference(syncStartTime);
    final avgFileTime =
        processedFiles > 0
            ? Duration(microseconds: duration.inMicroseconds ~/ processedFiles)
            : Duration.zero;

    final bytesPerSecond =
        duration.inSeconds > 0 ? totalBytes / duration.inSeconds : 0.0;

    SyncPerformance performance;
    if (bytesPerSecond > 1024 * 1024) {
      // > 1 MB/s
      performance = SyncPerformance.excellent;
    } else if (bytesPerSecond > 512 * 1024) {
      // > 512 KB/s
      performance = SyncPerformance.good;
    } else if (bytesPerSecond > 128 * 1024) {
      // > 128 KB/s
      performance = SyncPerformance.average;
    } else {
      performance = SyncPerformance.poor;
    }

    return SyncTimingAnalysis(
      startTime: syncStartTime,
      endTime: syncEndTime,
      duration: duration,
      processedFiles: processedFiles,
      totalBytes: totalBytes,
      averageFileTime: avgFileTime,
      bytesPerSecond: bytesPerSecond,
      performance: performance,
    );
  }

  /// Reset cache
  void resetCache() {
    _timezoneOffset = null;
    _lastServerSync = null;
    _serverTimeDrift = Duration.zero;
  }
}

/// Timestamp karşılaştırma sonucu
class TimestampComparisonResult {
  final bool isEqual;
  final Duration difference;
  final bool withinTolerance;
  final bool? isNewer;

  TimestampComparisonResult({
    required this.isEqual,
    required this.difference,
    required this.withinTolerance,
    this.isNewer,
  });

  // Backward compatibility
  String get relationship {
    if (isEqual) return 'equal';
    if (isNewer == true) return 'newer';
    if (isNewer == false) return 'older';
    return 'unknown';
  }

  @override
  String toString() {
    return 'TimestampComparisonResult(equal: $isEqual, diff: ${difference.inSeconds}s, tolerance: $withinTolerance)';
  }
}

/// Server sync sonucu
class ServerSyncResult {
  final bool success;
  final DateTime? serverTime;
  final DateTime? localTime;
  final Duration? timeDrift;
  final Duration? roundTripTime;
  final String? error;

  ServerSyncResult({
    required this.success,
    this.serverTime,
    this.localTime,
    this.timeDrift,
    this.roundTripTime,
    this.error,
  });

  @override
  String toString() {
    return 'ServerSyncResult(success: $success, drift: ${timeDrift?.inMilliseconds}ms)';
  }
}

/// Conflict timeline
class ConflictTimeline {
  final DateTime localTimestamp;
  final DateTime remoteTimestamp;
  final Duration timeDifference;
  final ConflictSeverity severity;
  final ConflictResolutionStrategy recommendedStrategy;
  final bool isLocalNewer;

  ConflictTimeline({
    required this.localTimestamp,
    required this.remoteTimestamp,
    required this.timeDifference,
    required this.severity,
    required this.recommendedStrategy,
    required this.isLocalNewer,
  });
}

/// Sync window
class SyncWindow {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int totalFiles;

  SyncWindow({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalFiles,
  });

  double get filesPerSecond =>
      duration.inSeconds > 0 ? totalFiles / duration.inSeconds : 0.0;
}

/// Sync timing analizi
class SyncTimingAnalysis {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final int processedFiles;
  final int totalBytes;
  final Duration averageFileTime;
  final double bytesPerSecond;
  final SyncPerformance performance;

  SyncTimingAnalysis({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.processedFiles,
    required this.totalBytes,
    required this.averageFileTime,
    required this.bytesPerSecond,
    required this.performance,
  });

  String get formattedBytesPerSecond {
    if (bytesPerSecond > 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (bytesPerSecond > 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${bytesPerSecond.toStringAsFixed(2)} B/s';
    }
  }
}

/// Enums
enum ConflictSeverity { low, medium, high }

enum ConflictResolutionStrategy { useLatest, useOldest, requireManual }

enum SyncPerformance { excellent, good, average, poor }
