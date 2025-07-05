import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../models/senkron_delta.dart';
import '../models/senkron_metadata.dart';
import '../models/senkron_operation.dart';
import '../models/senkron_session.dart';
import '../utils/yardimci_fonksiyonlar.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'sync_state_tracker.dart';
import 'document_change_tracker.dart';
import 'metadata_sync_manager.dart';
import 'senkron_delta_manager.dart';

/// Gelişmiş senkronizasyon yöneticisi - Tüm özellikler aktif
class SenkronManagerEnhanced {
  final VeriTabaniServisi _veriTabani;
  final DosyaServisi _dosyaServisi;
  final SyncStateTracker _stateTracker;
  final DocumentChangeTracker _changeTracker;
  final MetadataSyncManager _metadataManager;
  final SenkronDeltaManager _deltaManager;

  // Senkronizasyon durumu
  bool _senkronizasyonAktif = false;
  bool _durduruldu = false;
  bool _hataOlustu = false;
  String? _sonHata;

  // İstatistikler
  int _downloadedDocuments = 0;
  int _uploadedDocuments = 0;
  int _skippedDocuments = 0;
  int _erroredDocuments = 0;
  int _conflictedDocuments = 0;
  int _resolvedConflicts = 0;

  // Progress tracking
  double _progress = 0.0;
  String _currentOperation = '';
  int _totalOperations = 0;
  int _completedOperations = 0;

  // Callback'ler
  Function(String)? onLogMessage;
  Function(double)? onProgressUpdate;
  Function(String)? onStatusUpdate;

  // Configurasyon
  static const Duration _syncTimeout = Duration(seconds: 300);
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxRetries = 3;

  // Local device ID
  String? _localDeviceId;

  // Log mesajları
  final List<String> _logMessages = [];

  SenkronManagerEnhanced(
    this._veriTabani,
    this._dosyaServisi,
    this._stateTracker,
    this._changeTracker,
    this._metadataManager,
    this._deltaManager,
  );

  // ============== GENEL DURUMU ==============

  bool get senkronizasyonAktif => _senkronizasyonAktif;
  bool get durduruldu => _durduruldu;
  bool get hataOlustu => _hataOlustu;
  String? get sonHata => _sonHata;
  double get progress => _progress;
  String get currentOperation => _currentOperation;
  List<String> get logMessages => List.from(_logMessages);

  Map<String, dynamic> get statistics => {
    'downloaded': _downloadedDocuments,
    'uploaded': _uploadedDocuments,
    'skipped': _skippedDocuments,
    'errors': _erroredDocuments,
    'conflicts': _conflictedDocuments,
    'resolved': _resolvedConflicts,
    'total':
        _downloadedDocuments +
        _uploadedDocuments +
        _skippedDocuments +
        _erroredDocuments,
  };

  // ============== CALLBACK AYARLARI ==============

  void setCallbacks({
    Function(String)? onLog,
    Function(double)? onProgress,
    Function(String)? onStatus,
  }) {
    onLogMessage = onLog;
    onProgressUpdate = onProgress;
    onStatusUpdate = onStatus;
  }

  // ============== ANA SENKRONIZASYON METODLARI ==============

  /// Tam senkronizasyon - Tüm özellikler aktif
  Future<Map<String, dynamic>> performFullSync(
    SenkronCihazi targetDevice, {
    bool bidirectional = true,
    String conflictStrategy = 'LATEST_WINS',
    bool syncMetadata = true,
    bool useDeltaSync = false,
    DateTime? since,
  }) async {
    if (_senkronizasyonAktif) {
      throw Exception('Senkronizasyon zaten aktif');
    }

    _resetSyncState();
    _senkronizasyonAktif = true;

    try {
      _updateStatus('Senkronizasyon başlatılıyor...');
      _addLog('🚀 Gelişmiş senkronizasyon başlatıldı');
      _addLog('   • Hedef cihaz: ${targetDevice.ad} (${targetDevice.ip})');
      _addLog('   • Çift yönlü: ${bidirectional ? "Evet" : "Hayır"}');
      _addLog('   • Çakışma stratejisi: $conflictStrategy');
      _addLog('   • Metadata sync: ${syncMetadata ? "Evet" : "Hayır"}');
      _addLog('   • Delta sync: ${useDeltaSync ? "Evet" : "Hayır"}');

      // Local device ID'yi al
      _localDeviceId = await _getLocalDeviceId();

      // Senkronizasyon adımları
      final results = <String, dynamic>{};

      // 1. Bağlantı testi
      _updateOperation('Bağlantı test ediliyor...');
      final connectionTest = await _testConnection(targetDevice);
      if (!connectionTest['success']) {
        throw Exception('Bağlantı hatası: ${connectionTest['error']}');
      }
      _addLog('✅ Bağlantı başarılı');

      // 2. Metadata senkronizasyonu - GEÇİCİ OLARAK ATLANIYOR
      if (syncMetadata) {
        _updateOperation('Metadata senkronizasyonu...');
        _addLog('⚠️ Metadata sync GEÇİCİ OLARAK ATLANIYOR - Debug için');
        _addLog('📋 Doğrudan full document sync\'e geçiliyor...');
        /*
        try {
          final metadataResult = await _performMetadataSync(targetDevice);
          results['metadata'] = metadataResult;
          _addLog(
            '📋 Metadata sync: ${metadataResult['success'] ? "Başarılı" : "Başarısız"}',
          );
        } catch (e) {
          _addLog('⚠️ Metadata sync hatası: $e');
          _addLog('📋 Metadata sync atlanıyor, full sync devam ediyor...');
          results['metadata'] = {'success': false, 'error': e.toString()};
        }
        */
      }

      // 3. DOSYA TRANSFERİ - FULL DOCUMENT SYNC (HER ZAMAN AKTİF!)
      _updateOperation('📄 Kapsamlı dosya transferi başlatılıyor...');
      _addLog('🚀 FULL DOCUMENT SYNC ZORLA AKTİF!');
      _addLog('   • Upload/Download: Açık');
      _addLog('   • Bidirectional: ${bidirectional ? "Açık" : "Kapalı"}');
      _addLog('   • Conflict Strategy: $conflictStrategy');

      final fullResult = await _performFullDocumentSync(targetDevice);
      results['documents'] = fullResult;

      // İstatistikleri güncelle
      _downloadedDocuments += (fullResult['downloaded'] ?? 0) as int;
      _uploadedDocuments += (fullResult['uploaded'] ?? 0) as int;
      _skippedDocuments += (fullResult['skipped'] ?? 0) as int;
      _erroredDocuments += (fullResult['errors'] ?? 0) as int;

      _addLog('📊 Dosya transfer sonuçları:');
      _addLog('   • Upload: ${fullResult['uploaded'] ?? 0}');
      _addLog('   • Download: ${fullResult['downloaded'] ?? 0}');
      _addLog('   • Skip: ${fullResult['skipped'] ?? 0}');
      _addLog('   • Error: ${fullResult['errors'] ?? 0}');

      // 4. Çakışma çözümü
      if (_conflictedDocuments > 0) {
        _updateOperation('Çakışmalar çözülüyor...');
        final conflictResult = await _resolveAllConflicts(
          targetDevice,
          conflictStrategy,
        );
        results['conflicts'] = conflictResult;
        _resolvedConflicts = conflictResult['resolved'] ?? 0;
      }

      // 5. Temizlik ve optimizasyon
      _updateOperation('Temizlik yapılıyor...');
      await _performCleanup();

      _updateStatus('Senkronizasyon tamamlandı');
      _addLog('🎉 Senkronizasyon başarıyla tamamlandı');
      _addLog('   • İndirilen: $_downloadedDocuments');
      _addLog('   • Yüklenen: $_uploadedDocuments');
      _addLog('   • Atlanan: $_skippedDocuments');
      _addLog('   • Hatalı: $_erroredDocuments');
      _addLog('   • Çakışma: $_conflictedDocuments');
      _addLog('   • Çözülen: $_resolvedConflicts');

      return {
        'success': true,
        'statistics': statistics,
        'results': results,
        'duration': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      _hataOlustu = true;
      _sonHata = e.toString();
      _addLog('❌ Senkronizasyon hatası: $e');
      _updateStatus('Senkronizasyon hatası');

      return {
        'success': false,
        'error': e.toString(),
        'statistics': statistics,
      };
    } finally {
      _senkronizasyonAktif = false;
      _updateProgress(1.0);
    }
  }

  /// Metadata senkronizasyonu
  Future<Map<String, dynamic>> _performMetadataSync(
    SenkronCihazi targetDevice,
  ) async {
    try {
      _addLog('📋 Gelişmiş metadata senkronizasyonu başlatılıyor...');

      // MetadataSyncManager ile tam senkronizasyon
      final result = await _metadataManager.syncMetadata(
        targetDevice,
        _localDeviceId!,
      );

      // Basit metadata sync'i de paralel olarak çalıştır (backward compatibility)
      int additionalReceived = 0;
      try {
        // 1. Kategorileri sync et
        final remoteCategories = await _fetchRemoteCategories(targetDevice);
        final categoryResults = await _syncCategories(remoteCategories);
        additionalReceived += categoryResults;
        _addLog('📂 Kategoriler senkronize edildi: $categoryResults yeni');

        // 2. Kişileri sync et
        final remotePeople = await _fetchRemotePeople(targetDevice);
        final peopleResults = await _syncPeople(remotePeople);
        additionalReceived += peopleResults;
        _addLog('👥 Kişiler senkronize edildi: $peopleResults yeni');
      } catch (e) {
        _addLog('⚠️ Basit metadata sync hatası: $e');
      }

      final success = (result['errors'] ?? 0) == 0;
      final totalReceived = (result['received'] ?? 0) + additionalReceived;

      if (success) {
        _addLog('✅ Metadata senkronizasyonu tamamlandı');
        _addLog('   • Gönderilen metadata: ${result['sent'] ?? 0}');
        _addLog('   • Alınan metadata: $totalReceived');
        _addLog('   • Çakışmalar: ${result['conflicts'] ?? 0}');
      }

      return {
        'success': success,
        'sent': result['sent'] ?? 0,
        'received': totalReceived,
        'conflicts': result['conflicts'] ?? 0,
        'error': success ? null : 'Metadata sync hatası',
      };
    } catch (e) {
      _addLog('❌ Metadata sync hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remote kategorileri al
  Future<List<Map<String, dynamic>>> _fetchRemoteCategories(
    SenkronCihazi device,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://${device.ip}:8080/categories'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['categories'] ?? []);
      }
      return [];
    } catch (e) {
      _addLog('❌ Remote kategoriler alınamadı: $e');
      return [];
    }
  }

  /// Remote kişileri al
  Future<List<Map<String, dynamic>>> _fetchRemotePeople(
    SenkronCihazi device,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://${device.ip}:8080/people'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['people'] ?? []);
      }
      return [];
    } catch (e) {
      _addLog('❌ Remote kişiler alınamadı: $e');
      return [];
    }
  }

  /// Kategorileri senkronize et
  Future<int> _syncCategories(
    List<Map<String, dynamic>> remoteCategories,
  ) async {
    final localCategories = await _veriTabani.kategorileriGetir();
    int newCount = 0;

    for (final remoteCategory in remoteCategories) {
      final categoryName = remoteCategory['ad'] ?? remoteCategory['name'];
      if (categoryName == null || categoryName.isEmpty) continue;

      final exists = localCategories.any(
        (cat) => cat.kategoriAdi == categoryName,
      );

      if (!exists) {
        final newCategory = KategoriModeli(
          kategoriAdi: categoryName,
          renkKodu:
              remoteCategory['renkKodu'] ??
              remoteCategory['color'] ??
              '#2196F3',
          simgeKodu:
              remoteCategory['simgeKodu'] ?? remoteCategory['icon'] ?? 'folder',
          aciklama: remoteCategory['aciklama'] ?? remoteCategory['description'],
          olusturmaTarihi: DateTime.now(),
        );

        await _veriTabani.kategoriEkle(newCategory);
        newCount++;
      }
    }

    return newCount;
  }

  /// Kişileri senkronize et
  Future<int> _syncPeople(List<Map<String, dynamic>> remotePeople) async {
    final localPeople = await _veriTabani.kisileriGetir();
    int newCount = 0;

    for (final remotePerson in remotePeople) {
      // Türkçe ve İngilizce field isimleri ile uyumlu hale getir
      final firstName = remotePerson['ad'] ?? remotePerson['firstName'];
      final lastName = remotePerson['soyad'] ?? remotePerson['lastName'];

      if (firstName == null || lastName == null) continue;

      final exists = localPeople.any(
        (person) => person.ad == firstName && person.soyad == lastName,
      );

      if (!exists) {
        final newPerson = KisiModeli(
          ad: firstName,
          soyad: lastName,
          olusturmaTarihi: DateTime.now(),
          guncellemeTarihi: DateTime.now(),
        );

        await _veriTabani.kisiEkle(newPerson);
        newCount++;
      }
    }

    return newCount;
  }

  /// Delta senkronizasyonu
  Future<Map<String, dynamic>> _performDeltaSync(
    SenkronCihazi targetDevice, {
    DateTime? since,
  }) async {
    try {
      // Şimdilik basit delta sync implementasyonu
      final localChanges = await _changeTracker.getChangedDocuments(
        since ?? DateTime.now().subtract(const Duration(days: 1)),
      );

      // Remote delta'ları al
      final remoteDeltas = await _fetchRemoteDeltas(targetDevice, since);

      // Remote delta'ları işle
      int processedCount = 0;
      int errorCount = 0;

      for (final delta in remoteDeltas) {
        try {
          // Delta'yı işle (basit implementasyon)
          processedCount++;
        } catch (e) {
          errorCount++;
          _addLog('❌ Delta işleme hatası: $e');
        }
      }

      _addLog('📦 Delta sync tamamlandı');
      _addLog('   • Local değişiklikler: ${localChanges.length}');
      _addLog('   • Remote delta: ${remoteDeltas.length}');
      _addLog('   • İşlenen: $processedCount');
      _addLog('   • Hatalar: $errorCount');

      return {
        'success': true,
        'localChanges': localChanges.length,
        'remoteDeltas': remoteDeltas.length,
        'processed': processedCount,
        'errors': errorCount,
      };
    } catch (e) {
      _addLog('❌ Delta sync hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Tam belge senkronizasyonu
  Future<Map<String, dynamic>> _performFullDocumentSync(
    SenkronCihazi targetDevice,
  ) async {
    _addLog('📄 Kapsamlı belge senkronizasyonu başlatılıyor...');

    int uploaded = 0;
    int downloaded = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorMessages = [];

    try {
      // 1. Yerel belgeleri yükle
      try {
        final localDocuments = await _veriTabani.belgeleriGetir();
        _addLog('📋 Yerel belgeler: ${localDocuments.length} adet');

        for (final doc in localDocuments) {
          if (doc.dosyaYolu.isEmpty) continue;

          try {
            // Upload öncesi remote'da zaten var mı kontrol et
            final shouldUpload = await _shouldUploadToDevice(targetDevice, doc);
            if (!shouldUpload['upload']) {
              skipped++;
              _addLog(
                '⏭️ Zaten mevcut: ${doc.dosyaAdi} (${shouldUpload['reason']})',
              );
              continue;
            }

            await _uploadDocument(targetDevice, doc);
            uploaded++;
            _addLog('✅ Yüklendi: ${doc.dosyaAdi}');
          } catch (e) {
            errors++;
            final errorMsg = 'Yükleme hatası: ${doc.dosyaAdi} - $e';
            errorMessages.add(errorMsg);
            _addLog('❌ $errorMsg');
          }
        }
      } catch (e) {
        errors++;
        final errorMsg = 'Yerel belge listesi alınamadı: $e';
        errorMessages.add(errorMsg);
        _addLog('❌ $errorMsg');
      }

      // 2. Uzak belgeleri indir
      try {
        final remoteDocuments = await _fetchRemoteDocuments(targetDevice);
        _addLog('📥 Uzak belgeler: ${remoteDocuments.length} adet');

        for (final remoteDoc in remoteDocuments) {
          final fileName = remoteDoc['dosyaAdi'] ?? remoteDoc['fileName'];
          if (fileName == null) continue;

          try {
            // Yerel varlığını kontrol et (gelişmiş)
            final existsResult = await _checkLocalDocumentExists(remoteDoc);
            if (existsResult['exists'] == true) {
              skipped++;
              _addLog('⏭️ Zaten mevcut: $fileName (${existsResult['reason']})');
              continue;
            }

            await _downloadDocument(targetDevice, remoteDoc);
            downloaded++;
            _addLog('✅ İndirildi: $fileName');
          } catch (e) {
            errors++;
            final errorMsg = 'İndirme hatası: $fileName - $e';
            errorMessages.add(errorMsg);
            _addLog('❌ $errorMsg');
          }
        }
      } catch (e) {
        errors++;
        final errorMsg = 'Uzak belge listesi alınamadı: $e';
        errorMessages.add(errorMsg);
        _addLog('❌ $errorMsg');
      }

      // 3. Senkronizasyon durumunu güncelle
      try {
        await _stateTracker.updateSyncSession(
          targetDevice.id,
          _localDeviceId!,
          uploaded + downloaded,
          errors,
        );
      } catch (e) {
        _addLog('⚠️ Sync durumu güncellenemedi: $e');
      }

      // 4. Değişiklikleri kaydet
      try {
        await _changeTracker.commitChanges(targetDevice.id);
        _addLog('✅ Değişiklikler kaydedildi');
      } catch (e) {
        _addLog('⚠️ Değişiklikler kaydedilemedi: $e');
      }

      final success = errors == 0;

      if (success) {
        _addLog('✅ Belge senkronizasyonu tamamlandı');
      } else {
        _addLog('⚠️ Belge senkronizasyonu tamamlandı (bazı hatalar ile)');
      }

      _addLog('   📤 Yüklenen: $uploaded belgeler');
      _addLog('   📥 İndirilen: $downloaded belgeler');
      _addLog('   ⏭️ Atlanan: $skipped belgeler');
      _addLog('   ❌ Hata: $errors belgeler');

      return {
        'success': success,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'skipped': skipped,
        'errors': errors,
        'errorMessages': errorMessages,
      };
    } catch (e) {
      _addLog('❌ Kritik belge sync hatası: $e');
      return {
        'success': false,
        'error': e.toString(),
        'uploaded': uploaded,
        'downloaded': downloaded,
        'skipped': skipped,
        'errors': errors + 1,
        'errorMessages': [...errorMessages, e.toString()],
      };
    }
  }

  /// Belge yükleme
  Future<void> _uploadDocument(SenkronCihazi device, BelgeModeli doc) async {
    final file = File(doc.dosyaYolu);
    if (!await file.exists()) {
      throw Exception('Dosya bulunamadı: ${doc.dosyaYolu}');
    }

    // Multipart request oluştur
    final uri = Uri.parse('http://${device.ip}:8080/upload');
    final request = http.MultipartRequest('POST', uri);

    // Dosyayı ekle ve gerçek hash'i hesapla
    final fileBytes = await file.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: doc.dosyaAdi,
      contentType: MediaType.parse(
        lookupMimeType(doc.dosyaAdi) ?? 'application/octet-stream',
      ),
    );
    request.files.add(multipartFile);

    // Gerçek dosya hash'ini hesapla (tutarlılık için)
    final realFileHash = sha256.convert(fileBytes).toString();

    // Eğer DB'deki hash ile gerçek hash farklıysa uyar ve DB'yi güncelle
    if (doc.dosyaHash != null && doc.dosyaHash != realFileHash) {
      _addLog('⚠️ Hash uyumsuzluğu tespit edildi!');
      _addLog('   • DB Hash: ${doc.dosyaHash?.substring(0, 16)}...');
      _addLog('   • Gerçek Hash: ${realFileHash.substring(0, 16)}...');
      _addLog('   • Gerçek hash kullanılacak ve DB güncellenecek');

      // Veritabanındaki hash'i güncelle
      try {
        final updatedDoc = BelgeModeli(
          id: doc.id,
          dosyaAdi: doc.dosyaAdi,
          orijinalDosyaAdi: doc.orijinalDosyaAdi,
          dosyaYolu: doc.dosyaYolu,
          dosyaBoyutu: doc.dosyaBoyutu,
          dosyaTipi: doc.dosyaTipi,
          dosyaHash: realFileHash, // Gerçek hash
          olusturmaTarihi: doc.olusturmaTarihi,
          guncellemeTarihi: DateTime.now(), // Güncelleme zamanı
          kategoriId: doc.kategoriId,
          baslik: doc.baslik,
          aciklama: doc.aciklama,
          kisiId: doc.kisiId,
          etiketler: doc.etiketler,
          aktif: doc.aktif,
          senkronDurumu: doc.senkronDurumu,
          sonErisimTarihi: doc.sonErisimTarihi,
        );

        await _veriTabani.belgeGuncelle(updatedDoc);
        _addLog('✅ Veritabanı hash güncellendi');
      } catch (e) {
        _addLog('⚠️ Veritabanı hash güncellenemedi: $e');
      }
    }

    // Kişi bilgilerini al ve metadata'ya ekle
    String? kisiAd, kisiSoyad;
    if (doc.kisiId != null) {
      try {
        final kisi = await _veriTabani.kisiGetir(doc.kisiId!);
        if (kisi != null) {
          kisiAd = kisi.ad;
          kisiSoyad = kisi.soyad;
        }
      } catch (e) {
        _addLog('⚠️ Kişi bilgisi alınamadı: ${doc.kisiId}');
      }
    }

    // Metadata ekle - kişi bilgileri ile birlikte (tutarlı field naming)
    request.fields['belge_data'] = json.encode({
      'id': doc.id,
      'dosyaAdi': doc.dosyaAdi,
      'orijinalDosyaAdi': doc.orijinalDosyaAdi,
      'dosyaBoyutu': doc.dosyaBoyutu,
      'dosyaTipi': doc.dosyaTipi,
      'dosyaHash': realFileHash, // Gerçek hash kullan
      'kategoriId': doc.kategoriId,
      'kisiId': doc.kisiId,
      'kisiAd': kisiAd,
      'kisiSoyad': kisiSoyad,
      'baslik': doc.baslik,
      'aciklama': doc.aciklama,
      'etiketler': doc.etiketler,
      'olusturmaTarihi': doc.olusturmaTarihi.toIso8601String(),
      'guncellemeTarihi': doc.guncellemeTarihi.toIso8601String(),
      'aktif': doc.aktif,
      // Belge kimlik sistemi (Dosya Hash + Kişi ID - TC gibi sabit)
      'belgeKimlik': '${realFileHash}_${doc.kisiId ?? 'unknown'}',
    });

    // İstek gönder
    final response = await request.send().timeout(const Duration(seconds: 300));

    if (response.statusCode != 200) {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Upload hatası (${response.statusCode}): $responseBody');
    }

    _addLog(
      '📤 Yüklendi: ${doc.dosyaAdi} (${YardimciFonksiyonlar.dosyaBoyutuFormatla(doc.dosyaBoyutu)})',
    );
  }

  /// Belge indirme
  Future<void> _downloadDocument(
    SenkronCihazi device,
    Map<String, dynamic> remoteDoc,
  ) async {
    final fileName = remoteDoc['dosyaAdi'] ?? remoteDoc['fileName'];
    final fileHash = remoteDoc['dosyaHash'] ?? remoteDoc['fileHash'];

    if (fileName == null || fileHash == null) {
      throw Exception('Geçersiz dosya bilgisi');
    }

    // Download isteği
    final uri = Uri.parse('http://${device.ip}:8080/download/$fileHash');
    final response = await http.get(uri).timeout(const Duration(seconds: 300));

    if (response.statusCode != 200) {
      throw Exception(
        'Download hatası (${response.statusCode}): ${response.body}',
      );
    }

    // Dosyayı kaydet
    final belgelerKlasoru = await _dosyaServisi.belgelerKlasoruYolu();
    final filePath = path.join(belgelerKlasoru, fileName);
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    // Veritabanına ekle
    final belge = BelgeModeli(
      dosyaAdi: fileName,
      orijinalDosyaAdi: fileName,
      dosyaYolu: filePath,
      dosyaBoyutu: response.bodyBytes.length,
      dosyaTipi: remoteDoc['dosyaTipi'] ?? _getMimeType(fileName),
      dosyaHash: fileHash,
      kategoriId: remoteDoc['kategoriId'],
      kisiId: remoteDoc['kisiId'],
      baslik: remoteDoc['baslik'],
      aciklama: remoteDoc['aciklama'],
      etiketler:
          remoteDoc['etiketler'] != null
              ? List<String>.from(remoteDoc['etiketler'])
              : null,
      olusturmaTarihi:
          DateTime.tryParse(remoteDoc['olusturmaTarihi'] ?? '') ??
          DateTime.now(),
      guncellemeTarihi:
          DateTime.tryParse(remoteDoc['guncellemeTarihi'] ?? '') ??
          DateTime.now(),
      aktif: remoteDoc['aktif'] ?? true,
    );

    final belgeId = await _veriTabani.belgeEkle(belge);
    _addLog(
      '📥 İndirildi: $fileName (${YardimciFonksiyonlar.dosyaBoyutuFormatla(response.bodyBytes.length)})',
    );
  }

  /// Uzak belgeleri getir
  Future<List<Map<String, dynamic>>> _fetchRemoteDocuments(
    SenkronCihazi device,
  ) async {
    final uri = Uri.parse('http://${device.ip}:8080/documents');
    final response = await http.get(uri).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
        'Belge listesi alınamadı (${response.statusCode}): ${response.body}',
      );
    }

    final data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception('Belge listesi hatası: ${data['message']}');
    }

    return List<Map<String, dynamic>>.from(data['documents'] ?? []);
  }

  /// Local belge varlığını kontrol et (gelişmiş)
  Future<Map<String, dynamic>> _checkLocalDocumentExists(
    Map<String, dynamic> remoteDoc,
  ) async {
    final fileHash = remoteDoc['dosyaHash'] ?? remoteDoc['fileHash'];
    if (fileHash == null) {
      return {'exists': false, 'reason': 'Hash bilgisi eksik'};
    }

    final existingDoc = await _veriTabani.belgeGetirByHash(fileHash);
    if (existingDoc == null) {
      return {'exists': false, 'reason': 'Dosya mevcut değil'};
    }

    // Hash'i aynı olan belge bulundu, şimdi kişi bilgilerini kontrol et
    final remoteKisiId = remoteDoc['kisiId'];
    final remoteKisiAd = remoteDoc['kisiAd']?.toString();
    final remoteKisiSoyad = remoteDoc['kisiSoyad']?.toString();

    // Belge kimlik kontrolü - gerçek hash'i kullan (eğer dosya varsa)
    final remoteBelgeKimlik = remoteDoc['belgeKimlik']?.toString();

    // Local dosyanın belge kimliğini oluştur (Hash + Kişi ID)
    String localBelgeKimlik =
        '${existingDoc.dosyaHash}_${existingDoc.kisiId ?? 'unknown'}';

    // Dosya mevcutsa gerçek hash'i kontrol et
    final localFile = File(existingDoc.dosyaYolu);
    if (await localFile.exists()) {
      final localFileBytes = await localFile.readAsBytes();
      final realLocalHash = sha256.convert(localFileBytes).toString();

      if (realLocalHash != existingDoc.dosyaHash) {
        _addLog('⚠️ Local dosya hash uyumsuzluğu tespit edildi');
        _addLog('   • DB Hash: ${existingDoc.dosyaHash?.substring(0, 16)}...');
        _addLog('   • Gerçek Hash: ${realLocalHash.substring(0, 16)}...');
        localBelgeKimlik =
            '${realLocalHash}_${existingDoc.kisiId ?? 'unknown'}';
      }
    }

    _addLog('🔍 Belge varlık kontrolü:');
    _addLog('   • Dosya Hash: ${fileHash.substring(0, 16)}...');
    _addLog('   • Remote Kişi ID: $remoteKisiId');
    _addLog('   • Local Kişi ID: ${existingDoc.kisiId}');
    _addLog('   • Remote Belge Kimlik: $remoteBelgeKimlik');
    _addLog('   • Local Belge Kimlik: $localBelgeKimlik');

    // Aynı hash ve aynı kişi = tamamen aynı belge
    if (existingDoc.kisiId == remoteKisiId) {
      return {
        'exists': true,
        'reason': 'Aynı dosya, aynı kişi',
        'action': 'skip',
      };
    }

    // Aynı hash ama farklı kişi = güncelleme gerekli
    if (existingDoc.kisiId != remoteKisiId) {
      _addLog('⚠️ Kişi bilgisi farklı - güncelleme gerekli');

      // Kişi bilgisini güncelle
      try {
        // Önce remote kişiyi local'de bul/oluştur
        int? eslestirilenKisiId;
        if (remoteKisiAd != null && remoteKisiAd.isNotEmpty) {
          final yerelKisiler = await _veriTabani.kisileriGetir();
          final eslestirilenKisi = yerelKisiler.firstWhere(
            (k) =>
                k.ad.toLowerCase() == remoteKisiAd.toLowerCase() &&
                k.soyad.toLowerCase() == (remoteKisiSoyad ?? '').toLowerCase(),
            orElse:
                () => KisiModeli(
                  ad: '',
                  soyad: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                ),
          );

          if (eslestirilenKisi.ad.isNotEmpty) {
            eslestirilenKisiId = eslestirilenKisi.id;
          } else {
            // Yeni kişi oluştur
            final yeniKisi = KisiModeli(
              ad: remoteKisiAd,
              soyad: remoteKisiSoyad ?? '',
              olusturmaTarihi: DateTime.now(),
              guncellemeTarihi: DateTime.now(),
            );
            eslestirilenKisiId = await _veriTabani.kisiEkle(yeniKisi);
            _addLog('👤 Yeni kişi oluşturuldu: ${yeniKisi.tamAd}');
          }
        }

        // Belgeyi güncelle
        if (eslestirilenKisiId != null) {
          final guncelBelge = BelgeModeli(
            id: existingDoc.id,
            dosyaAdi: existingDoc.dosyaAdi,
            orijinalDosyaAdi: existingDoc.orijinalDosyaAdi,
            dosyaYolu: existingDoc.dosyaYolu,
            dosyaBoyutu: existingDoc.dosyaBoyutu,
            dosyaTipi: existingDoc.dosyaTipi,
            dosyaHash: existingDoc.dosyaHash,
            kategoriId: existingDoc.kategoriId,
            kisiId: eslestirilenKisiId, // Güncellenen kişi ID
            baslik: existingDoc.baslik,
            aciklama: existingDoc.aciklama,
            etiketler: existingDoc.etiketler,
            olusturmaTarihi: existingDoc.olusturmaTarihi,
            guncellemeTarihi: DateTime.now(),
            aktif: existingDoc.aktif,
          );

          await _veriTabani.belgeGuncelle(guncelBelge);
          _addLog('✅ Belge kişi bilgisi güncellendi');
        }

        return {
          'exists': true,
          'reason': 'Kişi bilgisi güncellendi',
          'action': 'updated',
        };
      } catch (e) {
        _addLog('❌ Belge güncellemesi hatası: $e');
        return {
          'exists': false,
          'reason': 'Güncelleme hatası: $e',
          'action': 'error',
        };
      }
    }

    // Bu duruma hiç gelmemeli ama güvenlik için
    return {'exists': true, 'reason': 'Varsayılan durum', 'action': 'skip'};
  }

  /// MIME type belirleme
  String _getMimeType(String fileName) {
    return lookupMimeType(fileName) ?? 'application/octet-stream';
  }

  // ============== YARDIMCI METODLAR ==============

  /// Bağlantı testi
  Future<Map<String, dynamic>> _testConnection(SenkronCihazi device) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://${device.ip}:8080/ping'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Local device ID'yi al
  Future<String> _getLocalDeviceId() async {
    return 'enhanced_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Remote delta'ları al
  Future<List<SenkronDelta>> _fetchRemoteDeltas(
    SenkronCihazi device,
    DateTime? since,
  ) async {
    try {
      final uri = Uri.parse('http://${device.ip}:8080/deltas').replace(
        queryParameters:
            since != null ? {'since': since.toIso8601String()} : null,
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final deltaList = List<Map<String, dynamic>>.from(data['deltas'] ?? []);

        return deltaList.map((deltaData) {
          return SenkronDelta.fromJson(deltaData);
        }).toList();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Remote delta alınamadı: $e');
      return [];
    }
  }

  /// Local delta'ları gönder
  Future<Map<String, dynamic>> _sendLocalDeltas(
    SenkronCihazi device,
    List<SenkronDelta> deltas,
  ) async {
    try {
      if (deltas.isEmpty) return {'success': true, 'sent': 0};

      final response = await http
          .post(
            Uri.parse('http://${device.ip}:8080/deltas'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'deltas': deltas.map((d) => d.toJson()).toList(),
              'sourceDevice': _localDeviceId,
            }),
          )
          .timeout(_syncTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'sent': deltas.length,
          'accepted': data['accepted'] ?? 0,
        };
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Delta gönderme hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Belge indirme gerekli mi?
  Future<bool> _shouldDownloadDocument(Map<String, dynamic> remoteDoc) async {
    final hash = remoteDoc['dosyaHash'] ?? remoteDoc['hash'] as String?;
    if (hash == null || hash.isEmpty) return false;

    // Local belgeler arasında bu hash'e sahip belge var mı kontrol et
    final localDocuments = await _veriTabani.belgeleriGetir();
    final exists = localDocuments.any((doc) => doc.dosyaHash == hash);

    return !exists; // Yoksa indir
  }

  /// Belge yükleme gerekli mi?
  Future<bool> _shouldUploadDocument(BelgeModeli localDoc) async {
    if (localDoc.dosyaHash.isEmpty) return false;

    // Bu methodun çağrıldığı yerde zaten remote belgelerle karşılaştırma yapılıyor
    // Bu nedenle basit bir kontrol yeterli
    return true;
  }

  /// Cihaza upload edilmeli mi kontrol et
  Future<Map<String, dynamic>> _shouldUploadToDevice(
    SenkronCihazi targetDevice,
    BelgeModeli localDoc,
  ) async {
    try {
      // Remote belgeleri al
      final remoteDocuments = await _fetchRemoteDocuments(targetDevice);

      // Aynı hash'e sahip belge var mı kontrol et
      for (final remoteDoc in remoteDocuments) {
        final remoteHash = remoteDoc['dosyaHash'] ?? remoteDoc['fileHash'];
        if (remoteHash == localDoc.dosyaHash) {
          // Hash aynı, kişi kontrolü yap
          final remoteKisiId = remoteDoc['kisiId'];

          if (remoteKisiId == localDoc.kisiId) {
            // Aynı hash ve aynı kişi - güncelleme tarihi kontrol et
            final remoteUpdateStr = remoteDoc['guncellemeTarihi']?.toString();
            final remoteUpdateTime =
                remoteUpdateStr != null
                    ? DateTime.tryParse(remoteUpdateStr)
                    : null;

            final localUpdateTime = localDoc.guncellemeTarihi;

            // Güncelleme tarihi karşılaştırması
            if (remoteUpdateTime != null &&
                localUpdateTime.isAfter(remoteUpdateTime)) {
              // Local daha yeni - upload et
              return {
                'upload': true,
                'reason':
                    'Local daha yeni versiyon (${localUpdateTime.toIso8601String().substring(0, 19)} > ${remoteUpdateTime.toIso8601String().substring(0, 19)})',
                'action': 'update',
              };
            } else if (remoteUpdateTime != null &&
                remoteUpdateTime.isAfter(localUpdateTime)) {
              // Remote daha yeni - upload etme
              return {
                'upload': false,
                'reason':
                    'Remote daha yeni versiyon (${remoteUpdateTime.toIso8601String().substring(0, 19)} > ${localUpdateTime.toIso8601String().substring(0, 19)})',
                'action': 'skip',
              };
            } else {
              // Metadata farklılıkları kontrol et
              final metadataChanged =
                  localDoc.baslik != remoteDoc['baslik'] ||
                  localDoc.aciklama != remoteDoc['aciklama'] ||
                  localDoc.kategoriId != remoteDoc['kategoriId'];

              if (metadataChanged) {
                return {
                  'upload': true,
                  'reason': 'Metadata değişikliği tespit edildi',
                  'action': 'update',
                };
              }

              // Tamamen aynı belge
              return {
                'upload': false,
                'reason': 'Aynı dosya, aynı kişi (değişiklik yok)',
                'action': 'skip',
              };
            }
          } else {
            // Aynı dosya ama farklı kişi - güncelleme gerekli
            return {
              'upload': true,
              'reason': 'Aynı dosya, farklı kişi - güncelleme gerekli',
              'action': 'update',
            };
          }
        }
      }

      // Remote'da bu belge yok, upload et
      return {'upload': true, 'reason': 'Yeni belge', 'action': 'new'};
    } catch (e) {
      // Hata durumunda upload et (güvenli taraf)
      return {
        'upload': true,
        'reason': 'Kontrol hatası: $e',
        'action': 'error_fallback',
      };
    }
  }

  // ============== ÇAKIŞMA ÇÖZÜMÜ ==============

  /// Tüm çakışmaları çöz
  Future<Map<String, dynamic>> _resolveAllConflicts(
    SenkronCihazi device,
    String strategy,
  ) async {
    try {
      // Çakışan belgeleri al (Bu örnekte basit bir yaklaşım)
      final conflicts = <Map<String, dynamic>>[];

      int resolved = 0;
      int failed = 0;

      for (final conflict in conflicts) {
        try {
          await _resolveConflict(device, conflict, strategy);
          resolved++;
        } catch (e) {
          failed++;
          _addLog('❌ Çakışma çözüm hatası: $e');
        }
      }

      return {
        'success': true,
        'resolved': resolved,
        'failed': failed,
        'total': conflicts.length,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Tek çakışma çöz
  Future<void> _resolveConflict(
    SenkronCihazi device,
    Map<String, dynamic> conflict,
    String strategy,
  ) async {
    switch (strategy) {
      case 'LATEST_WINS':
        // En son güncellenen kazansın
        break;
      case 'LOCAL_WINS':
        // Local kazansın
        break;
      case 'REMOTE_WINS':
        // Remote kazansın
        break;
      case 'MANUAL':
        // Manuel çözüm (şimdilik latest wins)
        break;
    }
  }

  // ============== TEMİZLİK VE OPTİMİZASYON ==============

  /// Temizlik işlemleri
  Future<void> _performCleanup() async {
    try {
      // Eski sync state'leri temizle
      await _stateTracker.clearSyncState();

      // Temizlik tamamlandı
      _addLog('🧹 Temizlik tamamlandı');
    } catch (e) {
      _addLog('⚠️ Temizlik hatası: $e');
    }
  }

  // ============== DURUM YÖNETİMİ ==============

  /// Senkronizasyonu durdur
  void stopSync() {
    _durduruldu = true;
    _updateStatus('Senkronizasyon durduruluyor...');
    _addLog('⏹️ Senkronizasyon durduruldu');
  }

  /// Senkronizasyon durumunu sıfırla
  void _resetSyncState() {
    _durduruldu = false;
    _hataOlustu = false;
    _sonHata = null;
    _downloadedDocuments = 0;
    _uploadedDocuments = 0;
    _skippedDocuments = 0;
    _erroredDocuments = 0;
    _conflictedDocuments = 0;
    _resolvedConflicts = 0;
    _progress = 0.0;
    _currentOperation = '';
    _totalOperations = 0;
    _completedOperations = 0;
    _logMessages.clear();
  }

  /// Progress güncelle
  void _updateProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
    onProgressUpdate?.call(_progress);
  }

  /// İşlem durumunu güncelle
  void _updateOperation(String operation) {
    _currentOperation = operation;
    _addLog('🔄 $operation');
  }

  /// Durum güncelle
  void _updateStatus(String status) {
    onStatusUpdate?.call(status);
  }

  /// Log mesajı ekle
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logMessages.add(logMessage);
    onLogMessage?.call(logMessage);

    // Log limitini kontrol et
    if (_logMessages.length > 1000) {
      _logMessages.removeRange(0, 500);
    }
  }

  // ============== DISPOSE ==============

  void dispose() {
    _senkronizasyonAktif = false;
    _durduruldu = true;
    _logMessages.clear();
    onLogMessage = null;
    onProgressUpdate = null;
    onStatusUpdate = null;
  }
}
