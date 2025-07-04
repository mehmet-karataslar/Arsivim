import '../models/belge_modeli.dart';
import '../models/senkron_conflict.dart';

/// Senkronizasyon çakışmalarını çözmek için kullanılan servis
class SenkronConflictResolver {
  static final SenkronConflictResolver _instance =
      SenkronConflictResolver._internal();
  static SenkronConflictResolver get instance => _instance;
  SenkronConflictResolver._internal();

  // Callback fonksiyonları
  Function(String message)? onLogMessage;
  Function(SenkronConflict conflict)? onConflictDetected;
  Function(SenkronConflict conflict, String resolution)? onConflictResolved;

  /// İki belge arasındaki çakışmaları tespit et
  Future<SenkronConflict?> detectConflict(
    BelgeModeli localDoc,
    Map<String, dynamic> remoteDoc,
  ) async {
    try {
      _log(
        '🔍 Çakışma analizi: ${localDoc.dosyaAdi} vs ${remoteDoc['dosyaAdi']}',
      );

      // 1. Hash karşılaştırması
      final localHash = localDoc.dosyaHash;
      final remoteHash = remoteDoc['dosyaHash'] as String?;

      if (localHash != null && remoteHash != null && localHash == remoteHash) {
        _log('✅ Hash eşleşmesi - çakışma yok');
        return null;
      }

      // 2. Timestamp analizi
      final localTime = localDoc.guncellemeTarihi;
      final remoteTimeStr =
          remoteDoc['guncellemeTarihi'] as String? ??
          remoteDoc['olusturmaTarihi'] as String?;

      if (remoteTimeStr == null) {
        _log('⚠️ Uzak belge tarih bilgisi eksik');
        return SenkronConflict(
          localDocument: localDoc,
          remoteDocument: remoteDoc,
          conflictType: SenkronConflictType.metadataIncomplete,
          detectedAt: DateTime.now(),
          severity: SenkronConflictSeverity.medium,
        );
      }

      final remoteTime = DateTime.parse(remoteTimeStr);
      final timeDifference = localTime.difference(remoteTime).inMinutes.abs();

      // 3. Çakışma türü belirleme
      SenkronConflictType conflictType;
      SenkronConflictSeverity severity;

      if (timeDifference < 5) {
        // Aynı anda düzenlenmiş
        conflictType = SenkronConflictType.simultaneousEdit;
        severity = SenkronConflictSeverity.high;
      } else if (localHash != remoteHash) {
        // İçerik farklı
        conflictType = SenkronConflictType.contentDifference;
        severity = SenkronConflictSeverity.medium;
      } else if (_hasMetadataConflict(localDoc, remoteDoc)) {
        // Metadata farklı
        conflictType = SenkronConflictType.metadataConflict;
        severity = SenkronConflictSeverity.low;
      } else {
        // Çakışma yok
        return null;
      }

      final conflict = SenkronConflict(
        localDocument: localDoc,
        remoteDocument: remoteDoc,
        conflictType: conflictType,
        detectedAt: DateTime.now(),
        severity: severity,
        timeDifference: timeDifference,
      );

      _log('⚠️ Çakışma tespit edildi: ${conflictType.name} (${severity.name})');
      onConflictDetected?.call(conflict);

      return conflict;
    } catch (e) {
      _log('❌ Çakışma tespit hatası: $e');
      return SenkronConflict(
        localDocument: localDoc,
        remoteDocument: remoteDoc,
        conflictType: SenkronConflictType.analysisError,
        detectedAt: DateTime.now(),
        severity: SenkronConflictSeverity.high,
        errorMessage: e.toString(),
      );
    }
  }

  /// Çakışmayı otomatik çöz
  Future<Map<String, dynamic>> resolveConflict(SenkronConflict conflict) async {
    try {
      _log('🔧 Çakışma çözümü: ${conflict.conflictType.name}');

      switch (conflict.conflictType) {
        case SenkronConflictType.simultaneousEdit:
          return {'resolution': 'preferLocal', 'autoResolved': true};

        case SenkronConflictType.contentDifference:
          return {'resolution': 'preferRemote', 'autoResolved': true};

        case SenkronConflictType.metadataConflict:
          return {'resolution': 'keepBoth', 'autoResolved': true};

        case SenkronConflictType.metadataIncomplete:
          return {'resolution': 'preferLocal', 'autoResolved': true};

        case SenkronConflictType.analysisError:
          return {'resolution': 'manual', 'autoResolved': false};

        case SenkronConflictType.contentMismatch:
          return {'resolution': 'manual', 'autoResolved': false};
      }
    } catch (e) {
      _log('❌ Çakışma çözüm hatası: $e');
      return {'resolution': 'manual', 'autoResolved': false};
    }
  }

  /// Aynı anda düzenleme çakışmasını çöz
  SenkronConflictResolution _resolveSimultaneousEdit(SenkronConflict conflict) {
    final local = conflict.localDocument;
    final remote = conflict.remoteDocument;

    // Dosya boyutu karşılaştırması
    final localSize = local.dosyaBoyutu;
    final remoteSize = remote['dosyaBoyutu'] as int? ?? 0;

    if (localSize > remoteSize) {
      _log('📊 Yerel dosya daha büyük - yerel tercih edildi');
      return SenkronConflictResolution.preferLocal;
    } else if (remoteSize > localSize) {
      _log('📊 Uzak dosya daha büyük - uzak tercih edildi');
      return SenkronConflictResolution.preferRemote;
    }

    // Metadata karşılaştırması
    final localMetadata = _getMetadataScore(local);
    final remoteMetadata = _getMetadataScore(remote);

    if (localMetadata > remoteMetadata) {
      _log('📋 Yerel metadata daha kapsamlı - yerel tercih edildi');
      return SenkronConflictResolution.preferLocal;
    } else if (remoteMetadata > localMetadata) {
      _log('📋 Uzak metadata daha kapsamlı - uzak tercih edildi');
      return SenkronConflictResolution.preferRemote;
    }

    // Son çare - manuel çözüm
    _log('⚖️ Otomatik çözüm başarısız - manuel müdahale gerekli');
    return SenkronConflictResolution.manual;
  }

  /// İçerik farklılığı çakışmasını çöz
  SenkronConflictResolution _resolveContentDifference(
    SenkronConflict conflict,
  ) {
    final local = conflict.localDocument;
    final remote = conflict.remoteDocument;

    // Timestamp karşılaştırması
    final localTime = local.guncellemeTarihi;

    // Güvenli tarih parsing
    DateTime remoteTime;
    try {
      final remoteTimeStr =
          remote['guncellemeTarihi'] as String? ??
          remote['olusturmaTarihi'] as String?;
      if (remoteTimeStr == null) {
        return SenkronConflictResolution.preferLocal;
      }
      remoteTime = DateTime.parse(remoteTimeStr);
    } catch (e) {
      _log('⚠️ Uzak tarih parse hatası: $e');
      return SenkronConflictResolution.preferLocal;
    }

    if (localTime.isAfter(remoteTime)) {
      _log('⏰ Yerel versiyon daha yeni - yerel tercih edildi');
      return SenkronConflictResolution.preferLocal;
    } else if (remoteTime.isAfter(localTime)) {
      _log('⏰ Uzak versiyon daha yeni - uzak tercih edildi');
      return SenkronConflictResolution.preferRemote;
    }

    // Aynı zamanda güncellenmiş - dosya boyutu karşılaştır
    final localSize = local.dosyaBoyutu;
    final remoteSize = remote['dosyaBoyutu'] as int? ?? 0;

    if (localSize != remoteSize) {
      return localSize > remoteSize
          ? SenkronConflictResolution.preferLocal
          : SenkronConflictResolution.preferRemote;
    }

    return SenkronConflictResolution.manual;
  }

  /// Metadata çakışmasını çöz
  SenkronConflictResolution _resolveMetadataConflict(SenkronConflict conflict) {
    final local = conflict.localDocument;
    final remote = conflict.remoteDocument;

    // Metadata kelime sayısı karşılaştır
    final localWords = _countMetadataWords(local);
    final remoteWords = _countMetadataWords(remote);

    if (localWords > remoteWords) {
      _log('📝 Yerel metadata daha detaylı - yerel tercih edildi');
      return SenkronConflictResolution.preferLocal;
    } else if (remoteWords > localWords) {
      _log('📝 Uzak metadata daha detaylı - uzak tercih edildi');
      return SenkronConflictResolution.preferRemote;
    }

    // Timestamp karşılaştırması
    final localTime = local.guncellemeTarihi;

    // Güvenli tarih parsing
    DateTime remoteTime;
    try {
      final remoteTimeStr =
          remote['guncellemeTarihi'] as String? ??
          remote['olusturmaTarihi'] as String?;
      if (remoteTimeStr == null) {
        return SenkronConflictResolution.preferLocal;
      }
      remoteTime = DateTime.parse(remoteTimeStr);
    } catch (e) {
      _log('⚠️ Uzak tarih parse hatası: $e');
      return SenkronConflictResolution.preferLocal;
    }

    return localTime.isAfter(remoteTime)
        ? SenkronConflictResolution.preferLocal
        : SenkronConflictResolution.preferRemote;
  }

  /// Eksik metadata çakışmasını çöz
  SenkronConflictResolution _resolveIncompleteMetadata(
    SenkronConflict conflict,
  ) {
    final local = conflict.localDocument;
    final remote = conflict.remoteDocument;

    // Hangi tarafın metadata'sı daha eksiksiz
    final localScore = _getMetadataScore(local);
    final remoteScore = _getMetadataScore(remote);

    if (localScore > remoteScore) {
      _log('📋 Yerel metadata daha eksiksiz - yerel tercih edildi');
      return SenkronConflictResolution.preferLocal;
    } else if (remoteScore > localScore) {
      _log('📋 Uzak metadata daha eksiksiz - uzak tercih edildi');
      return SenkronConflictResolution.preferRemote;
    }

    return SenkronConflictResolution.preferLocal; // Varsayılan
  }

  /// Metadata çakışması kontrolü
  bool _hasMetadataConflict(BelgeModeli local, Map<String, dynamic> remote) {
    return local.baslik != remote['baslik'] ||
        local.aciklama != remote['aciklama'] ||
        local.kategoriId != remote['kategoriId'] ||
        local.kisiId != remote['kisiId'];
  }

  /// Metadata puanlama
  int _getMetadataScore(dynamic doc) {
    int score = 0;

    if (doc is BelgeModeli) {
      if (doc.baslik != null && doc.baslik!.isNotEmpty) score += 2;
      if (doc.aciklama != null && doc.aciklama!.isNotEmpty) score += 2;
      if (doc.etiketler != null && doc.etiketler!.isNotEmpty) score += 1;
      if (doc.kisiId != null) score += 1;
    } else if (doc is Map<String, dynamic>) {
      if (doc['baslik'] != null && doc['baslik'].toString().isNotEmpty)
        score += 2;
      if (doc['aciklama'] != null && doc['aciklama'].toString().isNotEmpty)
        score += 2;
      if (doc['etiketler'] != null && (doc['etiketler'] as List).isNotEmpty)
        score += 1;
      if (doc['kisiId'] != null) score += 1;
    }

    return score;
  }

  /// Metadata kelime sayısı
  int _countMetadataWords(dynamic doc) {
    int count = 0;

    if (doc is BelgeModeli) {
      if (doc.baslik != null) count += doc.baslik!.split(' ').length;
      if (doc.aciklama != null) count += doc.aciklama!.split(' ').length;
    } else if (doc is Map<String, dynamic>) {
      if (doc['baslik'] != null)
        count += doc['baslik'].toString().split(' ').length;
      if (doc['aciklama'] != null)
        count += doc['aciklama'].toString().split(' ').length;
    }

    return count;
  }

  /// Log mesajı
  void _log(String message) {
    print(message);
    onLogMessage?.call(message);
  }

  /// Çakışma çözümü uygula
  Future<bool> applyResolution(
    SenkronConflict conflict,
    SenkronConflictResolution resolution,
  ) async {
    try {
      _log('✅ Çakışma çözümü uygulanıyor: ${resolution.name}');

      onConflictResolved?.call(conflict, resolution.name);

      return true;
    } catch (e) {
      _log('❌ Çakışma çözümü uygulama hatası: $e');
      return false;
    }
  }
}
