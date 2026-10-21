import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/services/aktarim_http.dart';
import 'package:arsiv_uygulamasi/services/depolama_konumu_servisi.dart';
import 'package:arsiv_uygulamasi/services/yedekleme_servisi.dart';
import 'package:arsiv_uygulamasi/services/veritabani_servisi.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/utils/sabitler.dart';

Future<Database> testDb(String path) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  await db.execute(
    '''CREATE TABLE kisiler(id INTEGER PRIMARY KEY AUTOINCREMENT,
    ad TEXT, soyad TEXT, kullanici_adi TEXT UNIQUE, sifre TEXT, kullanici_tipi TEXT,
    profil_fotografi TEXT, olusturma_tarihi TEXT, guncelleme_tarihi TEXT, aktif INTEGER)''',
  );
  await db.execute(
    '''CREATE TABLE kategoriler(id INTEGER PRIMARY KEY AUTOINCREMENT,
    kategori_adi TEXT UNIQUE, renk_kodu TEXT, simge_kodu TEXT, aciklama TEXT,
    olusturma_tarihi TEXT, aktif INTEGER, belge_sayisi INTEGER)''',
  );
  await db.execute(
    '''CREATE TABLE belgeler(id INTEGER PRIMARY KEY AUTOINCREMENT,
    dosya_adi TEXT, orijinal_dosya_adi TEXT, dosya_yolu TEXT, dosya_boyutu INTEGER,
    dosya_tipi TEXT, dosya_hash TEXT UNIQUE, kisi_id INTEGER, kategori_id INTEGER,
    baslik TEXT, aciklama TEXT, etiketler TEXT, olusturma_tarihi TEXT,
    guncelleme_tarihi TEXT, son_erisim_tarihi TEXT, aktif INTEGER, senkron_durumu INTEGER)''',
  );
  return db;
}

Map<String, dynamic> kisi({String ad = 'Ali', String user = 'ali'}) => {
  'ad': ad,
  'soyad': 'Yilmaz',
  'kullanici_adi': user,
  'sifre': 'GIZLI-PAROLA',
  'kullanici_tipi': 'ADMIN',
  'olusturma_tarihi': '2020-01-02T12:34:56Z',
  'guncelleme_tarihi': '2024-05-06T01:02:03Z',
  'aktif': 1,
};

void main() {
  sqfliteFfiInit();
  late Directory root;
  late Database source;
  late Database target;
  late GuvenliAktarimServisi sender;
  late GuvenliAktarimServisi receiver;
  late List<int> content;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('arsiv-transfer-test-');
    source = await testDb(p.join(root.path, 'source.db'));
    target = await testDb(p.join(root.path, 'target.db'));
    sender = GuvenliAktarimServisi(
      source,
      Directory(p.join(root.path, 'source')),
    );
    receiver = GuvenliAktarimServisi(
      target,
      Directory(p.join(root.path, 'target')),
    );
    content = List.generate(2048, (i) => i % 256);
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await root.delete(recursive: true);
  });

  Future<Map<String, dynamic>> paket({
    String ext = 'pdf',
    bool sahip = true,
    int? id,
  }) async {
    await sender.belgeler.create(recursive: true);
    final file = File(
      p.join(sender.belgeler.path, 'belge${ext.isEmpty ? '' : '.$ext'}'),
    );
    await file.writeAsBytes(content);
    int? kisiId;
    int? kategoriId;
    if (sahip) {
      kisiId = await source.insert('kisiler', kisi());
      kategoriId = await source.insert('kategoriler', {
        'kategori_adi': 'Arsiv',
        'renk_kodu': '#123456',
        'simge_kodu': 'folder',
        'aciklama': 'Belgeler',
        'olusturma_tarihi': '2019-01-01T00:00:00Z',
        'aktif': 1,
        'belge_sayisi': 0,
      });
    }
    final b = BelgeModeli(
      id: id,
      dosyaAdi: p.basename(file.path),
      orijinalDosyaAdi: 'Özgün${ext.isEmpty ? '' : '.$ext'}',
      dosyaYolu: file.path,
      dosyaBoyutu: content.length,
      dosyaTipi: ext,
      dosyaHash: sha256.convert(content).toString(),
      kisiId: kisiId,
      kategoriId: kategoriId,
      baslik: 'Başlık',
      aciklama: 'Açıklama',
      etiketler: ['a,b', 'Türkçe', 'etiket'],
      olusturmaTarihi: DateTime.utc(2021, 2, 3, 4, 5, 6),
      guncellemeTarihi: DateTime.utc(2024, 7, 8, 9, 10, 11),
    );
    final localId = await source.insert('belgeler', b.toMap());
    return sender.paketOlustur(localId);
  }

  for (final ext in {
    ...Sabitler.DESTEKLENEN_DOSYA_TIPLERI,
    'mkv',
    'flac',
    'aac',
    'xlsx',
    'bin',
    '',
  }) {
    test(
      '$ext: iki yon, baytlar, tarih, etiketler ve kimlikler korunur',
      () async {
        final data = await paket(ext: ext);
        // Ayni sayisal ID iki cihazda farkli kisilere ait olabilir.
        await target.insert('kisiler', kisi(ad: 'Baska', user: 'baska'));
        data['hedef_kisi_id'] = 0;
        final result = await receiver.al(data, Stream.value(content));
        expect(GuvenliAktarimServisi.onayGecerli(data, result), true);
        final row = (await target.query('belgeler')).single;
        expect(row['kisi_id'], isNot(1));
        expect(await File(row['dosya_yolu'] as String).readAsBytes(), content);
        expect(row['olusturma_tarihi'], data['belge']['olusturma_tarihi']);
        expect(row['guncelleme_tarihi'], data['belge']['guncelleme_tarihi']);
        expect(BelgeModeli.fromMap(row).etiketler, ['a,b', 'Türkçe', 'etiket']);
        expect(jsonEncode(data), isNot(contains('GIZLI-PAROLA')));
        final importedPerson =
            (await target.query(
              'kisiler',
              where: 'id = ?',
              whereArgs: [row['kisi_id']],
            )).single;
        expect(importedPerson['sifre'], isNull);
        expect(importedPerson['kullanici_tipi'], 'NORMAL');
        final reverse = await receiver.paketOlustur(row['id'] as int);
        final back = await sender.al(reverse, Stream.value(content));
        expect(back['durum'], 'zaten_var');
        expect((await source.query('belgeler')).length, 1);
      },
    );
  }

  test('ayni isim otomatik eslesmez, kullanici secimi zorunlu', () async {
    final data = await paket();
    await target.insert('kisiler', kisi());
    await expectLater(
      receiver.onKontrol(data),
      throwsA(isA<AktarimHatasi>().having((e) => e.kod, 'kod', 'KISI_SECIMI')),
    );
    expect(await target.query('belgeler'), isEmpty);
    data['hedef_kisi_id'] = 1;
    expect((await receiver.al(data, Stream.value(content)))['success'], true);
    expect((await target.query('kisiler')).length, 1);
  });

  test('yanlis kisi secimi reddedilir', () async {
    final data = await paket();
    await target.insert('kisiler', kisi(ad: 'Baska', user: 'baska'));
    data['hedef_kisi_id'] = 1;
    await expectLater(
      receiver.al(data, Stream.value(content)),
      throwsA(isA<AktarimHatasi>()),
    );
    expect(await target.query('belgeler'), isEmpty);
    expect(await target.query('kategoriler'), isEmpty);
  });

  test(
    'eksik, fazla, bozuk ve yarida kesilen dosyalar kayit olusturmaz',
    () async {
      final data = await paket();
      data['hedef_kisi_id'] = 0;
      for (final bytes in [
        content.sublist(1),
        [...content, 1],
        List.filled(content.length, 0),
      ]) {
        await expectLater(
          receiver.al(data, Stream.value(bytes)),
          throwsA(isA<AktarimHatasi>()),
        );
        expect(await target.query('belgeler'), isEmpty);
        expect(await target.query('kisiler'), isEmpty);
      }
      Stream<List<int>> broken() async* {
        yield content.sublist(0, 20);
        throw const SocketException('koptu');
      }

      await expectLater(
        receiver.al(data, broken()),
        throwsA(isA<SocketException>()),
      );
      expect(await receiver.belgeler.list().toList(), isEmpty);
      expect((await receiver.al(data, Stream.value(content)))['success'], true);
    },
  );

  test(
    'yeniden gonderim ve eszamanli tekrar ikinci belge/dosya uretmez',
    () async {
      final data = await paket();
      data['hedef_kisi_id'] = 0;
      final results = await Future.wait([
        receiver.al(data, Stream.value(content)),
        receiver.al(data, Stream.value(content)),
      ]);
      expect(results.map((r) => r['durum']).toSet(), {
        'kaydedildi',
        'zaten_var',
      });
      expect((await target.query('belgeler')).length, 1);
      expect((await receiver.belgeler.list().toList()).length, 1);
    },
  );

  test(
    'metadata cakismasi mevcut kisi, kategori ve etiketi degistirmez',
    () async {
      final data = await paket();
      data['hedef_kisi_id'] = 0;
      await receiver.al(data, Stream.value(content));
      final before = await target.query('belgeler');
      data['belge']['baslik'] = 'Baska baslik';
      data['metadata_hash'] = GuvenliAktarimServisi.metadataHash(data);
      data['aktarim_id'] =
          '${data['evrensel_belge_id']}:${data['metadata_hash']}';
      await expectLater(
        receiver.al(data, Stream.value(content)),
        throwsA(
          isA<AktarimHatasi>().having((e) => e.kod, 'kod', 'BELGE_CAKISMASI'),
        ),
      );
      expect(await target.query('belgeler'), before);
    },
  );

  test(
    'dosya yolu saldirisi, gecersiz tarih ve bilinmeyen sema reddedilir',
    () async {
      final data = await paket(sahip: false);
      for (final bad in ['../x.pdf', r'C:\x.pdf', 'CON.pdf', '/x.pdf']) {
        final copy = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
        copy['belge']['dosya_adi'] = bad;
        copy['metadata_hash'] = GuvenliAktarimServisi.metadataHash(copy);
        copy['aktarim_id'] =
            '${copy['evrensel_belge_id']}:${copy['metadata_hash']}';
        expect(
          () => GuvenliAktarimServisi.dogrula(copy),
          throwsA(isA<AktarimHatasi>()),
        );
      }
      data['surum'] = 99;
      expect(
        () => GuvenliAktarimServisi.dogrula(data),
        throwsA(isA<AktarimHatasi>()),
      );
      data['surum'] = 2;
      data['belge']['olusturma_tarihi'] = 'dun';
      data['metadata_hash'] = GuvenliAktarimServisi.metadataHash(data);
      data['aktarim_id'] =
          '${data['evrensel_belge_id']}:${data['metadata_hash']}';
      expect(
        () => GuvenliAktarimServisi.dogrula(data),
        throwsA(isA<AktarimHatasi>()),
      );
    },
  );

  test(
    'yanit kaybi, yanlis hash ve genel success gercek onay sayilmaz',
    () async {
      final data = await paket(sahip: false);
      expect(GuvenliAktarimServisi.onayGecerli(data, {'success': true}), false);
      final result = await receiver.al(data, Stream.value(content));
      result['metadata_hash'] = 'yanlis';
      expect(GuvenliAktarimServisi.onayGecerli(data, result), false);
    },
  );

  test(
    'evrensel belge kimligi iki yonde korunur, farkli icerik reddedilir',
    () async {
      final data = await paket(sahip: false);
      await receiver.al(data, Stream.value(content));
      final reverse = await receiver.paketOlustur(
        (await target.query('belgeler')).single['id'] as int,
      );
      expect(reverse['evrensel_belge_id'], data['evrensel_belge_id']);
      final changed = [...content]..[0] = 100;
      data['belge']['dosya_hash'] = sha256.convert(changed).toString();
      data['metadata_hash'] = GuvenliAktarimServisi.metadataHash(data);
      data['aktarim_id'] =
          '${data['evrensel_belge_id']}:${data['metadata_hash']}';
      await expectLater(
        receiver.al(data, Stream.value(changed)),
        throwsA(
          isA<AktarimHatasi>().having(
            (e) => e.kod,
            'kod',
            'BELGE_KIMLIK_CAKISMASI',
          ),
        ),
      );
      expect((await target.query('belgeler')).length, 1);
    },
  );

  test('gercek HTTP uzerinde buyuk dosya akis aktarimi', () async {
    content = List.generate(11 * 1024 * 1024, (i) => i % 251);
    final data = await paket(sahip: false, ext: 'mp4');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handling = server.first.then((request) async {
      expect(request.headers.value('Authorization'), isNull);
      expect(AktarimHttp.yetkili(request, 'test-key'), true);
      expect(AktarimHttp.yetkili(request, 'test-key'), false);
      final result = await AktarimHttp.al(request, receiver, 'test-key');
      await AktarimHttp.yanit(request, 'test-key', result);
    });
    try {
      final row = (await source.query('belgeler')).single;
      final result = await AktarimHttp.gonder(
        Uri.parse('http://127.0.0.1:${server.port}/sync/v2/file'),
        'test-key',
        data,
        File(row['dosya_yolu'] as String),
      );
      expect(GuvenliAktarimServisi.onayGecerli(data, result), true);
      await handling;
    } finally {
      await server.close(force: true);
    }
  });

  test('eski CSV etiketleri ve virgullu yeni etiketler okunur', () {
    expect(BelgeModeli.etiketleriCoz('a,b'), ['a', 'b']);
    expect(BelgeModeli.etiketleriCoz('["a,b","c"]'), ['a,b', 'c']);
    expect(BelgeModeli.etiketleriCoz(null), isEmpty);
  });

  test('1100 belge tek tek aktarilir, tekrar sayilari degistirmez', () async {
    final template = await paket(sahip: false);
    for (var i = 0; i < 1100; i++) {
      final bytes = utf8.encode('dosya-$i');
      final data = jsonDecode(jsonEncode(template)) as Map<String, dynamic>;
      data['belge']['dosya_hash'] = sha256.convert(bytes).toString();
      data['belge']['dosya_boyutu'] = bytes.length;
      data['belge']['dosya_adi'] = 'dosya-$i.pdf';
      data['metadata_hash'] = GuvenliAktarimServisi.metadataHash(data);
      data['evrensel_belge_id'] = 'belge-$i';
      data['aktarim_id'] =
          '${data['evrensel_belge_id']}:${data['metadata_hash']}';
      expect(
        (await receiver.al(data, Stream.value(bytes)))['durum'],
        'kaydedildi',
      );
      if (i % 100 == 0)
        expect(
          (await receiver.al(data, Stream.value(bytes)))['durum'],
          'zaten_var',
        );
    }
    expect((await target.query('belgeler')).length, 1100);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'DB yazma hatasinda kisi kategori ve dosya birlikte geri alinir',
    () async {
      final data = await paket();
      data['hedef_kisi_id'] = 0;
      await target.execute(
        "CREATE TRIGGER fail_insert BEFORE INSERT ON belgeler BEGIN SELECT RAISE(ABORT, 'test disk failure'); END",
      );
      await expectLater(
        receiver.al(data, Stream.value(content)),
        throwsA(isA<DatabaseException>()),
      );
      expect(await target.query('belgeler'), isEmpty);
      expect(await target.query('kisiler'), isEmpty);
      expect(await target.query('kategoriler'), isEmpty);
      expect(await receiver.belgeler.list().toList(), isEmpty);
      await target.execute('DROP TRIGGER fail_insert');
      expect((await receiver.al(data, Stream.value(content)))['success'], true);
    },
  );

  test('pasif belge ayni hash ile yeniden canlandirilmaz', () async {
    final data = await paket(sahip: false);
    await receiver.al(data, Stream.value(content));
    await target.update('belgeler', {'aktif': 0});
    await expectLater(
      receiver.al(data, Stream.value(content)),
      throwsA(isA<AktarimHatasi>()),
    );
    expect((await target.query('belgeler')).single['aktif'], 0);
  });

  test('bozuk hedef dosya zaten var onayi alamaz', () async {
    final data = await paket(sahip: false);
    await receiver.al(data, Stream.value(content));
    final row = (await target.query('belgeler')).single;
    await File(row['dosya_yolu'] as String).writeAsBytes([1, 2]);
    await expectLater(
      receiver.onKontrol(data),
      throwsA(
        isA<AktarimHatasi>().having((e) => e.kod, 'kod', 'HEDEF_DOSYA_BOZUK'),
      ),
    );
  });

  test(
    'sifreli paket tahrifi, yanlis anahtar, kesilme ve sira degisikligi reddedilir',
    () async {
      final frames =
          await AktarimHttp.sifrele(
            Stream.fromIterable([
              utf8.encode('gizli metin'),
              [1, 2, 3],
            ]),
            'key',
            'request',
          ).toList();
      final wire = frames.expand((v) => v).toList();
      expect(
        utf8.decode(wire, allowMalformed: true),
        isNot(contains('gizli metin')),
      );
      final plain =
          await AktarimHttp.coz(
            Stream.value(wire),
            'key',
            'request',
          ).expand((v) => v).toList();
      expect(plain, [...utf8.encode('gizli metin'), 1, 2, 3]);
      for (final bad in [
        [...wire]..[12] ^= 1,
        wire.sublist(0, wire.length - 1),
        [...frames[1], ...frames[0], ...frames[2]],
        [...wire, 42],
      ]) {
        await expectLater(
          AktarimHttp.coz(Stream.value(bad), 'key', 'request').drain<void>(),
          throwsA(anything),
        );
      }
      await expectLater(
        AktarimHttp.coz(Stream.value(wire), 'wrong', 'request').drain<void>(),
        throwsA(anything),
      );
      await expectLater(
        AktarimHttp.coz(
          Stream.value(wire),
          'key',
          'other-request',
        ).drain<void>(),
        throwsA(anything),
      );
    },
  );

  test(
    'aktarim sirasinda metadata degisirse senkronize isaretlenmez',
    () async {
      final data = await paket(sahip: false);
      final result = await receiver.al(data, Stream.value(content));
      await source.update('belgeler', {'baslik': 'Aktarim sirasinda degisti'});
      final id = (await source.query('belgeler')).single['id'] as int;
      await expectLater(
        sender.gonderimiOnayla(id, data, result),
        throwsA(isA<AktarimHatasi>()),
      );
      expect(
        (await source.query('belgeler')).single['senkron_durumu'],
        SenkronDurumu.YEREL_DEGISIM.index,
      );
    },
  );

  test(
    'WAL dahil snapshot, belge tasima, tarihler ve eski arsiv korunur',
    () async {
      await paket(sahip: true);
      final gizli = await Directory(p.join(root.path, 'private')).create();
      final acik = Directory(p.join(root.path, 'public'));
      final eskiPath = p.join(gizli.path, 'arsiv.db');
      await source.execute('VACUUM INTO ?', [eskiPath]);
      final live = await databaseFactoryFfi.openDatabase(
        eskiPath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await live.rawQuery('PRAGMA journal_mode=WAL');
      await live.update('belgeler', {'baslik': 'WAL icindeki son kayit'});
      final before = await live.query('belgeler');
      final servis = DepolamaKonumuServisi.test(
        gizli: gizli,
        acik: acik,
        factory: databaseFactoryFfi,
      );
      try {
        final yeniPath = await servis.veritabaniYoluHazirla();
        expect(yeniPath, p.join(acik.path, 'arsiv.db'));
        final yeni = await databaseFactoryFfi.openDatabase(yeniPath);
        try {
          final row = (await yeni.query('belgeler')).single;
          expect(row['baslik'], 'WAL icindeki son kayit');
          expect(row['guncelleme_tarihi'], before.single['guncelleme_tarihi']);
          expect(p.isWithin(acik.path, row['dosya_yolu'] as String), true);
          expect(
            await File(row['dosya_yolu'] as String).readAsBytes(),
            content,
          );
          expect(await live.query('belgeler'), before);
          expect(
            await File(before.single['dosya_yolu'] as String).exists(),
            true,
          );
        } finally {
          await yeni.close();
        }
        final restart = DepolamaKonumuServisi.test(
          gizli: gizli,
          acik: acik,
          factory: databaseFactoryFfi,
        );
        expect(await restart.veritabaniYoluHazirla(), yeniPath);
        final denied = DepolamaKonumuServisi.test(
          gizli: gizli,
          acik: acik,
          factory: databaseFactoryFfi,
          yazmaKontrolu: (_) async => false,
        );
        await expectLater(
          denied.veritabaniYoluHazirla(),
          throwsA(isA<StateError>()),
        );
        await File(yeniPath).delete();
        final missing = DepolamaKonumuServisi.test(
          gizli: gizli,
          acik: acik,
          factory: databaseFactoryFfi,
        );
        await expectLater(
          missing.veritabaniYoluHazirla(),
          throwsA(isA<StateError>()),
        );
      } finally {
        await live.close();
      }
    },
  );

  test(
    'ilk izin reddi ve bozuk belge tasimayi engeller, gizli DB yetkili kalir',
    () async {
      await paket(sahip: false);
      await source.update('belgeler', {'dosya_hash': 'bozuk-hash'});
      final gizli = await Directory(p.join(root.path, 'private')).create();
      final acik = Directory(p.join(root.path, 'public'));
      final eskiPath = p.join(gizli.path, 'arsiv.db');
      await source.execute('VACUUM INTO ?', [eskiPath]);
      final denied = DepolamaKonumuServisi.test(
        gizli: gizli,
        acik: acik,
        factory: databaseFactoryFfi,
        yazmaKontrolu: (_) async => false,
      );
      expect(await denied.veritabaniYoluHazirla(), eskiPath);
      final servis = DepolamaKonumuServisi.test(
        gizli: gizli,
        acik: acik,
        factory: databaseFactoryFfi,
      );
      expect(await servis.veritabaniYoluHazirla(), eskiPath);
      expect(servis.tasimaUyarisi, isNotNull);
      expect(await File(p.join(acik.path, 'arsiv.db')).exists(), false);
      expect(await File(eskiPath).exists(), true);
    },
  );

  test(
    'ayni isim farkli kullanici adi yeni kisi olarak elle onaylanabilir',
    () async {
      final data = await paket();
      await target.insert('kisiler', kisi(user: 'diger-ali'));
      await expectLater(
        receiver.onKontrol(data),
        throwsA(isA<AktarimHatasi>()),
      );
      data['hedef_kisi_id'] = 0;
      await receiver.al(data, Stream.value(content));
      expect((await target.query('kisiler')).length, 2);
      expect((await target.query('belgeler')).single['kisi_id'], 2);
    },
  );

  test(
    'profil fotografi hash ile aktarilir ve farkli hedef fotografi korunur',
    () async {
      final id = await source.insert('kisiler', kisi());
      final foto = await File(
        p.join(root.path, 'profil.jpg'),
      ).writeAsBytes([1, 2, 3, 4]);
      await source.update('kisiler', {'profil_fotografi': foto.path});
      final data = await sender.referansPaketi('kisi', id);
      data['hedef_kisi_id'] = 0;
      await receiver.referansAl(data);
      final row = (await target.query('kisiler')).single;
      expect(await File(row['profil_fotografi'] as String).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
      await receiver.referansAl(data);
      expect((await target.query('kisiler')).length, 1);
      await foto.writeAsBytes([5, 6]);
      final changed = await sender.referansPaketi('kisi', id);
      await expectLater(
        receiver.referansAl(changed),
        throwsA(
          isA<AktarimHatasi>().having((e) => e.kod, 'kod', 'PROFIL_CAKISMASI'),
        ),
      );
      expect(await File(row['profil_fotografi'] as String).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('copyWith kisi, kategori ve etiketleri acikca temizleyebilir', () async {
    await paket();
    final row = BelgeModeli.fromMap((await source.query('belgeler')).single);
    final cleared = row.copyWith(
      kisiId: null,
      kategoriId: null,
      etiketler: null,
      baslik: null,
    );
    expect(cleared.kisiId, isNull);
    expect(cleared.kategoriId, isNull);
    expect(cleared.etiketler, isNull);
    expect(cleared.baslik, isNull);
    expect(row.copyWith().kisiId, row.kisiId);
  });

  test(
    'dosya yedegi metadata manifesti uretir, eksigi basari saymaz',
    () async {
      await paket();
      final output = await Directory(p.join(root.path, 'yedekler')).create();
      final servis = YedeklemeServisi(veriTabani: _YedekDb(source));
      await servis.kisiVeKategoriYedeklemeYap([1], output.path);
      final run = (await output.list().toList()).single as Directory;
      final manifest = jsonDecode(
        await File(p.join(run.path, 'manifest.json')).readAsString(),
      );
      expect(manifest['tamamlandi'], true);
      expect(manifest['belgeler'].length, 1);
      final file = File(
        p.join(run.path, manifest['belgeler'][0]['dosya_yolu'] as String),
      );
      expect(await file.readAsBytes(), content);
      expect(jsonEncode(manifest), isNot(contains('GIZLI-PAROLA')));
      await File(
        (await source.query('belgeler')).single['dosya_yolu'] as String,
      ).delete();
      await expectLater(
        servis.kisiVeKategoriYedeklemeYap([1], output.path),
        throwsA(isA<Exception>()),
      );
      final allManifests = <dynamic>[];
      await for (final entry in output.list()) {
        allManifests.add(
          jsonDecode(
            await File(p.join(entry.path, 'manifest.json')).readAsString(),
          ),
        );
      }
      expect(allManifests.where((m) => m['tamamlandi'] == false).length, 1);
    },
  );
}

class _YedekDb implements VeriTabaniServisi {
  final Database connection;
  _YedekDb(this.connection);
  @override
  Future<List<KisiModeli>> kisileriGetir() async =>
      (await connection.query('kisiler')).map(KisiModeli.fromMap).toList();
  @override
  Future<List<KategoriModeli>> kategorileriGetir() async =>
      (await connection.query(
        'kategoriler',
      )).map(KategoriModeli.fromMap).toList();
  @override
  Future<List<BelgeModeli>> kisiBelgeleriniGetir(int id) async =>
      (await connection.query(
        'belgeler',
        where: 'kisi_id = ?',
        whereArgs: [id],
      )).map(BelgeModeli.fromMap).toList();
  @override
  Future<int> kisiBelgeSayisi(int id) async =>
      (await kisiBelgeleriniGetir(id)).length;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
