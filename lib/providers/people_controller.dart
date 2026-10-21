import 'package:flutter/foundation.dart';
import '../models/people_overview.dart';
import '../services/people_repository.dart';

class PeopleController extends ChangeNotifier {
  PeopleController(this.repository);
  final PeopleRepository repository;
  PeopleOverview? overview;
  PersonDetails? details;
  List<PersonSummary> visible = [];
  int? selectedId, categoryId;
  String query = '';
  PeopleSort sort = PeopleSort.name;
  PeopleDocumentFilter documentFilter = PeopleDocumentFilter.all;
  bool loading = false,
      detailLoading = false,
      _disposed = false,
      _initialized = false;
  String? error, detailError;
  Future<void>? _refresh;
  int _selectionGeneration = 0;

  PersonSummary? get selected {
    for (final person in overview?.people ?? <PersonSummary>[]) {
      if (person.person.id == selectedId) return person;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() =>
      _refresh ??= _load().whenComplete(() => _refresh = null);
  Future<void> _load() async {
    loading = true;
    error = null;
    _notify();
    try {
      overview = await repository.read();
      if (_disposed) return;
      if (categoryId != null &&
          !overview!.categories.any((c) => c.id == categoryId)) {
        categoryId = null;
      }
      _rebuild();
      final previousId = selectedId;
      if (!_initialized && visible.isNotEmpty) {
        selectedId = visible.first.person.id;
      }
      _initialized = true;
      if (selectedId != null && selected == null) close();
      if (selectedId != null) await select(selectedId!, force: true);
      if (previousId != selectedId) _notify();
    } catch (_) {
      error = 'Kişiler yüklenemedi. Yeniden deneyebilirsiniz.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> select(int id, {bool force = false}) async {
    if (!force && selectedId == id && (details != null || detailLoading)) {
      return;
    }
    selectedId = id;
    details = null;
    detailError = null;
    detailLoading = true;
    final generation = ++_selectionGeneration;
    _notify();
    try {
      final result = await repository.details(id);
      if (_disposed || generation != _selectionGeneration) return;
      details = result;
    } catch (_) {
      if (!_disposed && generation == _selectionGeneration) {
        detailError = 'Kişi ayrıntıları yüklenemedi.';
      }
    } finally {
      if (!_disposed && generation == _selectionGeneration) {
        detailLoading = false;
        _notify();
      }
    }
  }

  void close() {
    selectedId = null;
    details = null;
    detailError = null;
    detailLoading = false;
    _selectionGeneration++;
    _notify();
  }

  void search(String value) {
    query = value;
    _rebuild();
    _notify();
  }

  void filterCategory(int? value) {
    categoryId = value;
    _rebuild();
    _notify();
  }

  void filterDocuments(PeopleDocumentFilter value) {
    documentFilter = value;
    _rebuild();
    _notify();
  }

  void order(PeopleSort value) {
    sort = value;
    _rebuild();
    _notify();
  }

  static String normalize(String value) =>
      value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
  void _rebuild() {
    final search = normalize(query);
    visible =
        (overview?.people ?? <PersonSummary>[])
            .where(
              (entry) =>
                  (categoryId == null ||
                      entry.categories.any((c) => c.id == categoryId)) &&
                  (documentFilter == PeopleDocumentFilter.all ||
                      (documentFilter == PeopleDocumentFilter.withDocuments
                          ? entry.documentCount > 0
                          : entry.documentCount == 0)) &&
                  normalize(
                    '${entry.person.tamAd} ${entry.person.kullaniciAdi ?? ''} ${entry.categories.map((c) => c.kategoriAdi).join(' ')}',
                  ).contains(search),
            )
            .toList()
          ..sort(
            (a, b) => switch (sort) {
              PeopleSort.name => normalize(
                a.person.tamAd,
              ).compareTo(normalize(b.person.tamAd)),
              PeopleSort.updated => b.updated.compareTo(a.updated),
              PeopleSort.documents => b.documentCount.compareTo(
                a.documentCount,
              ),
              PeopleSort.newest => b.person.olusturmaTarihi.compareTo(
                a.person.olusturmaTarihi,
              ),
            },
          );
  }

  @override
  void dispose() {
    _disposed = true;
    _selectionGeneration++;
    super.dispose();
  }
}
