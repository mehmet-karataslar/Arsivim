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
      rethrow;
    }
  }

  /// Windows için tarayıcı arama
  Future<List<String>> _windowsTarayicilariAra() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('findScanners');
      return result.cast<String>();
    } on PlatformException catch (e) {
      _debugPrint('Windows tarayıcı arama hatası: ${e.message}');

      // WIA Scanner API'yi dene
      try {
        final String scanners = await _channel.invokeMethod('findWIAScanners');
        if (scanners.isNotEmpty) {
          return scanners.split('|').where((s) => s.isNotEmpty).toList();
        }
      } catch (e2) {
        _debugPrint('WIA tarayıcı arama hatası: $e2');
      }

      throw PlatformException(
        code: 'NO_SCANNERS_FOUND',
        message:
            'Hiç tarayıcı bulunamadı. Tarayıcınızın bağlı, açık ve doğru şekilde yüklendiğinden emin olun.',
        details: e.message,
      );
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
      rethrow;
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

      if (result == null || result.isEmpty) {
        throw PlatformException(
          code: 'SCAN_FAILED',
          message: 'Tarama işlemi tamamlanamadı',
        );
      }

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Windows belge tarama hatası: ${e.message}');

      // Hata kodlarına göre daha anlamlı mesajlar
      switch (e.code) {
        case 'SCANNER_NOT_FOUND':
          throw PlatformException(
            code: e.code,
            message: 'Seçilen tarayıcı bulunamadı veya bağlantı kesildi',
          );
        case 'SCANNER_BUSY':
          throw PlatformException(
            code: e.code,
            message: 'Tarayıcı meşgul. Lütfen bekleyip tekrar deneyin',
          );
        case 'PAPER_JAM':
          throw PlatformException(
            code: e.code,
            message: 'Kağıt sıkışması. Lütfen tarayıcıyı kontrol edin',
          );
        case 'NO_PAPER':
          throw PlatformException(
            code: e.code,
            message: 'Tarayıcıda kağıt yok. Lütfen kağıt ekleyin',
          );
        case 'COVER_OPEN':
          throw PlatformException(
            code: e.code,
            message: 'Tarayıcı kapağı açık. Lütfen kapatın',
          );
        default:
          throw PlatformException(
            code: 'SCAN_ERROR',
            message: 'Tarama sırasında hata oluştu: ${e.message}',
          );
      }
    }
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

      // Varsayılan ayarları döndür
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
      return false;
    }
  }

  /// Network tarayıcıları keşfet (WiFi tarayıcıları)
  Future<List<String>> networkTarayicilariKesfet() async {
    try {
      if (Platform.isWindows) {
        final List<dynamic> result = await _channel.invokeMethod(
          'discoverNetworkScanners',
        );
        return result.cast<String>();
      } else {
        throw UnsupportedError(
          'Network tarayıcı keşfi sadece Windows platformunda desteklenmektedir',
        );
      }
    } on PlatformException catch (e) {
      _debugPrint('Network tarayıcı keşfi hatası: ${e.message}');

      // Varsayılan olarak boş liste döndür
      return [];
    }
  }

  /// WiFi ağ durumunu kontrol et
  Future<bool> wifiDurumuKontrol() async {
    try {
      final bool result = await _channel.invokeMethod('checkWiFiStatus');
      return result;
    } on PlatformException catch (e) {
      _debugPrint('WiFi durum kontrolü hatası: ${e.message}');
      return false;
    }
  }

  /// Network tarayıcı bağlantı kalitesini test et
  Future<Map<String, dynamic>> networkBaglantiKalitesiTest(
    String tarayiciAdi,
  ) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'testNetworkScannerQuality',
        {'scannerName': tarayiciAdi},
      );

      return result.cast<String, dynamic>();
    } on PlatformException catch (e) {
      _debugPrint('Network bağlantı kalitesi testi hatası: ${e.message}');

      // Varsayılan kalite bilgisi
      return {
        'signalStrength': 0,
        'latency': -1,
        'isReachable': false,
        'connectionType': 'unknown',
        'errorMessage': e.message,
      };
    }
  }

  /// WiFi tarayıcı için özel ayarlar
  Future<Map<String, dynamic>> wifiTarayiciAyarlari(String tarayiciAdi) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'getWiFiScannerSettings',
        {'scannerName': tarayiciAdi},
      );

      return result.cast<String, dynamic>();
    } on PlatformException catch (e) {
      _debugPrint('WiFi tarayıcı ayarları alma hatası: ${e.message}');

      // WiFi tarayıcılar için optimize edilmiş varsayılan ayarlar
      return {
        'resolution': [150, 200, 300, 600], // Düşük başlangıç çözünürlüğü
        'colorModes': ['color', 'grayscale', 'blackwhite'],
        'paperSizes': ['A4', 'A3', 'Letter', 'Legal'],
        'outputFormats': ['pdf', 'jpeg', 'png'],
        'maxPages': 50, // WiFi için düşük sayfa limiti
        'duplex': false, // WiFi tarayıcılar genellikle duplex yapmaz
        'timeout': 30000, // 30 saniye timeout
        'bufferSize': 32768, // 32KB buffer
        'compression': 'medium', // Orta sıkıştırma
        'networkOptimized': true,
      };
    }
  }

  /// Network tarayıcı IP adresini al
  Future<String?> networkTarayiciIPAdres(String tarayiciAdi) async {
    try {
      final String? result = await _channel.invokeMethod(
        'getNetworkScannerIP',
        {'scannerName': tarayiciAdi},
      );

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Network tarayıcı IP adresi alma hatası: ${e.message}');
      return null;
    }
  }

  /// WiFi tarayıcı için optimize edilmiş tarama
  Future<String?> wifiOptimizeTarama({
    required String tarayiciAdi,
    int resolution = 200, // WiFi için düşük çözünürlük
    String colorMode = 'color',
    String paperSize = 'A4',
    String outputFormat = 'pdf',
    int timeout = 30000, // 30 saniye timeout
    bool networkOptimized = true,
  }) async {
    try {
      final String? result = await _channel.invokeMethod('wifiOptimizedScan', {
        'scannerName': tarayiciAdi,
        'resolution': resolution,
        'colorMode': colorMode,
        'paperSize': paperSize,
        'outputFormat': outputFormat,
        'timeout': timeout,
        'networkOptimized': networkOptimized,
        'compression': 'medium',
        'bufferSize': 32768,
      });

      if (result == null || result.isEmpty) {
        throw PlatformException(
          code: 'WIFI_SCAN_FAILED',
          message: 'WiFi tarama işlemi tamamlanamadı',
        );
      }

      return result;
    } on PlatformException catch (e) {
      _debugPrint('WiFi optimize tarama hatası: ${e.message}');

      // WiFi specific error handling
      switch (e.code) {
        case 'NETWORK_SCANNER_UNREACHABLE':
          throw PlatformException(
            code: e.code,
            message:
                'WiFi tarayıcı erişilemez durumda. Ağ bağlantınızı kontrol edin.',
          );
        case 'SCANNER_TIMEOUT':
          throw PlatformException(
            code: e.code,
            message: 'WiFi tarayıcı zaman aşımı. Ağ bağlantınızı kontrol edin.',
          );
        case 'WEAK_SIGNAL':
          throw PlatformException(
            code: e.code,
            message: 'WiFi sinyal gücü zayıf. Tarayıcıya daha yakın olun.',
          );
        case 'NETWORK_CONGESTION':
          throw PlatformException(
            code: e.code,
            message: 'Ağ trafiği yoğun. Daha sonra tekrar deneyin.',
          );
        default:
          throw PlatformException(
            code: 'WIFI_SCAN_ERROR',
            message: 'WiFi tarama hatası: ${e.message}',
          );
      }
    }
  }

  /// Network tarayıcı sorun giderme bilgileri
  Future<Map<String, dynamic>> networkSorunGiderme(String tarayiciAdi) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'networkTroubleshooting',
        {'scannerName': tarayiciAdi},
      );

      return result.cast<String, dynamic>();
    } on PlatformException catch (e) {
      _debugPrint('Network sorun giderme hatası: ${e.message}');

      // Temel sorun giderme bilgileri
      return {
        'wifiConnected': false,
        'scannerReachable': false,
        'signalStrength': 0,
        'latency': -1,
        'suggestedActions': [
          'WiFi bağlantınızı kontrol edin',
          'Tarayıcının WiFi ağına bağlı olduğundan emin olun',
          'Tarayıcıyı yeniden başlatın',
          'Router\'ı yeniden başlatın',
          'Tarayıcı IP adresini kontrol edin',
        ],
        'errorDetails': e.message,
      };
    }
  }

  /// Local network'te tarayıcı ara (IP range scanning)
  Future<List<String>> localNetworkTarayiciAra() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'scanLocalNetwork',
      );
      return result.cast<String>();
    } on PlatformException catch (e) {
      _debugPrint('Local network tarayıcı arama hatası: ${e.message}');
      return [];
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

      if (result == null || result.isEmpty) {
        throw PlatformException(
          code: 'ADVANCED_SCAN_FAILED',
          message: 'Gelişmiş tarama işlemi tamamlanamadı',
        );
      }

      return result;
    } on PlatformException catch (e) {
      _debugPrint('Gelişmiş tarama hatası: ${e.message}');
      rethrow;
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
      throw PlatformException(
        code: 'MULTI_PAGE_SCAN_FAILED',
        message: 'Çoklu sayfa tarama sırasında hata oluştu: ${e.message}',
      );
    }
  }

  /// Hata kodundan kullanıcı dostu mesaj üret
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'NO_SCANNERS_FOUND':
        return 'Tarayıcı bulunamadı. Cihazınızın bağlı ve açık olduğundan emin olun.';
      case 'SCANNER_NOT_FOUND':
        return 'Seçilen tarayıcı bulunamadı veya bağlantı kesildi.';
      case 'SCANNER_BUSY':
        return 'Tarayıcı başka bir işlem yapıyor. Lütfen bekleyip tekrar deneyin.';
      case 'PAPER_JAM':
        return 'Kağıt sıkışması tespit edildi. Lütfen tarayıcıyı kontrol edin.';
      case 'NO_PAPER':
        return 'Tarayıcıda kağıt yok. Lütfen kağıt ekleyin.';
      case 'COVER_OPEN':
        return 'Tarayıcı kapağı açık. Lütfen kapatın.';
      case 'SCANNER_CONNECTION_FAILED':
        return 'Tarayıcı bağlantısı başarısız. Cihazınızı kontrol edin.';
      case 'SCANNER_PROPERTIES_FAILED':
        return 'Tarayıcı ayarları yapılandırılamadı. Sürücüleri kontrol edin.';
      case 'DATA_TRANSFER_FAILED':
        return 'Veri aktarımı başarısız oldu. Tarayıcı bağlantısını kontrol edin.';
      case 'SCAN_OPERATION_FAILED':
        return 'Tarama işlemi başarısız oldu. Lütfen tekrar deneyin.';
      case 'PLUGIN_NOT_INITIALIZED':
        return 'Tarayıcı eklentisi başlatılamadı. Uygulamayı yeniden başlatın.';
      case 'UNKNOWN_SCANNER_ERROR':
        return 'Bilinmeyen tarayıcı hatası. Cihazınızı kontrol edin.';
      case 'BUFFER_TOO_SMALL':
        return 'Veri buffer\'ı yetersiz. Lütfen tekrar deneyin.';
      case 'NETWORK_SCANNER_UNREACHABLE':
        return 'Ağ tarayıcısına ulaşılamıyor. Wi-Fi bağlantınızı kontrol edin.';
      case 'SCANNER_OFFLINE':
        return 'Tarayıcı çevrim dışı. Cihazınızın açık ve ağa bağlı olduğundan emin olun.';
      case 'SCANNER_TIMEOUT':
        return 'Tarayıcı bağlantısı zaman aşımına uğradı. Ağ bağlantınızı kontrol edin.';
      case 'SCAN_FAILED':
        return 'Tarama işlemi başarısız oldu. Lütfen tekrar deneyin.';
      case 'ADVANCED_SCAN_FAILED':
        return 'Gelişmiş tarama ayarlarıyla tarama başarısız oldu.';
      case 'MULTI_PAGE_SCAN_FAILED':
        return 'Çoklu sayfa tarama başarısız oldu.';
      default:
        return 'Bilinmeyen bir hata oluştu: $errorCode. Lütfen tarayıcınızı kontrol edin.';
    }
  }

  void _debugPrint(String message) {
    if (kDebugMode) {
      print('TarayiciServisi: $message');
    }
  }
}
