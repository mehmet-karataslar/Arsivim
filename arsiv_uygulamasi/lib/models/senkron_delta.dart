import 'dart:convert';
import 'senkron_metadata.dart';

/// Senkronizasyon delta türleri
enum SenkronDeltaType {
  /// Yeni belge oluşturma
  create,

  /// Belge güncelleme
  update,

  /// Belge silme
  delete,
}

/// Senkronizasyon delta modeli
class SenkronDelta {
  final String id;
  final String documentId;
  final String documentHash;
  final SenkronDeltaType deltaType;
  final DateTime timestamp;
  final SenkronMetadata metadata;
  final int size;
  final int priority;
  final String? deviceId;
  final String? sessionId;
  final Map<String, dynamic>? additionalData;

  SenkronDelta({
    required this.id,
    required this.documentId,
    required this.documentHash,
    required this.deltaType,
    required this.timestamp,
    required this.metadata,
    required this.size,
    required this.priority,
    this.deviceId,
    this.sessionId,
    this.additionalData,
  });

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'documentHash': documentHash,
      'deltaType': deltaType.name,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata.toJson(),
      'size': size,
      'priority': priority,
      'deviceId': deviceId,
      'sessionId': sessionId,
      'additionalData': additionalData,
    };
  }

  /// JSON'dan oluştur
  factory SenkronDelta.fromJson(Map<String, dynamic> json) {
    return SenkronDelta(
      id: json['id'],
      documentId: json['documentId'],
      documentHash: json['documentHash'],
      deltaType: SenkronDeltaType.values.byName(json['deltaType']),
      timestamp: DateTime.parse(json['timestamp']),
      metadata: SenkronMetadata.fromJson(json['metadata']),
      size: json['size'],
      priority: json['priority'],
      deviceId: json['deviceId'],
      sessionId: json['sessionId'],
      additionalData: json['additionalData'],
    );
  }

  /// Delta kopyala
  SenkronDelta copyWith({
    String? id,
    String? documentId,
    String? documentHash,
    SenkronDeltaType? deltaType,
    DateTime? timestamp,
    SenkronMetadata? metadata,
    int? size,
    int? priority,
    String? deviceId,
    String? sessionId,
    Map<String, dynamic>? additionalData,
  }) {
    return SenkronDelta(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentHash: documentHash ?? this.documentHash,
      deltaType: deltaType ?? this.deltaType,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      size: size ?? this.size,
      priority: priority ?? this.priority,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  /// Delta açıklaması
  String get description {
    switch (deltaType) {
      case SenkronDeltaType.create:
        return 'Yeni belge oluşturuldu';
      case SenkronDeltaType.update:
        return 'Belge güncellendi';
      case SenkronDeltaType.delete:
        return 'Belge silindi';
    }
  }

  /// Priorite açıklaması
  String get priorityDescription {
    if (priority >= 8) return 'Çok Yüksek';
    if (priority >= 6) return 'Yüksek';
    if (priority >= 4) return 'Orta';
    if (priority >= 2) return 'Düşük';
    return 'Çok Düşük';
  }

  /// Boyut açıklaması
  String get sizeDescription {
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// Delta geçerli mi?
  bool get isValid {
    return id.isNotEmpty &&
        documentId.isNotEmpty &&
        documentHash.isNotEmpty &&
        timestamp.isBefore(DateTime.now().add(Duration(minutes: 1))) &&
        size >= 0 &&
        priority >= 1 &&
        priority <= 10;
  }

  /// Delta yaşı (dakika)
  int get ageInMinutes {
    return DateTime.now().difference(timestamp).inMinutes;
  }

  /// Delta özeti
  String get summary {
    return '${description} - ${sizeDescription} (${priorityDescription})';
  }

  @override
  String toString() {
    return 'SenkronDelta(${documentId}, ${deltaType.name}, ${sizeDescription})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SenkronDelta &&
        other.id == id &&
        other.documentId == documentId &&
        other.documentHash == documentHash;
  }

  @override
  int get hashCode => id.hashCode ^ documentId.hashCode ^ documentHash.hashCode;
}
