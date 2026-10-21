import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as paths;
import '../models/scan_page.dart';
import 'dosya_servisi.dart';

class ScannedPdf {
  const ScannedPdf(this.file, this.pageCount, {this.pages = const []});
  final PlatformFile file;
  final int pageCount;
  final List<ScanPage> pages;
}

/// Native scanner handles capture, page cropping and review; all returned pages
/// are converted, in their reviewed order, into one PDF for the editor.
class DocumentScanService {
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<Directory> createOutputDirectory() async {
    final support = await getApplicationSupportDirectory();
    final root = await Directory(
      paths.join(support.path, 'scan_drafts'),
    ).create(recursive: true);
    return root.createTemp('scan-');
  }

  Future<List<String>?> capturePages() => CunningDocumentScanner.getPictures(
    noOfPages: 100,
    isGalleryImportAllowed: false,
  );

  Future<ScannedPdf?> scan() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Fotoğrafla tarama Android ve iOS cihazlarda kullanılabilir.',
      );
    }
    final pictures = await capturePages();
    if (pictures == null || pictures.isEmpty) return null;
    return createPdf(pictures.map(ScanPage.new).toList());
  }

  Future<ScannedPdf> createPdf(List<ScanPage> pages, {String? name}) async {
    if (pages.isEmpty) throw StateError('PDF için en az bir sayfa gerekli.');
    for (final page in pages) {
      if (!await File(page.path).exists()) {
        throw StateError('Taranan sayfa bulunamadı.');
      }
    }
    final dir = await createOutputDirectory();
    final stored = <ScanPage>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final copy = await File(
        page.path,
      ).copy(paths.join(dir.path, 'page-$i${paths.extension(page.path)}'));
      stored.add(ScanPage(copy.path, quarterTurns: page.quarterTurns));
    }
    final title =
        name == null || name.trim().isEmpty
            ? 'Tarama_${DateTime.now().millisecondsSinceEpoch}'
            : paths.basenameWithoutExtension(name.trim());
    final document = await DosyaServisi().tarananFotograflariPdfYap(
      stored.map((p) => p.path).toList(),
      '$title.pdf',
      quarterTurns: stored.map((p) => p.quarterTurns).toList(),
      outputDirectory: dir,
    );
    return ScannedPdf(
      PlatformFile(
        name: document.orijinalDosyaAdi,
        path: document.dosyaYolu,
        size: document.dosyaBoyutu,
      ),
      stored.length,
      pages: stored,
    );
  }
}
