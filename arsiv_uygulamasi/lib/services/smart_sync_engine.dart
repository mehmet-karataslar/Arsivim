import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'sync_state_tracker.dart';
import 'file_version_manager.dart';
import 'document_change_tracker.dart';
import 'senkron_error_handler.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../utils/hash_comparator.dart';
import '../utils/timestamp_manager.dart';

/// Sync delta türleri
enum SyncDeltaType { create, update, delete, move, conflict, skip }

/// Sync operasyon önceliği
enum SyncPriority { high, medium, low }

/// Sync delta bilgisi
class SyncDelta {
  final String deltaId;
  final int belgeId;
  final SyncDeltaType type;
  final SyncPriority priority;
  final String sourceHash;
  final String targetHash;
  final Map<String, dynamic> metadata;
  final int estimatedSize;
  final DateTime timestamp;
  final List<String> dependencies;
  final Map<String, dynamic> changeDetails;

  SyncDelta({
    required this.deltaId,
    required this.belgeId,
    required this.type,
    required this.priority,
    required this.sourceHash,
    required this.targetHash,
    required this.metadata,
    required this.estimatedSize,
    required this.timestamp,
    this.dependencies = const [],
    this.changeDetails = const {},
  });

  Map<String, dynamic> toJson() => {
    'deltaId': deltaId,
    'belgeId': belgeId,
    'type': type.name,
    'priority': priority.name,
    'sourceHash': sourceHash,
    'targetHash': targetHash,
    'metadata': metadata,
    'estimatedSize': estimatedSize,
    'timestamp': timestamp.toIso8601String(),
    'dependencies': dependencies,
    'changeDetails': changeDetails,
  };
}

/// Sync planı
class SyncPlan {
  final String planId;
  final List<SyncDelta> deltas;
  final int totalSize;
  final Duration estimatedDuration;
  final Map<String, dynamic> statistics;
  final DateTime createdAt;

  SyncPlan({
    required this.planId,
    required this.deltas,
    required this.totalSize,
    required this.estimatedDuration,
    required this.statistics,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'deltas': deltas.map((d) => d.toJson()).toList(),
    'totalSize': totalSize,
    'estimatedDuration': estimatedDuration.inMilliseconds,
    'statistics': statistics,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Akıllı senkronizasyon motoru
class SmartSyncEngine {
  static final SmartSyncEngine _instance = SmartSyncEngine._internal();
  static SmartSyncEngine get instance => _instance;
  SmartSyncEngine._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final SyncStateTracker _syncStateTracker = SyncStateTracker.instance;
  final FileVersionManager _versionManager = FileVersionManager.instance;
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;
  final SenkronErrorHandler _errorHandler = SenkronErrorHandler.instance;
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  // Callbacks
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  /// Smart sync engine'i initialize et
  Future<void> initializeSmartSync() async {
    final db = await _veriTabani.database;

    // Sync deltas tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_deltas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delta_id TEXT NOT NULL UNIQUE,
        belge_id INTEGER NOT NULL,
        delta_type TEXT NOT NULL,
        priority TEXT NOT NULL,
        source_hash TEXT NOT NULL,
        target_hash TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        estimated_size INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        dependencies TEXT,
        change_details TEXT,
        status TEXT DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Sync plans tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT NOT NULL UNIQUE,
        total_size INTEGER NOT NULL,
        estimated_duration INTEGER NOT NULL,
        statistics TEXT NOT NULL,
        status TEXT DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        executed_at TEXT,
        completed_at TEXT
      )
    ''');

    // İndeksler
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_deltas_belge_id 
      ON sync_deltas(belge_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_deltas_type 
      ON sync_deltas(delta_type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_deltas_priority 
      ON sync_deltas(priority)
    ''');

    print('🧠 SmartSyncEngine initialized');
  }

  /// Değişen dosyaları tespit et
  Future<List<BelgeModeli>> identifyChangedFiles(
    SenkronCihazi targetDevice, {
    DateTime? since,
    Map<String, dynamic>? remoteManifest,
  }) async {
    _logMessage('🔍 Değişen dosyalar tespit ediliyor...');

    final changedFiles = <BelgeModeli>[];
    final db = await _veriTabani.database;

    // Yerel belgeler
    final localDocuments = await db.query('belgeler');

    for (final docData in localDocuments) {
      final belge = BelgeModeli.fromMap(docData);

      // Zaman filtresi
      if (since != null) {
        final guncellemeTarihi = belge.guncellemeTarihi;

        if (guncellemeTarihi.isBefore(since)) {
          continue;
        }
      }

      // Remote manifest ile karşılaştır
      if (remoteManifest != null) {
        final remoteFile = remoteManifest['files']?[belge.dosyaHash];

        if (remoteFile != null) {
          final remoteMetadataHash = remoteFile['metadata_hash'];
          final remoteContentHash = remoteFile['content_hash'];

          // Sync gerekli mi kontrol et
          final shouldSync = await _syncStateTracker.shouldSync(
            belge,
            targetDevice.id,
            remoteMetadataHash: remoteMetadataHash,
            remoteContentHash: remoteContentHash,
          );

          if (shouldSync) {
            changedFiles.add(belge);
          }
        } else {
          // Remote'da yok, yeni dosya
          changedFiles.add(belge);
        }
      } else {
        // Manifest yok, tüm dosyaları kontrol et
        final shouldSync = await _syncStateTracker.shouldSync(
          belge,
          targetDevice.id,
        );

        if (shouldSync) {
          changedFiles.add(belge);
        }
      }
    }

    _logMessage('📋 ${changedFiles.length} değişen dosya tespit edildi');
    return changedFiles;
  }

  /// Sync delta'larını hesapla
  Future<List<SyncDelta>> calculateSyncDelta(
    List<BelgeModeli> changedFiles,
    SenkronCihazi targetDevice, {
    Map<String, dynamic>? remoteManifest,
  }) async {
    _logMessage('⚙️ Sync deltaları hesaplanıyor...');

    final deltas = <SyncDelta>[];
    final now = DateTime.now();

    for (final belge in changedFiles) {
      final deltaId = 'delta_${belge.id}_${now.millisecondsSinceEpoch}';

      // Delta tipini belirle
      final deltaType = await _determineDeltaType(belge, remoteManifest);

      // Önceliği belirle
      final priority = _determinePriority(belge, deltaType);

      // Hash'leri hesapla
      final sourceHash = belge.dosyaHash;
      final targetHash = await _calculateTargetHash(belge, deltaType);

      // Metadata'yı hazırla
      final metadata = {
        'baslik': belge.baslik,
        'dosya_adi': belge.dosyaAdi,
        'dosya_tipi': belge.dosyaTipi,
        'kategori_id': belge.kategoriId,
        'kisi_id': belge.kisiId,
      };

      // Boyutu tahmin et
      final estimatedSize = await _estimateTransferSize(belge, deltaType);

      // Değişiklik detaylarını al
      final changeDetails = await _getChangeDetails(belge, deltaType);

      // Bağımlılıkları belirle
      final dependencies = await _identifyDependencies(belge);

      final delta = SyncDelta(
        deltaId: deltaId,
        belgeId: belge.id!,
        type: deltaType,
        priority: priority,
        sourceHash: sourceHash,
        targetHash: targetHash,
        metadata: metadata,
        estimatedSize: estimatedSize,
        timestamp: now,
        dependencies: dependencies,
        changeDetails: changeDetails,
      );

      deltas.add(delta);
    }

    // Delta'ları optimize et
    final optimizedDeltas = await _optimizeDeltas(deltas);

    _logMessage('✅ ${optimizedDeltas.length} sync delta hesaplandı');
    return optimizedDeltas;
  }

  /// Incremental sync uygula
  Future<Map<String, dynamic>> applyIncrementalSync(
    SyncPlan plan,
    SenkronCihazi targetDevice, {
    bool dryRun = false,
  }) async {
    _logMessage('🚀 Incremental sync uygulanıyor...');

    final results = <String, dynamic>{
      'plan_id': plan.planId,
      'total_deltas': plan.deltas.length,
      'successful_deltas': 0,
      'failed_deltas': 0,
      'skipped_deltas': 0,
      'transferred_bytes': 0,
      'errors': <Map<String, dynamic>>[],
      'dry_run': dryRun,
    };

    // Plan'ı kaydet
    await _saveSyncPlan(plan);

    // Delta'ları öncelik sırasına göre sırala
    final sortedDeltas = _sortDeltasByPriority(plan.deltas);

    for (int i = 0; i < sortedDeltas.length; i++) {
      final delta = sortedDeltas[i];
      final progress = (i + 1) / sortedDeltas.length;

      onProgressUpdate?.call(progress);
      onOperationUpdate?.call('Delta işleniyor: ${delta.type.name}');

      try {
        if (dryRun) {
          _logMessage(
            '🔍 Dry run: ${delta.type.name} - ${delta.metadata['baslik']}',
          );
          results['successful_deltas']++;
        } else {
          final deltaResult = await _applyDelta(delta, targetDevice);

          if (deltaResult['success']) {
            results['successful_deltas']++;
            results['transferred_bytes'] +=
                deltaResult['bytes_transferred'] ?? 0;

            // Sync state'i güncelle
            await _updateSyncStateFromDelta(delta, targetDevice);
          } else {
            results['failed_deltas']++;
            results['errors'].add({
              'delta_id': delta.deltaId,
              'error': deltaResult['error'],
            });
          }
        }
      } catch (e, stackTrace) {
        _logMessage('❌ Delta uygulama hatası: $e');

        // Error handler ile işle
        final errorInfo = _errorHandler.categorizeError(
          e,
          stackTrace: stackTrace,
          context: {
            'operation': 'apply_delta',
            'delta_type': delta.type.name,
            'belge_id': delta.belgeId,
          },
        );

        await _errorHandler.logDetailedError(errorInfo);

        results['failed_deltas']++;
        results['errors'].add({
          'delta_id': delta.deltaId,
          'error': e.toString(),
        });
      }
    }

    final successRate = results['successful_deltas'] / results['total_deltas'];
    results['success_rate'] = successRate;

    _logMessage(
      '✅ Incremental sync tamamlandı - Başarı oranı: ${(successRate * 100).toStringAsFixed(1)}%',
    );

    return results;
  }

  /// Sync planı oluştur
  Future<SyncPlan> createSyncPlan(
    List<SyncDelta> deltas, {
    String? planName,
  }) async {
    final planId = planName ?? 'plan_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // Toplam boyut hesapla
    final totalSize = deltas.fold<int>(
      0,
      (sum, delta) => sum + delta.estimatedSize,
    );

    // Süre tahmini (ortalama 1MB/saniye)
    final estimatedDuration = Duration(
      seconds: (totalSize / 1024 / 1024).ceil(),
    );

    // İstatistikler
    final statistics = {
      'total_deltas': deltas.length,
      'create_count':
          deltas.where((d) => d.type == SyncDeltaType.create).length,
      'update_count':
          deltas.where((d) => d.type == SyncDeltaType.update).length,
      'delete_count':
          deltas.where((d) => d.type == SyncDeltaType.delete).length,
      'high_priority_count':
          deltas.where((d) => d.priority == SyncPriority.high).length,
      'medium_priority_count':
          deltas.where((d) => d.priority == SyncPriority.medium).length,
      'low_priority_count':
          deltas.where((d) => d.priority == SyncPriority.low).length,
    };

    return SyncPlan(
      planId: planId,
      deltas: deltas,
      totalSize: totalSize,
      estimatedDuration: estimatedDuration,
      statistics: statistics,
      createdAt: now,
    );
  }

  /// Delta tipini belirle
  Future<SyncDeltaType> _determineDeltaType(
    BelgeModeli belge,
    Map<String, dynamic>? remoteManifest,
  ) async {
    if (remoteManifest == null) {
      return SyncDeltaType.create;
    }

    final remoteFile = remoteManifest['files']?[belge.dosyaHash];

    if (remoteFile == null) {
      return SyncDeltaType.create;
    }

    // Version karşılaştırması
    final latestSnapshot = await _versionManager.getLatestSnapshot(belge.id!);
    if (latestSnapshot != null) {
      final remoteVersion = remoteFile['version'] ?? 1;
      if (latestSnapshot.versionNumber > remoteVersion) {
        return SyncDeltaType.update;
      }
    }

    return SyncDeltaType.update;
  }

  /// Öncelik belirle
  SyncPriority _determinePriority(BelgeModeli belge, SyncDeltaType deltaType) {
    // Yeni dosyalar yüksek öncelikli
    if (deltaType == SyncDeltaType.create) {
      return SyncPriority.high;
    }

    // Büyük dosyalar düşük öncelikli
    if ((belge.dosyaBoyutu ?? 0) > 10 * 1024 * 1024) {
      return SyncPriority.low;
    }

    // Son güncellemeler yüksek öncelikli
    final updateTime = belge.guncellemeTarihi;
    if (DateTime.now().difference(updateTime).inDays < 1) {
      return SyncPriority.high;
    }

    return SyncPriority.medium;
  }

  /// Hedef hash hesapla
  Future<String> _calculateTargetHash(
    BelgeModeli belge,
    SyncDeltaType deltaType,
  ) async {
    switch (deltaType) {
      case SyncDeltaType.create:
      case SyncDeltaType.update:
        return belge.dosyaHash;
      case SyncDeltaType.delete:
        return '';
      default:
        return belge.dosyaHash;
    }
  }

  /// Transfer boyutu tahmin et
  Future<int> _estimateTransferSize(
    BelgeModeli belge,
    SyncDeltaType deltaType,
  ) async {
    switch (deltaType) {
      case SyncDeltaType.create:
        return belge.dosyaBoyutu ?? 0;
      case SyncDeltaType.update:
        // Incremental update için yaklaşık %30 boyut
        return ((belge.dosyaBoyutu ?? 0) * 0.3).round();
      case SyncDeltaType.delete:
        return 0;
      default:
        return belge.dosyaBoyutu ?? 0;
    }
  }

  /// Değişiklik detaylarını al
  Future<Map<String, dynamic>> _getChangeDetails(
    BelgeModeli belge,
    SyncDeltaType deltaType,
  ) async {
    final changes = <String, dynamic>{
      'type': deltaType.name,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Version manager'dan son değişiklikleri al
    final latestSnapshot = await _versionManager.getLatestSnapshot(belge.id!);
    if (latestSnapshot != null) {
      changes['version'] = latestSnapshot.versionNumber;
      changes['snapshot_id'] = latestSnapshot.snapshotId;
    }

    return changes;
  }

  /// Bağımlılıkları belirle
  Future<List<String>> _identifyDependencies(BelgeModeli belge) async {
    final dependencies = <String>[];

    // Kategori bağımlılığı
    if (belge.kategoriId != null) {
      dependencies.add('kategori_${belge.kategoriId}');
    }

    // Kişi bağımlılığı
    if (belge.kisiId != null) {
      dependencies.add('kisi_${belge.kisiId}');
    }

    return dependencies;
  }

  /// Delta'ları optimize et
  Future<List<SyncDelta>> _optimizeDeltas(List<SyncDelta> deltas) async {
    // Duplicate'leri kaldır
    final Map<int, SyncDelta> deltaMap = {};
    for (final delta in deltas) {
      final existing = deltaMap[delta.belgeId];
      if (existing == null || delta.priority.index < existing.priority.index) {
        deltaMap[delta.belgeId] = delta;
      }
    }

    // Batch operations için grupla
    final optimizedDeltas = deltaMap.values.toList();

    // Öncelik sırasına göre sırala
    optimizedDeltas.sort(
      (a, b) => a.priority.index.compareTo(b.priority.index),
    );

    return optimizedDeltas;
  }

  /// Delta'ları öncelik sırasına göre sırala
  List<SyncDelta> _sortDeltasByPriority(List<SyncDelta> deltas) {
    final sorted = List<SyncDelta>.from(deltas);
    sorted.sort((a, b) {
      // Önce öncelik
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      // Sonra boyut (küçükten büyüğe)
      return a.estimatedSize.compareTo(b.estimatedSize);
    });
    return sorted;
  }

  /// Sync planını kaydet
  Future<void> _saveSyncPlan(SyncPlan plan) async {
    final db = await _veriTabani.database;

    await db.insert('sync_plans', {
      'plan_id': plan.planId,
      'total_size': plan.totalSize,
      'estimated_duration': plan.estimatedDuration.inMilliseconds,
      'statistics': json.encode(plan.statistics),
      'status': 'EXECUTING',
      'created_at': plan.createdAt.toIso8601String(),
    });

    // Delta'ları kaydet
    for (final delta in plan.deltas) {
      await db.insert('sync_deltas', {
        'delta_id': delta.deltaId,
        'belge_id': delta.belgeId,
        'delta_type': delta.type.name,
        'priority': delta.priority.name,
        'source_hash': delta.sourceHash,
        'target_hash': delta.targetHash,
        'metadata_json': json.encode(delta.metadata),
        'estimated_size': delta.estimatedSize,
        'timestamp': delta.timestamp.toIso8601String(),
        'dependencies': json.encode(delta.dependencies),
        'change_details': json.encode(delta.changeDetails),
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Delta'yı uygula
  Future<Map<String, dynamic>> _applyDelta(
    SyncDelta delta,
    SenkronCihazi targetDevice,
  ) async {
    switch (delta.type) {
      case SyncDeltaType.create:
        return await _applyCreateDelta(delta, targetDevice);
      case SyncDeltaType.update:
        return await _applyUpdateDelta(delta, targetDevice);
      case SyncDeltaType.delete:
        return await _applyDeleteDelta(delta, targetDevice);
      default:
        return {'success': false, 'error': 'Unsupported delta type'};
    }
  }

  /// Create delta'yı uygula
  Future<Map<String, dynamic>> _applyCreateDelta(
    SyncDelta delta,
    SenkronCihazi targetDevice,
  ) async {
    // Dosyayı upload et
    final belge = await _getBelgeById(delta.belgeId);
    if (belge == null) {
      return {'success': false, 'error': 'Belge bulunamadı'};
    }

    // Dosya transferi (simulate)
    final bytesTransferred = delta.estimatedSize;

    return {
      'success': true,
      'bytes_transferred': bytesTransferred,
      'operation': 'create',
    };
  }

  /// Update delta'yı uygula
  Future<Map<String, dynamic>> _applyUpdateDelta(
    SyncDelta delta,
    SenkronCihazi targetDevice,
  ) async {
    // Incremental update (simulate)
    final bytesTransferred = delta.estimatedSize;

    return {
      'success': true,
      'bytes_transferred': bytesTransferred,
      'operation': 'update',
    };
  }

  /// Delete delta'yı uygula
  Future<Map<String, dynamic>> _applyDeleteDelta(
    SyncDelta delta,
    SenkronCihazi targetDevice,
  ) async {
    // Delete operation (simulate)
    return {'success': true, 'bytes_transferred': 0, 'operation': 'delete'};
  }

  /// Sync state'i delta'dan güncelle
  Future<void> _updateSyncStateFromDelta(
    SyncDelta delta,
    SenkronCihazi targetDevice,
  ) async {
    await _syncStateTracker.markAsSynced(
      delta.sourceHash,
      delta.metadata['dosya_adi'] ?? '',
      targetDevice.id,
      null,
      metadataHash: delta.targetHash,
      syncDirection: 'UPLOAD',
    );
  }

  /// Belge ID'sine göre belge al
  Future<BelgeModeli?> _getBelgeById(int belgeId) async {
    final db = await _veriTabani.database;
    final result = await db.query(
      'belgeler',
      where: 'id = ?',
      whereArgs: [belgeId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return BelgeModeli.fromMap(result.first);
  }

  /// Log mesajı
  void _logMessage(String message) {
    print('🧠 SmartSyncEngine: $message');
    onLogMessage?.call(message);
  }
}
