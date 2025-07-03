import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Senkronizasyon metadata modeli
class SenkronMetadata {
  final String documentId;
  final String? documentHash;
  final DateTime lastSyncTime;
  final DateTime lastModifiedTime;
  final int version;
  final Map<String, dynamic> properties;
  final String? deviceId;
  final String? sessionId;
  final bool isDeleted;
  final List<String>? conflicts;

  SenkronMetadata({
    required this.documentId,
    this.documentHash,
    required this.lastSyncTime,
    required this.lastModifiedTime,
    this.version = 1,
    this.properties = const {},
    this.deviceId,
    this.sessionId,
    this.isDeleted = false,
    this.conflicts,
  });

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'documentHash': documentHash,
      'lastSyncTime': lastSyncTime.toIso8601String(),
      'lastModifiedTime': lastModifiedTime.toIso8601String(),
      'version': version,
      'properties': properties,
      'deviceId': deviceId,
      'sessionId': sessionId,
      'isDeleted': isDeleted,
      'conflicts': conflicts,
    };
  }

  /// JSON'dan oluştur
  factory SenkronMetadata.fromJson(Map<String, dynamic> json) {
    return SenkronMetadata(
      documentId: json['documentId'],
      documentHash: json['documentHash'],
      lastSyncTime: DateTime.parse(json['lastSyncTime']),
      lastModifiedTime: DateTime.parse(json['lastModifiedTime']),
      version: json['version'] ?? 1,
      properties: json['properties'] ?? {},
      deviceId: json['deviceId'],
      sessionId: json['sessionId'],
      isDeleted: json['isDeleted'] ?? false,
      conflicts:
          json['conflicts'] != null
              ? List<String>.from(json['conflicts'])
              : null,
    );
  }

  /// Metadata'yı güncelle
  SenkronMetadata copyWith({
    String? documentHash,
    DateTime? lastSyncTime,
    DateTime? lastModifiedTime,
    int? version,
    Map<String, dynamic>? properties,
    String? deviceId,
    String? sessionId,
    bool? isDeleted,
    List<String>? conflicts,
  }) {
    return SenkronMetadata(
      documentId: documentId,
      documentHash: documentHash ?? this.documentHash,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastModifiedTime: lastModifiedTime ?? this.lastModifiedTime,
      version: version ?? this.version,
      properties: properties ?? this.properties,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      isDeleted: isDeleted ?? this.isDeleted,
      conflicts: conflicts ?? this.conflicts,
    );
  }

  /// Metadata signature oluştur
  String generateSignature() {
    final signatureData = {
      'documentId': documentId,
      'documentHash': documentHash,
      'lastModifiedTime': lastModifiedTime.toIso8601String(),
      'version': version,
      'properties': properties,
    };

    final jsonString = json.encode(signatureData);
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  /// Metadata'nın güncel olup olmadığını kontrol et
  bool isNewerThan(SenkronMetadata other) {
    if (version != other.version) {
      return version > other.version;
    }
    return lastModifiedTime.isAfter(other.lastModifiedTime);
  }

  /// Conflict ekle
  SenkronMetadata addConflict(String conflictId) {
    final newConflicts = List<String>.from(conflicts ?? []);
    if (!newConflicts.contains(conflictId)) {
      newConflicts.add(conflictId);
    }
    return copyWith(conflicts: newConflicts);
  }

  /// Conflict kaldır
  SenkronMetadata removeConflict(String conflictId) {
    final newConflicts = List<String>.from(conflicts ?? []);
    newConflicts.remove(conflictId);
    return copyWith(conflicts: newConflicts.isEmpty ? null : newConflicts);
  }

  /// Conflict var mı?
  bool get hasConflicts => conflicts != null && conflicts!.isNotEmpty;

  /// Metadata'nın geçerli olup olmadığını kontrol et
  bool get isValid {
    return documentId.isNotEmpty &&
        lastSyncTime.isBefore(DateTime.now().add(Duration(minutes: 1))) &&
        lastModifiedTime.isBefore(DateTime.now().add(Duration(minutes: 1)));
  }

  @override
  String toString() {
    return 'SenkronMetadata(${documentId}, v${version}, ${lastModifiedTime})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SenkronMetadata &&
        other.documentId == documentId &&
        other.documentHash == documentHash &&
        other.version == version;
  }

  @override
  int get hashCode =>
      documentId.hashCode ^ documentHash.hashCode ^ version.hashCode;
}
