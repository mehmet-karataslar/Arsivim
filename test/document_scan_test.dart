import 'dart:convert';
import 'dart:io';
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
    return output;
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
    expect(await root.list().where((f) => f.path.endsWith('.pdf')).length, 1);
  });
  test('Cancellation and empty capture do not generate a PDF', () async {
    for (final pages in [null, <String>[]]) {
      final scanner = PageScanner(pages, root);
      expect(await scanner.scan(), isNull);
      expect(scanner.directories, 0);
    }
    expect(await root.list().toList(), isEmpty);
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
