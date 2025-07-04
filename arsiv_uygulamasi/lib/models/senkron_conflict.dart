
import 'belge_modeli.dart';

/// Senkronizasyon çakışması türleri
enum SenkronConflictType {
  /// Aynı anda düzenleme
  simultaneousEdit,

  /// İçerik farklılığı
  contentDifference,

  /// İçerik uyuşmazlığı
  contentMismatch,

  /// Metadata çakışması
  metadataConflict,

  /// Metadata eksikliği
  metadataIncomplete,

  /// Analiz hatası
  analysisError,
}

/// Çakışma şiddeti
enum SenkronConflictSeverity {
  /// Düşük - otomatik çözülebilir
  low,

  /// Orta - otomatik çözüm denenebilir
  medium,

  /// Yüksek - manuel müdahale gerekli
  high,
}

/// Çakışma çözümü seçenekleri
enum SenkronConflictResolution {
  /// Yerel versiyonu tercih et
  preferLocal,

  /// Uzak versiyonu tercih et
  preferRemote,

  /// Manuel çözüm gerekli
  manual,

  /// Her ikisini de koru (duplicate)
  keepBoth,
}

/// Senkronizasyon çakışması model sınıfı
class SenkronConflict {
  final BelgeModeli localDocument;
  final Map<String, dynamic> remoteDocument;
  final SenkronConflictType conflictType;
  final DateTime detectedAt;
  final SenkronConflictSeverity severity;
  final int? timeDifference; // dakika cinsinden
  final String? errorMessage;
  final Map<String, dynamic>? additionalData;
  final bool isResolved;

  SenkronConflict({
    required this.localDocument,
    required this.remoteDocument,
    required this.conflictType,
    required this.detectedAt,
    required this.severity,
    this.timeDifference,
    this.errorMessage,
    this.additionalData,
    this.isResolved = false,
    // Backward compatibility
    String? conflictId,
  });

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'localDocument': localDocument.toJson(),
      'remoteDocument': remoteDocument,
      'conflictType': conflictType.name,
      'detectedAt': detectedAt.toIso8601String(),
      'severity': severity.name,
      'timeDifference': timeDifference,
      'errorMessage': errorMessage,
      'additionalData': additionalData,
      'isResolved': isResolved,
    };
  }

  /// JSON'dan oluştur
  factory SenkronConflict.fromJson(Map<String, dynamic> json) {
    return SenkronConflict(
      localDocument: BelgeModeli.fromJson(json['localDocument']),
      remoteDocument: json['remoteDocument'],
      conflictType: SenkronConflictType.values.byName(json['conflictType']),
      detectedAt: DateTime.parse(json['detectedAt']),
      severity: SenkronConflictSeverity.values.byName(json['severity']),
      timeDifference: json['timeDifference'],
      errorMessage: json['errorMessage'],
      additionalData: json['additionalData'],
      isResolved: json['isResolved'] ?? false,
    );
  }

  /// Çakışma açıklaması
  String get description {
    switch (conflictType) {
      case SenkronConflictType.simultaneousEdit:
        return 'Aynı anda düzenleme çakışması';
      case SenkronConflictType.contentDifference:
        return 'İçerik farklılığı';
      case SenkronConflictType.contentMismatch:
        return 'İçerik uyuşmazlığı';
      case SenkronConflictType.metadataConflict:
        return 'Metadata çakışması';
      case SenkronConflictType.metadataIncomplete:
        return 'Metadata eksikliği';
      case SenkronConflictType.analysisError:
        return 'Analiz hatası';
    }
  }

  /// Çakışma çözümü önerisi
  SenkronConflictResolution get suggestedResolution {
    switch (severity) {
      case SenkronConflictSeverity.low:
        return SenkronConflictResolution.preferLocal;
      case SenkronConflictSeverity.medium:
        return timeDifference != null && timeDifference! > 0
            ? SenkronConflictResolution.preferLocal
            : SenkronConflictResolution.preferRemote;
      case SenkronConflictSeverity.high:
        return SenkronConflictResolution.manual;
    }
  }

  /// Çakışma özeti
  String get summary {
    return '${localDocument.dosyaAdi} - ${description} (${severity.name})';
  }

  @override
  String toString() {
    return 'SenkronConflict(${localDocument.dosyaAdi}, ${conflictType.name}, ${severity.name})';
  }
}
