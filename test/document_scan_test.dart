import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:arsiv_uygulamasi/models/scan_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/services/document_scan_service.dart';

class PageScanner extends DocumentScanService {
  PageScanner(this.pages, this.output);
  final List<String>? pages;
  final Directory output;
  int directories = 0;
  @override
  bool get isSupported => true;
  @override
  Future<List<String>?> capturePages() async => pages;
  @override
  Future<Directory> createOutputDirectory() async {
    directories++;
    return output.createTemp('attempt-');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('scan-test-'));
  tearDown(() async => root.delete(recursive: true));
  test('Captured pages become a single PDF with one page per photo', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAADklEQVR4nGP4DwYMEAoAU7oL9ZisIGcAAAAASUVORK5CYII=',
    );
    final first = await File('${root.path}/one.png').writeAsBytes(png);
    final second = await File('${root.path}/two.png').writeAsBytes(png);
    final result = await PageScanner([first.path, second.path], root).scan();
    expect(result, isNotNull);
    expect(result!.pageCount, 2);
    expect(result.file.extension, 'pdf');
    final bytes = await File(result.file.path!).readAsBytes();
    expect(result.file.size, bytes.length);
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 2);
    expect(
      await root
          .list(recursive: true)
          .where((f) => f.path.endsWith('.pdf'))
          .length,
      1,
    );
  });
  test(
    'PDF preserves all page rotations and dotted names in durable copies',
    () async {
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
      img.fillRect(
        picture,
        x1: 35,
        y1: 130,
        x2: 270,
        y2: 136,
        color: img.ColorRgb8(130, 142, 140),
      );
      final original = await File(
        '${root.path}/original.png',
      ).writeAsBytes(img.encodePng(picture));
      final result = await PageScanner(null, root).createPdf(
        List.generate(4, (i) => ScanPage(original.path, quarterTurns: i)),
        name: 'Tutanak.2026.pdf',
      );
      expect(result.file.name, 'Tutanak.2026.pdf');
      expect(result.pages.map((p) => p.quarterTurns), [0, 1, 2, 3]);
      await original.delete();
      for (final page in result.pages) {
        expect(await File(page.path).exists(), isTrue);
        expect(page.isCompressed, isTrue);
        expect(page.path, endsWith('.jpg'));
      }
      final bytes = await File(result.file.path!).readAsBytes();
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        4,
      );
      if (const bool.fromEnvironment('CAPTURE_SCAN_PREVIEW')) {
        await File('artifacts/scan-rotation-check.pdf').writeAsBytes(bytes);
      }
    },
  );
  test(
    'Editing and restoring a scan does not recompress its JPEG pages',
    () async {
      final picture = img.Image(width: 420, height: 594);
      img.fill(picture, color: img.ColorRgb8(240, 240, 240));
      img.drawString(
        picture,
        'Arsiv 2026: 1234567890',
        font: img.arial24,
        x: 20,
        y: 30,
        color: img.ColorRgb8(0, 0, 0),
      );
      final original = await File(
        '${root.path}/source.png',
      ).writeAsBytes(img.encodePng(picture));
      final scanner = PageScanner(null, root);
      final first = await scanner.createPdf([ScanPage(original.path)]);
      final restored = ScanPage.fromJson(first.pages.single.toJson()).rotated();
      expect(restored.isCompressed, isTrue);
      final second = await scanner.createPdf([restored]);
      expect(
        await File(second.pages.single.path).readAsBytes(),
        await File(first.pages.single.path).readAsBytes(),
      );
      expect(second.pages.single.quarterTurns, 1);
      expect(ScanPage.fromJson({'path': original.path}).isCompressed, isFalse);
    },
  );
  test(
    'Corrupt later page leaves no partial PDF or copied draft pages',
    () async {
      final original = await File(
        '${root.path}/source.png',
      ).writeAsBytes(img.encodePng(img.Image(width: 20, height: 30)));
      final bad = await File('${root.path}/bad.png').writeAsBytes([0, 1, 2]);
      await expectLater(
        PageScanner([original.path, bad.path], root).scan(),
        throwsException,
      );
      expect(await root.list().where((e) => e is Directory).toList(), isEmpty);
      expect(await original.exists(), isTrue);
      expect(await bad.exists(), isTrue);
    },
  );
  test('Cancellation and empty capture do not generate a PDF', () async {
    for (final pages in [null, <String>[]]) {
      final scanner = PageScanner(pages, root);
      expect(await scanner.scan(), isNull);
      expect(scanner.directories, 0);
    }
    expect(await root.list().toList(), isEmpty);
  });
  test('Draft cleanup removes only an owned scan folder', () async {
    final draft = await Directory(
      '${root.path}/scan_drafts/scan-owned',
    ).create(recursive: true);
    final pdf = await File('${draft.path}/scan.pdf').writeAsBytes([1]);
    await File('${draft.path}/page-0.jpg').writeAsBytes([2]);
    final archive = await Directory(
      '${root.path}/archive/scan-archive',
    ).create(recursive: true);
    final saved = await File('${archive.path}/saved.pdf').writeAsBytes([1]);
    final unrelated =
        await Directory('${root.path}/scan_drafts/other').create();
    final other = await File('${unrelated.path}/other.pdf').writeAsBytes([1]);
    await DocumentScanService.releaseDraft(saved.path, supportDirectory: root);
    await DocumentScanService.releaseDraft(other.path, supportDirectory: root);
    expect(await saved.exists(), isTrue);
    expect(await other.exists(), isTrue);
    await DocumentScanService.releaseDraft(pdf.path, supportDirectory: root);
    expect(await draft.exists(), isFalse);
    expect(await saved.exists(), isTrue);
  });
  test(
    'Missing scan page fails instead of silently creating an incomplete PDF',
    () async {
      await expectLater(
        PageScanner(['${root.path}/missing.png'], root).scan(),
        throwsStateError,
      );
      expect(await root.list().toList(), isEmpty);
    },
  );
}
