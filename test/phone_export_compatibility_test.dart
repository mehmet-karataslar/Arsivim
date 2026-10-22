import 'dart:convert';
import 'dart:io';

import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/services/veritabani_servisi.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Opt-in rehearsal on already exported records. This does not claim to recover
// the original SQLite database, category history, sessions or deleted records.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const supplied = String.fromEnvironment('PHONE_EXPORT_DIRECTORY');

  test(
    'Recovered phone records and files work in an isolated current database',
    () async {
      final root = await Directory(supplied).resolveSymbolicLinks();
      final allowed =
          await Directory('artifacts/upgrade-audit').resolveSymbolicLinks();
      expect(p.isWithin(allowed, root), true);
      Future<List<Map<String, dynamic>>> rows(String file, String key) async {
        final data =
            jsonDecode(await File(p.join(root, file)).readAsString())
                as Map<String, dynamic>;
        expect(data['success'], true);
        return (data[key] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      final people = await rows('people.json', 'kisiler');
      final documents = await rows('documents.json', 'belgeler');
      expect(people.length, 1);
      expect(documents.length, 2);
      final filesByHash = <String, File>{};
      await for (final entry in Directory(p.join(root, 'files')).list()) {
        if (entry is File) {
          final digest = await sha256.bind(entry.openRead()).first;
          filesByHash[digest.toString()] = entry;
        }
      }

      final tempRoot = Directory('.test_tmp');
      await tempRoot.create(recursive: true);
      final temp = await tempRoot.createTemp('phone-record-rehearsal-');
      final service = VeriTabaniServisi.test(
        databasePath: p.join(temp.path, 'rehearsal.db'),
        factory: databaseFactoryFfi,
      );
      final db = await service.database;
      try {
        // These two category associations were also read from the actual phone UI.
        // Other category details were not exported and must not be inferred here.
        for (final entry in {5: 'Arşiv', 15: 'Seyahat'}.entries) {
          final category = await db.query(
            'kategoriler',
            where: 'id = ?',
            whereArgs: [entry.key],
          );
          expect(category.single['kategori_adi'] == entry.value, true);
        }
        await db.transaction((txn) async {
          for (final row in people) {
            final current = KisiModeli.fromMap(row).toMap();
            for (final key in current.keys) {
              // Compare booleans to keep private values out of failure output.
              expect(
                current[key] == row[key],
                true,
                reason: 'Person field must survive: $key',
              );
            }
            await txn.insert('kisiler', current);
          }
          for (final row in documents) {
            final model = BelgeModeli.fromMap(row);
            final file = filesByHash[model.dosyaHash];
            expect(
              file != null,
              true,
              reason: 'Every exported record needs bytes',
            );
            expect(await file!.length(), model.dosyaBoyutu);
            final current = model.toMap();
            for (final key in row.keys) {
              if (current.containsKey(key) && key != 'etiketler') {
                expect(
                  current[key] == row[key],
                  true,
                  reason: 'Document field must survive: $key',
                );
              }
            }
            final oldTags = row['etiketler'];
            final expectedTags =
                oldTags == null || oldTags == ''
                    ? <dynamic>[]
                    : (oldTags as String).trimLeft().startsWith('[')
                    ? jsonDecode(oldTags)
                    : oldTags.split(',');
            expect(
              jsonEncode(model.etiketler) == jsonEncode(expectedTags),
              true,
            );
            await txn.insert(
              'belgeler',
              model.copyWith(dosyaYolu: file.absolute.path).toMap(),
            );
          }
        });
        expect((await service.kisileriGetir()).length, 1);
        final saved = await service.belgeleriGetir();
        expect(saved.length, 2);
        expect(
          (await service.kisiBelgeleriniGetir(
            people.single['id'] as int,
          )).length,
          2,
        );
        for (final document in saved) {
          final original = documents.singleWhere(
            (row) => row['id'] == document.id,
          );
          expect(document.kisiId == original['kisi_id'], true);
          expect(document.kategoriId == original['kategori_id'], true);
          final digest =
              await sha256.bind(File(document.dosyaYolu).openRead()).first;
          expect(digest.toString() == original['dosya_hash'], true);
        }
        expect(
          (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
          'ok',
        );
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await db.close();
        expect(
          p.isWithin(p.absolute(tempRoot.path), p.absolute(temp.path)),
          true,
        );
        await temp.delete(recursive: true);
      }
    },
    skip:
        supplied.isEmpty ? 'Supply an ignored phone export explicitly' : false,
  );
}
