import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../services/sync_state_tracker.dart';
import '../services/document_change_tracker.dart';
import '../services/metadata_sync_manager.dart';
import '../services/senkron_conflict_resolver.dart';
import '../services/senkron_integrity_checker.dart';
import '../services/senkron_state_manager.dart';
import '../services/senkron_validation_service.dart';
import '../services/http_sunucu_enhanced.dart';
import '../utils/hash_comparator.dart';
import '../utils/network_optimizer.dart';
import '../utils/senkron_utils.dart';
import '../utils/timestamp_manager.dart';

class SenkronManagerEnhanced {
  // ============== Service Dependencies ==============
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final SyncStateTracker _stateTracker = SyncStateTracker.instance;
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;
  final MetadataSyncManager _metadataManager = MetadataSyncManager.instance;
  final SenkronConflictResolver _conflictResolver =
      SenkronConflictResolver.instance;
  final SenkronIntegrityChecker _integrityChecker =
      SenkronIntegrityChecker.instance;
  final SenkronValidationService _validationService =
      SenkronValidationService.instance;
  final NetworkOptimizer _networkOptimizer = NetworkOptimizer.instance;
  final TimestampManager _timestampManager = TimestampManager.instance;

  // ============== Progress Tracking ==============
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  // ============== Statistics ==============
  int _uploadedDocuments = 0;
  int _downloadedDocuments = 0;
  int _erroredDocuments = 0;
  int _conflictedDocuments = 0;
  int _skippedDocuments = 0;

  // ============== Configuration ==============
  Duration _syncThreshold = const Duration(minutes: 5);
  int _maxRetryAttempts = 3;
  bool _enableBidirectionalSync = true;
  String _conflictResolutionStrategy = 'LATEST_WINS';

  /// Ana senkronizasyon işlemi - Geliştirilmiş versiyon
  Future<Map<String, dynamic>> performEnhancedSynchronization(
    SenkronCihazi targetDevice, {
    bool bidirectional = true,
    String strategy = 'LATEST_WINS',
    DateTime? since,
  }) async {
    _resetStatistics();
    final syncResult = <String, dynamic>{};

    try {
      _addLog('🚀 Geliştirilmiş senkronizasyon başlatılıyor...');
      _addLog('🔗 Cihaz: ${targetDevice.ad} (${targetDevice.ip})');

      // ============== PHASE 0: INITIALIZATION ==============
      _updateProgress(0.05, 'Senkronizasyon başlatılıyor...');
      await _initializeSyncComponents();

      // ============== PHASE 1: NETWORK QUALITY TEST ==============
      _updateProgress(0.10, 'Network kalitesi test ediliyor...');
      final networkQuality = await _testNetworkQuality(targetDevice);
      syncResult['networkQuality'] = networkQuality;

      // ============== PHASE 2: BIDIRECTIONAL METADATA SYNC ==============
      _updateProgress(0.25, 'Metadata senkronizasyonu...');
      final metadataResult = await _performBidirectionalMetadataSync(
        targetDevice,
        since: since,
        bidirectional: bidirectional,
        strategy: strategy,
      );
      syncResult['metadataSync'] = metadataResult;

      // ============== PHASE 3: DOCUMENT CHANGE DETECTION ==============
      _updateProgress(0.40, 'Değişiklikler tespit ediliyor...');
      final changeResult = await _detectDocumentChanges(targetDevice, since);
      syncResult['changeDetection'] = changeResult;

      // ============== PHASE 4: CONFLICT RESOLUTION ==============
      _updateProgress(0.55, 'Çakışmalar çözülüyor...');
      final conflictResult = await _resolveDocumentConflicts(
        changeResult['conflicts'] ?? [],
        strategy,
      );
      syncResult['conflictResolution'] = conflictResult;

      // ============== PHASE 5: BIDIRECTIONAL DOCUMENT SYNC ==============
      _updateProgress(0.70, 'Belgeler senkronize ediliyor...');
      final documentResult = await _performBidirectionalDocumentSync(
        targetDevice,
        changeResult,
        conflictResult,
        bidirectional,
      );
      syncResult['documentSync'] = documentResult;

      // ============== PHASE 6: STATE UPDATE ==============
      _updateProgress(0.90, 'Senkronizasyon durumu güncelleniyor...');
      await _updateSyncStates(targetDevice, syncResult);

      // ============== PHASE 7: CLEANUP ==============
      _updateProgress(0.95, 'Temizlik işlemleri...');
      await _performCleanup();

      _updateProgress(1.0, 'Senkronizasyon tamamlandı');
      _addLog('✅ Geliştirilmiş senkronizasyon başarıyla tamamlandı!');
      _logDetailedStatistics();

      syncResult.addAll({
        'success': true,
        'timestamp': DateTime.now().toIso8601String(),
        'statistics': _getStatistics(),
      });

      return syncResult;
    } catch (e) {
      _addLog('❌ Senkronizasyon hatası: $e');

      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'statistics': _getStatistics(),
      };
    }
  }

  /// Senkronizasyon bileşenlerini başlat
  Future<void> _initializeSyncComponents() async {
    await _stateTracker.initializeSyncState();
    await _changeTracker.initializeChangeTracking();
    _addLog('📊 Senkronizasyon bileşenleri başlatıldı');
  }

  /// Network kalitesini test et
  Future<Map<String, dynamic>> _testNetworkQuality(
    SenkronCihazi targetDevice,
  ) async {
    try {
      final serverUrl = 'http://${targetDevice.ip}:8080';
      final qualityResult = await _networkOptimizer.testNetworkQuality(
        serverUrl,
      );

      _addLog('🌐 Network kalitesi: ${qualityResult.quality.name}');
      _addLog(
        '📶 Bandwidth: ${(qualityResult.bandwidth / 1024).toStringAsFixed(1)} KB/s',
      );
      _addLog('⏱️ Latency: ${qualityResult.latency}ms');

      return {
        'quality': qualityResult.quality.name,
        'bandwidth': qualityResult.bandwidth,
        'latency': qualityResult.latency,
        'packetLoss': qualityResult.packetLoss,
      };
    } catch (e) {
      _addLog('⚠️ Network kalite testi başarısız: $e');
      return {'quality': 'unknown', 'error': e.toString()};
    }
  }

  /// Çift yönlü metadata senkronizasyonu
  Future<Map<String, dynamic>> _performBidirectionalMetadataSync(
    SenkronCihazi targetDevice, {
    DateTime? since,
    bool bidirectional = true,
    String strategy = 'LATEST_WINS',
  }) async {
    try {
      final result = await _metadataManager.syncMetadata(
        targetDevice,
        since: since,
        bidirectional: bidirectional,
        strategy: strategy,
      );

      _addLog('📋 Metadata sync: ${result.success ? "Başarılı" : "Başarısız"}');
      if (result.success) {
        _addLog('   • Local değişiklikler: ${result.localChangesCount}');
        _addLog('   • Remote değişiklikler: ${result.remoteChangesCount}');
        _addLog('   • Çakışmalar: ${result.conflictsCount}');
        _addLog('   • Çözülen çakışmalar: ${result.resolvedConflictsCount}');
      }

      return {
        'success': result.success,
        'localChanges': result.localChangesCount,
        'remoteChanges': result.remoteChangesCount,
        'conflicts': result.conflictsCount,
        'resolved': result.resolvedConflictsCount,
        'error': result.error,
      };
    } catch (e) {
      _addLog('❌ Metadata sync hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Belge değişikliklerini tespit et
  Future<Map<String, dynamic>> _detectDocumentChanges(
    SenkronCihazi targetDevice,
    DateTime? since,
  ) async {
    try {
      final localDocuments = await _veriTabani.belgeleriGetir();
      final remoteDocuments = await _fetchRemoteDocuments(targetDevice.ip);

      final changes = <String, dynamic>{
        'newLocal': <BelgeModeli>[],
        'newRemote': <Map<String, dynamic>>[],
        'modifiedLocal': <BelgeModeli>[],
        'modifiedRemote': <Map<String, dynamic>>[],
        'conflicts': <Map<String, dynamic>>[],
      };

      // Remote belgelerde yeni/değişmiş olanları bul
      for (final remoteDoc in remoteDocuments) {
        final remoteHash = remoteDoc['hash'] ?? '';
        if (remoteHash.isEmpty) continue;

        final localMatch = localDocuments.firstWhere(
          (local) => local.dosyaHash == remoteHash,
          orElse: () => null as BelgeModeli,
        );

        if (localMatch == null) {
          // Yeni remote belge
          if (await _shouldSyncDocument(remoteHash)) {
            changes['newRemote'].add(remoteDoc);
          }
        } else {
          // Mevcut belgeyi karşılaştır
          final comparison = await _compareDocumentMetadata(
            localMatch,
            remoteDoc,
          );
          if (comparison['hasConflict']) {
            changes['conflicts'].add({
              'local': localMatch,
              'remote': remoteDoc,
              'conflictType': comparison['conflictType'],
            });
          } else if (comparison['remoteNewer']) {
            changes['modifiedRemote'].add(remoteDoc);
          }
        }
      }

      // Local belgelerde yeni/değişmiş olanları bul
      for (final localDoc in localDocuments) {
        if (localDoc.dosyaHash.isEmpty) continue;

        final remoteMatch = remoteDocuments.firstWhere(
          (remote) => remote['hash'] == localDoc.dosyaHash,
          orElse: () => null as Map<String, dynamic>,
        );

        if (remoteMatch == null) {
          // Yeni local belge
          if (await _shouldSyncDocument(localDoc.dosyaHash)) {
            changes['newLocal'].add(localDoc);
          }
        }
      }

      _addLog('🔍 Değişiklik tespit sonuçları:');
      _addLog('   • Yeni local belgeler: ${changes['newLocal'].length}');
      _addLog('   • Yeni remote belgeler: ${changes['newRemote'].length}');
      _addLog(
        '   • Değişmiş remote belgeler: ${changes['modifiedRemote'].length}',
      );
      _addLog('   • Çakışmalar: ${changes['conflicts'].length}');

      return changes;
    } catch (e) {
      _addLog('❌ Değişiklik tespit hatası: $e');
      return {'error': e.toString()};
    }
  }

  /// Belge çakışmalarını çöz
  Future<Map<String, dynamic>> _resolveDocumentConflicts(
    List<dynamic> conflicts,
    String strategy,
  ) async {
    final resolved = <Map<String, dynamic>>[];
    final unresolved = <Map<String, dynamic>>[];

    for (final conflict in conflicts) {
      try {
        final localDoc = conflict['local'] as BelgeModeli;
        final remoteDoc = conflict['remote'] as Map<String, dynamic>;

        final resolution = await _resolveConflict(
          localDoc,
          remoteDoc,
          strategy,
        );

        if (resolution['resolved']) {
          resolved.add(resolution);
          _addLog('✅ Çakışma çözüldü: ${localDoc.dosyaAdi}');
        } else {
          unresolved.add(conflict);
          _addLog('⚠️ Çakışma çözülemedi: ${localDoc.dosyaAdi}');
          _conflictedDocuments++;
        }
      } catch (e) {
        _addLog('❌ Çakışma çözüm hatası: $e');
        unresolved.add(conflict);
        _conflictedDocuments++;
      }
    }

    return {
      'resolved': resolved,
      'unresolved': unresolved,
      'resolvedCount': resolved.length,
      'unresolvedCount': unresolved.length,
    };
  }

  /// Çift yönlü belge senkronizasyonu
  Future<Map<String, dynamic>> _performBidirectionalDocumentSync(
    SenkronCihazi targetDevice,
    Map<String, dynamic> changes,
    Map<String, dynamic> conflictResolution,
    bool bidirectional,
  ) async {
    final result = <String, dynamic>{
      'uploaded': 0,
      'downloaded': 0,
      'errors': 0,
      'skipped': 0,
    };

    try {
      // Remote'dan yeni belgeleri indir
      if (bidirectional) {
        final newRemoteDocs = changes['newRemote'] as List<dynamic>;
        for (final remoteDoc in newRemoteDocs) {
          try {
            await _downloadDocumentWithRetry(targetDevice, remoteDoc);
            _downloadedDocuments++;
            result['downloaded']++;
          } catch (e) {
            _addLog('❌ İndirme hatası: ${remoteDoc['fileName']} - $e');
            _erroredDocuments++;
            result['errors']++;
          }
        }
      }

      // Local'dan yeni belgeleri yükle
      final newLocalDocs = changes['newLocal'] as List<BelgeModeli>;
      for (final localDoc in newLocalDocs) {
        try {
          await _uploadDocumentWithRetry(targetDevice, localDoc);
          _uploadedDocuments++;
          result['uploaded']++;
        } catch (e) {
          _addLog('❌ Yükleme hatası: ${localDoc.dosyaAdi} - $e');
          _erroredDocuments++;
          result['errors']++;
        }
      }

      // Çözülen çakışmaları uygula
      final resolvedConflicts = conflictResolution['resolved'] as List<dynamic>;
      for (final resolution in resolvedConflicts) {
        try {
          await _applyConflictResolution(targetDevice, resolution);
        } catch (e) {
          _addLog('❌ Çakışma uygulama hatası: $e');
          result['errors']++;
        }
      }

      return result;
    } catch (e) {
      _addLog('❌ Belge sync hatası: $e');
      return {'error': e.toString()};
    }
  }

  /// Retry mekanizması ile belge indirme
  Future<void> _downloadDocumentWithRetry(
    SenkronCihazi cihaz,
    Map<String, dynamic> docData,
  ) async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        await _downloadDocumentEnhanced(cihaz, docData);
        return; // Başarılı
      } catch (e) {
        if (attempt == _maxRetryAttempts) {
          rethrow; // Son deneme başarısız
        }

        _addLog('⚠️ İndirme denemesi $attempt başarısız, tekrar deneniyor...');
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Retry mekanizması ile belge yükleme
  Future<void> _uploadDocumentWithRetry(
    SenkronCihazi cihaz,
    BelgeModeli belge,
  ) async {
    for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        await _uploadDocumentEnhanced(cihaz, belge);
        return; // Başarılı
      } catch (e) {
        if (attempt == _maxRetryAttempts) {
          rethrow; // Son deneme başarısız
        }

        _addLog('⚠️ Yükleme denemesi $attempt başarısız, tekrar deneniyor...');
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Geliştirilmiş belge indirme
  Future<void> _downloadDocumentEnhanced(
    SenkronCihazi cihaz,
    Map<String, dynamic> docData,
  ) async {
    final fileName = docData['fileName'] ?? docData['dosyaAdi'];
    if (fileName == null) return;

    final dosyaHash = docData['hash'] ?? '';

    // State tracking başlat
    await _stateTracker.markAsSyncing(
      dosyaHash,
      fileName,
      hedefCihaz: cihaz.ad,
    );

    try {
      // Dosyayı indir
      final response = await http
          .get(Uri.parse('http://${cihaz.ip}:8080/download/$fileName'))
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // Hash kontrolü
      final downloadedHash = sha256.convert(response.bodyBytes).toString();
      if (dosyaHash.isNotEmpty && downloadedHash != dosyaHash) {
        throw Exception('Hash uyumsuzlığı');
      }

      // Dosyayı kaydet
      final belgelerKlasoru = await _dosyaServisi.belgelerKlasoruYolu();
      final filePath = '$belgelerKlasoru/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Veritabanına kaydet
      final belge = BelgeModeli(
        dosyaAdi: fileName,
        orijinalDosyaAdi: fileName,
        dosyaYolu: filePath,
        dosyaBoyutu: response.bodyBytes.length,
        dosyaTipi: docData['fileType'] ?? 'unknown',
        dosyaHash: downloadedHash,
        olusturmaTarihi: DateTime.now(),
        guncellemeTarihi: DateTime.now(),
        kategoriId: docData['categoryId'] ?? 1,
        baslik: docData['title'],
        aciklama: docData['description'],
      );

      final belgeId = await _veriTabani.belgeEkle(belge);

      // Change tracking
      await _changeTracker.trackDocumentChanges(
        belge.copyWith(id: belgeId),
        cihazId: cihaz.id,
        degisiklikAciklamasi: 'Downloaded from ${cihaz.ad}',
      );

      // State güncelle
      await _stateTracker.markAsSynced(
        downloadedHash,
        fileName,
        hedefCihaz: cihaz.ad,
      );

      _addLog('📥 İndirildi: $fileName');
    } catch (e) {
      await _stateTracker.markAsError(
        dosyaHash,
        fileName,
        e.toString(),
        hedefCihaz: cihaz.ad,
      );
      rethrow;
    }
  }

  /// Geliştirilmiş belge yükleme
  Future<void> _uploadDocumentEnhanced(
    SenkronCihazi cihaz,
    BelgeModeli belge,
  ) async {
    final dosya = File(belge.dosyaYolu);
    if (!await dosya.exists()) {
      throw Exception('Dosya bulunamadı: ${belge.dosyaYolu}');
    }

    // State tracking başlat
    await _stateTracker.markAsSyncing(
      belge.dosyaHash,
      belge.dosyaAdi,
      hedefCihaz: cihaz.ad,
    );

    try {
      // Multipart request
      final uri = Uri.parse('http://${cihaz.ip}:8080/upload');
      final request = http.MultipartRequest('POST', uri);

      final mimeType =
          lookupMimeType(belge.dosyaYolu) ?? 'application/octet-stream';
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        belge.dosyaYolu,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // Enhanced metadata
      request.fields.addAll(<String, String>{
        'title': belge.baslik ?? '',
        'description': belge.aciklama ?? '',
        'categoryId': belge.kategoriId.toString(),
        'personId': belge.kisiId?.toString() ?? '',
        'tags': belge.etiketler?.join(',') ?? '',
        'hash': belge.dosyaHash,
        'uploadTimestamp': DateTime.now().toIso8601String(),
        'sourceDevice': cihaz.id,
      });

      final response = await request.send().timeout(
        const Duration(seconds: 180),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      // State güncelle
      await _stateTracker.markAsSynced(
        belge.dosyaHash,
        belge.dosyaAdi,
        hedefCihaz: cihaz.ad,
      );

      _addLog('📤 Yüklendi: ${belge.dosyaAdi}');
    } catch (e) {
      await _stateTracker.markAsError(
        belge.dosyaHash,
        belge.dosyaAdi,
        e.toString(),
        hedefCihaz: cihaz.ad,
      );
      rethrow;
    }
  }

  /// Sync gerekli mi kontrol et
  Future<bool> _shouldSyncDocument(String dosyaHash) async {
    return await _stateTracker.shouldSync(
      BelgeModeli(
        dosyaAdi: '',
        orijinalDosyaAdi: '',
        dosyaYolu: '',
        dosyaBoyutu: 0,
        dosyaTipi: '',
        dosyaHash: dosyaHash,
        olusturmaTarihi: DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      ),
      threshold: _syncThreshold,
    );
  }

  /// Belge metadata karşılaştırması
  Future<Map<String, dynamic>> _compareDocumentMetadata(
    BelgeModeli localDoc,
    Map<String, dynamic> remoteDoc,
  ) async {
    final remoteTimestamp =
        remoteDoc['lastModified'] != null
            ? DateTime.tryParse(remoteDoc['lastModified'].toString()) ??
                DateTime.now()
            : DateTime.now();

    final hasConflict =
        localDoc.guncellemeTarihi.isAfter(remoteTimestamp) &&
        remoteTimestamp.isAfter(
          localDoc.guncellemeTarihi.subtract(_syncThreshold),
        );

    return {
      'hasConflict': hasConflict,
      'localNewer': localDoc.guncellemeTarihi.isAfter(remoteTimestamp),
      'remoteNewer': remoteTimestamp.isAfter(localDoc.guncellemeTarihi),
      'conflictType': hasConflict ? 'TIMESTAMP_CONFLICT' : 'NO_CONFLICT',
    };
  }

  /// Çakışma çözümü
  Future<Map<String, dynamic>> _resolveConflict(
    BelgeModeli localDoc,
    Map<String, dynamic> remoteDoc,
    String strategy,
  ) async {
    switch (strategy) {
      case 'LATEST_WINS':
        final remoteTimestamp =
            remoteDoc['lastModified'] != null
                ? DateTime.tryParse(remoteDoc['lastModified'].toString()) ??
                    DateTime.now()
                : DateTime.now();

        return {
          'resolved': true,
          'action':
              localDoc.guncellemeTarihi.isAfter(remoteTimestamp)
                  ? 'UPLOAD'
                  : 'DOWNLOAD',
          'document':
              localDoc.guncellemeTarihi.isAfter(remoteTimestamp)
                  ? localDoc
                  : remoteDoc,
        };

      case 'LOCAL_WINS':
        return {'resolved': true, 'action': 'UPLOAD', 'document': localDoc};

      case 'REMOTE_WINS':
        return {'resolved': true, 'action': 'DOWNLOAD', 'document': remoteDoc};

      case 'MANUAL':
        // Manuel çakışma çözümü - şimdilik latest wins
        return _resolveConflict(localDoc, remoteDoc, 'LATEST_WINS');

      default:
        return {'resolved': false, 'error': 'Unknown strategy: $strategy'};
    }
  }

  /// Çakışma çözümünü uygula
  Future<void> _applyConflictResolution(
    SenkronCihazi targetDevice,
    Map<String, dynamic> resolution,
  ) async {
    final action = resolution['action'] as String;

    switch (action) {
      case 'UPLOAD':
        final localDoc = resolution['document'] as BelgeModeli;
        await _uploadDocumentWithRetry(targetDevice, localDoc);
        break;
      case 'DOWNLOAD':
        final remoteDoc = resolution['document'] as Map<String, dynamic>;
        await _downloadDocumentWithRetry(targetDevice, remoteDoc);
        break;
    }
  }

  /// Senkronizasyon durumlarını güncelle
  Future<void> _updateSyncStates(
    SenkronCihazi targetDevice,
    Map<String, dynamic> syncResult,
  ) async {
    // Başarılı sync kayıtlarını güncelle
    if (syncResult['status'] == 'success') {
      await _stateTracker.clearErrorStates();
    }

    _addLog('📊 Senkronizasyon durumları güncellendi');
  }

  /// Temizlik işlemleri
  Future<void> _performCleanup() async {
    // Eski versiyonları temizle
    await _changeTracker.cleanupOldVersions(
      keepVersions: 10,
      olderThan: const Duration(days: 30),
    );

    // Eski sync state kayıtlarını temizle
    await _stateTracker.cleanupOldSyncStates(
      olderThan: const Duration(days: 7),
    );

    _addLog('🧹 Temizlik işlemleri tamamlandı');
  }

  /// Remote belgeler listesini al
  Future<List<Map<String, dynamic>>> _fetchRemoteDocuments(
    String remoteIP,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$remoteIP:8080/documents'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['documents'] ?? []);
      }
      return [];
    } catch (e) {
      _addLog('❌ Remote belgeler alınamadı: $e');
      return [];
    }
  }

  /// Utility methods
  void _resetStatistics() {
    _uploadedDocuments = 0;
    _downloadedDocuments = 0;
    _erroredDocuments = 0;
    _conflictedDocuments = 0;
    _skippedDocuments = 0;
  }

  Map<String, int> _getStatistics() {
    return {
      'uploaded': _uploadedDocuments,
      'downloaded': _downloadedDocuments,
      'errors': _erroredDocuments,
      'conflicts': _conflictedDocuments,
      'skipped': _skippedDocuments,
    };
  }

  void _updateProgress(double progress, String? operation) {
    onProgressUpdate?.call(progress);
    if (operation != null) {
      onOperationUpdate?.call(operation);
    }
  }

  void _addLog(String message) {
    onLogMessage?.call(message);
  }

  void _logDetailedStatistics() {
    _addLog('📊 Detaylı Senkronizasyon İstatistikleri:');
    _addLog('   • Yüklenen belgeler: $_uploadedDocuments');
    _addLog('   • İndirilen belgeler: $_downloadedDocuments');
    _addLog('   • Hatalı işlemler: $_erroredDocuments');
    _addLog('   • Çakışan belgeler: $_conflictedDocuments');
    _addLog('   • Atlanan belgeler: $_skippedDocuments');
  }

  /// Configuration methods
  void configureSyncSettings({
    Duration? syncThreshold,
    int? maxRetryAttempts,
    bool? enableBidirectionalSync,
    String? conflictResolutionStrategy,
  }) {
    if (syncThreshold != null) _syncThreshold = syncThreshold;
    if (maxRetryAttempts != null) _maxRetryAttempts = maxRetryAttempts;
    if (enableBidirectionalSync != null)
      _enableBidirectionalSync = enableBidirectionalSync;
    if (conflictResolutionStrategy != null)
      _conflictResolutionStrategy = conflictResolutionStrategy;
  }

  /// Callback ayarlama metodu
  void setCallbacks({
    Function(double)? onProgress,
    Function(String)? onOperation,
    Function(String)? onLog,
  }) {
    onProgressUpdate = onProgress;
    onOperationUpdate = onOperation;
    onLogMessage = onLog;
  }
}
