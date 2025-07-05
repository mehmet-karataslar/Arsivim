import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'veritabani_servisi.dart';

/// Senkronizasyon hata türleri
enum SenkronErrorType {
  network,
  authentication,
  storage,
  conflict,
  timeout,
  validation,
  unknown,
}

/// Hata kurtarma stratejileri
enum RecoveryStrategy { retry, skip, fallback, manual, abort }

/// Detaylı hata bilgisi
class SenkronErrorInfo {
  final String errorId;
  final SenkronErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  final RecoveryStrategy suggestedStrategy;
  final int retryCount;
  final Duration? retryDelay;

  SenkronErrorInfo({
    required this.errorId,
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
    required this.timestamp,
    this.context = const {},
    required this.suggestedStrategy,
    this.retryCount = 0,
    this.retryDelay,
  });

  Map<String, dynamic> toJson() => {
    'errorId': errorId,
    'type': type.name,
    'message': message,
    'originalError': originalError?.toString(),
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'suggestedStrategy': suggestedStrategy.name,
    'retryCount': retryCount,
    'retryDelay': retryDelay?.inMilliseconds,
  };
}

/// Gelişmiş senkronizasyon hata yöneticisi
class SenkronErrorHandler {
  static final SenkronErrorHandler _instance = SenkronErrorHandler._internal();
  static SenkronErrorHandler get instance => _instance;
  SenkronErrorHandler._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final List<SenkronErrorInfo> _errorHistory = [];
  final Map<String, int> _retryCounters = {};

  // Callbacks
  Function(SenkronErrorInfo)? onError;
  Function(SenkronErrorInfo)? onRetry;
  Function(SenkronErrorInfo)? onRecovery;

  /// Hata loglama tablosunu başlat
  Future<void> initializeErrorLogging() async {
    final db = await _veriTabani.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_errors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        error_id TEXT NOT NULL UNIQUE,
        error_type TEXT NOT NULL,
        message TEXT NOT NULL,
        original_error TEXT,
        stack_trace TEXT,
        timestamp TEXT NOT NULL,
        context TEXT,
        suggested_strategy TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        retry_delay INTEGER,
        resolved INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_errors_type 
      ON senkron_errors(error_type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_errors_timestamp 
      ON senkron_errors(timestamp)
    ''');

    print('🔧 SenkronErrorHandler initialized');
  }

  /// Hatayı analiz et ve kategorize et
  SenkronErrorInfo categorizeError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();
    final errorMessage = error.toString();

    SenkronErrorType type;
    RecoveryStrategy strategy;
    Duration? retryDelay;

    // Hata tipini belirle
    if (error is SocketException ||
        error is TimeoutException ||
        errorMessage.contains('Connection') ||
        errorMessage.contains('Network')) {
      type = SenkronErrorType.network;
      strategy = RecoveryStrategy.retry;
      retryDelay = const Duration(seconds: 5);
    } else if (error is HttpException &&
        (errorMessage.contains('401') || errorMessage.contains('403'))) {
      type = SenkronErrorType.authentication;
      strategy = RecoveryStrategy.manual;
    } else if (error is FileSystemException ||
        errorMessage.contains('Storage') ||
        errorMessage.contains('Permission')) {
      type = SenkronErrorType.storage;
      strategy = RecoveryStrategy.skip;
    } else if (errorMessage.contains('Conflict') ||
        errorMessage.contains('Version')) {
      type = SenkronErrorType.conflict;
      strategy = RecoveryStrategy.manual;
    } else if (error is TimeoutException || errorMessage.contains('timeout')) {
      type = SenkronErrorType.timeout;
      strategy = RecoveryStrategy.retry;
      retryDelay = const Duration(seconds: 10);
    } else if (errorMessage.contains('Validation') ||
        errorMessage.contains('Invalid')) {
      type = SenkronErrorType.validation;
      strategy = RecoveryStrategy.skip;
    } else {
      type = SenkronErrorType.unknown;
      strategy = RecoveryStrategy.fallback;
    }

    return SenkronErrorInfo(
      errorId: errorId,
      type: type,
      message: errorMessage,
      originalError: error,
      stackTrace: stackTrace,
      timestamp: timestamp,
      context: context ?? {},
      suggestedStrategy: strategy,
      retryDelay: retryDelay,
    );
  }

  /// Yeniden deneme kararı ver
  Future<bool> shouldRetry(SenkronErrorInfo errorInfo) async {
    final errorKey =
        '${errorInfo.type.name}_${errorInfo.context['operation'] ?? 'unknown'}';
    final currentRetryCount = _retryCounters[errorKey] ?? 0;

    // Maksimum retry limitleri
    const maxRetries = {
      SenkronErrorType.network: 3,
      SenkronErrorType.timeout: 2,
      SenkronErrorType.storage: 1,
      SenkronErrorType.authentication: 0,
      SenkronErrorType.conflict: 0,
      SenkronErrorType.validation: 0,
      SenkronErrorType.unknown: 1,
    };

    final maxRetryCount = maxRetries[errorInfo.type] ?? 0;
    final shouldRetry = currentRetryCount < maxRetryCount;

    if (shouldRetry) {
      _retryCounters[errorKey] = currentRetryCount + 1;

      // Network durumunu kontrol et
      if (errorInfo.type == SenkronErrorType.network) {
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity == ConnectivityResult.none) {
          return false; // Network yoksa retry yapma
        }
      }
    }

    return shouldRetry;
  }

  /// Detaylı hata kaydı
  Future<void> logDetailedError(SenkronErrorInfo errorInfo) async {
    try {
      final db = await _veriTabani.database;

      await db.insert('senkron_errors', {
        'error_id': errorInfo.errorId,
        'error_type': errorInfo.type.name,
        'message': errorInfo.message,
        'original_error': errorInfo.originalError?.toString(),
        'stack_trace': errorInfo.stackTrace?.toString(),
        'timestamp': errorInfo.timestamp.toIso8601String(),
        'context':
            errorInfo.context.isNotEmpty ? errorInfo.context.toString() : null,
        'suggested_strategy': errorInfo.suggestedStrategy.name,
        'retry_count': errorInfo.retryCount,
        'retry_delay': errorInfo.retryDelay?.inMilliseconds,
        'resolved': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Memory'de de sakla
      _errorHistory.add(errorInfo);
      if (_errorHistory.length > 100) {
        _errorHistory.removeAt(0); // En eskisini kaldır
      }

      // Callback çağır
      onError?.call(errorInfo);

      print('🔴 Detaylı hata kaydedildi: ${errorInfo.errorId}');
      print('   Tip: ${errorInfo.type.name}');
      print('   Mesaj: ${errorInfo.message}');
      print('   Strateji: ${errorInfo.suggestedStrategy.name}');
    } catch (e) {
      print('❌ Hata kaydı başarısız: $e');
    }
  }

  /// Hata kurtarma stratejisini uygula
  Future<Map<String, dynamic>> recoverFromError(
    SenkronErrorInfo errorInfo,
  ) async {
    switch (errorInfo.suggestedStrategy) {
      case RecoveryStrategy.retry:
        // Retry delay uygula
        if (errorInfo.retryDelay != null) {
          await Future.delayed(errorInfo.retryDelay!);
        }

        onRetry?.call(errorInfo);
        return {
          'action': 'retry',
          'delay': errorInfo.retryDelay?.inMilliseconds ?? 0,
          'message': 'Yeniden deneniyor...',
        };

      case RecoveryStrategy.skip:
        return {'action': 'skip', 'message': 'İşlem atlandı'};

      case RecoveryStrategy.fallback:
        return {'action': 'fallback', 'message': 'Alternatif yöntem deneniyor'};

      case RecoveryStrategy.manual:
        return {'action': 'manual', 'message': 'Manuel müdahale gerekiyor'};

      case RecoveryStrategy.abort:
        return {'action': 'abort', 'message': 'İşlem iptal edildi'};
    }
  }

  /// Hata geçmişini temizle
  void clearErrorHistory() {
    _errorHistory.clear();
    _retryCounters.clear();
  }

  /// Hata istatistiklerini al
  Future<Map<String, dynamic>> getErrorStatistics() async {
    final db = await _veriTabani.database;

    final stats = <String, dynamic>{};

    // Tip bazında hata sayıları
    for (final type in SenkronErrorType.values) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM senkron_errors WHERE error_type = ?',
        [type.name],
      );
      stats[type.name] = result.first['count'] as int;
    }

    // Son 24 saat içindeki hatalar
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final recentErrors = await db.rawQuery(
      'SELECT COUNT(*) as count FROM senkron_errors WHERE timestamp > ?',
      [yesterday.toIso8601String()],
    );
    stats['recent_errors'] = recentErrors.first['count'] as int;

    // Çözülmemiş hatalar
    final unresolvedErrors = await db.rawQuery(
      'SELECT COUNT(*) as count FROM senkron_errors WHERE resolved = 0',
    );
    stats['unresolved_errors'] = unresolvedErrors.first['count'] as int;

    return stats;
  }

  /// Hatayı çözülmüş olarak işaretle
  Future<void> markErrorAsResolved(String errorId) async {
    final db = await _veriTabani.database;

    await db.update(
      'senkron_errors',
      {'resolved': 1},
      where: 'error_id = ?',
      whereArgs: [errorId],
    );
  }

  /// Eski hata kayıtlarını temizle (30 günden eski)
  Future<void> cleanOldErrors() async {
    final db = await _veriTabani.database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

    await db.delete(
      'senkron_errors',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }
}
