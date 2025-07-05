import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'veritabani_servisi.dart';
import '../models/belge_modeli.dart';

/// Senkronizasyon durumu enum'u
enum SyncState { pending, syncing, synced, error, conflict }

/// Senkronizasyon durumu takip servisi
/// Aynı dosyaların tekrar transfer edilmesini önler
class SyncStateTracker {
  static final SyncStateTracker _instance = SyncStateTracker._internal();
  static SyncStateTracker get instance => _instance;
  SyncStateTracker._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();

  /// Senkronizasyon durumu tablosunu oluştur
  Future<void> initializeSyncState() async {
    final db = await _veriTabani.database;

    // Senkronizasyon durumu tablosunu oluştur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dosya_hash TEXT NOT NULL UNIQUE,
        dosya_adi TEXT NOT NULL,
        son_sync_zamani TEXT NOT NULL,
        sync_durumu TEXT DEFAULT 'SYNCED',
        hedef_cihaz_id TEXT,
        kaynak_cihaz_id TEXT,
        metadata_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // İndeks oluştur
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_state_hash 
      ON senkron_state(dosya_hash)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_state_durum 
      ON senkron_state(sync_durumu)
    ''');
  }

  /// Dosyanın sync durumunu kontrol et
  Future<bool> isSynced(String dosyaHash, String? hedefCihazId) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'senkron_state',
      where: 'dosya_hash = ? AND sync_durumu = ? AND hedef_cihaz_id = ?',
      whereArgs: [dosyaHash, 'SYNCED', hedefCihazId],
    );

    return result.isNotEmpty;
  }

  /// Dosyayı senkronize olarak işaretle
  Future<void> markAsSynced(
    String dosyaHash,
    String dosyaAdi,
    String? hedefCihazId,
    String? kaynakCihazId, {
    String? metadataHash,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('senkron_state', {
      'dosya_hash': dosyaHash,
      'dosya_adi': dosyaAdi,
      'son_sync_zamani': now,
      'sync_durumu': 'SYNCED',
      'hedef_cihaz_id': hedefCihazId,
      'kaynak_cihaz_id': kaynakCihazId,
      'metadata_hash': metadataHash ?? '',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Son sync zamanını al
  Future<DateTime?> getLastSyncTime(String dosyaHash) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'senkron_state',
      where: 'dosya_hash = ?',
      whereArgs: [dosyaHash],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return DateTime.parse(result.first['son_sync_zamani'] as String);
    }
    return null;
  }

  /// Sync durumunu güncelle
  Future<void> updateSyncState(
    String dosyaHash,
    String yeniDurum, {
    String? metadataHash,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'senkron_state',
      {
        'sync_durumu': yeniDurum,
        'metadata_hash': metadataHash,
        'updated_at': now,
      },
      where: 'dosya_hash = ?',
      whereArgs: [dosyaHash],
    );
  }

  /// Sync durumunu temizle
  Future<void> clearSyncState([String? cihazId]) async {
    final db = await _veriTabani.database;

    if (cihazId != null) {
      await db.delete(
        'senkron_state',
        where: 'hedef_cihaz_id = ? OR kaynak_cihaz_id = ?',
        whereArgs: [cihazId, cihazId],
      );
    } else {
      await db.delete('senkron_state');
    }
  }

  /// Sync gerekli mi kontrol et
  Future<bool> shouldSync(
    BelgeModeli belge,
    String? hedefCihazId, {
    String? remoteMetadataHash,
  }) async {
    if (belge.dosyaHash.isEmpty) return false;

    // Daha önce sync edilmiş mi kontrol et
    final synced = await isSynced(belge.dosyaHash, hedefCihazId);

    if (!synced) {
      return true; // Hiç sync edilmemiş
    }

    // Metadata değişmiş mi kontrol et
    if (remoteMetadataHash != null) {
      final db = await _veriTabani.database;
      final result = await db.query(
        'senkron_state',
        where: 'dosya_hash = ? AND metadata_hash = ?',
        whereArgs: [belge.dosyaHash, remoteMetadataHash],
      );

      // Metadata hash'i farklıysa sync gerekli
      return result.isEmpty;
    }

    return false; // Sync gerekli değil
  }

  /// Senkronizasyon istatistikleri
  Future<Map<String, int>> getSyncStats() async {
    final db = await _veriTabani.database;

    final syncedCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM senkron_state WHERE sync_durumu = ?',
      ['SYNCED'],
    );

    final pendingCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM senkron_state WHERE sync_durumu = ?',
      ['PENDING'],
    );

    final errorCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM senkron_state WHERE sync_durumu = ?',
      ['ERROR'],
    );

    return {
      'synced': syncedCount.first['count'] as int,
      'pending': pendingCount.first['count'] as int,
      'error': errorCount.first['count'] as int,
    };
  }

  /// Eski sync kayıtlarını temizle (30 gün üzeri)
  Future<void> cleanOldSyncRecords() async {
    final db = await _veriTabani.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));

    await db.delete(
      'senkron_state',
      where: 'updated_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// HTTP sunucu için senkronizasyon istatistikleri
  Future<Map<String, int>> getSyncStatistics() async {
    return await getSyncStats(); // Mevcut metodu kullan
  }

  /// Tüm sync durumlarını al
  Future<List<Map<String, dynamic>>> getAllSyncStates() async {
    final db = await _veriTabani.database;
    return await db.query('senkron_state', orderBy: 'updated_at DESC');
  }

  /// Belirli durumdaki dosyaları al
  Future<List<Map<String, dynamic>>> getFilesByState(SyncState state) async {
    final db = await _veriTabani.database;
    final stateName = state.toString().split('.').last.toUpperCase();

    return await db.query(
      'senkron_state',
      where: 'sync_durumu = ?',
      whereArgs: [stateName],
      orderBy: 'updated_at DESC',
    );
  }

  // ============== EKSİK METODLAR ==============

  /// Sync durumunu getir
  Future<Map<String, dynamic>?> getSyncState(String dosyaHash) async {
    final db = await _veriTabani.database;
    final result = await db.query(
      'senkron_state',
      where: 'dosya_hash = ?',
      whereArgs: [dosyaHash],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      final data = result.first;
      return {
        'hash': data['dosya_hash'],
        'lastSyncTime': DateTime.parse(data['son_sync_zamani'] as String),
        'syncState': data['sync_durumu'],
        'deviceId': data['hedef_cihaz_id'],
        'metadataHash': data['metadata_hash'],
      };
    }
    return null;
  }

  /// Dosyayı hata durumuna işaretle
  Future<void> markAsError(String dosyaHash, String localDeviceId) async {
    await updateSyncState(dosyaHash, 'ERROR');
  }

  /// Çakışmalı dosyaları getir
  Future<List<Map<String, dynamic>>> getConflictedFiles() async {
    final db = await _veriTabani.database;
    return await db.query(
      'senkron_state',
      where: 'sync_durumu = ?',
      whereArgs: ['CONFLICT'],
      orderBy: 'updated_at DESC',
    );
  }

  /// Çakışmayı çöz
  Future<void> resolveConflict(String dosyaHash, String localDeviceId) async {
    await updateSyncState(dosyaHash, 'SYNCED');
  }

  /// Senkronizasyon oturumunu güncelle
  Future<void> updateSyncSession(
    String deviceId,
    String localDeviceId,
    int successCount,
    int errorCount,
  ) async {
    try {
      // Basit session tracking için mevcut state update metodunu kullan
      final sessionHash = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await updateSyncState(sessionHash, errorCount == 0 ? 'SYNCED' : 'ERROR');
      print(
        'Sync session güncellendi: $successCount success, $errorCount error',
      );
    } catch (e) {
      print('Sync session güncellenemedi: $e');
    }
  }
}
