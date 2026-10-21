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
    return '($value IN (SELECT value FROM json_each(COALESCE($prefix${kind}_ids, json_array($prefix${kind}_id)))))';
  }
}
