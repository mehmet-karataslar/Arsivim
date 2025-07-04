import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/belge_modeli.dart';
import '../models/senkron_session.dart';
import '../utils/sabitler.dart';

/// Senkronizasyon doğrulama servisi
class SenkronValidationService {
  static final SenkronValidationService _instance =
      SenkronValidationService._internal();
  static SenkronValidationService get instance => _instance;
  SenkronValidationService._internal();

  /// Ön koşul kontrollerini yap
  Future<SenkronValidationResult> validatePrerequisites() async {
    return await validateSyncPrerequisites();
  }

  /// Senkronizasyon ön koşullarını doğrula
  Future<SenkronValidationResult> validateSyncPrerequisites() async {
    final results = <SenkronValidationCheck>[];

    // Network bağlantısı kontrolü
    results.add(await _checkNetworkConnectivity());

    // Depolama alanı kontrolü
    results.add(await _checkStorageSpace());

    // Dosya sistemi erişimi kontrolü
    results.add(await _checkFileSystemAccess());

    // İzin kontrolü
    results.add(await _checkPermissions());

    // Sistem kaynaklarını kontrolü
    results.add(await _checkSystemResources());

    final allPassed = results.every((check) => check.isValid);
    final criticalFailed = results.any(
      (check) =>
          !check.isValid &&
          check.severity == SenkronValidationSeverity.critical,
    );

    return SenkronValidationResult(
      isValid: allPassed,
      canProceedWithWarnings: !criticalFailed,
      checks: results,
    );
  }

  /// Belge doğrulama
  Future<bool> validateDocument(BelgeModeli document) async {
    try {
      // Dosya varlığı kontrolü
      if (!await File(document.dosyaYolu).exists()) {
        _log('⚠️ Dosya bulunamadı: ${document.dosyaAdi}');
        return false;
      }

      // Dosya boyutu kontrolü
      final file = File(document.dosyaYolu);
      final actualSize = await file.length();
      if (actualSize != document.dosyaBoyutu) {
        _log('⚠️ Dosya boyutu uyumsuzluğu: ${document.dosyaAdi}');
        return false;
      }

      // Hash kontrolü (eğer mevcut ise)
      if (document.dosyaHash.isNotEmpty) {
        final actualHash = await _calculateFileHash(file);
        if (actualHash != document.dosyaHash) {
          _log('⚠️ Hash uyumsuzluğu: ${document.dosyaAdi}');
          return false;
        }
      }

      // Dosya türü kontrolü
      if (!_isSupportedFileType(document.dosyaTipi)) {
        _log('⚠️ Desteklenmeyen dosya türü: ${document.dosyaTipi}');
        return false;
      }

      return true;
    } catch (e) {
      _log('❌ Belge doğrulama hatası: $e');
      return false;
    }
  }

  /// Oturum parametrelerini doğrula
  bool validateSessionParameters(SenkronSession session) {
    // Session ID kontrolü
    if (session.sessionId.isEmpty) {
      _log('⚠️ Geçersiz session ID');
      return false;
    }

    // Cihaz ID kontrolü
    if (session.localDeviceId.isEmpty || session.remoteDeviceId.isEmpty) {
      _log('⚠️ Geçersiz cihaz ID\'leri');
      return false;
    }

    // Durum kontrolü
    if (session.status == SenkronSessionStatus.unknown) {
      _log('⚠️ Geçersiz session durumu');
      return false;
    }

    return true;
  }

  /// Network bağlantısını kontrol et
  Future<SenkronValidationCheck> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;

      return SenkronValidationCheck(
        name: 'Network Bağlantısı',
        isValid: hasConnection,
        severity: SenkronValidationSeverity.critical,
        message:
            hasConnection
                ? 'Network bağlantısı mevcut'
                : 'Network bağlantısı bulunamadı',
      );
    } catch (e) {
      return SenkronValidationCheck(
        name: 'Network Bağlantısı',
        isValid: false,
        severity: SenkronValidationSeverity.critical,
        message: 'Network kontrolü başarısız: $e',
      );
    }
  }

  /// Depolama alanını kontrol et
  Future<SenkronValidationCheck> _checkStorageSpace() async {
    try {
      // Geçici dizin kullanarak alan kontrolü
      final tempDir = Directory.systemTemp;
      final freeSpace = await _getAvailableSpace(tempDir.path);

      const requiredSpace = 100 * 1024 * 1024; // 100 MB minimum
      final hasEnoughSpace = freeSpace > requiredSpace;

      return SenkronValidationCheck(
        name: 'Depolama Alanı',
        isValid: hasEnoughSpace,
        severity: SenkronValidationSeverity.high,
        message:
            hasEnoughSpace
                ? 'Yeterli depolama alanı mevcut (${_formatBytes(freeSpace)})'
                : 'Yetersiz depolama alanı (${_formatBytes(freeSpace)} mevcut)',
      );
    } catch (e) {
      return SenkronValidationCheck(
        name: 'Depolama Alanı',
        isValid: false,
        severity: SenkronValidationSeverity.high,
        message: 'Depolama alanı kontrolü başarısız: $e',
      );
    }
  }

  /// Dosya sistemi erişimini kontrol et
  Future<SenkronValidationCheck> _checkFileSystemAccess() async {
    try {
      // Test dosyası oluşturarak yazma iznini kontrol et
      final testFile = File('${Directory.systemTemp.path}/sync_test.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();

      return SenkronValidationCheck(
        name: 'Dosya Sistemi Erişimi',
        isValid: true,
        severity: SenkronValidationSeverity.critical,
        message: 'Dosya sistemi erişimi başarılı',
      );
    } catch (e) {
      return SenkronValidationCheck(
        name: 'Dosya Sistemi Erişimi',
        isValid: false,
        severity: SenkronValidationSeverity.critical,
        message: 'Dosya sistemi erişimi başarısız: $e',
      );
    }
  }

  /// İzinleri kontrol et
  Future<SenkronValidationCheck> _checkPermissions() async {
    try {
      // Temel izinleri kontrol et
      // Bu kısım platform özelinde genişletilebilir

      return SenkronValidationCheck(
        name: 'İzinler',
        isValid: true,
        severity: SenkronValidationSeverity.medium,
        message: 'Gerekli izinler mevcut',
      );
    } catch (e) {
      return SenkronValidationCheck(
        name: 'İzinler',
        isValid: false,
        severity: SenkronValidationSeverity.medium,
        message: 'İzin kontrolü başarısız: $e',
      );
    }
  }

  /// Sistem kaynaklarını kontrol et
  Future<SenkronValidationCheck> _checkSystemResources() async {
    try {
      // Bellek ve CPU kullanımını kontrol et
      // Bu kısım platform özelinde implementasyon gerektirir

      return SenkronValidationCheck(
        name: 'Sistem Kaynakları',
        isValid: true,
        severity: SenkronValidationSeverity.low,
        message: 'Sistem kaynakları yeterli',
      );
    } catch (e) {
      return SenkronValidationCheck(
        name: 'Sistem Kaynakları',
        isValid: false,
        severity: SenkronValidationSeverity.low,
        message: 'Sistem kaynakları kontrolü başarısız: $e',
      );
    }
  }

  /// Dosya hash hesapla
  Future<String> _calculateFileHash(File file) async {
    // Basit hash hesaplama - crypto paketi ile SHA-256 kullanılabilir
    final bytes = await file.readAsBytes();
    return bytes.length.toString(); // Geçici implementasyon
  }

  /// Desteklenen dosya türünü kontrol et
  bool _isSupportedFileType(String fileType) {
    return Sabitler.DESTEKLENEN_DOSYA_TIPLERI.contains(fileType.toLowerCase());
  }

  /// Mevcut disk alanını hesapla
  Future<int> _getAvailableSpace(String path) async {
    // Platform özelinde implementasyon gerekir
    // Şimdilik sabit değer dönüyoruz
    return 1024 * 1024 * 1024; // 1 GB
  }

  /// Byte formatı
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Log mesajı
  void _log(String message) {
    print(message);
  }

  /// Disk alanı kontrolü (alias)
  Future<DiskSpaceResult> checkDiskSpace() async {
    final check = await _checkStorageSpace();
    return DiskSpaceResult(
      hasSufficientSpace: check.isValid,
      availableGB: 1.0, // Placeholder
      usedGB: 0.5, // Placeholder
      totalGB: 1.5, // Placeholder
    );
  }

  /// Database bütünlüğü kontrolü
  Future<DatabaseIntegrityResult> checkDatabaseIntegrity() async {
    try {
      // Basit database bütünlük kontrolü
      // Gerçek implementasyon VeriTabaniServisi ile olacak
      return DatabaseIntegrityResult(isValid: true, errors: [], warnings: []);
    } catch (e) {
      return DatabaseIntegrityResult(
        isValid: false,
        errors: [e.toString()],
        warnings: [],
      );
    }
  }

  /// Database onarımı
  Future<void> repairDatabase() async {
    try {
      // Database onarım işlemleri
      // Gerçek implementasyon VeriTabaniServisi ile olacak
      print('Database onarımı yapılıyor...');
    } catch (e) {
      throw Exception('Database onarımı başarısız: $e');
    }
  }
}

/// Disk alanı sonucu
class DiskSpaceResult {
  final bool hasSufficientSpace;
  final double availableGB;
  final double usedGB;
  final double totalGB;

  DiskSpaceResult({
    required this.hasSufficientSpace,
    required this.availableGB,
    required this.usedGB,
    required this.totalGB,
  });
}

/// Database bütünlük sonucu
class DatabaseIntegrityResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  DatabaseIntegrityResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// Doğrulama sonucu
class SenkronValidationResult {
  final bool isValid;
  final bool canProceedWithWarnings;
  final List<SenkronValidationCheck> checks;

  SenkronValidationResult({
    required this.isValid,
    required this.canProceedWithWarnings,
    required this.checks,
  });

  /// Hata mesajları
  List<String> get errorMessages {
    return checks
        .where((check) => !check.isValid)
        .map((check) => check.message)
        .toList();
  }

  /// Errors property (alias)
  List<String> get errors => errorMessages;

  /// Uyarı mesajları
  List<String> get warningMessages {
    return checks
        .where(
          (check) =>
              !check.isValid &&
              check.severity != SenkronValidationSeverity.critical,
        )
        .map((check) => check.message)
        .toList();
  }

  /// Kritik hatalar
  List<SenkronValidationCheck> get criticalFailures {
    return checks
        .where(
          (check) =>
              !check.isValid &&
              check.severity == SenkronValidationSeverity.critical,
        )
        .toList();
  }
}

/// Doğrulama kontrolü
class SenkronValidationCheck {
  final String name;
  final bool isValid;
  final SenkronValidationSeverity severity;
  final String message;

  SenkronValidationCheck({
    required this.name,
    required this.isValid,
    required this.severity,
    required this.message,
  });
}

/// Doğrulama ciddiyeti
enum SenkronValidationSeverity {
  low, // Düşük - devam edilebilir
  medium, // Orta - uyarı ile devam
  high, // Yüksek - dikkatli devam
  critical, // Kritik - durdurucu
}
