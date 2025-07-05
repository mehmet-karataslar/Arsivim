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

/// Çalışan Senkronizasyon Manager - Hatasız Versiyon
class SenkronManagerWorking {
  static final SenkronManagerWorking _instance =
      SenkronManagerWorking._internal();
  static SenkronManagerWorking get instance => _instance;
  SenkronManagerWorking._internal();

  // ============== Progress Tracking ==============
  Function(double progress)? onProgressUpdate;
  Function(String operation)? onOperationUpdate;
  Function(String message)? onLogMessage;

  // ============== Statistics ==============
  int _uploadedDocuments = 0;
  int _downloadedDocuments = 0;
  int _erroredDocuments = 0;

  /// Ana senkronizasyon işlemi
  Future<Map<String, int>> performSynchronization(
    SenkronCihazi bagliBulunanCihaz,
  ) async {
    _resetStatistics();

    try {
      _addLog('🚀 Güvenilir senkronizasyon başlatılıyor...');
      _addLog('🔗 Cihaz: ${bagliBulunanCihaz.ad} (${bagliBulunanCihaz.ip})');

      // ============== PHASE 1: METADATA SYNC ==============
      _updateProgress(0.20, 'Metadata senkronizasyonu...');
      await _syncMetadata(bagliBulunanCihaz);

      // ============== PHASE 2: DOCUMENT SYNC ==============
      _updateProgress(0.70, 'Belge senkronizasyonu...');
      await _syncDocuments(bagliBulunanCihaz);

      _updateProgress(1.0, 'Senkronizasyon tamamlandı');
      _addLog('✅ Senkronizasyon başarıyla tamamlandı!');
      _logStatistics();

      return {
        'yeni': _downloadedDocuments,
        'guncellenen': 0,
        'gonderilen': _uploadedDocuments,
        'hata': _erroredDocuments,
      };
    } catch (e) {
      _addLog('❌ Senkronizasyon hatası: $e');
      rethrow;
    }
  }

  /// Metadata senkronizasyonu
  Future<void> _syncMetadata(SenkronCihazi cihaz) async {
    _addLog('📋 Kategoriler ve kişiler senkronize ediliyor...');

    try {
      // Kategoriler
      final remoteCategories = await _fetchRemoteCategories(cihaz.ip);
      await _syncCategories(remoteCategories);

      // Kişiler
      final remotePeople = await _fetchRemotePeople(cihaz.ip);
      await _syncPeople(remotePeople);
    } catch (e) {
      _addLog('⚠️ Metadata sync hatası: $e');
    }
  }

  /// Belge senkronizasyonu
  Future<void> _syncDocuments(SenkronCihazi cihaz) async {
    _addLog('📁 Belgeler senkronize ediliyor...');

    try {
      final veriTabani = VeriTabaniServisi();

      // Remote belgeleri al
      final remoteDocuments = await _fetchRemoteDocuments(cihaz.ip);
      final localDocuments = await veriTabani.belgeleriGetir();

      _addLog(
        '📊 Remote: ${remoteDocuments.length}, Local: ${localDocuments.length}',
      );

      // Yeni belgeleri indir
      for (final remoteDoc in remoteDocuments) {
        final remoteHash = remoteDoc['hash'] ?? '';
        if (remoteHash.isEmpty) continue;

        final exists = localDocuments.any(
          (local) => local.dosyaHash == remoteHash,
        );

        if (!exists) {
          try {
            await _downloadDocument(cihaz, remoteDoc);
            _downloadedDocuments++;
          } catch (e) {
            _addLog('❌ İndirme hatası: ${remoteDoc['fileName']} - $e');
            _erroredDocuments++;
          }
        }
      }

      // Yeni belgeleri yükle
      for (final localDoc in localDocuments) {
        if (localDoc.dosyaHash.isEmpty) continue;

        final exists = remoteDocuments.any(
          (remote) => remote['hash'] == localDoc.dosyaHash,
        );

        if (!exists) {
          try {
            await _uploadDocument(cihaz, localDoc);
            _uploadedDocuments++;
          } catch (e) {
            _addLog('❌ Yükleme hatası: ${localDoc.dosyaAdi} - $e');
            _erroredDocuments++;
          }
        }
      }
    } catch (e) {
      _addLog('❌ Belge sync hatası: $e');
    }
  }

  /// Remote verileri fetch et
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

  /// Kategorileri senkronize et
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
          olusturmaTarihi: DateTime.now(),
        );

        await veriTabani.kategoriEkle(newCategory);
        _addLog('📋 Yeni kategori: $categoryName');
      }
    }
  }

  /// Kişileri senkronize et
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

    // Hash kontrolü
    final downloadedHash = sha256.convert(response.bodyBytes).toString();
    final expectedHash = docData['dosyaHash'] ?? docData['hash'];

    if (expectedHash != null && downloadedHash != expectedHash) {
      throw Exception('Hash uyumsuzlığı');
    }

    // Dosyayı kaydet
    final dosyaServisi = DosyaServisi();
    final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
    final filePath = '$belgelerKlasoru/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    // Veritabanına kaydet
    final veriTabani = VeriTabaniServisi();
    final belge = BelgeModeli(
      dosyaAdi: fileName,
      orijinalDosyaAdi: fileName,
      dosyaYolu: filePath,
      dosyaBoyutu: response.bodyBytes.length,
      dosyaTipi: docData['dosyaTipi'] ?? docData['fileType'] ?? 'unknown',
      dosyaHash: downloadedHash,
      olusturmaTarihi: DateTime.now(),
      guncellemeTarihi: DateTime.now(),
      kategoriId: docData['kategoriId'] ?? docData['categoryId'] ?? 1,
      baslik: docData['baslik'] ?? docData['title'],
      aciklama: docData['aciklama'] ?? docData['description'],
    );

    await veriTabani.belgeEkle(belge);
    _addLog('📥 İndirildi: $fileName');
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

    _addLog('📤 Yüklendi: ${belge.dosyaAdi}');
  }

  /// Utility methods
  void _resetStatistics() {
    _uploadedDocuments = 0;
    _downloadedDocuments = 0;
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
    _addLog('   • Hatalı: $_erroredDocuments');
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
