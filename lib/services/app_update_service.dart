import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum UpdatePlatform { android, windows, unsupported }

enum UpdateStage { idle, checking, available, downloading, ready, installing }

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stable releases only. Build metadata does not replace a version bump.
class UpdateVersion implements Comparable<UpdateVersion> {
  UpdateVersion(String value) {
    final match = RegExp(
      r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\+\d+)?$',
    ).firstMatch(value);
    if (match == null) {
      throw const UpdateException('Sürüm bilgisi geçersiz.');
    }
    parts = [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }
  late final List<int> parts;
  @override
  int compareTo(UpdateVersion other) {
    for (var i = 0; i < parts.length; i++) {
      final result = parts[i].compareTo(other.parts[i]);
      if (result != 0) return result;
    }
    return 0;
  }
}

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.name,
    required this.url,
    required this.size,
    required this.sha256Hex,
    required this.notes,
  });
  final String version;
  final String name;
  final Uri url;
  final int size;
  final String sha256Hex;
  final String notes;

  static AppUpdate? fromRelease(
    Map<String, dynamic> json,
    String installedVersion,
    UpdatePlatform platform,
  ) {
    if (json['draft'] != false || json['prerelease'] != false) {
      throw const UpdateException('Yayınlanmış kararlı sürüm bulunamadı.');
    }
    final tag = json['tag_name'] as String;
    final version = UpdateVersion(tag);
    if (version.compareTo(UpdateVersion(installedVersion)) <= 0) return null;
    final suffix = switch (platform) {
      UpdatePlatform.android => 'android.apk',
      UpdatePlatform.windows => 'windows-x64-setup.exe',
      _ =>
        throw const UpdateException(
          'Bu cihazda uygulama içi güncelleme desteklenmiyor.',
        ),
    };
    final name = 'Arsivim-v${version.parts.join('.')}-$suffix';
    final matches =
        (json['assets'] as List)
            .where(
              (item) =>
                  item is Map &&
                  item['name'] == name &&
                  item['state'] == 'uploaded',
            )
            .toList();
    if (matches.length != 1) {
      throw const UpdateException(
        'Yeni sürüm var ancak bu cihazın kurulum paketi henüz hazır değil. Daha sonra tekrar kontrol edin.',
      );
    }
    final asset = matches.single as Map;
    final url = Uri.parse(asset['browser_download_url'] as String);
    final expected = Uri.https(
      'github.com',
      '/${AppUpdateService.repository}/releases/download/$tag/$name',
    );
    final digest = asset['digest'];
    final size = asset['size'];
    if (url != expected ||
        digest is! String ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size is! int ||
        size <= 0 ||
        size > 1024 * 1024 * 1024) {
      throw const UpdateException(
        'Güncelleme paketinin adresi veya doğrulama bilgileri geçersiz.',
      );
    }
    return AppUpdate(
      version: version.parts.join('.'),
      name: name,
      url: url,
      size: size,
      sha256Hex: digest.substring(7).toLowerCase(),
      notes: (json['body'] as String? ?? '').trim(),
    );
  }
}

/// Shared across profile rebuilds/navigation. No network request until Check.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    UpdatePlatform? platform,
    http.Client Function()? clientFactory,
    Future<PackageInfo> Function()? packageLoader,
    Future<Directory> Function()? temporaryDirectory,
    Future<String> Function(File)? installer,
  }) : platform =
           platform ??
           (Platform.isAndroid
               ? UpdatePlatform.android
               : Platform.isWindows
               ? UpdatePlatform.windows
               : UpdatePlatform.unsupported),
       _clientFactory = clientFactory ?? http.Client.new,
       _packageLoader = packageLoader ?? PackageInfo.fromPlatform,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _installer = installer;

  static final instance = AppUpdateService();
  static const repository = 'mehmet-karataslar/Arsivim';
  static const _channel = MethodChannel('arsivim/app_update');
  final UpdatePlatform platform;
  final http.Client Function() _clientFactory;
  final Future<PackageInfo> Function() _packageLoader;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<String> Function(File)? _installer;
  UpdateStage stage = UpdateStage.idle;
  String? installedVersion;
  String? installedBuild;
  AppUpdate? update;
  File? _downloadedFile;
  http.Client? _downloadClient;
  bool _cancelled = false;
  int receivedBytes = 0;
  String? message;
  String? error;
  bool get supported => platform != UpdatePlatform.unsupported;
  bool get busy =>
      stage == UpdateStage.checking ||
      stage == UpdateStage.downloading ||
      stage == UpdateStage.installing;
  double? get progress => update == null ? null : receivedBytes / update!.size;

  Future<void> initialize() async {
    if (installedVersion != null) return;
    try {
      final info = await _packageLoader();
      installedVersion = info.version;
      installedBuild = info.buildNumber;
      notifyListeners();
    } catch (_) {
      // A failed platform lookup is retried by Check; never guess a version.
    }
  }

  Future<void> check() async {
    if (busy || !supported) return;
    stage = UpdateStage.checking;
    error = null;
    message = null;
    notifyListeners();
    final client = _clientFactory();
    try {
      final info = await _packageLoader();
      installedVersion = info.version;
      installedBuild = info.buildNumber;
      final response = await client
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Arsivim-Updater',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const UpdateException(
          'GitHub kontrol sınırına ulaşıldı. Bir süre sonra tekrar deneyin.',
        );
      }
      if (response.statusCode == 404) {
        throw const UpdateException(
          'Yayın bilgisine ulaşılamadı. Daha sonra tekrar deneyin.',
        );
      }
      if (response.statusCode != 200) {
        throw const UpdateException(
          'Güncelleme sunucusuna ulaşılamadı. Daha sonra tekrar deneyin.',
        );
      }
      final candidate = AppUpdate.fromRelease(
        jsonDecode(response.body) as Map<String, dynamic>,
        info.version,
        platform,
      );
      await _removeDownload();
      update = candidate;
      stage = candidate == null ? UpdateStage.idle : UpdateStage.available;
      message =
          candidate == null
              ? 'Uygulamanız güncel.'
              : '${candidate.version} sürümü hazır.';
    } catch (e) {
      stage =
          _downloadedFile != null
              ? UpdateStage.ready
              : update != null
              ? UpdateStage.available
              : UpdateStage.idle;
      error = _errorMessage(e);
    } finally {
      client.close();
      notifyListeners();
    }
  }

  Future<void> download() async {
    final release = update;
    if (busy || release == null || stage == UpdateStage.ready) return;
    stage = UpdateStage.downloading;
    receivedBytes = 0;
    error = null;
    message = null;
    _cancelled = false;
    notifyListeners();
    final client = _clientFactory();
    _downloadClient = client;
    Directory? directory;
    try {
      final root = await _temporaryDirectory();
      final cache = await Directory(
        p.join(root.path, 'arsivim-updates'),
      ).create(recursive: true);
      directory = await cache.createTemp('package-');
      final partial = File(p.join(directory.path, '${release.name}.part'));
      final response = await client
          .send(http.Request('GET', release.url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const UpdateException(
          'Güncelleme indirilemedi. Yeniden deneyin.',
        );
      }
      if (response.contentLength != null &&
          response.contentLength != release.size) {
        throw const UpdateException(
          'Paket boyutu yayın bilgisiyle eşleşmiyor.',
        );
      }
      final output = await partial.open(mode: FileMode.write);
      var lastNotification = DateTime.now();
      try {
        await for (final bytes in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          if (_cancelled) throw const UpdateException('İndirme iptal edildi.');
          receivedBytes += bytes.length;
          if (receivedBytes > release.size) {
            throw const UpdateException(
              'İndirilen paket beklenen boyutu aşıyor.',
            );
          }
          await output.writeFrom(bytes);
          if (DateTime.now().difference(lastNotification).inMilliseconds >=
              150) {
            notifyListeners();
            lastNotification = DateTime.now();
          }
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (_cancelled) throw const UpdateException('İndirme iptal edildi.');
      await _verify(partial, release);
      if (_cancelled) throw const UpdateException('İndirme iptal edildi.');
      _downloadedFile = await partial.rename(
        p.join(directory.path, release.name),
      );
      directory = null; // Owned by _downloadedFile until installation/recheck.
      stage = UpdateStage.ready;
      message = 'İndirme tamamlandı ve paket doğrulandı. Kurulum hazır.';
    } catch (e) {
      stage = UpdateStage.available;
      if (_cancelled) {
        message = 'İndirme iptal edildi. Yeniden başlatabilirsiniz.';
      } else {
        error = _errorMessage(e);
      }
    } finally {
      client.close();
      _downloadClient = null;
      if (directory != null && await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {
          /* Retry uses a new directory. */
        }
      }
      notifyListeners();
    }
  }

  void cancelDownload() {
    if (stage != UpdateStage.downloading) return;
    _cancelled = true;
    _downloadClient?.close();
  }

  Future<void> install() async {
    final file = _downloadedFile;
    final release = update;
    if (stage != UpdateStage.ready || file == null || release == null) return;
    stage = UpdateStage.installing;
    error = null;
    message = null;
    notifyListeners();
    try {
      // Check again immediately before executing, including retries after settings.
      await _verify(file, release);
      message = await (_installer ?? _installOnPlatform)(file);
    } catch (e) {
      error = _errorMessage(e);
      await _removeDownload();
    } finally {
      stage =
          _downloadedFile == null ? UpdateStage.available : UpdateStage.ready;
      notifyListeners();
    }
  }

  Future<String> _installOnPlatform(File file) async {
    if (platform == UpdatePlatform.android) {
      final result = await _channel.invokeMethod<String>('installApk', {
        'path': file.path,
      });
      if (result == 'permissionRequired') {
        return 'Açılan ayarlarda bu kaynaktan yüklemeye izin verin. Ardından buraya dönüp “Güncellemeyi kur” düğmesine tekrar basın.';
      }
      if (result != 'opened') {
        throw const UpdateException('Android kurulum ekranı açılamadı.');
      }
      return 'Android kurulum ekranı açıldı. “Güncelle” seçeneğini onaylayın.';
    }
    if (platform == UpdatePlatform.windows) {
      // The installer owns the fixed per-user installation directory. Never run
      // a raw application EXE or replace files while the archive is open.
      await Process.start(file.path, [
        '/NORESTART',
      ], mode: ProcessStartMode.detached);
      return 'Kurulum açıldı. İşlemlerinizi kaydedip Arşivim’i kapatın ve kurulum penceresinden devam edin.';
    }
    throw const UpdateException('Bu cihazda kurulum desteklenmiyor.');
  }

  static Future<void> _verify(File file, AppUpdate release) async {
    if (await file.length() != release.size ||
        (await sha256.bind(file.openRead()).first).toString() !=
            release.sha256Hex) {
      throw const UpdateException(
        'Paket doğrulanamadı. Dosya kurulmadı; yeniden indirin.',
      );
    }
  }

  Future<void> _removeDownload() async {
    final file = _downloadedFile;
    _downloadedFile = null;
    if (file != null) {
      try {
        await file.parent.delete(recursive: true);
      } catch (_) {
        /* Cache can be reclaimed by the OS. */
      }
    }
  }

  static String _errorMessage(Object error) => switch (error) {
    UpdateException() => error.message,
    TimeoutException() => 'Bağlantı zaman aşımına uğradı. Yeniden deneyin.',
    SocketException() || http.ClientException() =>
      'İnternet bağlantısını kontrol edip yeniden deneyin.',
    FileSystemException() =>
      'Dosya kaydedilemedi veya okunamadı. Boş alanı kontrol edip yeniden indirin.',
    PlatformException() =>
      error.message ?? 'Kurulum başlatılamadı. Yeniden deneyin.',
    _ => 'Güncelleme işlemi tamamlanamadı. Daha sonra yeniden deneyin.',
  };
}
