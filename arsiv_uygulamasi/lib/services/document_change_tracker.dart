import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import '../models/belge_modeli.dart';
import '../utils/hash_comparator.dart';
import '../utils/timestamp_manager.dart';

/// Belge değişikliklerini takip eden sınıf
class DocumentChangeTracker {
  static final DocumentChangeTracker _instance =
      DocumentChangeTracker._internal();
  static DocumentChangeTracker get instance => _instance;
  DocumentChangeTracker._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  /// Belge versiyon tablosunu oluştur
  Future<void> initializeChangeTracking() async {
    final db = await _veriTabani.database;

    // Belge versiyonları tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS belge_versiyonlari (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        versiyon_numarasi INTEGER NOT NULL,
        dosya_hash TEXT NOT NULL,
        metadata_hash TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        dosya_boyutu INTEGER NOT NULL,
        olusturma_tarihi TEXT NOT NULL,
        degisiklik_tipi TEXT NOT NULL,
        degisiklik_aciklamasi TEXT,
        kullanici_id TEXT,
        cihaz_id TEXT,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Metadata değişiklikleri tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata_degisiklikleri (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        alan_adi TEXT NOT NULL,
        eski_deger TEXT,
        yeni_deger TEXT,
        degisiklik_tarihi TEXT NOT NULL,
        cihaz_id TEXT,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // İndeksler
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_belge_versiyonlari_belge_id 
      ON belge_versiyonlari(belge_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_belge_versiyonlari_hash 
      ON belge_versiyonlari(dosya_hash)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_metadata_degisiklikleri_belge_id 
      ON metadata_degisiklikleri(belge_id)
    ''');

    print('📝 DocumentChangeTracker initialized');
  }

  /// Belge değişikliklerini takip et
  Future<void> trackDocumentChanges(
    BelgeModeli belge, {
    String? cihazId,
    String? kullaniciId,
    String? degisiklikAciklamasi,
  }) async {
    final db = await _veriTabani.database;

    // Mevcut versiyon numarasını al
    final versionResult = await db.query(
      'belge_versiyonlari',
      where: 'belge_id = ?',
      whereArgs: [belge.id],
      orderBy: 'versiyon_numarasi DESC',
      limit: 1,
    );

    final yeniVersionNo =
        versionResult.isNotEmpty
            ? (versionResult.first['versiyon_numarasi'] as int) + 1
            : 1;

    // Hash değerlerini hesapla
    final contentHash = await _calculateContentHash(belge.dosyaYolu);
    final metadataHash = _hashComparator.generateMetadataHash(belge);

    // Değişiklik tipini belirle
    final degisiklikTipi = await _determineDegisiklikTipi(belge, versionResult);

    // Versiyon kaydını oluştur
    await db.insert('belge_versiyonlari', {
      'belge_id': belge.id,
      'versiyon_numarasi': yeniVersionNo,
      'dosya_hash': belge.dosyaHash,
      'metadata_hash': metadataHash,
      'content_hash': contentHash,
      'dosya_boyutu': belge.dosyaBoyutu,
      'olusturma_tarihi': DateTime.now().toIso8601String(),
      'degisiklik_tipi': degisiklikTipi,
      'degisiklik_aciklamasi': degisiklikAciklamasi,
      'kullanici_id': kullaniciId,
      'cihaz_id': cihazId ?? 'unknown',
    });

    // Metadata değişikliklerini kaydet
    await _trackMetadataChanges(belge, cihazId);
  }

  /// Metadata değişikliklerini takip et
  Future<void> _trackMetadataChanges(BelgeModeli belge, String? cihazId) async {
    final db = await _veriTabani.database;

    // Önceki metadata'yı al
    final previousVersion = await db.query(
      'belge_versiyonlari',
      where: 'belge_id = ?',
      whereArgs: [belge.id],
      orderBy: 'versiyon_numarasi DESC',
      limit: 1,
      offset: 1, // Bir önceki versiyonu al
    );

    if (previousVersion.isEmpty) return;

    // Önceki belgeyi al
    final previousBelge = await _veriTabani.belgeGetir(belge.id!);
    if (previousBelge == null) return;

    // Metadata değişikliklerini karşılaştır
    final changes = _compareMetadata(previousBelge, belge);

    final now = DateTime.now().toIso8601String();

    for (final change in changes) {
      await db.insert('metadata_degisiklikleri', {
        'belge_id': belge.id,
        'alan_adi': change['field'],
        'eski_deger': change['oldValue'],
        'yeni_deger': change['newValue'],
        'degisiklik_tarihi': now,
        'cihaz_id': cihazId ?? 'unknown',
      });
    }
  }

  /// Metadata değişikliklerini karşılaştır
  List<Map<String, dynamic>> _compareMetadata(
    BelgeModeli eski,
    BelgeModeli yeni,
  ) {
    final changes = <Map<String, dynamic>>[];

    // Başlık değişikliği
    if (eski.baslik != yeni.baslik) {
      changes.add({
        'field': 'baslik',
        'oldValue': eski.baslik,
        'newValue': yeni.baslik,
      });
    }

    // Açıklama değişikliği
    if (eski.aciklama != yeni.aciklama) {
      changes.add({
        'field': 'aciklama',
        'oldValue': eski.aciklama,
        'newValue': yeni.aciklama,
      });
    }

    // Kategori değişikliği
    if (eski.kategoriId != yeni.kategoriId) {
      changes.add({
        'field': 'kategori_id',
        'oldValue': eski.kategoriId?.toString(),
        'newValue': yeni.kategoriId?.toString(),
      });
    }

    // Kişi değişikliği
    if (eski.kisiId != yeni.kisiId) {
      changes.add({
        'field': 'kisi_id',
        'oldValue': eski.kisiId?.toString(),
        'newValue': yeni.kisiId?.toString(),
      });
    }

    // Etiket değişikliği
    if (eski.etiketler != yeni.etiketler) {
      changes.add({
        'field': 'etiketler',
        'oldValue': eski.etiketler,
        'newValue': yeni.etiketler,
      });
    }

    return changes;
  }

  /// Değişiklik tipini belirle
  Future<String> _determineDegisiklikTipi(
    BelgeModeli belge,
    List<Map<String, dynamic>> previousVersions,
  ) async {
    if (previousVersions.isEmpty) {
      return 'CREATE';
    }

    final previousVersion = previousVersions.first;
    final previousHash = previousVersion['content_hash'] as String;
    final currentHash = await _calculateContentHash(belge.dosyaYolu);

    if (previousHash != currentHash) {
      return 'CONTENT_UPDATE';
    }

    final previousMetadataHash = previousVersion['metadata_hash'] as String;
    final currentMetadataHash = _hashComparator.generateMetadataHash(belge);

    if (previousMetadataHash != currentMetadataHash) {
      return 'METADATA_UPDATE';
    }

    return 'NO_CHANGE';
  }

  /// Değişen belgeleri al
  Future<List<Map<String, dynamic>>> getChangedDocuments({
    DateTime? since,
    String? cihazId,
    int? limit,
  }) async {
    final db = await _veriTabani.database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (since != null) {
      whereClause += ' AND olusturma_tarihi > ?';
      whereArgs.add(since.toIso8601String());
    }

    if (cihazId != null) {
      whereClause += ' AND cihaz_id = ?';
      whereArgs.add(cihazId);
    }

    return await db.query(
      'belge_versiyonlari',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'olusturma_tarihi DESC',
      limit: limit,
    );
  }

  /// Belge versiyonlarını karşılaştır
  Future<DocumentComparisonResult> compareDocumentVersions(
    BelgeModeli belge1,
    BelgeModeli belge2,
  ) async {
    final result = await _hashComparator.compareDocuments(belge1, belge2);

    return DocumentComparisonResult(
      isContentSame: result.isMatch,
      isMetadataSame: result.metadataHashMatch,
      hasConflict: !result.isMatch && result.metadataHashMatch,
      contentHash1: belge1.dosyaHash,
      contentHash2: belge2.dosyaHash,
      metadataHash1: _hashComparator.generateMetadataHash(belge1),
      metadataHash2: _hashComparator.generateMetadataHash(belge2),
      differences: _compareMetadata(belge1, belge2),
    );
  }

  /// Belge metadata'sını birleştir
  Future<BelgeModeli> mergeDocumentMetadata(
    BelgeModeli localBelge,
    BelgeModeli remoteBelge, {
    String mergeStrategy = 'LATEST_WINS',
  }) async {
    switch (mergeStrategy) {
      case 'LATEST_WINS':
        return _mergeLatestWins(localBelge, remoteBelge);
      case 'LOCAL_WINS':
        return localBelge;
      case 'REMOTE_WINS':
        return remoteBelge;
      case 'MANUAL':
        return _createMergeConflict(localBelge, remoteBelge);
      default:
        return _mergeLatestWins(localBelge, remoteBelge);
    }
  }

  /// En son güncellenen kazanır stratejisi
  BelgeModeli _mergeLatestWins(BelgeModeli local, BelgeModeli remote) {
    final localTime = local.guncellemeTarihi;
    final remoteTime = remote.guncellemeTarihi;

    if (remoteTime.isAfter(localTime)) {
      return remote.copyWith(id: local.id);
    } else {
      return local;
    }
  }

  /// Merge conflict oluştur
  BelgeModeli _createMergeConflict(BelgeModeli local, BelgeModeli remote) {
    return local.copyWith(
      aciklama:
          '${local.aciklama ?? ''}\n\n[CONFLICT]\nRemote: ${remote.aciklama ?? ''}',
    );
  }

  /// Belge versiyonlarını al
  Future<List<Map<String, dynamic>>> getDocumentVersions(int belgeId) async {
    final db = await _veriTabani.database;
    return await db.query(
      'belge_versiyonlari',
      where: 'belge_id = ?',
      whereArgs: [belgeId],
      orderBy: 'versiyon_numarasi DESC',
    );
  }

  /// Metadata değişikliklerini al
  Future<List<Map<String, dynamic>>> getMetadataChanges(int belgeId) async {
    final db = await _veriTabani.database;
    return await db.query(
      'metadata_degisiklikleri',
      where: 'belge_id = ?',
      whereArgs: [belgeId],
      orderBy: 'degisiklik_tarihi DESC',
    );
  }

  /// Eski versiyonları temizle
  Future<void> cleanupOldVersions({
    int? keepVersions,
    Duration? olderThan,
  }) async {
    final db = await _veriTabani.database;

    if (keepVersions != null) {
      // Her belge için belirli sayıda versiyon tut
      final belgeIds = await db.query('belgeler', columns: ['id']);

      for (final belgeMap in belgeIds) {
        final belgeId = belgeMap['id'] as int;

        await db.delete(
          'belge_versiyonlari',
          where: '''
            belge_id = ? AND versiyon_numarasi NOT IN (
              SELECT versiyon_numarasi 
              FROM belge_versiyonlari 
              WHERE belge_id = ? 
              ORDER BY versiyon_numarasi DESC 
              LIMIT ?
            )
          ''',
          whereArgs: [belgeId, belgeId, keepVersions],
        );
      }
    }

    if (olderThan != null) {
      final cutoffDate = DateTime.now().subtract(olderThan).toIso8601String();

      await db.delete(
        'belge_versiyonlari',
        where: 'olusturma_tarihi < ?',
        whereArgs: [cutoffDate],
      );

      await db.delete(
        'metadata_degisiklikleri',
        where: 'degisiklik_tarihi < ?',
        whereArgs: [cutoffDate],
      );
    }
  }

  /// Content hash hesaplama helper metodu
  Future<String> _calculateContentHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('Dosya bulunamadı', filePath);
      }

      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      throw Exception('Content hash hesaplama hatası: $e');
    }
  }
}

/// Belge karşılaştırma sonucu
class DocumentComparisonResult {
  final bool isContentSame;
  final bool isMetadataSame;
  final bool hasConflict;
  final String contentHash1;
  final String contentHash2;
  final String metadataHash1;
  final String metadataHash2;
  final List<Map<String, dynamic>> differences;

  DocumentComparisonResult({
    required this.isContentSame,
    required this.isMetadataSame,
    required this.hasConflict,
    required this.contentHash1,
    required this.contentHash2,
    required this.metadataHash1,
    required this.metadataHash2,
    required this.differences,
  });

  bool get isIdentical => isContentSame && isMetadataSame;
  bool get hasMetadataOnlyChanges => !isContentSame && isMetadataSame;
  bool get hasContentChanges => !isContentSame;
}
