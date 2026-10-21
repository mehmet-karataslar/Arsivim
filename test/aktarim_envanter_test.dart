import 'dart:convert';
import 'dart:io';

import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/services/aktarim_envanter_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _database(String path) async {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE kisiler(
          id INTEGER PRIMARY KEY, ad TEXT, soyad TEXT, kullanici_adi TEXT UNIQUE,
          sifre TEXT, kullanici_tipi TEXT, profil_fotografi TEXT,
          olusturma_tarihi TEXT, guncelleme_tarihi TEXT, aktif INTEGER)''');
        await db.execute('''CREATE TABLE kategoriler(
          id INTEGER PRIMARY KEY, kategori_adi TEXT UNIQUE, renk_kodu TEXT,
          simge_kodu TEXT, aciklama TEXT, olusturma_tarihi TEXT,
          aktif INTEGER, belge_sayisi INTEGER)''');
        await db.execute('''CREATE TABLE belgeler(
          id INTEGER PRIMARY KEY, dosya_adi TEXT, orijinal_dosya_adi TEXT,
          dosya_yolu TEXT, dosya_boyutu INTEGER, dosya_tipi TEXT,
          dosya_hash TEXT UNIQUE, kisi_id INTEGER, kategori_id INTEGER,
          kisi_ids TEXT, kategori_ids TEXT, baslik TEXT, aciklama TEXT,
          etiketler TEXT, olusturma_tarihi TEXT, guncelleme_tarihi TEXT,
          son_erisim_tarihi TEXT, aktif INTEGER, senkron_durumu INTEGER)''');
      },
    ),
  );
}

List<int> _bytes(int id) => utf8.encode('document-$id');

Map<String, dynamic> _document(int id) =>
    BelgeModeli(
      id: id,
      dosyaAdi: 'document-$id.pdf',
      orijinalDosyaAdi: 'original-$id.pdf',
      dosyaYolu: 'nonexistent-$id.pdf',
      dosyaBoyutu: _bytes(id).length,
      dosyaTipi: 'pdf',
      dosyaHash: sha256.convert(_bytes(id)).toString(),
      baslik: 'Document $id',
      etiketler: ['a,b', 'c'],
      olusturmaTarihi: DateTime.utc(2020, 1, 2),
      guncellemeTarihi: DateTime.utc(2021, 1, 2),
    ).toMap();

Map<String, dynamic> _person(int id) => {
  'id': id,
  'ad': 'Ali $id',
  'soyad': 'Yilmaz',
  'kullanici_adi': 'ali$id',
  'sifre': 'NEVER-EXPOSE-THIS',
  'kullanici_tipi': 'ADMIN',
  'olusturma_tarihi': '2019-01-01T00:00:00Z',
  'guncelleme_tarihi': '2020-01-01T00:00:00Z',
  'aktif': 1,
};

Map<String, dynamic> _category(int id) => {
  'id': id,
  'kategori_adi': 'Category $id',
  'renk_kodu': '#123456',
  'simge_kodu': 'folder',
  'aciklama': 'Category description',
  'olusturma_tarihi': '2019-01-01T00:00:00Z',
  'aktif': 1,
  'belge_sayisi': 0,
};

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

List<Map<String, dynamic>> _items(Map<String, dynamic> page) =>
    (page['items'] as List).cast<Map<String, dynamic>>();

Future<List<Map<String, dynamic>>> _all(AktarimEnvanterServisi service) async {
  final items = <Map<String, dynamic>>[];
  int? cursor;
  do {
    final page = await service.page(afterId: cursor);
    items.addAll(_items(page));
    cursor = page['next'] as int?;
  } while (cursor != null);
  return items;
}

void _resign(Map<String, dynamic> item) {
  item['signature'] =
      sha256
          .convert(
            utf8.encode(
              jsonEncode([
                AktarimEnvanterServisi.inventoryVersion,
                item['contentHash'],
                item['metadataHash'],
              ]),
            ),
          )
          .toString();
}

void main() {
  sqfliteFfiInit();
  late Directory root;
  late Database source;
  late Database target;
  late GuvenliAktarimServisi sender;
  late GuvenliAktarimServisi receiver;
  late AktarimEnvanterServisi local;
  late AktarimEnvanterServisi remote;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('arsiv-inventory-test-');
    source = await _database(p.join(root.path, 'source.db'));
    target = await _database(p.join(root.path, 'target.db'));
    sender = GuvenliAktarimServisi(
      source,
      Directory(p.join(root.path, 'source')),
    );
    receiver = GuvenliAktarimServisi(
      target,
      Directory(p.join(root.path, 'target')),
    );
    local = AktarimEnvanterServisi(sender);
    remote = AktarimEnvanterServisi(receiver);
  });

  tearDown(() async {
    await source.close();
    await target.close();
    await root.delete(recursive: true);
  });

  Future<void> seedLinks() async {
    for (var i = 1; i <= 3; i++) {
      await source.insert('kisiler', _person(i));
      await source.insert('kategoriler', _category(i));
    }
    await source.insert('belgeler', {
      ..._document(1),
      'kisi_id': 1,
      'kategori_id': 1,
      'kisi_ids': '[1,2,3]',
      'kategori_ids': '[1,2,3]',
    });
  }

  Future<Map<String, dynamic>> transfer() async {
    final packet = await sender.paketOlustur(1);
    final extra = packet['baglantilar'] as Map?;
    packet['hedef_kisi_secimleri'] = {
      for (final ref in [
        if (packet['kisi'] != null) packet['kisi'],
        ...?extra?['kisi'] as List?,
      ])
        ref['evrensel_id']: 0,
    };
    await receiver.al(packet, Stream.value(_bytes(1)));
    return packet;
  }

  Future<Map<String, dynamic>> comparison() async =>
      AktarimEnvanterServisi.compare(await _all(local), await _all(remote));

  test('empty inventory, cursor and strict page limits', () async {
    expect(await local.page(), {
      'success': true,
      'inventoryVersion': 1,
      'protocolVersion': 3,
      'items': [],
      'next': null,
    });
    for (final limit in [-1, 0, 201]) {
      await expectLater(local.page(limit: limit), throwsRangeError);
    }
    await expectLater(local.page(afterId: -1), throwsRangeError);
    expect((await local.page(afterId: 999))['next'], isNull);
    expect((await comparison())['same'], 0);
  });

  test(
    '1205 documents: keyset pagination, no file reads or business writes',
    () async {
      final batch = source.batch();
      for (var i = 1; i <= 1205; i++) {
        batch.insert('belgeler', {
          ..._document(i * 2),
          'aktif': i % 11 == 0 ? 0 : 1,
        });
      }
      await batch.commit(noResult: true);
      final before = await source.query('belgeler', orderBy: 'id');
      final watch = Stopwatch()..start();
      final first = await local.page();
      expect(_items(first), hasLength(200));
      expect(await local.page(), first);
      final all = await _all(local);
      expect(
        all.map((r) => r['id']).toList(),
        before.where((r) => r['aktif'] == 1).map((r) => r['id']).toList(),
      );
      expect(all.map((r) => r['canonicalId']).toSet(), hasLength(all.length));
      expect(await source.query('belgeler', orderBy: 'id'), before);
      expect(await sender.belgeler.exists(), false);
      final result = AktarimEnvanterServisi.compare(all, []);
      expect(result['localNewIds'], hasLength(all.length));
      expect(result['conflicts'], isEmpty);
      expect(jsonDecode(jsonEncode(result))['same'], 0);
      // This is a regression guard, not a disk-speed microbenchmark.
      expect(watch.elapsed, lessThan(const Duration(minutes: 1)));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'byte-limited pages resume without omissions, including UTF-8 labels',
    () async {
      final batch = source.batch();
      for (var i = 1; i <= 24; i++) {
        batch.insert('belgeler', {
          ..._document(i),
          'baslik': List.filled(3000, '\u0130').join(),
        });
      }
      await batch.commit(noResult: true);
      await sender.hazirla();
      // Alias-heavy entries reproduce a response budget exceeded before 200 rows.
      final aliases = source.batch();
      for (var id = 1; id <= 24; id++) {
        for (var alias = 0; alias < 80; alias++) {
          aliases.insert('aktarim_kimlikleri', {
            'tur': 'belge',
            'yerel_id': id,
            'evrensel_id': '$id-$alias-${List.filled(60, 'x').join()}',
          });
        }
      }
      await aliases.commit(noResult: true);
      final first = await local.page();
      expect(_items(first).length, lessThan(24));
      expect(first['next'], _items(first).last['id']);
      expect(
        utf8.encode(jsonEncode(first)).length,
        lessThan(AktarimEnvanterServisi.maxPageBytes),
      );
      expect(await local.page(), first);
      final next = await local.page(afterId: first['next'] as int);
      expect(
        utf8.encode(jsonEncode(next)).length,
        lessThan(AktarimEnvanterServisi.maxPageBytes),
      );
      expect(_items(next).first['id'], (_items(first).last['id'] as int) + 1);
      expect(
        (await _all(local)).map((r) => r['id']).toList(),
        List.generate(24, (i) => i + 1),
      );
    },
  );

  test('oversized single entry fails clearly and can be retried', () async {
    await source.insert('belgeler', _document(1));
    final original = _items(await local.page()).single;
    final batch = source.batch();
    for (var i = 0; i < 1600; i++) {
      batch.insert('aktarim_kimlikleri', {
        'tur': 'belge',
        'yerel_id': 1,
        'evrensel_id': 'alias-$i-${List.filled(145, 'x').join()}',
      });
    }
    await batch.commit(noResult: true);
    await expectLater(
      local.page(),
      throwsA(
        isA<AktarimHatasi>().having((e) => e.kod, 'code', 'ENVANTER_BOYUT'),
      ),
    );
    await source.delete(
      'aktarim_kimlikleri',
      where: 'evrensel_id LIKE ?',
      whereArgs: ['alias-%'],
    );
    expect(_items(await local.page()).single, original);
    expect(await source.query('belgeler'), [_document(1)]);
  });

  test('numeric IDs are peer-local; new directions are additive', () async {
    await source.insert('belgeler', _document(1));
    await target.insert('belgeler', {..._document(2), 'id': 1});
    final before = await target.query('belgeler');
    var result = await comparison();
    expect(result['localNewIds'], [1]);
    expect(result['remoteNewIds'], [1]);
    await transfer();
    result = await comparison();
    expect(result['same'], 1);
    expect(result['sameRemoteIds'], [2]);
    expect(result['remoteNewIds'], [1]);
    expect(await target.query('belgeler', where: 'id = 1'), before);
    expect((result['byLocalId'] as Map)['1']['status'], 'same');
  });

  test('transferred local metadata and timestamps do not echo', () async {
    await seedLinks();
    await transfer();
    final initial = await comparison();
    expect(initial['same'], 1);
    await target.update('belgeler', {
      'dosya_yolu': 'another-local-path',
      'guncelleme_tarihi': '2026-01-01T00:00:00Z',
      'son_erisim_tarihi': '2026-02-01T00:00:00Z',
      'senkron_durumu': 4,
      'olusturma_tarihi': '2020-01-02T03:00:00+03:00',
      'kisi_ids': '[1,3,2]',
      'kategori_ids': '[1,3,2]',
    });
    await target.update('kisiler', {
      'ad': '  AL\u0130   1  ',
      'soyad': '  YILMAZ  ',
      'kullanici_adi': ' AL\u01301 ',
      'olusturma_tarihi': '2025-01-01T00:00:00Z',
      'guncelleme_tarihi': '2026-01-01T00:00:00Z',
      'profil_fotografi': 'local-photo.png',
      'kullanici_tipi': 'ADMIN',
    }, where: 'id = 1');
    await target.update('kategoriler', {
      'olusturma_tarihi': '2025-01-01T00:00:00Z',
      'belge_sayisi': 99,
    });
    // Turkish lowercase of YILMAZ is y\u0131lmaz, not yilmaz.
    await source.update('kisiler', {'soyad': 'Y\u0131lmaz'}, where: 'id = 1');
    final result = await comparison();
    expect(result['same'], 1);
    expect(result['localNewIds'], isEmpty);
    expect(result['remoteNewIds'], isEmpty);
    expect(result['conflicts'], isEmpty);
    expect(
      jsonEncode(await local.page()),
      isNot(contains('NEVER-EXPOSE-THIS')),
    );
    expect(jsonEncode(await remote.page()), isNot(contains('local-photo.png')));
  });

  test(
    'all business differences remain conflicts, not automatic sends',
    () async {
      await seedLinks();
      await transfer();
      final baseline = (await target.query('belgeler')).single;
      for (final change in <Map<String, dynamic>>[
        {'baslik': 'changed'},
        {'aciklama': 'changed'},
        {'etiketler': '["different"]'},
        {'dosya_adi': 'renamed.pdf'},
        {'orijinal_dosya_adi': 'renamed.pdf'},
        {'olusturma_tarihi': '2020-01-03T00:00:00Z'},
        {'dosya_boyutu': 999},
        {'kisi_ids': '[1,2]'},
        {'kategori_ids': '[1,2]'},
        {'kisi_id': 2, 'kisi_ids': '[2,1,3]'},
        {'kategori_id': 2, 'kategori_ids': '[2,1,3]'},
        {
          'dosya_hash': sha256.convert([8, 9]).toString(),
        },
      ]) {
        await target.update('belgeler', change);
        final before = await target.query('belgeler');
        final result = await comparison();
        expect(result['same'], 0, reason: '$change');
        expect(result['localNewIds'], isEmpty);
        expect(result['remoteNewIds'], isEmpty);
        expect(result['conflicts'], hasLength(1));
        expect(await target.query('belgeler'), before);
        await target.update('belgeler', baseline);
      }
      await target.update('kategoriler', {
        'renk_kodu': '#abcdef',
      }, where: 'id = 3');
      expect((await comparison())['conflicts'], hasLength(1));
      await target.update('kategoriler', {
        'renk_kodu': '#123456',
      }, where: 'id = 3');
      await target.update('kisiler', {
        'kullanici_adi': 'different',
      }, where: 'id = 3');
      expect((await comparison())['conflicts'], hasLength(1));
    },
  );

  test(
    'canonical aliases for documents and every reference survive restart',
    () async {
      await seedLinks();
      final original = _items(await local.page()).single;
      await transfer();
      // Source adopts a new canonical alias; target knows only the original.
      final rows = await source.query('aktarim_kimlikleri', orderBy: 'rowid');
      await source.delete('aktarim_kimlikleri');
      for (final row in rows) {
        await source.insert('aktarim_kimlikleri', {
          ...row,
          'evrensel_id': 'new-${row['evrensel_id']}',
        });
        await source.insert('aktarim_kimlikleri', row);
      }
      final before = await _all(local);
      expect(before.single['canonicalId'], isNot(original['canonicalId']));
      expect((await comparison())['same'], 1);
      await source.close();
      source = await _database(p.join(root.path, 'source.db'));
      sender = GuvenliAktarimServisi(source, sender.belgeler);
      local = AktarimEnvanterServisi(sender);
      expect(await _all(local), before);
      expect(
        (await sender.paketOlustur(1))['evrensel_belge_id'],
        before.single['canonicalId'],
      );
      expect((await comparison())['same'], 1);
    },
  );

  test(
    'archive owner canonical ID includes preexisting identity aliases',
    () async {
      await seedLinks();
      await local.page();
      await source.execute(
        'CREATE TABLE arsiv_hesabi(yerel_kisi_id INTEGER, yonetici_id TEXT)',
      );
      await source.insert('arsiv_hesabi', {
        'yerel_kisi_id': 1,
        'yonetici_id': 'archive-owner',
      });
      final packet = await sender.paketOlustur(1);
      expect(packet['kisi']['evrensel_id'], 'archive-owner');
      final entry = _items(await local.page()).single;
      expect(entry['links']['kisi'][0]['ids'], contains('archive-owner'));
      expect(entry['links']['kisi'][0]['ids'], hasLength(2));
    },
  );

  test(
    'same hash with distinct IDs is a review candidate even with equal business data',
    () async {
      await source.insert('belgeler', _document(1));
      await target.insert('belgeler', _document(1));
      final a = await _all(local);
      final b = await _all(remote);
      expect(a.single['signature'], b.single['signature']);
      final before = await target.query('belgeler');
      final mappings = await target.query('aktarim_kimlikleri');
      final result = AktarimEnvanterServisi.compare(a, b);
      expect(result['same'], 0);
      expect(result['localNewIds'], isEmpty);
      expect(result['remoteNewIds'], isEmpty);
      expect(
        (result['conflicts'] as List).single['reason'],
        'same_content_distinct_ids',
      );
      expect(await target.query('belgeler'), before);
      expect(await target.query('aktarim_kimlikleri'), mappings);
    },
  );

  test('same name is not a substitute for reference identity', () async {
    await seedLinks();
    await transfer();
    final a = await _all(local);
    final b = await _all(remote);
    b.single['links']['kisi'][1]['ids'] = ['unrelated-person'];
    final result = AktarimEnvanterServisi.compare(a, b);
    expect(result['same'], 0);
    expect(
      (result['conflicts'] as List).single['reason'],
      'link_identity_unconfirmed',
    );
  });

  test(
    'reference alias bridges cannot collapse two same-name people',
    () async {
      await seedLinks();
      await source.update('kisiler', {
        'ad': 'Same',
        'soyad': 'Person',
        'kullanici_adi': null,
      });
      final a = _items(await local.page()).single;
      final b = _copy(a);
      final left = (a['links']['kisi'] as List).cast<Map>();
      final right = (b['links']['kisi'] as List).cast<Map>();
      final first = (left[0]['ids'] as List).single;
      final second = (left[1]['ids'] as List).single;
      left[0]['ids'] = [first, 'first-alias'];
      left[1]['ids'] = [second, 'second-alias'];
      right[0]['ids'] = [first, second];
      right[1]['ids'] = ['first-alias', 'second-alias'];
      final result = AktarimEnvanterServisi.compare([a], [b]);
      expect(result['same'], 0);
      expect(
        (result['conflicts'] as List).single['reason'],
        'link_identity_unconfirmed',
      );
      expect(result['localNewIds'], isEmpty);
      expect(result['remoteNewIds'], isEmpty);
    },
  );

  test(
    'identity/hash bridges and duplicate aliases fail closed on either peer',
    () async {
      await source.insert('belgeler', _document(1));
      final a = _items(await local.page()).single;
      final b = _copy(a)..['id'] = 2;
      b['contentHash'] = sha256.convert([2]).toString();
      _resign(b);
      final c = _copy(a)..['id'] = 3;
      c['ids'] = ['other'];
      c['canonicalId'] = 'other';
      // a -> b via universal ID, a -> c via content hash.
      for (final pair in [
        ([a], [b, c]),
        ([b, c], [a]),
        (<Map<String, dynamic>>[], [a, b, c]),
        ([a, b, c], <Map<String, dynamic>>[]),
      ]) {
        final result = AktarimEnvanterServisi.compare(pair.$1, pair.$2);
        expect(result['same'], 0);
        expect(result['localNewIds'], isEmpty);
        expect(result['remoteNewIds'], isEmpty);
        expect(
          (result['conflicts'] as List).single['reason'],
          'ambiguous_identity',
        );
      }
    },
  );

  test(
    'identical page retries deduplicate; incomplete or inconsistent snapshots fail',
    () async {
      await source.insert('belgeler', _document(1));
      final a = _items(await local.page()).single;
      expect(
        AktarimEnvanterServisi.compare([a, _copy(a)], [a, _copy(a)])['same'],
        1,
      );
      expect(
        () => AktarimEnvanterServisi.compare([a], [], remoteComplete: false),
        throwsStateError,
      );
      expect(
        () => AktarimEnvanterServisi.compare([], [a], localComplete: false),
        throwsStateError,
      );
      final changed = _copy(a)..['title'] = 'concurrent change';
      expect(
        () => AktarimEnvanterServisi.compare([a, changed], []),
        throwsFormatException,
      );
      for (final change in <Map<String, dynamic>>[
        {'inventoryVersion': 99},
        {'id': 0},
        {'ids': []},
        {'canonicalId': 'unknown'},
        {'contentHash': 'broken'},
        {'metadataHash': 'broken'},
        {'signature': 'broken'},
        {'links': {}},
        {
          'links': {
            'kisi': [null],
            'kategori': [],
          },
        },
      ]) {
        expect(
          () => AktarimEnvanterServisi.compare([
            {...a, ...change},
          ], []),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'interrupted receive and retry only become same after verified engine commit',
    () async {
      await source.insert('belgeler', _document(1));
      await target.insert('belgeler', _document(9));
      final existing = await target.query('belgeler');
      final packet = await sender.paketOlustur(1);
      await expectLater(
        receiver.al(packet, Stream.value([0])),
        throwsA(isA<AktarimHatasi>()),
      );
      expect((await comparison())['localNewIds'], [1]);
      expect(await target.query('belgeler'), existing);
      final ack = await receiver.al(packet, Stream.value(_bytes(1)));
      expect(GuvenliAktarimServisi.onayGecerli(packet, ack), true);
      await target.close();
      target = await _database(p.join(root.path, 'target.db'));
      receiver = GuvenliAktarimServisi(target, receiver.belgeler);
      remote = AktarimEnvanterServisi(receiver);
      expect((await comparison())['same'], 1);
      expect(
        (await receiver.al(packet, Stream.value(_bytes(1))))['durum'],
        'zaten_var',
      );
      expect((await target.query('belgeler')).length, 2);
      expect(await target.query('belgeler', where: 'id = 9'), existing);
      expect(
        (await source.query('belgeler')).single['senkron_durumu'],
        SenkronDurumu.YEREL_DEGISIM.index,
      );
    },
  );

  test(
    'inventory equality is not content verification or a synchronization ACK',
    () async {
      await source.insert('belgeler', _document(1));
      final packet = await transfer();
      final row = (await target.query('belgeler')).single;
      await File(row['dosya_yolu'] as String).writeAsBytes([9]);
      expect((await comparison())['same'], 1);
      expect(
        GuvenliAktarimServisi.onayGecerli(packet, await remote.page()),
        false,
      );
      await expectLater(
        receiver.onKontrol(packet),
        throwsA(
          isA<AktarimHatasi>().having(
            (e) => e.kod,
            'code',
            'HEDEF_DOSYA_BOZUK',
          ),
        ),
      );
    },
  );

  test(
    'inactive rows stay untouched; invalid active records fail the page',
    () async {
      await source.insert('belgeler', {..._document(1), 'aktif': 0});
      expect(_items(await local.page()), isEmpty);
      expect((await source.query('belgeler')).single['aktif'], 0);
      await source.insert('belgeler', {
        ..._document(2),
        'dosya_hash': 'invalid',
      });
      await expectLater(local.page(), throwsA(isA<AktarimHatasi>()));
      expect((await source.query('belgeler')).length, 2);
    },
  );
}
