import 'package:flutter/foundation.dart';
import '../models/category_overview.dart';
import '../models/kategori_modeli.dart';
import '../services/category_repository.dart';

class CategoriesController extends ChangeNotifier {
  CategoriesController(this.repository);
  final CategoryRepository repository;
  CategoryOverview? overview;
  bool loading = false, busy = false, _disposed = false;
  String? error;
  String query = '';
  CategoryFilter filter = CategoryFilter.all;
  CategorySort sort = CategorySort.updated;
  Future<void>? _pending;
  List<CategoryEntry> visible = [];
  Set<int?> _mostUsed = {};
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() =>
      _pending ??= _load().whenComplete(() => _pending = null);
  Future<void> _load() async {
    loading = true;
    error = null;
    _notify();
    try {
      overview = await repository.read();
      final ranked =
          overview!.entries.where((entry) => entry.count > 0).toList()
            ..sort((a, b) => b.count.compareTo(a.count));
      _mostUsed = ranked.take(3).map((entry) => entry.category.id).toSet();
      _rebuild();
    } catch (_) {
      error = 'Kategoriler yüklenemedi. Yeniden deneyebilirsiniz.';
    } finally {
      loading = false;
      _notify();
    }
  }

  bool matches(CategoryEntry item, CategoryFilter selected) {
    return switch (selected) {
      CategoryFilter.all => true,
      CategoryFilter.active => item.category.aktif,
      CategoryFilter.favorites => item.favorite,
      CategoryFilter.recent => item.category.olusturmaTarihi.isAfter(
        DateTime.now().subtract(const Duration(days: 7)),
      ),
      CategoryFilter.mostUsed => _mostUsed.contains(item.category.id),
      CategoryFilter.personal => item.group == CategoryGroup.personal,
      CategoryFilter.work => item.group == CategoryGroup.work,
      CategoryFilter.official => item.group == CategoryGroup.official,
    };
  }

  int count(CategoryFilter selected) =>
      overview?.entries.where((e) => matches(e, selected)).length ?? 0;
  void search(String value) {
    query = value;
    _rebuild();
    _notify();
  }

  void select(CategoryFilter value) {
    filter = value;
    _rebuild();
    _notify();
  }

  void order(CategorySort value) {
    sort = value;
    _rebuild();
    _notify();
  }

  void _rebuild() {
    final normalized =
        query.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
    visible =
        (overview?.entries ?? <CategoryEntry>[])
            .where(
              (entry) =>
                  matches(entry, filter) &&
                  '${entry.category.kategoriAdi} ${entry.category.aciklama ?? ''}'
                      .replaceAll('İ', 'i')
                      .replaceAll('I', 'ı')
                      .toLowerCase()
                      .contains(normalized),
            )
            .toList();
    visible.sort(
      (a, b) => switch (sort) {
        CategorySort.updated => b.updated.compareTo(a.updated),
        CategorySort.name => a.category.kategoriAdi.toLowerCase().compareTo(
          b.category.kategoriAdi.toLowerCase(),
        ),
        CategorySort.mostUsed => b.count.compareTo(a.count),
        CategorySort.newest => b.category.olusturmaTarihi.compareTo(
          a.category.olusturmaTarihi,
        ),
      },
    );
  }

  Future<void> favorite(CategoryEntry entry) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _pending;
      await repository.favorite(entry);
      await refresh();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> save(KategoriModeli category, CategoryGroup group) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _pending;
      await repository.save(category, group);
      await refresh();
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
