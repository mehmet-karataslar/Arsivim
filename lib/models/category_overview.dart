import 'kategori_modeli.dart';

enum CategoryGroup { general, personal, work, official }

extension CategoryGroupLabel on CategoryGroup {
  String get label => switch (this) {
    CategoryGroup.general => 'Genel',
    CategoryGroup.personal => 'Kişisel',
    CategoryGroup.work => 'İş',
    CategoryGroup.official => 'Resmi',
  };
}

enum CategorySort { updated, name, mostUsed, newest }

enum CategoryFilter {
  all,
  active,
  favorites,
  recent,
  mostUsed,
  personal,
  work,
  official,
}

class CategoryEntry {
  const CategoryEntry({
    required this.category,
    required this.updated,
    required this.group,
    this.favorite = false,
  });
  final KategoriModeli category;
  final DateTime updated;
  final CategoryGroup group;
  final bool favorite;
  int get count => category.belgeSayisi ?? 0;
}

class CategoryEvent {
  const CategoryEvent(this.category, this.label, this.time);
  final KategoriModeli category;
  final String label;
  final DateTime time;
}

class CategoryOverview {
  const CategoryOverview(this.entries, this.events);
  final List<CategoryEntry> entries;
  final List<CategoryEvent> events;
  int get documents => entries.fold(0, (count, item) => count + item.count);
  CategoryEntry? get busiest =>
      entries.isEmpty
          ? null
          : (entries.toList()..sort((a, b) => b.count.compareTo(a.count)))
              .first;
  CategoryEntry? get latest =>
      entries.isEmpty
          ? null
          : (entries.toList()..sort((a, b) => b.updated.compareTo(a.updated)))
              .first;
}
