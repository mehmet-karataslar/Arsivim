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

  /// Call only after importing the PDF and removing its saved draft reference.
  /// Never delete camera sources, imported archive files or arbitrary folders.
  static Future<void> releaseDraft(
    String pdfPath, {
    Directory? supportDirectory,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final root = Directory(paths.join(support.path, 'scan_drafts'));
    final folder = File(pdfPath).parent;
    if (!await root.exists() || !await folder.exists()) return;
    final realRoot = await root.resolveSymbolicLinks();
    final realFolder = await folder.resolveSymbolicLinks();
    if (!paths.equals(paths.dirname(realFolder), realRoot) ||
        !paths.basename(realFolder).startsWith('scan-') ||
        paths.extension(pdfPath).toLowerCase() != '.pdf') {
      return;
    }
    await Directory(realFolder).delete(recursive: true);
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
    try {
      final title =
          name == null || name.trim().isEmpty
              ? 'Tarama_${DateTime.now().millisecondsSinceEpoch}'
              : paths
                  .basename(name.trim())
                  .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
      final document = await DosyaServisi().tarananFotograflariPdfYap(
        pages.map((p) => p.path).toList(),
        '$title.pdf',
        quarterTurns: pages.map((p) => p.quarterTurns).toList(),
        compressedPages: pages.map((p) => p.isCompressed).toList(),
        pageCopiesDirectory: dir,
        outputDirectory: dir,
      );
      return ScannedPdf(
        PlatformFile(
          name: document.orijinalDosyaAdi,
          path: document.dosyaYolu,
          size: document.dosyaBoyutu,
        ),
        pages.length,
        pages: List.generate(
          pages.length,
          (i) => ScanPage(
            paths.join(dir.path, 'page-$i.jpg'),
            quarterTurns: pages[i].quarterTurns,
            isCompressed: true,
          ),
        ),
      );
    } catch (_) {
      // Only this attempt's private draft directory is removed. Originals stay
      // available in the review screen so the user can retry a failed page.
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
  }
}
