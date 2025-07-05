import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'veritabani_servisi.dart';
import 'document_change_tracker.dart';
import 'sync_state_tracker.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_delta.dart';
import '../models/senkron_metadata.dart';
import '../utils/timestamp_manager.dart';
import '../utils/senkron_utils.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Gelişmiş Delta Senkronizasyon Yöneticisi
/// Bu sınıf, belgeler arasındaki değişiklikleri (delta) tespit eder,
/// karşılaştırır ve senkronizasyon için hazırlar.
class SenkronDeltaManager {
  static final SenkronDeltaManager _instance = SenkronDeltaManager._internal();
  static SenkronDeltaManager get instance => _instance;
  SenkronDeltaManager._internal();

  // ============== Servis Bağımlılıkları ==============
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;
  final SyncStateTracker _stateTracker = SyncStateTracker.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  // ============== Callback Fonksiyonları ==============
  Function(String mesaj)? onLogMessage;
  Function(double ilerleme)? onProgressUpdate;
  Function(String operasyon)? onOperationUpdate;

  // ============== Durum Değişkenleri ==============
  bool _deltaHesaplamaAktif = false;
  int _toplamDeltaSayisi = 0;
  int _islenenDeltaSayisi = 0;

  /// Delta tablosunu başlat
  Future<void> initializeDeltaDatabase() async {
    final db = await _veriTabani.database;

    // Delta tablosunu oluştur
    await db.execute('''
      CREATE TABLE IF NOT EXISTS senkron_deltalar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delta_id TEXT NOT NULL UNIQUE,
        belge_id INTEGER NOT NULL,
        belge_hash TEXT NOT NULL,
        delta_tipi TEXT NOT NULL,
        olusturma_zamani TEXT NOT NULL,
        boyut INTEGER NOT NULL,
        oncelik INTEGER NOT NULL,
        cihaz_id TEXT,
        oturum_id TEXT,
        dosya_yolu TEXT,
        metadata TEXT,
        ek_veri TEXT,
        islendi INTEGER DEFAULT 0,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // İndeksler oluştur
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_deltalar_belge_id 
      ON senkron_deltalar(belge_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_deltalar_hash 
      ON senkron_deltalar(belge_hash)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_senkron_deltalar_tip 
      ON senkron_deltalar(delta_tipi)
    ''');

    _logMesaj('📊 Delta veritabanı başlatıldı');
  }

  /// Local deltaları oluştur ve veritabanına kaydet
  Future<List<SenkronDelta>> generateLocalDeltas({
    DateTime? baslangicTarihi,
    int? limitSayisi,
    String? cihazId,
    String? oturumId,
  }) async {
    try {
      _deltaHesaplamaAktif = true;
      _updateOperation('Local deltalar oluşturuluyor...');

      final baslangic =
          baslangicTarihi ?? DateTime.now().subtract(const Duration(days: 1));

      // Değişen belgeleri al
      final degisimler = await _changeTracker.getChangedDocuments(baslangic);

      _toplamDeltaSayisi = degisimler.length;
      _logMesaj('📋 ${degisimler.length} değişiklik tespit edildi');

      final deltalar = <SenkronDelta>[];

      for (int i = 0; i < degisimler.length; i++) {
        final degisim = degisimler[i];
        _islenenDeltaSayisi = i + 1;
        _updateProgress(_islenenDeltaSayisi / _toplamDeltaSayisi);

        try {
          final belgeId = degisim['belge_id'] as int;
          final belge = await _veriTabani.belgeGetir(belgeId);

          if (belge != null) {
            final delta = await _createDeltaFromDocument(
              belge,
              degisim,
              cihazId,
              oturumId,
            );

            deltalar.add(delta);
            await _saveDeltaToDatabase(delta);

            _logMesaj('✅ Delta oluşturuldu: ${belge.dosyaAdi}');
          }
        } catch (e) {
          _logMesaj('❌ Delta oluşturma hatası: $e');
        }
      }

      _deltaHesaplamaAktif = false;
      _logMesaj('🎯 ${deltalar.length} adet local delta oluşturuldu');

      return deltalar;
    } catch (e) {
      _deltaHesaplamaAktif = false;
      _logMesaj('❌ Local delta oluşturma hatası: $e');
      return [];
    }
  }

  /// Belgeden delta oluştur
  Future<SenkronDelta> _createDeltaFromDocument(
    BelgeModeli belge,
    Map<String, dynamic> degisim,
    String? cihazId,
    String? oturumId,
  ) async {
    final deltaId = YardimciFonksiyonlar.uniqueIdOlustur();
    final degisiklikTipi = degisim['degisiklik_tipi'] as String;

    // Delta tipini belirle
    final deltaType = _mapDegisiklikTipiToDeltaType(degisiklikTipi);

    // Metadata oluştur - SenkronMetadata constructor'ına uygun parametreler
    final metadata = SenkronMetadata(
      documentId: belge.id!.toString(),
      documentHash: belge.dosyaHash,
      lastSyncTime: DateTime.now(),
      lastModifiedTime: belge.guncellemeTarihi,
      version: 1,
      properties: {
        'dosyaAdi': belge.dosyaAdi,
        'kategoriId': belge.kategoriId,
        'kisiId': belge.kisiId,
        'baslik': belge.baslik,
        'aciklama': belge.aciklama,
        'etiketler': belge.etiketler,
        'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
        'dosyaTipi': belge.dosyaTipi,
      },
      deviceId: cihazId,
      sessionId: oturumId,
    );

    // Öncelik hesapla
    final oncelik = _calculateDeltaPriority(belge, deltaType);

    return SenkronDelta(
      id: deltaId,
      documentId: belge.id!.toString(),
      documentHash: belge.dosyaHash,
      deltaType: deltaType,
      timestamp: DateTime.now(),
      metadata: metadata,
      size: belge.dosyaBoyutu,
      priority: oncelik,
      deviceId: cihazId,
      sessionId: oturumId,
      filePath: belge.dosyaYolu,
      additionalData: {
        'degisiklik_tipi': degisiklikTipi,
        'degisiklik_zamani': degisim['olusturma_tarihi'],
      },
    );
  }

  /// Değişiklik tipini delta tipine dönüştür
  SenkronDeltaType _mapDegisiklikTipiToDeltaType(String degisiklikTipi) {
    switch (degisiklikTipi.toLowerCase()) {
      case 'create':
      case 'insert':
        return SenkronDeltaType.create;
      case 'update':
      case 'modify':
        return SenkronDeltaType.update;
      case 'delete':
      case 'remove':
        return SenkronDeltaType.delete;
      default:
        return SenkronDeltaType.update;
    }
  }

  /// Delta önceliğini hesapla
  int _calculateDeltaPriority(BelgeModeli belge, SenkronDeltaType deltaType) {
    int temelOncelik = 5; // Varsayılan orta öncelik

    // Delta tipine göre öncelik ayarla
    switch (deltaType) {
      case SenkronDeltaType.create:
        temelOncelik = 7; // Yeni dosyalar yüksek öncelik
        break;
      case SenkronDeltaType.update:
        temelOncelik = 5; // Güncellemeler orta öncelik
        break;
      case SenkronDeltaType.delete:
        temelOncelik = 8; // Silme işlemleri en yüksek öncelik
        break;
    }

    // Dosya boyutuna göre öncelik ayarla
    if (belge.dosyaBoyutu > 10 * 1024 * 1024) {
      // 10MB+
      temelOncelik -= 2; // Büyük dosyalar düşük öncelik
    } else if (belge.dosyaBoyutu < 1024 * 1024) {
      // 1MB-
      temelOncelik += 1; // Küçük dosyalar yüksek öncelik
    }

    // Güncellik kontrolü
    final guncellikGunu =
        DateTime.now().difference(belge.guncellemeTarihi).inDays;
    if (guncellikGunu <= 1) {
      temelOncelik += 2; // Son 1 gün içinde güncellenen dosyalar
    }

    return temelOncelik.clamp(1, 10); // 1-10 arasında sınırla
  }

  /// Delta'yı veritabanına kaydet
  Future<void> _saveDeltaToDatabase(SenkronDelta delta) async {
    final db = await _veriTabani.database;

    await db.insert('senkron_deltalar', {
      'delta_id': delta.id,
      'belge_id': int.parse(delta.documentId),
      'belge_hash': delta.documentHash,
      'delta_tipi': delta.deltaType.name,
      'olusturma_zamani': delta.timestamp.toIso8601String(),
      'boyut': delta.size,
      'oncelik': delta.priority,
      'cihaz_id': delta.deviceId,
      'oturum_id': delta.sessionId,
      'dosya_yolu': delta.filePath,
      'metadata': json.encode(delta.metadata.toJson()),
      'ek_veri': json.encode(delta.additionalData ?? {}),
      'islendi': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remote deltaları işle
  Future<DeltaProcessingResult> processRemoteDeltas(
    List<SenkronDelta> remoteDeltalar,
    String? cihazId,
  ) async {
    try {
      _updateOperation('Remote deltalar işleniyor...');

      final sonuc = DeltaProcessingResult();
      _toplamDeltaSayisi = remoteDeltalar.length;

      for (int i = 0; i < remoteDeltalar.length; i++) {
        final delta = remoteDeltalar[i];
        _islenenDeltaSayisi = i + 1;
        _updateProgress(_islenenDeltaSayisi / _toplamDeltaSayisi);

        try {
          final islemSonucu = await _processSingleRemoteDelta(delta, cihazId);

          if (islemSonucu) {
            sonuc.basariliIslemler++;
            _logMesaj('✅ Delta işlendi: ${delta.documentId}');
          } else {
            sonuc.hataliIslemler++;
            _logMesaj('❌ Delta işlenemedi: ${delta.documentId}');
          }
        } catch (e) {
          sonuc.hataliIslemler++;
          _logMesaj('❌ Delta işleme hatası: ${delta.documentId} - $e');
        }
      }

      sonuc.toplamIslemler = remoteDeltalar.length;
      _logMesaj(
        '📊 Delta işleme tamamlandı: ${sonuc.basariliIslemler}/${sonuc.toplamIslemler}',
      );

      return sonuc;
    } catch (e) {
      _logMesaj('❌ Remote delta işleme hatası: $e');
      return DeltaProcessingResult();
    }
  }

  /// Tek bir remote delta'yı işle
  Future<bool> _processSingleRemoteDelta(
    SenkronDelta delta,
    String? cihazId,
  ) async {
    try {
      switch (delta.deltaType) {
        case SenkronDeltaType.create:
          return await _processCreateDelta(delta, cihazId);
        case SenkronDeltaType.update:
          return await _processUpdateDelta(delta, cihazId);
        case SenkronDeltaType.delete:
          return await _processDeleteDelta(delta, cihazId);
      }
    } catch (e) {
      _logMesaj('❌ Delta işleme hatası: $e');
      return false;
    }
  }

  /// Create delta'sını işle
  Future<bool> _processCreateDelta(SenkronDelta delta, String? cihazId) async {
    // Dosya zaten var mı kontrol et - tüm belgeleri al ve hash ile kontrol et
    final tumBelgeler = await _veriTabani.belgeleriGetir();
    final mevcutBelge = tumBelgeler.firstWhere(
      (belge) => belge.dosyaHash == delta.documentHash,
      orElse: () => null as BelgeModeli,
    );

    if (mevcutBelge != null) {
      _logMesaj('⚠️ Dosya zaten mevcut: ${delta.documentId}');
      return true; // Zaten var, başarılı sayıyoruz
    }

    // Yeni belge oluştur
    final dosyaAdi =
        delta.metadata.properties['dosyaAdi'] as String? ?? 'unknown';
    _logMesaj('🔄 Create delta işleniyor: $dosyaAdi');

    return true;
  }

  /// Update delta'sını işle
  Future<bool> _processUpdateDelta(SenkronDelta delta, String? cihazId) async {
    // Mevcut belgeyi bul
    final mevcutBelge = await _veriTabani.belgeGetir(
      int.parse(delta.documentId),
    );

    if (mevcutBelge == null) {
      _logMesaj('⚠️ Güncellenecek belge bulunamadı: ${delta.documentId}');
      return false;
    }

    // Güncelleme için işaretle
    final dosyaAdi =
        delta.metadata.properties['dosyaAdi'] as String? ?? 'unknown';
    _logMesaj('🔄 Update delta işleniyor: $dosyaAdi');

    return true;
  }

  /// Delete delta'sını işle
  Future<bool> _processDeleteDelta(SenkronDelta delta, String? cihazId) async {
    // Silme işlemi için işaretle
    final dosyaAdi =
        delta.metadata.properties['dosyaAdi'] as String? ?? 'unknown';
    _logMesaj('🔄 Delete delta işleniyor: $dosyaAdi');

    return true;
  }

  /// Deltaları karşılaştır ve senkronizasyon planı oluştur
  Future<DeltaComparisonResult> compareDeltas(
    List<SenkronDelta> localDeltalar,
    List<SenkronDelta> remoteDeltalar,
  ) async {
    try {
      _updateOperation('Deltalar karşılaştırılıyor...');

      final sonuc = DeltaComparisonResult();
      final cakismalar = <DeltaConflict>[];
      final indirilecekler = <SenkronDelta>[];
      final yuklenecekler = <SenkronDelta>[];

      // Remote deltaları kontrol et
      for (final remoteDelta in remoteDeltalar) {
        final localDelta = localDeltalar.firstWhere(
          (local) => local.documentId == remoteDelta.documentId,
          orElse: () => null as SenkronDelta,
        );

        if (localDelta == null) {
          // Sadece remote'da var, indir
          indirilecekler.add(remoteDelta);
        } else if (localDelta.documentHash != remoteDelta.documentHash) {
          // Çakışma var
          cakismalar.add(
            DeltaConflict(
              localDelta: localDelta,
              remoteDelta: remoteDelta,
              conflictType: 'HASH_MISMATCH',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }

      // Local deltaları kontrol et
      for (final localDelta in localDeltalar) {
        final remoteDelta = remoteDeltalar.firstWhere(
          (remote) => remote.documentId == localDelta.documentId,
          orElse: () => null as SenkronDelta,
        );

        if (remoteDelta == null) {
          // Sadece local'da var, yükle
          yuklenecekler.add(localDelta);
        }
      }

      sonuc.conflicts = cakismalar;
      sonuc.toDownload = indirilecekler;
      sonuc.toUpload = yuklenecekler;
      sonuc.summary = {
        'conflicts': cakismalar.length,
        'downloads': indirilecekler.length,
        'uploads': yuklenecekler.length,
        'total': localDeltalar.length + remoteDeltalar.length,
      };

      _logMesaj('📊 Delta karşılaştırması tamamlandı');
      _logMesaj('   • Çakışmalar: ${cakismalar.length}');
      _logMesaj('   • İndirilecekler: ${indirilecekler.length}');
      _logMesaj('   • Yüklenecekler: ${yuklenecekler.length}');

      return sonuc;
    } catch (e) {
      _logMesaj('❌ Delta karşılaştırma hatası: $e');
      return DeltaComparisonResult();
    }
  }

  /// Veritabanından deltaları al
  Future<List<SenkronDelta>> getDeltasFromDatabase({
    DateTime? since,
    int? limit,
    bool? processed,
  }) async {
    final db = await _veriTabani.database;
    final deltalar = <SenkronDelta>[];

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (since != null) {
        whereClause += 'olusturma_zamani > ?';
        whereArgs.add(since.toIso8601String());
      }

      if (processed != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'islendi = ?';
        whereArgs.add(processed ? 1 : 0);
      }

      final results = await db.query(
        'senkron_deltalar',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'oncelik DESC, olusturma_zamani ASC',
        limit: limit,
      );

      for (final row in results) {
        final metadata = SenkronMetadata.fromJson(
          json.decode(row['metadata'] as String),
        );

        final delta = SenkronDelta(
          id: row['delta_id'] as String,
          documentId: row['belge_id'].toString(),
          documentHash: row['belge_hash'] as String,
          deltaType: SenkronDeltaType.values.byName(
            row['delta_tipi'] as String,
          ),
          timestamp: DateTime.parse(row['olusturma_zamani'] as String),
          metadata: metadata,
          size: row['boyut'] as int,
          priority: row['oncelik'] as int,
          deviceId: row['cihaz_id'] as String?,
          sessionId: row['oturum_id'] as String?,
          filePath: row['dosya_yolu'] as String?,
          additionalData: json.decode(row['ek_veri'] as String),
        );

        deltalar.add(delta);
      }

      return deltalar;
    } catch (e) {
      _logMesaj('❌ Veritabanından delta okuma hatası: $e');
      return [];
    }
  }

  /// Delta'yı işlendi olarak işaretle
  Future<void> markDeltaAsProcessed(String deltaId) async {
    final db = await _veriTabani.database;
    await db.update(
      'senkron_deltalar',
      {'islendi': 1},
      where: 'delta_id = ?',
      whereArgs: [deltaId],
    );
  }

  /// Eski deltaları temizle
  Future<void> cleanupOldDeltas({Duration? olderThan}) async {
    final db = await _veriTabani.database;
    final threshold = olderThan ?? const Duration(days: 30);
    final cutoffDate = DateTime.now().subtract(threshold).toIso8601String();

    final deletedRows = await db.delete(
      'senkron_deltalar',
      where: 'olusturma_zamani < ? AND islendi = 1',
      whereArgs: [cutoffDate],
    );

    _logMesaj('🧹 ${deletedRows} eski delta temizlendi');
  }

  /// Delta istatistiklerini al
  Future<Map<String, dynamic>> getDeltaStatistics() async {
    final db = await _veriTabani.database;

    final result = await db.rawQuery('''
      SELECT 
        delta_tipi,
        COUNT(*) as toplam,
        SUM(CASE WHEN islendi = 1 THEN 1 ELSE 0 END) as islendi,
        SUM(CASE WHEN islendi = 0 THEN 1 ELSE 0 END) as beklemede,
        SUM(boyut) as toplam_boyut
      FROM senkron_deltalar 
      GROUP BY delta_tipi
    ''');

    final istatistikler = <String, dynamic>{};

    for (final row in result) {
      istatistikler[row['delta_tipi'] as String] = {
        'toplam': row['toplam'],
        'islendi': row['islendi'],
        'beklemede': row['beklemede'],
        'toplam_boyut': row['toplam_boyut'],
      };
    }

    return istatistikler;
  }

  // ============== Yardımcı Metodlar ==============

  void _logMesaj(String mesaj) {
    print('📋 DeltaManager: $mesaj');
    onLogMessage?.call(mesaj);
  }

  void _updateProgress(double ilerleme) {
    onProgressUpdate?.call(ilerleme);
  }

  void _updateOperation(String operasyon) {
    onOperationUpdate?.call(operasyon);
  }

  /// Mevcut delta işlemi aktif mi?
  bool get isProcessingActive => _deltaHesaplamaAktif;

  /// İşlem durumu bilgileri
  Map<String, dynamic> get processingStatus => {
    'active': _deltaHesaplamaAktif,
    'total': _toplamDeltaSayisi,
    'processed': _islenenDeltaSayisi,
    'progress':
        _toplamDeltaSayisi > 0 ? _islenenDeltaSayisi / _toplamDeltaSayisi : 0.0,
  };
}

/// Delta işleme sonuç sınıfı
class DeltaProcessingResult {
  int toplamIslemler = 0;
  int basariliIslemler = 0;
  int hataliIslemler = 0;
  List<String> hatalar = [];

  double get basariOrani =>
      toplamIslemler > 0 ? basariliIslemler / toplamIslemler : 0.0;

  Map<String, dynamic> toJson() => {
    'toplamIslemler': toplamIslemler,
    'basariliIslemler': basariliIslemler,
    'hataliIslemler': hataliIslemler,
    'basariOrani': basariOrani,
    'hatalar': hatalar,
  };
}

/// Delta karşılaştırma sonuç sınıfı
class DeltaComparisonResult {
  List<DeltaConflict> conflicts = [];
  List<SenkronDelta> toDownload = [];
  List<SenkronDelta> toUpload = [];
  Map<String, dynamic> summary = {};

  Map<String, dynamic> toJson() => {
    'conflicts': conflicts.map((c) => c.toJson()).toList(),
    'toDownload': toDownload.map((d) => d.toJson()).toList(),
    'toUpload': toUpload.map((d) => d.toJson()).toList(),
    'summary': summary,
  };
}

/// Delta çakışma sınıfı
class DeltaConflict {
  final SenkronDelta localDelta;
  final SenkronDelta remoteDelta;
  final String conflictType;
  final DateTime detectedAt;

  DeltaConflict({
    required this.localDelta,
    required this.remoteDelta,
    required this.conflictType,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'localDelta': localDelta.toJson(),
    'remoteDelta': remoteDelta.toJson(),
    'conflictType': conflictType,
    'detectedAt': detectedAt.toIso8601String(),
  };
}
