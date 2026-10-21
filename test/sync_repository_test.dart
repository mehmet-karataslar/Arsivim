import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/services/sync_repository.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late SyncRepository repo;
  final now = DateTime(2026, 10, 21, 12);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      '''CREATE TABLE belgeler(id INTEGER PRIMARY KEY,dosya_adi TEXT,
      orijinal_dosya_adi TEXT,dosya_yolu TEXT,dosya_boyutu INTEGER,dosya_tipi TEXT,
      dosya_hash TEXT,kategori_ids TEXT, kisi_ids TEXT, kategori_id INTEGER,kisi_id INTEGER,baslik TEXT,aciklama TEXT,
      etiketler TEXT,olusturma_tarihi TEXT,guncelleme_tarihi TEXT,
      son_erisim_tarihi TEXT,aktif INTEGER,senkron_durumu INTEGER)''',
    );
    for (var i = 0; i < 7; i++) {
      await db.insert(
        'belgeler',
        BelgeModeli(
          id: i + 1,
          dosyaAdi: '$i.pdf',
          orijinalDosyaAdi: '$i.pdf',
          dosyaYolu: 'unused',
          dosyaBoyutu: 100,
          dosyaTipi: 'pdf',
          dosyaHash: 'hash$i',
          olusturmaTarihi: now,
          guncellemeTarihi: now,
          aktif: i != 6,
          senkronDurumu: SenkronDurumu.values[i % 6],
        ).toMap(),
      );
    }
    repo = SyncRepository(database: () async => db, backup: () async => now);
  });
  tearDown(() => db.close());
  test(
    'Durumlar topluca sayılır; henüz olmayan geçmiş için veri uydurulmaz',
    () async {
      final data = await repo.read(now: now);
      expect(data.total, 6);
      expect(data.pending, 2);
      expect(data.synced, 1);
      expect(data.today, 0);
      expect(data.lastTransfer, isNull);
      expect(data.events, isEmpty);
      expect(data.lastBackup, now);
      expect((await repo.pendingDocuments()).map((d) => d.id), [2, 5]);
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='aktarim_gecmisi'",
        ),
        isEmpty,
      );
    },
  );
  test(
    'Bugünün doğrulanan farklı dosyaları sayılır; gece sınırı, hata ve tekrar ayrılır',
    () async {
      await db.execute('''CREATE TABLE aktarim_gecmisi(id INTEGER PRIMARY KEY,
      dosya_hash TEXT,durum TEXT,mesaj TEXT,zaman TEXT)''');
      final midnight = DateTime(now.year, now.month, now.day);
      for (var i = 0; i < 35; i++) {
        await db.insert('aktarim_gecmisi', {
          'id': i,
          'dosya_hash':
              i == 0
                  ? 'previous'
                  : i == 1
                  ? 'failed'
                  : i == 2
                  ? 'future'
                  : 'hash0',
          'durum': i == 1 ? 'hata' : 'gonderildi',
          'zaman':
              (i == 0
                      ? midnight.subtract(const Duration(seconds: 1))
                      : i == 2
                      ? midnight.add(const Duration(days: 1))
                      : midnight.add(Duration(minutes: i)))
                  .toUtc()
                  .toIso8601String(),
        });
      }
      final data = await repo.read(now: now);
      expect(data.today, 1);
      expect(data.events.length, 30);
      expect(data.events.any((e) => e.title == '0.pdf'), true);
      expect(data.lastTransfer, midnight.add(const Duration(days: 1)));
    },
  );
}
