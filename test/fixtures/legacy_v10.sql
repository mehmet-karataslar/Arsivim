-- Source: v2.5.2-debug-final (5d94850), arsiv_uygulamasi/lib/services/veritabani_servisi.dart _onCreate.
-- Schema version from that tag: 10. Binary/source correspondence was not reproducibly recorded.
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
      );
CREATE TABLE kategoriler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kategori_adi TEXT NOT NULL UNIQUE,
        renk_kodu TEXT DEFAULT '#2196F3',
        simge_kodu TEXT DEFAULT 'folder',
        aciklama TEXT,
        olusturma_tarihi TEXT NOT NULL,
        aktif INTEGER DEFAULT 1,
        belge_sayisi INTEGER DEFAULT 0
      );
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
      );
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
      );
CREATE TABLE senkron_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dosya_hash TEXT NOT NULL UNIQUE,
        son_sync_zamani TEXT NOT NULL,
        sync_durumu TEXT NOT NULL DEFAULT 'PENDING',
        cihaz_id TEXT,
        metadata_hash TEXT,
        olusturma_tarihi TEXT NOT NULL
      );
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
      );
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
      );
PRAGMA user_version = 10;
