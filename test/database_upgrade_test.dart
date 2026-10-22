import 'dart:convert';
import 'dart:io';

import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/services/database_upgrade_guard.dart';
import 'package:arsiv_uygulamasi/services/veritabani_servisi.dart';
import 'package:arsiv_uygulamasi/utils/sabitler.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late String dbPath;
  late VeriTabaniServisi service;
  const date = '2025-07-19T12:34:56.000';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('arsiv-upgrade-test-');
    dbPath = p.join(root.path, 'arsiv.db');
    service = VeriTabaniServisi.test(
      databasePath: dbPath,
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async {
    await service.kapat();
    await root.delete(recursive: true);
  });

  Future<Database> legacy({int version = 10, bool preAccount = false}) async {
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    var sql = await File('test/fixtures/legacy_v10.sql').readAsString();
    if (preAccount) {
      sql = sql
          .replaceAll('kullanici_adi TEXT UNIQUE,', '')
          .replaceAll('sifre TEXT,', '')
          .replaceAll("kullanici_tipi TEXT DEFAULT 'NORMAL',", '')
          .replaceAll('profil_fotografi TEXT,', '');
    }
    for (final statement in sql.split(';')) {
      if (statement.trim().isNotEmpty) await db.execute(statement);
    }
    await db.setVersion(version);
    for (final id in [3, 7]) {
      await db.insert('kisiler', {
        'id': id,
        'ad': 'Eski',
        'soyad': 'Kişi $id',
        if (!preAccount) 'kullanici_adi': 'kisi$id',
        if (!preAccount)
          'sifre': sha256.convert(utf8.encode('parola$id')).toString(),
        'olusturma_tarihi': date,
        'guncelleme_tarihi': date,
        'aktif': id == 3 ? 1 : 0,
      });
    }
    await db.insert('kategoriler', {
      'id': 8,
      'kategori_adi': 'Eski Kategori',
      'olusturma_tarihi': date,
    });
    final file = await File(
      p.join(root.path, 'belge.txt'),
    ).writeAsString('Eski içerik');
    for (final id in [11, 15]) {
      await db.insert('belgeler', {
        'id': id,
        'dosya_adi': 'belge.txt',
        'orijinal_dosya_adi': 'belge.txt',
        'dosya_yolu': file.path,
        'dosya_boyutu': await file.length(),
        'dosya_tipi': 'txt',
        'dosya_hash':
            id == 11
                ? sha256.convert(await file.readAsBytes()).toString()
                : 'inactive-hash',
        'kisi_id': 3,
        'kategori_id': 8,
        'baslik': 'Korunacak başlık',
        'olusturma_tarihi': date,
        'guncelleme_tarihi': date,
        'aktif': id == 11 ? 1 : 0,
      });
    }
    return db;
  }

  test(
    'Archived v10 schema preserves every old value, IDs, files and inactive rows',
    () async {
      final old = await legacy();
      await old.rawQuery('PRAGMA journal_mode=WAL');
      await old.update('belgeler', {
        'baslik': 'Son WAL kaydı',
      }, where: 'id = 11');
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in ['kisiler', 'kategoriler', 'belgeler']) {
        before[table] = await old.query(table, orderBy: 'id');
      }
      await old.close();
      final db = await service.database;
      expect(await db.getVersion(), Sabitler.VERITABANI_VERSIYONU);
      for (final entry in before.entries) {
        final rows = await db.query(
          entry.key,
          columns: entry.value.first.keys.toList(),
          orderBy: 'id',
        );
        expect(rows, entry.value);
      }
      final model = BelgeModeli.fromMap(
        (await db.query('belgeler', where: 'id = 11')).single,
      );
      expect(model.kisiId, 3);
      expect(model.kategoriId, 8);
      expect(await File(model.dosyaYolu).readAsString(), 'Eski içerik');
      final manifests =
          await Directory(p.join(root.path, 'Yedekler'))
              .list(recursive: true)
              .where((f) => p.basename(f.path) == 'dogrulama.json')
              .toList();
      expect(manifests, hasLength(1));
      final manifest = jsonDecode(
        await File(manifests.single.path).readAsString(),
      );
      final snapshot = File(
        p.join(p.dirname(manifests.single.path), 'arsiv.db'),
      );
      expect(
        manifest['sha256'],
        sha256.convert(await snapshot.readAsBytes()).toString(),
      );
      final backup = await databaseFactoryFfi.openDatabase(snapshot.path);
      expect(await backup.getVersion(), 10);
      expect(await backup.query('belgeler', orderBy: 'id'), before['belgeler']);
      await backup.close();
      await service.kapat();
      await service.database;
      expect(await Directory(p.join(root.path, 'Yedekler')).list().length, 1);
    },
  );

  test(
    'Pre-account schema adds username without illegal ADD COLUMN UNIQUE',
    () async {
      final db = await legacy(version: 5, preAccount: true);
      await db.close();
      final upgraded = await service.database;
      final person = (await upgraded.query('kisiler', where: 'id = 3')).single;
      expect(person['kullanici_adi'], isNull);
      expect(person['sifre'], isNull);
      expect(person['ad'], 'Eski');
      expect(
        person.keys,
        containsAll(['eposta', 'telefon', 'adres', 'profil_fotografi']),
      );
    },
  );

  test(
    'Failed DDL rolls back columns and version; independent backup survives',
    () async {
      final db = await legacy();
      await db.execute('CREATE TABLE idx_belgeler_hash (id INTEGER)');
      final before = await db.query('belgeler');
      await db.close();
      await expectLater(service.database, throwsA(isA<DatabaseException>()));
      final original = await databaseFactoryFfi.openDatabase(dbPath);
      expect(await original.getVersion(), 10);
      expect(await original.query('belgeler'), before);
      expect(
        (await original.rawQuery(
          'PRAGMA table_info(belgeler)',
        )).map((c) => c['name']),
        isNot(contains('kisi_ids')),
      );
      await original.close();
      expect(await Directory(p.join(root.path, 'Yedekler')).list().length, 1);
    },
  );

  test('Backup failure prevents any schema change', () async {
    final db = await legacy();
    await db.close();
    await File(p.join(root.path, 'Yedekler')).writeAsString('not a directory');
    await expectLater(service.database, throwsA(isA<FileSystemException>()));
    final original = await databaseFactoryFfi.openDatabase(dbPath);
    expect(await original.getVersion(), 10);
    await original.close();
  });

  test('A missing core table never becomes a new empty table', () async {
    final db = await legacy();
    await db.execute('DROP TABLE belgeler');
    await db.close();
    await expectLater(service.database, throwsA(isA<StateError>()));
    final original = await databaseFactoryFfi.openDatabase(dbPath);
    expect(await original.getVersion(), 10);
    expect(
      await original.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'belgeler'",
      ),
      isEmpty,
    );
    await original.close();
  });

  test('A newer archive is rejected without a downgrade or reset', () async {
    final db = await legacy(version: Sabitler.VERITABANI_VERSIYONU + 1);
    await db.close();
    final before = await File(dbPath).readAsBytes();
    await expectLater(service.database, throwsA(isA<StateError>()));
    expect(await File(dbPath).readAsBytes(), before);
  });

  test(
    'Integrity guard detects changed content even when record counts match',
    () async {
      final db = await legacy();
      await expectLater(
        db.transaction((tx) async {
          final original = await DatabaseUpgradeGuard.capture(tx);
          await tx.update('belgeler', {'baslik': 'lost original value'});
          await DatabaseUpgradeGuard.verifyPreserved(tx, original);
        }),
        throwsA(isA<StateError>()),
      );
      expect((await db.query('belgeler')).first['baslik'], 'Korunacak başlık');
      await db.close();
    },
  );

  test('Fresh installation creates complete current schema', () async {
    final db = await service.database;
    expect(await db.getVersion(), Sabitler.VERITABANI_VERSIYONU);
    expect(await db.query('belgeler'), isEmpty);
    expect(await db.query('kategoriler'), isNotEmpty);
  });
}
