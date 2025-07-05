import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import '../utils/sabitler.dart';

/// Log servisi - uygulama genelinde loglama için
class LogServisi {
  static final LogServisi _instance = LogServisi._internal();
  static LogServisi get instance => _instance;
  LogServisi._internal();

  late Logger _logger;
  File? _logFile;
  bool _initialized = false;
  final List<LogEntry> _memoryLogs = [];

  /// Maksimum memory log sayısı (mobilde daha az)
  int get _maxMemoryLogs => Platform.isAndroid || Platform.isIOS ? 50 : 1000;

  /// Logging'in aktif olup olmadığını kontrol et (tüm platformlarda aktif)
  bool get _isLoggingEnabled => true;

  /// Log servisi başlat
  Future<void> init() async {
    if (_initialized) return;

    // Logger setup
    Logger.root.level = Level.ALL;
    _logger = Logger('ArsivApp');

    // Log file setup
    await _setupLogFile();

    // Listen to all log records
    Logger.root.onRecord.listen(_handleLogRecord);

    _initialized = true;

    info('📁 Log servisi başlatıldı');
  }

  /// Log dosyası ayarla
  Future<void> _setupLogFile() async {
    try {
      // Mobilde external storage directory kullan, PC'de documents directory
      final Directory documentsDir;
      if (Platform.isAndroid || Platform.isIOS) {
        documentsDir = await getApplicationDocumentsDirectory();
      } else {
        documentsDir = await getApplicationDocumentsDirectory();
      }

      final logDir = Directory(path.join(documentsDir.path, 'logs'));

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      _logFile = File(path.join(logDir.path, Sabitler.LOG_DOSYASI));

      // Check file size and rotate if necessary
      if (await _logFile!.exists()) {
        final fileSize = await _logFile!.length();
        if (fileSize > Sabitler.MAKSIMUM_LOG_BOYUTU) {
          await _rotateLogFile();
        }
      }
    } catch (e) {
      print('❌ Log dosyası ayarlanırken hata: $e');
    }
  }

  /// Log dosyasını döndür
  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath = _logFile!.path.replaceAll('.txt', '_$timestamp.txt');

      await _logFile!.rename(backupPath);

      // Create new log file
      _logFile = File(_logFile!.path);

      info('📁 Log dosyası döndürüldü: $backupPath');
    } catch (e) {
      print('❌ Log dosyası döndürülürken hata: $e');
    }
  }

  /// Log kaydını işle
  void _handleLogRecord(LogRecord record) {
    final formattedMessage = _formatLogMessage(record);

    // Console output
    print(formattedMessage);

    // Memory storage
    _addToMemoryLogs(
      LogEntry(
        timestamp: record.time,
        level: record.level,
        message: record.message,
        loggerName: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      ),
    );

    // File storage
    _writeToFile(formattedMessage);
  }

  /// Log mesajını formatla
  String _formatLogMessage(LogRecord record) {
    final timestamp = record.time.toIso8601String();
    final level = record.level.name.padRight(7);
    final logger = record.loggerName;
    final message = record.message;

    var formatted = '[$timestamp] [$level] [$logger] $message';

    if (record.error != null) {
      formatted += '\nError: ${record.error}';
    }

    if (record.stackTrace != null) {
      formatted += '\nStack trace:\n${record.stackTrace}';
    }

    return formatted;
  }

  /// Memory log'lara ekle
  void _addToMemoryLogs(LogEntry entry) {
    _memoryLogs.add(entry);

    // Keep only recent logs in memory
    if (_memoryLogs.length > _maxMemoryLogs) {
      // Mobilde daha agresif temizlik
      final removeCount =
          Platform.isAndroid || Platform.isIOS
              ? (_maxMemoryLogs * 0.3).round()
              : 1;

      for (int i = 0; i < removeCount && _memoryLogs.isNotEmpty; i++) {
        _memoryLogs.removeAt(0);
      }
    }
  }

  /// Dosyaya yaz
  Future<void> _writeToFile(String message) async {
    if (_logFile == null) return;

    try {
      // Mobilde dosya yazma işlemini sınırla (performans için)
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobilde sadece önemli log'ları dosyaya yaz
        if (message.contains('ERROR') ||
            message.contains('SEVERE') ||
            message.contains('SYNC:') ||
            message.contains('bağlandı')) {
          await _logFile!.writeAsString(
            '$message\n',
            mode: FileMode.append,
            flush: false, // Mobilde flush'ı kapatarak performance artır
          );
        }
      } else {
        // PC'de tüm log'ları yaz
        await _logFile!.writeAsString(
          '$message\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (e) {
      print('❌ Log dosyasına yazma hatası: $e');
    }
  }

  /// Debug log
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized || !_isLoggingEnabled) return;
    _logger.fine(message, error, stackTrace);
  }

  /// Info log
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized || !_isLoggingEnabled) return;
    _logger.info(message, error, stackTrace);
  }

  /// Warning log
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized || !_isLoggingEnabled) return;
    _logger.warning(message, error, stackTrace);
  }

  /// Error log
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_initialized || !_isLoggingEnabled) return;
    _logger.severe(message, error, stackTrace);
  }

  /// Sync operation log
  void syncLog(
    String operation,
    String status, [
    Map<String, dynamic>? details,
  ]) {
    if (!_isLoggingEnabled) return;
    final message = 'SYNC: $operation - $status';
    if (details != null) {
      info('$message\nDetails: ${json.encode(details)}');
    } else {
      info(message);
    }
  }

  /// Network operation log
  void networkLog(
    String endpoint,
    String method,
    int statusCode, [
    String? error,
  ]) {
    if (!_isLoggingEnabled) return;
    final message = 'NETWORK: $method $endpoint - Status: $statusCode';
    if (error != null) {
      this.error('$message\nError: $error');
    } else {
      info(message);
    }
  }

  /// File operation log
  void fileLog(String operation, String filePath, [String? error]) {
    if (!_isLoggingEnabled) return;
    final message = 'FILE: $operation - $filePath';
    if (error != null) {
      this.error('$message\nError: $error');
    } else {
      info(message);
    }
  }

  /// Database operation log
  void dbLog(String operation, String table, [Map<String, dynamic>? details]) {
    if (!_isLoggingEnabled) return;
    final message = 'DATABASE: $operation on $table';
    if (details != null) {
      info('$message\nDetails: ${json.encode(details)}');
    } else {
      info(message);
    }
  }

  /// Memory'deki log'ları al
  List<LogEntry> getMemoryLogs({Level? filterLevel}) {
    if (filterLevel == null) {
      return List.from(_memoryLogs);
    }

    return _memoryLogs
        .where((log) => log.level.value >= filterLevel.value)
        .toList();
  }

  /// Log dosyasını oku
  Future<String?> getLogFileContent() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return null;
    }

    try {
      return await _logFile!.readAsString();
    } catch (e) {
      error('Log dosyası okunamadı', e);
      return null;
    }
  }

  /// Log dosyalarını temizle
  Future<void> clearLogs() async {
    try {
      // Clear memory logs
      _memoryLogs.clear();

      // Clear log file
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }

      info('📁 Log dosyaları temizlendi');
    } catch (e) {
      error('Log temizleme hatası', e);
    }
  }

  /// Log istatistikleri
  Map<String, dynamic> getLogStats() {
    final stats = <String, int>{};

    for (final log in _memoryLogs) {
      final levelName = log.level.name;
      stats[levelName] = (stats[levelName] ?? 0) + 1;
    }

    return {
      'total_memory_logs': _memoryLogs.length,
      'log_file_path': _logFile?.path,
      'level_breakdown': stats,
      'initialized': _initialized,
    };
  }

  /// Export logs as JSON
  Future<String> exportLogsAsJson() async {
    final exportData = {
      'export_timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'logs': _memoryLogs.map((log) => log.toMap()).toList(),
      'stats': getLogStats(),
    };

    return json.encode(exportData);
  }

  /// Senkronizasyon ile ilgili son log'ları al
  Future<List<Map<String, dynamic>>> getRecentSyncLogs() async {
    try {
      final syncLogs =
          _memoryLogs
              .where(
                (log) =>
                    log.message.contains('SYNC:') ||
                    log.message.contains('senkronizasyon') ||
                    log.message.contains('bağlandı') ||
                    log.message.contains('bağlantı') ||
                    log.message.toLowerCase().contains('sync'),
              )
              .toList();

      // Mobilde daha az log al (performans için)
      final maxLogs = Platform.isAndroid || Platform.isIOS ? 5 : 10;
      final recentSyncLogs =
          syncLogs.length > maxLogs
              ? syncLogs.sublist(syncLogs.length - maxLogs)
              : syncLogs;

      return recentSyncLogs
          .map(
            (log) => {
              'mesaj': log.message,
              'zaman': log.timestamp.toIso8601String(),
              'seviye': log.level.name,
              'logger': log.loggerName,
              'hata': log.error?.toString(),
            },
          )
          .toList();
    } catch (e) {
      print('❌ Sync loglar alinirken hata: $e');
      return [];
    }
  }

  /// Log servisi kapat
  Future<void> dispose() async {
    if (!_initialized) return;

    info('📁 Log servisi kapatılıyor');
    _memoryLogs.clear();
    _logFile = null;
    _initialized = false;
  }
}

/// Log entry modeli
class LogEntry {
  final DateTime timestamp;
  final Level level;
  final String message;
  final String loggerName;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.loggerName,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'logger_name': loggerName,
      'error': error?.toString(),
      'stack_trace': stackTrace?.toString(),
    };
  }
}
