import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/document_filters.dart';
import 'package:arsiv_uygulamasi/services/document_editor_repository.dart';
import 'package:arsiv_uygulamasi/services/document_links.dart';
import 'package:arsiv_uygulamasi/services/document_repository.dart';
import 'package:arsiv_uygulamasi/services/people_repository.dart';
import 'package:arsiv_uygulamasi/services/category_repository.dart';
import 'package:arsiv_uygulamasi/services/home_summary_service.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'guvenli_aktarim_test.dart' show testDb, kisi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory root;
  late File source;
  late BelgeModeli original;
  late DocumentEditorRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('editor-test-');
    db = await testDb('${root.path}/archive.db');
    source = await File('${root.path}/source.pdf').writeAsBytes([1, 2, 3, 4]);
    for (var id = 1; id <= 2; id++) {
      await db.insert('kisiler', {
        'id': id,
        ...kisi(ad: 'Kişi $id', user: 'user$id'),
      });
      await db.insert('kategoriler', {
        'id': id,
        'kategori_adi': 'Kategori $id',
        'renk_kodu': '#008557',
        'simge_kodu': 'folder',
        'aktif': 1,
        'olusturma_tarihi': '2026-10-21T00:00:00Z',
      });
    }
    original = BelgeModeli(
      id: 1,
      dosyaAdi: 'source.pdf',
      orijinalDosyaAdi: 'source.pdf',
      dosyaYolu: source.path,
      dosyaBoyutu: 4,
      dosyaTipi: 'pdf',
      dosyaHash: await GuvenliAktarimServisi.hash(source),
      kisiId: 1,
      kategoriId: 1,
      baslik: 'Belge',
      olusturmaTarihi: DateTime(2026, 10, 20),
      guncellemeTarihi: DateTime(2026, 10, 21),
    );
    await db.insert('belgeler', original.toMap());
    repository = DocumentEditorRepository(
      database: () async => db,
      owner: 'test',
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'Çoklu bağlantılar filtrelere, sayaçlara ve kişi ayrıntılarına yansır; belge tek sayılır',
    () async {
      final edited = original.copyWith(
        kisiIds: [1, 2],
        kategoriIds: [1, 2],
        guncellemeTarihi: DateTime(2026, 10, 22),
      );
      await repository.update(original, edited);
      final docs = await DocumentRepository(
        database: () async => db,
      ).fetch(const DocumentFilters(personId: 2, categoryId: 2));
      expect(docs.total, 1);
      expect(docs.documents.single.belge.tumKisiIds, [1, 2]);
      final search = await DocumentRepository(
        database: () async => db,
      ).fetch(const DocumentFilters(query: 'Kişi 2'));
      expect(search.total, 1);
      final people = await PeopleRepository(database: () async => db).read();
      expect(people.documentCount, 1);
      expect(people.people.map((p) => p.documentCount), [1, 1]);
      expect(
        (await PeopleRepository(
          database: () async => db,
        ).details(2)).documents.single.id,
        1,
      );
      expect(
        (await CategoryRepository(database: () async => db).read()).entries.map(
          (e) => e.category.belgeSayisi,
        ),
        [1, 1],
      );
      final totals = await HomeSummaryService.aggregate(db);
      expect(totals['count'], 1);
      expect(totals['bytes'], 4);
      expect(totals['categories'], 2);
      await repository.update(
        edited,
        edited.copyWith(
          kategoriId: null,
          kategoriIds: [],
          kisiId: 2,
          kisiIds: [2],
        ),
      );
      final saved = BelgeModeli.fromMap((await db.query('belgeler')).single);
      expect(saved.tumKisiIds, [2]);
      expect(saved.tumKategoriIds, isEmpty);
    },
  );
  test(
    'Geçersiz bağlantı ve eşzamanlı düzenleme eski kaydı değiştirmez',
    () async {
      await expectLater(
        repository.update(original, original.copyWith(kisiIds: [999])),
        throwsStateError,
      );
      expect((await db.query('belgeler')).single['kisi_ids'], '[1]');
      await db.update('belgeler', {
        'guncelleme_tarihi': '2026-10-23T00:00:00.000',
      }, where: 'id=1');
      await expectLater(
        repository.update(original, original.copyWith(baslik: 'Eski ekran')),
        throwsStateError,
      );
      expect((await db.query('belgeler')).single['baslik'], 'Belge');
    },
  );
  test(
    'Tekrarlı içerikte yalnızca yeni kopya temizlenir; kaynak ve kayıt korunur',
    () async {
      final copied = File('${root.path}/copied.pdf');
      final repo = DocumentEditorRepository(
        database: () async => db,
        importFile: (file) async {
          await File(file.path!).copy(copied.path);
          return original.copyWith(id: null, dosyaYolu: copied.path);
        },
      );
      await expectLater(
        repo.import(
          PlatformFile(name: 'source.pdf', size: 4, path: source.path),
          (doc) => doc,
        ),
        throwsStateError,
      );
      expect(await copied.exists(), false);
      expect(await source.exists(), true);
      expect((await db.query('belgeler')).length, 1);
    },
  );
  test(
    'Taslak hesap ve belgeye göre ayrılır; tüm çoklu seçimleri korur',
    () async {
      await repository.saveDraft(null, {
        'people': [1, 2],
        'categories': [2, 1],
      });
      expect((await repository.draft(null))!['people'], [1, 2]);
      expect(await repository.draft(1), null);
      expect(
        await DocumentEditorRepository(
          database: () async => db,
          owner: 'other',
        ).draft(null),
        null,
      );
      await repository.deleteDraft(null);
      expect(await repository.draft(null), null);
    },
  );
  test('Eski şema geçişi tekli bağlantıyı ve belgeyi korur', () async {
    final old = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      await old.execute(
        'CREATE TABLE belgeler(id INTEGER PRIMARY KEY,kisi_id INTEGER,kategori_id INTEGER)',
      );
      await old.insert('belgeler', {'id': 1, 'kisi_id': 7, 'kategori_id': 9});
      await DocumentLinks.prepare(old);
      await DocumentLinks.prepare(old);
      expect(
        (await old.rawQuery(
          "SELECT id FROM belgeler b WHERE ${DocumentLinks.contains('kisi', '7')} AND ${DocumentLinks.contains('kategori', '9')}",
        )).single['id'],
        1,
      );
      expect((await old.query('belgeler')).single['kisi_id'], 7);
    } finally {
      await old.close();
    }
  });
  test(
    'Çoklu bağlantı aktarımı hedefin yerel kimliklerine çevrilir ve tekrarda çoğalmaz',
    () async {
      await repository.update(
        original,
        original.copyWith(kisiIds: [1, 2], kategoriIds: [1, 2]),
      );
      final target = await testDb('${root.path}/target.db');
      try {
        await target.insert('kisiler', {
          'id': 40,
          ...kisi(ad: 'Başka', user: 'different'),
        });
        await target.insert('kategoriler', {
          'id': 30,
          'kategori_adi': 'Başka',
          'aktif': 1,
        });
        final sender = GuvenliAktarimServisi(db, Directory(root.path));
        final receiver = GuvenliAktarimServisi(
          target,
          Directory('${root.path}/received'),
        );
        final packet = await sender.paketOlustur(1);
        expect(packet['baglantilar']['kisi'].length, 1);
        try {
          await receiver.onKontrol(packet);
          fail('Kişi eşleştirmesi gerekli');
        } on AktarimHatasi catch (e) {
          expect(e.kod, 'KISI_SECIMI');
          expect(e.kisiEvrenselId, isNotNull);
        }
        packet['hedef_kisi_secimleri'] = {
          packet['kisi']['evrensel_id']: 0,
          packet['baglantilar']['kisi'][0]['evrensel_id']: 0,
        };
        await receiver.onKontrol(packet);
        await receiver.al(packet, source.openRead());
        final saved = BelgeModeli.fromMap(
          (await target.query('belgeler')).single,
        );
        expect(saved.tumKisiIds, [41, 42]);
        expect(saved.tumKategoriIds, [31, 32]);
        await receiver.al(packet, source.openRead());
        expect((await target.query('belgeler')).length, 1);
        final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
        tampered['baglantilar']['kisi'][0]['ad'] = 'Yanlış';
        expect(
          () => GuvenliAktarimServisi.dogrula(tampered),
          throwsA(isA<AktarimHatasi>()),
        );
      } finally {
        await target.close();
      }
    },
  );
}
