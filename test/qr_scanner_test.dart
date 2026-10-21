import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:arsiv_uygulamasi/models/connection_qr.dart';
import 'package:arsiv_uygulamasi/providers/qr_scan_controller.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/widgets/qr_scanner_widget.dart';
import 'package:arsiv_uygulamasi/widgets/qr_scanner/qr_camera_view.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';

Map<String, dynamic> payload({DateTime? expires}) => {
  'type': 'arsivim_connection',
  'account_version': 1,
  'session_version': 1,
  'transfer_version': GuvenliAktarimServisi.surum,
  'pair_ticket': 'a' * 48,
  'transfer_token': 'b' * 48,
  'pair_expires':
      (expires ?? DateTime.now().add(const Duration(minutes: 5)))
          .millisecondsSinceEpoch,
  'ip': '192.168.1.100',
  'port': 8080,
  'device_name': 'Arşiv bilgisayarım',
  'account': {
    'arsiv_id': 'c' * 48,
    'yonetici_id': 'd' * 48,
    'ad': 'Mehmet',
    'soyad': 'Karataş',
    'kullanici_adi': 'mehmet',
    'bagli': 0,
  },
};

class CameraPlatform extends MobileScannerPlatform {
  final codes = StreamController<BarcodeCapture?>.broadcast();
  final torch = StreamController<TorchState>.broadcast();
  int starts = 0, stops = 0, disposes = 0, flashes = 0;
  bool denied = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => codes.stream;
  @override
  Stream<TorchState> get torchStateStream => torch.stream;
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xff253730));
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    expect(options.formats, [BarcodeFormat.qrCode]);
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> toggleTorch() async {
    flashes++;
    torch.add(TorchState.on);
  }

  @override
  Future<void> setFocusPoint(Offset point) async {}
  void emit(String code) => codes.add(
    BarcodeCapture(
      barcodes: [Barcode(rawValue: code, format: BarcodeFormat.qrCode)],
    ),
  );
  Future<void> close() async {
    await codes.close();
    await torch.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Invalid, expired, incompatible and arbitrary QR codes cannot proceed',
    () {
      for (final raw in [
        'https://example.com',
        '[]',
        '{}',
        'not json',
        jsonEncode({...payload(), 'type': 'other'}),
        jsonEncode({...payload(), 'port': 22}),
        jsonEncode({...payload(), 'transfer_token': 'invalid'}),
        jsonEncode({...payload(), 'session_version': 0}),
        jsonEncode({...payload(), 'account': {}}),
        jsonEncode(
          payload(expires: DateTime.now().subtract(const Duration(seconds: 1))),
        ),
      ]) {
        expect(() => ConnectionQr.parse(raw), throwsA(isA<QrReadException>()));
      }
      final result = ConnectionQr.parse(jsonEncode(payload()));
      expect(result.device, 'Arşiv bilgisayarım');
      expect(result.address, '192.168.1.100:8080');
    },
  );
  test(
    'Duplicate detections/confirmations are ignored and expiry is checked again',
    () {
      var clock = DateTime(2026, 10, 22);
      final c = QrScanController(clock: () => clock);
      addTearDown(c.dispose);
      final code = jsonEncode(
        payload(expires: clock.add(const Duration(seconds: 30))),
      );
      c.detect(code);
      c.detect('invalid');
      expect(c.result, isNotNull);
      expect(c.error, isNull);
      clock = clock.add(const Duration(minutes: 1));
      expect(c.confirm(), isNull);
      expect(c.error, contains('süresi dolmuş'));
      c.retry();
      c.detect(
        jsonEncode(payload(expires: clock.add(const Duration(minutes: 1)))),
      );
      expect(c.confirm(), isNotNull);
      expect(c.confirm(), isNull);
    },
  );
  late MobileScannerPlatform previous;
  late CameraPlatform platform;
  setUp(() {
    previous = MobileScannerPlatform.instance;
    platform = CameraPlatform();
    MobileScannerPlatform.instance = platform;
    MobileScannerController.resetPlatformSessionOwner();
  });
  tearDown(() async {
    await platform.close();
    MobileScannerPlatform.instance = previous;
  });
  testWidgets(
    'Camera starts inline, pauses in background, resumes and releases on close',
    (tester) async {
      String? scanned;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: QrCameraView(
                onDetected: (raw) => scanned = raw,
                onError: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.starts, 1);
      await tester.tap(find.byTooltip('Feneri aç'));
      await tester.pumpAndSettle();
      expect(platform.flashes, 1);
      expect(find.byTooltip('Feneri kapat'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(platform.stops, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(platform.starts, 2);
      platform.emit('example');
      await tester.pump();
      expect(scanned, 'example');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(platform.disposes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Permission denied is actionable and does not repeatedly prompt on lifecycle',
    (tester) async {
      platform.denied = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: QrCameraView(onDetected: (_) {}, onError: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kamera izni gerekli'), findsOneWidget);
      expect(find.text('Ayarları aç'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(platform.starts, 1);
      platform.denied = false;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(platform.starts, 2);
      expect(find.text('Kamera izni gerekli'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_QR')) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 390),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Scanner ${size.width}x${size.height} text $scale reads, retries and confirms once',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          var submissions = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.forPalette(AppPalette.forest),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: RepaintBoundary(
                key: key,
                child: QRScannerScreen(
                  onQRScanned: (_) => submissions++,
                  cameraBuilder:
                      (_, detected) =>
                          QrCameraView(onDetected: detected, onError: (_) {}),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_QR') &&
              size.width == 390 &&
              scale == 1) {
            await tester.runAsync(() async {
              final shot =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await shot.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'artifacts/qr-scanner-390.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              shot.dispose();
            });
          }
          platform.emit('not an archive code');
          await tester.pumpAndSettle();
          expect(find.text('Kod kullanılamıyor'), findsOneWidget);
          expect(submissions, 0);
          expect(platform.disposes, 1);
          await tester.ensureVisible(find.byKey(const ValueKey('qr-retry')));
          await tester.tap(find.byKey(const ValueKey('qr-retry')));
          await tester.pumpAndSettle();
          expect(platform.starts, 2);
          final code = jsonEncode(payload());
          platform.emit(code);
          platform.emit(code);
          await tester.pumpAndSettle();
          expect(find.text('Cihaz bilgisi'), findsOneWidget);
          expect(submissions, 0);
          expect(find.text('Mehmet Karataş'), findsOneWidget);
          expect(find.byType(QrCameraView), findsNothing);
          await tester.ensureVisible(find.byKey(const ValueKey('qr-confirm')));
          await tester.tap(find.byKey(const ValueKey('qr-confirm')));
          await tester.pumpAndSettle();
          expect(submissions, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
