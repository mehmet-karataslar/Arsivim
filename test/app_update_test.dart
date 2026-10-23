import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arsiv_uygulamasi/services/app_update_service.dart';
import 'package:arsiv_uygulamasi/widgets/profile/profile_update.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageBytes = utf8.encode('test package bytes');
Map<String, dynamic> release({
  String version = '2.6.4',
  String suffix = 'android.apk',
}) {
  final name = 'Arsivim-v$version-$suffix';
  return {
    'tag_name': 'v$version',
    'draft': false,
    'prerelease': false,
    'body': 'Güncelleme test notları',
    'assets': [
      <String, dynamic>{
        'name': name,
        'state': 'uploaded',
        'size': packageBytes.length,
        'digest': 'sha256:${sha256.convert(packageBytes)}',
        'browser_download_url':
            'https://github.com/${AppUpdateService.repository}/releases/download/v$version/$name',
      },
    ],
  };
}

Future<PackageInfo> packageInfo() async => PackageInfo(
  appName: 'Arşivim',
  packageName: 'com.mehmetkarataslar.arsivim',
  version: '2.6.3',
  buildNumber: '29',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('numeric comparison, equal and older versions never update', () {
    expect(
      UpdateVersion('v2.10.0').compareTo(UpdateVersion('2.9.9')),
      greaterThan(0),
    );
    expect(UpdateVersion('2.6.3+99').compareTo(UpdateVersion('2.6.3+29')), 0);
    for (final version in ['2.6.3', '2.5.9']) {
      expect(
        AppUpdate.fromRelease(
          release(version: version),
          '2.6.3',
          UpdatePlatform.android,
        ),
        isNull,
      );
    }
    for (final bad in ['2.6', '2.6.4-beta.1', '../2.6.4', '02.6.4']) {
      expect(() => UpdateVersion(bad), throwsA(isA<UpdateException>()));
    }
  });

  test(
    'only a complete stable release and exact platform asset are accepted',
    () {
      for (final key in ['draft', 'prerelease']) {
        final json = release()..[key] = true;
        expect(
          () => AppUpdate.fromRelease(json, '2.6.3', UpdatePlatform.android),
          throwsA(isA<UpdateException>()),
        );
      }
      final windows = release(suffix: 'windows-x64-setup.exe');
      expect(
        AppUpdate.fromRelease(windows, '2.6.3', UpdatePlatform.windows)?.name,
        endsWith('-setup.exe'),
      );
      for (final suffix in [
        'windows-x64.zip',
        'windows-x64.exe',
        'android.apk',
      ]) {
        expect(
          () => AppUpdate.fromRelease(
            release(suffix: suffix),
            '2.6.3',
            UpdatePlatform.windows,
          ),
          throwsA(isA<UpdateException>()),
        );
      }
    },
  );

  test(
    'missing digest, external URL, ambiguous package and invalid size are rejected',
    () {
      for (final change
          in <String, dynamic>{
            'digest': null,
            'browser_download_url': 'https://evil.example/update.apk',
            'size': -1,
            'state': 'new',
          }.entries) {
        final json = release();
        (json['assets'] as List).single[change.key] = change.value;
        expect(
          () => AppUpdate.fromRelease(json, '2.6.3', UpdatePlatform.android),
          throwsA(isA<UpdateException>()),
        );
      }
      final duplicate = release();
      (duplicate['assets'] as List).add((duplicate['assets'] as List).single);
      expect(
        () => AppUpdate.fromRelease(duplicate, '2.6.3', UpdatePlatform.android),
        throwsA(isA<UpdateException>()),
      );
    },
  );

  group('download and installation', () {
    late Directory temp;
    late AppUpdateService service;
    var installations = 0;
    File? installedFile;
    late List<int> downloadedBytes;
    var statusCode = 200;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('arsivim-update-test-');
      installations = 0;
      installedFile = null;
      downloadedBytes = packageBytes;
      statusCode = 200;
      service = AppUpdateService(
        platform: UpdatePlatform.android,
        packageLoader: packageInfo,
        temporaryDirectory: () async => temp,
        clientFactory:
            () => MockClient(
              (request) async =>
                  request.url.host == 'api.github.com'
                      ? http.Response(
                        jsonEncode(release()),
                        statusCode,
                        headers: {
                          'content-type': 'application/json; charset=utf-8',
                        },
                      )
                      : http.Response.bytes(downloadedBytes, 200),
            ),
        installer: (file) async {
          installations++;
          installedFile = file;
          return 'Kurulum açıldı';
        },
      );
    });
    tearDown(() async {
      service.dispose();
      await temp.delete(recursive: true);
    });

    test('only verified complete download can be installed', () async {
      await service.install();
      expect(installations, 0);
      await service.check();
      expect(service.stage, UpdateStage.available);
      await service.download();
      expect(service.stage, UpdateStage.ready);
      expect(service.progress, 1);
      expect(installations, 0); // Explicit user installation step.
      await service.install();
      expect(installations, 1);
      expect(await installedFile!.readAsBytes(), packageBytes);
      expect(installedFile!.path, endsWith('.apk'));
    });

    test(
      'corrupt or truncated download never reaches installer and can retry',
      () async {
        await service.check();
        for (final bytes in [
          List.filled(packageBytes.length, 0),
          packageBytes.sublist(1),
        ]) {
          downloadedBytes = bytes;
          await service.download();
          expect(service.stage, UpdateStage.available);
          expect(service.error, isNotNull);
          expect(
            await temp.list(recursive: true).where((e) => e is File).length,
            0,
          );
          await service.install();
          expect(installations, 0);
        }
        downloadedBytes = packageBytes;
        await service.download();
        expect(service.stage, UpdateStage.ready);
      },
    );

    test(
      'file modified after download is checked again before execution',
      () async {
        await service.check();
        await service.download();
        final file =
            (await temp.list(recursive: true).where((e) => e is File).first)
                as File;
        await file.writeAsBytes(List.filled(packageBytes.length, 0));
        await service.install();
        expect(installations, 0);
        expect(service.stage, UpdateStage.available);
        expect(service.error, contains('doğrulanamadı'));
      },
    );

    test(
      'rate limit is not reported as up to date and can be retried',
      () async {
        statusCode = 403;
        await service.check();
        expect(service.message, isNull);
        expect(service.error, contains('sınırına'));
        statusCode = 200;
        await service.check();
        expect(service.error, isNull);
        expect(service.update, isNotNull);
      },
    );
  });

  test(
    'duplicate checks share busy guard and do not send another request',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final service = AppUpdateService(
        platform: UpdatePlatform.android,
        packageLoader: packageInfo,
        clientFactory:
            () => MockClient((_) {
              calls++;
              return response.future;
            }),
      );
      final first = service.check();
      await service.check();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      response.complete(
        http.Response(
          jsonEncode(release()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await first;
      service.dispose();
    },
  );

  test('cancelled streaming download is removed and never ready', () async {
    final temp = await Directory.systemTemp.createTemp(
      'arsivim-update-cancel-',
    );
    final stream = StreamController<List<int>>();
    final started = Completer<void>();
    final service = AppUpdateService(
      platform: UpdatePlatform.android,
      packageLoader: packageInfo,
      temporaryDirectory: () async => temp,
      clientFactory:
          () => MockClient.streaming((request, _) async {
            if (request.url.host == 'api.github.com') {
              return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode(release()))),
                200,
              );
            }
            started.complete();
            return http.StreamedResponse(stream.stream, 200);
          }),
    );
    await service.check();
    final downloading = service.download();
    await started.future;
    service.cancelDownload();
    stream.add(packageBytes);
    await stream.close();
    await downloading;
    expect(service.stage, UpdateStage.available);
    expect(service.message, contains('iptal'));
    expect(await temp.list(recursive: true).where((e) => e is File).length, 0);
    service.dispose();
    await temp.delete(recursive: true);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'profile update flow fits width $width and only checks on tap',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        final service = AppUpdateService(
          platform: UpdatePlatform.windows,
          packageLoader: packageInfo,
          clientFactory:
              () => MockClient((_) async {
                calls++;
                return http.Response(
                  jsonEncode(release(suffix: 'windows-x64-setup.exe')),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileUpdate(service: service),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(find.text('Yüklü sürüm: 2.6.3 (29)'), findsOneWidget);
        await tester.tap(find.text('Güncellemeleri kontrol et'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('Güncellemeyi indir'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        service.dispose();
      },
    );
  }
}
