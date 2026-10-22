import 'sqlite_snapshot.dart';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// A snapshot is taken before sqflite starts its schema transaction. A failed
/// migration must throw so SQLite rolls back both the schema and user_version.
abstract final class DatabaseUpgradeGuard {
  static Future<void> checkIntegrity(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA integrity_check');
    if (rows.length != 1 || rows.single.values.single != 'ok') {
      throw StateError(
        'Veritabani butunluk kontrolu basarisiz. Arsiv korunuyor.',
      );
    }
  }

  static Future<void> beforeOpen(
    Database db,
    DatabaseFactory factory,
    int targetVersion,
  ) async {
    final version = await db.getVersion();
    if (version > targetVersion) {
      throw StateError(
        'Bu arsiv daha yeni bir uygulamayla kullanilmis (sema $version). '
        'Guncel uygulamayi acin; veriler degistirilmedi.',
      );
    }
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    if (version == 0 && tables.isNotEmpty) {
      throw StateError('Surumu belirsiz veritabani otomatik degistirilemez.');
    }
    if (version == 0 || version == targetVersion) return;
    await checkIntegrity(db);
    final parent = await Directory(
      p.join(p.dirname(db.path), 'Yedekler'),
    ).create(recursive: true);
    final folder = await parent.createTemp('sema-$version-$targetVersion-');
    final snapshot = File(p.join(folder.path, 'arsiv.db'));
    // VACUUM includes committed WAL data. Copying just arsiv.db would not.
    await SqliteSnapshot.create(db, snapshot.path, factory: factory);
    final copy = await factory.openDatabase(
      snapshot.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      await checkIntegrity(copy);
      if (await copy.getVersion() != version) {
        throw StateError('Gecis yedeginin sema surumu dogrulanamadi.');
      }
    } finally {
      await copy.close();
    }
    await File(p.join(folder.path, 'dogrulama.json')).writeAsString(
      jsonEncode({
        'kaynak': db.path,
        'eski_sema': version,
        'hedef_sema': targetVersion,
        'zaman': DateTime.now().toUtc().toIso8601String(),
        'boyut': await snapshot.length(),
        'sha256': (await sha256.bind(snapshot.openRead()).first).toString(),
        'kapsam':
            'SQLite; belge ve fotograf dosyalari mevcut konumlarinda korunur',
      }),
      flush: true,
    );
  }

  static String _quote(String name) => '"${name.replaceAll('"', '""')}"';

  /// Keep original columns and rows in connection-local temporary tables.
  /// Compare actual content, including inactive records, rather than only counts.
  static Future<Map<String, List<String>>> capture(DatabaseExecutor db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final result = <String, List<String>>{};
    for (final table in tables) {
      final name = table['name'] as String;
      final columns = await db.rawQuery('PRAGMA table_info(${_quote(name)})');
      result[name] = columns.map((r) => r['name'] as String).toList();
      await db.execute(
        'CREATE TEMP TABLE ${_quote('_upgrade_$name')} AS SELECT * FROM main.${_quote(name)}',
      );
    }
    return result;
  }

  static Future<void> verifyPreserved(
    DatabaseExecutor db,
    Map<String, List<String>> original,
  ) async {
    for (final entry in original.entries) {
      final columns = entry.value.map(_quote).join(', ');
      final before = 'temp.${_quote('_upgrade_${entry.key}')}';
      final after = 'main.${_quote(entry.key)}';
      final counts = await db.rawQuery(
        'SELECT (SELECT COUNT(*) FROM $before) = (SELECT COUNT(*) FROM $after) AS equal_count',
      );
      final missing = await db.rawQuery(
        'SELECT $columns, COUNT(*) FROM $before GROUP BY $columns EXCEPT SELECT $columns, COUNT(*) FROM $after GROUP BY $columns LIMIT 1',
      );
      final changed = await db.rawQuery(
        'SELECT $columns, COUNT(*) FROM $after GROUP BY $columns EXCEPT SELECT $columns, COUNT(*) FROM $before GROUP BY $columns LIMIT 1',
      );
      if (counts.single['equal_count'] != 1 ||
          missing.isNotEmpty ||
          changed.isNotEmpty) {
        throw StateError(
          '${entry.key} kayitlari degisti; sema gecisi geri alindi.',
        );
      }
      await db.execute('DROP TABLE $before');
    }
    await checkIntegrity(db);
  }
}
