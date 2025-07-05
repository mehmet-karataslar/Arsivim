import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'sync_state_tracker.dart';
import 'file_version_manager.dart';
import 'smart_sync_engine.dart';
import 'senkron_error_handler.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../utils/hash_comparator.dart';
import '../utils/timestamp_manager.dart';

/// Sync yönü
enum SyncDirection { upload, download, bidirectional, conflict, skip }

/// Sync strateji
enum SyncStrategy { latestWins, localWins, remoteWins, manual, merge }

/// Sync manifest
class SyncManifest {
  final String manifestId;
  final String deviceId;
  final String deviceName;
  final DateTime createdAt;
  final Map<String, ManifestFile> files;
  final Map<String, dynamic> metadata;
  final int totalSize;
  final int fileCount;

  SyncManifest({
    required this.manifestId,
    required this.deviceId,
    required this.deviceName,
    required this.createdAt,
    required this.files,
    required this.metadata,
    required this.totalSize,
    required this.fileCount,
  });

  Map<String, dynamic> toJson() => {
    'manifestId': manifestId,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'createdAt': createdAt.toIso8601String(),
    'files': files.map((k, v) => MapEntry(k, v.toJson())),
    'metadata': metadata,
    'totalSize': totalSize,
    'fileCount': fileCount,
  };

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    final filesMap = <String, ManifestFile>{};
    final filesJson = json['files'] as Map<String, dynamic>? ?? {};

    for (final entry in filesJson.entries) {
      filesMap[entry.key] = ManifestFile.fromJson(entry.value);
    }

    return SyncManifest(
      manifestId: json['manifestId'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      createdAt: DateTime.parse(json['createdAt']),
      files: filesMap,
      metadata: json['metadata'] ?? {},
      totalSize: json['totalSize'] ?? 0,
      fileCount: json['fileCount'] ?? 0,
    );
  }
}

/// Manifest dosya bilgisi
class ManifestFile {
  final String fileHash;
  final String fileName;
  final String? filePath;
  final int fileSize;
  final String contentHash;
  final String metadataHash;
  final int contentVersion;
  final int metadataVersion;
  final DateTime lastModified;
  final Map<String, dynamic> metadata;

  ManifestFile({
    required this.fileHash,
    required this.fileName,
    this.filePath,
    required this.fileSize,
    required this.contentHash,
    required this.metadataHash,
    required this.contentVersion,
    required this.metadataVersion,
    required this.lastModified,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'fileName': fileName,
    'filePath': filePath,
    'fileSize': fileSize,
    'contentHash': contentHash,
    'metadataHash': metadataHash,
    'contentVersion': contentVersion,
    'metadataVersion': metadataVersion,
    'lastModified': lastModified.toIso8601String(),
    'metadata': metadata,
  };

  factory ManifestFile.fromJson(Map<String, dynamic> json) {
    return ManifestFile(
      fileHash: json['fileHash'],
      fileName: json['fileName'],
      filePath: json['filePath'],
      fileSize: json['fileSize'],
      contentHash: json['contentHash'],
      metadataHash: json['metadataHash'],
      contentVersion: json['contentVersion'],
      metadataVersion: json['metadataVersion'],
      lastModified: DateTime.parse(json['lastModified']),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Sync karar
class SyncDecision {
  final String fileHash;
  final SyncDirection direction;
  final SyncStrategy strategy;
  final String reason;
  final Map<String, dynamic> metadata;

  SyncDecision({
    required this.fileHash,
    required this.direction,
    required this.strategy,
    required this.reason,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'fileHash': fileHash,
    'direction': direction.name,
    'strategy': strategy.name,
    'reason': reason,
    'metadata': metadata,
  };
}

/// Bidirectional sync protocol
class BidirectionalSyncProtocol {
  static final BidirectionalSyncProtocol _instance =
      BidirectionalSyncProtocol._internal();
  static BidirectionalSyncProtocol get instance => _instance;
  BidirectionalSyncProtocol._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final SyncStateTracker _syncStateTracker = SyncStateTracker.instance;
  final FileVersionManager _versionManager = FileVersionManager.instance;
  final SmartSyncEngine _smartSyncEngine = SmartSyncEngine.instance;
  final SenkronErrorHandler _errorHandler = SenkronErrorHandler.instance;
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  // Callbacks
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;
  Function(SyncDecision decision)? onConflictDecision;

  /// Bidirectional sync protocol'ü initialize et
  Future<void> initializeBidirectionalSync() async {
    final db = await _veriTabani.database;

    // Sync sessions tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL UNIQUE,
        local_device_id TEXT NOT NULL,
        remote_device_id TEXT NOT NULL,
        local_manifest_id TEXT NOT NULL,
        remote_manifest_id TEXT NOT NULL,
        sync_strategy TEXT NOT NULL,
        status TEXT DEFAULT 'NEGOTIATING',
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        error_message TEXT
      )
    ''');

    // Sync decisions tablosu
    await db.execute('''
       CREATE TABLE IF NOT EXISTS sync_decisions (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         session_id TEXT NOT NULL,
         file_hash TEXT NOT NULL,
         direction TEXT NOT NULL,
         strategy TEXT NOT NULL,
         reason TEXT NOT NULL,
         metadata_json TEXT,
         created_at TEXT NOT NULL,
         executed_at TEXT
       )
     ''');

    // Sync manifests tablosu
    await db.execute('''
       CREATE TABLE IF NOT EXISTS sync_manifests (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         manifest_id TEXT NOT NULL UNIQUE,
         device_id TEXT NOT NULL,
         created_at TEXT NOT NULL,
         file_count INTEGER NOT NULL,
         total_size INTEGER NOT NULL,
         manifest_data TEXT NOT NULL
       )
     ''');

    print('🔄 BidirectionalSyncProtocol initialized');
  }

  /// Sync yönünü negotiate et
  Future<Map<String, SyncDecision>> negotiateSyncDirection(
    SyncManifest localManifest,
    SyncManifest remoteManifest, {
    SyncStrategy defaultStrategy = SyncStrategy.latestWins,
  }) async {
    _logMessage('🤝 Sync yönü negotiate ediliyor...');

    final decisions = <String, SyncDecision>{};
    final allFileHashes = <String>{};

    // Tüm dosya hash'lerini topla
    allFileHashes.addAll(localManifest.files.keys);
    allFileHashes.addAll(remoteManifest.files.keys);

    for (final fileHash in allFileHashes) {
      final localFile = localManifest.files[fileHash];
      final remoteFile = remoteManifest.files[fileHash];

      final decision = await _makeFileDecision(
        fileHash,
        localFile,
        remoteFile,
        defaultStrategy,
      );

      decisions[fileHash] = decision;
    }

    _logMessage('📋 ${decisions.length} dosya için karar alındı');
    return decisions;
  }

  /// Sync manifest oluştur
  Future<SyncManifest> createSyncManifest(
    String deviceId,
    String deviceName,
  ) async {
    _logMessage('📋 Sync manifest oluşturuluyor...');

    final manifestId = 'manifest_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final db = await _veriTabani.database;

    // Tüm belgeleri al
    final documents = await db.query('belgeler');
    final files = <String, ManifestFile>{};
    int totalSize = 0;

    for (final docData in documents) {
      final belge = BelgeModeli.fromMap(docData);

      // Metadata hash'ini hesapla
      final metadataHash = _hashComparator.generateMetadataHash(belge);

      // Version bilgilerini al
      final latestSnapshot = await _versionManager.getLatestSnapshot(belge.id!);
      final contentVersion = latestSnapshot?.versionNumber ?? 1;

      // Metadata version'ını sync state'den al
      final syncState = await _getSyncState(belge.dosyaHash);
      final metadataVersion = (syncState?['metadata_version'] as int?) ?? 1;

      final manifestFile = ManifestFile(
        fileHash: belge.dosyaHash,
        fileName: belge.dosyaAdi ?? 'unknown',
        filePath: belge.dosyaYolu,
        fileSize: belge.dosyaBoyutu ?? 0,
        contentHash: belge.dosyaHash,
        metadataHash: metadataHash,
        contentVersion: contentVersion,
        metadataVersion: metadataVersion,
        lastModified: belge.guncellemeTarihi ?? now,
        metadata: {
          'baslik': belge.baslik,
          'aciklama': belge.aciklama,
          'etiketler': belge.etiketler,
          'kategori_id': belge.kategoriId,
          'kisi_id': belge.kisiId,
        },
      );

      files[belge.dosyaHash] = manifestFile;
      totalSize += manifestFile.fileSize;
    }

    final manifest = SyncManifest(
      manifestId: manifestId,
      deviceId: deviceId,
      deviceName: deviceName,
      createdAt: now,
      files: files,
      metadata: {
        'platform': Platform.operatingSystem,
        'version': '1.0.0',
        'total_documents': documents.length,
      },
      totalSize: totalSize,
      fileCount: files.length,
    );

    // Manifest'i kaydet
    await _saveManifest(manifest);

    _logMessage('✅ Manifest oluşturuldu: ${files.length} dosya');
    return manifest;
  }

  /// Bidirectional sync yürüt
  Future<Map<String, dynamic>> executeBidirectionalSync(
    SenkronCihazi targetDevice,
    Map<String, SyncDecision> decisions, {
    bool parallelExecution = true,
  }) async {
    _logMessage('🚀 Bidirectional sync başlatılıyor...');

    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final results = <String, dynamic>{
      'session_id': sessionId,
      'total_files': decisions.length,
      'upload_count': 0,
      'download_count': 0,
      'skip_count': 0,
      'conflict_count': 0,
      'success_count': 0,
      'error_count': 0,
      'transferred_bytes': 0,
      'errors': <Map<String, dynamic>>[],
    };

    // Session'ı başlat
    await _startSyncSession(sessionId, targetDevice, decisions);

    // Kararları grupla
    final uploadDecisions = <String, SyncDecision>{};
    final downloadDecisions = <String, SyncDecision>{};
    final conflictDecisions = <String, SyncDecision>{};

    for (final entry in decisions.entries) {
      switch (entry.value.direction) {
        case SyncDirection.upload:
          uploadDecisions[entry.key] = entry.value;
          results['upload_count']++;
          break;
        case SyncDirection.download:
          downloadDecisions[entry.key] = entry.value;
          results['download_count']++;
          break;
        case SyncDirection.conflict:
          conflictDecisions[entry.key] = entry.value;
          results['conflict_count']++;
          break;
        case SyncDirection.skip:
          results['skip_count']++;
          break;
        default:
          break;
      }
    }

    try {
      // Conflict resolution
      if (conflictDecisions.isNotEmpty) {
        final conflictResults = await _resolveConflicts(
          conflictDecisions,
          targetDevice,
        );
        results['conflict_resolution'] = conflictResults;
      }

      // Upload operations
      if (uploadDecisions.isNotEmpty) {
        final uploadResults = await _executeUploads(
          uploadDecisions,
          targetDevice,
          parallelExecution: parallelExecution,
        );
        results['upload_results'] = uploadResults;
        results['success_count'] += uploadResults['success_count'] ?? 0;
        results['error_count'] += uploadResults['error_count'] ?? 0;
        results['transferred_bytes'] += uploadResults['transferred_bytes'] ?? 0;
      }

      // Download operations
      if (downloadDecisions.isNotEmpty) {
        final downloadResults = await _executeDownloads(
          downloadDecisions,
          targetDevice,
          parallelExecution: parallelExecution,
        );
        results['download_results'] = downloadResults;
        results['success_count'] += downloadResults['success_count'] ?? 0;
        results['error_count'] += downloadResults['error_count'] ?? 0;
        results['transferred_bytes'] +=
            downloadResults['transferred_bytes'] ?? 0;
      }

      // Session'ı tamamla
      await _completeSyncSession(sessionId, 'COMPLETED');

      final successRate = results['success_count'] / results['total_files'];
      results['success_rate'] = successRate;

      _logMessage(
        '✅ Bidirectional sync tamamlandı - Başarı oranı: ${(successRate * 100).toStringAsFixed(1)}%',
      );
    } catch (e, stackTrace) {
      _logMessage('❌ Bidirectional sync hatası: $e');

      // Error handling
      final errorInfo = _errorHandler.categorizeError(
        e,
        stackTrace: stackTrace,
        context: {
          'operation': 'bidirectional_sync',
          'session_id': sessionId,
          'target_device': targetDevice.ad,
        },
      );

      await _errorHandler.logDetailedError(errorInfo);
      await _completeSyncSession(sessionId, 'ERROR', e.toString());

      results['error'] = e.toString();
    }

    return results;
  }

  /// Dosya kararı al
  Future<SyncDecision> _makeFileDecision(
    String fileHash,
    ManifestFile? localFile,
    ManifestFile? remoteFile,
    SyncStrategy strategy,
  ) async {
    // Dosya sadece lokalde var
    if (localFile != null && remoteFile == null) {
      return SyncDecision(
        fileHash: fileHash,
        direction: SyncDirection.upload,
        strategy: strategy,
        reason: 'Dosya sadece lokalde mevcut',
      );
    }

    // Dosya sadece remote'da var
    if (localFile == null && remoteFile != null) {
      return SyncDecision(
        fileHash: fileHash,
        direction: SyncDirection.download,
        strategy: strategy,
        reason: 'Dosya sadece remote\'da mevcut',
      );
    }

    // Her iki tarafta da var
    if (localFile != null && remoteFile != null) {
      return await _compareFiles(localFile, remoteFile, strategy);
    }

    // Bu duruma hiç gelmemeli
    return SyncDecision(
      fileHash: fileHash,
      direction: SyncDirection.skip,
      strategy: strategy,
      reason: 'Bilinmeyen durum',
    );
  }

  /// Dosyaları karşılaştır
  Future<SyncDecision> _compareFiles(
    ManifestFile localFile,
    ManifestFile remoteFile,
    SyncStrategy strategy,
  ) async {
    // Hash'ler aynıysa sync gerekli değil
    if (localFile.contentHash == remoteFile.contentHash &&
        localFile.metadataHash == remoteFile.metadataHash) {
      return SyncDecision(
        fileHash: localFile.fileHash,
        direction: SyncDirection.skip,
        strategy: strategy,
        reason: 'Dosyalar aynı',
      );
    }

    // Strategy'ye göre karar ver
    switch (strategy) {
      case SyncStrategy.latestWins:
        return _decideByLatestWins(localFile, remoteFile);
      case SyncStrategy.localWins:
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.upload,
          strategy: strategy,
          reason: 'Lokal dosya öncelikli',
        );
      case SyncStrategy.remoteWins:
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.download,
          strategy: strategy,
          reason: 'Remote dosya öncelikli',
        );
      case SyncStrategy.manual:
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.conflict,
          strategy: strategy,
          reason: 'Manuel müdahale gerekli',
        );
      case SyncStrategy.merge:
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.conflict,
          strategy: strategy,
          reason: 'Merge gerekli',
        );
    }
  }

  /// En son güncellenen dosyayı seç
  SyncDecision _decideByLatestWins(
    ManifestFile localFile,
    ManifestFile remoteFile,
  ) {
    if (localFile.lastModified.isAfter(remoteFile.lastModified)) {
      return SyncDecision(
        fileHash: localFile.fileHash,
        direction: SyncDirection.upload,
        strategy: SyncStrategy.latestWins,
        reason: 'Lokal dosya daha yeni',
        metadata: {
          'local_modified': localFile.lastModified.toIso8601String(),
          'remote_modified': remoteFile.lastModified.toIso8601String(),
        },
      );
    } else if (remoteFile.lastModified.isAfter(localFile.lastModified)) {
      return SyncDecision(
        fileHash: localFile.fileHash,
        direction: SyncDirection.download,
        strategy: SyncStrategy.latestWins,
        reason: 'Remote dosya daha yeni',
        metadata: {
          'local_modified': localFile.lastModified.toIso8601String(),
          'remote_modified': remoteFile.lastModified.toIso8601String(),
        },
      );
    } else {
      // Aynı zamanda güncellenmiş, version'a bak
      if (localFile.contentVersion > remoteFile.contentVersion) {
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.upload,
          strategy: SyncStrategy.latestWins,
          reason: 'Lokal dosya version\'ı daha yüksek',
        );
      } else if (remoteFile.contentVersion > localFile.contentVersion) {
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.download,
          strategy: SyncStrategy.latestWins,
          reason: 'Remote dosya version\'ı daha yüksek',
        );
      } else {
        return SyncDecision(
          fileHash: localFile.fileHash,
          direction: SyncDirection.conflict,
          strategy: SyncStrategy.latestWins,
          reason: 'Conflict: Aynı zamanda güncellenmiş',
        );
      }
    }
  }

  /// Conflict'leri çöz
  Future<Map<String, dynamic>> _resolveConflicts(
    Map<String, SyncDecision> conflictDecisions,
    SenkronCihazi targetDevice,
  ) async {
    final results = <String, dynamic>{
      'total_conflicts': conflictDecisions.length,
      'resolved_conflicts': 0,
      'manual_conflicts': 0,
    };

    for (final entry in conflictDecisions.entries) {
      final decision = entry.value;

      // Callback ile kullanıcıya sor
      if (onConflictDecision != null) {
        onConflictDecision!(decision);
      }

      // Şimdilik otomatik merge dene
      if (decision.strategy == SyncStrategy.merge) {
        // Merge logic burada implement edilecek
        results['resolved_conflicts']++;
      } else {
        results['manual_conflicts']++;
      }
    }

    return results;
  }

  /// Upload operations'ları yürüt
  Future<Map<String, dynamic>> _executeUploads(
    Map<String, SyncDecision> uploadDecisions,
    SenkronCihazi targetDevice, {
    bool parallelExecution = true,
  }) async {
    final results = <String, dynamic>{
      'total_uploads': uploadDecisions.length,
      'success_count': 0,
      'error_count': 0,
      'transferred_bytes': 0,
    };

    // Upload logic burada implement edilecek
    // Şimdilik simulate et
    for (final entry in uploadDecisions.entries) {
      try {
        // Simulate upload
        await Future.delayed(Duration(milliseconds: 100));
        results['success_count']++;
        results['transferred_bytes'] += 1024; // Simulate
      } catch (e) {
        results['error_count']++;
      }
    }

    return results;
  }

  /// Download operations'ları yürüt
  Future<Map<String, dynamic>> _executeDownloads(
    Map<String, SyncDecision> downloadDecisions,
    SenkronCihazi targetDevice, {
    bool parallelExecution = true,
  }) async {
    final results = <String, dynamic>{
      'total_downloads': downloadDecisions.length,
      'success_count': 0,
      'error_count': 0,
      'transferred_bytes': 0,
    };

    // Download logic burada implement edilecek
    // Şimdilik simulate et
    for (final entry in downloadDecisions.entries) {
      try {
        // Simulate download
        await Future.delayed(Duration(milliseconds: 100));
        results['success_count']++;
        results['transferred_bytes'] += 1024; // Simulate
      } catch (e) {
        results['error_count']++;
      }
    }

    return results;
  }

  /// Manifest'i kaydet
  Future<void> _saveManifest(SyncManifest manifest) async {
    final db = await _veriTabani.database;

    await db.insert('sync_manifests', {
      'manifest_id': manifest.manifestId,
      'device_id': manifest.deviceId,
      'created_at': manifest.createdAt.toIso8601String(),
      'file_count': manifest.fileCount,
      'total_size': manifest.totalSize,
      'manifest_data': json.encode(manifest.toJson()),
    });
  }

  /// Sync session'ı başlat
  Future<void> _startSyncSession(
    String sessionId,
    SenkronCihazi targetDevice,
    Map<String, SyncDecision> decisions,
  ) async {
    final db = await _veriTabani.database;

    await db.insert('sync_sessions', {
      'session_id': sessionId,
      'local_device_id': 'local',
      'remote_device_id': targetDevice.id.toString(),
      'local_manifest_id': 'local_manifest',
      'remote_manifest_id': 'remote_manifest',
      'sync_strategy': 'BIDIRECTIONAL',
      'status': 'EXECUTING',
      'created_at': DateTime.now().toIso8601String(),
      'started_at': DateTime.now().toIso8601String(),
    });

    // Kararları kaydet
    for (final entry in decisions.entries) {
      await db.insert('sync_decisions', {
        'session_id': sessionId,
        'file_hash': entry.key,
        'direction': entry.value.direction.name,
        'strategy': entry.value.strategy.name,
        'reason': entry.value.reason,
        'metadata_json': json.encode(entry.value.metadata),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Sync session'ı tamamla
  Future<void> _completeSyncSession(
    String sessionId,
    String status, [
    String? errorMessage,
  ]) async {
    final db = await _veriTabani.database;

    await db.update(
      'sync_sessions',
      {
        'status': status,
        'completed_at': DateTime.now().toIso8601String(),
        'error_message': errorMessage,
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Sync state'i al
  Future<Map<String, dynamic>?> _getSyncState(String fileHash) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'senkron_state',
      where: 'dosya_hash = ?',
      whereArgs: [fileHash],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  /// Log mesajı
  void _logMessage(String message) {
    print('🔄 BidirectionalSync: $message');
    onLogMessage?.call(message);
  }
}
