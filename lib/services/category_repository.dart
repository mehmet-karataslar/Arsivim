import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/kategori_modeli.dart';
import '../models/category_overview.dart';
import 'category_preferences.dart';
import 'veritabani_servisi.dart';

class CategoryRepository {
  CategoryRepository({Future<Database> Function()? database})
    : _database = database ?? (() => VeriTabaniServisi().database);
  final Future<Database> Function() _database;
  Future<CategoryOverview> read() async {
    final db = await _database();
    // Tek toplulaştırma: her kategori için ayrı belge sorgusu yapılmaz.
    final rows = await db.rawQuery(
      '''SELECT k.*, COALESCE(b.total,0) AS belge_sayisi, b.updated AS document_updated
      FROM kategoriler k LEFT JOIN (
        SELECT kategori_id,COUNT(*) AS total,MAX(guncelleme_tarihi) AS updated FROM belgeler WHERE aktif=1 GROUP BY kategori_id
      ) b ON b.kategori_id=k.id WHERE k.aktif=1 ORDER BY k.kategori_adi''',
    );
    final prefs = await CategoryPreferences.read();
    final entries = <CategoryEntry>[];
    final events = <CategoryEvent>[];
    for (final row in rows) {
      final category = KategoriModeli.fromMap(row);
      final metadata = prefs['${category.id}'] as Map? ?? {};
      final edited = DateTime.tryParse(metadata['edited'] as String? ?? '');
      final documentUpdated = DateTime.tryParse(
        row['document_updated'] as String? ?? '',
      );
      var updated = category.olusturmaTarihi;
      for (final time in [edited, documentUpdated]) {
        if (time != null && time.isAfter(updated)) updated = time;
      }
      final group =
          CategoryGroup.values
              .where((g) => g.name == metadata['group'])
              .firstOrNull ??
          CategoryPreferences.defaultGroup(category.kategoriAdi);
      entries.add(
        CategoryEntry(
          category: category,
          updated: updated,
          group: group,
          favorite: metadata['favorite'] == true,
        ),
      );
      events.add(
        CategoryEvent(
          category,
          'kategorisi oluşturuldu',
          category.olusturmaTarihi,
        ),
      );
      if (edited != null) {
        events.add(CategoryEvent(category, 'kategorisi güncellendi', edited));
      }
      if (documentUpdated != null) {
        events.add(
          CategoryEvent(
            category,
            'kategorisinde belge güncellendi',
            documentUpdated,
          ),
        );
      }
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    return CategoryOverview(entries, events.take(50).toList());
  }

  Future<void> favorite(CategoryEntry entry) =>
      CategoryPreferences.update(entry.category.id!, favorite: !entry.favorite);
  Future<void> save(KategoriModeli category, CategoryGroup group) async {
    final db = await _database();
    final editing = category.id != null;
    final map = category.toMap()..remove('belge_sayisi');
    if (editing) {
      await db.update(
        'kategoriler',
        map,
        where: 'id=?',
        whereArgs: [category.id],
      );
    } else {
      map.remove('id');
      category.id = await db.insert('kategoriler', map);
    }
    await CategoryPreferences.update(
      category.id!,
      group: group,
      edited: editing ? DateTime.now() : null,
    );
  }
}
