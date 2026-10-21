import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:arsiv_uygulamasi/models/scan_page.dart';
import 'package:arsiv_uygulamasi/providers/scan_review_controller.dart';
import 'package:arsiv_uygulamasi/providers/document_editor_controller.dart';
import 'package:arsiv_uygulamasi/screens/scan_review_screen.dart';
import 'package:arsiv_uygulamasi/services/document_scan_service.dart';
import 'package:arsiv_uygulamasi/services/document_editor_repository.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';

class ReviewScanner extends DocumentScanService {
  bool fail = false;
  Completer<void>? wait;
  int builds = 0;
  List<ScanPage>? built;
  List<String>? extra;
  @override
  bool get isSupported => true;
  @override
  Future<List<String>?> capturePages() async => extra;
  @override
  Future<ScannedPdf> createPdf(List<ScanPage> pages, {String? name}) async {
    builds++;
    built = pages;
    if (wait != null) await wait!.future;
    if (fail) throw StateError('disk full');
    return ScannedPdf(
      PlatformFile(name: '$name.pdf', path: 'C:/review.pdf', size: 123),
      pages.length,
      pages: pages,
    );
  }
}

class DraftRepository extends DocumentEditorRepository {
  Map<String, dynamic>? value;
  @override
  Future<EditorOptions> options() async => const EditorOptions([], []);
  @override
  Future<Map<String, dynamic>?> draft(int? id) async => value;
  @override
  Future<void> saveDraft(int? id, Map<String, dynamic> data) async {
    value = data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Order, rotation, removal undo and added pages reach the same PDF',
    () async {
      final scanner = ReviewScanner()..extra = ['third'];
      final original = [const ScanPage('first'), const ScanPage('second')];
      final data = ScanReviewController(original, scanner);
      data.move(1);
      data.rotate();
      data.remove();
      data.undo();
      await data.addPages();
      expect(data.pages.map((p) => p.path), ['second', 'first', 'third']);
      expect(data.pages[1].quarterTurns, 1);
      expect(original.first.quarterTurns, 0);
      final result = await data.finish('Deneme');
      expect(result!.pageCount, 3);
      expect(scanner.built![1].quarterTurns, 1);
      data.dispose();
    },
  );
  test(
    'Empty scan and duplicate saves are blocked; generation failure retains pages',
    () async {
      final scanner =
          ReviewScanner()
            ..wait = Completer<void>()
            ..fail = true;
      final data = ScanReviewController([const ScanPage('first')], scanner);
      data.remove();
      expect(await data.finish('Empty'), isNull);
      data.undo();
      final run = data.finish('Saved');
      data.rotate();
      data.remove();
      await data.finish('Again');
      expect(scanner.builds, 1);
      expect(data.pages.single.quarterTurns, 0);
      scanner.wait!.complete();
      expect(await run, isNull);
      expect(data.pages.single.path, 'first');
      expect(data.error, contains('yeniden deneyebilirsiniz'));
      data.dispose();
    },
  );
  test(
    'Scan draft restores order and rotation; replacing PDF does not add a second document',
    () async {
      final root = await Directory.systemTemp.createTemp('scan-draft-test-');
      addTearDown(() => root.delete(recursive: true));
      final page = await File('${root.path}/page.png').writeAsBytes([1, 2]);
      final pdf = await File('${root.path}/test.pdf').writeAsBytes([1, 2, 3]);
      final repository = DraftRepository();
      final c = DocumentEditorController(repository: repository);
      await c.load();
      final file = PlatformFile(name: 'Test.pdf', path: pdf.path, size: 3);
      c.addScan(
        ScannedPdf(file, 1, pages: [ScanPage(page.path, quarterTurns: 3)]),
      );
      await c.saveDraft();
      c.dispose();
      final restored = DocumentEditorController(repository: repository);
      await restored.load();
      await restored.restoreDraft();
      expect(restored.scanPages[pdf.path]!.single.quarterTurns, 3);
      restored.addScan(
        ScannedPdf(
          PlatformFile(
            name: 'Updated.pdf',
            path: '${root.path}/updated.pdf',
            size: 4,
          ),
          1,
          pages: [ScanPage(page.path)],
        ),
        replacing: pdf.path,
      );
      expect(restored.files.length, 1);
      expect(restored.scanPages.containsKey(pdf.path), false);
      restored.dispose();
    },
  );
  late Directory images;
  late String imagePath;
  setUpAll(() async {
    images = await Directory.systemTemp.createTemp('scan-preview-test-');
    final picture = img.Image(width: 420, height: 594);
    img.fill(picture, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      picture,
      x1: 30,
      y1: 35,
      x2: 390,
      y2: 85,
      color: img.ColorRgb8(0, 125, 90),
    );
    for (var y = 130; y < 500; y += 35) {
      img.fillRect(
        picture,
        x1: 35,
        y1: y,
        x2: y == 130 ? 270 : 375,
        y2: y + 6,
        color: img.ColorRgb8(130, 142, 140),
      );
    }
    imagePath =
        (await File(
          '${images.path}/page.png',
        ).writeAsBytes(img.encodePng(picture))).path;
    if (const bool.fromEnvironment('CAPTURE_SCAN_PREVIEW')) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  tearDownAll(() async => images.delete(recursive: true));
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Review ${size.width}x${size.height} text $scale remains usable',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await tester.runAsync(() async {
            for (final width in [180, 1600]) {
              await precacheImage(
                ResizeImage(FileImage(File(imagePath)), width: width),
                tester.element(find.byType(SizedBox)),
              );
            }
          });
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
                child: ScanReviewScreen(
                  pages: [ScanPage(imagePath), ScanPage(imagePath)],
                  scanner: ReviewScanner(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('CAPTURE_SCAN_PREVIEW') &&
              size.width == 390 &&
              scale == 1) {
            await tester.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'artifacts/scan-review-390.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final create = find.byKey(const ValueKey('scan-create-pdf'));
          await tester.ensureVisible(create);
          await tester.pumpAndSettle();
          expect(create.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Keyboard reduces the available height while naming the PDF.
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
