import 'sqlite_snapshot.dart';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/sabitler.dart';

class DepolamaKonumuServisi {
  static final DepolamaKonumuServisi _instance =
      DepolamaKonumuServisi._internal();
  static DepolamaKonumuServisi get instance => _instance;

  DepolamaKonumuServisi._internal();

  DepolamaKonumuServisi.test({
    required Directory gizli,
    required Directory acik,
    required DatabaseFactory factory,
    this.yazmaKontrolu,
  }) : _testGizli = gizli,
       _testAcik = acik,
       _testFactory = factory;
  Directory? _testGizli;
  Directory? _testAcik;
  DatabaseFactory? _testFactory;
  Future<bool> Function(Directory)? yazmaKontrolu;
  bool get _android => _testGizli != null || Platform.isAndroid;
  Future<Directory> _gizliKlasor() async =>
      _testGizli ?? await getApplicationDocumentsDirectory();

  Directory? _aktifKokKlasor;
  Directory? _gizliKokKlasor;
  bool _acikKlasorKullaniliyor = false;
  Future<Directory>? _hazirlik;
  Future<String>? _veritabaniHazirlik;

  bool get acikKlasorKullaniliyor => _acikKlasorKullaniliyor;

  Future<Directory> aktifKokKlasor() async {
    try {
      return await (_hazirlik ??= _konumuSec());
    } catch (_) {
      _hazirlik = null;
      rethrow;
    }
  }

  Future<Directory> _konumuSec() async {
    if (_aktifKokKlasor != null) return _aktifKokKlasor!;

    _gizliKokKlasor = await _gizliKlasor();

    if (_android) {
      final acikKlasor =
          _testAcik ?? Directory('/storage/emulated/0/Documents/Arsiv');
      final yazilabilir =
          await (yazmaKontrolu?.call(acikKlasor) ??
              _klasorYazilabilirMi(acikKlasor));
      final isaret = File(
        path.join(_gizliKokKlasor!.path, '.arsiv-acik-konum.json'),
      );
      if (await isaret.exists()) {
        final kayit = jsonDecode(await isaret.readAsString());
        if (kayit['konum'] != acikKlasor.path ||
            !yazilabilir ||
            !await File(
              path.join(acikKlasor.path, Sabitler.VERITABANI_ADI),
            ).exists()) {
          throw StateError(
            'Aktif acik arsive ulasilamiyor. Depolama iznini ve arsiv.db dosyasini kontrol edin. Eski yedege otomatik gecilmedi.',
          );
        }
      } else if (await File(
            path.join(_gizliKokKlasor!.path, Sabitler.VERITABANI_ADI),
          ).exists() &&
          await File(
            path.join(acikKlasor.path, Sabitler.VERITABANI_ADI),
          ).exists()) {
        throw StateError(
          'Hem gizli hem acik klasorde arsiv.db var. Iki veritabani korunarak hangi arsivin guncel oldugu dogrulanmali.',
        );
      }
      if (yazilabilir) {
        _aktifKokKlasor = acikKlasor;
        _acikKlasorKullaniliyor = true;
      } else {
        if (await File(
          path.join(acikKlasor.path, Sabitler.VERITABANI_ADI),
        ).exists()) {
          throw StateError(
            'Acik arsiv var ancak yazma izni yok. Izin verin; bos gizli arsiv olusturulmadi.',
          );
        }
        _aktifKokKlasor = _gizliKokKlasor;
        _acikKlasorKullaniliyor = false;
        tasimaUyarisi =
            'Acik klasore yazma izni yok. Mevcut gizli arsiv kullaniliyor; veriler tasinmadi.';
      }
    } else {
      _aktifKokKlasor = _gizliKokKlasor;
      _acikKlasorKullaniliyor = false;
    }

    await _temelKlasorleriOlustur(_aktifKokKlasor!);
    return _aktifKokKlasor!;
  }

  Future<Directory> belgelerKlasoru() async {
    final kok = await aktifKokKlasor();
    final klasor = Directory(path.join(kok.path, Sabitler.BELGELER_KLASORU));
    if (!await klasor.exists()) {
      await klasor.create(recursive: true);
    }
    return klasor;
  }

  Future<Directory> yedeklerKlasoru() async {
    final kok = await aktifKokKlasor();
    final klasor = Directory(path.join(kok.path, 'Yedekler'));
    if (!await klasor.exists()) {
      await klasor.create(recursive: true);
    }
    return klasor;
  }

  Future<Directory> logKlasoru() async {
    final kok = await aktifKokKlasor();
    final klasor = Directory(path.join(kok.path, 'Logs'));
    if (!await klasor.exists()) {
      await klasor.create(recursive: true);
    }
    return klasor;
  }

  Future<String> veritabaniYoluHazirla() async {
    try {
      return await (_veritabaniHazirlik ??= _veritabaniYolunuHazirla());
    } catch (_) {
      _veritabaniHazirlik = null;
      rethrow;
    }
  }

  Future<String> _veritabaniYolunuHazirla() async {
    final aktifKok = await aktifKokKlasor();
    final aktifDb = File(path.join(aktifKok.path, Sabitler.VERITABANI_ADI));

    if (_android && _acikKlasorKullaniliyor) {
      final gizliKok = _gizliKokKlasor ?? await _gizliKlasor();
      final gizliDb = File(path.join(gizliKok.path, Sabitler.VERITABANI_ADI));

      if (await gizliDb.exists() && !await aktifDb.exists()) {
        try {
          await _veritabaniniGuvenliKopyala(gizliDb, aktifDb);
        } catch (e) {
          // Snapshot olusmadiysa eski arsiv yetkili kalir; kismi hedef acilmaz.
          if (await aktifDb.exists()) rethrow;
          _aktifKokKlasor = gizliKok;
          _acikKlasorKullaniliyor = false;
          _hazirlik = Future.value(gizliKok);
          tasimaUyarisi =
              'Acik klasore tasima tamamlanamadi; gizli arsiv kullaniliyor: $e';
          return gizliDb.path;
        }
      }
      // A fresh installation must not publish a marker before SQLite exists.
      // If its first open fails, it can retry instead of being locked out forever.
      if (await aktifDb.exists()) await veritabaniAcilisiniOnayla();
    }

    return aktifDb.path;
  }

  Future<void> veritabaniAcilisiniOnayla() async {
    if (!_android || !_acikKlasorKullaniliyor) return;
    final aktifKok = await aktifKokKlasor();
    if (!await File(
      path.join(aktifKok.path, Sabitler.VERITABANI_ADI),
    ).exists()) {
      throw StateError('Aktif arsiv olusmadan konum kaydedilemez.');
    }
    final gizliKok = _gizliKokKlasor ?? await _gizliKlasor();
    final isaret = File(path.join(gizliKok.path, '.arsiv-acik-konum.json'));
    if (await isaret.exists()) return;
    final klasor = await gizliKok.createTemp('konum-');
    try {
      final gecici = File(path.join(klasor.path, 'konum.json'));
      await gecici.writeAsString(
        jsonEncode({'konum': aktifKok.path}),
        flush: true,
      );
      await gecici.rename(isaret.path);
    } finally {
      await klasor.delete(recursive: true);
    }
  }

  Future<Map<String, String>> eskiVeYeniBelgeKlasorleri() async {
    final aktifBelgeler = await belgelerKlasoru();
    final gizliKok = _gizliKokKlasor ?? await _gizliKlasor();
    final gizliBelgeler = Directory(
      path.join(gizliKok.path, Sabitler.BELGELER_KLASORU),
    );

    return {'eski': gizliBelgeler.path, 'yeni': aktifBelgeler.path};
  }

  Future<String> dosyaHashi(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
  }

  Future<bool> dosyaKopyalaVeDogrula(File kaynak, File hedef) async {
    if (!await kaynak.exists()) return false;
    if (!await hedef.parent.exists()) {
      await hedef.parent.create(recursive: true);
    }

    final geciciKlasor = await hedef.parent.createTemp('kopya-');
    final gecici = File(path.join(geciciKlasor.path, 'icerik.tmp'));

    try {
      await kaynak.copy(gecici.path);

      final kaynakStat = await kaynak.stat();
      final geciciStat = await gecici.stat();
      if (kaynakStat.size != geciciStat.size) {
        await gecici.delete();
        return false;
      }

      final kaynakHash = await dosyaHashi(kaynak);
      final hedefHash = await dosyaHashi(gecici);
      if (kaynakHash != hedefHash) {
        await gecici.delete();
        return false;
      }

      if (await hedef.exists()) {
        throw StateError('Hedef zaten var; mevcut dosyanin uzerine yazilmadi.');
      }
      await gecici.rename(hedef.path);
      return true;
    } finally {
      if (await geciciKlasor.exists())
        await geciciKlasor.delete(recursive: true);
    }
  }

  Future<void> _veritabaniniGuvenliKopyala(File kaynak, File hedef) async {
    final yedekKlasor = await (await yedeklerKlasoru()).createTemp(
      'db-snapshot-',
    );
    final snapshot = File(path.join(yedekKlasor.path, 'arsiv.db'));
    final factory = _testFactory ?? databaseFactory;
    final source = await factory.openDatabase(
      kaynak.path,
      options: OpenDatabaseOptions(singleInstance: false, readOnly: true),
    );
    try {
      // WAL dahil tutarli SQLite snapshot'i; dosya sisteminden canli DB kopyalanmaz.
      await SqliteSnapshot.create(source, snapshot.path, factory: factory);
    } finally {
      await source.close();
    }
    final stage = File(path.join(yedekKlasor.path, 'arsiv-stage.db'));
    await snapshot.copy(stage.path);
    final check = await factory.openDatabase(
      stage.path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final kopyaKlasoru = await (await belgelerKlasoru()).createTemp('tasima-');
    bool tamamlandi = false;
    try {
      final integrity = await check.rawQuery('PRAGMA integrity_check');
      if (integrity.length != 1 || integrity.single.values.single != 'ok') {
        throw StateError('Veritabani yedegi butunluk kontrolunu gecemedi.');
      }
      final once = <String, int>{};
      for (final table in ['kisiler', 'kategoriler', 'belgeler']) {
        once[table] =
            (await check.rawQuery(
                  'SELECT COUNT(*) AS n FROM $table',
                )).single['n']
                as int;
      }
      await check.transaction((tx) async {
        final belgeler = await tx.query('belgeler');
        for (final row in belgeler) {
          final sourceFile = File(row['dosya_yolu'] as String);
          if (!await sourceFile.exists() ||
              await sourceFile.length() != row['dosya_boyutu'] ||
              await dosyaHashi(sourceFile) != row['dosya_hash']) {
            throw StateError(
              'Belge ${row['id']} kaynak dosyasi dogrulanamadi.',
            );
          }
          final targetFile = File(
            path.join(
              kopyaKlasoru.path,
              'belge-${row['id']}',
              path.basename(sourceFile.path),
            ),
          );
          if (!await dosyaKopyalaVeDogrula(sourceFile, targetFile))
            throw StateError('Belge kopyasi dogrulanamadi.');
          await tx.update(
            'belgeler',
            {'dosya_yolu': targetFile.path},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        final kisiler = await tx.query('kisiler');
        for (final row in kisiler) {
          final foto = row['profil_fotografi'];
          if (foto is! String || foto.isEmpty) continue;
          final sourceFile = File(foto);
          final targetFile = File(
            path.join(
              kopyaKlasoru.path,
              'kisi-${row['id']}',
              path.basename(foto),
            ),
          );
          if (!await dosyaKopyalaVeDogrula(sourceFile, targetFile))
            throw StateError('Profil fotografi dogrulanamadi.');
          await tx.update(
            'kisiler',
            {'profil_fotografi': targetFile.path},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      });
      for (final entry in once.entries) {
        if ((await check.rawQuery(
              'SELECT COUNT(*) AS n FROM ${entry.key}',
            )).single['n'] !=
            entry.value) {
          throw StateError('Tasima sirasinda kayit sayisi degisti.');
        }
      }
      if ((await check.rawQuery(
            'PRAGMA integrity_check',
          )).single.values.single !=
          'ok') {
        throw StateError('Hedef veritabani dogrulanamadi.');
      }
      await check.close();
      final basarili = await dosyaKopyalaVeDogrula(stage, hedef);
      if (!basarili) throw StateError('Hedef veritabani kopyalanamadi.');
      tamamlandi = true;
    } finally {
      if (check.isOpen) await check.close();
      if (!tamamlandi && !await hedef.exists() && await kopyaKlasoru.exists()) {
        await kopyaKlasoru.delete(recursive: true);
      }
    }
  }

  String? tasimaUyarisi;

  Future<bool> _klasorYazilabilirMi(Directory klasor) async {
    try {
      if (!await klasor.exists()) {
        await klasor.create(recursive: true);
      }
      await _temelKlasorleriOlustur(klasor);

      final testKlasoru = await klasor.createTemp('.arsiv-yazma-');
      final testDosyasi = File(path.join(testKlasoru.path, 'test'));
      await testDosyasi.writeAsString('ok', flush: true);
      await testDosyasi.delete();
      await testKlasoru.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _temelKlasorleriOlustur(Directory kok) async {
    final klasorler = [
      kok,
      Directory(path.join(kok.path, Sabitler.BELGELER_KLASORU)),
      Directory(path.join(kok.path, 'Yedekler')),
      Directory(path.join(kok.path, 'Logs')),
    ];

    for (final klasor in klasorler) {
      if (!await klasor.exists()) {
        await klasor.create(recursive: true);
      }
    }
  }
}
