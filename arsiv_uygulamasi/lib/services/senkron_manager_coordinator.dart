import 'dart:async';
import 'senkron_manager_enhanced.dart';
import 'senkron_manager_working.dart';
import 'senkron_manager_simple.dart';
import '../models/senkron_cihazi.dart';

/// Senkronizasyon manager'ları arasında seçim ve koordinasyon
/// Bu sınıf hangi sync manager'ın kullanılacağını belirler ve
/// tüm sync işlemlerini tek noktadan yönetir.
class SenkronManagerCoordinator {
  static final SenkronManagerCoordinator _instance =
      SenkronManagerCoordinator._internal();
  static SenkronManagerCoordinator get instance => _instance;
  SenkronManagerCoordinator._internal();

  // ============== Sync Manager Türleri ==============
  final SenkronManagerEnhanced _enhancedManager = SenkronManagerEnhanced();
  final SenkronManagerWorking _workingManager = SenkronManagerWorking.instance;
  final SenkronManagerSimple _simpleManager = SenkronManagerSimple.instance;

  // ============== Varsayılan Ayarlar ==============
  SyncManagerType _currentType = SyncManagerType.working; // Güvenli başlangıç
  bool _autoFallback = true; // Hata durumunda otomatik geri dönüş

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

  /// Ana senkronizasyon metodu - seçilen manager'a göre işlem yapar
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

      // Auto fallback aktifse alternatif manager dene
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

  /// Belirli manager ile sync işlemini gerçekleştir
  Future<Map<String, dynamic>> _executeSyncWithManager(
    SyncManagerType managerType,
    SenkronCihazi targetDevice, {
    bool? bidirectional,
    String? strategy,
    DateTime? since,
  }) async {
    switch (managerType) {
      case SyncManagerType.enhanced:
        // Enhanced manager - gelişmiş özelliklerle
        return await _enhancedManager.performEnhancedSynchronization(
          targetDevice,
          bidirectional: bidirectional ?? true,
          strategy: strategy ?? 'LATEST_WINS',
          since: since,
        );

      case SyncManagerType.working:
        // Working manager - basit ve güvenilir
        final result = await _workingManager.performSynchronization(
          targetDevice,
        );
        return _convertIntResultToMap(result);

      case SyncManagerType.simple:
        // Simple manager - temel özelliklerle
        final result = await _simpleManager.performSynchronization(
          targetDevice,
        );
        return _convertIntResultToMap(result);
    }
  }

  /// Int sonuçları Map formatına dönüştür (uyumluluk için)
  Map<String, dynamic> _convertIntResultToMap(Map<String, int> result) {
    return {
      'success': true,
      'timestamp': DateTime.now().toIso8601String(),
      'statistics': {
        'downloadedDocuments': result['yeni'] ?? 0,
        'uploadedDocuments': result['gonderilen'] ?? 0,
        'updatedDocuments': result['guncellenen'] ?? 0,
        'conflictedDocuments': result['cakisma'] ?? 0,
        'erroredDocuments': result['hata'] ?? 0,
        'skippedDocuments': 0,
      },
      'managerType': _currentType.name,
    };
  }

  /// Callback'leri ayarla
  void _setupCallbacks() {
    switch (_currentType) {
      case SyncManagerType.enhanced:
        _enhancedManager.onProgressUpdate = onProgressUpdate;
        _enhancedManager.onOperationUpdate = onOperationUpdate;
        _enhancedManager.onLogMessage = onLogMessage;
        break;

      case SyncManagerType.working:
        _workingManager.onProgressUpdate = onProgressUpdate;
        _workingManager.onOperationUpdate = onOperationUpdate;
        _workingManager.onLogMessage = onLogMessage;
        break;

      case SyncManagerType.simple:
        _simpleManager.onProgressUpdate = onProgressUpdate;
        _simpleManager.onOperationUpdate = onOperationUpdate;
        _simpleManager.onLogMessage = onLogMessage;
        break;
    }
  }

  /// Manager özelliklerini getir
  Map<String, dynamic> getManagerCapabilities(SyncManagerType type) {
    switch (type) {
      case SyncManagerType.enhanced:
        return {
          'name': 'Enhanced Sync Manager',
          'features': [
            'Çift yönlü senkronizasyon',
            'Gelişmiş conflict resolution',
            'Network optimizasyonu',
            'Metadata sync',
            'Change tracking',
            'Progress tracking',
            'Integrity checking',
            'Delta synchronization',
          ],
          'complexity': 'Yüksek',
          'reliability': 'Yüksek',
          'performance': 'En Yüksek',
          'recommended': true,
        };

      case SyncManagerType.working:
        return {
          'name': 'Working Sync Manager',
          'features': [
            'Basit ve güvenilir',
            'Metadata sync',
            'Document sync',
            'Progress tracking',
            'Hızlı setup',
          ],
          'complexity': 'Düşük',
          'reliability': 'Çok Yüksek',
          'performance': 'Orta',
          'recommended': false,
        };

      case SyncManagerType.simple:
        return {
          'name': 'Simple Sync Manager',
          'features': [
            '3 aşamalı sync',
            'Temel validation',
            'Conflict detection',
            'Basic progress tracking',
          ],
          'complexity': 'Çok Düşük',
          'reliability': 'Yüksek',
          'performance': 'Düşük',
          'recommended': false,
        };
    }
  }

  /// Sync geçmişini getir
  Map<String, dynamic> getSyncHistory() {
    return {
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'lastUsedManager': _lastUsedManager?.displayName,
      'lastResult': _lastSyncResult,
      'currentManager': _currentType.displayName,
      'autoFallbackEnabled': _autoFallback,
    };
  }

  /// En uygun manager'ı öner
  SyncManagerType recommendBestManager({
    int? documentCount,
    bool? hasConflicts,
    bool? needsBidirectional,
    String? networkQuality,
  }) {
    // Çok fazla belge varsa Enhanced
    if (documentCount != null && documentCount > 100) {
      return SyncManagerType.enhanced;
    }

    // Conflict varsa Enhanced
    if (hasConflicts == true) {
      return SyncManagerType.enhanced;
    }

    // Çift yönlü sync gerekiyorsa Enhanced
    if (needsBidirectional == true) {
      return SyncManagerType.enhanced;
    }

    // Network kalitesi kötüyse Working (daha basit)
    if (networkQuality == 'poor' || networkQuality == 'bad') {
      return SyncManagerType.working;
    }

    // Varsayılan olarak Enhanced öner (en gelişmiş)
    return SyncManagerType.enhanced;
  }

  /// Performans istatistikleri
  Map<String, dynamic> getPerformanceStats() {
    final lastResult = _lastSyncResult;
    if (lastResult == null) {
      return {'hasData': false};
    }

    final stats = lastResult['statistics'] as Map<String, dynamic>? ?? {};
    return {
      'hasData': true,
      'lastManagerUsed': _lastUsedManager?.displayName,
      'lastSyncDuration':
          _lastSyncTime != null
              ? DateTime.now().difference(_lastSyncTime!).inMilliseconds
              : 0,
      'documentsProcessed':
          (stats['downloadedDocuments'] ?? 0) +
          (stats['uploadedDocuments'] ?? 0) +
          (stats['updatedDocuments'] ?? 0),
      'errorCount': stats['erroredDocuments'] ?? 0,
      'conflictCount': stats['conflictedDocuments'] ?? 0,
      'successRate': _calculateSuccessRate(stats),
    };
  }

  /// Başarı oranını hesapla
  double _calculateSuccessRate(Map<String, dynamic> stats) {
    final total =
        (stats['downloadedDocuments'] ?? 0) +
        (stats['uploadedDocuments'] ?? 0) +
        (stats['updatedDocuments'] ?? 0) +
        (stats['erroredDocuments'] ?? 0);

    if (total == 0) return 1.0;

    final successful = total - (stats['erroredDocuments'] ?? 0);
    return successful / total;
  }

  /// Test modu - tüm managerlari test et
  Future<Map<String, dynamic>> testAllManagers(
    SenkronCihazi targetDevice,
  ) async {
    _logMesaj('🧪 Tüm sync managerlar test ediliyor...');

    final results = <String, dynamic>{};

    for (final type in SyncManagerType.values) {
      _logMesaj('📊 ${type.displayName} test ediliyor...');

      try {
        final startTime = DateTime.now();
        final result = await _executeSyncWithManager(type, targetDevice);
        final duration = DateTime.now().difference(startTime);

        results[type.name] = {
          'success': true,
          'duration': duration.inMilliseconds,
          'result': result,
        };

        _logMesaj('✅ ${type.displayName} testi başarılı');
      } catch (e) {
        results[type.name] = {'success': false, 'error': e.toString()};

        _logMesaj('❌ ${type.displayName} testi başarısız: $e');
      }
    }

    _logMesaj('🎯 Tüm manager testleri tamamlandı');
    return results;
  }

  // ============== Getters ==============

  SyncManagerType get currentManagerType => _currentType;
  bool get autoFallbackEnabled => _autoFallback;
  Map<String, dynamic>? get lastSyncResult => _lastSyncResult;
  DateTime? get lastSyncTime => _lastSyncTime;

  // ============== Private Methods ==============

  void _logMesaj(String mesaj) {
    print('🎛️ SyncCoordinator: $mesaj');
    onLogMessage?.call(mesaj);
  }
}

/// Sync Manager türleri
enum SyncManagerType { enhanced, working, simple }

/// Sync Manager türü uzantıları
extension SyncManagerTypeExtension on SyncManagerType {
  String get displayName {
    switch (this) {
      case SyncManagerType.enhanced:
        return 'Enhanced Manager';
      case SyncManagerType.working:
        return 'Working Manager';
      case SyncManagerType.simple:
        return 'Simple Manager';
    }
  }

  String get description {
    switch (this) {
      case SyncManagerType.enhanced:
        return 'Gelişmiş özelliklerin hepsini içeren manager';
      case SyncManagerType.working:
        return 'Basit ve güvenilir çalışan manager';
      case SyncManagerType.simple:
        return 'En temel sync işlevleri';
    }
  }

  bool get isRecommended {
    return this == SyncManagerType.enhanced;
  }
}
