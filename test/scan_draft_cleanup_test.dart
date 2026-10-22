import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/scan_page.dart';
import 'package:arsiv_uygulamasi/providers/document_editor_controller.dart';
import 'package:arsiv_uygulamasi/services/document_editor_repository.dart';
import 'package:arsiv_uygulamasi/services/document_scan_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class CleanupRepository extends DocumentEditorRepository {
  final events = <String>[];
  bool failImport = false, failDraft = false, failCleanup = false;
  @override
  Future<void> import(
    PlatformFile source,
    BelgeModeli Function(BelgeModeli) edit,
  ) async {
    if (failImport && source.name == 'second.pdf') throw StateError('import');
    events.add('import:${source.path}');
  }

  @override
  Future<void> deleteDraft(int? id) async {
    if (failDraft) throw StateError('draft');
    events.add('deleteDraft');
  }

  @override
  Future<void> saveDraft(int? id, Map<String, dynamic> data) async {
    if (failDraft) throw StateError('draft');
    events.add('saveDraft');
  }

  @override
  Future<void> releaseScanDraft(String pdfPath) async {
    events.add('release:$pdfPath');
    if (failCleanup) throw StateError('cleanup');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DocumentEditorController controller(CleanupRepository repository) {
    final c = DocumentEditorController(repository: repository);
    c.title.text = 'Tarama';
    c.people.add(1);
    for (final name in ['first', 'second']) {
      c.addScan(
        ScannedPdf(
          PlatformFile(name: '$name.pdf', path: '/draft/$name.pdf', size: 100),
          1,
          pages: [ScanPage('/draft/$name.jpg', isCompressed: true)],
        ),
      );
    }
    addTearDown(c.dispose);
    return c;
  }

  test(
    'Committed scans are cleaned only after saved draft references are gone',
    () async {
      final repo = CleanupRepository();
      expect(await controller(repo).save(), isTrue);
      expect(repo.events, [
        'import:/draft/first.pdf',
        'import:/draft/second.pdf',
        'deleteDraft',
        'release:/draft/first.pdf',
        'release:/draft/second.pdf',
      ]);
    },
  );
  test(
    'Partial import retains failed pages and cleans only after persisting retry draft',
    () async {
      final repo = CleanupRepository()..failImport = true;
      final c = controller(repo);
      expect(await c.save(), isFalse);
      expect(repo.events, [
        'import:/draft/first.pdf',
        'saveDraft',
        'release:/draft/first.pdf',
      ]);
      expect(c.scanPages.keys, ['/draft/second.pdf']);
    },
  );
  test(
    'Failed draft writes or deletion keep referenced files intact',
    () async {
      for (final partial in [false, true]) {
        final repo =
            CleanupRepository()
              ..failDraft = true
              ..failImport = partial;
        await controller(repo).save();
        expect(repo.events.where((e) => e.startsWith('release:')), isEmpty);
      }
    },
  );
  test(
    'Cleanup failure does not turn a saved archive document into a retry',
    () async {
      final repo = CleanupRepository()..failCleanup = true;
      final c = controller(repo);
      expect(await c.save(), isTrue);
      expect(c.files, isEmpty);
      expect(c.message, contains('temizlenemedi'));
    },
  );
  test(
    'Replaced and removed scans survive until the new draft is persisted',
    () async {
      final repo = CleanupRepository();
      final c = controller(repo);
      c.addScan(
        ScannedPdf(
          PlatformFile(
            name: 'revised.pdf',
            path: '/draft/revised.pdf',
            size: 100,
          ),
          1,
          pages: [ScanPage('/draft/revised.jpg', isCompressed: true)],
        ),
        replacing: '/draft/first.pdf',
      );
      c.removeFile(c.files.last);
      expect(repo.events, isEmpty);
      repo.failDraft = true;
      await c.saveDraft();
      expect(repo.events, isEmpty);
      repo.failDraft = false;
      await c.saveDraft();
      expect(repo.events, [
        'saveDraft',
        'release:/draft/first.pdf',
        'release:/draft/second.pdf',
      ]);
      expect(c.scanPages.keys, ['/draft/revised.pdf']);
    },
  );
}
