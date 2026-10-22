import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arsiv_uygulamasi/services/document_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE belgeler(id INTEGER PRIMARY KEY, kisi_id INTEGER, kisi_ids TEXT, kategori_id INTEGER, kategori_ids TEXT, aktif INTEGER)',
    );
    await db.execute('CREATE TABLE kisiler(id INTEGER PRIMARY KEY)');
    for (final id in [1, 2, 11, 21, 101, 1001, 4294967297]) {
      await db.insert('kisiler', {'id': id});
    }
  });
  tearDown(() => db.close());

  test(
    'Whole ID matching preserves primary links and excludes numeric substrings',
    () async {
      await db.insert('belgeler', {
        'id': 1,
        'kisi_id': 2,
        'kisi_ids': '[11,101,1001,4294967297]',
        'aktif': 1,
      });
      for (final id in [1, 2, 11, 21, 101, 1001, 4294967297]) {
        final rows = await db.rawQuery(
          'SELECT id FROM belgeler b WHERE ${DocumentLinks.contains('kisi', '?')}',
          [id],
        );
        expect(
          rows.isNotEmpty,
          [2, 11, 101, 1001, 4294967297].contains(id),
          reason: 'ID $id',
        );
      }
    },
  );

  test(
    'Nullable, empty, pretty-printed and duplicate arrays do not duplicate counts',
    () async {
      for (final extra in [null, '[]', '[1,1,11]', ' [ 1,\n\t11,\r21 ] ']) {
        await db.delete('belgeler');
        await db.insert('belgeler', {'id': 1, 'kisi_id': 1, 'kisi_ids': extra});
        final rows = await db.rawQuery(
          'SELECT p.id, COUNT(b.id) AS n FROM kisiler p LEFT JOIN belgeler b ON ${DocumentLinks.contains('kisi', 'p.id')} GROUP BY p.id',
        );
        final expected = {
          1,
          ...((extra == null ? [] : jsonDecode(extra)) as List).cast<int>(),
        };
        for (final row in rows) {
          expect(
            row['n'],
            expected.contains(row['id']) ? 1 : 0,
            reason: '$extra / ${row['id']}',
          );
        }
      }
    },
  );

  test(
    'Two bound predicates and unaliased UPDATE touch only matching records',
    () async {
      await db.insert('belgeler', {
        'id': 1,
        'kisi_id': 1,
        'kisi_ids': '[11]',
        'kategori_id': 2,
        'kategori_ids': '[21]',
        'aktif': 1,
      });
      await db.insert('belgeler', {
        'id': 2,
        'kisi_ids': '[101]',
        'kategori_ids': '[21]',
        'aktif': 1,
      });
      final changed = await db.update(
        'belgeler',
        {'aktif': 0},
        where:
            '${DocumentLinks.contains('kisi', '?', '')} AND ${DocumentLinks.contains('kategori', '?', '')}',
        whereArgs: [11, 21],
      );
      expect(changed, 1);
      expect((await db.query('belgeler', where: 'id=2')).single['aktif'], 1);
    },
  );

  test(
    'Seeded integer-list cases agree with JSON1 oracle and preserve rows',
    () async {
      final random = Random(252);
      for (var id = 1; id <= 150; id++) {
        final ids = List.generate(
          random.nextInt(12),
          (_) => random.nextInt(25) + 1,
        );
        await db.insert('belgeler', {
          'id': id,
          'kisi_id': id.isEven ? random.nextInt(25) + 1 : null,
          'kisi_ids':
              id % 7 == 0
                  ? null
                  : (id % 3 == 0
                      ? const JsonEncoder.withIndent('  ').convert(ids)
                      : jsonEncode(ids)),
        });
      }
      final before = await db.query('belgeler', orderBy: 'id');
      for (var id = 1; id <= 30; id++) {
        final actual = await db.rawQuery(
          'SELECT id FROM belgeler b WHERE ${DocumentLinks.contains('kisi', '?')} ORDER BY id',
          [id],
        );
        final oracle = await db.rawQuery(
          "SELECT id FROM belgeler b WHERE ? IN (SELECT kisi_id UNION SELECT value FROM json_each(COALESCE(kisi_ids, '[]')) ) ORDER BY id",
          [id],
        );
        expect(actual, oracle, reason: 'ID $id');
      }
      expect(await db.query('belgeler', orderBy: 'id'), before);
    },
  );

  test(
    'Export real generated predicates for a SQLite engine without JSON1',
    () async {
      const exportPath = String.fromEnvironment('EXPORT_LINK_QUERIES');
      if (exportPath.isEmpty) return;
      await File(exportPath).writeAsString(
        jsonEncode({
          'bound':
              'SELECT id FROM belgeler b WHERE ${DocumentLinks.contains('kisi', '?')} ORDER BY id',
          'join':
              'SELECT p.id, COUNT(b.id) AS n FROM kisiler p LEFT JOIN belgeler b ON ${DocumentLinks.contains('kisi', 'p.id')} GROUP BY p.id ORDER BY p.id',
        }),
      );
    },
  );
}
