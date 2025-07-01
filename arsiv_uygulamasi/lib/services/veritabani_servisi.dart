import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../utils/sabitler.dart';

// SQLite veritabanı operasyonları
class VeriTabaniServisi {
  static Database? _database;
  static final VeriTabaniServisi _instance = VeriTabaniServisi._internal();

  factory VeriTabaniServisi() => _instance;
  VeriTabaniServisi._internal();

  // Veritabanı bağlantısı ve tablo oluşturma
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, Sabitler.VERITABANI_ADI);

    return await openDatabase(
      path,
      version: Sabitler.VERITABANI_VERSIYONU,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Kişiler tablosu
    await db.execute('''
      CREATE TABLE kisiler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ad TEXT NOT NULL,
        soyad TEXT NOT NULL,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1
      )
    ''');

    // Kategoriler tablosu
    await db.execute('''
      CREATE TABLE kategoriler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kategori_adi TEXT NOT NULL UNIQUE,
        ust_kategori_id INTEGER,
        renk_kodu TEXT DEFAULT '#2196F3',
        simge_kodu TEXT DEFAULT 'folder',
        aciklama TEXT,
        olusturma_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1,
        FOREIGN KEY (ust_kategori_id) REFERENCES kategoriler(id)
      )
    ''');

    // Belgeler tablosu
    await db.execute('''
      CREATE TABLE belgeler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dosya_adi TEXT NOT NULL,
        orijinal_dosya_adi TEXT NOT NULL,
        dosya_yolu TEXT NOT NULL,
        dosya_boyutu INTEGER NOT NULL,
        dosya_tipi TEXT NOT NULL,
        dosya_hash TEXT UNIQUE NOT NULL,
        kategori_id INTEGER,
        kisi_id INTEGER,
        baslik TEXT,
        aciklama TEXT,
        etiketler TEXT,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL,
        son_erisim_tarihi TEXT,
        aktif INTEGER DEFAULT 1,
        senkron_durumu INTEGER DEFAULT 0,
        FOREIGN KEY (kategori_id) REFERENCES kategoriler(id),
        FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
      )
    ''');

    // Senkron logları tablosu
    await db.execute('''
      CREATE TABLE senkron_logları (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER,
        islem_tipi TEXT NOT NULL,
        kaynak_cihaz TEXT NOT NULL,
        hedef_cihaz TEXT NOT NULL,
        islem_tarihi TEXT NOT NULL,
        durum TEXT DEFAULT 'BEKLEMEDE',
        hata_mesaji TEXT,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Cihaz bilgileri tablosu
    await db.execute('''
      CREATE TABLE cihaz_bilgileri (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cihaz_adi TEXT NOT NULL,
        cihaz_tipi TEXT NOT NULL,
        mac_adresi TEXT UNIQUE,
        son_senkron_tarihi TEXT,
        toplam_belge_sayisi INTEGER DEFAULT 0,
        toplam_boyut INTEGER DEFAULT 0,
        senkron_aktif INTEGER DEFAULT 1,
        olusturma_tarihi TEXT NOT NULL
      )
    ''');

    // İndeksler
    await _createIndexes(db);

    // Varsayılan kategorileri ekle
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Kişiler tablosunu ekle
      await db.execute('''
        CREATE TABLE kisiler (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ad TEXT NOT NULL,
          soyad TEXT NOT NULL,
          olusturma_tarihi TEXT NOT NULL,
          guncelleme_tarihi TEXT NOT NULL,
          aktif INTEGER DEFAULT 1
        )
      ''');

      // Belgeler tablosuna kisi_id sütunu ekle
      await db.execute('ALTER TABLE belgeler ADD COLUMN kisi_id INTEGER');
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_belgeler_hash ON belgeler(dosya_hash)');
    await db.execute(
      'CREATE INDEX idx_belgeler_kategori ON belgeler(kategori_id)',
    );
    await db.execute(
      'CREATE INDEX idx_belgeler_tarih ON belgeler(olusturma_tarihi)',
    );
    await db.execute('CREATE INDEX idx_belgeler_aktif ON belgeler(aktif)');
    await db.execute(
      'CREATE INDEX idx_senkron_durum ON belgeler(senkron_durumu)',
    );
    await db.execute(
      'CREATE INDEX idx_senkron_tarih ON senkron_logları(islem_tarihi)',
    );
    await db.execute(
      'CREATE INDEX idx_senkron_durum_log ON senkron_logları(durum)',
    );
  }

  Future<void> _insertDefaultCategories(Database db) async {
    List<KategoriModeli> defaultCategories =
        KategoriModeli.ontanimliKategoriler();

    for (KategoriModeli kategori in defaultCategories) {
      await db.insert('kategoriler', kategori.toMap());
    }
  }

  Future<void> _ensureDefaultCategories(Database db) async {
    List<KategoriModeli> defaultCategories =
        KategoriModeli.ontanimliKategoriler();

    // Mevcut kategori adlarını al
    final existingMaps = await db.query(
      'kategoriler',
      columns: ['kategori_adi'],
      where: 'aktif = ?',
      whereArgs: [1],
    );

    Set<String> existingNames =
        existingMaps.map((map) => map['kategori_adi'] as String).toSet();

    print('Mevcut kategori adları: $existingNames');

    // Eksik kategorileri ekle
    for (KategoriModeli kategori in defaultCategories) {
      if (!existingNames.contains(kategori.kategoriAdi)) {
        print('Eksik kategori ekleniyor: ${kategori.kategoriAdi}');
        await db.insert('kategoriler', kategori.toMap());
      }
    }
  }

  Future<void> _dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS belgeler');
    await db.execute('DROP TABLE IF EXISTS kategoriler');
    await db.execute('DROP TABLE IF EXISTS kisiler');
    await db.execute('DROP TABLE IF EXISTS senkron_logları');
    await db.execute('DROP TABLE IF EXISTS cihaz_bilgileri');
  }

  // BELGE CRUD İŞLEMLERİ

  // Belge ekleme
  Future<int> belgeEkle(BelgeModeli belge) async {
    final db = await database;
    return await db.insert('belgeler', belge.toMap());
  }

  // Tüm belgeleri getir
  Future<List<BelgeModeli>> belgeleriGetir({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'aktif = ?',
      whereArgs: [1],
      orderBy: 'guncelleme_tarihi DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // ID'ye göre belge getir
  Future<BelgeModeli?> belgeGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'id = ? AND aktif = ?',
      whereArgs: [id, 1],
    );

    if (maps.isNotEmpty) {
      return BelgeModeli.fromMap(maps.first);
    }
    return null;
  }

  // Hash'e göre belge getir
  Future<BelgeModeli?> belgeGetirHash(String hash) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'dosya_hash = ? AND aktif = ?',
      whereArgs: [hash, 1],
    );

    if (maps.isNotEmpty) {
      return BelgeModeli.fromMap(maps.first);
    }
    return null;
  }

  // Belge güncelleme
  Future<int> belgeGuncelle(BelgeModeli belge) async {
    final db = await database;
    return await db.update(
      'belgeler',
      belge.toMap(),
      where: 'id = ?',
      whereArgs: [belge.id],
    );
  }

  // Belge silme (soft delete)
  Future<int> belgeSil(int belgeId) async {
    final db = await database;
    return await db.update(
      'belgeler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [belgeId],
    );
  }

  // Belge kalıcı silme
  Future<int> belgeKaliciSil(int belgeId) async {
    final db = await database;
    return await db.delete('belgeler', where: 'id = ?', whereArgs: [belgeId]);
  }

  // Gelişmiş arama - dosya adı, başlık, açıklama, etiket, kategori ve kişi bilgilerine göre
  Future<List<BelgeModeli>> belgeAra(String aramaMetni) async {
    final db = await database;

    // Kategoriler ve kişiler için JOIN ile arama
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT DISTINCT b.* FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE b.aktif = 1 AND (
        b.dosya_adi LIKE ? OR 
        b.orijinal_dosya_adi LIKE ? OR 
        b.baslik LIKE ? OR 
        b.aciklama LIKE ? OR 
        b.etiketler LIKE ? OR
        k.kategori_adi LIKE ? OR
        (ki.ad || ' ' || ki.soyad) LIKE ?
      )
      ORDER BY b.guncelleme_tarihi DESC
    ''',
      [
        '%$aramaMetni%', // dosya_adi
        '%$aramaMetni%', // orijinal_dosya_adi
        '%$aramaMetni%', // baslik
        '%$aramaMetni%', // aciklama
        '%$aramaMetni%', // etiketler
        '%$aramaMetni%', // kategori_adi
        '%$aramaMetni%', // kişi adı soyadı
      ],
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // Kategoriye göre belgeler
  Future<List<BelgeModeli>> kategoriyeGoreBelgeler(int kategoriId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'kategori_id = ? AND aktif = ?',
      whereArgs: [kategoriId, 1],
      orderBy: 'guncelleme_tarihi DESC',
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // KİŞİ CRUD İŞLEMLERİ

  // Kişi ekleme
  Future<int> kisiEkle(KisiModeli kisi) async {
    final db = await database;
    return await db.insert('kisiler', kisi.toMap());
  }

  // Tüm kişileri getir
  Future<List<KisiModeli>> kisileriGetir() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kisiler',
      where: 'aktif = ?',
      whereArgs: [1],
      orderBy: 'ad ASC, soyad ASC',
    );

    return List.generate(maps.length, (i) {
      return KisiModeli.fromMap(maps[i]);
    });
  }

  // ID'ye göre kişi getir
  Future<KisiModeli?> kisiGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kisiler',
      where: 'id = ? AND aktif = ?',
      whereArgs: [id, 1],
    );

    if (maps.isNotEmpty) {
      return KisiModeli.fromMap(maps.first);
    }
    return null;
  }

  // Kişi güncelleme
  Future<int> kisiGuncelle(KisiModeli kisi) async {
    final db = await database;
    return await db.update(
      'kisiler',
      kisi.toMap(),
      where: 'id = ?',
      whereArgs: [kisi.id],
    );
  }

  // Kişi silme (soft delete)
  Future<int> kisiSil(int kisiId) async {
    final db = await database;
    return await db.update(
      'kisiler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [kisiId],
    );
  }

  // Kişiye göre belgeler
  Future<List<BelgeModeli>> kisiyeGoreBelgeler(int kisiId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'kisi_id = ? AND aktif = ?',
      whereArgs: [kisiId, 1],
      orderBy: 'guncelleme_tarihi DESC',
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // KATEGORİ CRUD İŞLEMLERİ

  // Kategori ekleme
  Future<int> kategoriEkle(KategoriModeli kategori) async {
    final db = await database;
    return await db.insert('kategoriler', kategori.toMap());
  }

  // Tüm kategorileri getir
  Future<List<KategoriModeli>> kategorileriGetir() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kategoriler',
      where: 'aktif = ?',
      whereArgs: [1],
      orderBy: 'kategori_adi ASC',
    );

    print('Veritabanından ${maps.length} kategori bulundu');

    // Eğer kategori yoksa veya 16'dan azsa default kategorileri ekle
    if (maps.length < 16) {
      print('Eksik kategoriler var, default kategoriler kontrol ediliyor...');
      await _ensureDefaultCategories(db);

      // Tekrar sorgula
      final newMaps = await db.query(
        'kategoriler',
        where: 'aktif = ?',
        whereArgs: [1],
        orderBy: 'kategori_adi ASC',
      );

      print(
        'Default kategoriler eklendikten sonra: ${newMaps.length} kategori',
      );
      return List.generate(newMaps.length, (i) {
        return KategoriModeli.fromMap(newMaps[i]);
      });
    }

    return List.generate(maps.length, (i) {
      return KategoriModeli.fromMap(maps[i]);
    });
  }

  // Kategori güncelleme
  Future<int> kategoriGuncelle(KategoriModeli kategori) async {
    final db = await database;
    return await db.update(
      'kategoriler',
      kategori.toMap(),
      where: 'id = ?',
      whereArgs: [kategori.id],
    );
  }

  // Kategori silme
  Future<int> kategoriSil(int kategoriId) async {
    final db = await database;
    return await db.update(
      'kategoriler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [kategoriId],
    );
  }

  // SENKRONIZASYON METODLARI

  // Değişmiş hash'leri getir
  Future<List<String>> degismisHashleriGetir() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      columns: ['dosya_hash'],
      where: 'senkron_durumu != ? AND aktif = ?',
      whereArgs: [SenkronDurumu.SENKRONIZE.index, 1],
    );

    return maps.map((map) => map['dosya_hash'] as String).toList();
  }

  // Senkron durumu güncelleme
  Future<void> senkronDurumunuGuncelle(int belgeId, SenkronDurumu durum) async {
    final db = await database;
    await db.update(
      'belgeler',
      {'senkron_durumu': durum.index},
      where: 'id = ?',
      whereArgs: [belgeId],
    );
  }

  // Tüm hash'leri getir
  Future<Map<String, String>> tumHashleriGetir() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      columns: ['dosya_adi', 'dosya_hash'],
      where: 'aktif = ?',
      whereArgs: [1],
    );

    Map<String, String> hashMap = {};
    for (Map<String, dynamic> map in maps) {
      hashMap[map['dosya_adi']] = map['dosya_hash'];
    }
    return hashMap;
  }

  // İSTATİSTİK METODLARI

  // Toplam belge sayısı
  Future<int> toplamBelgeSayisi() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM belgeler WHERE aktif = ?',
      [1],
    );
    return result.first['count'] as int;
  }

  // Toplam dosya boyutu
  Future<int> toplamDosyaBoyutu() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(dosya_boyutu) as total FROM belgeler WHERE aktif = ?',
      [1],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  // Kategoriye göre belge sayıları
  Future<Map<int, int>> kategoriBelgeSayilari() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT kategori_id, COUNT(*) as count 
      FROM belgeler 
      WHERE aktif = ? 
      GROUP BY kategori_id
    ''',
      [1],
    );

    Map<int, int> sayilar = {};
    for (Map<String, dynamic> map in maps) {
      int? kategoriId = map['kategori_id'];
      if (kategoriId != null) {
        sayilar[kategoriId] = map['count'] as int;
      }
    }
    return sayilar;
  }

  // VERİTABANI YÖNETİMİ

  // Veritabanını kapat
  Future<void> kapat() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Veritabanı yolunu getir
  static Future<String> veritabaniYolu() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, Sabitler.VERITABANI_ADI);
  }

  // Veritabanını sıfırla
  Future<void> veritabaniniSifirla() async {
    await kapat();
    String path = await veritabaniYolu();
    await File(path).delete();
    _database = await _initDatabase();
  }
}
