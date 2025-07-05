import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/senkron_cihazi.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'metadata_sync_manager.dart';

/// SADELEŞTİRİLMİŞ Gelişmiş Senkronizasyon Yöneticisi
/// Sadece çalışan ve gereken özellikler - Karmaşık kodlar temizlendi
class SenkronManagerEnhanced {
  final VeriTabaniServisi _veriTabani;
  final DosyaServisi _dosyaServisi;
  final MetadataSyncManager _metadataManager;

  // Senkronizasyon durumu
  bool _senkronizasyonAktif = false;
  bool _durduruldu = false;
  String? _sonHata;

  // İstatistikler
  int _downloadedDocuments = 0;
  int _uploadedDocuments = 0;
  int _skippedDocuments = 0;
  int _erroredDocuments = 0;

  // Progress tracking
  double _progress = 0.0;
  String _currentOperation = '';

  // Callback'ler
  Function(String)? onLogMessage;
  Function(double)? onProgressUpdate;
  Function(String)? onStatusUpdate;

  // Timeout ayarları
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
    this._metadataManager,
  );

  // ============== GETTER'LAR ==============
  bool get senkronizasyonAktif => _senkronizasyonAktif;
  bool get durduruldu => _durduruldu;
  String? get sonHata => _sonHata;
  double get progress => _progress;
  String get currentOperation => _currentOperation;
  List<String> get logMessages => List.from(_logMessages);

  Map<String, dynamic> get statistics => {
    'downloaded': _downloadedDocuments,
    'uploaded': _uploadedDocuments,
    'skipped': _skippedDocuments,
    'errors': _erroredDocuments,
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

  // ============== ANA SENKRONIZASYON METODLARı ==============

  /// Tam senkronizasyon - Sadeleştirilmiş versiyon
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
      _addLog('   • Metadata sync: ${syncMetadata ? "Evet" : "Hayır"}');

      // Local device ID'yi al
      _localDeviceId = await _getLocalDeviceId();

      final results = <String, dynamic>{};

      // 1. Bağlantı testi
      _updateOperation('Bağlantı test ediliyor...');
      final connectionTest = await _testConnection(targetDevice);
      if (!connectionTest['success']) {
        throw Exception('Bağlantı hatası: ${connectionTest['error']}');
      }
      _addLog('✅ Bağlantı başarılı');

      // 2. Metadata senkronizasyonu
      if (syncMetadata) {
        _updateOperation('Metadata senkronizasyonu...');
        _addLog('📋 Metadata sync aktif - kategori ve kişi senkronizasyonu');
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
      }

      // 3. DOSYA TRANSFERİ - FULL DOCUMENT SYNC
      _updateOperation('📄 Kapsamlı dosya transferi başlatılıyor...');
      _addLog('🚀 FULL DOCUMENT SYNC AKTİF!');
      _addLog('   • Upload/Download: Açık');
      _addLog('   • Bidirectional: ${bidirectional ? "Açık" : "Kapalı"}');

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

      // Senkronizasyon tamamlandı
      _updateOperation('Senkronizasyon tamamlandı');
      _updateProgress(1.0);

      return {
        'success': true,
        'totalDocuments': fullResult['total'] ?? 0,
        'uploaded': fullResult['uploaded'] ?? 0,
        'downloaded': fullResult['downloaded'] ?? 0,
        'skipped': fullResult['skipped'] ?? 0,
        'errors': fullResult['errors'] ?? 0,
        'metadata': results['metadata'],
        'documents': results['documents'],
      };
    } catch (e) {
      _sonHata = e.toString();
      _addLog('❌ Senkronizasyon hatası: $e');
      rethrow;
    } finally {
      _senkronizasyonAktif = false;
    }
  }

  /// Senkronizasyon durdu
  void stopSynchronization() {
    _durduruldu = true;
    _addLog('🛑 Senkronizasyon durduruldu');
  }

  // ============== YARDIMCI METODLAR ==============

  void _resetSyncState() {
    _durduruldu = false;
    _sonHata = null;
    _progress = 0.0;
    _currentOperation = '';
    _downloadedDocuments = 0;
    _uploadedDocuments = 0;
    _skippedDocuments = 0;
    _erroredDocuments = 0;
    _logMessages.clear();
  }

  void _updateProgress(double progress) {
    _progress = progress;
    onProgressUpdate?.call(progress);
  }

  void _updateOperation(String operation) {
    _currentOperation = operation;
    onStatusUpdate?.call(operation);
  }

  void _updateStatus(String status) {
    onStatusUpdate?.call(status);
  }

  void _addLog(String message) {
    _logMessages.add(message);
    onLogMessage?.call(message);
    print(message);
  }

  /// Local device ID'yi al
  Future<String> _getLocalDeviceId() async {
    try {
      // Platform bilgisi ile unique ID oluştur
      final platform = Platform.operatingSystem;
      final hostname = Platform.localHostname;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'enhanced_device_$timestamp';
    } catch (e) {
      return 'enhanced_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Bağlantı testi
  Future<Map<String, dynamic>> _testConnection(SenkronCihazi device) async {
    try {
      final response = await http
          .get(Uri.parse('http://${device.ip}:8080/ping'))
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

  /// Metadata senkronizasyonu
  Future<Map<String, dynamic>> _performMetadataSync(
    SenkronCihazi targetDevice,
  ) async {
    try {
      // MetadataSyncManager ile senkronizasyon
      final result = await _metadataManager.syncMetadata(
        targetDevice,
        _localDeviceId!,
      );

      final success = (result['errors'] ?? 0) == 0;

      if (success) {
        _addLog('✅ Metadata senkronizasyonu tamamlandı');
        _addLog('   • Gönderilen metadata: ${result['sent'] ?? 0}');
        _addLog('   • Alınan metadata: ${result['received'] ?? 0}');
      }

      return {
        'success': success,
        'sent': result['sent'] ?? 0,
        'received': result['received'] ?? 0,
        'error': success ? null : 'Metadata sync hatası',
      };
    } catch (e) {
      _addLog('❌ Metadata sync hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Full document sync - Ana dosya transfer metodu
  Future<Map<String, dynamic>> _performFullDocumentSync(
    SenkronCihazi targetDevice,
  ) async {
    int uploadedCount = 0;
    int downloadedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    try {
      _addLog('📄 Full document sync başlatılıyor...');

      // 1. Local belgeleri al
      final localDocuments = await _veriTabani.belgeleriGetir();
      _addLog('📱 Local belgeler: ${localDocuments.length} adet');

      // 2. Remote belgeleri al
      final remoteDocuments = await _fetchRemoteDocuments(targetDevice);
      _addLog('🌐 Remote belgeler: ${remoteDocuments.length} adet');

      final totalOperations = localDocuments.length + remoteDocuments.length;
      int completedOperations = 0;

      // 3. Local belgeleri upload et
      _addLog('📤 Local belgeler upload ediliyor...');
      for (final doc in localDocuments) {
        if (_durduruldu) break;

        try {
          final shouldUpload = await _shouldUploadDocument(
            doc,
            remoteDocuments,
          );
          if (shouldUpload) {
            await _uploadDocument(doc, targetDevice);
            uploadedCount++;
            _addLog('✅ Upload: ${doc.dosyaAdi}');
          } else {
            skippedCount++;
            _addLog('⏭️ Skip: ${doc.dosyaAdi} (zaten mevcut)');
          }
        } catch (e) {
          errorCount++;
          _addLog('❌ Upload error: ${doc.dosyaAdi} - $e');
        }

        completedOperations++;
        _updateProgress(completedOperations / totalOperations);
      }

      // 4. Remote belgeleri download et
      _addLog('📥 Remote belgeler download ediliyor...');
      for (final remoteDoc in remoteDocuments) {
        if (_durduruldu) break;

        try {
          final shouldDownload = await _shouldDownloadDocument(
            remoteDoc,
            localDocuments,
          );
          if (shouldDownload) {
            await _downloadDocument(remoteDoc, targetDevice);
            downloadedCount++;
            _addLog('✅ Download: ${remoteDoc['dosyaAdi']}');
          } else {
            skippedCount++;
            _addLog('⏭️ Skip: ${remoteDoc['dosyaAdi']} (zaten mevcut)');
          }
        } catch (e) {
          errorCount++;
          _addLog('❌ Download error: ${remoteDoc['dosyaAdi']} - $e');
        }

        completedOperations++;
        _updateProgress(completedOperations / totalOperations);
      }

      return {
        'success': true,
        'uploaded': uploadedCount,
        'downloaded': downloadedCount,
        'skipped': skippedCount,
        'errors': errorCount,
        'total': uploadedCount + downloadedCount + skippedCount,
      };
    } catch (e) {
      _addLog('❌ Full document sync hatası: $e');
      return {
        'success': false,
        'uploaded': uploadedCount,
        'downloaded': downloadedCount,
        'errors': errorCount + 1,
        'error': e.toString(),
      };
    }
  }

  /// Remote belgeleri al
  Future<List<Map<String, dynamic>>> _fetchRemoteDocuments(
    SenkronCihazi device,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://${device.ip}:8080/documents'),
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

  /// Belgenin upload edilip edilmeyeceğini kontrol et
  Future<bool> _shouldUploadDocument(
    BelgeModeli doc,
    List<Map<String, dynamic>> remoteDocuments,
  ) async {
    // Dosya hash'ini hesapla
    final fileHash = await _calculateFileHash(doc.dosyaYolu);
    if (fileHash.isEmpty) return false;

    // Remote'ta aynı hash'e sahip belge var mı kontrol et
    final existsRemote = remoteDocuments.any((remote) {
      final remoteHash = remote['dosyaHash']?.toString() ?? '';
      final remotePersonId = remote['kisiId']?.toString() ?? '';
      final localPersonId = doc.kisiId?.toString() ?? '';

      // Aynı hash + aynı kişi = duplicate
      return remoteHash == fileHash && remotePersonId == localPersonId;
    });

    if (existsRemote) {
      _addLog('   • Duplicate tespit edildi: ${doc.dosyaAdi}');
      return false;
    }

    return true;
  }

  /// Belgenin download edilip edilmeyeceğini kontrol et
  Future<bool> _shouldDownloadDocument(
    Map<String, dynamic> remoteDoc,
    List<BelgeModeli> localDocuments,
  ) async {
    final remoteHash = remoteDoc['dosyaHash']?.toString() ?? '';
    final remotePersonId = remoteDoc['kisiId']?.toString() ?? '';

    if (remoteHash.isEmpty) return false;

    // Local'de aynı hash'e sahip belge var mı kontrol et
    final existsLocal = localDocuments.any((local) {
      final localPersonId = local.kisiId?.toString() ?? '';
      // Aynı hash + aynı kişi = duplicate
      return local.dosyaHash == remoteHash && localPersonId == remotePersonId;
    });

    if (existsLocal) {
      _addLog('   • Duplicate tespit edildi: ${remoteDoc['dosyaAdi']}');
      return false;
    }

    return true;
  }

  /// Dosya hash'ini hesapla
  Future<String> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      _addLog('❌ Hash hesaplama hatası: $e');
      return '';
    }
  }

  /// Belge upload et
  Future<void> _uploadDocument(BelgeModeli doc, SenkronCihazi device) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://${device.ip}:8080/upload'),
    );

    try {
      // Dosya hash'ini hesapla
      final realFileHash = await _calculateFileHash(doc.dosyaYolu);
      if (realFileHash.isEmpty) {
        throw Exception('Dosya hash\'i hesaplanamadı');
      }

      // Database hash'ini güncelle
      if (doc.dosyaHash != realFileHash) {
        final updatedDoc = BelgeModeli(
          id: doc.id,
          dosyaAdi: doc.dosyaAdi,
          orijinalDosyaAdi: doc.orijinalDosyaAdi,
          dosyaYolu: doc.dosyaYolu,
          dosyaBoyutu: doc.dosyaBoyutu,
          dosyaTipi: doc.dosyaTipi,
          dosyaHash: realFileHash,
          kategoriId: doc.kategoriId,
          kisiId: doc.kisiId,
          baslik: doc.baslik,
          aciklama: doc.aciklama,
          etiketler: doc.etiketler,
          olusturmaTarihi: doc.olusturmaTarihi,
          guncellemeTarihi: DateTime.now(),
          aktif: doc.aktif,
          senkronDurumu: doc.senkronDurumu,
        );
        await _veriTabani.belgeGuncelle(updatedDoc);
        doc = updatedDoc;
      }

      // Kişi bilgilerini al
      final kisi = await _veriTabani.kisiGetir(doc.kisiId!);
      final kisiAd = kisi?.ad ?? 'Bilinmeyen';
      final kisiSoyad = kisi?.soyad ?? '';

      // Metadata hazırla
      final metadata = {
        'id': doc.id,
        'dosyaAdi': doc.dosyaAdi,
        'orijinalDosyaAdi': doc.orijinalDosyaAdi,
        'dosyaBoyutu': doc.dosyaBoyutu,
        'dosyaTipi': doc.dosyaTipi,
        'dosyaHash': realFileHash,
        'kategoriId': doc.kategoriId,
        'kisiId': doc.kisiId,
        'kisiAd': kisiAd,
        'kisiSoyad': kisiSoyad,
        'baslik': doc.baslik,
        'aciklama': doc.aciklama,
        'etiketler': doc.etiketler,
        'olusturmaTarihi': doc.olusturmaTarihi.toIso8601String(),
        'guncellemeTarihi': doc.guncellemeTarihi.toIso8601String(),
        'belgeKimlik': '${realFileHash}_${doc.kisiId}',
      };

      // Metadata ekle
      request.fields['belge_data'] = json.encode(metadata);

      // Dosyayı ekle
      final file = await http.MultipartFile.fromPath(
        'file',
        doc.dosyaYolu,
        filename: doc.dosyaAdi,
      );
      request.files.add(file);

      // İsteği gönder
      final response = await request.send().timeout(_syncTimeout);
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Upload hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload hatası: $e');
    }
  }

  /// Belge download et
  Future<void> _downloadDocument(
    Map<String, dynamic> remoteDoc,
    SenkronCihazi device,
  ) async {
    try {
      final fileName = remoteDoc['dosyaAdi']?.toString() ?? '';
      final hash = remoteDoc['dosyaHash']?.toString() ?? '';

      if (fileName.isEmpty || hash.isEmpty) {
        throw Exception('Eksik dosya bilgisi');
      }

      // Hash tabanlı download
      final response = await http
          .get(Uri.parse('http://${device.ip}:8080/download/$hash'))
          .timeout(_syncTimeout);

      if (response.statusCode != 200) {
        throw Exception('Download hatası: ${response.statusCode}');
      }

      // Dosyayı kaydet
      final documentsPath = await _dosyaServisi.belgelerKlasoruYolu();
      final filePath = path.join(documentsPath, fileName);
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Kişi bilgilerini eşleştir
      final kisiId = await _findOrCreatePerson(remoteDoc);

      // Veritabanına ekle
      final newDoc = BelgeModeli(
        dosyaAdi: fileName,
        orijinalDosyaAdi: remoteDoc['orijinalDosyaAdi']?.toString() ?? fileName,
        dosyaYolu: filePath,
        dosyaBoyutu: remoteDoc['dosyaBoyutu'] ?? response.bodyBytes.length,
        dosyaTipi: remoteDoc['dosyaTipi']?.toString() ?? 'unknown',
        dosyaHash: hash,
        kategoriId: remoteDoc['kategoriId'] ?? 1,
        kisiId: kisiId,
        baslik: remoteDoc['baslik']?.toString(),
        aciklama: remoteDoc['aciklama']?.toString(),
        etiketler: remoteDoc['etiketler'],
        olusturmaTarihi: DateTime.now(),
        guncellemeTarihi: DateTime.now(),
        aktif: true,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      await _veriTabani.belgeEkle(newDoc);
    } catch (e) {
      throw Exception('Download hatası: $e');
    }
  }

  /// Kişi bul veya oluştur
  Future<int> _findOrCreatePerson(Map<String, dynamic> remoteDoc) async {
    final kisiAd = remoteDoc['kisiAd']?.toString() ?? 'Bilinmeyen';
    final kisiSoyad = remoteDoc['kisiSoyad']?.toString() ?? '';

    // Mevcut kişileri kontrol et
    final mevcutKisiler = await _veriTabani.kisileriGetir();
    for (final kisi in mevcutKisiler) {
      if (kisi.ad == kisiAd && kisi.soyad == kisiSoyad) {
        return kisi.id!;
      }
    }

    // Yeni kişi oluştur
    final yeniKisi = KisiModeli(
      ad: kisiAd,
      soyad: kisiSoyad,
      olusturmaTarihi: DateTime.now(),
      guncellemeTarihi: DateTime.now(),
    );

    return await _veriTabani.kisiEkle(yeniKisi);
  }
}
