import 'package:sqflite/sqflite.dart';

/// Additive migration; existing people and account credentials stay in place.
abstract final class PersonContactSchema {
  static Future<void> prepare(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(kisiler)');
    final names = columns.map((row) => row['name']).toSet();
    for (final field in ['eposta', 'telefon', 'adres']) {
      if (!names.contains(field)) {
        await db.execute('ALTER TABLE kisiler ADD COLUMN $field TEXT');
      }
    }
  }
}
