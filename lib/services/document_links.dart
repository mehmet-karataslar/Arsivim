import 'package:sqflite/sqflite.dart';

/// Legacy primary links remain readable. Additional links travel with the row,
/// including SQLite backups; readers use EXISTS so documents are never duplicated.
class DocumentLinks {
  static final _ready = Expando<Future<void>>();

  static Future<void> prepare(Database db) async {
    try {
      await (_ready[db] ??= _prepare(db));
    } catch (_) {
      _ready[db] = null;
      rethrow;
    }
  }

  static Future<void> _prepare(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(belgeler)');
    if (columns.isEmpty) return;
    for (final name in ['kisi_ids', 'kategori_ids']) {
      if (!columns.any((column) => column['name'] == name)) {
        await db.execute('ALTER TABLE belgeler ADD COLUMN $name TEXT');
      }
    }
  }

  static String contains(String kind, String value, [String alias = 'b']) {
    final prefix = alias.isEmpty ? '' : '$alias.';
    // These columns contain JSON arrays of integer IDs (BelgeModeli.toMap),
    // not arbitrary JSON. Match complete comma-delimited IDs so 1 cannot match
    // 11. Core SQLite functions work on Android engines without JSON1 too.
    final ids =
        "REPLACE(REPLACE(REPLACE(REPLACE("
        "COALESCE($prefix${kind}_ids, '[]'), ' ', ''), "
        "char(9), ''), char(10), ''), char(13), '')";
    // Keep the value expression in exactly one place: callers supply one bound
    // argument per predicate. It can also be a correlated person/category ID.
    return "EXISTS (SELECT 1 FROM (SELECT $value AS archive_link_id) "
        "WHERE archive_link_id = $prefix${kind}_id "
        "OR INSTR(',' || SUBSTR($ids, 2, LENGTH($ids) - 2) || ',', "
        "',' || CAST(archive_link_id AS TEXT) || ',') > 0)";
  }
}
