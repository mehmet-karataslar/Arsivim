import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/services/document_links.dart';
import 'package:arsiv_uygulamasi/services/document_editor_repository.dart';
import 'package:arsiv_uygulamasi/services/dosya_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/utils/sabitler.dart';
import 'package:arsiv_uygulamasi/utils/yardimci_fonksiyonlar.dart';

import 'guvenli_aktarim_test.dart' show testDb, kisi;
import 'document_scan_test.dart' show PageScanner;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late Database source, target;
  late GuvenliAktarimServisi sender, receiver;
  late File file;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('transfer-integrity-');
    source = await testDb('${root.path}/source.db');
    target = await testDb('${root.path}/target.db');
    sender = GuvenliAktarimServisi(source, root);
    receiver = GuvenliAktarimServisi(
      target,
      Directory('${root.path}/received'),
    );
    file = await File('${root.path}/source.pdf').writeAsBytes([0, 1, 2, 255]);
    for (var id = 1; id <= 2; id++) {
      await source.insert('kisiler', {
        'id': id,
        ...kisi(ad: 'Person $id', user: 'user$id'),
      });
      await source.insert('kategoriler', {
        'id': id,
        'kategori_adi': 'Category $id',
        'renk_kodu': '#123456',
        'simge_kodu': 'folder',
        'olusturma_tarihi': '2026-01-01T00:00:00Z',
        'aktif': 1,
        'belge_sayisi': 0,
      });
    }
    await source.insert(
      'belgeler',
      BelgeModeli(
        id: 1,
        dosyaAdi: 'source.pdf',
        orijinalDosyaAdi: 'Report.2026.PDF',
        dosyaYolu: file.path,
        dosyaBoyutu: 4,
        dosyaTipi: 'pdf',
        dosyaHash: await GuvenliAktarimServisi.hash(file),
        kisiId: 1,
        kisiIds: [1, 2],
        kategoriId: 1,
        kategoriIds: [1, 2],
        etiketler: ['a,b', '[old]', 'Turkce'],
        baslik: 'Report',
        aciklama: 'Details',
        olusturmaTarihi: DateTime.utc(2020),
        guncellemeTarihi: DateTime.utc(2026),
      ).toMap(),
    );
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await root.delete(recursive: true);
  });

  Future<Map<String, dynamic>> packet([int id = 1]) async {
    final data = await sender.paketOlustur(id);
    data['hedef_kisi_secimleri'] = {
      data['kisi']['evrensel_id']: 0,
      data['baglantilar']['kisi'][0]['evrensel_id']: 0,
    };
    return data;
  }

  void sign(Map<String, dynamic> data) {
    data['metadata_hash'] = GuvenliAktarimServisi.metadataHash(data);
    data['aktarim_id'] =
        '${data['evrensel_belge_id']}:${data['metadata_hash']}';
  }

  test('Legacy primary remains visible when additional JSON omits it', () async {
    for (final extra in ['[2]', '[]', null]) {
      await source.update('belgeler', {
        'kisi_ids': extra,
        'kategori_ids': extra,
      });
      final rows = await source.rawQuery(
        "SELECT id FROM belgeler b WHERE ${DocumentLinks.contains('kisi', '?')} AND ${DocumentLinks.contains('kategori', '?')}",
        [1, 1],
      );
      expect(rows.map((r) => r['id']), [1], reason: 'extra=$extra');
      expect((await source.query('belgeler')).single['kisi_ids'], extra);
    }
  });

  test(
    'All links, metadata and category counts survive both directions and retry',
    () async {
      await target.insert('kisiler', {'id': 40, ...kisi(user: 'unrelated')});
      await target.insert('kategoriler', {
        'id': 30,
        'kategori_adi': 'Unrelated',
        'aktif': 1,
      });
      final data = await packet();
      await receiver.onKontrol(data);
      final receipt = await receiver.al(data, file.openRead());
      expect(GuvenliAktarimServisi.onayGecerli(data, receipt), isTrue);
      final row = (await target.query('belgeler')).single;
      final model = BelgeModeli.fromMap(row);
      expect(model.tumKisiIds, [41, 42]);
      expect(model.tumKategoriIds, [31, 32]);
      expect(
        await File(model.dosyaYolu).readAsBytes(),
        await file.readAsBytes(),
      );
      expect(GuvenliAktarimServisi.belgeMetadata(row), data['belge']);
      final counts = await target.query(
        'kategoriler',
        where: 'id IN (31,32)',
        orderBy: 'id',
      );
      expect(counts.map((r) => r['belge_sayisi']), [1, 1]);
      expect((await receiver.al(data, file.openRead()))['durum'], 'zaten_var');
      final reverse = await receiver.paketOlustur(model.id!);
      expect(
        (await sender.al(reverse, File(model.dosyaYolu).openRead()))['durum'],
        'zaten_var',
      );
      expect((await source.query('belgeler')).length, 1);
      expect((await target.query('belgeler')).length, 1);
    },
  );

  test(
    'Distinct people cannot silently collapse onto one target person',
    () async {
      await source.update('kisiler', {'ad': 'Same', 'kullanici_adi': null});
      await target.insert('kisiler', {
        'id': 10,
        ...kisi(ad: 'Same'),
        'kullanici_adi': null,
      });
      final data = await packet();
      data['hedef_kisi_secimleri'] = {
        data['kisi']['evrensel_id']: 10,
        data['baglantilar']['kisi'][0]['evrensel_id']: 10,
      };
      final failure = throwsA(
        isA<AktarimHatasi>().having((e) => e.kod, 'code', 'BAGLANTI_CAKISMASI'),
      );
      await expectLater(receiver.onKontrol(data), failure);
      await expectLater(receiver.al(data, file.openRead()), failure);
      expect(await target.query('belgeler'), isEmpty);
      expect(await target.query('aktarim_kimlikleri'), isEmpty);
      expect((await target.query('kisiler')).length, 1);
      expect(await target.query('kategoriler'), isEmpty);
      expect(await receiver.belgeler.list().toList(), isEmpty);
    },
  );

  test('Malformed and orphaned extra links fail with a schema error', () async {
    final data = await packet();
    for (final orphan in [false, true]) {
      final copy = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      if (orphan) {
        copy['kisi'] = null;
      } else {
        copy['baglantilar']['kisi'] = [null];
      }
      sign(copy);
      expect(
        () => GuvenliAktarimServisi.dogrula(copy),
        throwsA(isA<AktarimHatasi>().having((e) => e.kod, 'code', 'SEMA')),
      );
    }
  });

  test(
    'Original extension must agree with stored extension and type',
    () async {
      final data = await packet();
      data['belge']['orijinal_dosya_adi'] = 'Report.mp3';
      sign(data);
      expect(
        () => GuvenliAktarimServisi.dogrula(data),
        throwsA(
          isA<AktarimHatasi>().having((e) => e.kod, 'code', 'DOSYA_TIPI'),
        ),
      );
    },
  );

  test(
    'Whitespace around JSON tags does not split a tag containing commas',
    () {
      expect(BelgeModeli.etiketleriCoz(' \n ["a,b","[old]"] '), [
        'a,b',
        '[old]',
      ]);
      expect(BelgeModeli.etiketleriCoz('[legacy,tag'), ['[legacy', 'tag']);
    },
  );

  test('Extensionless names are portable and rapid names do not collide', () {
    expect(
      YardimciFonksiyonlar.benzersizDosyaAdi('notes', ''),
      isNot(endsWith('.')),
    );
    final names = List.generate(
      2000,
      (_) => YardimciFonksiyonlar.benzersizDosyaAdi('notes', 'pdf'),
    );
    expect(names.toSet().length, names.length);
  });

  test(
    'Generated names fit the portable byte limit without splitting Unicode',
    () {
      final name = YardimciFonksiyonlar.benzersizDosyaAdi(
        List.filled(220, 'ş').join(),
        'pdf',
      );
      expect(utf8.encode(name).length, lessThanOrEqualTo(240));
      expect(name, endsWith('.pdf'));
    },
  );

  test(
    'List-only legacy links survive a return transfer without rewriting the source',
    () async {
      await source.update('belgeler', {'kisi_id': null, 'kategori_id': null});
      final data = await packet();
      await receiver.al(data, file.openRead());
      final reverse = await receiver.paketOlustur(1);
      expect((await sender.al(reverse, file.openRead()))['durum'], 'zaten_var');
      final original = (await source.query('belgeler')).single;
      expect(original['kisi_id'], isNull);
      expect(original['kategori_id'], isNull);
      expect(BelgeModeli.fromMap(original).tumKisiIds, [1, 2]);
    },
  );

  test(
    'New imports of all supported extensions preserve bytes and multi-links in both directions',
    () async {
      var index = 0;
      for (final ext in {
        ...Sabitler.DESTEKLENEN_DOSYA_TIPLERI,
        'mkv',
        'flac',
        'aac',
        'xlsx',
        'bin',
        '',
      }) {
        final name = 'Report.2026${ext.isEmpty ? '' : '.${ext.toUpperCase()}'}';
        // Extensionless input must actually lack an extension, including dots in its base.
        final originalName = ext.isEmpty ? 'notes' : name;
        final bytes = [index++, ...List.generate(1024, (i) => i % 256)];
        final input = await File(
          '${root.path}/input-$index',
        ).writeAsBytes(bytes);
        final imported = await DosyaServisi().dosyaKopyalaVeHashHesapla(
          PlatformFile(name: originalName, path: input.path, size: 0),
          outputDirectory: Directory('${root.path}/imports'),
        );
        expect(imported.dosyaTipi, ext);
        expect(imported.orijinalDosyaAdi, originalName);
        expect(imported.dosyaBoyutu, bytes.length);
        expect(await input.readAsBytes(), bytes);
        final id = await source.insert(
          'belgeler',
          imported
              .copyWith(
                kisiId: 1,
                kisiIds: [1, 2],
                kategoriId: 1,
                kategoriIds: [1, 2],
                etiketler: ['one,two', 'üç'],
                baslik: 'Imported',
                aciklama: 'Details',
              )
              .toMap()
            ..remove('id'),
        );
        final data = await packet(id);
        await receiver.onKontrol(data);
        await receiver.al(data, File(imported.dosyaYolu).openRead());
        final saved =
            (await target.query(
              'belgeler',
              where: 'dosya_hash=?',
              whereArgs: [imported.dosyaHash],
            )).single;
        expect(GuvenliAktarimServisi.belgeMetadata(saved), data['belge']);
        expect(await File(saved['dosya_yolu'] as String).readAsBytes(), bytes);
        expect(BelgeModeli.fromMap(saved).tumKisiIds.length, 2);
        expect(BelgeModeli.fromMap(saved).tumKategoriIds.length, 2);
        final reverse = await receiver.paketOlustur(saved['id'] as int);
        expect(
          (await sender.al(reverse, Stream.value(bytes)))['durum'],
          'zaten_var',
        );
      }
      expect((await target.query('belgeler')).length, index);
    },
  );

  test(
    'Scanned multipage PDF imports and transfers with every link and tag',
    () async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAADklEQVR4nGP4DwYMEAoAU7oL9ZisIGcAAAAASUVORK5CYII=',
      );
      final page = await File('${root.path}/page.png').writeAsBytes(png);
      final scanDir = await Directory('${root.path}/scan').create();
      final scan = (await PageScanner([page.path, page.path], scanDir).scan())!;
      final repository = DocumentEditorRepository(
        database: () async => source,
        owner: 'test',
        importFile:
            (f) => DosyaServisi().dosyaKopyalaVeHashHesapla(
              f,
              outputDirectory: Directory('${root.path}/imports'),
            ),
      );
      await repository.import(
        scan.file,
        (doc) => doc.copyWith(
          kisiId: 2,
          kisiIds: [2, 1],
          kategoriId: 2,
          kategoriIds: [2, 1],
          etiketler: ['taranmış', 'a,b'],
          baslik: 'Tutanak',
          aciklama: 'İki sayfa',
        ),
      );
      final data = await packet(2);
      await receiver.al(data, File(scan.file.path!).openRead());
      final row = (await target.query('belgeler')).single;
      expect(GuvenliAktarimServisi.belgeMetadata(row), data['belge']);
      final bytes = await File(row['dosya_yolu'] as String).readAsBytes();
      expect(bytes, await File(scan.file.path!).readAsBytes());
      expect(
        await GuvenliAktarimServisi.hash(File(row['dosya_yolu'] as String)),
        data['belge']['dosya_hash'],
      );
      final pdf = latin1.decode(bytes);
      expect(pdf, contains('/DCTDecode'));
      expect(pdf, isNot(contains('/Font')));
      expect(pdf, isNot(contains('/ToUnicode')));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        2,
      );
      final reverse = await receiver.paketOlustur(row['id'] as int);
      expect(reverse['kisi']['evrensel_id'], data['kisi']['evrensel_id']);
      expect(
        reverse['kategori']['evrensel_id'],
        data['kategori']['evrensel_id'],
      );
      expect(
        (await sender.al(reverse, Stream.value(bytes)))['durum'],
        'zaten_var',
      );
      expect((await source.query('belgeler')).length, 2);
      expect(await page.readAsBytes(), png);
    },
  );

  test(
    'Concurrent imports with identical names never overwrite a stored copy',
    () async {
      final output = Directory('${root.path}/imports');
      final first = await DosyaServisi().dosyaKopyalaVeHashHesapla(
        PlatformFile(name: 'same.pdf', path: file.path, size: 4),
        outputDirectory: output,
      );
      final secondInput = await File(
        '${root.path}/second',
      ).writeAsBytes([5, 6, 7]);
      final others = await Future.wait(
        List.generate(
          20,
          (_) => DosyaServisi().dosyaKopyalaVeHashHesapla(
            PlatformFile(name: 'same.pdf', path: secondInput.path, size: 3),
            outputDirectory: output,
          ),
        ),
      );
      expect({first.dosyaYolu, ...others.map((b) => b.dosyaYolu)}.length, 21);
      expect(await File(first.dosyaYolu).readAsBytes(), [0, 1, 2, 255]);
      for (final other in others) {
        expect(await File(other.dosyaYolu).readAsBytes(), [5, 6, 7]);
      }
    },
  );
}
