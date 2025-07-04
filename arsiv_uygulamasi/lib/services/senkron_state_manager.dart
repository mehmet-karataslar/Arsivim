import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/senkron_session.dart';
import '../models/senkron_operation.dart';
import '../models/senkron_conflict.dart';
import '../utils/yardimci_fonksiyonlar.dart';

/// Senkronizasyon durumu yöneticisi
/// Gerçek zamanlı state management ve stream-based updates sağlar
class SenkronStateManager {
  static final SenkronStateManager _instance = SenkronStateManager._internal();
  static SenkronStateManager get instance => _instance;
  SenkronStateManager._internal();

  // State streams
  final _sessionController = StreamController<SenkronSession>.broadcast();
  final _operationController = StreamController<SenkronOperation>.broadcast();
  final _conflictController = StreamController<SenkronConflict>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<SenkronStatus>.broadcast();

  // Current state
  SenkronSession? _currentSession;
  final List<SenkronOperation> _operations = [];
  final List<SenkronConflict> _conflicts = [];
  SenkronStatus _currentStatus = SenkronStatus.idle;
  double _currentProgress = 0.0;

  // Getters for streams
  Stream<SenkronSession> get sessionStream => _sessionController.stream;
  Stream<SenkronOperation> get operationStream => _operationController.stream;
  Stream<SenkronConflict> get conflictStream => _conflictController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<SenkronStatus> get statusStream => _statusController.stream;

  // Getters for current state
  SenkronSession? get currentSession => _currentSession;
  SenkronStatus get currentStatus => _currentStatus;
  double get currentProgress => _currentProgress;
  List<SenkronConflict> get conflicts => List.from(_conflicts);
  List<SenkronOperation> get operations => List.from(_operations);

  /// Yeni senkronizasyon session'ı başlat
  Future<SenkronSession> startSession({
    required String localDeviceId,
    required String remoteDeviceId,
  }) async {
    try {
      // Mevcut session varsa sonlandır
      if (_currentSession != null) {
        await endSession();
      }

      // Yeni session oluştur
      _currentSession = SenkronSession(
        sessionId: YardimciFonksiyonlar.uniqueIdOlustur(),
        localDeviceId: localDeviceId,
        remoteDeviceId: remoteDeviceId,
        startTime: DateTime.now(),
        status: SenkronSessionStatus.active,
        operations: [],
        conflicts: [],
        statistics: SenkronSessionStatistics.empty(),
      );

      // State'i güncelle
      _updateStatus(SenkronStatus.connecting);
      _updateProgress(0.0);
      _logInfo(
        'Senkronizasyon session başlatıldı: ${_currentSession!.sessionId}',
      );

      // Session'ı broadcast et
      _sessionController.sink.add(_currentSession!);

      return _currentSession!;
    } catch (e) {
      _logError('Session başlatma hatası: $e');
      rethrow;
    }
  }

  /// Session'ı sonlandır
  Future<void> endSession({String? reason}) async {
    if (_currentSession == null) return;

    try {
      // Session'ı güncelle
      _currentSession = _currentSession!.copyWith(
        endTime: DateTime.now(),
        status: SenkronSessionStatus.completed,
        operations: _operations,
        conflicts: _conflicts,
      );

      // Final session'ı broadcast et
      _sessionController.sink.add(_currentSession!);

      _logInfo(
        'Senkronizasyon session sonlandırıldı${reason != null ? ': $reason' : ''}',
      );

      // State'i temizle
      _currentSession = null;
      _operations.clear();
      _conflicts.clear();
      _updateStatus(SenkronStatus.idle);
      _updateProgress(0.0);
    } catch (e) {
      _logError('Session sonlandırma hatası: $e');
    }
  }

  /// Yeni operasyon ekle
  Future<SenkronOperation> addOperation({
    required SenkronOperationType type,
    required String documentId,
    required String documentName,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentSession == null) {
      throw Exception('Aktif session yok');
    }

    final operation = SenkronOperation(
      operationId: YardimciFonksiyonlar.uniqueIdOlustur(),
      documentId: documentId,
      documentName: documentName,
      type: type,
      status: SenkronOperationStatus.pending,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    _operations.add(operation);
    _operationController.sink.add(operation);

    _logInfo('Yeni operasyon eklendi: ${operation.operationId} (${type.name})');

    return operation;
  }

  /// Operasyon durumunu güncelle
  Future<void> updateOperation(
    String operationId,
    SenkronOperationStatus status, {
    double? progress,
    String? error,
  }) async {
    final operationIndex = _operations.indexWhere(
      (op) => op.operationId == operationId,
    );
    if (operationIndex == -1) return;

    final operation = _operations[operationIndex];
    final updatedOperation = operation.copyWith(
      status: status,
      progress: progress ?? operation.progress,
      errorMessage: error,
      completedAt:
          status == SenkronOperationStatus.completed ||
                  status == SenkronOperationStatus.failed
              ? DateTime.now()
              : null,
    );

    _operations[operationIndex] = updatedOperation;
    _operationController.sink.add(updatedOperation);

    _logInfo('Operasyon güncellendi: $operationId -> ${status.name}');
  }

  /// Conflict ekle
  Future<void> addConflict(SenkronConflict conflict) async {
    _conflicts.add(conflict);
    _conflictController.sink.add(conflict);
    _logWarning(
      'Yeni conflict: ${conflict.localDocument.dosyaAdi} (${conflict.conflictType.name})',
    );
  }

  /// Conflict'i çöz
  Future<void> resolveConflict(SenkronConflict conflict) async {
    final conflictIndex = _conflicts.indexWhere((c) => c == conflict);
    if (conflictIndex == -1) return;

    _conflicts.removeAt(conflictIndex);
    _logInfo('Conflict çözüldü: ${conflict.localDocument.dosyaAdi}');
  }

  /// Progress güncelle
  void updateProgress(double progress) {
    _currentProgress = progress.clamp(0.0, 1.0);
    _progressController.sink.add(_currentProgress);
  }

  /// Status güncelle
  void _updateStatus(SenkronStatus status) {
    _currentStatus = status;
    _statusController.sink.add(status);
  }

  /// Progress güncelle (internal)
  void _updateProgress(double progress) {
    updateProgress(progress);
  }

  /// Log mesajları
  void _logInfo(String message) {
    final logMessage = '[${DateTime.now().toIso8601String()}] INFO: $message';
    _logController.sink.add(logMessage);
    if (kDebugMode) {
      debugPrint(logMessage);
    }
  }

  void _logWarning(String message) {
    final logMessage =
        '[${DateTime.now().toIso8601String()}] WARNING: $message';
    _logController.sink.add(logMessage);
    if (kDebugMode) {
      debugPrint(logMessage);
    }
  }

  void _logError(String message) {
    final logMessage = '[${DateTime.now().toIso8601String()}] ERROR: $message';
    _logController.sink.add(logMessage);
    if (kDebugMode) {
      debugPrint(logMessage);
    }
  }

  /// Temizlik
  void dispose() {
    _sessionController.close();
    _operationController.close();
    _conflictController.close();
    _progressController.close();
    _logController.close();
    _statusController.close();
  }

  /// Session'ı zorla sonlandır
  Future<void> terminateSession(String sessionId, {String? reason}) async {
    if (_currentSession?.sessionId == sessionId) {
      await endSession(reason: reason);
    }
  }

  /// Geçmişi temizle
  Future<void> clearHistory() async {
    _operations.clear();
    _conflicts.clear();
  }

  /// Session'ı tamamla
  Future<SenkronSession> completeSession(String sessionId) async {
    if (_currentSession?.sessionId == sessionId) {
      _currentSession = _currentSession!.copyWith(
        status: SenkronSessionStatus.completed,
        endTime: DateTime.now(),
      );
      return _currentSession!;
    }
    throw Exception('Session bulunamadı: $sessionId');
  }
}

/// Senkronizasyon durumu enum'u
enum SenkronStatus {
  idle,
  connecting,
  synchronizing,
  conflictResolution,
  completed,
  failed,
  cancelled,
}

/// Senkronizasyon durumu uzantıları
extension SenkronStatusExtension on SenkronStatus {
  String get displayName {
    switch (this) {
      case SenkronStatus.idle:
        return 'Boşta';
      case SenkronStatus.connecting:
        return 'Bağlanıyor';
      case SenkronStatus.synchronizing:
        return 'Senkronizasyon';
      case SenkronStatus.conflictResolution:
        return 'Conflict Çözümü';
      case SenkronStatus.completed:
        return 'Tamamlandı';
      case SenkronStatus.failed:
        return 'Başarısız';
      case SenkronStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  bool get isActive {
    return this == SenkronStatus.connecting ||
        this == SenkronStatus.synchronizing ||
        this == SenkronStatus.conflictResolution;
  }
}
