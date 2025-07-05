import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
        dosya_hash TEXT NOT NULL,
        metadata_hash TEXT NOT NULL,
        versiyon_numarasi INTEGER NOT NULL,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL,
        baslik TEXT,
        aciklama TEXT,
        etiketler TEXT,
        kategori_id INTEGER,
        kisi_id INTEGER,
        change_type TEXT DEFAULT 'UPDATE',
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Metadata değişiklik logu tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata_degisiklikleri (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        degisiklik_tipi TEXT NOT NULL,
        eski_deger TEXT,
        yeni_deger TEXT,
        degisiklik_alani TEXT NOT NULL,
        degisiklik_zamani TEXT NOT NULL,
        cihaz_id TEXT,
        sync_edildi INTEGER DEFAULT 0,
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
      CREATE INDEX IF NOT EXISTS idx_metadata_degisiklikleri_entity_id 
      ON metadata_degisiklikleri(entity_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_metadata_degisiklikleri_zaman 
      ON metadata_degisiklikleri(degisiklik_zamani)
    ''');

    print('📝 DocumentChangeTracker initialized');
  }

  /// Belge değişikliklerini takip et
  Future<void> trackDocumentChanges(
    BelgeModeli eskiBelge,
    BelgeModeli yeniBelge,
    String? cihazId,
  ) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    // Değişiklikleri tespit et
    final degisiklikler = _detectChanges(eskiBelge, yeniBelge);

    if (degisiklikler.isEmpty) return;

    // Her değişiklik için log kaydı oluştur
    for (final degisiklik in degisiklikler) {
      await db.insert('metadata_degisiklikleri', {
        'entity_type': 'BELGE',
        'entity_id': yeniBelge.id,
        'degisiklik_tipi': degisiklik['type'] ?? '',
        'eski_deger': degisiklik['old_value'] ?? '',
        'yeni_deger': degisiklik['new_value'] ?? '',
        'degisiklik_zamani': now,
        'cihaz_id': cihazId,
        'sync_edildi': 0,
      });
    }

    // Versiyon kaydı oluştur
    await _createVersionRecord(yeniBelge, cihazId);
  }

  /// Değişiklikleri tespit et
  List<Map<String, dynamic>> _detectChanges(
    BelgeModeli eskiBelge,
    BelgeModeli yeniBelge,
  ) {
    final degisiklikler = <Map<String, dynamic>>[];

    // Başlık değişikliği
    if (eskiBelge.baslik != yeniBelge.baslik) {
      degisiklikler.add({
        'type': 'TITLE_CHANGE',
        'field': 'baslik',
        'old_value': eskiBelge.baslik ?? '',
        'new_value': yeniBelge.baslik ?? '',
      });
    }

    // Açıklama değişikliği
    if (eskiBelge.aciklama != yeniBelge.aciklama) {
      degisiklikler.add({
        'type': 'DESCRIPTION_CHANGE',
        'field': 'aciklama',
        'old_value': eskiBelge.aciklama ?? '',
        'new_value': yeniBelge.aciklama ?? '',
      });
    }

    // Etiket değişikliği
    if (eskiBelge.etiketler != yeniBelge.etiketler) {
      degisiklikler.add({
        'type': 'TAGS_CHANGE',
        'field': 'etiketler',
        'old_value': eskiBelge.etiketler?.join(',') ?? '',
        'new_value': yeniBelge.etiketler?.join(',') ?? '',
      });
    }

    // Kategori değişikliği
    if (eskiBelge.kategoriId != yeniBelge.kategoriId) {
      degisiklikler.add({
        'type': 'CATEGORY_CHANGE',
        'field': 'kategori_id',
        'old_value': eskiBelge.kategoriId?.toString() ?? '',
        'new_value': yeniBelge.kategoriId?.toString() ?? '',
      });
    }

    // Kişi değişikliği
    if (eskiBelge.kisiId != yeniBelge.kisiId) {
      degisiklikler.add({
        'type': 'PERSON_CHANGE',
        'field': 'kisi_id',
        'old_value': eskiBelge.kisiId?.toString() ?? '',
        'new_value': yeniBelge.kisiId?.toString() ?? '',
      });
    }

    return degisiklikler;
  }

  /// Versiyon kaydı oluştur
  Future<void> _createVersionRecord(BelgeModeli belge, String? cihazId) async {
    final db = await _veriTabani.database;
    final now = DateTime.now().toIso8601String();

    // Mevcut versiyon sayısını al
    final versionCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM belge_versiyonlari WHERE belge_id = ?',
      [belge.id],
    );

    final nextVersion = (versionCount.first['count'] as int) + 1;
    final metadataHash = _hashComparator.generateMetadataHash(belge);

    await db.insert('belge_versiyonlari', {
      'belge_id': belge.id,
      'dosya_hash': belge.dosyaHash,
      'metadata_hash': metadataHash,
      'versiyon_numarasi': nextVersion,
      'olusturma_tarihi': now,
      'guncelleme_tarihi': now,
      'baslik': belge.baslik,
      'aciklama': belge.aciklama,
      'etiketler': belge.etiketler,
      'kategori_id': belge.kategoriId,
      'kisi_id': belge.kisiId,
      'change_type': 'UPDATE',
    });
  }

  /// Belge versiyonlarını karşılaştır
  Future<Map<String, dynamic>> compareDocumentVersions(
    BelgeModeli localBelge,
    Map<String, dynamic> remoteMetadata,
  ) async {
    final localMetadataHash = _hashComparator.generateMetadataHash(localBelge);
    final remoteMetadataHash = remoteMetadata['metadata_hash'] ?? '';

    final result = {
      'needs_sync': localMetadataHash != remoteMetadataHash,
      'local_hash': localMetadataHash,
      'remote_hash': remoteMetadataHash,
      'conflict': false,
      'resolution': 'none',
    };

    if (result['needs_sync'] == true) {
      // Çakışma analizi
      final conflictAnalysis = await _analyzeConflict(
        localBelge,
        remoteMetadata,
      );
      result['conflict'] = conflictAnalysis['has_conflict'];
      result['resolution'] = conflictAnalysis['resolution'];
    }

    return result;
  }

  /// Çakışma analizi
  Future<Map<String, dynamic>> _analyzeConflict(
    BelgeModeli localBelge,
    Map<String, dynamic> remoteMetadata,
  ) async {
    final db = await _veriTabani.database;

    // Son değişiklik zamanlarını karşılaştır
    final localLastModified = localBelge.guncellemeTarihi;
    final remoteLastModifiedString =
        remoteMetadata['guncelleme_tarihi']?.toString() ??
        localBelge.guncellemeTarihi.toIso8601String();
    final remoteLastModified = DateTime.parse(remoteLastModifiedString);

    // Pending değişiklik var mı kontrol et
    final pendingChanges = await db.query(
      'metadata_degisiklikleri',
      where: 'entity_type = ? AND entity_id = ? AND sync_edildi = ?',
      whereArgs: ['BELGE', localBelge.id, 0],
    );

    final timeDiff = localLastModified.difference(remoteLastModified).inMinutes;
    final hasPendingChanges = pendingChanges.isNotEmpty;

    if (timeDiff.abs() < 5 && !hasPendingChanges) {
      // Yakın zamanda değişiklik, çakışma yok
      return {'has_conflict': false, 'resolution': 'merge'};
    } else if (localLastModified.isAfter(remoteLastModified)) {
      // Local daha yeni
      return {'has_conflict': hasPendingChanges, 'resolution': 'local_wins'};
    } else {
      // Remote daha yeni
      return {'has_conflict': hasPendingChanges, 'resolution': 'remote_wins'};
    }
  }

  /// Metadata'ları birleştir
  Future<BelgeModeli> mergeDocumentMetadata(
    BelgeModeli localBelge,
    Map<String, dynamic> remoteMetadata,
    String resolution,
  ) async {
    switch (resolution) {
      case 'local_wins':
        return localBelge;

      case 'remote_wins':
        return BelgeModeli(
          id: localBelge.id,
          dosyaAdi: localBelge.dosyaAdi,
          orijinalDosyaAdi: localBelge.orijinalDosyaAdi,
          dosyaYolu: localBelge.dosyaYolu,
          dosyaBoyutu: localBelge.dosyaBoyutu,
          dosyaTipi: localBelge.dosyaTipi,
          dosyaHash: localBelge.dosyaHash,
          baslik: remoteMetadata['baslik']?.toString(),
          aciklama: remoteMetadata['aciklama']?.toString(),
          etiketler: _parseEtiketler(remoteMetadata['etiketler']?.toString()),
          kategoriId: remoteMetadata['kategori_id'] as int?,
          kisiId: remoteMetadata['kisi_id'] as int?,
          olusturmaTarihi: localBelge.olusturmaTarihi,
          guncellemeTarihi: DateTime.parse(
            remoteMetadata['guncelleme_tarihi']?.toString() ??
                DateTime.now().toIso8601String(),
          ),
          sonErisimTarihi: localBelge.sonErisimTarihi,
          aktif: localBelge.aktif,
          senkronDurumu: localBelge.senkronDurumu,
        );

      case 'merge':
        // Akıllı birleştirme
        return _intelligentMerge(localBelge, remoteMetadata);

      default:
        return localBelge;
    }
  }

  /// Akıllı birleştirme
  BelgeModeli _intelligentMerge(
    BelgeModeli localBelge,
    Map<String, dynamic> remoteMetadata,
  ) {
    // Basit birleştirme stratejisi: boş olmayan değerleri tercih et
    return BelgeModeli(
      id: localBelge.id,
      dosyaAdi: localBelge.dosyaAdi,
      orijinalDosyaAdi: localBelge.orijinalDosyaAdi,
      dosyaYolu: localBelge.dosyaYolu,
      dosyaBoyutu: localBelge.dosyaBoyutu,
      dosyaTipi: localBelge.dosyaTipi,
      dosyaHash: localBelge.dosyaHash,
      baslik:
          (remoteMetadata['baslik']?.toString().isNotEmpty == true)
              ? remoteMetadata['baslik']?.toString()
              : localBelge.baslik,
      aciklama:
          (remoteMetadata['aciklama']?.toString().isNotEmpty == true)
              ? remoteMetadata['aciklama']?.toString()
              : localBelge.aciklama,
      etiketler: _mergeEtiketler(
        localBelge.etiketler,
        remoteMetadata['etiketler']?.toString(),
      ),
      kategoriId:
          remoteMetadata['kategori_id'] as int? ?? localBelge.kategoriId,
      kisiId: remoteMetadata['kisi_id'] as int? ?? localBelge.kisiId,
      olusturmaTarihi: localBelge.olusturmaTarihi,
      guncellemeTarihi: DateTime.now(),
      sonErisimTarihi: localBelge.sonErisimTarihi,
      aktif: localBelge.aktif,
      senkronDurumu: localBelge.senkronDurumu,
    );
  }

  /// Etiketleri string'den List<String>?'e çevir
  List<String>? _parseEtiketler(String? etiketlerString) {
    if (etiketlerString == null || etiketlerString.isEmpty) return null;
    return etiketlerString
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Etiketleri birleştir
  List<String>? _mergeEtiketler(
    List<String>? localEtiketler,
    String? remoteEtiketlerString,
  ) {
    final remoteEtiketler = _parseEtiketler(remoteEtiketlerString);

    if (localEtiketler == null && remoteEtiketler == null) return null;
    if (localEtiketler == null) return remoteEtiketler;
    if (remoteEtiketler == null) return localEtiketler;

    final localTagSet = localEtiketler.toSet();
    final remoteTagSet = remoteEtiketler.toSet();

    localTagSet.addAll(remoteTagSet);

    return localTagSet.where((tag) => tag.isNotEmpty).toList();
  }

  /// Etiketleri birleştir (deprecated - eskiyi desteklemek için)
  String? _mergeTags(String? localTags, String? remoteTags) {
    if (localTags == null && remoteTags == null) return null;
    if (localTags == null) return remoteTags;
    if (remoteTags == null) return localTags;

    final localTagList = localTags.split(',').map((e) => e.trim()).toSet();
    final remoteTagList = remoteTags.split(',').map((e) => e.trim()).toSet();

    localTagList.addAll(remoteTagList);

    return localTagList.where((tag) => tag.isNotEmpty).join(', ');
  }

  /// Dosyanın belirli tarihten beri değişip değişmediğini kontrol et
  Future<bool> hasChangedSince(String dosyaHash, DateTime since) async {
    final db = await _veriTabani.database;

    // Belge tablosundan son güncelleme zamanını kontrol et
    final belgeResult = await db.query(
      'belgeler',
      where: 'dosya_hash = ? AND guncelleme_tarihi > ?',
      whereArgs: [dosyaHash, since.toIso8601String()],
    );

    if (belgeResult.isNotEmpty) {
      return true;
    }

    // Metadata değişiklikleri tablosundan kontrol et
    final metadataResult = await db.query(
      'metadata_degisiklikleri',
      where: 'entity_type = ? AND degisiklik_zamani > ?',
      whereArgs: ['belge', since.toIso8601String()],
    );

    return metadataResult.isNotEmpty;
  }

  /// Değişen belgeleri getir
  Future<List<Map<String, dynamic>>> getChangedDocuments(
    DateTime since, {
    String? cihazId,
  }) async {
    final db = await _veriTabani.database;

    // Null argüman sorununu çöz
    final whereArgs = [since.toIso8601String(), 0];
    String whereClause = 'degisiklik_zamani > ? AND sync_edildi = ?';

    if (cihazId != null) {
      whereClause += ' AND cihaz_id = ?';
      whereArgs.add(cihazId);
    }

    return await db.query(
      'metadata_degisiklikleri',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'degisiklik_zamani DESC',
    );
  }

  /// Değişiklikleri senkronize edildi olarak işaretle
  Future<void> markChangesAsSynced(List<int> changeIds) async {
    final db = await _veriTabani.database;

    for (final id in changeIds) {
      await db.update(
        'metadata_degisiklikleri',
        {'sync_edildi': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Eski değişiklik kayıtlarını temizle
  Future<void> cleanOldChangeRecords() async {
    final db = await _veriTabani.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));

    await db.delete(
      'metadata_degisiklikleri',
      where: 'degisiklik_zamani < ? AND sync_edildi = ?',
      whereArgs: [cutoffDate.toIso8601String(), 1],
    );
  }

  /// Değişiklikleri commit et
  Future<void> commitChanges(String deviceId) async {
    try {
      // Son 1 saat içindeki değişiklikleri commit et
      final since = DateTime.now().subtract(const Duration(hours: 1));
      final pendingChanges = await _veriTabani.sonDegisiklikleriGetir(since);

      for (final change in pendingChanges) {
        // Belgenin metadata'sını güncelle
        await _veriTabani.metadataGuncelle(
          change['id'],
          change['baslik'],
          change['aciklama'],
          change['etiketler'],
          'committed_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      print('Değişiklikler commit edildi: ${pendingChanges.length} adet');
    } catch (e) {
      print('Değişiklikler commit edilemedi: $e');
    }
  }
}
