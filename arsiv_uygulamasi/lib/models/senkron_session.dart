import 'senkron_operation.dart';
import 'senkron_conflict.dart';

/// Senkronizasyon oturumu modeli
class SenkronSession {
  final String sessionId;
  final String localDeviceId;
  final String remoteDeviceId;
  final DateTime startTime;
  final DateTime? endTime;
  final SenkronSessionStatus status;
  final List<SenkronOperation> operations;
  final List<SenkronConflict> conflicts;
  final SenkronSessionStatistics statistics;
  final String? errorMessage;

  SenkronSession({
    required this.sessionId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.operations,
    required this.conflicts,
    required this.statistics,
    this.errorMessage,
  });

  /// JSON'dan model oluştur
  factory SenkronSession.fromJson(Map<String, dynamic> json) {
    return SenkronSession(
      sessionId: json['sessionId'] as String,
      localDeviceId: json['localDeviceId'] as String,
      remoteDeviceId: json['remoteDeviceId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime:
          json['endTime'] != null
              ? DateTime.parse(json['endTime'] as String)
              : null,
      status: SenkronSessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SenkronSessionStatus.unknown,
      ),
      operations:
          (json['operations'] as List<dynamic>?)
              ?.map(
                (op) => SenkronOperation.fromJson(op as Map<String, dynamic>),
              )
              .toList() ??
          [],
      conflicts:
          (json['conflicts'] as List<dynamic>?)
              ?.map(
                (conflict) =>
                    SenkronConflict.fromJson(conflict as Map<String, dynamic>),
              )
              .toList() ??
          [],
      statistics: SenkronSessionStatistics.fromJson(
        json['statistics'] as Map<String, dynamic>,
      ),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Model'i JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'localDeviceId': localDeviceId,
      'remoteDeviceId': remoteDeviceId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.name,
      'operations': operations.map((op) => op.toJson()).toList(),
      'conflicts': conflicts.map((conflict) => conflict.toJson()).toList(),
      'statistics': statistics.toJson(),
      'errorMessage': errorMessage,
    };
  }

  /// Oturumu başlat
  SenkronSession start() {
    return copyWith(
      status: SenkronSessionStatus.active,
      startTime: DateTime.now(),
    );
  }

  /// Oturumu tamamla
  SenkronSession complete() {
    return copyWith(
      status: SenkronSessionStatus.completed,
      endTime: DateTime.now(),
    );
  }

  /// Oturumu hata ile sonlandır
  SenkronSession fail(String error) {
    return copyWith(
      status: SenkronSessionStatus.failed,
      endTime: DateTime.now(),
      errorMessage: error,
    );
  }

  /// Operasyon ekle
  SenkronSession addOperation(SenkronOperation operation) {
    return copyWith(operations: [...operations, operation]);
  }

  /// Çakışma ekle
  SenkronSession addConflict(SenkronConflict conflict) {
    return copyWith(conflicts: [...conflicts, conflict]);
  }

  /// Oturum süresini hesapla
  Duration get duration {
    final endTime = this.endTime ?? DateTime.now();
    return endTime.difference(startTime);
  }

  /// Başarılı operasyon sayısı
  int get successfulOperations {
    return operations
        .where((op) => op.status == SenkronOperationStatus.completed)
        .length;
  }

  /// Başarısız operasyon sayısı
  int get failedOperations {
    return operations
        .where((op) => op.status == SenkronOperationStatus.failed)
        .length;
  }

  /// Kopyala ve değiştir
  SenkronSession copyWith({
    String? sessionId,
    String? localDeviceId,
    String? remoteDeviceId,
    DateTime? startTime,
    DateTime? endTime,
    SenkronSessionStatus? status,
    List<SenkronOperation>? operations,
    List<SenkronConflict>? conflicts,
    SenkronSessionStatistics? statistics,
    String? errorMessage,
  }) {
    return SenkronSession(
      sessionId: sessionId ?? this.sessionId,
      localDeviceId: localDeviceId ?? this.localDeviceId,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      operations: operations ?? this.operations,
      conflicts: conflicts ?? this.conflicts,
      statistics: statistics ?? this.statistics,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Senkronizasyon oturumu durumu
enum SenkronSessionStatus {
  preparing,
  active,
  paused,
  completed,
  failed,
  cancelled,
  unknown,
}

/// Senkronizasyon oturumu istatistikleri
class SenkronSessionStatistics {
  final int totalDocuments;
  final int processedDocuments;
  final int uploadedDocuments;
  final int downloadedDocuments;
  final int skippedDocuments;
  final int conflictedDocuments;
  final int totalBytes;
  final int transferredBytes;
  final double averageSpeed;
  final DateTime lastUpdate;

  SenkronSessionStatistics({
    required this.totalDocuments,
    required this.processedDocuments,
    required this.uploadedDocuments,
    required this.downloadedDocuments,
    required this.skippedDocuments,
    required this.conflictedDocuments,
    required this.totalBytes,
    required this.transferredBytes,
    required this.averageSpeed,
    required this.lastUpdate,
  });

  /// JSON'dan model oluştur
  factory SenkronSessionStatistics.fromJson(Map<String, dynamic> json) {
    return SenkronSessionStatistics(
      totalDocuments: json['totalDocuments'] as int,
      processedDocuments: json['processedDocuments'] as int,
      uploadedDocuments: json['uploadedDocuments'] as int,
      downloadedDocuments: json['downloadedDocuments'] as int,
      skippedDocuments: json['skippedDocuments'] as int,
      conflictedDocuments: json['conflictedDocuments'] as int,
      totalBytes: json['totalBytes'] as int,
      transferredBytes: json['transferredBytes'] as int,
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
    );
  }

  /// Model'i JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'totalDocuments': totalDocuments,
      'processedDocuments': processedDocuments,
      'uploadedDocuments': uploadedDocuments,
      'downloadedDocuments': downloadedDocuments,
      'skippedDocuments': skippedDocuments,
      'conflictedDocuments': conflictedDocuments,
      'totalBytes': totalBytes,
      'transferredBytes': transferredBytes,
      'averageSpeed': averageSpeed,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  /// İlerleme yüzdesi
  double get progressPercentage {
    if (totalDocuments == 0) return 0.0;
    return (processedDocuments / totalDocuments) * 100;
  }

  /// Transfer hızı (MB/s)
  double get transferSpeedMBps {
    return averageSpeed / (1024 * 1024);
  }

  /// Boş istatistik
  factory SenkronSessionStatistics.empty() {
    return SenkronSessionStatistics(
      totalDocuments: 0,
      processedDocuments: 0,
      uploadedDocuments: 0,
      downloadedDocuments: 0,
      skippedDocuments: 0,
      conflictedDocuments: 0,
      totalBytes: 0,
      transferredBytes: 0,
      averageSpeed: 0.0,
      lastUpdate: DateTime.now(),
    );
  }

  /// Kopyala ve değiştir
  SenkronSessionStatistics copyWith({
    int? totalDocuments,
    int? processedDocuments,
    int? uploadedDocuments,
    int? downloadedDocuments,
    int? skippedDocuments,
    int? conflictedDocuments,
    int? totalBytes,
    int? transferredBytes,
    double? averageSpeed,
    DateTime? lastUpdate,
  }) {
    return SenkronSessionStatistics(
      totalDocuments: totalDocuments ?? this.totalDocuments,
      processedDocuments: processedDocuments ?? this.processedDocuments,
      uploadedDocuments: uploadedDocuments ?? this.uploadedDocuments,
      downloadedDocuments: downloadedDocuments ?? this.downloadedDocuments,
      skippedDocuments: skippedDocuments ?? this.skippedDocuments,
      conflictedDocuments: conflictedDocuments ?? this.conflictedDocuments,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}
