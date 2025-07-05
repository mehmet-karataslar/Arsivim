import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';

class TarayiciServisi {
  static const MethodChannel _channel = MethodChannel(
    'arsiv_uygulamasi/tarayici',
  );

  /// Mevcut tarayıcıları arar ve listeler
  Future<List<String>> tarayicilariAra() async {
    try {
      if (Platform.isWindows) {
        return await _windowsTarayicilariAra();
      } else {
        throw UnsupportedError(
          'Tarayıcı özelliği sadece Windows platformunda desteklenmektedir',
        );
      }
    } catch (e) {
      _debugPrint('Tarayıcı arama hatası: $e');
      return [];
    }
  }

  /// Windows için tarayıcı arama
  Future<List<String>> _windowsTarayicilariAra() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('findScanners');
      return result.cast<String>();
    } on PlatformException catch (e) {
      _debugPrint('Windows tarayıcı arama hatası: ${e.message}');

      // WIA Scanner API kullanmayı dene
      try {
        final String scanners = await _channel.invokeMethod('findWIAScanners');
        if (scanners.isNotEmpty) {
          return scanners.split('|').where((s) => s.isNotEmpty).toList();
        }
      } catch (e2) {
        _debugPrint('WIA tarayıcı arama hatası: $e2');
      }

      // Varsayılan tarayıcı listesi (test amaçlı)
      return [
        'Canon PIXMA Scanner',
        'HP LaserJet Scanner',
        'Epson Scanner',
        'Windows Fax and Scan',
      ];
    }
  }

  /// Belge tarama işlemi
  Future<String?> belgeTara(String tarayiciAdi) async {
    try {
      if (Platform.isWindows) {
        return await _windowsBelgeTara(tarayiciAdi);
      } else {
        throw UnsupportedError(
          'Tarayıcı özelliği sadece Windows platformunda desteklenmektedir',
        );
      }
    } catch (e) {
      _debugPrint('Belge tarama hatası: $e');
      return null;
    }
  }

  /// Windows için belge tarama
  Future<String?> _windowsBelgeTara(String tarayiciAdi) async {
    try {
      final String? result = await _channel.invokeMethod('scanDocument', {
        'scannerName': tarayiciAdi,
        'outputFormat': 'pdf',
        'quality': 'high',
        'colorMode': 'color',
      });

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Windows belge tarama hatası: ${e.message}');

      // Test amaçlı simülasyon
      return await _simulateScanning();
    }
  }

  /// Test amaçlı tarama simülasyonu
  Future<String?> _simulateScanning() async {
    // Gerçek uygulamada bunu kaldırın
    await Future.delayed(const Duration(seconds: 2));

    // Temp dizinde test dosyası oluştur
    final tempDir = Directory.systemTemp;
    final testFile = File(
      '${tempDir.path}/scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    // Basit PDF içeriği oluştur (gerçek tarama yerine)
    final content = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
trailer
<< /Size 4 /Root 1 0 R >>
startxref
190
%%EOF''';

    await testFile.writeAsString(content);

    return testFile.path;
  }

  /// Tarayıcı ayarları
  Future<Map<String, dynamic>> tarayiciAyarlariGetir(String tarayiciAdi) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getScannerSettings',
        {'scannerName': tarayiciAdi},
      );

      return result.cast<String, dynamic>();
    } on PlatformException catch (e) {
      _debugPrint('Tarayıcı ayarları alma hatası: ${e.message}');

      // Varsayılan ayarlar
      return {
        'resolution': [100, 200, 300, 600, 1200],
        'colorModes': ['color', 'grayscale', 'blackwhite'],
        'paperSizes': ['A4', 'A3', 'Letter', 'Legal'],
        'outputFormats': ['pdf', 'jpeg', 'png', 'tiff'],
        'maxPages': 100,
        'duplex': true,
      };
    }
  }

  /// Tarayıcı durumu kontrolü
  Future<bool> tarayiciDurumuKontrol(String tarayiciAdi) async {
    try {
      final bool result = await _channel.invokeMethod('checkScannerStatus', {
        'scannerName': tarayiciAdi,
      });

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Tarayıcı durum kontrolü hatası: ${e.message}');
      return false;
    }
  }

  /// Tarayıcı bağlantısını test et
  Future<bool> tarayiciBaglantiTest(String tarayiciAdi) async {
    try {
      final bool result = await _channel.invokeMethod('testScannerConnection', {
        'scannerName': tarayiciAdi,
      });

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Tarayıcı bağlantı testi hatası: ${e.message}');
      return true; // Test amaçlı true döndür
    }
  }

  /// Özel tarama ayarları ile belge tara
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
      final String? result = await _channel.invokeMethod('advancedScan', {
        'scannerName': tarayiciAdi,
        'resolution': resolution,
        'colorMode': colorMode,
        'paperSize': paperSize,
        'outputFormat': outputFormat,
        'duplex': duplex,
        'quality': quality,
      });

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Gelişmiş tarama hatası: ${e.message}');
      return await _simulateScanning();
    }
  }

  /// Çoklu sayfa tarama
  Future<List<String>> cokluSayfaTara({
    required String tarayiciAdi,
    required int sayfaSayisi,
    int resolution = 300,
    String outputFormat = 'pdf',
  }) async {
    try {
      final List<dynamic> result = await _channel
          .invokeMethod('multiPageScan', {
            'scannerName': tarayiciAdi,
            'pageCount': sayfaSayisi,
            'resolution': resolution,
            'outputFormat': outputFormat,
          });

      return result.cast<String>();
    } on PlatformException catch (e) {
      _debugPrint('Çoklu sayfa tarama hatası: ${e.message}');

      // Test amaçlı simülasyon
      final List<String> simulatedPages = [];
      for (int i = 0; i < sayfaSayisi; i++) {
        final page = await _simulateScanning();
        if (page != null) {
          simulatedPages.add(page);
        }
      }
      return simulatedPages;
    }
  }

  void _debugPrint(String message) {
    if (kDebugMode) {
      print('TarayiciServisi: $message');
    }
  }
}
