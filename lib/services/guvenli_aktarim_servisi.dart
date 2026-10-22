import 'document_links.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/belge_modeli.dart';
import '../utils/kimlik_normalizasyonu.dart';

class AktarimHatasi implements Exception {
  String? kisiEvrenselId;
  final String kod;
  final String mesaj;
  final List<Map<String, dynamic>> adaylar;
  AktarimHatasi(this.kod, this.mesaj, [this.adaylar = const []]);
  Map<String, dynamic> toMap() => {
    'success': false,
    'kod': kod,
    'error': mesaj,
    'adaylar': adaylar,
    if (kisiEvrenselId != null) 'kisi_evrensel_id': kisiEvrenselId,
  };
  @override
  String toString() => mesaj;
}

/// PC ve mobil ayni protokolu ve ayni kayit kurallarini kullanir.
/// Yerel sayisal kimlikler karsi cihaza birincil anahtar olarak yazilmaz.
class GuvenliAktarimServisi {
  static const surum = 3;
  static const azamiMetadata = 256 * 1024;
  static const azamiReferans = 8 * 1024 * 1024;
  static const azamiDosya = 16 * 1024 * 1024 * 1024;
  final Database db;
  final Directory belgeler;
  final Future<void> Function()? yetkiKontrol;
  GuvenliAktarimServisi(this.db, this.belgeler, {this.yetkiKontrol});

  static String kimlik() =>
      List.generate(
        24,
        (_) => Random.secure().nextInt(256),
      ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  static Future<String> hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> hazirla() async {
    await DocumentLinks.prepare(db);
    await db.execute('''CREATE TABLE IF NOT EXISTS aktarim_kimlikleri (
      tur TEXT NOT NULL, yerel_id INTEGER NOT NULL, evrensel_id TEXT NOT NULL,
      PRIMARY KEY(tur, evrensel_id))''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_aktarim_yerel
      ON aktarim_kimlikleri(tur, yerel_id)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS aktarim_gecmisi (
      id INTEGER PRIMARY KEY AUTOINCREMENT, aktarim_id TEXT,
      dosya_hash TEXT, metadata_hash TEXT, durum TEXT NOT NULL,
      mesaj TEXT, zaman TEXT NOT NULL)''');
  }

  Future<String> _evrenselId(DatabaseExecutor tx, String tur, int id) async {
    if (tur == 'kisi' &&
        (await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='arsiv_hesabi'",
        )).isNotEmpty) {
      final owner = await tx.query(
        'arsiv_hesabi',
        where: 'yerel_kisi_id = ?',
        whereArgs: [id],
      );
      if (owner.isNotEmpty) return owner.single['yonetici_id'] as String;
    }
    final rows = await tx.query(
      'aktarim_kimlikleri',
      where: 'tur = ? AND yerel_id = ?',
      whereArgs: [tur, id],
      orderBy: 'rowid',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['evrensel_id'] as String;
    final value = kimlik();
    await tx.insert('aktarim_kimlikleri', {
      'tur': tur,
      'yerel_id': id,
      'evrensel_id': value,
    });
    return value;
  }

  static String _json(Object? value) {
    Object? canonical(Object? v) {
      if (v is Map) {
        final keys = v.keys.cast<String>().toList()..sort();
        return {for (final k in keys) k: canonical(v[k])};
      }
      if (v is List) return v.map(canonical).toList();
      return v;
    }

    return jsonEncode(canonical(value));
  }

  static const belgeAlanlari = [
    'dosya_adi',
    'orijinal_dosya_adi',
    'dosya_boyutu',
    'dosya_tipi',
    'dosya_hash',
    'baslik',
    'aciklama',
    'etiketler',
    'olusturma_tarihi',
    'guncelleme_tarihi',
    'son_erisim_tarihi',
    'aktif',
  ];

  static Map<String, dynamic> belgeMetadata(Map<String, dynamic> row) {
    final result = {for (final key in belgeAlanlari) key: row[key]};
    result['etiketler'] = BelgeModeli.etiketleriCoz(row['etiketler']);
    for (final key in [
      'olusturma_tarihi',
      'guncelleme_tarihi',
      'son_erisim_tarihi',
    ]) {
      if (result[key] != null) {
        result[key] =
            DateTime.parse(result[key] as String).toUtc().toIso8601String();
      }
    }
    return result;
  }

  static String metadataHash(Map<String, dynamic> paket) =>
      sha256
          .convert(
            utf8.encode(
              _json({
                if (paket.containsKey('baglantilar'))
                  'baglantilar': paket['baglantilar'],
                for (final key in ['belge', 'kisi', 'kategori', 'profil'])
                  key: paket[key],
              }),
            ),
          )
          .toString();

  Future<Map<String, dynamic>> paketOlustur(int belgeId) async {
    await hazirla();
    return db.transaction((tx) => _paketOlustur(tx, belgeId));
  }

  Future<Map<String, dynamic>> _paketOlustur(
    DatabaseExecutor tx,
    int belgeId,
  ) async {
    final rows = await tx.query(
      'belgeler',
      where: 'id = ? AND aktif = 1',
      whereArgs: [belgeId],
    );
    if (rows.length != 1)
      throw AktarimHatasi('KAYNAK_YOK', 'Kaynak belge bulunamadi.');
    final row = rows.single;
    final paket = <String, dynamic>{
      'surum': surum,
      'belge': belgeMetadata(row),
    };
    final extra = <String, List<Map<String, dynamic>>>{
      'kisi': [],
      'kategori': [],
    };
    for (final tur in ['kisi', 'kategori']) {
      final ids =
          {
            ...[row['${tur}_id']].whereType<int>(),
            ...BelgeModeli.idsCoz(row['${tur}_ids']),
          }.toList();
      paket[tur] = null;
      for (final id in ids) {
        final rows = await tx.query(
          tur == 'kisi' ? 'kisiler' : 'kategoriler',
          where: 'id = ? AND aktif = 1',
          whereArgs: [id],
        );
        if (rows.length != 1)
          throw AktarimHatasi('BAGIMLILIK_YOK', '$tur kaydi eksik veya pasif.');
        final kaynak = rows.single;
        final alanlar =
            tur == 'kisi'
                ? [
                  'ad',
                  'soyad',
                  'kullanici_adi',
                  'olusturma_tarihi',
                  'guncelleme_tarihi',
                ]
                : [
                  'kategori_adi',
                  'renk_kodu',
                  'simge_kodu',
                  'aciklama',
                  'olusturma_tarihi',
                ];
        final ref = <String, dynamic>{
          for (final k in alanlar) k: kaynak[k],
          'evrensel_id': await _evrenselId(tx, tur, id),
        };
        if (paket[tur] == null) {
          paket[tur] = ref;
        } else {
          extra[tur]!.add(ref);
        }
      }
    }
    if (extra.values.any((v) => v.isNotEmpty)) paket['baglantilar'] = extra;
    paket['metadata_hash'] = metadataHash(paket);
    paket['evrensel_belge_id'] = await _evrenselId(tx, 'belge', belgeId);
    paket['aktarim_id'] =
        '${paket['evrensel_belge_id']}:${paket['metadata_hash']}';
    dogrula(paket);
    return paket;
  }

  Future<void> gonderimiOnayla(
    int belgeId,
    Map<String, dynamic> paket,
    Map<String, dynamic> yanit,
  ) async {
    if (!onayGecerli(paket, yanit))
      throw AktarimHatasi('ONAY', 'Alici onayi gecersiz.');
    await db.transaction((tx) async {
      final guncel = await _paketOlustur(tx, belgeId);
      if (guncel['metadata_hash'] != paket['metadata_hash']) {
        throw AktarimHatasi(
          'KAYNAK_DEGISTI',
          'Kaynak bilgiler aktarim sirasinda degisti; yeniden kontrol gerekli.',
        );
      }
      await tx.update(
        'belgeler',
        {'senkron_durumu': SenkronDurumu.SENKRONIZE.index},
        where: 'id = ?',
        whereArgs: [belgeId],
      );
      await _gecmis(tx, paket, 'gonderildi', null);
    });
  }

  Future<Map<String, dynamic>> referansPaketi(String tur, int id) async {
    if (!['kisi', 'kategori'].contains(tur))
      throw AktarimHatasi('SEMA', 'Kayit turu gecersiz.');
    await hazirla();
    return db.transaction((tx) async {
      final rows = await tx.query(
        tur == 'kisi' ? 'kisiler' : 'kategoriler',
        where: 'id = ? AND aktif = 1',
        whereArgs: [id],
      );
      if (rows.length != 1)
        throw AktarimHatasi('KAYNAK_YOK', 'Kayit bulunamadi.');
      final row = rows.single;
      final keys =
          tur == 'kisi'
              ? [
                'ad',
                'soyad',
                'kullanici_adi',
                'olusturma_tarihi',
                'guncelleme_tarihi',
              ]
              : [
                'kategori_adi',
                'renk_kodu',
                'simge_kodu',
                'aciklama',
                'olusturma_tarihi',
              ];
      final paket = <String, dynamic>{
        'surum': surum,
        'tur': tur,
        tur: {
          for (final k in keys) k: row[k],
          'evrensel_id': await _evrenselId(tx, tur, id),
        },
      };
      final fotoYolu = row['profil_fotografi'];
      if (tur == 'kisi' && fotoYolu is String && fotoYolu.isNotEmpty) {
        final foto = File(fotoYolu);
        if (!await foto.exists() || await foto.length() > 5 * 1024 * 1024) {
          throw AktarimHatasi(
            'PROFIL',
            'Profil fotografi eksik veya 5 MiB sinirini asiyor.',
          );
        }
        final bytes = await foto.readAsBytes();
        paket['profil'] = {
          'uzanti': p.extension(fotoYolu).toLowerCase(),
          'boyut': bytes.length,
          'hash': sha256.convert(bytes).toString(),
          'icerik': base64Encode(bytes),
        };
      }
      paket['metadata_hash'] = metadataHash(paket);
      return paket;
    });
  }

  Future<Map<String, dynamic>> referansAl(Map<String, dynamic> paket) async {
    final tur = paket['tur'];
    if (paket['surum'] != surum ||
        !['kisi', 'kategori'].contains(tur) ||
        paket['metadata_hash'] != metadataHash(paket)) {
      throw AktarimHatasi('SEMA', 'Kayit paketi dogrulanamadi.');
    }
    final row = _map(paket[tur], 'kayit');
    _metin(row['evrensel_id'], 'evrensel_id', max: 160);
    _tarih(row['olusturma_tarihi'], 'olusturma_tarihi');
    if (tur == 'kisi') {
      _metin(row['ad'], 'ad');
      _metin(row['soyad'], 'soyad');
      _tarih(row['guncelleme_tarihi'], 'guncelleme_tarihi');
      if (row['kullanici_adi'] != null)
        _metin(row['kullanici_adi'], 'kullanici_adi');
    } else {
      for (final k in ['kategori_adi', 'renk_kodu', 'simge_kodu']) {
        _metin(row[k], k);
      }
      if (row['aciklama'] != null)
        _metin(row['aciklama'], 'aciklama', bos: true, max: 65536);
    }
    await hazirla();
    Directory? fotoKlasoru;
    File? foto;
    var fotoKullanildi = false;
    var committed = false;
    try {
      if (paket['profil'] != null) {
        if (tur != 'kisi')
          throw AktarimHatasi('PROFIL', 'Kategori profil fotografi tasiyamaz.');
        final data = _map(paket['profil'], 'profil');
        final ext = data['uzanti'];
        if (ext is! String ||
            !RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(ext) ||
            data['icerik'] is! String ||
            (data['icerik'] as String).length > 7 * 1024 * 1024) {
          throw AktarimHatasi('PROFIL', 'Profil fotografi yapisi gecersiz.');
        }
        final bytes = base64Decode(data['icerik'] as String);
        if (bytes.isEmpty ||
            bytes.length > 5 * 1024 * 1024 ||
            bytes.length != data['boyut'] ||
            sha256.convert(bytes).toString() != data['hash'])
          throw AktarimHatasi('PROFIL', 'Profil fotografi dogrulanamadi.');
        await belgeler.create(recursive: true);
        fotoKlasoru = await belgeler.createTemp('profil-');
        foto = File(p.join(fotoKlasoru.path, 'profil$ext'));
        await foto.writeAsBytes(bytes, flush: true);
        if (await hash(foto) != data['hash'])
          throw AktarimHatasi(
            'PROFIL',
            'Kaydedilen profil fotografi dogrulanamadi.',
          );
      }
      await yetkiKontrol?.call();
      final result = await db.transaction((tx) async {
        if (tur == 'kisi') {
          final id = await _kisi(tx, paket, yaz: true);
          if (foto != null) {
            final current =
                (await tx.query(
                  'kisiler',
                  where: 'id = ?',
                  whereArgs: [id],
                )).single;
            final old = current['profil_fotografi'];
            if (old is String && old.isNotEmpty && await File(old).exists()) {
              if (await hash(File(old)) != paket['profil']['hash'])
                throw AktarimHatasi(
                  'PROFIL_CAKISMASI',
                  'Hedefte farkli profil fotografi var; korunuyor.',
                );
            } else {
              await tx.update(
                'kisiler',
                {'profil_fotografi': foto!.path},
                where: 'id = ?',
                whereArgs: [id],
              );
              fotoKullanildi = true;
            }
          }
        } else {
          await _kategori(tx, paket, yaz: true);
        }
        return {'success': true, 'metadata_hash': paket['metadata_hash']};
      });
      committed = true;
      return result;
    } finally {
      if ((!committed || !fotoKullanildi) &&
          fotoKlasoru != null &&
          await fotoKlasoru.exists()) {
        await fotoKlasoru.delete(recursive: true);
      }
    }
  }

  static Map<String, dynamic> _map(dynamic value, String alan) {
    if (value is! Map) throw AktarimHatasi('SEMA', '$alan yapisi gecersiz.');
    return Map<String, dynamic>.from(value);
  }

  static void _metin(
    dynamic value,
    String alan, {
    bool bos = false,
    int max = 4096,
  }) {
    if (value is! String ||
        (!bos && value.trim().isEmpty) ||
        value.length > max ||
        value.contains('\x00')) {
      throw AktarimHatasi('SEMA', '$alan alani gecersiz.');
    }
  }

  static void _tarih(dynamic value, String alan) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw AktarimHatasi('TARIH', '$alan tarihi gecersiz.');
    }
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
    ).firstMatch(value);
    if (m == null)
      throw AktarimHatasi('TARIH', '$alan ISO tarih biciminde olmali.');
    final yil = int.parse(m[1]!);
    final ay = int.parse(m[2]!);
    final gun = int.parse(m[3]!);
    final tarih = DateTime.utc(yil, ay, gun);
    if (tarih.year != yil ||
        tarih.month != ay ||
        tarih.day != gun ||
        int.parse(m[4]!) > 23 ||
        int.parse(m[5]!) > 59 ||
        int.parse(m[6]!) > 59) {
      throw AktarimHatasi('TARIH', '$alan takvim tarihi gecersiz.');
    }
  }

  static void dogrula(Map<String, dynamic> paket) {
    if (![2, surum].contains(paket['surum']))
      throw AktarimHatasi(
        'SURUM',
        'Iki cihazi da guncelleyin. Aktarim surumu desteklenmiyor.',
      );
    if (utf8.encode(jsonEncode(paket)).length > azamiMetadata)
      throw AktarimHatasi('BOYUT', 'Belge bilgileri cok buyuk.');
    _metin(paket['aktarim_id'], 'aktarim_id', max: 160);
    _metin(paket['evrensel_belge_id'], 'evrensel_belge_id', max: 80);
    if (paket['aktarim_id'] !=
        '${paket['evrensel_belge_id']}:${paket['metadata_hash']}') {
      throw AktarimHatasi(
        'KIMLIK',
        'Aktarim kimligi belge kimligi ve metadata ile uyusmuyor.',
      );
    }
    final b = _map(paket['belge'], 'belge');
    if (b.length != belgeAlanlari.length ||
        !belgeAlanlari.every(b.containsKey)) {
      throw AktarimHatasi(
        'SEMA',
        'Belge alanlari eksik veya tanimsiz alanlar var.',
      );
    }
    for (final alan in ['dosya_adi', 'orijinal_dosya_adi']) {
      _metin(b[alan], alan, max: 240);
      final ad = b[alan] as String;
      if (ad == '.' ||
          ad == '..' ||
          RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(ad) ||
          ad.endsWith('.') ||
          ad.endsWith(' ')) {
        throw AktarimHatasi('DOSYA_ADI', 'Dosya adi guvenli degil: $alan');
      }
      if (RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(ad)) {
        throw AktarimHatasi(
          'DOSYA_ADI',
          'Bu dosya adi Windows tarafinda kullanilamaz.',
        );
      }
    }
    if (b['dosya_boyutu'] is! int ||
        b['dosya_boyutu'] < 0 ||
        b['dosya_boyutu'] > azamiDosya) {
      throw AktarimHatasi(
        'BOYUT',
        'Dosya boyutu gecersiz veya 16 GiB sinirini asiyor.',
      );
    }
    if (b['dosya_hash'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(b['dosya_hash'])) {
      throw AktarimHatasi('HASH', 'SHA-256 dosya ozeti gecersiz.');
    }
    _metin(b['dosya_tipi'], 'dosya_tipi', bos: true, max: 32);
    for (final alan in ['dosya_adi', 'orijinal_dosya_adi']) {
      if (p.extension(b[alan]).replaceFirst('.', '').toLowerCase() !=
          (b['dosya_tipi'] as String).toLowerCase()) {
        throw AktarimHatasi(
          'DOSYA_TIPI',
          '$alan uzantisi ile tur bilgisi uyusmuyor. Mevcut belge korundu.',
        );
      }
    }
    for (final k in ['olusturma_tarihi', 'guncelleme_tarihi']) {
      _tarih(b[k], k);
    }
    if (b['son_erisim_tarihi'] != null)
      _tarih(b['son_erisim_tarihi'], 'son_erisim_tarihi');
    for (final k in ['baslik', 'aciklama']) {
      if (b[k] != null) _metin(b[k], k, bos: true, max: 65536);
    }
    if (b['aktif'] != 1 ||
        b['etiketler'] is! List ||
        (b['etiketler'] as List).any((v) => v is! String || v.length > 1024)) {
      throw AktarimHatasi('SEMA', 'Etiketler veya aktiflik bilgisi gecersiz.');
    }
    for (final tur in ['kisi', 'kategori']) {
      if (paket[tur] == null) continue;
      final ref = _map(paket[tur], tur);
      _metin(ref['evrensel_id'], '$tur evrensel_id', max: 160);
      _tarih(ref['olusturma_tarihi'], '$tur olusturma_tarihi');
      if (tur == 'kisi') {
        _metin(ref['ad'], 'ad');
        _metin(ref['soyad'], 'soyad');
        _tarih(ref['guncelleme_tarihi'], 'kisi guncelleme_tarihi');
        if (ref['kullanici_adi'] != null)
          _metin(ref['kullanici_adi'], 'kullanici_adi');
      } else {
        for (final k in ['kategori_adi', 'renk_kodu', 'simge_kodu']) {
          _metin(ref[k], k);
        }
        if (ref['aciklama'] != null)
          _metin(ref['aciklama'], 'kategori aciklama', bos: true, max: 65536);
      }
    }
    if (paket.containsKey('baglantilar')) {
      if (paket['surum'] != surum)
        throw AktarimHatasi(
          'SURUM',
          'Çoklu bağlantı için iki cihazı da güncelleyin.',
        );
      final links = _map(paket['baglantilar'], 'baglantilar');
      if (links.keys.any((k) => !['kisi', 'kategori'].contains(k)))
        throw AktarimHatasi('SEMA', 'Bağlantı türü geçersiz.');
      for (final kind in ['kisi', 'kategori']) {
        final refs = links[kind];
        if (refs is! List || refs.length > 100)
          throw AktarimHatasi('SEMA', 'Bağlantı listesi geçersiz.');
        if (refs.isNotEmpty && paket[kind] == null) {
          throw AktarimHatasi('SEMA', 'Ek bağlantıların ana bağlantısı eksik.');
        }
        final seen = <String>{
          if (paket[kind] != null) paket[kind]['evrensel_id'] as String,
        };
        for (final ref in refs) {
          _map(ref, kind);
          final copy = Map<String, dynamic>.from(paket)..remove('baglantilar');
          copy[kind] = ref;
          copy['metadata_hash'] = metadataHash(copy);
          copy['aktarim_id'] =
              '${copy['evrensel_belge_id']}:${copy['metadata_hash']}';
          dogrula(copy);
          if (!seen.add(ref['evrensel_id'] as String))
            throw AktarimHatasi('SEMA', 'Tekrarlı bağlantı.');
        }
      }
    }
    if (paket['metadata_hash'] != metadataHash(paket))
      throw AktarimHatasi('METADATA_HASH', 'Belge bilgileri dogrulanamadi.');
  }

  Future<int?> _kisi(
    DatabaseExecutor tx,
    Map<String, dynamic> paket, {
    required bool yaz,
  }) async {
    if (paket['kisi'] == null) return null;
    final k = _map(paket['kisi'], 'kisi');
    final eslesme = await tx.query(
      'aktarim_kimlikleri',
      where: 'tur = ? AND evrensel_id = ?',
      whereArgs: ['kisi', k['evrensel_id']],
    );
    if (eslesme.isNotEmpty) {
      final id = eslesme.single['yerel_id'] as int;
      final rows = await tx.query(
        'kisiler',
        where: 'id = ? AND aktif = 1',
        whereArgs: [id],
      );
      if (rows.length != 1 || !KimlikNormalizasyonu.ayniKisi(rows.single, k)) {
        throw AktarimHatasi(
          'KISI_CAKISMASI',
          'Kayitli kisi kimligi ile kisi bilgileri uyusmuyor.',
        );
      }
      return id;
    }
    final kisiler = await tx.query(
      'kisiler',
      columns: ['id', 'ad', 'soyad', 'kullanici_adi', 'aktif'],
    );
    final kullanici = KimlikNormalizasyonu.kullanici(k['kullanici_adi']);
    final adaylar =
        kisiler
            .where(
              (r) =>
                  (KimlikNormalizasyonu.metin(r['ad'] as String) ==
                          KimlikNormalizasyonu.metin(k['ad'] as String) &&
                      KimlikNormalizasyonu.metin(r['soyad'] as String) ==
                          KimlikNormalizasyonu.metin(k['soyad'] as String)) ||
                  (kullanici != null &&
                      KimlikNormalizasyonu.kullanici(r['kullanici_adi']) ==
                          kullanici),
            )
            .toList();
    final secim = paket['hedef_kisi_id'];
    int? id;
    if (secim is int && secim > 0) {
      if (!adaylar.any(
        (r) =>
            r['id'] == secim &&
            r['aktif'] == 1 &&
            KimlikNormalizasyonu.ayniKisi(r, k),
      )) {
        throw AktarimHatasi(
          'KISI_CAKISMASI',
          'Secilen kisi bilgileri kaynak kisiyle uyusmuyor.',
        );
      }
      id = secim;
    } else if (secim == 0 &&
        !adaylar.any(
          (a) =>
              kullanici != null &&
              KimlikNormalizasyonu.kullanici(a['kullanici_adi']) == kullanici,
        )) {
      if (!yaz) return -1;
      id = await tx.insert('kisiler', {
        'ad': k['ad'],
        'soyad': k['soyad'],
        'kullanici_adi': k['kullanici_adi'],
        'olusturma_tarihi': k['olusturma_tarihi'],
        'guncelleme_tarihi': k['guncelleme_tarihi'],
        'aktif': 1,
        'kullanici_tipi': 'NORMAL',
      });
    } else {
      throw AktarimHatasi(
        'KISI_SECIMI',
        adaylar.isEmpty
            ? '${k['ad']} ${k['soyad']} hedefte yeni kisi olarak olusturulsun mu?'
            : '${k['ad']} ${k['soyad']} icin hedef kisiyi secin. Ad-soyad tek basina yeterli degil.',
        adaylar.map((r) => Map<String, dynamic>.from(r)).toList(),
      );
    }
    if (yaz)
      await tx.insert('aktarim_kimlikleri', {
        'tur': 'kisi',
        'yerel_id': id,
        'evrensel_id': k['evrensel_id'],
      });
    return id;
  }

  Future<int?> _kategori(
    DatabaseExecutor tx,
    Map<String, dynamic> paket, {
    required bool yaz,
  }) async {
    if (paket['kategori'] == null) return null;
    final k = _map(paket['kategori'], 'kategori');
    final rows = await tx.query(
      'kategoriler',
      where: 'kategori_adi = ?',
      whereArgs: [k['kategori_adi']],
    );
    final kimlikler = await tx.query(
      'aktarim_kimlikleri',
      where: 'tur = ? AND evrensel_id = ?',
      whereArgs: ['kategori', k['evrensel_id']],
    );
    if (kimlikler.isNotEmpty &&
        (rows.isEmpty || rows.single['id'] != kimlikler.single['yerel_id'])) {
      throw AktarimHatasi(
        'KATEGORI_CAKISMASI',
        'Kategori kimligi hedefte farkli bir kategoriye bagli.',
      );
    }
    if (rows.isNotEmpty) {
      if (rows.length != 1 || rows.single['aktif'] != 1)
        throw AktarimHatasi(
          'KATEGORI_CAKISMASI',
          'Hedef kategori pasif veya belirsiz.',
        );
      for (final alan in ['renk_kodu', 'simge_kodu', 'aciklama']) {
        if (rows.single[alan] != k[alan])
          throw AktarimHatasi(
            'KATEGORI_CAKISMASI',
            '${k['kategori_adi']}: $alan bilgisi farkli.',
          );
      }
      final id = rows.single['id'] as int;
      if (yaz && kimlikler.isEmpty)
        await tx.insert('aktarim_kimlikleri', {
          'tur': 'kategori',
          'yerel_id': id,
          'evrensel_id': k['evrensel_id'],
        });
      return id;
    }
    if (!yaz) return -1;
    final id = await tx.insert('kategoriler', {
      for (final key in [
        'kategori_adi',
        'renk_kodu',
        'simge_kodu',
        'aciklama',
        'olusturma_tarihi',
      ])
        key: k[key],
      'aktif': 1,
      'belge_sayisi': 0,
    });
    await tx.insert('aktarim_kimlikleri', {
      'tur': 'kategori',
      'yerel_id': id,
      'evrensel_id': k['evrensel_id'],
    });
    return id;
  }

  Future<Map<String, List<int>>> _baglantilariCoz(
    DatabaseExecutor tx,
    Map<String, dynamic> paket, {
    required bool yaz,
  }) async {
    final result = <String, List<int>>{'kisi': [], 'kategori': []};
    for (final kind in result.keys) {
      final refs = [
        if (paket[kind] != null) paket[kind],
        ...?paket['baglantilar']?[kind] as List?,
      ];
      for (final ref in refs) {
        final single = <String, dynamic>{kind: ref};
        final choices = paket['hedef_kisi_secimleri'];
        if (kind == 'kisi') {
          single['hedef_kisi_id'] =
              choices is Map ? choices[ref['evrensel_id']] : null;
          if (ref == paket[kind])
            single['hedef_kisi_id'] ??= paket['hedef_kisi_id'];
        }
        try {
          final id =
              kind == 'kisi'
                  ? await _kisi(tx, single, yaz: yaz)
                  : await _kategori(tx, single, yaz: yaz);
          if (id != null) {
            // Negative IDs only mark not-yet-created references during preview.
            if (id > 0 && result[kind]!.contains(id)) {
              throw AktarimHatasi(
                'BAGLANTI_CAKISMASI',
                'Farklı $kind bağlantıları hedefte aynı kayda eşleşiyor. '
                    'Bağlantılar birleştirilmedi; eşleştirmeyi kontrol edin.',
              );
            }
            result[kind]!.add(id);
          }
        } on AktarimHatasi catch (error) {
          if (kind == 'kisi')
            error.kisiEvrenselId = ref['evrensel_id'] as String;
          rethrow;
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>?> _mevcut(
    DatabaseExecutor tx,
    Map<String, dynamic> paket,
    int? kisi,
    int? kategori,
    Map<String, List<int>> links,
  ) async {
    final b = _map(paket['belge'], 'belge');
    final kimlikler = await tx.query(
      'aktarim_kimlikleri',
      where: 'tur = ? AND evrensel_id = ?',
      whereArgs: ['belge', paket['evrensel_belge_id']],
    );
    final rows = await tx.query(
      'belgeler',
      where: 'dosya_hash = ?',
      whereArgs: [b['dosya_hash']],
    );
    if (kimlikler.isNotEmpty &&
        (rows.isEmpty || rows.single['id'] != kimlikler.single['yerel_id'])) {
      throw AktarimHatasi(
        'BELGE_KIMLIK_CAKISMASI',
        'Belge kimligi hedefte farkli bir icerige bagli. Mevcut belge korundu.',
      );
    }
    if (rows.isEmpty) return null;
    final row = rows.single;
    // Yerel son-erisim ve guncelleme zamani farkli olabilir; is verisi farki cakismadir.
    final local =
        belgeMetadata(row)
          ..remove('son_erisim_tarihi')
          ..remove('guncelleme_tarihi');
    final remote =
        Map<String, dynamic>.from(b)
          ..remove('son_erisim_tarihi')
          ..remove('guncelleme_tarihi');
    final model = BelgeModeli.fromMap(row);
    bool same(List<int> a, List<int> b) =>
        a.toSet().length == b.toSet().length && a.toSet().containsAll(b);
    if (!same(model.tumKisiIds, links['kisi']!) ||
        !same(model.tumKategoriIds, links['kategori']!) ||
        model.tumKisiIds.firstOrNull != kisi ||
        model.tumKategoriIds.firstOrNull != kategori ||
        _json(local) != _json(remote)) {
      throw AktarimHatasi(
        'BELGE_CAKISMASI',
        'Ayni icerik hedefte farkli kisi, kategori veya belge bilgileriyle kayitli. Mevcut kayit korundu.',
      );
    }
    final file = File(row['dosya_yolu'] as String);
    if (!await file.exists() ||
        await file.length() != b['dosya_boyutu'] ||
        await hash(file) != b['dosya_hash']) {
      throw AktarimHatasi(
        'HEDEF_DOSYA_BOZUK',
        'Hedef kaydin dosyasi eksik veya bozuk. Mevcut kayit korundu.',
      );
    }
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> onKontrol(Map<String, dynamic> paket) async {
    dogrula(paket);
    await hazirla();
    return db.transaction((tx) async {
      final links = await _baglantilariCoz(tx, paket, yaz: false);
      final kisi = links['kisi']!.firstOrNull;
      final kategori = links['kategori']!.firstOrNull;
      await _mevcut(tx, paket, kisi, kategori, links);
      return {
        'success': true,
        'durum': 'hazir',
        'metadata_hash': paket['metadata_hash'],
      };
    });
  }

  Future<Map<String, dynamic>> al(
    Map<String, dynamic> paket,
    Stream<List<int>> icerik,
  ) async {
    dogrula(paket);
    await hazirla();
    await belgeler.create(recursive: true);
    final klasor = await belgeler.createTemp('aktarim-');
    final gecici = File(p.join(klasor.path, 'icerik.part'));
    final b = _map(paket['belge'], 'belge');
    bool kaydedildi = false;
    try {
      final output = await gecici.open(mode: FileMode.write);
      var boyut = 0;
      try {
        await for (final bytes in icerik.timeout(const Duration(seconds: 60))) {
          boyut += bytes.length;
          if (boyut > b['dosya_boyutu'])
            throw AktarimHatasi(
              'BOYUT',
              'Gelen dosya bildirilen boyutu asiyor.',
            );
          await output.writeFrom(bytes);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (boyut != b['dosya_boyutu'] || await hash(gecici) != b['dosya_hash']) {
        throw AktarimHatasi(
          'HASH',
          'Dosya eksik veya SHA-256 dogrulamasi basarisiz.',
        );
      }
      final hedef = await gecici.rename(
        p.join(klasor.path, b['dosya_adi'] as String),
      );
      await yetkiKontrol?.call();
      final sonuc = await db.transaction((tx) async {
        final links = await _baglantilariCoz(tx, paket, yaz: true);
        final kisi = links['kisi']!.firstOrNull;
        final kategori = links['kategori']!.firstOrNull;
        final mevcut = await _mevcut(tx, paket, kisi, kategori, links);
        int? belgeId = mevcut?['id'] as int?;
        if (mevcut == null) {
          belgeId = await tx.insert('belgeler', {
            ...b,
            'etiketler': jsonEncode(b['etiketler']),
            'dosya_yolu': hedef.path,
            'kisi_id': kisi,
            'kategori_id': kategori,
            'kisi_ids': jsonEncode(links['kisi']),
            'kategori_ids': jsonEncode(links['kategori']),
            'senkron_durumu': SenkronDurumu.SENKRONIZE.index,
          });
          for (final categoryId in links['kategori']!) {
            await tx.rawUpdate(
              'UPDATE kategoriler SET belge_sayisi = (SELECT COUNT(*) FROM belgeler b WHERE ${DocumentLinks.contains('kategori', '?')} AND b.aktif = 1) WHERE id = ?',
              [categoryId, categoryId],
            );
          }
        }
        final kimlikler = await tx.query(
          'aktarim_kimlikleri',
          where: 'tur = ? AND evrensel_id = ?',
          whereArgs: ['belge', paket['evrensel_belge_id']],
        );
        if (kimlikler.isEmpty)
          await tx.insert('aktarim_kimlikleri', {
            'tur': 'belge',
            'yerel_id': belgeId,
            'evrensel_id': paket['evrensel_belge_id'],
          });
        final durum = mevcut == null ? 'kaydedildi' : 'zaten_var';
        await _gecmis(tx, paket, durum, null);
        return {
          'success': true,
          'verified': true,
          'durum': durum,
          'aktarim_id': paket['aktarim_id'],
          'metadata_hash': paket['metadata_hash'],
          'dosya_hash': b['dosya_hash'],
        };
      });
      kaydedildi = sonuc['durum'] == 'kaydedildi';
      return sonuc;
    } catch (e) {
      await _gecmis(db, paket, 'hata', e.toString());
      rethrow;
    } finally {
      // Yalnizca bu istegin createTemp ile olusturdugu klasor temizlenir.
      if (!kaydedildi && await klasor.exists())
        await klasor.delete(recursive: true);
    }
  }

  Future<void> _gecmis(
    DatabaseExecutor tx,
    Map<String, dynamic> paket,
    String durum,
    String? mesaj,
  ) async {
    await tx.insert('aktarim_gecmisi', {
      'aktarim_id': paket['aktarim_id'],
      'dosya_hash': paket['belge']['dosya_hash'],
      'metadata_hash': paket['metadata_hash'],
      'durum': durum,
      'mesaj': mesaj,
      'zaman': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static bool onayGecerli(
    Map<String, dynamic> paket,
    Map<String, dynamic> yanit,
  ) =>
      yanit['success'] == true &&
      yanit['verified'] == true &&
      ['kaydedildi', 'zaten_var'].contains(yanit['durum']) &&
      yanit['aktarim_id'] == paket['aktarim_id'] &&
      yanit['metadata_hash'] == paket['metadata_hash'] &&
      yanit['dosya_hash'] == paket['belge']['dosya_hash'];
}
