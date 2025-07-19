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
      rethrow;
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

    // Yeni tablolar - Invoice ve Tax (v8)
    await _createInvoiceAndTaxTables(db);

    // Varsayılan kategorileri ekle
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Database upgrade: $oldVersion -> $newVersion');

    // Migration işlemini yap
    await _performMigration(db, oldVersion, newVersion);
  }

  /// Veritabanı bütünlüğünü kontrol et ve eksik tabloları oluştur
  Future<void> _checkDatabaseIntegrity(Database db) async {
    try {
      // Temel tabloların varlığını kontrol et
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final requiredTables = ['kisiler', 'kategoriler', 'belgeler', 'invoices', 'taxes', 'activities', 'reminders'];
      final existingTables = tables.map((t) => t['name'] as String).toList();
      
      bool hasCreatedTables = false;

      for (final table in requiredTables) {
        if (!existingTables.contains(table)) {
          print('⚠️ Eksik tablo tespit edildi: $table - Otomatik oluşturuluyor...');
          
          // Eksik tabloları oluştur
          if (table == 'activities' || table == 'reminders') {
            await _createCalendarTables(db);
            print('✅ Calendar tabloları (activities, reminders) oluşturuldu');
            hasCreatedTables = true;
          } else if (table == 'invoices' || table == 'taxes') {
            await _createInvoiceAndTaxTables(db);
            print('✅ Invoice ve Tax tabloları oluşturuldu');
            hasCreatedTables = true;
          }
        }
      }
      
      if (hasCreatedTables) {
        print('✅ Eksik tablolar başarıyla oluşturuldu');
      }

      // Basit bir query ile veritabanının çalıştığını kontrol et
      await db.rawQuery('SELECT COUNT(*) FROM kisiler');
      await db.rawQuery('SELECT COUNT(*) FROM kategoriler');
      await db.rawQuery('SELECT COUNT(*) FROM belgeler');
      await db.rawQuery('SELECT COUNT(*) FROM activities');
      await db.rawQuery('SELECT COUNT(*) FROM reminders');

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
        rethrow;
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
        rethrow;
      }
    }

    if (oldVersion < 8) {
      // V8 Migration - Invoice ve Tax tablolarını ekle
      try {
        print('🔄 V8 Migration başlatılıyor - Invoice ve Tax tabloları ekleniyor...');

        // Invoice ve Tax tablolarını oluştur
        await _createInvoiceAndTaxTables(db);

        print('✅ Invoice ve Tax tabloları V8 ile eklendi');
      } catch (e) {
        print('❌ V8 migration hatası: $e');
        rethrow;
      }
    }

    if (oldVersion < 9) {
      // V9 Migration - Calendar Activities ve Reminders tablolarını ekle
      try {
        print('🔄 V9 Migration başlatılıyor - Calendar Activities ve Reminders tabloları ekleniyor...');

        // Activities ve Reminders tablolarını oluştur
        await _createCalendarTables(db);

        print('✅ Calendar Activities ve Reminders tabloları V9 ile eklendi');
      } catch (e) {
        print('❌ V9 migration hatası: $e');
        rethrow;
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

  Future<void> _createInvoiceAndTaxTables(Database db) async {
    // Invoices tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kisi_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL UNIQUE,
        issue_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'PENDING',
        invoice_type TEXT NOT NULL DEFAULT 'INCOMING',
        supplier_name TEXT,
        supplier_address TEXT,
        supplier_tax_number TEXT,
        supplier_ust_id_nr TEXT,
        customer_name TEXT,
        customer_address TEXT,
        customer_tax_number TEXT,
        customer_ust_id_nr TEXT,
        currency TEXT NOT NULL DEFAULT 'EUR',
        net_amount REAL NOT NULL,
        tax_amount REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 19.0,
        gross_amount REAL NOT NULL,
        payment_terms TEXT,
        payment_method TEXT,
        reference_number TEXT,
        description TEXT,
        notes TEXT,
        finanzamt TEXT,
        elster_data TEXT,
        attached_documents TEXT,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1,
        FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
      )
    ''');

    // Taxes tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS taxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kisi_id INTEGER NOT NULL,
        tax_year INTEGER NOT NULL,
        tax_period TEXT NOT NULL,
        tax_period_start TEXT NOT NULL,
        tax_period_end TEXT NOT NULL,
        tax_status TEXT NOT NULL DEFAULT 'DRAFT',
        tax_type TEXT NOT NULL,
        tax_category TEXT NOT NULL,
        calculated_amount REAL NOT NULL DEFAULT 0.0,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        remaining_amount REAL NOT NULL DEFAULT 0.0,
        submission_deadline TEXT,
        submission_date TEXT,
        payment_deadline TEXT,
        payment_date TEXT,
        tax_office TEXT,
        tax_number TEXT,
        ust_id_nr TEXT,
        elster_data TEXT,
        previous_year_carryover REAL DEFAULT 0.0,
        deductions_amount REAL DEFAULT 0.0,
        additional_tax REAL DEFAULT 0.0,
        notes TEXT,
        attached_documents TEXT,
        olusturma_tarihi TEXT NOT NULL,
        guncelleme_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1,
        FOREIGN KEY (kisi_id) REFERENCES kisiler(id)
      )
    ''');

    // Invoice ve Tax tablolarının indekslerini oluştur
    await _createInvoiceAndTaxIndexes(db);
  }

  Future<void> _createInvoiceAndTaxIndexes(Database db) async {
    // Invoice indeksleri
    await db.execute('CREATE INDEX idx_invoices_kisi ON invoices(kisi_id)');
    await db.execute('CREATE INDEX idx_invoices_number ON invoices(invoice_number)');
    await db.execute('CREATE INDEX idx_invoices_status ON invoices(payment_status)');
    await db.execute('CREATE INDEX idx_invoices_type ON invoices(invoice_type)');
    await db.execute('CREATE INDEX idx_invoices_due_date ON invoices(due_date)');
    await db.execute('CREATE INDEX idx_invoices_issue_date ON invoices(issue_date)');
    await db.execute('CREATE INDEX idx_invoices_aktif ON invoices(aktif)');

    // Tax indeksleri
    await db.execute('CREATE INDEX idx_taxes_kisi ON taxes(kisi_id)');
    await db.execute('CREATE INDEX idx_taxes_year ON taxes(tax_year)');
    await db.execute('CREATE INDEX idx_taxes_period ON taxes(tax_period)');
    await db.execute('CREATE INDEX idx_taxes_status ON taxes(tax_status)');
    await db.execute('CREATE INDEX idx_taxes_type ON taxes(tax_type)');
    await db.execute('CREATE INDEX idx_taxes_category ON taxes(tax_category)');
    await db.execute('CREATE INDEX idx_taxes_aktif ON taxes(aktif)');
  }

  Future<void> _createCalendarTables(Database db) async {
    // Activities tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        related_item_id TEXT,
        related_item_type TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Reminders tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        reminder_date TEXT NOT NULL,
        recurrence_type INTEGER NOT NULL DEFAULT 0,
        recurrence_interval INTEGER,
        priority INTEGER NOT NULL DEFAULT 1,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        is_auto_generated INTEGER NOT NULL DEFAULT 0,
        related_item_id TEXT,
        related_item_type TEXT,
        metadata TEXT,
        next_occurrence TEXT,
        last_triggered TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Calendar tablolarının indekslerini oluştur
    await _createCalendarIndexes(db);
  }

  Future<void> _createCalendarIndexes(Database db) async {
    // Activities indeksleri
    await db.execute('CREATE INDEX idx_activities_date ON activities(activity_date)');
    await db.execute('CREATE INDEX idx_activities_type ON activities(type)');
    await db.execute('CREATE INDEX idx_activities_related ON activities(related_item_id, related_item_type)');

    // Reminders indeksleri
    await db.execute('CREATE INDEX idx_reminders_date ON reminders(reminder_date)');
    await db.execute('CREATE INDEX idx_reminders_next_occurrence ON reminders(next_occurrence)');
    await db.execute('CREATE INDEX idx_reminders_enabled ON reminders(is_enabled)');
    await db.execute('CREATE INDEX idx_reminders_auto_generated ON reminders(is_auto_generated)');
    await db.execute('CREATE INDEX idx_reminders_related ON reminders(related_item_id, related_item_type)');
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

  /// Mevcut kategorilerin tarihlerini güncelle - senkronizasyon optimizasyonu için
  Future<void> _mevcutKategorilerTarihGuncelle() async {
    final db = await database;

    // Mevcut kategorilerin sayısını kontrol et
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM kategoriler WHERE aktif = 1',
    );
    final mevcutKategoriSayisi = result.first['count'] as int;

    // Eğer kategoriler varsa ve tarihler bugün ise, geriye çek
    if (mevcutKategoriSayisi > 0) {
      final bugun = DateTime.now();
      final bugunBaslangic = DateTime(bugun.year, bugun.month, bugun.day);

      // Bugün oluşturulmuş kategorileri bul
      final bugunkuKategoriler = await db.query(
        'kategoriler',
        where: 'aktif = 1 AND olusturma_tarihi >= ?',
        whereArgs: [bugunBaslangic.toIso8601String()],
      );

      if (bugunkuKategoriler.isNotEmpty) {
        print(
          '📅 ${bugunkuKategoriler.length} kategori tarihi güncelleniyor (mevcut kategoriler senkronizasyondan çıkarılıyor)',
        );

        // Mevcut kategorilerin tarihlerini 1 hafta öncesine çek
        final eskiTarih = DateTime.now().subtract(const Duration(days: 7));

        await db.update(
          'kategoriler',
          {'olusturma_tarihi': eskiTarih.toIso8601String()},
          where: 'aktif = 1 AND olusturma_tarihi >= ?',
          whereArgs: [bugunBaslangic.toIso8601String()],
        );

        print('✅ Mevcut kategoriler senkronizasyon listesinden çıkarıldı');
      }
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

    // Minimum karakter kontrolü
    if (aramaMetni != null && aramaMetni.trim().length < 1) {
      // Çok kısa arama metni için boş liste döndür
      return [];
    }

    // Dinamik WHERE koşulları
    List<String> kosullar = ['b.aktif = 1'];
    List<dynamic> parametreler = [];

    // Gelişmiş metin araması
    if (aramaMetni != null && aramaMetni.trim().isNotEmpty) {
      final arananMetin = aramaMetni.trim().toLowerCase();
      final aramaSozcukleri =
          arananMetin.split(' ').where((s) => s.length >= 1).toList();

      if (aramaSozcukleri.isNotEmpty) {
        // Çoklu arama koşulları oluştur
        List<String> aramaKosullari = [];

        for (final sozcuk in aramaSozcukleri) {
          final sozcukKosulu = '''(
            b.dosya_adi LIKE ? OR 
            b.orijinal_dosya_adi LIKE ? OR 
            b.baslik LIKE ? OR 
            b.aciklama LIKE ? OR 
            b.etiketler LIKE ? OR
            k.kategori_adi LIKE ? OR
            (ki.ad || ' ' || ki.soyad) LIKE ?
          )''';

          aramaKosullari.add(sozcukKosulu);

          // Her sözcük için parametreleri ekle
          parametreler.addAll([
            '%$sozcuk%', // dosya_adi
            '%$sozcuk%', // orijinal_dosya_adi
            '%$sozcuk%', // baslik
            '%$sozcuk%', // aciklama
            '%$sozcuk%', // etiketler
            '%$sozcuk%', // kategori_adi
            '%$sozcuk%', // kişi adı soyadı
          ]);
        }

        // Tüm sözcüklerin en az birinde eşleşme olmalı
        kosullar.add('(${aramaKosullari.join(' OR ')})');
      }
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

    // Gelişmiş sıralama - tam eşleşmeler önce gelsin
    String siralamaKosulu = 'b.guncelleme_tarihi DESC';

    if (aramaMetni != null && aramaMetni.trim().isNotEmpty) {
      final arananMetin = aramaMetni.trim().toLowerCase();

      // Tam eşleşme kontrolü için CASE WHEN yapısı
      siralamaKosulu = '''
        CASE 
          WHEN LOWER(b.dosya_adi) = '$arananMetin' THEN 1
          WHEN LOWER(b.orijinal_dosya_adi) = '$arananMetin' THEN 2
          WHEN LOWER(b.baslik) = '$arananMetin' THEN 3
          WHEN LOWER(b.dosya_adi) LIKE '$arananMetin%' THEN 4
          WHEN LOWER(b.orijinal_dosya_adi) LIKE '$arananMetin%' THEN 5
          WHEN LOWER(b.baslik) LIKE '$arananMetin%' THEN 6
          WHEN LOWER(k.kategori_adi) = '$arananMetin' THEN 7
          WHEN LOWER(ki.ad || ' ' || ki.soyad) = '$arananMetin' THEN 8
          ELSE 9
        END ASC,
        b.guncelleme_tarihi DESC
      ''';
    }

    final sorgu = '''
      SELECT DISTINCT b.* FROM belgeler b
      LEFT JOIN kategoriler k ON b.kategori_id = k.id
      LEFT JOIN kisiler ki ON b.kisi_id = ki.id
      WHERE ${kosullar.join(' AND ')}
      ORDER BY $siralamaKosulu
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

  // Belge hash'ine göre belge bul
  Future<BelgeModeli?> belgeBulHash(String hash) async {
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

  // Tüm kategorileri getir
  Future<List<KategoriModeli>> kategorileriGetir() async {
    final db = await database;

    // Önce mevcut kategorilerin tarihlerini güncelle
    await _mevcutKategorilerTarihGuncelle();

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

  // ============== INVOICE CRUD İŞLEMLERİ ==============

  // Invoice ekleme
  Future<int> invoiceEkle(Map<String, dynamic> invoice) async {
    final db = await database;
    return await db.insert('invoices', invoice);
  }

  // Tüm invoice'ları getir
  Future<List<Map<String, dynamic>>> invoicesGetir({
    int? kisiId,
    String? paymentStatus,
    String? invoiceType,
  }) async {
    final db = await database;
    
    String whereClause = 'aktif = ?';
    List<dynamic> whereArgs = [1];

    if (kisiId != null) {
      whereClause += ' AND kisi_id = ?';
      whereArgs.add(kisiId);
    }

    if (paymentStatus != null) {
      whereClause += ' AND payment_status = ?';
      whereArgs.add(paymentStatus);
    }

    if (invoiceType != null) {
      whereClause += ' AND invoice_type = ?';
      whereArgs.add(invoiceType);
    }

    return await db.query(
      'invoices',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'issue_date DESC',
    );
  }

  // Invoice'ları kişi bilgileri ile birlikte getir
  Future<List<Map<String, dynamic>>> invoicesDetayliGetir({
    int? kisiId,
    String? paymentStatus,
  }) async {
    final db = await database;
    
    String whereClause = 'i.aktif = ?';
    List<dynamic> whereArgs = [1];

    if (kisiId != null) {
      whereClause += ' AND i.kisi_id = ?';
      whereArgs.add(kisiId);
    }

    if (paymentStatus != null) {
      whereClause += ' AND i.payment_status = ?';
      whereArgs.add(paymentStatus);
    }

    return await db.rawQuery('''
      SELECT i.*, k.ad, k.soyad
      FROM invoices i
      LEFT JOIN kisiler k ON i.kisi_id = k.id
      WHERE $whereClause
      ORDER BY i.issue_date DESC
    ''', whereArgs);
  }

  // ID'ye göre invoice getir
  Future<Map<String, dynamic>?> invoiceGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'id = ? AND aktif = ?',
      whereArgs: [id, 1],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Invoice güncelleme
  Future<int> invoiceGuncelle(int id, Map<String, dynamic> invoice) async {
    final db = await database;
    invoice['guncelleme_tarihi'] = DateTime.now().toIso8601String();
    return await db.update(
      'invoices',
      invoice,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Invoice silme (aktif durumunu pasif yapma)
  Future<int> invoiceSil(int id) async {
    final db = await database;
    return await db.update(
      'invoices',
      {'aktif': 0, 'guncelleme_tarihi': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Invoice istatistikleri
  Future<Map<String, dynamic>> invoiceIstatistikleri({int? kisiId}) async {
    final db = await database;
    
    String whereClause = 'aktif = 1';
    List<dynamic> whereArgs = [];

    if (kisiId != null) {
      whereClause += ' AND kisi_id = ?';
      whereArgs.add(kisiId);
    }

    // Toplam tutar
    final totalResult = await db.rawQuery('''
      SELECT 
        SUM(gross_amount) as total_amount,
        COUNT(*) as total_count
      FROM invoices 
      WHERE $whereClause
    ''', whereArgs);

    // Ödeme durumuna göre sayılar
    final statusResult = await db.rawQuery('''
      SELECT 
        payment_status,
        COUNT(*) as count,
        SUM(gross_amount) as amount
      FROM invoices 
      WHERE $whereClause
      GROUP BY payment_status
    ''', whereArgs);

    // Vadesi geçen faturalar
    final overdueResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(gross_amount) as amount
      FROM invoices 
      WHERE $whereClause AND due_date < ? AND payment_status = 'PENDING'
    ''', [...whereArgs, DateTime.now().toIso8601String()]);

    return {
      'total_amount': totalResult.first['total_amount'] ?? 0.0,
      'total_count': totalResult.first['total_count'] ?? 0,
      'status_breakdown': statusResult,
      'overdue_count': overdueResult.first['count'] ?? 0,
      'overdue_amount': overdueResult.first['amount'] ?? 0.0,
    };
  }

  // ============== TAX CRUD İŞLEMLERİ ==============

  // Tax ekleme
  Future<int> taxEkle(Map<String, dynamic> tax) async {
    final db = await database;
    return await db.insert('taxes', tax);
  }

  // Invoice numarasına göre getir
  Future<Map<String, dynamic>?> invoiceGetirByNumber(String invoiceNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'invoice_number = ? AND aktif = ?',
      whereArgs: [invoiceNumber, 1],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Tüm tax'ları getir
  Future<List<Map<String, dynamic>>> taxesGetir({
    int? kisiId,
    String? taxStatus,
    int? taxYear,
  }) async {
    final db = await database;
    
    String whereClause = 'aktif = ?';
    List<dynamic> whereArgs = [1];

    if (kisiId != null) {
      whereClause += ' AND kisi_id = ?';
      whereArgs.add(kisiId);
    }

    if (taxStatus != null) {
      whereClause += ' AND tax_status = ?';
      whereArgs.add(taxStatus);
    }

    if (taxYear != null) {
      whereClause += ' AND tax_year = ?';
      whereArgs.add(taxYear);
    }

    return await db.query(
      'taxes',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'tax_year DESC, tax_period DESC',
    );
  }

  // Tax'ları kişi bilgileri ile birlikte getir
  Future<List<Map<String, dynamic>>> taxesDetayliGetir({
    int? kisiId,
    String? taxStatus,
  }) async {
    final db = await database;
    
    String whereClause = 't.aktif = ?';
    List<dynamic> whereArgs = [1];

    if (kisiId != null) {
      whereClause += ' AND t.kisi_id = ?';
      whereArgs.add(kisiId);
    }

    if (taxStatus != null) {
      whereClause += ' AND t.tax_status = ?';
      whereArgs.add(taxStatus);
    }

    return await db.rawQuery('''
      SELECT t.*, k.ad, k.soyad
      FROM taxes t
      LEFT JOIN kisiler k ON t.kisi_id = k.id
      WHERE $whereClause
      ORDER BY t.tax_year DESC, t.tax_period DESC
    ''', whereArgs);
  }

  // ID'ye göre tax getir
  Future<Map<String, dynamic>?> taxGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'taxes',
      where: 'id = ? AND aktif = ?',
      whereArgs: [id, 1],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Döneme göre tax getir  
  Future<Map<String, dynamic>?> taxGetirByPeriod(int kisiId, int taxYear, int taxPeriod) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'taxes',
      where: 'kisi_id = ? AND tax_year = ? AND tax_period = ? AND aktif = ?',
      whereArgs: [kisiId, taxYear, taxPeriod, 1],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Tax güncelleme
  Future<int> taxGuncelle(int id, Map<String, dynamic> tax) async {
    final db = await database;
    tax['guncelleme_tarihi'] = DateTime.now().toIso8601String();
    return await db.update(
      'taxes',
      tax,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tax silme (aktif durumunu pasif yapma)
  Future<int> taxSil(int id) async {
    final db = await database;
    return await db.update(
      'taxes',
      {'aktif': 0, 'guncelleme_tarihi': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tax istatistikleri
  Future<Map<String, dynamic>> taxIstatistikleri({int? kisiId}) async {
    final db = await database;
    
    String whereClause = 'aktif = 1';
    List<dynamic> whereArgs = [];

    if (kisiId != null) {
      whereClause += ' AND kisi_id = ?';
      whereArgs.add(kisiId);
    }

    // Toplam hesaplanan vergi
    final totalResult = await db.rawQuery('''
      SELECT 
        SUM(calculated_amount) as total_calculated,
        SUM(paid_amount) as total_paid,
        COUNT(*) as total_count
      FROM taxes 
      WHERE $whereClause
    ''', whereArgs);

    // Durum'a göre sayılar
    final statusResult = await db.rawQuery('''
      SELECT 
        tax_status,
        COUNT(*) as count,
        SUM(calculated_amount) as calculated_amount,
        SUM(paid_amount) as paid_amount
      FROM taxes 
      WHERE $whereClause
      GROUP BY tax_status
    ''', whereArgs);

    // Bekleyen vergiler
    final pendingResult = await db.rawQuery('''
      SELECT COUNT(*) as count, SUM(remaining_amount) as amount
      FROM taxes 
      WHERE $whereClause AND tax_status IN ('READY', 'SUBMITTED')
    ''', [...whereArgs]);

    return {
      'total_calculated': totalResult.first['total_calculated'] ?? 0.0,
      'total_paid': totalResult.first['total_paid'] ?? 0.0,
      'total_count': totalResult.first['total_count'] ?? 0,
      'status_breakdown': statusResult,
      'pending_count': pendingResult.first['count'] ?? 0,
      'pending_amount': pendingResult.first['amount'] ?? 0.0,
    };
  }

  // ========================
  // ACTIVITIES CRUD METHODS
  // ========================

  // Activity ekleme
  Future<int> activityEkle(Map<String, dynamic> activity) async {
    final db = await database;
    try {
      return await db.insert('activities', activity);
    } catch (e) {
      throw Exception('Activity ekleme hatası: $e');
    }
  }

  // Tüm activities'leri getir
  Future<List<Map<String, dynamic>>> activitiesGetir() async {
    final db = await database;
    return await db.query(
      'activities',
      orderBy: 'activity_date DESC, created_at DESC',
    );
  }

  // Tarih aralığına göre activities getir
  Future<List<Map<String, dynamic>>> activitiesGetirByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    return await db.query(
      'activities',
      where: 'activity_date >= ? AND activity_date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'activity_date DESC, created_at DESC',
    );
  }

  // Belirli bir tarihteki activities getir
  Future<List<Map<String, dynamic>>> activitiesGetirByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return await db.query(
      'activities',
      where: 'activity_date >= ? AND activity_date <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'activity_date DESC, created_at DESC',
    );
  }

  // Related item'a göre activities getir
  Future<List<Map<String, dynamic>>> activitiesGetirByRelatedItem(String relatedItemId, String relatedItemType) async {
    final db = await database;
    return await db.query(
      'activities',
      where: 'related_item_id = ? AND related_item_type = ?',
      whereArgs: [relatedItemId, relatedItemType],
      orderBy: 'activity_date DESC, created_at DESC',
    );
  }

  // Activity güncelleme
  Future<int> activityGuncelle(int id, Map<String, dynamic> activity) async {
    final db = await database;
    activity['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'activities',
      activity,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Activity silme
  Future<int> activitySil(int id) async {
    final db = await database;
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========================
  // REMINDERS CRUD METHODS
  // ========================

  // Reminder ekleme
  Future<int> reminderEkle(Map<String, dynamic> reminder) async {
    final db = await database;
    try {
      return await db.insert('reminders', reminder);
    } catch (e) {
      throw Exception('Reminder ekleme hatası: $e');
    }
  }

  // Tüm reminders'ları getir
  Future<List<Map<String, dynamic>>> remindersGetir() async {
    final db = await database;
    return await db.query(
      'reminders',
      orderBy: 'reminder_date ASC, created_at DESC',
    );
  }

  // Aktif reminders'ları getir
  Future<List<Map<String, dynamic>>> remindersGetirActive() async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'is_enabled = ?',
      whereArgs: [1],
      orderBy: 'reminder_date ASC, created_at DESC',
    );
  }

  // Belirli bir tarihteki reminders getir
  Future<List<Map<String, dynamic>>> remindersGetirByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return await db.query(
      'reminders',
      where: '(reminder_date >= ? AND reminder_date <= ?) OR (next_occurrence >= ? AND next_occurrence <= ?)',
      whereArgs: [
        startOfDay.toIso8601String(), 
        endOfDay.toIso8601String(),
        startOfDay.toIso8601String(), 
        endOfDay.toIso8601String(),
      ],
      orderBy: 'reminder_date ASC, created_at DESC',
    );
  }

  // Related item'a göre reminders getir
  Future<List<Map<String, dynamic>>> remindersGetirByRelatedItem(String relatedItemId, String relatedItemType) async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'related_item_id = ? AND related_item_type = ?',
      whereArgs: [relatedItemId, relatedItemType],
      orderBy: 'reminder_date ASC, created_at DESC',
    );
  }

  // Reminder getir by ID
  Future<Map<String, dynamic>?> reminderGetir(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );

    return maps.isNotEmpty ? maps.first : null;
  }

  // Reminder güncelleme
  Future<int> reminderGuncelle(int id, Map<String, dynamic> reminder) async {
    final db = await database;
    reminder['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Reminder silme
  Future<int> reminderSil(int id) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Overdue reminders getir
  Future<List<Map<String, dynamic>>> remindersGetirOverdue() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    return await db.query(
      'reminders',
      where: 'is_enabled = ? AND ((next_occurrence IS NOT NULL AND next_occurrence < ?) OR (next_occurrence IS NULL AND reminder_date < ?))',
      whereArgs: [1, now, now],
      orderBy: 'reminder_date ASC',
    );
  }

  // Today's reminders getir
  Future<List<Map<String, dynamic>>> remindersGetirToday() async {
    final today = DateTime.now();
    return await remindersGetirByDate(today);
  }
}
