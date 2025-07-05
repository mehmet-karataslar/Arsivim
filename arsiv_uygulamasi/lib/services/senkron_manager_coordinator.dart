import 'dart:async';
import 'senkron_manager_enhanced.dart';
import 'senkron_manager_working.dart';
import 'senkron_manager_simple.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'metadata_sync_manager.dart';
import 'senkron_error_handler.dart';
import '../models/senkron_cihazi.dart';

/// SADELEŞTİRİLMİŞ Senkronizasyon Koordinatörü
/// Enhanced Manager odaklı - Gereksiz karmaşıklık temizlendi
class SenkronManagerCoordinator {
  static final SenkronManagerCoordinator _instance =
      SenkronManagerCoordinator._internal();
  static SenkronManagerCoordinator get instance => _instance;

  SenkronManagerCoordinator._internal() {
    // Enhanced manager'ı initialize et - Sadeleştirilmiş
    _enhancedManager = SenkronManagerEnhanced(
      VeriTabaniServisi(),
      DosyaServisi(),
      MetadataSyncManager.instance,
    );

    // Error handler'ı initialize et
    _initializeErrorHandler();
  }

  // ============== Sync Manager'lar ==============
  late final SenkronManagerEnhanced _enhancedManager;
  final SenkronManagerWorking _workingManager = SenkronManagerWorking.instance;
  final SenkronManagerSimple _simpleManager = SenkronManagerSimple.instance;
  final SenkronErrorHandler _errorHandler = SenkronErrorHandler.instance;

  // ============== Ayarlar ==============
  SyncManagerType _currentType = SyncManagerType.enhanced; // Enhanced default
  bool _autoFallback = true;

  // ============== Progress Tracking ==============
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  // ============== Son Sync Sonuçları ==============
  Map<String, dynamic>? _lastSyncResult;
  DateTime? _lastSyncTime;
  SyncManagerType? _lastUsedManager;

  /// Aktif sync manager tipini ayarla
  void setSyncManagerType(SyncManagerType type) {
    _currentType = type;
    _logMesaj('🔄 Sync Manager değiştirildi: ${type.displayName}');
    _setupCallbacks();
  }

  /// Auto fallback'i aç/kapat
  void setAutoFallback(bool enabled) {
    _autoFallback = enabled;
    _logMesaj('🔄 Auto fallback: ${enabled ? "Açık" : "Kapalı"}');
  }

  /// Ana senkronizasyon metodu - Sadeleştirilmiş
  Future<Map<String, dynamic>> performSynchronization(
    SenkronCihazi targetDevice, {
    bool? bidirectional,
    String? strategy,
    DateTime? since,
  }) async {
    _logMesaj('🚀 Koordineli senkronizasyon başlatılıyor...');
    _logMesaj('📱 Manager: ${_currentType.displayName}');
    _logMesaj('🔗 Cihaz: ${targetDevice.ad} (${targetDevice.ip})');

    try {
      // Seçilen manager ile sync yap
      final result = await _executeSyncWithManager(
        _currentType,
        targetDevice,
        bidirectional: bidirectional,
        strategy: strategy,
        since: since,
      );

      // Başarılı sonucu kaydet
      _lastSyncResult = result;
      _lastSyncTime = DateTime.now();
      _lastUsedManager = _currentType;

      _logMesaj('✅ Senkronizasyon başarıyla tamamlandı!');
      return result;
    } catch (e) {
      _logMesaj('❌ ${_currentType.displayName} ile sync hatası: $e');

      // Auto fallback aktifse Working Manager dene
      if (_autoFallback && _currentType != SyncManagerType.working) {
        _logMesaj('🔄 Auto fallback aktif - Working Manager deneniyor...');

        try {
          final fallbackResult = await _executeSyncWithManager(
            SyncManagerType.working,
            targetDevice,
            bidirectional: bidirectional,
            strategy: strategy,
            since: since,
          );

          _lastSyncResult = fallbackResult;
          _lastSyncTime = DateTime.now();
          _lastUsedManager = SyncManagerType.working;

          _logMesaj('✅ Fallback ile sync başarılı!');
          return fallbackResult;
        } catch (fallbackError) {
          _logMesaj('❌ Fallback de başarısız: $fallbackError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Manager ile sync yap - Sadeleştirilmiş
  Future<Map<String, dynamic>> _executeSyncWithManager(
    SyncManagerType type,
    SenkronCihazi targetDevice, {
    bool? bidirectional,
    String? strategy,
    DateTime? since,
  }) async {
    _logMesaj('🔧 ${type.displayName} ile sync başlatılıyor...');

    switch (type) {
      case SyncManagerType.enhanced:
        return await _enhancedManager.performFullSync(
          targetDevice,
          bidirectional: bidirectional ?? true,
          conflictStrategy: strategy ?? 'LATEST_WINS',
          syncMetadata: true,
          useDeltaSync: false, // Delta sync devre dışı
          since: since,
        );

      case SyncManagerType.working:
        final result = await _workingManager.performSynchronization(
          targetDevice,
        );
        return _normalizeResult(result, 'Working Manager');

      case SyncManagerType.simple:
        final result = await _simpleManager.performSynchronization(
          targetDevice,
        );
        return _normalizeResult(result, 'Simple Manager');

      default:
        throw Exception('Desteklenmeyen sync manager tipi: $type');
    }
  }

  /// Callback'leri ayarla
  void _setupCallbacks() {
    _enhancedManager.setCallbacks(
      onLog: onLogMessage,
      onProgress: onProgressUpdate,
      onStatus: onOperationUpdate,
    );

    _workingManager.onProgressUpdate = onProgressUpdate;
    _workingManager.onOperationUpdate = onOperationUpdate;
    _workingManager.onLogMessage = onLogMessage;

    _simpleManager.onProgressUpdate = onProgressUpdate;
    _simpleManager.onOperationUpdate = onOperationUpdate;
    _simpleManager.onLogMessage = onLogMessage;
  }

  /// Error handler'ı initialize et
  void _initializeErrorHandler() {
    try {
      // Error handler için özel initialization gerekmiyor
      _logMesaj('✅ Error handler başarıyla initialize edildi');
    } catch (e) {
      _logMesaj('⚠️ Error handler initialize hatası: $e');
    }
  }

  /// Sonucu normalize et
  Map<String, dynamic> _normalizeResult(
    Map<String, dynamic> result,
    String managerName,
  ) {
    return {
      'success': result['success'] ?? false,
      'manager': managerName,
      'totalDocuments': result['totalDocuments'] ?? result['total'] ?? 0,
      'uploaded': result['uploaded'] ?? 0,
      'downloaded': result['downloaded'] ?? 0,
      'skipped': result['skipped'] ?? 0,
      'errors': result['errors'] ?? 0,
      'metadata': result['metadata'],
      'documents': result['documents'],
      'rawResult': result,
    };
  }

  /// Log mesajı
  void _logMesaj(String message) {
    onLogMessage?.call(message);
    print(message);
  }

  // ============== Getter'lar ==============
  Map<String, dynamic>? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSyncTime => _lastSyncTime;
  SyncManagerType? get lastUsedManager => _lastUsedManager;
  SyncManagerType get currentManager => _currentType;
  bool get autoFallbackEnabled => _autoFallback;

  /// Stats al
  Map<String, dynamic> get coordinatorStats => {
    'currentManager': _currentType.displayName,
    'autoFallback': _autoFallback,
    'lastSyncTime': _lastSyncTime?.toIso8601String(),
    'lastUsedManager': _lastUsedManager?.displayName,
    'lastSyncSuccess': _lastSyncResult?['success'] ?? false,
  };
}

/// Sync Manager Tipleri - Sadeleştirilmiş
enum SyncManagerType { enhanced, working, simple }

extension SyncManagerTypeExtension on SyncManagerType {
  String get displayName {
    switch (this) {
      case SyncManagerType.enhanced:
        return 'Gelişmiş Yönetici';
      case SyncManagerType.working:
        return 'Çalışan Yönetici';
      case SyncManagerType.simple:
        return 'Basit Yönetici';
    }
  }
}
