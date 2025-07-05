import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../utils/hash_comparator.dart';
import '../utils/timestamp_manager.dart';

/// Dosya versiyon türleri
enum FileVersionType { creation, update, metadata, content, conflict, merge }

/// Dosya versiyon snapshot'u
class FileVersionSnapshot {
  final String snapshotId;
  final int belgeId;
  final String contentHash;
  final String metadataHash;
  final String compositeHash;
  final DateTime timestamp;
  final FileVersionType type;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> content;
  final String? parentSnapshotId;
  final String? deviceId;
  final int versionNumber;

  FileVersionSnapshot({
    required this.snapshotId,
    required this.belgeId,
    required this.contentHash,
    required this.metadataHash,
    required this.compositeHash,
    required this.timestamp,
    required this.type,
    required this.metadata,
    required this.content,
    this.parentSnapshotId,
    this.deviceId,
    required this.versionNumber,
  });

  Map<String, dynamic> toJson() => {
    'snapshotId': snapshotId,
    'belgeId': belgeId,
    'contentHash': contentHash,
    'metadataHash': metadataHash,
    'compositeHash': compositeHash,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'metadata': metadata,
    'content': content,
    'parentSnapshotId': parentSnapshotId,
    'deviceId': deviceId,
    'versionNumber': versionNumber,
  };

  factory FileVersionSnapshot.fromJson(Map<String, dynamic> json) {
    return FileVersionSnapshot(
      snapshotId: json['snapshotId'],
      belgeId: json['belgeId'],
      contentHash: json['contentHash'],
      metadataHash: json['metadataHash'],
      compositeHash: json['compositeHash'],
      timestamp: DateTime.parse(json['timestamp']),
      type: FileVersionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FileVersionType.update,
      ),
      metadata: json['metadata'],
      content: json['content'],
      parentSnapshotId: json['parentSnapshotId'],
      deviceId: json['deviceId'],
      versionNumber: json['versionNumber'],
    );
  }
}

/// Dosya değişiklik detayı
class FileVersionDiff {
  final String diffId;
  final String fromSnapshotId;
  final String toSnapshotId;
  final List<Map<String, dynamic>> metadataChanges;
  final List<Map<String, dynamic>> contentChanges;
  final FileVersionType changeType;
  final DateTime timestamp;

  FileVersionDiff({
    required this.diffId,
    required this.fromSnapshotId,
    required this.toSnapshotId,
    required this.metadataChanges,
    required this.contentChanges,
    required this.changeType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'diffId': diffId,
    'fromSnapshotId': fromSnapshotId,
    'toSnapshotId': toSnapshotId,
    'metadataChanges': metadataChanges,
    'contentChanges': contentChanges,
    'changeType': changeType.name,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Gelişmiş dosya versiyon yöneticisi
class FileVersionManager {
  static final FileVersionManager _instance = FileVersionManager._internal();
  static FileVersionManager get instance => _instance;
  FileVersionManager._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  /// Versiyon yönetimi tablolarını oluştur
  Future<void> initializeVersionManagement() async {
    final db = await _veriTabani.database;

    // Dosya versiyon snapshot'ları
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_version_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_id TEXT NOT NULL UNIQUE,
        belge_id INTEGER NOT NULL,
        content_hash TEXT NOT NULL,
        metadata_hash TEXT NOT NULL,
        composite_hash TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        version_type TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        content_json TEXT NOT NULL,
        parent_snapshot_id TEXT,
        device_id TEXT,
        version_number INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Versiyon diff'leri
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_version_diffs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        diff_id TEXT NOT NULL UNIQUE,
        from_snapshot_id TEXT NOT NULL,
        to_snapshot_id TEXT NOT NULL,
        metadata_changes TEXT NOT NULL,
        content_changes TEXT NOT NULL,
        change_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Versiyon trees (parent-child ilişkileri)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_version_trees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        snapshot_id TEXT NOT NULL,
        parent_snapshot_id TEXT,
        depth INTEGER NOT NULL,
        branch_name TEXT DEFAULT 'main',
        is_head INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // İndeksler
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_version_snapshots_belge_id 
      ON file_version_snapshots(belge_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_version_snapshots_composite_hash 
      ON file_version_snapshots(composite_hash)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_version_trees_belge_id 
      ON file_version_trees(belge_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_file_version_trees_head 
      ON file_version_trees(is_head)
    ''');

    print('📂 FileVersionManager initialized');
  }

  /// Dosya snapshot'ı oluştur
  Future<FileVersionSnapshot> createFileSnapshot(
    BelgeModeli belge,
    FileVersionType type, {
    String? deviceId,
    String? parentSnapshotId,
  }) async {
    final now = DateTime.now();
    final snapshotId = '${belge.id}_${now.millisecondsSinceEpoch}';

    // Metadata ve content hash'lerini hesapla
    final metadataHash = _hashComparator.generateMetadataHash(belge);
    final contentHash = belge.dosyaHash;
    final compositeHash = _generateCompositeHash(metadataHash, contentHash);

    // Versiyon numarasını hesapla
    final versionNumber = await _getNextVersionNumber(belge.id ?? 0);

    // Metadata bilgilerini topla
    final metadata = {
      'baslik': belge.baslik,
      'aciklama': belge.aciklama,
      'etiketler': belge.etiketler,
      'kategori_id': belge.kategoriId,
      'kisi_id': belge.kisiId,
      'dosya_adi': belge.dosyaAdi,
      'dosya_boyutu': belge.dosyaBoyutu,
      'dosya_tipi': belge.dosyaTipi,
      'olusturma_tarihi': belge.olusturmaTarihi,
      'guncelleme_tarihi': belge.guncellemeTarihi,
    };

    // Content bilgilerini topla
    final content = {
      'dosya_yolu': belge.dosyaYolu,
      'dosya_hash': belge.dosyaHash,
      'dosya_boyutu': belge.dosyaBoyutu,
      'mime_type': _getMimeType(belge.dosyaTipi),
    };

    // Dosya var mı kontrol et
    if (belge.dosyaYolu != null) {
      final file = File(belge.dosyaYolu!);
      if (await file.exists()) {
        final stats = await file.stat();
        content['file_size'] = stats.size;
        content['modified_time'] = stats.modified.toIso8601String();
      }
    }

    final snapshot = FileVersionSnapshot(
      snapshotId: snapshotId,
      belgeId: belge.id ?? 0,
      contentHash: contentHash,
      metadataHash: metadataHash,
      compositeHash: compositeHash,
      timestamp: now,
      type: type,
      metadata: metadata,
      content: content,
      parentSnapshotId: parentSnapshotId,
      deviceId: deviceId,
      versionNumber: versionNumber,
    );

    // Veritabanına kaydet
    await _saveSnapshot(snapshot);

    // Version tree'yi güncelle
    await _updateVersionTree(snapshot);

    return snapshot;
  }

  /// İki versiyon arası karşılaştırma
  Future<FileVersionDiff> compareVersions(
    String fromSnapshotId,
    String toSnapshotId,
  ) async {
    final fromSnapshot = await _getSnapshot(fromSnapshotId);
    final toSnapshot = await _getSnapshot(toSnapshotId);

    if (fromSnapshot == null || toSnapshot == null) {
      throw Exception('Snapshot bulunamadı');
    }

    final diffId = 'diff_${fromSnapshotId}_${toSnapshotId}';
    final now = DateTime.now();

    // Metadata değişikliklerini tespit et
    final metadataChanges = <Map<String, dynamic>>[];
    fromSnapshot.metadata.forEach((key, oldValue) {
      final newValue = toSnapshot.metadata[key];
      if (oldValue != newValue) {
        metadataChanges.add({
          'field': key,
          'old_value': oldValue,
          'new_value': newValue,
          'change_type': 'MODIFIED',
        });
      }
    });

    // Yeni metadata field'ları
    toSnapshot.metadata.forEach((key, newValue) {
      if (!fromSnapshot.metadata.containsKey(key)) {
        metadataChanges.add({
          'field': key,
          'old_value': null,
          'new_value': newValue,
          'change_type': 'ADDED',
        });
      }
    });

    // Content değişikliklerini tespit et
    final contentChanges = <Map<String, dynamic>>[];
    if (fromSnapshot.contentHash != toSnapshot.contentHash) {
      contentChanges.add({
        'field': 'content',
        'old_hash': fromSnapshot.contentHash,
        'new_hash': toSnapshot.contentHash,
        'change_type': 'CONTENT_MODIFIED',
      });
    }

    // Dosya boyutu değişikliği
    final oldSize = fromSnapshot.content['dosya_boyutu'] ?? 0;
    final newSize = toSnapshot.content['dosya_boyutu'] ?? 0;
    if (oldSize != newSize) {
      contentChanges.add({
        'field': 'file_size',
        'old_value': oldSize,
        'new_value': newSize,
        'change_type': 'SIZE_CHANGED',
      });
    }

    // Değişiklik tipini belirle
    final changeType = _determineChangeType(metadataChanges, contentChanges);

    final diff = FileVersionDiff(
      diffId: diffId,
      fromSnapshotId: fromSnapshotId,
      toSnapshotId: toSnapshotId,
      metadataChanges: metadataChanges,
      contentChanges: contentChanges,
      changeType: changeType,
      timestamp: now,
    );

    // Diff'i kaydet
    await _saveDiff(diff);

    return diff;
  }

  /// Değişiklikleri birleştir
  Future<BelgeModeli> mergeChanges(
    BelgeModeli baseBelge,
    List<FileVersionDiff> diffs, {
    String? strategy = 'LATEST_WINS',
  }) async {
    var mergedBelge = baseBelge.copyWith();

    for (final diff in diffs) {
      // Metadata değişikliklerini uygula
      for (final change in diff.metadataChanges) {
        await _applyMetadataChange(mergedBelge, change, strategy);
      }

      // Content değişikliklerini uygula
      for (final change in diff.contentChanges) {
        await _applyContentChange(mergedBelge, change, strategy);
      }
    }

    return mergedBelge;
  }

  /// Dosya için son snapshot'ı al
  Future<FileVersionSnapshot?> getLatestSnapshot(int belgeId) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'file_version_snapshots',
      where: 'belge_id = ?',
      whereArgs: [belgeId],
      orderBy: 'version_number DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;

    return _snapshotFromDbRow(result.first);
  }

  /// Dosya için tüm snapshot'ları al
  Future<List<FileVersionSnapshot>> getAllSnapshots(int belgeId) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'file_version_snapshots',
      where: 'belge_id = ?',
      whereArgs: [belgeId],
      orderBy: 'version_number ASC',
    );

    return result.map((row) => _snapshotFromDbRow(row)).toList();
  }

  /// Composite hash oluştur
  String _generateCompositeHash(String metadataHash, String contentHash) {
    final combined = '$metadataHash:$contentHash';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Sonraki versiyon numarasını al
  Future<int> _getNextVersionNumber(int belgeId) async {
    final db = await _veriTabani.database;

    final result = await db.rawQuery(
      'SELECT MAX(version_number) as max_version FROM file_version_snapshots WHERE belge_id = ?',
      [belgeId],
    );

    final maxVersion = result.first['max_version'] as int? ?? 0;
    return maxVersion + 1;
  }

  /// MIME type'ı belirle
  String _getMimeType(String? uzanti) {
    if (uzanti == null) return 'application/octet-stream';

    final mimeTypes = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };

    return mimeTypes[uzanti.toLowerCase()] ?? 'application/octet-stream';
  }

  /// Snapshot'ı kaydet
  Future<void> _saveSnapshot(FileVersionSnapshot snapshot) async {
    final db = await _veriTabani.database;

    await db.insert('file_version_snapshots', {
      'snapshot_id': snapshot.snapshotId,
      'belge_id': snapshot.belgeId,
      'content_hash': snapshot.contentHash,
      'metadata_hash': snapshot.metadataHash,
      'composite_hash': snapshot.compositeHash,
      'timestamp': snapshot.timestamp.toIso8601String(),
      'version_type': snapshot.type.name,
      'metadata_json': json.encode(snapshot.metadata),
      'content_json': json.encode(snapshot.content),
      'parent_snapshot_id': snapshot.parentSnapshotId,
      'device_id': snapshot.deviceId,
      'version_number': snapshot.versionNumber,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Snapshot'ı getir
  Future<FileVersionSnapshot?> _getSnapshot(String snapshotId) async {
    final db = await _veriTabani.database;

    final result = await db.query(
      'file_version_snapshots',
      where: 'snapshot_id = ?',
      whereArgs: [snapshotId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return _snapshotFromDbRow(result.first);
  }

  /// Database row'undan snapshot oluştur
  FileVersionSnapshot _snapshotFromDbRow(Map<String, dynamic> row) {
    return FileVersionSnapshot(
      snapshotId: row['snapshot_id'],
      belgeId: row['belge_id'],
      contentHash: row['content_hash'],
      metadataHash: row['metadata_hash'],
      compositeHash: row['composite_hash'],
      timestamp: DateTime.parse(row['timestamp']),
      type: FileVersionType.values.firstWhere(
        (t) => t.name == row['version_type'],
        orElse: () => FileVersionType.update,
      ),
      metadata: json.decode(row['metadata_json']),
      content: json.decode(row['content_json']),
      parentSnapshotId: row['parent_snapshot_id'],
      deviceId: row['device_id'],
      versionNumber: row['version_number'],
    );
  }

  /// Diff'i kaydet
  Future<void> _saveDiff(FileVersionDiff diff) async {
    final db = await _veriTabani.database;

    await db.insert('file_version_diffs', {
      'diff_id': diff.diffId,
      'from_snapshot_id': diff.fromSnapshotId,
      'to_snapshot_id': diff.toSnapshotId,
      'metadata_changes': json.encode(diff.metadataChanges),
      'content_changes': json.encode(diff.contentChanges),
      'change_type': diff.changeType.name,
      'timestamp': diff.timestamp.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Version tree'yi güncelle
  Future<void> _updateVersionTree(FileVersionSnapshot snapshot) async {
    final db = await _veriTabani.database;

    // Önceki head'i güncelle
    await db.update(
      'file_version_trees',
      {'is_head': 0},
      where: 'belge_id = ? AND is_head = 1',
      whereArgs: [snapshot.belgeId],
    );

    // Depth hesapla
    int depth = 0;
    if (snapshot.parentSnapshotId != null) {
      final parentResult = await db.query(
        'file_version_trees',
        where: 'snapshot_id = ?',
        whereArgs: [snapshot.parentSnapshotId],
      );

      if (parentResult.isNotEmpty) {
        depth = (parentResult.first['depth'] as int) + 1;
      }
    }

    // Yeni head ekle
    await db.insert('file_version_trees', {
      'belge_id': snapshot.belgeId,
      'snapshot_id': snapshot.snapshotId,
      'parent_snapshot_id': snapshot.parentSnapshotId,
      'depth': depth,
      'branch_name': 'main',
      'is_head': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Değişiklik tipini belirle
  FileVersionType _determineChangeType(
    List<Map<String, dynamic>> metadataChanges,
    List<Map<String, dynamic>> contentChanges,
  ) {
    if (contentChanges.isNotEmpty && metadataChanges.isNotEmpty) {
      return FileVersionType.update;
    } else if (contentChanges.isNotEmpty) {
      return FileVersionType.content;
    } else if (metadataChanges.isNotEmpty) {
      return FileVersionType.metadata;
    }
    return FileVersionType.update;
  }

  /// Metadata değişikliğini uygula
  Future<void> _applyMetadataChange(
    BelgeModeli belge,
    Map<String, dynamic> change,
    String? strategy,
  ) async {
    final field = change['field'];
    final newValue = change['new_value'];

    switch (field) {
      case 'baslik':
        belge.baslik = newValue;
        break;
      case 'aciklama':
        belge.aciklama = newValue;
        break;
      case 'etiketler':
        if (newValue is List) {
          belge.etiketler = List<String>.from(newValue);
        }
        break;
      case 'kategori_id':
        belge.kategoriId = newValue;
        break;
      case 'kisi_id':
        belge.kisiId = newValue;
        break;
    }
  }

  /// Content değişikliğini uygula
  Future<void> _applyContentChange(
    BelgeModeli belge,
    Map<String, dynamic> change,
    String? strategy,
  ) async {
    final field = change['field'];
    final newValue = change['new_value'];

    switch (field) {
      case 'file_size':
        belge.dosyaBoyutu = newValue;
        break;
      case 'content':
        belge.dosyaHash = change['new_hash'];
        break;
    }
  }
}
