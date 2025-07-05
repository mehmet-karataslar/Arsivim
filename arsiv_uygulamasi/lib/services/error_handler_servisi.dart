import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'log_servisi.dart';

/// Hata yönetimi servisi - uygulama genelinde hata yakalama ve işleme
class ErrorHandlerServisi {
  static final ErrorHandlerServisi _instance = ErrorHandlerServisi._internal();
  static ErrorHandlerServisi get instance => _instance;
  ErrorHandlerServisi._internal();

  late LogServisi _logServisi;
  bool _initialized = false;

  // Error statistics
  int _totalErrors = 0;
  int _handledErrors = 0;
  int _criticalErrors = 0;
  final Map<String, int> _errorTypes = {};
  final List<AppError> _recentErrors = [];
  static const int _maxRecentErrors = 50;

  /// Error handler servisini başlat
  Future<void> init() async {
    if (_initialized) return;

    _logServisi = LogServisi.instance;

    // Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Platform dispatcher error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };

    // Zone error handler for async errors
    runZonedGuarded(
      () {
        // This will catch async errors
      },
      (error, stack) {
        _handleZoneError(error, stack);
      },
    );

    _initialized = true;
    _logServisi.info('🚨 Error handler servisi başlatıldı');
  }

  /// Flutter widget hatasını işle
  void _handleFlutterError(FlutterErrorDetails details) {
    _totalErrors++;

    final error = AppError(
      type: ErrorType.widget,
      message: details.exception.toString(),
      stackTrace: details.stack,
      timestamp: DateTime.now(),
      context: details.context?.toString(),
      library: details.library,
      fatal: false,
    );

    _logError(error);
    _trackError(error);

    // Original Flutter error handling
    FlutterError.presentError(details);
  }

  /// Platform hatasını işle
  bool _handlePlatformError(Object error, StackTrace stack) {
    _totalErrors++;

    final appError = AppError(
      type: ErrorType.platform,
      message: error.toString(),
      stackTrace: stack,
      timestamp: DateTime.now(),
      fatal: _isCriticalError(error),
    );

    _logError(appError);
    _trackError(appError);

    return true;
  }

  /// Zone hatasını işle
  void _handleZoneError(Object error, StackTrace stack) {
    _totalErrors++;

    final appError = AppError(
      type: ErrorType.async,
      message: error.toString(),
      stackTrace: stack,
      timestamp: DateTime.now(),
      fatal: _isCriticalError(error),
    );

    _logError(appError);
    _trackError(appError);
  }

  /// Manuel hata işleme
  void handleError(
    Object error, [
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
  ]) {
    _totalErrors++;
    _handledErrors++;

    final appError = AppError(
      type: ErrorType.manual,
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: context,
      severity: severity,
      fatal: severity == ErrorSeverity.critical,
    );

    _logError(appError);
    _trackError(appError);
  }

  /// Network hatasını işle
  void handleNetworkError(
    Object error, [
    StackTrace? stackTrace,
    String? endpoint,
    int? statusCode,
  ]) {
    _totalErrors++;
    _handledErrors++;

    final appError = AppError(
      type: ErrorType.network,
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: endpoint,
      metadata: {'status_code': statusCode, 'endpoint': endpoint},
      severity: _getNetworkErrorSeverity(statusCode),
    );

    _logError(appError);
    _trackError(appError);
  }

  /// Database hatasını işle
  void handleDatabaseError(
    Object error, [
    StackTrace? stackTrace,
    String? operation,
    String? table,
  ]) {
    _totalErrors++;
    _handledErrors++;

    final appError = AppError(
      type: ErrorType.database,
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: operation,
      metadata: {'operation': operation, 'table': table},
      severity: ErrorSeverity.high,
      fatal: false,
    );

    _logError(appError);
    _trackError(appError);
  }

  /// File hatasını işle
  void handleFileError(
    Object error, [
    StackTrace? stackTrace,
    String? filePath,
    String? operation,
  ]) {
    _totalErrors++;
    _handledErrors++;

    final appError = AppError(
      type: ErrorType.file,
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: operation,
      metadata: {'file_path': filePath, 'operation': operation},
      severity: ErrorSeverity.medium,
    );

    _logError(appError);
    _trackError(appError);
  }

  /// Sync hatasını işle
  void handleSyncError(
    Object error, [
    StackTrace? stackTrace,
    String? operation,
    Map<String, dynamic>? syncData,
  ]) {
    _totalErrors++;
    _handledErrors++;

    final appError = AppError(
      type: ErrorType.sync,
      message: error.toString(),
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      context: operation,
      metadata: syncData,
      severity: ErrorSeverity.high,
    );

    _logError(appError);
    _trackError(appError);
  }

  /// Hatayı loglaya
  void _logError(AppError error) {
    switch (error.severity) {
      case ErrorSeverity.low:
        _logServisi.debug(
          '🟡 ${error.type.name.toUpperCase()}: ${error.message}',
          error,
          error.stackTrace,
        );
        break;
      case ErrorSeverity.medium:
        _logServisi.warning(
          '🟠 ${error.type.name.toUpperCase()}: ${error.message}',
          error,
          error.stackTrace,
        );
        break;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        _logServisi.error(
          '🔴 ${error.type.name.toUpperCase()}: ${error.message}',
          error,
          error.stackTrace,
        );
        break;
    }

    // Context bilgisi varsa ekle
    if (error.context != null) {
      _logServisi.info('📍 Context: ${error.context}');
    }

    // Metadata varsa ekle
    if (error.metadata != null) {
      _logServisi.info('📊 Metadata: ${error.metadata}');
    }
  }

  /// Error istatistiklerini güncelle
  void _trackError(AppError error) {
    // Error type tracking
    final typeName = error.type.name;
    _errorTypes[typeName] = (_errorTypes[typeName] ?? 0) + 1;

    // Critical error tracking
    if (error.fatal || error.severity == ErrorSeverity.critical) {
      _criticalErrors++;
    }

    // Recent errors tracking
    _recentErrors.add(error);
    if (_recentErrors.length > _maxRecentErrors) {
      _recentErrors.removeAt(0);
    }
  }

  /// Kritik hata kontrolü
  bool _isCriticalError(Object error) {
    if (error is OutOfMemoryError) return true;
    if (error is StackOverflowError) return true;
    if (error.toString().toLowerCase().contains('fatal')) return true;
    return false;
  }

  /// Network error severity belirleme
  ErrorSeverity _getNetworkErrorSeverity(int? statusCode) {
    if (statusCode == null) return ErrorSeverity.medium;

    if (statusCode >= 500) return ErrorSeverity.high;
    if (statusCode >= 400) return ErrorSeverity.medium;
    return ErrorSeverity.low;
  }

  /// UI'ya hata göster
  void showErrorToUser(
    BuildContext context,
    Object error, [
    String? userMessage,
    VoidCallback? onRetry,
  ]) {
    final message = userMessage ?? _getUserFriendlyMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Tekrar Dene',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Kullanıcı dostu hata mesajı
  String _getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('socket')) {
      return 'İnternet bağlantısı sorunu. Lütfen bağlantınızı kontrol edin.';
    }

    if (errorString.contains('permission')) {
      return 'İzin hatası. Lütfen uygulama izinlerini kontrol edin.';
    }

    if (errorString.contains('file') || errorString.contains('path')) {
      return 'Dosya işlemi hatası. Lütfen tekrar deneyin.';
    }

    if (errorString.contains('database') || errorString.contains('sql')) {
      return 'Veritabanı hatası. Lütfen uygulamayı yeniden başlatın.';
    }

    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  /// Error istatistikleri
  Map<String, dynamic> getErrorStats() {
    return {
      'total_errors': _totalErrors,
      'handled_errors': _handledErrors,
      'critical_errors': _criticalErrors,
      'error_types': Map.from(_errorTypes),
      'recent_errors_count': _recentErrors.length,
      'error_rate':
          _totalErrors > 0
              ? (_handledErrors / _totalErrors * 100).toStringAsFixed(2)
              : '0.00',
    };
  }

  /// Son hataları al
  List<AppError> getRecentErrors({ErrorSeverity? minSeverity}) {
    if (minSeverity == null) {
      return List.from(_recentErrors);
    }

    return _recentErrors.where((error) {
      return error.severity.index >= minSeverity.index;
    }).toList();
  }

  /// Error istatistiklerini temizle
  void clearErrorStats() {
    _totalErrors = 0;
    _handledErrors = 0;
    _criticalErrors = 0;
    _errorTypes.clear();
    _recentErrors.clear();

    _logServisi.info('🚨 Error istatistikleri temizlendi');
  }

  /// Error handler servisi kapat
  void dispose() {
    _recentErrors.clear();
    _errorTypes.clear();
    _initialized = false;

    _logServisi.info('🚨 Error handler servisi kapatıldı');
  }
}

/// Uygulama hata modeli
class AppError {
  final ErrorType type;
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? context;
  final String? library;
  final Map<String, dynamic>? metadata;
  final ErrorSeverity severity;
  final bool fatal;

  AppError({
    required this.type,
    required this.message,
    this.stackTrace,
    required this.timestamp,
    this.context,
    this.library,
    this.metadata,
    this.severity = ErrorSeverity.medium,
    this.fatal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
      'library': library,
      'metadata': metadata,
      'severity': severity.name,
      'fatal': fatal,
      'stack_trace': stackTrace?.toString(),
    };
  }

  @override
  String toString() {
    return 'AppError(${type.name}: $message)';
  }
}

/// Error türleri
enum ErrorType {
  widget,
  platform,
  async,
  network,
  database,
  file,
  sync,
  manual,
}

/// Error şiddet seviyeleri
enum ErrorSeverity { low, medium, high, critical }
