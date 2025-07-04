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
class MetadataSyncManager {
  static final MetadataSyncManager _instance = MetadataSyncManager._internal();
  static MetadataSyncManager get instance => _instance;
  MetadataSyncManager._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;
  final SyncStateTracker _stateTracker = SyncStateTracker.instance;
  final HashComparator _hashComparator = HashComparator.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  /// Metadata senkronizasyonu gerçekleştir
  Future<MetadataSyncResult> syncMetadata(
    SenkronCihazi targetDevice, {
    DateTime? since,
    bool bidirectional = true,
    String strategy = 'LATEST_WINS',
  }) async {
    try {
      final result = MetadataSyncResult();

      // 1. Local değişiklikleri al
      final localChanges = await _getLocalMetadataChanges(since);
      result.localChangesCount = localChanges.length;

      // 2. Remote değişiklikleri al
      final remoteChanges = await _getRemoteMetadataChanges(
        targetDevice,
        since,
      );
      result.remoteChangesCount = remoteChanges.length;

      // 3. Çakışmaları tespit et
      final conflicts = await _detectMetadataConflicts(
        localChanges,
        remoteChanges,
      );
      result.conflictsCount = conflicts.length;

      // 4. Çakışmaları çöz
      final resolvedChanges = await _resolveMetadataConflicts(
        conflicts,
        strategy,
      );
      result.resolvedConflictsCount = resolvedChanges.length;

      // 5. Local metadata'yı güncelle
      if (bidirectional) {
        await _applyRemoteMetadataChanges(remoteChanges, resolvedChanges);
        result.appliedRemoteChanges = remoteChanges.length;
      }

      // 6. Remote metadata'yı güncelle
      await _sendLocalMetadataChanges(targetDevice, localChanges);
      result.sentLocalChanges = localChanges.length;

      result.success = true;
      result.syncTimestamp = DateTime.now();

      return result;
    } catch (e) {
      return MetadataSyncResult(
        success: false,
        error: 'Metadata sync hatası: $e',
      );
    }
  }

  /// Local metadata değişikliklerini al
  Future<List<MetadataChange>> _getLocalMetadataChanges(DateTime? since) async {
    final changes = <MetadataChange>[];
    final sinceTime = since ?? DateTime.now().subtract(const Duration(days: 1));

    // Belgeler için metadata değişiklikleri
    final belgeChanges = await _changeTracker.getChangedDocuments(
      since: sinceTime,
      limit: 1000,
    );

    for (final change in belgeChanges) {
      final belgeId = change['belge_id'] as int;
      final belge = await _veriTabani.belgeGetir(belgeId);

      if (belge != null) {
        changes.add(
          MetadataChange(
            entityType: 'belge',
            entityId: belgeId,
            changeType: change['degisiklik_tipi'] as String,
            metadata: _belgeToMetadata(belge),
            timestamp: DateTime.parse(change['olusturma_tarihi'] as String),
            hash: _hashComparator.generateMetadataHash(belge),
          ),
        );
      }
    }

    // Kategoriler için değişiklikleri al
    final kategoriler = await _veriTabani.kategorileriGetir();
    for (final kategori in kategoriler) {
      if (kategori.olusturmaTarihi.isAfter(sinceTime)) {
        changes.add(
          MetadataChange(
            entityType: 'kategori',
            entityId: kategori.id!,
            changeType: 'UPDATE',
            metadata: _kategoriToMetadata(kategori),
            timestamp: kategori.olusturmaTarihi,
            hash: _generateKategoriHash(kategori),
          ),
        );
      }
    }

    // Kişiler için değişiklikleri al
    final kisiler = await _veriTabani.kisileriGetir();
    for (final kisi in kisiler) {
      if (kisi.guncellemeTarihi.isAfter(sinceTime)) {
        changes.add(
          MetadataChange(
            entityType: 'kisi',
            entityId: kisi.id!,
            changeType: 'UPDATE',
            metadata: _kisiToMetadata(kisi),
            timestamp: kisi.guncellemeTarihi,
            hash: _generateKisiHash(kisi),
          ),
        );
      }
    }

    return changes;
  }

  /// Remote metadata değişikliklerini al
  Future<List<MetadataChange>> _getRemoteMetadataChanges(
    SenkronCihazi targetDevice,
    DateTime? since,
  ) async {
    try {
      final sinceParam = since?.toIso8601String() ?? '';
      final response = await http
          .get(
            Uri.parse(
              'http://${targetDevice.ip}:8080/sync/metadata?since=$sinceParam',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final changesData = data['changes'] as List;

        return changesData
            .map((change) => MetadataChange.fromJson(change))
            .toList();
      } else {
        throw Exception('Remote metadata alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Remote metadata fetch hatası: $e');
    }
  }

  /// Metadata çakışmalarını tespit et
  Future<List<MetadataConflict>> _detectMetadataConflicts(
    List<MetadataChange> localChanges,
    List<MetadataChange> remoteChanges,
  ) async {
    final conflicts = <MetadataConflict>[];

    for (final localChange in localChanges) {
      final conflictingRemoteChange = remoteChanges.firstWhere(
        (remote) =>
            remote.entityType == localChange.entityType &&
            remote.entityId == localChange.entityId &&
            remote.hash != localChange.hash,
        orElse: () => null as MetadataChange,
      );

      if (conflictingRemoteChange != null) {
        conflicts.add(
          MetadataConflict(
            entityType: localChange.entityType,
            entityId: localChange.entityId,
            localChange: localChange,
            remoteChange: conflictingRemoteChange,
            conflictType: _determineConflictType(
              localChange,
              conflictingRemoteChange,
            ),
          ),
        );
      }
    }

    return conflicts;
  }

  /// Metadata çakışmalarını çöz
  Future<List<MetadataChange>> _resolveMetadataConflicts(
    List<MetadataConflict> conflicts,
    String strategy,
  ) async {
    final resolvedChanges = <MetadataChange>[];

    for (final conflict in conflicts) {
      MetadataChange? resolvedChange;

      switch (strategy) {
        case 'LATEST_WINS':
          resolvedChange = _resolveLatestWins(conflict);
          break;
        case 'LOCAL_WINS':
          resolvedChange = conflict.localChange;
          break;
        case 'REMOTE_WINS':
          resolvedChange = conflict.remoteChange;
          break;
        case 'MANUAL':
          resolvedChange = await _resolveManualConflict(conflict);
          break;
        default:
          resolvedChange = _resolveLatestWins(conflict);
      }

      if (resolvedChange != null) {
        resolvedChanges.add(resolvedChange);
      }
    }

    return resolvedChanges;
  }

  /// Remote metadata değişikliklerini uygula
  Future<void> _applyRemoteMetadataChanges(
    List<MetadataChange> remoteChanges,
    List<MetadataChange> resolvedChanges,
  ) async {
    for (final change in remoteChanges) {
      try {
        switch (change.entityType) {
          case 'belge':
            await _applyBelgeMetadataChange(change);
            break;
          case 'kategori':
            await _applyKategoriMetadataChange(change);
            break;
          case 'kisi':
            await _applyKisiMetadataChange(change);
            break;
        }
      } catch (e) {
        print('Metadata change uygulama hatası: $e');
      }
    }

    // Çözülen çakışmaları uygula
    for (final resolvedChange in resolvedChanges) {
      try {
        switch (resolvedChange.entityType) {
          case 'belge':
            await _applyBelgeMetadataChange(resolvedChange);
            break;
          case 'kategori':
            await _applyKategoriMetadataChange(resolvedChange);
            break;
          case 'kisi':
            await _applyKisiMetadataChange(resolvedChange);
            break;
        }
      } catch (e) {
        print('Resolved change uygulama hatası: $e');
      }
    }
  }

  /// Local metadata değişikliklerini gönder
  Future<void> _sendLocalMetadataChanges(
    SenkronCihazi targetDevice,
    List<MetadataChange> localChanges,
  ) async {
    try {
      final changesJson =
          localChanges.map((change) => change.toJson()).toList();

      final response = await http
          .post(
            Uri.parse('http://${targetDevice.ip}:8080/sync/metadata'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'changes': changesJson}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Local metadata gönderilemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Local metadata send hatası: $e');
    }
  }

  /// Helper metodlar
  Map<String, dynamic> _belgeToMetadata(BelgeModeli belge) {
    return {
      'id': belge.id,
      'dosyaAdi': belge.dosyaAdi,
      'orijinalDosyaAdi': belge.orijinalDosyaAdi,
      'baslik': belge.baslik,
      'aciklama': belge.aciklama,
      'kategoriId': belge.kategoriId,
      'kisiId': belge.kisiId,
      'etiketler': belge.etiketler,
      'guncellemeTarihi': belge.guncellemeTarihi.toIso8601String(),
    };
  }

  Map<String, dynamic> _kategoriToMetadata(KategoriModeli kategori) {
    return {
      'id': kategori.id,
      'kategoriAdi': kategori.kategoriAdi,
      'renkKodu': kategori.renkKodu,
      'simgeKodu': kategori.simgeKodu,
      'aciklama': kategori.aciklama,
      'olusturmaTarihi': kategori.olusturmaTarihi.toIso8601String(),
    };
  }

  Map<String, dynamic> _kisiToMetadata(KisiModeli kisi) {
    return {
      'id': kisi.id,
      'ad': kisi.ad,
      'soyad': kisi.soyad,
      'guncellemeTarihi': kisi.guncellemeTarihi.toIso8601String(),
    };
  }

  String _generateKategoriHash(KategoriModeli kategori) {
    final data = json.encode(_kategoriToMetadata(kategori));
    return sha256.convert(utf8.encode(data)).toString();
  }

  String _generateKisiHash(KisiModeli kisi) {
    final data = json.encode(_kisiToMetadata(kisi));
    return sha256.convert(utf8.encode(data)).toString();
  }

  String _determineConflictType(MetadataChange local, MetadataChange remote) {
    if (local.timestamp.isAfter(remote.timestamp)) {
      return 'LOCAL_NEWER';
    } else if (remote.timestamp.isAfter(local.timestamp)) {
      return 'REMOTE_NEWER';
    } else {
      return 'SIMULTANEOUS';
    }
  }

  MetadataChange _resolveLatestWins(MetadataConflict conflict) {
    return conflict.localChange.timestamp.isAfter(
          conflict.remoteChange.timestamp,
        )
        ? conflict.localChange
        : conflict.remoteChange;
  }

  Future<MetadataChange?> _resolveManualConflict(
    MetadataConflict conflict,
  ) async {
    // Manuel çakışma çözümü için gelecekte UI entegrasyonu
    return _resolveLatestWins(conflict);
  }

  Future<void> _applyBelgeMetadataChange(MetadataChange change) async {
    final belge = await _veriTabani.belgeGetir(change.entityId);
    if (belge != null) {
      final metadata = change.metadata;
      final updatedBelge = BelgeModeli(
        id: belge.id,
        dosyaAdi: belge.dosyaAdi,
        orijinalDosyaAdi: belge.orijinalDosyaAdi,
        dosyaYolu: belge.dosyaYolu,
        dosyaBoyutu: belge.dosyaBoyutu,
        dosyaTipi: belge.dosyaTipi,
        dosyaHash: belge.dosyaHash,
        kategoriId: metadata['kategoriId'],
        kisiId: metadata['kisiId'],
        baslik: metadata['baslik'],
        aciklama: metadata['aciklama'],
        etiketler: metadata['etiketler'],
        olusturmaTarihi: belge.olusturmaTarihi,
        guncellemeTarihi: DateTime.parse(metadata['guncellemeTarihi']),
        sonErisimTarihi: belge.sonErisimTarihi,
        aktif: belge.aktif,
        senkronDurumu: belge.senkronDurumu,
      );

      await _veriTabani.belgeGuncelle(updatedBelge);
    }
  }

  Future<void> _applyKategoriMetadataChange(MetadataChange change) async {
    final kategori = await _veriTabani.kategoriGetir(change.entityId);
    if (kategori != null) {
      final metadata = change.metadata;
      final updatedKategori = KategoriModeli(
        id: kategori.id,
        kategoriAdi: metadata['kategoriAdi'],
        renkKodu: metadata['renkKodu'],
        simgeKodu: metadata['simgeKodu'],
        aciklama: metadata['aciklama'],
        olusturmaTarihi:
            metadata['olusturmaTarihi'] != null
                ? DateTime.parse(metadata['olusturmaTarihi'])
                : kategori.olusturmaTarihi,
        aktif: kategori.aktif,
      );

      await _veriTabani.kategoriGuncelle(updatedKategori);
    }
  }

  Future<void> _applyKisiMetadataChange(MetadataChange change) async {
    final kisi = await _veriTabani.kisiGetir(change.entityId);
    if (kisi != null) {
      final metadata = change.metadata;
      final updatedKisi = KisiModeli(
        id: kisi.id,
        ad: metadata['ad'],
        soyad: metadata['soyad'],
        olusturmaTarihi: kisi.olusturmaTarihi,
        guncellemeTarihi: DateTime.parse(metadata['guncellemeTarihi']),
        aktif: kisi.aktif,
      );

      await _veriTabani.kisiGuncelle(updatedKisi);
    }
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
