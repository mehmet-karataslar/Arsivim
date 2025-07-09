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

  /// Veritabanını manuel olarak başlat (uygulama başlangıcında kullanılabilir)
  Future<void> baslat() async {
    try {
      print('🚀 Veritabanı servisi başlatılıyor...');
      await database; // Bu, veritabanını otomatik olarak başlatır
      print('✅ Veritabanı servisi başarıyla başlatıldı!');
    } catch (e) {
      print('❌ Veritabanı servisi başlatma hatası: $e');
      rethrow;
    }
  }

  // Veritabanı bağlantısı ve tablo oluşturma
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, Sabitler.VERITABANI_ADI);

    // Veritabanı dosyasının varlığını kontrol et
    bool databaseExists = await File(path).exists();

    if (databaseExists) {
      print('✅ Mevcut veritabanı bulundu: $path');
      print('📂 Mevcut veritabanı kullanılıyor...');
    } else {
      print('🆕 Veritabanı bulunamadı: $path');
      print('🔧 Yeni veritabanı oluşturuluyor...');
    }

    try {
      final database = await openDatabase(
        path,
        version: Sabitler.VERITABANI_VERSIYONU,
        onCreate: (db, version) async {
          print('🎯 Yeni veritabanı oluşturuluyor (versiyon: $version)');
          await _onCreate(db, version);
          print('✅ Veritabanı başarıyla oluşturuldu!');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('🔄 Veritabanı güncelleniyor ($oldVersion -> $newVersion)');
          await _onUpgrade(db, oldVersion, newVersion);
          print('✅ Veritabanı başarıyla güncellendi!');
        },
        onOpen: (db) async {
          print('🔓 Veritabanı açıldı: $path');
          // Veritabanı bütünlüğünü kontrol et
          await _checkDatabaseIntegrity(db);
        },
      );

      return database;
    } catch (e) {
      print('❌ Veritabanı başlatma hatası: $e');

      // Hata durumunda veritabanı dosyasını sil ve yeniden oluştur
      if (await File(path).exists()) {
        print('🗑️ Bozuk veritabanı dosyası siliniyor...');
        await File(path).delete();
      }

      print('🔧 Veritabanı yeniden oluşturuluyor...');
      return await openDatabase(
        path,
        version: Sabitler.VERITABANI_VERSIYONU,
        onCreate: (db, version) async {
          print('🎯 Yedek veritabanı oluşturuluyor (versiyon: $version)');
          await _onCreate(db, version);
          print('✅ Yedek veritabanı başarıyla oluşturuldu!');
        },
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Kişiler tablosu
    await db.execute('''
      CREATE TABLE kisiler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ad TEXT NOT NULL,
        soyad TEXT NOT NULL,
        kullanici_adi TEXT UNIQUE,
        sifre TEXT,
        kullanici_tipi TEXT DEFAULT 'NORMAL',
        profil_fotografi TEXT,
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
        renk_kodu TEXT DEFAULT '#2196F3',
        simge_kodu TEXT DEFAULT 'folder',
        aciklama TEXT,
        olusturma_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1,
        belge_sayisi INTEGER DEFAULT 0
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
        versiyon_numarasi INTEGER DEFAULT 1,
        metadata_hash TEXT,
        son_metadata_guncelleme TEXT,
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

    // Senkronizasyon durumu tablosu (raporda belirtilen)
    await db.execute('''
      CREATE TABLE senkron_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dosya_hash TEXT NOT NULL UNIQUE,
        son_sync_zamani TEXT NOT NULL,
        sync_durumu TEXT NOT NULL DEFAULT 'PENDING',
        cihaz_id TEXT,
        metadata_hash TEXT,
        olusturma_tarihi TEXT NOT NULL
      )
    ''');

    // Belge versiyonları tablosu (raporda belirtilen)
    await db.execute('''
      CREATE TABLE belge_versiyonlari (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        belge_id INTEGER NOT NULL,
        versiyon_numarasi INTEGER NOT NULL,
        dosya_hash TEXT NOT NULL,
        metadata_hash TEXT,
        degisiklik_aciklamasi TEXT,
        olusturan_cihaz TEXT,
        olusturma_tarihi TEXT NOT NULL,
        FOREIGN KEY (belge_id) REFERENCES belgeler(id)
      )
    ''');

    // Metadata değişiklikleri tablosu (raporda belirtilen)
    await db.execute('''
      CREATE TABLE metadata_degisiklikleri (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        degisiklik_tipi TEXT NOT NULL,
        eski_deger TEXT,
        yeni_deger TEXT,
        degisiklik_zamani TEXT NOT NULL,
        cihaz_id TEXT,
        sync_edildi INTEGER DEFAULT 0
      )
    ''');

    // İndeksler
    await _createIndexes(db);

    // Varsayılan kategorileri ekle
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Database upgrade: $oldVersion -> $newVersion');

    // Kritik migration hatası durumunda veritabanını sıfırla
    try {
      await _performMigration(db, oldVersion, newVersion);
    } catch (e) {
      print('❌ Migration başarısız: $e');
      print('🔄 Veritabanı sıfırlanıyor...');
      await _dropAllTables(db);
      await _onCreate(db, newVersion);
      print('✅ Veritabanı yeniden oluşturuldu');
    }
  }

  /// Veritabanı bütünlüğünü kontrol et
  Future<void> _checkDatabaseIntegrity(Database db) async {
    try {
      // Temel tabloların varlığını kontrol et
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final requiredTables = ['kisiler', 'kategoriler', 'belgeler'];
      final existingTables = tables.map((t) => t['name'] as String).toList();

      for (final table in requiredTables) {
        if (!existingTables.contains(table)) {
          print('⚠️ Eksik tablo tespit edildi: $table');
          throw Exception('Eksik tablo: $table');
        }
      }

      // Basit bir query ile veritabanının çalıştığını kontrol et
      await db.rawQuery('SELECT COUNT(*) FROM kisiler');
      await db.rawQuery('SELECT COUNT(*) FROM kategoriler');
      await db.rawQuery('SELECT COUNT(*) FROM belgeler');

      print('✅ Veritabanı bütünlük kontrolü başarılı');
    } catch (e) {
      print('❌ Veritabanı bütünlük kontrolü başarısız: $e');
      throw e;
    }
  }

  Future<void> _performMigration(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
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

    if (oldVersion < 3) {
      // metadata_degisiklikleri tablosunda sync_durumu kolonu sync_edildi olarak değiştir
      try {
        // Önce kolonu kontrol et
        final columns = await db.rawQuery(
          "PRAGMA table_info(metadata_degisiklikleri)",
        );
        final hasOldColumn = columns.any((col) => col['name'] == 'sync_durumu');

        if (hasOldColumn) {
          // Eski tabloyu yedekle
          await db.execute('''
            CREATE TABLE metadata_degisiklikleri_backup AS 
            SELECT * FROM metadata_degisiklikleri
          ''');

          // Eski tabloyu sil
          await db.execute('DROP TABLE metadata_degisiklikleri');

          // Yeni tabloyu oluştur
          await db.execute('''
            CREATE TABLE metadata_degisiklikleri (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity_type TEXT NOT NULL,
              entity_id INTEGER NOT NULL,
              degisiklik_tipi TEXT NOT NULL,
              eski_deger TEXT,
              yeni_deger TEXT,
              degisiklik_zamani TEXT NOT NULL,
              cihaz_id TEXT,
              sync_edildi INTEGER DEFAULT 0
            )
          ''');

          // Verileri geri aktar (sync_durumu -> sync_edildi conversion)
          await db.execute('''
            INSERT INTO metadata_degisiklikleri 
            (id, entity_type, entity_id, degisiklik_tipi, eski_deger, yeni_deger, degisiklik_zamani, cihaz_id, sync_edildi)
            SELECT 
              id, entity_type, entity_id, degisiklik_tipi, eski_deger, yeni_deger, degisiklik_zamani, cihaz_id,
              CASE WHEN sync_durumu = 'SYNCED' THEN 1 ELSE 0 END
            FROM metadata_degisiklikleri_backup
          ''');

          // Backup tabloyu sil
          await db.execute('DROP TABLE metadata_degisiklikleri_backup');

          print(
            '✅ metadata_degisiklikleri tablosu güncellendi (sync_durumu -> sync_edildi)',
          );
        }
      } catch (e) {
        print('⚠️ metadata_degisiklikleri migration hatası: $e');
      }
    }

    if (oldVersion < 4) {
      // Aggressive migration - metadata_degisiklikleri tablosunu tamamen yeniden oluştur
      try {
        print(
          '🔄 V4 Migration başlatılıyor - metadata_degisiklikleri yeniden oluşturuluyor...',
        );

        // Eski tabloyu tamamen sil
        await db.execute('DROP TABLE IF EXISTS metadata_degisiklikleri');

        // Yeni tabloyu doğru schema ile oluştur
        await db.execute('''
          CREATE TABLE metadata_degisiklikleri (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            degisiklik_tipi TEXT NOT NULL,
            eski_deger TEXT,
            yeni_deger TEXT,
            degisiklik_zamani TEXT NOT NULL,
            cihaz_id TEXT,
            sync_edildi INTEGER DEFAULT 0
          )
        ''');

        // Indexleri de yeniden oluştur
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_entity ON metadata_degisiklikleri(entity_type, entity_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_zaman ON metadata_degisiklikleri(degisiklik_zamani)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_sync ON metadata_degisiklikleri(sync_edildi)',
        );

        print('✅ metadata_degisiklikleri tablosu V4 ile yeniden oluşturuldu');
      } catch (e) {
        print('❌ V4 migration hatası: $e');
      }
    }

    if (oldVersion < 5) {
      // V5 Migration - kategoriler tablosuna belge_sayisi kolonu ekle
      try {
        print(
          '🔄 V5 Migration başlatılıyor - kategoriler tablosuna belge_sayisi kolonu ekleniyor...',
        );

        await db.execute(
          'ALTER TABLE kategoriler ADD COLUMN belge_sayisi INTEGER DEFAULT 0',
        );

        print('✅ kategoriler tablosu V5 ile güncellendi');
      } catch (e) {
        print('❌ V5 migration hatası: $e');
      }
    }

    if (oldVersion < 6) {
      // V6 Migration - kullanıcı sistemi için kişiler tablosunu güncelle
      try {
        print('🔄 V6 Migration başlatılıyor - kullanıcı sistemi ekleniyor...');

        // Önce mevcut kolonları kontrol et
        final columns = await db.rawQuery("PRAGMA table_info(kisiler)");
        final existingColumns = columns.map((col) => col['name']).toSet();

        print('Mevcut kolonlar: $existingColumns');

        // Kullanıcı alanlarını ekle (sadece yoksa)
        if (!existingColumns.contains('kullanici_adi')) {
          await db.execute(
            'ALTER TABLE kisiler ADD COLUMN kullanici_adi TEXT UNIQUE',
          );
          print('✅ kullanici_adi kolonu eklendi');
        }

        if (!existingColumns.contains('sifre')) {
          await db.execute('ALTER TABLE kisiler ADD COLUMN sifre TEXT');
          print('✅ sifre kolonu eklendi');
        }

        if (!existingColumns.contains('kullanici_tipi')) {
          await db.execute(
            'ALTER TABLE kisiler ADD COLUMN kullanici_tipi TEXT DEFAULT "NORMAL"',
          );
          print('✅ kullanici_tipi kolonu eklendi');
        }

        print('✅ Kullanıcı sistemi V6 ile eklendi');
      } catch (e) {
        print('❌ V6 migration hatası: $e');
        // Migration başarısız olursa veritabanını sıfırla
        print('🔄 Veritabanı sıfırlanıyor...');
        await _dropAllTables(db);
        await _onCreate(db, 6);
        print('✅ Veritabanı yeniden oluşturuldu');
      }
    }

    if (oldVersion < 7) {
      // V7 Migration - kişiler tablosuna profil_fotografi kolonu ekle
      try {
        print(
          '🔄 V7 Migration başlatılıyor - profil fotoğrafı kolonu ekleniyor...',
        );

        // Önce mevcut kolonları kontrol et
        final columns = await db.rawQuery("PRAGMA table_info(kisiler)");
        final existingColumns = columns.map((col) => col['name']).toSet();

        print('Mevcut kolonlar: $existingColumns');

        // Profil fotoğrafı alanını ekle (sadece yoksa)
        if (!existingColumns.contains('profil_fotografi')) {
          await db.execute(
            'ALTER TABLE kisiler ADD COLUMN profil_fotografi TEXT',
          );
          print('✅ profil_fotografi kolonu eklendi');
        }

        print('✅ Profil fotoğrafı sistemi V7 ile eklendi');
      } catch (e) {
        print('❌ V7 migration hatası: $e');
        // Migration başarısız olursa veritabanını sıfırla
        print('🔄 Veritabanı sıfırlanıyor...');
        await _dropAllTables(db);
        await _onCreate(db, 7);
        print('✅ Veritabanı yeniden oluşturuldu');
      }
    }
  }

  Future<void> _createIndexes(Database db) async {
    // Belgeler tablosu indeksleri
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
      'CREATE INDEX idx_belgeler_metadata_hash ON belgeler(metadata_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_belgeler_versiyon ON belgeler(versiyon_numarasi)',
    );

    // Senkron logları indeksleri
    await db.execute(
      'CREATE INDEX idx_senkron_tarih ON senkron_logları(islem_tarihi)',
    );
    await db.execute(
      'CREATE INDEX idx_senkron_durum_log ON senkron_logları(durum)',
    );

    // Senkron state indeksleri
    await db.execute(
      'CREATE INDEX idx_sync_state_hash ON senkron_state(dosya_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_state_durum ON senkron_state(sync_durumu)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_state_zaman ON senkron_state(son_sync_zamani)',
    );

    // Belge versiyonları indeksleri
    await db.execute(
      'CREATE INDEX idx_versiyon_belge ON belge_versiyonlari(belge_id)',
    );
    await db.execute(
      'CREATE INDEX idx_versiyon_hash ON belge_versiyonlari(dosya_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_versiyon_tarih ON belge_versiyonlari(olusturma_tarihi)',
    );

    // Metadata değişiklikleri indeksleri
    await db.execute(
      'CREATE INDEX idx_metadata_entity ON metadata_degisiklikleri(entity_type, entity_id)',
    );
    await db.execute(
      'CREATE INDEX idx_metadata_zaman ON metadata_degisiklikleri(degisiklik_zamani)',
    );
    await db.execute(
      'CREATE INDEX idx_metadata_sync ON metadata_degisiklikleri(sync_edildi)',
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
    await db.execute('DROP TABLE IF EXISTS metadata_degisiklikleri');
    await db.execute('DROP TABLE IF EXISTS belge_versiyonlari');
    await db.execute('DROP TABLE IF EXISTS senkron_state');
    await db.execute('DROP TABLE IF EXISTS senkron_logları');
    await db.execute('DROP TABLE IF EXISTS belgeler');
    await db.execute('DROP TABLE IF EXISTS kategoriler');
    await db.execute('DROP TABLE IF EXISTS kisiler');
  }

  /// Veritabanını manuel olarak sıfırlama (kullanıcı için)
  Future<void> resetDatabase() async {
    try {
      print('🔄 Veritabanı manuel olarak sıfırlanıyor...');

      // Mevcut database bağlantısını kapat
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Veritabanı dosyasını sil
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, Sabitler.VERITABANI_ADI);
      File dbFile = File(path);

      if (await dbFile.exists()) {
        await dbFile.delete();
        print('✅ Veritabanı dosyası silindi');
      }

      // Yeni veritabanını oluştur
      _database = await _initDatabase();
      print('✅ Veritabanı yeniden oluşturuldu');
    } catch (e) {
      print('❌ Veritabanı sıfırlanırken hata: $e');
      rethrow;
    }
  }

  // BELGE CRUD İŞLEMLERİ

  // Belge ekleme - UNIQUE constraint hatası tamamen önlendi
  Future<int> belgeEkle(BelgeModeli belge) async {
    final db = await database;

    // Basit ama etkili çözüm: Direkt REPLACE INTO kullan
    try {
      print('📝 Belge ekleme/güncelleme: ${belge.dosyaAdi}');
      print('   • Hash: ${belge.dosyaHash.substring(0, 16)}...');

      return await db.insert(
        'belgeler',
        belge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Belge ekleme hatası: $e');
      rethrow;
    }
  }

  // Tüm belgeleri getir - PAGINATED
  Future<List<BelgeModeli>> belgeleriGetir({
    int? limit = 20,
    int? offset = 0,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
  }) async {
    final db = await database;

    String whereClause = 'aktif = ?';
    List<dynamic> whereArgs = [1];

    // Tarih filtrelemesi ekle
    if (baslangicTarihi != null && bitisTarihi != null) {
      whereClause += ' AND olusturma_tarihi BETWEEN ? AND ?';
      whereArgs.addAll([
        baslangicTarihi.toIso8601String(),
        bitisTarihi.toIso8601String(),
      ]);
    } else if (baslangicTarihi != null) {
      whereClause += ' AND olusturma_tarihi >= ?';
      whereArgs.add(baslangicTarihi.toIso8601String());
    } else if (bitisTarihi != null) {
      whereClause += ' AND olusturma_tarihi <= ?';
      whereArgs.add(bitisTarihi.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'guncelleme_tarihi DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // Belgeleri kategori ve kişi bilgileri ile birlikte getir - JOIN kullanımı
  Future<List<Map<String, dynamic>>> belgeleriDetayliGetir({
    int? limit = 20,
    int? offset = 0,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
  }) async {
    final db = await database;

    String whereClause = 'b.aktif = 1';
    List<dynamic> whereArgs = [];

    // Tarih filtrelemesi ekle
    if (baslangicTarihi != null && bitisTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi BETWEEN ? AND ?';
      whereArgs.addAll([
        baslangicTarihi.toIso8601String(),
        bitisTarihi.toIso8601String(),
      ]);
    } else if (baslangicTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi >= ?';
      whereArgs.add(baslangicTarihi.toIso8601String());
    } else if (bitisTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi <= ?';
      whereArgs.add(bitisTarihi.toIso8601String());
    }

    final String query = '''
      SELECT 
        b.*,
        k.kategori_adi,
        k.renk_kodu,
        k.simge_kodu,
        ki.ad as kisi_ad,
        ki.soyad as kisi_soyad,
        ki.profil_fotografi as kisi_profil_fotografi
      FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE $whereClause
      ORDER BY b.guncelleme_tarihi DESC
      LIMIT ? OFFSET ?
    ''';

    whereArgs.addAll([limit, offset]);

    final List<Map<String, dynamic>> results = await db.rawQuery(
      query,
      whereArgs,
    );
    return results;
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

  // Kategori ID'ye göre belgeleri getir
  Future<List<BelgeModeli>> kategoriyeGoreBelgeleriGetir(
    int kategoriId, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'kategori_id = ? AND aktif = ?',
      whereArgs: [kategoriId, 1],
      orderBy: 'guncelleme_tarihi DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // Belgeleri kategori ve kişi bilgileri ile birlikte getir - JOIN kullanımı
  Future<List<Map<String, dynamic>>> kategoriyeGoreBelgeleriDetayliGetir(
    int kategoriId, {
    int? limit,
    int? offset,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
  }) async {
    final db = await database;

    // WHERE clause'u dinamik olarak oluştur
    String whereClause = 'b.kategori_id = ? AND b.aktif = 1';
    List<dynamic> parametreler = [kategoriId];

    // Tarih filtrelemesi ekle
    if (baslangicTarihi != null && bitisTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi BETWEEN ? AND ?';
      parametreler.addAll([
        baslangicTarihi.toIso8601String(),
        bitisTarihi.toIso8601String(),
      ]);
    } else if (baslangicTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi >= ?';
      parametreler.add(baslangicTarihi.toIso8601String());
    } else if (bitisTarihi != null) {
      whereClause += ' AND b.olusturma_tarihi <= ?';
      parametreler.add(bitisTarihi.toIso8601String());
    }

    // SQL sorgusunu dinamik olarak oluştur
    String sorgu = '''
      SELECT 
        b.*,
        k.kategori_adi,
        k.renk_kodu,
        k.simge_kodu,
        ki.ad as kisi_ad,
        ki.soyad as kisi_soyad,
        ki.profil_fotografi as kisi_profil_fotografi
      FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE $whereClause
      ORDER BY b.guncelleme_tarihi DESC
    ''';

    if (limit != null) {
      sorgu += ' LIMIT ?';
      parametreler.add(limit);

      if (offset != null) {
        sorgu += ' OFFSET ?';
        parametreler.add(offset);
      }
    }

    print('DEBUG: Kategori sorgusu: $sorgu');
    print('DEBUG: Parametreler: $parametreler');

    final List<Map<String, dynamic>> results = await db.rawQuery(
      sorgu,
      parametreler,
    );
    print('DEBUG: Kategori sorgusu sonucu: ${results.length} belge');

    return results;
  }

  // Hash'e göre belge getir
  Future<BelgeModeli?> belgeGetirByHash(String hash) async {
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

  // Hash'e göre belge bul (alias for consistency)
  Future<BelgeModeli?> belgeBulHash(String hash) async {
    return await belgeGetirByHash(hash);
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

  // Belge silme (aktif durumunu pasif yapma)
  Future<int> belgeSil(int id) async {
    final db = await database;
    return await db.update(
      'belgeler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [id],
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

  // Tarihe göre belge arama
  Future<List<BelgeModeli>> belgeAramaDetayli({
    String? aramaMetni,
    int? ay,
    int? yil,
    int? kategoriId,
    int? kisiId,
  }) async {
    final db = await database;

    // Dinamik WHERE koşulları
    List<String> kosullar = ['b.aktif = 1'];
    List<dynamic> parametreler = [];

    // Metin araması
    if (aramaMetni != null && aramaMetni.isNotEmpty) {
      kosullar.add('''(
        b.dosya_adi LIKE ? OR 
        b.orijinal_dosya_adi LIKE ? OR 
        b.baslik LIKE ? OR 
        b.aciklama LIKE ? OR 
        b.etiketler LIKE ? OR
        k.kategori_adi LIKE ? OR
        (ki.ad || ' ' || ki.soyad) LIKE ?
      )''');
      parametreler.addAll([
        '%$aramaMetni%', // dosya_adi
        '%$aramaMetni%', // orijinal_dosya_adi
        '%$aramaMetni%', // baslik
        '%$aramaMetni%', // aciklama
        '%$aramaMetni%', // etiketler
        '%$aramaMetni%', // kategori_adi
        '%$aramaMetni%', // kişi adı soyadı
      ]);
    }

    // Ay filtresi
    if (ay != null) {
      kosullar.add("strftime('%m', b.olusturma_tarihi) = ?");
      parametreler.add(ay.toString().padLeft(2, '0'));
    }

    // Yıl filtresi
    if (yil != null) {
      kosullar.add("strftime('%Y', b.olusturma_tarihi) = ?");
      parametreler.add(yil.toString());
    }

    // Kategori filtresi
    if (kategoriId != null) {
      kosullar.add('b.kategori_id = ?');
      parametreler.add(kategoriId);
    }

    // Kişi filtresi
    if (kisiId != null) {
      kosullar.add('b.kisi_id = ?');
      parametreler.add(kisiId);
    }

    final sorgu = '''
      SELECT DISTINCT b.* FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE ${kosullar.join(' AND ')}
      ORDER BY b.guncelleme_tarihi DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      sorgu,
      parametreler,
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // KİŞİ CRUD İŞLEMLERİ

  // Kişi ekleme
  Future<int> kisiEkle(KisiModeli kisi) async {
    final db = await database;
    final map = kisi.toMap();
    map.remove('id'); // ID'yi kaldır, otomatik olarak atanacak
    return await db.insert('kisiler', map);
  }

  // Kişi ID'si ile ekleme (senkronizasyon için)
  Future<int> kisiEkleIdIle(KisiModeli kisi) async {
    final db = await database;
    final map = kisi.toMap();
    return await db.insert('kisiler', map);
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

  // Ad ve soyada göre kişi bul
  Future<KisiModeli?> kisiBulAdSoyad(String ad, String soyad) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kisiler',
      where: 'ad = ? AND soyad = ? AND aktif = ?',
      whereArgs: [ad, soyad, 1],
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

  // Kişi silme (aktif durumunu pasif yapma)
  Future<int> kisiSil(int id) async {
    final db = await database;
    return await db.update(
      'kisiler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Kişi arama
  Future<List<KisiModeli>> kisiAra(String sorgu) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kisiler',
      where: '(ad LIKE ? OR soyad LIKE ?) AND aktif = ?',
      whereArgs: ['%$sorgu%', '%$sorgu%', 1],
      orderBy: 'ad ASC, soyad ASC',
    );

    return List.generate(maps.length, (i) {
      return KisiModeli.fromMap(maps[i]);
    });
  }

  // Kişi sayısını getir
  Future<int> kisiSayisi() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM kisiler WHERE aktif = ?',
      [1],
    );
    return result.first['count'] as int;
  }

  // Kişinin belgelerini getir
  Future<List<BelgeModeli>> kisiBelgeleriniGetir(int kisiId) async {
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
    final map = kategori.toMap();
    print('DEBUG: Veritabanına eklenecek map: $map');
    return await db.insert('kategoriler', map);
  }

  // Kategori ID'si ile ekleme (senkronizasyon için)
  Future<int> kategoriEkleIdIle(KategoriModeli kategori) async {
    final db = await database;
    final map = kategori.toMap();
    return await db.insert('kategoriler', map);
  }

  // Ada göre kategori bul
  Future<KategoriModeli?> kategoriBulAd(String ad) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kategoriler',
      where: 'kategori_adi = ? AND aktif = ?',
      whereArgs: [ad, 1],
    );

    if (maps.isNotEmpty) {
      return KategoriModeli.fromMap(maps.first);
    }
    return null;
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

  // ID'ye göre kategori getir
  Future<KategoriModeli?> kategoriGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'kategoriler',
      where: 'id = ? AND aktif = ?',
      whereArgs: [id, 1],
    );

    if (maps.isNotEmpty) {
      return KategoriModeli.fromMap(maps.first);
    }
    return null;
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

  // Kategori silme (aktif durumunu pasif yapma)
  Future<int> kategoriSil(int id) async {
    final db = await database;
    return await db.update(
      'kategoriler',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Kategoriye ait kişileri sil
  Future<int> kategoriKisileriSil(int kategoriId) async {
    final db = await database;

    // Önce kategoriye ait belgelerdeki kişi bağlantılarını al
    final belgelerResult = await db.query(
      'belgeler',
      columns: ['kisi_id'],
      where: 'kategori_id = ? AND aktif = ? AND kisi_id IS NOT NULL',
      whereArgs: [kategoriId, 1],
    );

    // Kategoriye ait belgelerin kişi bağlantılarını kaldır
    await db.update(
      'belgeler',
      {'kisi_id': null},
      where: 'kategori_id = ? AND aktif = ?',
      whereArgs: [kategoriId, 1],
    );

    // Başka belgelerde kullanılmayan kişileri sil
    final kisiIdleri =
        belgelerResult
            .map((e) => e['kisi_id'] as int?)
            .where((id) => id != null)
            .toSet();

    int silinenKisiSayisi = 0;
    for (int? kisiId in kisiIdleri) {
      if (kisiId != null) {
        // Bu kişinin başka belgelerde kullanılıp kullanılmadığını kontrol et
        final kullaniliyorMu = await db.query(
          'belgeler',
          where: 'kisi_id = ? AND aktif = ?',
          whereArgs: [kisiId, 1],
          limit: 1,
        );

        if (kullaniliyorMu.isEmpty) {
          // Kişi başka yerde kullanılmıyorsa sil
          await db.update(
            'kisiler',
            {'aktif': 0},
            where: 'id = ?',
            whereArgs: [kisiId],
          );
          silinenKisiSayisi++;
        }
      }
    }

    return silinenKisiSayisi;
  }

  // Kategoriye ait belgeleri sil
  Future<int> kategoriBelgeleriSil(int kategoriId) async {
    final db = await database;
    return await db.update(
      'belgeler',
      {'aktif': 0},
      where: 'kategori_id = ? AND aktif = ?',
      whereArgs: [kategoriId, 1],
    );
  }

  // Kategoriye ait hem kişileri hem belgeleri sil
  Future<Map<String, int>> kategoriHepsiniSil(int kategoriId) async {
    final db = await database;

    // Önce kişileri sil
    final silinenKisiSayisi = await kategoriKisileriSil(kategoriId);

    // Sonra belgeleri sil
    final silinenBelgeSayisi = await kategoriBelgeleriSil(kategoriId);

    return {'kisiSayisi': silinenKisiSayisi, 'belgeSayisi': silinenBelgeSayisi};
  }

  // Kategoriye ait belge sayılarını getir
  Future<Map<int, int>> kategoriBelgeSayilari() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT kategori_id, COUNT(*) as belge_sayisi
      FROM belgeler
      WHERE aktif = 1
      GROUP BY kategori_id
    ''');

    return {
      for (var row in result)
        (row['kategori_id'] as int): (row['belge_sayisi'] as int),
    };
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
      'SELECT COUNT(*) as count FROM belgeler WHERE aktif = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
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

  // Öncelikli belgeleri getir (ana ekran için)
  Future<List<BelgeModeli>> onceakliBelgeleriGetir({int limit = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'aktif = ?',
      whereArgs: [1],
      orderBy: 'son_erisim_tarihi DESC NULLS LAST, guncelleme_tarihi DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // Öncelikli belgeleri detaylı getir (ana sayfa için)
  Future<List<Map<String, dynamic>>> onceakliBelgeleriDetayliGetir({
    int limit = 5,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT 
        b.*,
        k.kategori_adi,
        k.renk_kodu,
        k.simge_kodu,
        ki.ad as kisi_ad,
        ki.soyad as kisi_soyad,
        ki.profil_fotografi as kisi_profil_fotografi
      FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE b.aktif = 1
      ORDER BY b.guncelleme_tarihi DESC
      LIMIT ?
    ''',
      [limit],
    );

    return results;
  }

  // Belge istatistiklerini getir
  Future<Map<String, dynamic>> belgeIstatistikleriGetir() async {
    final db = await database;

    // Toplam belge sayısı
    final belgeResult = await db.rawQuery(
      'SELECT COUNT(*) as sayi FROM belgeler WHERE aktif = 1',
    );
    final belgeSayisi = Sqflite.firstIntValue(belgeResult) ?? 0;

    // Toplam dosya boyutu
    final boyutResult = await db.rawQuery(
      'SELECT SUM(dosya_boyutu) as toplam FROM belgeler WHERE aktif = 1',
    );
    final toplamBoyut = Sqflite.firstIntValue(boyutResult) ?? 0;

    // Son 30 günde eklenen belge sayısı
    final tarih30GunOnce = DateTime.now().subtract(const Duration(days: 30));
    final yeniResult = await db.rawQuery(
      'SELECT COUNT(*) as sayi FROM belgeler WHERE aktif = 1 AND olusturma_tarihi > ?',
      [tarih30GunOnce.toIso8601String()],
    );
    final yeniBelgeSayisi = Sqflite.firstIntValue(yeniResult) ?? 0;

    // Kategorilere göre dağılım
    final kategoriResult = await db.rawQuery('''
      SELECT 
        k.kategori_adi,
        COUNT(b.id) as belge_sayisi
      FROM kategoriler k
      LEFT JOIN belgeler b ON k.id = b.kategori_id AND b.aktif = 1
      WHERE k.aktif = 1
      GROUP BY k.id, k.kategori_adi
      ORDER BY belge_sayisi DESC
      LIMIT 5
    ''');

    return {
      'toplam_belge_sayisi': belgeSayisi,
      'toplam_dosya_boyutu': toplamBoyut,
      'yeni_belge_sayisi': yeniBelgeSayisi,
      'kategori_dagilimi': kategoriResult,
    };
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

  // Senkron logları - Yeni sistem için hazırlanıyor
  Future<List<Map<String, dynamic>>> senkronLoglariniGetir({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'senkron_logları',
      orderBy: 'islem_tarihi DESC',
      limit: limit,
    );
    return maps;
  }

  // Log ekle
  Future<int> senkronLogEkle(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('senkron_logları', log);
  }

  // Senkron durumuna göre belgeleri getir
  Future<List<BelgeModeli>> senkronDurumunaGoreBelgeleriGetir(
    int senkronDurumu,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'belgeler',
      where: 'senkron_durumu = ? AND aktif = ?',
      whereArgs: [senkronDurumu, 1],
      orderBy: 'guncelleme_tarihi DESC',
    );

    return List.generate(maps.length, (i) {
      return BelgeModeli.fromMap(maps[i]);
    });
  }

  // Belgeler tablosunda senkron durumunu güncelle
  Future<int> belgeSenkronDurumuGuncelle(int belgeId, int durum) async {
    final db = await database;
    return await db.update(
      'belgeler',
      {'senkron_durumu': durum},
      where: 'id = ?',
      whereArgs: [belgeId],
    );
  }

  // Kişinin belge sayısını getir
  Future<int> kisiBelgeSayisi(int kisiId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM belgeler WHERE kisi_id = ? AND aktif = ?',
      [kisiId, 1],
    );
    return result.first['count'] as int;
  }

  // Kişinin belgelerini getir
  Future<List<BelgeModeli>> kisiBelGeleriniGetir(int kisiId) async {
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

  Future<int> belgeVersiyonKaydet(
    int belgeId,
    int versiyonNumarasi,
    String dosyaHash,
    String? metadataHash,
    String? degisiklikAciklamasi,
    String? olusturanCihaz,
  ) async {
    final db = await database;
    return await db.insert('belge_versiyonlari', {
      'belge_id': belgeId,
      'versiyon_numarasi': versiyonNumarasi,
      'dosya_hash': dosyaHash,
      'metadata_hash': metadataHash,
      'degisiklik_aciklamasi': degisiklikAciklamasi,
      'olusturan_cihaz': olusturanCihaz,
      'olusturma_tarihi': DateTime.now().toIso8601String(),
    });
  }

  // Son değişiklikleri getir (raporda belirtilen)
  Future<List<Map<String, dynamic>>> sonDegisiklikleriGetir(
    DateTime since,
  ) async {
    final db = await database;
    return await db.query(
      'belgeler',
      where: 'guncelleme_tarihi > ? AND aktif = ?',
      whereArgs: [since.toIso8601String(), 1],
      orderBy: 'guncelleme_tarihi DESC',
    );
  }

  // Metadata güncelleme (raporda belirtilen)
  Future<int> metadataGuncelle(
    int belgeId,
    String? baslik,
    String? aciklama,
    String? etiketler,
    String? metadataHash,
  ) async {
    final db = await database;
    final guncellemeTarihi = DateTime.now().toIso8601String();

    return await db.update(
      'belgeler',
      {
        if (baslik != null) 'baslik': baslik,
        if (aciklama != null) 'aciklama': aciklama,
        if (etiketler != null) 'etiketler': etiketler,
        if (metadataHash != null) 'metadata_hash': metadataHash,
        'son_metadata_guncelleme': guncellemeTarihi,
        'guncelleme_tarihi': guncellemeTarihi,
      },
      where: 'id = ?',
      whereArgs: [belgeId],
    );
  }

  // ============== SYNC STATE TRACKING ==============

  // Sync state kaydet/güncelle
  Future<void> syncStateGuncelle(
    String dosyaHash,
    String syncDurumu,
    String? cihazId,
    String? metadataHash,
  ) async {
    final db = await database;
    final tarih = DateTime.now().toIso8601String();

    await db.execute(
      '''
      INSERT OR REPLACE INTO senkron_state 
      (dosya_hash, son_sync_zamani, sync_durumu, cihaz_id, metadata_hash, olusturma_tarihi)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [dosyaHash, tarih, syncDurumu, cihazId, metadataHash, tarih],
    );
  }

  // Sync state getir
  Future<Map<String, dynamic>?> syncStateGetir(String dosyaHash) async {
    final db = await database;
    final maps = await db.query(
      'senkron_state',
      where: 'dosya_hash = ?',
      whereArgs: [dosyaHash],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  // Sync edilmemiş dosyaları getir
  Future<List<String>> syncEdilmemisHashleriGetir() async {
    final db = await database;
    final maps = await db.query(
      'senkron_state',
      columns: ['dosya_hash'],
      where: 'sync_durumu != ?',
      whereArgs: ['SYNCED'],
    );
    return maps.map((m) => m['dosya_hash'] as String).toList();
  }

  // Tüm sync state'leri getir
  Future<List<Map<String, dynamic>>> tumSyncStateleriniGetir() async {
    final db = await database;
    return await db.query('senkron_state', orderBy: 'son_sync_zamani DESC');
  }

  // Sync state temizle
  Future<void> syncStateTemizle(String? dosyaHash) async {
    final db = await database;
    if (dosyaHash != null) {
      await db.delete(
        'senkron_state',
        where: 'dosya_hash = ?',
        whereArgs: [dosyaHash],
      );
    } else {
      await db.delete('senkron_state');
    }
  }

  // ============== METADATA CHANGE TRACKING ==============

  // Metadata değişikliği kaydet
  Future<int> metadataDegisikligiKaydet(
    String entityType,
    int entityId,
    String degisiklikTipi,
    String? eskiDeger,
    String? yeniDeger,
    String? cihazId,
  ) async {
    final db = await database;
    return await db.insert('metadata_degisiklikleri', {
      'entity_type': entityType,
      'entity_id': entityId,
      'degisiklik_tipi': degisiklikTipi,
      'eski_deger': eskiDeger,
      'yeni_deger': yeniDeger,
      'degisiklik_zamani': DateTime.now().toIso8601String(),
      'cihaz_id': cihazId,
      'sync_edildi': 0,
    });
  }

  // Sync edilmemiş metadata değişikliklerini getir
  Future<List<Map<String, dynamic>>>
  syncEdilmemisMetadataDegisiklikleriniGetir() async {
    final db = await database;
    return await db.query(
      'metadata_degisiklikleri',
      where: 'sync_edildi = ?',
      whereArgs: [0],
      orderBy: 'degisiklik_zamani ASC',
    );
  }

  // Metadata değişikliğini sync edildi olarak işaretle
  Future<void> metadataDegisikligiSyncEdiOlarakIsaretle(int id) async {
    final db = await database;
    await db.update(
      'metadata_degisiklikleri',
      {'sync_edildi': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Son zamandan beri metadata değişikliklerini getir
  Future<List<Map<String, dynamic>>>
  sonZamandanBeriMetadataDegisiklikleriniGetir(DateTime since) async {
    final db = await database;
    return await db.query(
      'metadata_degisiklikleri',
      where: 'degisiklik_zamani > ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'degisiklik_zamani DESC',
    );
  }

  // ============== BELGE VERSİYON METODLARI ==============

  // Belgenin tüm versiyonlarını getir
  Future<List<Map<String, dynamic>>> belgeVersiyonlariniGetir(
    int belgeId,
  ) async {
    final db = await database;
    return await db.query(
      'belge_versiyonlari',
      where: 'belge_id = ?',
      whereArgs: [belgeId],
      orderBy: 'versiyon_numarasi DESC',
    );
  }

  // Belgenin son versiyon numarasını getir
  Future<int> belgeninSonVersiyonNumarasiniGetir(int belgeId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT MAX(versiyon_numarasi) as max_versiyon 
      FROM belge_versiyonlari 
      WHERE belge_id = ?
    ''',
      [belgeId],
    );

    return (result.first['max_versiyon'] as int?) ?? 0;
  }

  // Belgenin versiyon numarasını güncelle
  Future<void> belgeVersiyonNumarasiniGuncelle(
    int belgeId,
    int yeniVersiyon,
  ) async {
    final db = await database;
    await db.update(
      'belgeler',
      {
        'versiyon_numarasi': yeniVersiyon,
        'guncelleme_tarihi': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [belgeId],
    );
  }
}
