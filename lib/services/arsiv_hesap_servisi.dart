import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../utils/kimlik_normalizasyonu.dart';
import 'parola_servisi.dart';

class HesapHatasi implements Exception {
  final String mesaj;
  HesapHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

/// Hesap sahipligi kisilerden ayridir. Yerel kisi/belge ID'leri korunur.
class ArsivHesapServisi {
  final Database db;
  ArsivHesapServisi(this.db);
  static final _hazirliklar = Expando<Future<void>>();

  static String kimlik() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> hazirla() async {
    try {
      await (_hazirliklar[db] ??= _hazirla());
    } catch (_) {
      _hazirliklar[db] = null;
      rethrow;
    }
  }

  Future<void> _hazirla() async {
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='arsiv_hesabi'",
    );
    if (exists.isEmpty && db.path != ':memory:') {
      final accounts = await db.query(
        'kisiler',
        columns: ['id'],
        where: "sifre IS NOT NULL AND sifre <> ''",
      );
      if (accounts.isNotEmpty) {
        final dir = await Directory(
          p.join(p.dirname(db.path), 'Yedekler'),
        ).create(recursive: true);
        final folder = await dir.createTemp('hesap-gecisi-');
        final snapshot = File(p.join(folder.path, 'arsiv.db'));
        await db.execute('VACUUM INTO ?', [snapshot.path]);
        if (!await snapshot.exists() || await snapshot.length() < 512) {
          throw HesapHatasi(
            'Hesap gecisi yedegi olusturulamadi; mevcut kayitlar degistirilmedi.',
          );
        }
        await File(p.join(folder.path, 'dogrulama.json')).writeAsString(
          jsonEncode({
            'boyut': await snapshot.length(),
            'sha256': (await sha256.bind(snapshot.openRead()).first).toString(),
            'zaman': DateTime.now().toUtc().toIso8601String(),
          }),
          flush: true,
        );
      }
    }
    await db.transaction((tx) async {
      await tx.execute('''CREATE TABLE IF NOT EXISTS arsiv_hesabi (
        id INTEGER PRIMARY KEY CHECK(id = 1), arsiv_id TEXT NOT NULL,
        yonetici_id TEXT NOT NULL, yerel_kisi_id INTEGER NOT NULL UNIQUE,
        bagli INTEGER NOT NULL DEFAULT 0 CHECK(bagli IN (0,1)))''');
      await tx.execute(
        '''CREATE TABLE IF NOT EXISTS hesap_eslesme_gecmisi (
        id INTEGER PRIMARY KEY AUTOINCREMENT, onceki_arsiv_id TEXT,
        yeni_arsiv_id TEXT NOT NULL, yerel_kisi_id INTEGER NOT NULL, zaman TEXT NOT NULL)''',
      );
      await tx.execute('''CREATE TABLE IF NOT EXISTS aktarim_kimlikleri (
        tur TEXT NOT NULL, yerel_id INTEGER NOT NULL, evrensel_id TEXT NOT NULL,
        PRIMARY KEY(tur, evrensel_id))''');
      await tx.execute('''CREATE TRIGGER IF NOT EXISTS arsiv_sahibi_silinemez
        BEFORE DELETE ON kisiler WHEN EXISTS(SELECT 1 FROM arsiv_hesabi WHERE yerel_kisi_id = OLD.id)
        BEGIN SELECT RAISE(ABORT, 'Arsiv yoneticisi silinemez'); END''');
      await tx.execute(
        '''CREATE TRIGGER IF NOT EXISTS arsiv_sahibi_korunur
        BEFORE UPDATE ON kisiler WHEN EXISTS(SELECT 1 FROM arsiv_hesabi WHERE yerel_kisi_id = OLD.id)
        AND (NEW.id != OLD.id OR NEW.aktif != 1 OR NEW.kullanici_adi IS NOT OLD.kullanici_adi
             OR NEW.sifre IS NULL OR NEW.sifre = '')
        BEGIN SELECT RAISE(ABORT, 'Arsiv yoneticisinin hesabi devre disi birakilamaz'); END''',
      );
    });
  }

  Future<Map<String, dynamic>?> hesap() async {
    await hazirla();
    final rows = await db.query('arsiv_hesabi');
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.single);
  }

  Future<Map<String, dynamic>> _sahip(DatabaseExecutor tx, int kisiId) async {
    final owners = await tx.query('arsiv_hesabi');
    if (owners.length != 1 || owners.single['yerel_kisi_id'] != kisiId) {
      throw HesapHatasi('Bu arsivin tek yonetici hesabi ile giris yapin.');
    }
    final people = await tx.query(
      'kisiler',
      where: 'id = ? AND aktif = 1',
      whereArgs: [kisiId],
    );
    if (people.length != 1 ||
        KimlikNormalizasyonu.kullanici(people.single['kullanici_adi']) ==
            null ||
        people.single['sifre'] == null) {
      throw HesapHatasi(
        'Yonetici hesabi bulunamadi veya devre disi. Mevcut arsiv korundu.',
      );
    }
    return Map<String, dynamic>.from(people.single);
  }

  Future<Map<String, dynamic>> yonetici(int id) async {
    await hazirla();
    return _sahip(db, id);
  }

  Future<Map<String, dynamic>> giris(
    String username,
    String password, {
    int? secilenKisiId,
  }) async {
    await hazirla();
    final key = KimlikNormalizasyonu.kullanici(username);
    if (key == null || password.isEmpty || password.length > 1024) {
      throw HesapHatasi('Kullanici adi veya sifre gecersiz.');
    }
    final all = await db.query(
      'kisiler',
      where: 'aktif = 1 AND sifre IS NOT NULL',
    );
    final candidates =
        all
            .where(
              (r) => KimlikNormalizasyonu.kullanici(r['kullanici_adi']) == key,
            )
            .toList();
    // Eski harf-farki kayitlarini otomatik birlestirmeyiz. Secim de parola ister.
    final owner = await hesap();
    final selectedId = secilenKisiId ?? owner?['yerel_kisi_id'];
    final selected =
        selectedId == null
            ? candidates
            : candidates.where((r) => r['id'] == selectedId).toList();
    if (selected.length != 1)
      throw HesapHatasi(
        candidates.length > 1
            ? 'Bu kullanici adiyla birden fazla eski kayit var. Giris ekraninda mevcut hesap kaydini secin; kayitlar korunuyor.'
            : 'Kullanici adi veya sifre yanlis.',
      );
    final person = selected.single;
    final oldHash = person['sifre'] as String;
    if (!await ParolaServisi.dogrula(password, oldHash))
      throw HesapHatasi('Kullanici adi veya sifre yanlis.');
    final newHash =
        oldHash.startsWith('pbkdf2-sha256\$')
            ? oldHash
            : await ParolaServisi.olustur(password);
    await db.transaction((tx) async {
      final current =
          (await tx.query(
            'kisiler',
            where: 'id = ? AND aktif = 1',
            whereArgs: [person['id']],
          )).single;
      if (current['sifre'] != oldHash ||
          current['kullanici_adi'] != person['kullanici_adi']) {
        throw HesapHatasi('Hesap degisti; yeniden giris yapin.');
      }
      final owners = await tx.query('arsiv_hesabi');
      if (owners.isEmpty) {
        final admins = await tx.query(
          'kisiler',
          columns: ['id'],
          where:
              "aktif = 1 AND UPPER(kullanici_tipi) = 'ADMIN' AND sifre IS NOT NULL AND sifre <> '' AND kullanici_adi IS NOT NULL AND kullanici_adi <> ''",
        );
        if (admins.isNotEmpty && !admins.any((r) => r['id'] == person['id'])) {
          throw HesapHatasi(
            'Mevcut yonetici hesabi ile giris yapin; diger kisiler korunuyor.',
          );
        }
        await tx.insert('arsiv_hesabi', {
          'id': 1,
          'arsiv_id': kimlik(),
          'yonetici_id': kimlik(),
          'yerel_kisi_id': person['id'],
          'bagli': 0,
        });
      }
      await _sahip(tx, person['id'] as int);
      await tx.update(
        'kisiler',
        {'sifre': newHash},
        where: 'id = ?',
        whereArgs: [person['id']],
      );
    });
    return {...person, 'sifre': newHash, 'kullanici_tipi': 'ADMIN'};
  }

  Future<List<Map<String, dynamic>>> girisAdaylari(String username) async {
    await hazirla();
    final owner = await hesap();
    final rows = await db.query(
      'kisiler',
      columns: ['id', 'ad', 'soyad', 'kullanici_adi'],
      where: "aktif = 1 AND sifre IS NOT NULL AND sifre <> ''",
    );
    return rows
        .where(
          (r) =>
              KimlikNormalizasyonu.kullanici(r['kullanici_adi']) ==
                  KimlikNormalizasyonu.kullanici(username) &&
              (owner == null || r['id'] == owner['yerel_kisi_id']),
        )
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<int> kaydet(Map<String, dynamic> person, String password) async {
    await hazirla();
    if (password.length < 6 ||
        password.length > 1024 ||
        KimlikNormalizasyonu.kullanici(person['kullanici_adi']) == null)
      throw HesapHatasi('Kullanici adi veya sifre gecersiz.');
    final passwordHash = await ParolaServisi.olustur(password);
    return db.transaction((tx) async {
      final accounts = await tx.query(
        'kisiler',
        columns: ['id'],
        where: "sifre IS NOT NULL AND sifre <> ''",
      );
      if ((await tx.query('arsiv_hesabi')).isNotEmpty || accounts.isNotEmpty) {
        throw HesapHatasi(
          'Bu cihazda hesap var. Yeni yonetici yerine mevcut hesabiniza giris yapin.',
        );
      }
      final people = await tx.query('kisiler', columns: ['kullanici_adi']);
      if (people.any(
        (r) =>
            KimlikNormalizasyonu.kullanici(r['kullanici_adi']) ==
            KimlikNormalizasyonu.kullanici(person['kullanici_adi']),
      )) {
        throw HesapHatasi(
          'Bu kullanici adi mevcut bir kisiye ait. Kisi kaydi korundu.',
        );
      }
      final id = await tx.insert(
        'kisiler',
        {...person, 'sifre': passwordHash, 'kullanici_tipi': 'NORMAL'}
          ..remove('id'),
      );
      await tx.insert('arsiv_hesabi', {
        'id': 1,
        'arsiv_id': kimlik(),
        'yonetici_id': kimlik(),
        'yerel_kisi_id': id,
        'bagli': 0,
      });
      return id;
    });
  }

  Future<Map<String, dynamic>> tanitim(int kisiId) async {
    final person = await yonetici(kisiId);
    final account = (await hesap())!;
    return {
      for (final k in ['arsiv_id', 'yonetici_id', 'bagli']) k: account[k],
      for (final k in ['ad', 'soyad', 'kullanici_adi']) k: person[k],
    };
  }

  static void tanitimDogrula(Map<String, dynamic> remote) {
    for (final key in ['arsiv_id', 'yonetici_id']) {
      if (remote[key] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(remote[key]))
        throw HesapHatasi('Hesap kimligi gecersiz.');
    }
    for (final key in ['ad', 'soyad', 'kullanici_adi']) {
      if (remote[key] is! String ||
          (remote[key] as String).trim().isEmpty ||
          (remote[key] as String).length > 256) {
        throw HesapHatasi('Hesap bilgileri eksik.');
      }
    }
    if (remote['bagli'] != 0 && remote['bagli'] != 1)
      throw HesapHatasi('Hesap baglanti durumu gecersiz.');
  }

  Future<void> baglantiKontrol(int kisiId, Map<String, dynamic> remote) async {
    tanitimDogrula(remote);
    final local = await tanitim(kisiId);
    if (!KimlikNormalizasyonu.ayniKisi(local, remote))
      throw HesapHatasi(
        'Iki cihazdaki yonetici adi ve kullanici adi uyusmuyor. Hesaplar degistirilmedi.',
      );
    if (local['bagli'] == 1 &&
        (local['arsiv_id'] != remote['arsiv_id'] ||
            local['yonetici_id'] != remote['yonetici_id'])) {
      throw HesapHatasi(
        'Bu cihaz zaten baska bir arsive bagli. Otomatik hesap birlestirilmedi.',
      );
    }
  }

  /// QR'yi gosteren cihazin hesabi ortak kimliktir. Yerel eski ID korunur.
  Future<void> bagla(int kisiId, Map<String, dynamic> remote) async {
    await baglantiKontrol(kisiId, remote);
    await db.transaction((tx) async {
      final person = await _sahip(tx, kisiId);
      final old = (await tx.query('arsiv_hesabi')).single;
      if (!KimlikNormalizasyonu.ayniKisi(person, remote) ||
          (old['bagli'] == 1 &&
              (old['arsiv_id'] != remote['arsiv_id'] ||
                  old['yonetici_id'] != remote['yonetici_id']))) {
        throw HesapHatasi('Hesap eslesme sirasinda degisti.');
      }
      final aliases = await tx.query(
        'aktarim_kimlikleri',
        where: 'tur = ? AND evrensel_id = ?',
        whereArgs: ['kisi', remote['yonetici_id']],
      );
      if (aliases.any((r) => r['yerel_id'] != kisiId))
        throw HesapHatasi(
          'Yonetici kimligi baska bir kisiye bagli; kayitlar korundu.',
        );
      if (aliases.isEmpty)
        await tx.insert('aktarim_kimlikleri', {
          'tur': 'kisi',
          'yerel_id': kisiId,
          'evrensel_id': remote['yonetici_id'],
        });
      await tx.update('arsiv_hesabi', {
        'arsiv_id': remote['arsiv_id'],
        'yonetici_id': remote['yonetici_id'],
        'bagli': 1,
      }, where: 'id = 1');
      if (old['arsiv_id'] != remote['arsiv_id'] || old['bagli'] != 1) {
        await tx.insert('hesap_eslesme_gecmisi', {
          'onceki_arsiv_id': old['arsiv_id'],
          'yeni_arsiv_id': remote['arsiv_id'],
          'yerel_kisi_id': kisiId,
          'zaman': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
  }
}
