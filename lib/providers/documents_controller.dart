import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ana_sayfa_ozeti.dart';
import '../models/document_filters.dart';
import '../services/document_repository.dart';

/// Arama geciktirilir, eski sorgu sonuçları elenir ve liste 25'lik sayfalarla alınır.
class DocumentsController extends ChangeNotifier {
  DocumentsController(this.repository, this.filters);
  final DocumentRepository repository;
  DocumentFilters filters;
  DocumentOverview? overview;
  List<SonBelgeOzeti> documents = [];
  int total = 0;
  bool loading = false, loadingMore = false, _disposed = false;
  String? error;
  int _generation = 0;
  Timer? _debounce;
  bool get hasMore => documents.length < total;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool stats = true}) async {
    _debounce?.cancel();
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    _notify();
    try {
      final nextOverview = stats ? await repository.overview() : overview;
      if (_disposed || generation != _generation) return;
      final page = await repository.fetch(
        filters,
        sharedIds: nextOverview?.sharedIds ?? [],
      );
      if (_disposed || generation != _generation) return;
      overview = nextOverview;
      documents = page.documents;
      total = page.total;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = 'Belgeler yüklenemedi. Yeniden deneyebilirsiniz.';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void apply(DocumentFilters value) {
    filters = value;
    documents = [];
    total = 0;
    refresh(stats: overview == null);
  }

  void search(String query) {
    _debounce?.cancel();
    // Kullanıcı yazarken önceki isteği geçersiz kıl.
    ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    filters = filters.copyWith(query: query);
    _notify();
    _debounce = Timer(const Duration(milliseconds: 280), () => apply(filters));
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final page = await repository.fetch(
        filters,
        offset: documents.length,
        sharedIds: overview?.sharedIds ?? [],
      );
      if (_disposed || generation != _generation) return;
      documents = [...documents, ...page.documents];
      total = page.total;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Diğer belgeler yüklenemedi. Tekrar deneyin.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _debounce?.cancel();
    super.dispose();
  }
}
