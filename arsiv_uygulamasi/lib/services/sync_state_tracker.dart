import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'veritabani_servisi.dart';
import '../models/belge_modeli.dart';

/// Senkronizasyon durumu enum'u
enum SyncState { notSynced, syncing, synced, error, conflict }

/// Senkronizasyon durumunu takip eden sınıf
class SyncStateTracker {
  static final SyncStateTracker _instance = SyncStateTracker._internal();
  static SyncStateTracker get instance => _instance;
  SyncStateTracker._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();

  /// Senkronizasyon state tablosunu oluştur
  Future<void> initializeSyncState() async {
    final db = await _veriTabani.database;

    // Senkron state tablosunu kontrol et ve oluştur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dosya_hash TEXT NOT NULL UNIQUE,
        dosya_adi TEXT NOT NULL,
        sync_durumu TEXT NOT NULL,
        son_sync_zamani TEXT,
        hedef_cihaz TEXT,
        hata_mesaji TEXT,
        retry_count INTEGER DEFAULT 0,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL
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

    print('📊 SyncStateTracker initialized');
  }

  /// Dosyayı senkronize olarak işaretle
  Future<void> markAsSynced(
    String dosyaHash,
    String dosyaAdi, {
    String? hedefCihaz,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('senkron_state', {
      'dosya_hash': dosyaHash,
      'dosya_adi': dosyaAdi,
      'sync_durumu': SyncState.synced.name,
      'son_sync_zamani': now,
      'hedef_cihaz': hedefCihaz ?? 'unknown',
      'retry_count': 0,
      'olusturma_tarihi': now,
      'guncelleme_tarihi': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Dosyayı senkronizasyon başladı olarak işaretle
  Future<void> markAsSyncing(
    String dosyaHash,
    String dosyaAdi, {
    String? hedefCihaz,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('senkron_state', {
      'dosya_hash': dosyaHash,
      'dosya_adi': dosyaAdi,
      'sync_durumu': SyncState.syncing.name,
      'son_sync_zamani': now,
      'hedef_cihaz': hedefCihaz ?? 'unknown',
      'retry_count': 0,
      'olusturma_tarihi': now,
      'guncelleme_tarihi': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Dosyayı hata olarak işaretle
  Future<void> markAsError(
    String dosyaHash,
    String dosyaAdi,
    String hataMesaji, {
    String? hedefCihaz,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    // Mevcut retry count'u al
    final existing = await getSyncState(dosyaHash);
    final retryCount = (existing?['retry_count'] ?? 0) + 1;

    await db.insert('senkron_state', {
      'dosya_hash': dosyaHash,
      'dosya_adi': dosyaAdi,
      'sync_durumu': SyncState.error.name,
      'son_sync_zamani': now,
      'hedef_cihaz': hedefCihaz ?? 'unknown',
      'hata_mesaji': hataMesaji,
      'retry_count': retryCount,
      'olusturma_tarihi': now,
      'guncelleme_tarihi': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Dosyayı çakışma olarak işaretle
  Future<void> markAsConflict(
    String dosyaHash,
    String dosyaAdi,
    String conflictMesaji, {
    String? hedefCihaz,
  }) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('senkron_state', {
      'dosya_hash': dosyaHash,
      'dosya_adi': dosyaAdi,
      'sync_durumu': SyncState.conflict.name,
      'son_sync_zamani': now,
      'hedef_cihaz': hedefCihaz ?? 'unknown',
      'hata_mesaji': conflictMesaji,
      'retry_count': 0,
      'olusturma_tarihi': now,
      'guncelleme_tarihi': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Dosyanın senkronizasyon durumunu kontrol et
  Future<bool> isSynced(String dosyaHash) async {
    final state = await getSyncState(dosyaHash);
    return state != null && state['sync_durumu'] == SyncState.synced.name;
  }

  /// Dosyanın sync durumunu al
  Future<Map<String, dynamic>?> getSyncState(String dosyaHash) async {
    final db = await _veriTabani.database;
    final result = await db.query(
      'senkron_state',
      where: 'dosya_hash = ?',
      whereArgs: [dosyaHash],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  /// Son sync zamanını al
  Future<DateTime?> getLastSyncTime(String dosyaHash) async {
    final state = await getSyncState(dosyaHash);
    if (state != null && state['son_sync_zamani'] != null) {
      return DateTime.parse(state['son_sync_zamani']);
    }
    return null;
  }

  /// Sync gerekli mi kontrol et
  Future<bool> shouldSync(BelgeModeli belge, {Duration? threshold}) async {
    final state = await getSyncState(belge.dosyaHash);

    if (state == null) {
      return true; // Hiç senkronize edilmemiş
    }

    final syncDurumu = state['sync_durumu'];

    // Hata durumunda retry count kontrol et
    if (syncDurumu == SyncState.error.name) {
      final retryCount = state['retry_count'] ?? 0;
      return retryCount < 3; // 3 kez retry yap
    }

    // Çakışma durumunda manuel müdahale gerekli
    if (syncDurumu == SyncState.conflict.name) {
      return false;
    }

    // Senkronize edilmiş dosyalar için threshold kontrol et
    if (syncDurumu == SyncState.synced.name) {
      if (threshold != null && state['son_sync_zamani'] != null) {
        final lastSync = DateTime.parse(state['son_sync_zamani']);
        final now = DateTime.now();
        return now.difference(lastSync) > threshold;
      }
      return false; // Yakın zamanda senkronize edilmiş
    }

    return true; // Diğer durumlar için sync yap
  }

  /// Tüm sync durumlarını getir
  Future<List<Map<String, dynamic>>> getAllSyncStates() async {
    final db = await _veriTabani.database;
    return await db.query('senkron_state', orderBy: 'guncelleme_tarihi DESC');
  }

  /// Belirli durumdaki dosyaları getir
  Future<List<Map<String, dynamic>>> getFilesByState(SyncState state) async {
    final db = await _veriTabani.database;
    return await db.query(
      'senkron_state',
      where: 'sync_durumu = ?',
      whereArgs: [state.name],
      orderBy: 'guncelleme_tarihi DESC',
    );
  }

  /// Sync state'i temizle
  Future<void> clearSyncState({String? dosyaHash}) async {
    final db = await _veriTabani.database;

    if (dosyaHash != null) {
      await db.delete(
        'senkron_state',
        where: 'dosya_hash = ?',
        whereArgs: [dosyaHash],
      );
    } else {
      await db.delete('senkron_state');
    }
  }

  /// Hatalı sync kayıtlarını temizle
  Future<void> clearErrorStates() async {
    final db = await _veriTabani.database;
    await db.delete(
      'senkron_state',
      where: 'sync_durumu = ?',
      whereArgs: [SyncState.error.name],
    );
  }

  /// Sync istatistiklerini al
  Future<Map<String, int>> getSyncStatistics() async {
    final db = await _veriTabani.database;
    final result = await db.rawQuery('''
      SELECT 
        sync_durumu,
        COUNT(*) as count
      FROM senkron_state 
      GROUP BY sync_durumu
    ''');

    final stats = <String, int>{};
    for (final row in result) {
      stats[row['sync_durumu'] as String] = row['count'] as int;
    }

    return stats;
  }

  /// Eski sync kayıtlarını temizle
  Future<void> cleanupOldSyncStates({Duration? olderThan}) async {
    final db = await _veriTabani.database;
    final threshold = olderThan ?? const Duration(days: 30);
    final cutoffDate = DateTime.now().subtract(threshold).toIso8601String();

    await db.delete(
      'senkron_state',
      where: 'guncelleme_tarihi < ?',
      whereArgs: [cutoffDate],
    );
  }
}
