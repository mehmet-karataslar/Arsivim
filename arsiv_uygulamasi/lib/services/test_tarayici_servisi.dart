import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Test amaçlı tarayıcı servisi
/// Fiziksel tarayıcı olmadan test yapabilmek için
class TestTarayiciServisi {
  /// Test tarayıcıları listesi
  Future<List<String>> tarayicilariAra() async {
    // Simüle edilen tarayıcılar
    await Future.delayed(const Duration(seconds: 1)); // Arama simülasyonu

    return [
      'Test Canon PIXMA Scanner',
      'Test HP LaserJet Scanner',
      'Test Epson L3150 Scanner',
      'Test Brother MFC Scanner',
      'Test Samsung SCX Scanner',
    ];
  }

  /// Test belge tarama - gerçek PDF dosyası oluşturur
  Future<String?> belgeTara(String tarayiciAdi) async {
    try {
      // Tarama simülasyonu
      await Future.delayed(const Duration(seconds: 3));

      // Temp dizinine gerçek PDF dosyası oluştur
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'test_scanned_document_$timestamp.pdf';
      final filePath = path.join(tempDir.path, fileName);

      // Gerçek PDF içeriği oluştur
      final pdfContent = await _createTestPDF(tarayiciAdi);
      final file = File(filePath);
      await file.writeAsBytes(pdfContent);

      return filePath;
    } catch (e) {
      print('Test tarama hatası: $e');
      return null;
    }
  }

  /// Gerçek PDF dosyası oluştur
  Future<Uint8List> _createTestPDF(String tarayiciAdi) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';

    // Basit ama geçerli PDF formatı
    final pdfHeader = '%PDF-1.4\n';
    final catalog = '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
    final pages =
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';

    final pageContent = '''3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 200 >>
stream
BT
/F1 24 Tf
50 750 Td
(TEST TARANAN BELGE) Tj
0 -50 Td
/F1 12 Tf
(Tarayici: $tarayiciAdi) Tj
0 -20 Td
(Tarih: $dateStr) Tj
0 -30 Td
(Bu bir test belgesidir.) Tj
0 -20 Td
(Tarayici sistemi calisıyor!) Tj
ET
endstream
endobj
''';

    final xref = '''xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000300 00000 n 
0000000380 00000 n 
''';

    final trailer = '''trailer
<< /Size 6 /Root 1 0 R >>
startxref
650
%%EOF
''';

    final fullPdf = pdfHeader + catalog + pages + pageContent + xref + trailer;
    return Uint8List.fromList(fullPdf.codeUnits);
  }

  /// Test tarayıcı ayarları
  Future<Map<String, dynamic>> tarayiciAyarlariGetir(String tarayiciAdi) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'resolution': [150, 300, 600, 1200],
      'colorModes': ['color', 'grayscale', 'blackwhite'],
      'paperSizes': ['A4', 'A3', 'Letter', 'Legal'],
      'outputFormats': ['pdf', 'jpeg', 'png'],
      'maxPages': 50,
      'duplex': true,
      'autoFeeder': true,
    };
  }

  /// Test tarayıcı durum kontrolü
  Future<bool> tarayiciDurumuKontrol(String tarayiciAdi) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true; // Test tarayıcıları her zaman hazır
  }

  /// Test bağlantı kontrolü
  Future<bool> tarayiciBaglantiTest(String tarayiciAdi) async {
    await Future.delayed(const Duration(seconds: 1));
    return true; // Test tarayıcıları her zaman bağlı
  }

  /// Gelişmiş test tarama
  Future<String?> gelismisImageTara({
    required String tarayiciAdi,
    int resolution = 300,
    String colorMode = 'color',
    String paperSize = 'A4',
    String outputFormat = 'pdf',
    bool duplex = false,
    int quality = 80,
  }) async {
    try {
      // Daha uzun simülasyon (ayarlara göre)
      final duration = resolution > 600 ? 5 : 3;
      await Future.delayed(Duration(seconds: duration));

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'test_advanced_scan_$timestamp.$outputFormat';
      final filePath = path.join(tempDir.path, fileName);

      if (outputFormat == 'pdf') {
        final pdfContent = await _createAdvancedTestPDF(
          tarayiciAdi,
          resolution,
          colorMode,
          paperSize,
          duplex,
        );
        await File(filePath).writeAsBytes(pdfContent);
      } else {
        // Diğer formatlar için basit içerik
        await File(filePath).writeAsString('Test $outputFormat file');
      }

      return filePath;
    } catch (e) {
      print('Gelişmiş test tarama hatası: $e');
      return null;
    }
  }

  /// Gelişmiş test PDF oluştur
  Future<Uint8List> _createAdvancedTestPDF(
    String tarayiciAdi,
    int resolution,
    String colorMode,
    String paperSize,
    bool duplex,
  ) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';

    final pdfHeader = '%PDF-1.4\n';
    final catalog = '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
    final pages =
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';

    final pageContent = '''3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 350 >>
stream
BT
/F1 20 Tf
50 750 Td
(GELİŞMİŞ TEST TARAMA) Tj
0 -40 Td
/F1 12 Tf
(Tarayici: $tarayiciAdi) Tj
0 -20 Td
(Tarih: $dateStr) Tj
0 -25 Td
(Çözünürlük: ${resolution} DPI) Tj
0 -20 Td
(Renk Modu: $colorMode) Tj
0 -20 Td
(Kağıt Boyutu: $paperSize) Tj
0 -20 Td
(Çift Taraflı: ${duplex ? 'Evet' : 'Hayır'}) Tj
0 -30 Td
(Bu gelişmiş test belgesidir.) Tj
0 -20 Td
(Tüm ayarlar test edildi!) Tj
ET
endstream
endobj
''';

    final xref = '''xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000350 00000 n 
0000000430 00000 n 
''';

    final trailer = '''trailer
<< /Size 6 /Root 1 0 R >>
startxref
800
%%EOF
''';

    final fullPdf = pdfHeader + catalog + pages + pageContent + xref + trailer;
    return Uint8List.fromList(fullPdf.codeUnits);
  }

  /// Test tarayıcı bilgileri
  Future<Map<String, dynamic>> tarayiciBilgileriGetir(
    String tarayiciAdi,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'name': tarayiciAdi,
      'manufacturer':
          tarayiciAdi.contains('Canon')
              ? 'Canon'
              : tarayiciAdi.contains('HP')
              ? 'HP'
              : tarayiciAdi.contains('Epson')
              ? 'Epson'
              : tarayiciAdi.contains('Brother')
              ? 'Brother'
              : 'Samsung',
      'model': tarayiciAdi.split(' ').last,
      'status': 'Hazır',
      'connection': 'USB',
      'driver': 'Test Driver v1.0',
      'capabilities': [
        'Renkli Tarama',
        'Çift Taraflı',
        'Otomatik Besleme',
        'OCR Desteği',
      ],
    };
  }
}
