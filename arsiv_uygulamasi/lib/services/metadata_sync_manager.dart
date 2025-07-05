import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'document_change_tracker.dart';
import 'sync_state_tracker.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../utils/hash_comparator.dart';
import '../utils/timestamp_manager.dart';

/// Metadata senkronizasyonu yönetici sınıfı
/// Çift yönlü metadata senkronizasyonu sağlar
class MetadataSyncManager {
  static final MetadataSyncManager _instance = MetadataSyncManager._internal();
  static MetadataSyncManager get instance => _instance;
  MetadataSyncManager._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;
  final SyncStateTracker _stateTracker = SyncStateTracker.instance;
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  // Progress callback'leri
  Function(String message)? onLogMessage;
  Function(double progress)? onProgressUpdate;

  /// Metadata senkronizasyonu başlat
  Future<Map<String, int>> syncMetadata(
    SenkronCihazi targetDevice,
    String localDeviceId,
  ) async {
    _addLog('📋 Metadata senkronizasyonu başlatılıyor...');

    final stats = {'sent': 0, 'received': 0, 'conflicts': 0, 'errors': 0};

    try {
      // 1. Local değişiklikleri karşı tarafa gönder
      _updateProgress(0.2, 'Local değişiklikler gönderiliyor...');
      final sentChanges = await _sendLocalChanges(targetDevice, localDeviceId);
      stats['sent'] = sentChanges;

      // 2. Remote değişiklikleri al
      _updateProgress(0.5, 'Remote değişiklikler alınıyor...');
      final receivedChanges = await _receiveRemoteChanges(
        targetDevice,
        localDeviceId,
      );
      stats['received'] = receivedChanges['received'] ?? 0;
      stats['conflicts'] = receivedChanges['conflicts'] ?? 0;

      // 3. Çakışmaları çöz
      _updateProgress(0.8, 'Çakışmalar çözülüyor...');
      await _resolveConflicts(targetDevice, localDeviceId);

      _updateProgress(1.0, 'Metadata senkronizasyonu tamamlandı');
      _addLog('✅ Metadata senkronizasyonu başarıyla tamamlandı');

      return stats;
    } catch (e) {
      _addLog('❌ Metadata senkronizasyon hatası: $e');
      stats['errors'] = 1;
      return stats;
    }
  }

  /// Local değişiklikleri karşı tarafa gönder
  Future<int> _sendLocalChanges(
    SenkronCihazi targetDevice,
    String localDeviceId,
  ) async {
    // Son senkronizasyon zamanından sonraki değişiklikleri al
    final lastSyncTime = await _getLastSyncTime(targetDevice.id);
    final changes = await _changeTracker.getChangedDocuments(
      lastSyncTime,
      cihazId: localDeviceId,
    );

    if (changes.isEmpty) {
      _addLog('📭 Gönderilecek değişiklik bulunamadı');
      return 0;
    }

    _addLog('📤 ${changes.length} değişiklik gönderiliyor...');

    try {
      // Değişiklikleri batch halinde gönder
      final batchSize = 10;
      int sentCount = 0;

      for (int i = 0; i < changes.length; i += batchSize) {
        final batch = changes.skip(i).take(batchSize).toList();

        final response = await http
            .post(
              Uri.parse('http://${targetDevice.ip}:8080/metadata/sync'),
              headers: {
                'Content-Type': 'application/json',
                'X-Device-ID': localDeviceId,
              },
              body: json.encode({
                'changes': batch,
                'sync_time': DateTime.now().toIso8601String(),
              }),
            )
            .timeout(Duration(seconds: 30));

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final processedIds = List<int>.from(result['processed_ids'] ?? []);

          // Başarılı olan değişiklikleri synced olarak işaretle
          await _changeTracker.markChangesAsSynced(processedIds);
          sentCount += processedIds.length;

          _addLog('📤 ${processedIds.length} değişiklik gönderildi');
        } else {
          _addLog('❌ Batch gönderme hatası: ${response.statusCode}');
        }
      }

      return sentCount;
    } catch (e) {
      _addLog('❌ Değişiklik gönderme hatası: $e');
      return 0;
    }
  }

  /// Remote değişiklikleri al
  Future<Map<String, int>> _receiveRemoteChanges(
    SenkronCihazi targetDevice,
    String localDeviceId,
  ) async {
    final stats = {'received': 0, 'conflicts': 0};

    try {
      final lastSyncTime = await _getLastSyncTime(targetDevice.id);

      final response = await http
          .get(
            Uri.parse(
              'http://${targetDevice.ip}:8080/metadata/changes',
            ).replace(
              queryParameters: {
                'since': lastSyncTime.toIso8601String(),
                'device_id': localDeviceId,
              },
            ),
            headers: {
              'Accept': 'application/json',
              'X-Device-ID': localDeviceId,
            },
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final remoteChanges = List<Map<String, dynamic>>.from(
          data['changes'] ?? [],
        );

        _addLog('📥 ${remoteChanges.length} remote değişiklik alındı');

        for (final change in remoteChanges) {
          final processed = await _processRemoteChange(change, targetDevice.id);
          if (processed == 'received') {
            stats['received'] = stats['received']! + 1;
          } else if (processed == 'conflict') {
            stats['conflicts'] = stats['conflicts']! + 1;
          }
        }
      } else {
        _addLog('❌ Remote değişiklik alma hatası: ${response.statusCode}');
      }

      return stats;
    } catch (e) {
      _addLog('❌ Remote değişiklik alma hatası: $e');
      return stats;
    }
  }

  /// Remote değişikliği işle
  Future<String> _processRemoteChange(
    Map<String, dynamic> change,
    String targetDeviceId,
  ) async {
    try {
      final belgeId = change['belge_id'] as int;
      final localBelge = await _veriTabani.belgeGetir(belgeId);

      if (localBelge == null) {
        _addLog('⚠️ Belge bulunamadı: $belgeId');
        return 'error';
      }

      // Çakışma kontrolü
      final comparison = await _changeTracker.compareDocumentVersions(
        localBelge,
        change,
      );

      if (comparison['conflict'] == true) {
        _addLog('⚠️ Çakışma tespit edildi: ${localBelge.dosyaAdi}');
        await _storeConflict(localBelge, change, targetDeviceId);
        return 'conflict';
      }

      // Değişikliği uygula
      if (comparison['needs_sync'] == true) {
        final resolution = comparison['resolution'] as String;
        final mergedBelge = await _changeTracker.mergeDocumentMetadata(
          localBelge,
          change,
          resolution,
        );

        await _veriTabani.belgeGuncelle(mergedBelge);
        _addLog('✅ Metadata güncellendi: ${mergedBelge.dosyaAdi}');
        return 'received';
      }

      return 'skipped';
    } catch (e) {
      _addLog('❌ Remote değişiklik işleme hatası: $e');
      return 'error';
    }
  }

  /// Çakışmayı kaydet
  Future<void> _storeConflict(
    BelgeModeli localBelge,
    Map<String, dynamic> remoteChange,
    String targetDeviceId,
  ) async {
    final db = await _veriTabani.database;

    await db.insert('metadata_conflicts', {
      'belge_id': localBelge.id,
      'local_metadata': json.encode(localBelge.toJson()),
      'remote_metadata': json.encode(remoteChange),
      'conflict_time': DateTime.now().toIso8601String(),
      'source_device': targetDeviceId,
      'status': 'PENDING',
    });
  }

  /// Çakışmaları çöz
  Future<void> _resolveConflicts(
    SenkronCihazi targetDevice,
    String localDeviceId,
  ) async {
    final db = await _veriTabani.database;

    // Çakışma tablosunu oluştur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        local_metadata TEXT NOT NULL,
        remote_metadata TEXT NOT NULL,
        conflict_time TEXT NOT NULL,
        source_device TEXT NOT NULL,
        status TEXT DEFAULT 'PENDING',
        resolution TEXT,
        resolved_time TEXT,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Bekleyen çakışmaları al
    final conflicts = await db.query(
      'metadata_conflicts',
      where: 'status = ? AND source_device = ?',
      whereArgs: ['PENDING', targetDevice.id],
    );

    _addLog('🔄 ${conflicts.length} çakışma çözülüyor...');

    for (final conflict in conflicts) {
      await _resolveConflict(conflict);
    }
  }

  /// Tekil çakışmayı çöz
  Future<void> _resolveConflict(Map<String, dynamic> conflict) async {
    try {
      final belgeId = conflict['belge_id'] as int;
      final localMetadata = json.decode(conflict['local_metadata'] as String);
      final remoteMetadata = json.decode(conflict['remote_metadata'] as String);

      // Basit çözüm: En yeni metadata'yı al
      final localTime = DateTime.parse(localMetadata['guncelleme_tarihi']);
      final remoteTime = DateTime.parse(remoteMetadata['guncelleme_tarihi']);

      final resolution =
          localTime.isAfter(remoteTime) ? 'local_wins' : 'remote_wins';

      if (resolution == 'remote_wins') {
        final localBelge = await _veriTabani.belgeGetir(belgeId);
        if (localBelge != null) {
          final mergedBelge = await _changeTracker.mergeDocumentMetadata(
            localBelge,
            remoteMetadata,
            resolution,
          );
          await _veriTabani.belgeGuncelle(mergedBelge);
        }
      }

      // Çakışmayı çözüldü olarak işaretle
      final db = await _veriTabani.database;
      await db.update(
        'metadata_conflicts',
        {
          'status': 'RESOLVED',
          'resolution': resolution,
          'resolved_time': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [conflict['id']],
      );

      _addLog('✅ Çakışma çözüldü: $resolution');
    } catch (e) {
      _addLog('❌ Çakışma çözümleme hatası: $e');
    }
  }

  /// Son senkronizasyon zamanını al
  Future<DateTime> _getLastSyncTime(String? deviceId) async {
    if (deviceId == null) return DateTime.now().subtract(Duration(days: 1));

    final db = await _veriTabani.database;

    // Metadata sync tablosunu oluştur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata_sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        last_sync_time TEXT NOT NULL,
        sync_type TEXT DEFAULT 'METADATA',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    final result = await db.query(
      'metadata_sync_log',
      where: 'device_id = ? AND sync_type = ?',
      whereArgs: [deviceId, 'METADATA'],
      orderBy: 'last_sync_time DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return DateTime.parse(result.first['last_sync_time'] as String);
    }

    return DateTime.now().subtract(Duration(days: 1));
  }

  /// Son senkronizasyon zamanını güncelle
  Future<void> _updateLastSyncTime(String deviceId) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('metadata_sync_log', {
      'device_id': deviceId,
      'last_sync_time': now,
      'sync_type': 'METADATA',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Log mesajı ekle
  void _addLog(String message) {
    print('MetadataSyncManager: $message');
    onLogMessage?.call(message);
  }

  /// Progress güncelle
  void _updateProgress(double progress, String operation) {
    onProgressUpdate?.call(progress);
  }

  /// Çakışmaları al
  Future<List<Map<String, dynamic>>> getPendingConflicts() async {
    final db = await _veriTabani.database;

    return await db.rawQuery('''
      SELECT 
        mc.*,
        b.dosya_adi,
        b.baslik
      FROM metadata_conflicts mc
      JOIN belgeler b ON mc.belge_id = b.id
      WHERE mc.status = 'PENDING'
      ORDER BY mc.conflict_time DESC
    ''');
  }

  /// Çakışmayı manuel çöz
  Future<void> resolveConflictManually(
    int conflictId,
    String resolution,
  ) async {
    final db = await _veriTabani.database;

    final conflict = await db.query(
      'metadata_conflicts',
      where: 'id = ?',
      whereArgs: [conflictId],
    );

    if (conflict.isNotEmpty) {
      await _resolveConflict(conflict.first);
    }
  }

  /// Eski çakışma kayıtlarını temizle
  Future<void> cleanOldConflicts() async {
    final db = await _veriTabani.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));

    await db.delete(
      'metadata_conflicts',
      where: 'resolved_time < ? AND status = ?',
      whereArgs: [cutoffDate.toIso8601String(), 'RESOLVED'],
    );
  }
}

/// Metadata değişikliği
class MetadataChange {
  final String entityType;
  final int entityId;
  final String changeType;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String hash;

  MetadataChange({
    required this.entityType,
    required this.entityId,
    required this.changeType,
    required this.metadata,
    required this.timestamp,
    required this.hash,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'changeType': changeType,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'hash': hash,
    };
  }

  factory MetadataChange.fromJson(Map<String, dynamic> json) {
    return MetadataChange(
      entityType: json['entityType'],
      entityId: json['entityId'],
      changeType: json['changeType'],
      metadata: json['metadata'],
      timestamp: DateTime.parse(json['timestamp']),
      hash: json['hash'],
    );
  }
}

/// Metadata çakışması
class MetadataConflict {
  final String entityType;
  final int entityId;
  final MetadataChange localChange;
  final MetadataChange remoteChange;
  final String conflictType;

  MetadataConflict({
    required this.entityType,
    required this.entityId,
    required this.localChange,
    required this.remoteChange,
    required this.conflictType,
  });
}

/// Metadata sync sonucu
class MetadataSyncResult {
  bool success;
  String? error;
  int localChangesCount;
  int remoteChangesCount;
  int conflictsCount;
  int resolvedConflictsCount;
  int appliedRemoteChanges;
  int sentLocalChanges;
  DateTime? syncTimestamp;

  MetadataSyncResult({
    this.success = false,
    this.error,
    this.localChangesCount = 0,
    this.remoteChangesCount = 0,
    this.conflictsCount = 0,
    this.resolvedConflictsCount = 0,
    this.appliedRemoteChanges = 0,
    this.sentLocalChanges = 0,
    this.syncTimestamp,
  });
}
