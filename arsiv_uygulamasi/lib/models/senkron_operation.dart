import 'belge_modeli.dart';

/// Senkronizasyon operasyonu modeli
class SenkronOperation {
  final String operationId;
  final String documentId;
  final String documentName;
  final SenkronOperationType type;
  final SenkronOperationStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? fileSize;
  final int? transferredBytes;
  final double? progress;
  final String? localPath;
  final String? remotePath;
  final String? hash;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  final int retryCount;
  final int maxRetries;

  SenkronOperation({
    required this.operationId,
    required this.documentId,
    required this.documentName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.fileSize,
    this.transferredBytes,
    this.progress,
    this.localPath,
    this.remotePath,
    this.hash,
    this.errorMessage,
    required this.metadata,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  /// JSON'dan model oluştur
  factory SenkronOperation.fromJson(Map<String, dynamic> json) {
    return SenkronOperation(
      operationId: json['operationId'] as String,
      documentId: json['documentId'] as String,
      documentName: json['documentName'] as String,
      type: SenkronOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SenkronOperationType.unknown,
      ),
      status: SenkronOperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SenkronOperationStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt:
          json['startedAt'] != null
              ? DateTime.parse(json['startedAt'] as String)
              : null,
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'] as String)
              : null,
      fileSize: json['fileSize'] as int?,
      transferredBytes: json['transferredBytes'] as int?,
      progress: (json['progress'] as num?)?.toDouble(),
      localPath: json['localPath'] as String?,
      remotePath: json['remotePath'] as String?,
      hash: json['hash'] as String?,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
    );
  }

  /// Model'i JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'documentId': documentId,
      'documentName': documentName,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'fileSize': fileSize,
      'transferredBytes': transferredBytes,
      'progress': progress,
      'localPath': localPath,
      'remotePath': remotePath,
      'hash': hash,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
    };
  }

  /// Belge modeli ile operasyon oluştur
  factory SenkronOperation.fromDocument(
    BelgeModeli document,
    SenkronOperationType type, {
    String? operationId,
    String? remotePath,
  }) {
    return SenkronOperation(
      operationId: operationId ?? _generateOperationId(),
      documentId: document.id.toString(),
      documentName: document.dosyaAdi,
      type: type,
      status: SenkronOperationStatus.pending,
      createdAt: DateTime.now(),
      fileSize: document.dosyaBoyutu,
      localPath: document.dosyaYolu,
      remotePath: remotePath,
      hash: document.dosyaHash,
      metadata: {
        'kategoriId': document.kategoriId,
        'kisiId': document.kisiId,
        'baslik': document.baslik,
        'aciklama': document.aciklama,
      },
    );
  }

  /// Operasyonu başlat
  SenkronOperation start() {
    return copyWith(
      status: SenkronOperationStatus.inProgress,
      startedAt: DateTime.now(),
    );
  }

  /// Operasyonu tamamla
  SenkronOperation complete() {
    return copyWith(
      status: SenkronOperationStatus.completed,
      completedAt: DateTime.now(),
      progress: 100.0,
    );
  }

  /// Operasyonu başarısız olarak işaretle
  SenkronOperation fail(String error) {
    return copyWith(
      status: SenkronOperationStatus.failed,
      completedAt: DateTime.now(),
      errorMessage: error,
    );
  }

  /// Kopyala ve değiştir
  SenkronOperation copyWith({
    String? operationId,
    String? documentId,
    String? documentName,
    SenkronOperationType? type,
    SenkronOperationStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? fileSize,
    int? transferredBytes,
    double? progress,
    String? localPath,
    String? remotePath,
    String? hash,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    int? retryCount,
    int? maxRetries,
  }) {
    return SenkronOperation(
      operationId: operationId ?? this.operationId,
      documentId: documentId ?? this.documentId,
      documentName: documentName ?? this.documentName,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      fileSize: fileSize ?? this.fileSize,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      hash: hash ?? this.hash,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  /// Unique operasyon ID oluştur
  static String _generateOperationId() {
    return 'op_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Senkronizasyon operasyon türü
enum SenkronOperationType {
  upload,
  download,
  update,
  delete,
  metadata,
  unknown,
}

/// Senkronizasyon operasyon durumu
enum SenkronOperationStatus {
  pending,
  inProgress,
  completed,
  failed,
  paused,
  cancelled,
  skipped,
}
