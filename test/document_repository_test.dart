import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/models/ana_sayfa_ozeti.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/document_filters.dart';
import 'package:arsiv_uygulamasi/providers/documents_controller.dart';
import 'package:arsiv_uygulamasi/services/document_activity_service.dart';
import 'package:arsiv_uygulamasi/services/document_repository.dart';
import 'package:arsiv_uygulamasi/services/category_repository.dart';
import 'package:arsiv_uygulamasi/services/category_preferences.dart';
import 'package:arsiv_uygulamasi/models/category_overview.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';

BelgeModeli file(int id) => BelgeModeli(
  id: id,
  dosyaAdi: '$id.pdf',
  orijinalDosyaAdi: '$id.pdf',
  dosyaYolu: 'unused',
  dosyaBoyutu: id * 100000,
  dosyaTipi: id.isEven ? 'pdf' : 'docx',
  dosyaHash: '$id',
  kategoriId: 1,
  kisiId: 1,
  baslik: id == 30 ? 'İŞ SÖZLEŞMESİ' : 'Belge $id',
  olusturmaTarihi: DateTime(2026, 10, 21, id % 24),
  guncellemeTarihi: DateTime(2026, 10, 21),
  aktif: id != 31,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late DocumentRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      "CREATE TABLE kategoriler(id INTEGER PRIMARY KEY,kategori_adi TEXT UNIQUE,aktif INTEGER,renk_kodu TEXT,simge_kodu TEXT,aciklama TEXT,olusturma_tarihi TEXT DEFAULT '2026-10-01T00:00:00.000',belge_sayisi INTEGER DEFAULT 0)",
    );
    await db.execute(
      'CREATE TABLE kisiler(id INTEGER PRIMARY KEY,ad TEXT,soyad TEXT,kullanici_adi TEXT,aktif INTEGER)',
    );
    await db.execute(
      '''CREATE TABLE belgeler(id INTEGER PRIMARY KEY,dosya_adi TEXT,orijinal_dosya_adi TEXT,
      dosya_yolu TEXT,dosya_boyutu INTEGER,dosya_tipi TEXT,dosya_hash TEXT,kategori_ids TEXT, kisi_ids TEXT, kategori_id INTEGER,kisi_id INTEGER,
      baslik TEXT,aciklama TEXT,etiketler TEXT,olusturma_tarihi TEXT,guncelleme_tarihi TEXT,
      son_erisim_tarihi TEXT,aktif INTEGER,senkron_durumu INTEGER)''',
    );
    await db.insert('kategoriler', {
      'id': 1,
      'kategori_adi': 'Eğitim',
      'aktif': 1,
    });
    await db.insert('kisiler', {
      'id': 1,
      'ad': 'Nesih',
      'soyad': 'Karataş',
      'kullanici_adi': 'nesih',
      'aktif': 1,
    });
    for (var id = 1; id <= 31; id++) {
      await db.insert('belgeler', file(id).toMap());
    }
    repository = DocumentRepository(database: () async => db);
  });
  tearDown(() async => db.close());

  test(
    'Kategori özeti okuma sırasında veri eklemez; sayılar, yıldız ve grup kalıcıdır',
    () async {
      final categories = CategoryRepository(database: () async => db);
      final before = await categories.read();
      expect(before.entries.length, 1);
      expect(before.entries.single.count, 30);
      expect(before.entries.single.updated, DateTime(2026, 10, 21));
      await categories.favorite(before.entries.single);
      expect(
        (await CategoryRepository(database: () async => db).read())
            .entries
            .single
            .favorite,
        true,
      );
      final model = KategoriModeli(
        kategoriAdi: 'Yeni grup',
        olusturmaTarihi: DateTime(2026, 10, 20),
      );
      await categories.save(model, CategoryGroup.work);
      final saved = await categories.read();
      expect(saved.entries.length, 2);
      expect(
        saved.entries.firstWhere((e) => e.category.id == model.id).group,
        CategoryGroup.work,
      );
      expect(
        saved.entries.firstWhere((e) => e.category.id == model.id).count,
        0,
      );
      model.kategoriAdi = 'Düzenlenen grup';
      await categories.save(model, CategoryGroup.official);
      final edited = await categories.read();
      expect(edited.entries.length, 2);
      expect(
        edited.events.any((event) => event.label == 'kategorisi güncellendi'),
        true,
      );
      expect(
        (await CategoryPreferences.read())['${model.id}']['group'],
        'official',
      );
    },
  );

  test(
    'Sayfalama toplam arşivi sayar, pasif kayıtları dışlar, tekrarlamaz',
    () async {
      final first = await repository.fetch(const DocumentFilters());
      final second = await repository.fetch(
        const DocumentFilters(),
        offset: 25,
      );
      expect(first.total, 30);
      expect(first.documents.length, 25);
      expect(second.documents.length, 5);
      expect(
        {
          ...first.documents.map((d) => d.belge.id),
          ...second.documents.map((d) => d.belge.id),
        }.length,
        30,
      );
    },
  );
  test(
    'Arama bütün arşivde Türkçe, kişi ve kategori alanlarını kapsar; jokerler literal',
    () async {
      expect(
        (await repository.fetch(
          const DocumentFilters(query: 'iş sözleşmesi'),
        )).documents.single.belge.id,
        30,
      );
      expect(
        (await repository.fetch(const DocumentFilters(query: 'eğitim'))).total,
        30,
      );
      expect(
        (await repository.fetch(const DocumentFilters(query: 'Karataş'))).total,
        30,
      );
      expect(
        (await repository.fetch(
          const DocumentFilters(query: "%' OR 1=1 --"),
        )).total,
        0,
      );
      expect(
        (await repository.fetch(const DocumentFilters(query: '_'))).total,
        0,
      );
    },
  );
  test(
    'Arama başlık, dosya, açıklama, etiket ve uzantıda harf farkını yok sayar',
    () async {
      await db.update(
        'belgeler',
        {
          'baslik': 'IŞIK ÇİZELGESİ',
          'orijinal_dosya_adi': 'ÖZGÜN EVRAK',
          'dosya_adi': 'SAKLANAN KOPYA',
          'dosya_tipi': '.XLSX',
          'aciklama': 'YILLIK BÜTÇE AÇIKLAMASI',
          'etiketler': 'ÖNEMLİ,ŞİRKET',
        },
        where: 'id=?',
        whereArgs: [30],
      );
      for (final query in [
        'ışık çizelgesi',
        'IŞIK ÇİZELGESİ',
        'iŞiK çİzElGeSı',
        'özgün evrak',
        'Özgün Evrak',
        'saklanan kopya',
        'xlsx',
        'XlSx',
        '.xlsx',
        '.XLSX',
        'yıllık bütçe açıklaması',
        'YILLIK BÜTÇE AÇIKLAMASI',
        'önemli',
        'ÖNEMLI',
        'şirket',
        'ŞIRKET',
      ]) {
        final page = await repository.fetch(DocumentFilters(query: query));
        expect(page.total, 1, reason: query);
        expect(page.documents.single.belge.id, 30, reason: query);
      }
    },
  );
  test(
    'Kişi adı, soyadı ve kullanıcı adı farklı harf biçimleriyle bulunur',
    () async {
      await db.update(
        'kisiler',
        {'ad': 'İPEK', 'soyad': 'IŞIK', 'kullanici_adi': 'IPEK.ARŞİV'},
        where: 'id=?',
        whereArgs: [1],
      );
      for (final query in [
        'ipek',
        'İpek',
        'ıpek',
        'ışık',
        'IŞIK',
        'işik',
        'ipek.arşiv',
      ]) {
        expect(
          (await repository.fetch(DocumentFilters(query: query))).total,
          30,
          reason: query,
        );
      }
      await db.insert('kisiler', {
        'id': 2,
        'ad': 'ÇAĞRI',
        'soyad': null,
        'kullanici_adi': 'EK.KİŞİ',
        'aktif': 1,
      });
      await db.update(
        'belgeler',
        {'kisi_ids': '[1,2]'},
        where: 'id=?',
        whereArgs: [30],
      );
      for (final query in ['çağrı', 'ÇAĞRI', 'çağri', 'ek.kişi']) {
        final page = await repository.fetch(DocumentFilters(query: query));
        expect(page.total, 1, reason: query);
        expect(page.documents.single.belge.id, 30, reason: query);
      }
    },
  );
  test(
    'Almanca harfler ve ae/oe/ue/ss yazımları her iki yönde eşleşir',
    () async {
      for (final ascii in [false, true]) {
        await db.update(
          'belgeler',
          {
            'baslik':
                ascii ? 'AERZTLICHE BESCHEINIGUNG' : 'ÄRZTLICHE BESCHEINIGUNG',
            'orijinal_dosya_adi': ascii ? 'GROESSE.PDF' : 'GRÖẞE.PDF',
            'aciklama': ascii ? 'STRASSE UND GEBUEHREN' : 'Straße und Gebühren',
            'etiketler': ascii ? 'KUENDIGUNG' : 'KÜNDIGUNG',
          },
          where: 'id=?',
          whereArgs: [30],
        );
        for (final query in [
          'ärztliche',
          'ÄrZtLiChE',
          'aerztliche',
          'AERZTLICHE',
          'größe.pdf',
          'GRÖSSE.pdf',
          'GROESSE.PDF',
          'straße',
          'STRAẞE',
          'STRASSE',
          'Strasse',
          'gebühren',
          'GEBÜHREN',
          'GEBUEHREN',
          'kündigung',
          'Kündigung',
          'KUENDIGUNG',
        ]) {
          final page = await repository.fetch(DocumentFilters(query: query));
          expect(page.total, 1, reason: '$query (ascii: $ascii)');
          expect(page.documents.single.belge.id, 30, reason: query);
        }
        await db.update(
          'kisiler',
          {
            'ad': 'Jörg',
            'soyad': ascii ? 'MUELLER' : 'MÜLLER',
            'kullanici_adi': ascii ? 'WEISS' : 'WEIẞ',
          },
          where: 'id=?',
          whereArgs: [1],
        );
        for (final query in [
          'jörg',
          'JOERG',
          'müller',
          'MÜLLER',
          'Mueller',
          'weiß',
          'WEISS',
        ]) {
          expect(
            (await repository.fetch(DocumentFilters(query: query))).total,
            30,
            reason: '$query (ascii: $ascii)',
          );
        }
      }
    },
  );
  test(
    'Tür, kişi, kategori, boyut ve tarih filtreleri birlikte uygulanır',
    () async {
      final page = await repository.fetch(
        DocumentFilters(
          extension: 'pdf',
          categoryId: 1,
          personId: 1,
          large: true,
          from: DateTime(2026, 10, 21),
          until: DateTime(2026, 10, 22),
        ),
      );
      expect(page.total, 10);
      expect(
        (await repository.fetch(
          DocumentFilters(from: DateTime(2026, 10, 22)),
        )).total,
        0,
      );
      expect(
        (await repository.fetch(const DocumentFilters(categoryId: 2))).total,
        0,
      );
      expect(
        (await repository.fetch(
          const DocumentFilters(sort: DocumentSort.largest),
        )).documents.first.belge.id,
        30,
      );
    },
  );
  test('Özet, tür dağılımı ve faaliyetler gerçek aktif verilerdir', () async {
    await DocumentActivityService.record(file(30), 'share');
    await DocumentActivityService.record(file(31), 'open');
    final stats = await repository.overview(now: DateTime(2026, 10, 21));
    expect(stats.summary.belgeSayisi, 30);
    expect(stats.today, 30);
    expect(stats.summary.kategoriSayisi, 1);
    expect(stats.summary.dosyaBoyutu, 46500000);
    expect(stats.summary.turBoyutlari['documents'], 46500000);
    expect(stats.types['pdf'], 15);
    expect(stats.sharedIds, [30]);
    expect(stats.activities.length, 1);
    expect(
      (await repository.fetch(
        const DocumentFilters(shared: true),
        sharedIds: stats.sharedIds,
      )).total,
      1,
    );
    expect(
      (await repository.fetch(const DocumentFilters(shared: true))).total,
      0,
    );
  });
  test(
    'Faaliyet geçmişi sınırlıdır ve eşzamanlı kayıtları kaybetmez',
    () async {
      await Future.wait(
        List.generate(
          105,
          (_) => DocumentActivityService.record(file(1), 'open'),
        ),
      );
      expect((await DocumentActivityService.read()).length, 100);
    },
  );
  test('Yeni arama eski isteğin geç gelen sonucunu eler', () async {
    final fake = PendingRepository();
    final controller = DocumentsController(fake, const DocumentFilters());
    final initial = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    controller.apply(const DocumentFilters(query: 'new'));
    await Future<void>.delayed(Duration.zero);
    fake.requests.last.complete(
      DocumentPage([SonBelgeOzeti(belge: file(2))], 1),
    );
    await Future<void>.delayed(Duration.zero);
    fake.requests.first.complete(
      DocumentPage([SonBelgeOzeti(belge: file(1))], 1),
    );
    await initial;
    expect(controller.documents.single.belge.id, 2);
    expect(controller.loading, false);
    controller.dispose();
  });
}

class PendingRepository extends DocumentRepository {
  final requests = <Completer<DocumentPage>>[];
  @override
  Future<DocumentOverview> overview({DateTime? now}) async =>
      const DocumentOverview(
        summary: AnaSayfaOzeti(belgeSayisi: 2, dosyaBoyutu: 0, sonBelgeler: []),
      );
  @override
  Future<DocumentPage> fetch(
    DocumentFilters filters, {
    int offset = 0,
    int limit = 25,
    List<int> sharedIds = const [],
  }) {
    final result = Completer<DocumentPage>();
    requests.add(result);
    return result.future;
  }
}
