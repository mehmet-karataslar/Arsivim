import 'dart:io';

import 'package:sqflite/sqflite.dart';

/// Consistent SQLite snapshots, including Android SQLite versions before 3.27
/// which do not implement VACUUM INTO. Never copy a live .db without its WAL.
abstract final class SqliteSnapshot {
  static String _quote(String name) => '"${name.replaceAll('"', '""')}"';

  static Future<void> create(
    Database source,
    String destination, {
    DatabaseFactory? factory,
    bool forcePortable = false,
  }) async {
    if (await File(destination).exists()) {
      throw StateError('Yedek hedefi zaten var; uzerine yazilmadi.');
    }
    final version =
        (await source.rawQuery('SELECT sqlite_version()')).single.values.single
            as String;
    final parts = version.split('.').map(int.parse).toList();
    if (!forcePortable && (parts[0] > 3 || (parts[0] == 3 && parts[1] >= 27))) {
      await source.execute('VACUUM INTO ?', [destination]);
      return;
    }
    final target = await (factory ?? databaseFactory).openDatabase(
      destination,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      // A single read transaction sees the same committed rows for every table.
      await source.transaction((read) async {
        final schema = await read.rawQuery(
          "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type, name",
        );
        await target.transaction((write) async {
          for (final table in schema.where((r) => r['type'] == 'table')) {
            final sql = table['sql'] as String;
            if (sql.toUpperCase().contains('CREATE VIRTUAL TABLE')) {
              throw StateError(
                'Bu arsivin sanal tablolari icin yeni SQLite gerekli.',
              );
            }
            await write.execute(sql);
            final name = _quote(table['name'] as String);
            var offset = 0;
            while (true) {
              final rows = await read.rawQuery(
                'SELECT * FROM $name LIMIT 200 OFFSET ?',
                [offset],
              );
              if (rows.isEmpty) break;
              final batch = write.batch();
              for (final row in rows) {
                final columns = row.keys.map(_quote).join(',');
                final placeholders = List.filled(row.length, '?').join(',');
                batch.rawInsert(
                  'INSERT INTO $name ($columns) VALUES ($placeholders)',
                  row.values.toList(),
                );
              }
              await batch.commit(noResult: true);
              offset += rows.length;
            }
          }
          final hasSequence = await read.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='sqlite_sequence'",
          );
          if (hasSequence.isNotEmpty) {
            await write.delete('sqlite_sequence');
            for (final row in await read.query('sqlite_sequence')) {
              await write.insert('sqlite_sequence', row);
            }
          }
          // Install triggers only after rows are copied: they must not fire during backup.
          for (final object in schema.where((r) => r['type'] != 'table')) {
            await write.execute(object['sql'] as String);
          }
          final userVersion =
              (await read.rawQuery('PRAGMA user_version')).single.values.single
                  as int;
          await write.execute('PRAGMA user_version = $userVersion');
          final appId =
              (await read.rawQuery(
                    'PRAGMA application_id',
                  )).single.values.single
                  as int;
          await write.execute('PRAGMA application_id = $appId');
        });
      }, exclusive: false);
      final result = await target.rawQuery('PRAGMA integrity_check');
      if (result.length != 1 || result.single.values.single != 'ok') {
        throw StateError('Yedek butunluk kontrolu basarisiz.');
      }
    } finally {
      await target.close();
    }
  }
}
