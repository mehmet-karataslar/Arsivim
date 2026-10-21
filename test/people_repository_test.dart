import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/services/people_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late PeopleRepository repository;
  final created = DateTime(2026, 10, 1);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      '''CREATE TABLE kisiler(id INTEGER PRIMARY KEY,ad TEXT,
      soyad TEXT,kullanici_adi TEXT,sifre TEXT,kullanici_tipi TEXT,
      profil_fotografi TEXT,olusturma_tarihi TEXT,guncelleme_tarihi TEXT,aktif INTEGER)''',
    );
    await db.execute('''CREATE TABLE kategoriler(id INTEGER PRIMARY KEY,
      kategori_adi TEXT,renk_kodu TEXT,simge_kodu TEXT,aciklama TEXT,
      olusturma_tarihi TEXT,aktif INTEGER,belge_sayisi INTEGER)''');
    await db.execute(
      '''CREATE TABLE belgeler(id INTEGER PRIMARY KEY,dosya_adi TEXT,
      orijinal_dosya_adi TEXT,dosya_yolu TEXT,dosya_boyutu INTEGER,dosya_tipi TEXT,
      dosya_hash TEXT,kategori_id INTEGER,kisi_id INTEGER,baslik TEXT,aciklama TEXT,
      etiketler TEXT,olusturma_tarihi TEXT,guncelleme_tarihi TEXT,
      son_erisim_tarihi TEXT,aktif INTEGER,senkron_durumu INTEGER)''',
    );
    for (var id = 1; id <= 3; id++) {
      await db.insert(
        'kisiler',
        KisiModeli(
          id: id,
          ad: 'Kişi $id',
          soyad: 'Test',
          sifre: 'test-only',
          olusturmaTarihi: created,
          guncellemeTarihi: created,
          aktif: id != 3,
        ).toMap(),
      );
    }
    for (var id = 1; id <= 2; id++) {
      await db.insert(
        'kategoriler',
        KategoriModeli(
          id: id,
          kategoriAdi: 'Kategori $id',
          olusturmaTarihi: created,
          aktif: id == 1,
        ).toMap(),
      );
    }
    for (var id = 1; id <= 24; id++) {
      await db.insert(
        'belgeler',
        BelgeModeli(
          id: id,
          dosyaAdi: '$id.pdf',
          orijinalDosyaAdi: '$id.pdf',
          dosyaYolu: 'C:\\Arsiv\\Belgeler\\$id.pdf',
          dosyaBoyutu: 100,
          dosyaTipi: 'pdf',
          dosyaHash: '$id',
          kategoriId: id == 1 ? 2 : 1,
          kisiId: id == 24 ? 3 : 1,
          aciklama: id == 1 ? ' ' : 'Not $id',
          olusturmaTarihi: created,
          guncellemeTarihi: created.add(Duration(days: id)),
          aktif: id != 23,
        ).toMap(),
      );
    }
    repository = PeopleRepository(database: () async => db);
  });
  tearDown(() async => db.close());

  test(
    'Aktif kişi ve belge sayıları; pasif kategori ve parola dışarıda kalır',
    () async {
      final result = await repository.read();
      expect(result.people.length, 2);
      expect(result.documentCount, 22);
      expect(result.average, 11);
      final person = result.people.firstWhere((p) => p.person.id == 1);
      expect(person.documentCount, 22);
      expect(person.person.sifre, isNull);
      expect(person.categories.single.id, 1);
      expect(person.categories.single.belgeSayisi, 21);
      expect(person.updated, created.add(const Duration(days: 22)));
      expect(
        result.people.firstWhere((p) => p.person.id == 2).documentCount,
        0,
      );
    },
  );

  test(
    'Panel kişiye göre son 10 belge, 20 açıklama ve gerçek klasörleri getirir',
    () async {
      final result = await repository.details(1);
      expect(result.documents.length, 10);
      expect(result.documents.first.id, 22);
      expect(result.documents.last.id, 13);
      expect(result.documents.every((d) => d.kisiId == 1 && d.aktif), isTrue);
      expect(result.notes.length, 20);
      expect(result.notes.first.id, 22);
      expect(result.notes.last.id, 3);
      expect(result.folders.single.path, r'C:\Arsiv\Belgeler');
      expect(result.folders.single.name, 'Belgeler');
      expect(result.folders.single.count, 22);
      expect((await repository.details(2)).documents, isEmpty);
    },
  );

  test('Kişiyi kaldırmak belgeleri silmez', () async {
    await repository.remove(1);
    expect((await repository.read()).people.single.person.id, 2);
    expect(
      (await db.query('belgeler', where: 'kisi_id = 1 AND aktif = 1')).length,
      22,
    );
  });
}
