import 'package:flutter/foundation.dart';
import '../models/scan_page.dart';
import '../services/document_scan_service.dart';

class ScanReviewController extends ChangeNotifier {
  ScanReviewController(List<ScanPage> initial, this.scanner)
    : pages = [...initial];
  final DocumentScanService scanner;
  final List<ScanPage> pages;
  int selected = 0;
  bool busy = false, _disposed = false;
  String? error;
  (int, ScanPage)? _removed;
  bool get canUndo => _removed != null && !busy;
  ScanPage? get current => pages.isEmpty ? null : pages[selected];
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void select(int index) {
    if (!busy) {
      selected = index;
      _emit();
    }
  }

  void rotate() {
    if (busy || pages.isEmpty) return;
    pages[selected] = pages[selected].rotated();
    _emit();
  }

  void move(int direction) {
    final target = selected + direction;
    if (busy || target < 0 || target >= pages.length) return;
    pages.insert(target, pages.removeAt(selected));
    selected = target;
    _emit();
  }

  void remove() {
    if (busy || pages.isEmpty) return;
    _removed = (selected, pages.removeAt(selected));
    selected = pages.isEmpty ? 0 : selected.clamp(0, pages.length - 1);
    _emit();
  }

  void undo() {
    if (!canUndo) return;
    final (index, page) = _removed!;
    selected = index.clamp(0, pages.length);
    pages.insert(selected, page);
    _removed = null;
    _emit();
  }

  Future<void> addPages() async {
    if (busy || !scanner.isSupported) return;
    busy = true;
    error = null;
    _emit();
    try {
      final result = await scanner.capturePages();
      if (result != null && result.isNotEmpty) {
        selected = pages.length;
        pages.addAll(result.map(ScanPage.new));
      }
    } catch (_) {
      error = 'Yeni sayfalar alınamadı. Mevcut sayfalarınız korunuyor.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<ScannedPdf?> finish(String name) async {
    if (busy || pages.isEmpty) return null;
    if (name.trim().isEmpty) {
      error = 'PDF için bir ad girin.';
      _emit();
      return null;
    }
    busy = true;
    error = null;
    _emit();
    try {
      return await scanner.createPdf(List.of(pages), name: name);
    } catch (_) {
      error =
          'PDF oluşturulamadı. Sayfalarınız burada; yeniden deneyebilirsiniz.';
      return null;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
