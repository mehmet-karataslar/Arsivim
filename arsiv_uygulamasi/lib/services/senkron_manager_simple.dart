import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/senkron_cihazi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../services/senkron_conflict_resolver.dart';
import '../services/senkron_state_manager.dart';
import '../services/senkron_validation_service.dart';
import '../services/senkron_integrity_checker.dart';

/// Basit ve Çalışan Senkronizasyon Manager
class SenkronManagerSimple {
  static final SenkronManagerSimple _instance =
      SenkronManagerSimple._internal();
  static SenkronManagerSimple get instance => _instance;
  SenkronManagerSimple._internal();

  // ============== Progress Tracking ==============
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  // ============== Core Services ==============
  final SenkronStateManager _stateManager = SenkronStateManager.instance;
  final SenkronValidationService _validationService =
      SenkronValidationService.instance;
  final SenkronIntegrityChecker _integrityChecker =
      SenkronIntegrityChecker.instance;
  final SenkronConflictResolver _conflictResolver =
      SenkronConflictResolver.instance;

  // ============== Statistics ==============
  int _uploadedDocuments = 0;
  int _downloadedDocuments = 0;
  int _conflictedDocuments = 0;
  int _erroredDocuments = 0;

  /// Ana senkronizasyon işlemi - Basit 3 Aşamalı Sistem
  Future<Map<String, int>> performSynchronization(
    SenkronCihazi bagliBulunanCihaz,
  ) async {
    _resetStatistics();

    try {
      _addLog('🚀 Basit senkronizasyon sistemi başlatılıyor...');
      _addLog('🔗 Cihaz: ${bagliBulunanCihaz.ad} (${bagliBulunanCihaz.ip})');

      // ============== PHASE 1: PRE-VALIDATION ==============
      _updateProgress(0.10, 'Ön kontroller yapılıyor...');
      await _performBasicValidation();

      // ============== PHASE 2: SYNC METADATA ==============
      _updateProgress(0.30, 'Metadata senkronizasyonu...');
      await _syncMetadata(bagliBulunanCihaz);

      // ============== PHASE 3: SYNC DOCUMENTS ==============
      _updateProgress(0.60, 'Belge senkronizasyonu...');
      await _syncDocuments(bagliBulunanCihaz);

      _updateProgress(1.0, 'Senkronizasyon tamamlandı');
      _addLog('✅ Senkronizasyon başarıyla tamamlandı!');
      _logStatistics();

      return {
        'yeni': _downloadedDocuments,
        'guncellenen': _downloadedDocuments,
        'gonderilen': _uploadedDocuments,
        'cakisma': _conflictedDocuments,
        'hata': _erroredDocuments,
      };
    } catch (e) {
      _addLog('❌ Senkronizasyon hatası: $e');
      rethrow;
    }
  }

  /// Basit validation
  Future<void> _performBasicValidation() async {
    _addLog('🔍 Temel kontroller...');

    final validation = await _validationService.validatePrerequisites();
    if (!validation.isValid) {
      throw Exception('Sistem gereksinimleri karşılanmıyor');
    }

    _addLog('✅ Temel kontroller başarılı');
  }

  /// Metadata senkronizasyonu
  Future<void> _syncMetadata(SenkronCihazi cihaz) async {
    _addLog('📋 Metadata senkronizasyonu...');

    try {
      // Kategoriler
      final remoteCategories = await _fetchRemoteCategories(cihaz.ip);
      await _syncCategories(remoteCategories);

      // Kişiler
      final remotePeople = await _fetchRemotePeople(cihaz.ip);
      await _syncPeople(remotePeople);

      _addLog('✅ Metadata senkronizasyonu tamamlandı');
    } catch (e) {
      _addLog('⚠️ Metadata sync hatası: $e');
    }
  }

  /// Belge senkronizasyonu
  Future<void> _syncDocuments(SenkronCihazi cihaz) async {
    _addLog('📁 Belge senkronizasyonu...');

    try {
      // Remote belgeleri al
      final remoteDocuments = await _fetchRemoteDocuments(cihaz.ip);
      final veriTabani = VeriTabaniServisi();
      final localDocuments = await veriTabani.belgeleriGetir();

      // Download yeni belgeler
      for (final remoteDoc in remoteDocuments) {
        final exists = localDocuments.any(
          (local) =>
              local.dosyaHash == remoteDoc['hash'] &&
              local.dosyaHash.isNotEmpty,
        );

        if (!exists) {
          try {
            await _downloadDocument(cihaz, remoteDoc);
            _downloadedDocuments++;
            _addLog('📥 İndirildi: ${remoteDoc['fileName']}');
          } catch (e) {
            _addLog('❌ İndirme hatası: ${remoteDoc['fileName']} - $e');
            _erroredDocuments++;
          }
        }
      }

      // Upload yeni belgeler
      for (final localDoc in localDocuments) {
        final exists = remoteDocuments.any(
          (remote) =>
              remote['hash'] == localDoc.dosyaHash &&
              localDoc.dosyaHash.isNotEmpty,
        );

        if (!exists) {
          try {
            await _uploadDocument(cihaz, localDoc);
            _uploadedDocuments++;
            _addLog('📤 Yüklendi: ${localDoc.dosyaAdi}');
          } catch (e) {
            _addLog('❌ Yükleme hatası: ${localDoc.dosyaAdi} - $e');
            _erroredDocuments++;
          }
        }
      }

      _addLog('✅ Belge senkronizasyonu tamamlandı');
    } catch (e) {
      _addLog('❌ Belge sync hatası: $e');
    }
  }

  /// Remote belgeler fetch
  Future<List<Map<String, dynamic>>> _fetchRemoteDocuments(
    String remoteIP,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$remoteIP:8080/documents'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 30));

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

  /// Remote kategoriler fetch
  Future<List<Map<String, dynamic>>> _fetchRemoteCategories(
    String remoteIP,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$remoteIP:8080/categories'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 15));

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

  /// Remote kişiler fetch
  Future<List<Map<String, dynamic>>> _fetchRemotePeople(String remoteIP) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$remoteIP:8080/people'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 15));

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

  /// Kategori senkronizasyonu
  Future<void> _syncCategories(
    List<Map<String, dynamic>> remoteCategories,
  ) async {
    final veriTabani = VeriTabaniServisi();
    final localCategories = await veriTabani.kategorileriGetir();

    for (final remoteCategory in remoteCategories) {
      // Türkçe field isimleri ile uyumlu hale getir
      final categoryName =
          remoteCategory['kategoriAdi'] ??
          remoteCategory['ad'] ??
          remoteCategory['name'];
      if (categoryName == null) continue;

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
          olusturmaTarihi: DateTime.now(),
        );

        await veriTabani.kategoriEkle(newCategory);
        _addLog('📋 Yeni kategori: $categoryName');
      }
    }
  }

  /// Kişi senkronizasyonu
  Future<void> _syncPeople(List<Map<String, dynamic>> remotePeople) async {
    final veriTabani = VeriTabaniServisi();
    final localPeople = await veriTabani.kisileriGetir();

    for (final remotePerson in remotePeople) {
      // Türkçe field isimleri ile uyumlu hale getir
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

        await veriTabani.kisiEkle(newPerson);
        _addLog('👤 Yeni kişi: $firstName $lastName');
      }
    }
  }

  /// Belge indirme
  Future<void> _downloadDocument(
    SenkronCihazi cihaz,
    Map<String, dynamic> docData,
  ) async {
    // Türkçe field isimleri ile uyumlu hale getir
    final fileName = docData['dosyaAdi'] ?? docData['fileName'];
    if (fileName == null) return;

    // Dosyayı indir
    final response = await http
        .get(Uri.parse('http://${cihaz.ip}:8080/download/$fileName'))
        .timeout(Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    // Dosyayı kaydet
    final dosyaServisi = DosyaServisi();
    final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
    final filePath = '$belgelerKlasoru/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    // Hash hesapla
    final fileHash = sha256.convert(response.bodyBytes).toString();

    // Veritabanına kaydet
    final veriTabani = VeriTabaniServisi();
    final belge = BelgeModeli(
      dosyaAdi: fileName,
      orijinalDosyaAdi: fileName,
      dosyaYolu: filePath,
      dosyaBoyutu: response.bodyBytes.length,
      dosyaTipi: docData['dosyaTipi'] ?? docData['fileType'] ?? 'unknown',
      dosyaHash: fileHash,
      olusturmaTarihi: DateTime.now(),
      guncellemeTarihi: DateTime.now(),
      kategoriId: docData['kategoriId'] ?? docData['categoryId'] ?? 1,
      baslik: docData['baslik'] ?? docData['title'],
      aciklama: docData['aciklama'] ?? docData['description'],
    );

    await veriTabani.belgeEkle(belge);
  }

  /// Belge yükleme
  Future<void> _uploadDocument(SenkronCihazi cihaz, BelgeModeli belge) async {
    final dosya = File(belge.dosyaYolu);
    if (!await dosya.exists()) {
      throw Exception('Dosya bulunamadı: ${belge.dosyaYolu}');
    }

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

    // Metadata
    request.fields.addAll({
      'title': belge.baslik ?? '',
      'description': belge.aciklama ?? '',
      'categoryId': belge.kategoriId.toString(),
      'hash': belge.dosyaHash,
    });

    final response = await request.send().timeout(Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// Utility methods
  void _resetStatistics() {
    _uploadedDocuments = 0;
    _downloadedDocuments = 0;
    _conflictedDocuments = 0;
    _erroredDocuments = 0;
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

  void _logStatistics() {
    _addLog('📊 Senkronizasyon İstatistikleri:');
    _addLog('   • Yüklenen: $_uploadedDocuments');
    _addLog('   • İndirilen: $_downloadedDocuments');
    _addLog('   • Çakışmalı: $_conflictedDocuments');
    _addLog('   • Hatalı: $_erroredDocuments');
  }

  /// Callback ayarlama
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
