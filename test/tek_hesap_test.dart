import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/services/arsiv_hesap_servisi.dart';
import 'package:arsiv_uygulamasi/services/auth_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/services/hesap_eslesme_servisi.dart';
import 'package:arsiv_uygulamasi/services/parola_servisi.dart';
import 'package:arsiv_uygulamasi/utils/kimlik_normalizasyonu.dart';
import 'guvenli_aktarim_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory root;
  late Database pc;
  late Database phone;
  late AuthServisi pcAuth;
  late AuthServisi phoneAuth;
  const password = 'Guclu-Sifre-123';
  late String secureHash;
  setUpAll(() async {
    secureHash = await ParolaServisi.olustur(password);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('arsiv-hesap-test-');
    pc = await fixture.testDb(p.join(root.path, 'pc.db'));
    phone = await fixture.testDb(p.join(root.path, 'phone.db'));
    pcAuth = AuthServisi.test(pc);
    phoneAuth = AuthServisi.test(phone);
  });
  tearDown(() async {
    await pc.close();
    await phone.close();
    await root.delete(recursive: true);
  });

  Future<int> person(
    Database db, {
    bool upper = false,
    bool legacy = false,
    String user = 'mehmet',
    String name = 'Mehmet',
    String role = 'NORMAL',
  }) async => db.insert('kisiler', {
    ...fixture.kisi(
      ad: upper ? 'MEHMET' : name,
      user: upper ? user.toUpperCase() : user,
    ),
    'soyad': upper ? 'KARATAŞ' : 'Karataş',
    'kullanici_tipi': role,
    'sifre':
        legacy ? sha256.convert(utf8.encode(password)).toString() : secureHash,
  });
  Future<void> login(
    AuthServisi auth, {
    String user = 'mehmet',
    int? id,
  }) async {
    final result = await auth.login(
      kullaniciAdi: user,
      sifre: password,
      kisiId: id,
    );
    expect(result.success, true, reason: result.message);
  }

  Future<Map<String, dynamic>> link(
    HesapEslesmeServisi host,
    HesapEslesmeServisi client,
  ) async {
    final ticket = await host.biletOlustur();
    final response = await host.kabulEt('phone', {
      'account_version': 1,
      'pair_ticket': ticket['pair_ticket'],
      'account': await phoneAuth.hesapTanitim(yeniDogrulama: true),
    });
    await client.karsiCihazaBaglanildi('pc', response);
    return response;
  }

  Future<int> document(Database db, int owner, int index) async {
    final content = utf8.encode('Belge $index: Türkçe içerik');
    final file = File(p.join(root.path, '${p.basename(db.path)}-$index.pdf'));
    await file.writeAsBytes(content);
    return db.insert('belgeler', {
      'dosya_adi': '$index.pdf',
      'orijinal_dosya_adi': '$index.pdf',
      'dosya_yolu': file.path,
      'dosya_boyutu': content.length,
      'dosya_tipi': 'pdf',
      'dosya_hash': sha256.convert(content).toString(),
      'kisi_id': owner,
      'kategori_id': null,
      'baslik': 'Belge $index',
      'aciklama': 'Açıklama',
      'etiketler': jsonEncode(['a,b', 'Türkçe']),
      'aktif': 1,
      'senkron_durumu': 0,
      'olusturma_tarihi': '2020-01-02T00:00:00.000Z',
      'guncelleme_tarihi': '2021-01-02T00:00:00.000Z',
    });
  }

  test('Turkce harf, bosluk ve Unicode; farkli harfler birlesmez', () {
    expect(KimlikNormalizasyonu.metin('  MEHMET   KARATAŞ '), 'mehmet karataş');
    expect(KimlikNormalizasyonu.metin('İSMAİL'), 'ismail');
    expect(KimlikNormalizasyonu.metin('IŞIK'), 'ışık');
    expect(KimlikNormalizasyonu.metin('I\u0307SMAI\u0307L'), 'ismail');
    expect(KimlikNormalizasyonu.metin('S\u0327EN'), 'şen');
    expect(
      KimlikNormalizasyonu.metin('Karatas'),
      isNot(KimlikNormalizasyonu.metin('Karataş')),
    );
    expect(
      KimlikNormalizasyonu.metin('İ'),
      isNot(KimlikNormalizasyonu.metin('I')),
    );
    expect(KimlikNormalizasyonu.kullanici(null), isNull);
  });

  test(
    'eski sifreyle gecis: fiziksel yedek, ID ve belge alanlari korunur',
    () async {
      final id = await person(pc, legacy: true);
      await document(pc, id, 1);
      final beforePeople = await pc.query('kisiler');
      final beforeDocuments = await pc.query('belgeler');
      await login(pcAuth, user: ' MEHMET ');
      expect(await pc.query('belgeler'), beforeDocuments);
      final after = (await pc.query('kisiler')).single;
      expect(after['sifre'], startsWith('pbkdf2-sha256\$600000\$'));
      expect(
        {...after}..remove('sifre'),
        {...beforePeople.single}..remove('sifre'),
      );
      final backups =
          await Directory(p.join(root.path, 'Yedekler'))
              .list(recursive: true)
              .where((f) => f.path.endsWith('arsiv.db'))
              .toList();
      expect(backups, hasLength(1));
      final backup = await databaseFactoryFfi.openDatabase(
        backups.single.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      expect(await backup.query('kisiler'), beforePeople);
      expect(await backup.query('belgeler'), beforeDocuments);
      await backup.close();
      expect((await (await pcAuth.hesapServisi).hesap())!['yerel_kisi_id'], id);
      expect(pcAuth.currentUser!.kullaniciTipi, 'ADMIN');
    },
  );

  test('yanlis sifre ve eski QR oneki yonetici olusturamaz', () async {
    await person(pc, legacy: true);
    final before = await pc.query('kisiler');
    expect(
      (await pcAuth.login(kullaniciAdi: 'mehmet', sifre: 'yanlis')).success,
      false,
    );
    expect(await (await pcAuth.hesapServisi).hesap(), isNull);
    expect(await pc.query('kisiler'), before);
    expect(
      (await pcAuth.qrLogin(
        kullaniciAdi: 'mehmet',
        token: 'qr_login_sahte',
      )).success,
      false,
    );
    expect(pcAuth.isLoggedIn, false);
  });

  test(
    'tek yonetici: ikinci kayit ve eski baska hesap girisi engellenir',
    () async {
      final mainId = await person(pc);
      final otherId = await person(pc, user: 'baska', name: 'Başka');
      await document(pc, otherId, 100);
      await login(pcAuth);
      expect(
        (await pcAuth.register(
          ad: 'Yeni',
          soyad: 'Kişi',
          kullaniciAdi: 'yeni',
          sifre: password,
        )).success,
        false,
      );
      final otherAuth = AuthServisi.test(pc);
      expect(
        (await otherAuth.login(kullaniciAdi: 'baska', sifre: password)).success,
        false,
      );
      expect((await pc.query('kisiler')).map((r) => r['id']), [
        mainId,
        otherId,
      ]);
      expect((await pc.query('belgeler')).single['kisi_id'], otherId);
      expect(await pc.query('arsiv_hesabi'), hasLength(1));
    },
  );

  test('eski ADMIN varsa NORMAL hesap sahipligi alamaz', () async {
    final owner = await person(pc, role: 'ADMIN');
    await person(pc, user: 'normal');
    expect(
      (await pcAuth.login(kullaniciAdi: 'normal', sifre: password)).success,
      false,
    );
    expect(await (await pcAuth.hesapServisi).hesap(), isNull);
    await login(pcAuth);
    expect(
      (await (await pcAuth.hesapServisi).hesap())!['yerel_kisi_id'],
      owner,
    );
  });

  test('eski harf-farki hesaplari secim ister ve silinmez', () async {
    final one = await person(pc);
    final two = await person(pc, upper: true);
    expect(await pcAuth.girisAdaylari('Mehmet'), hasLength(2));
    expect(
      (await pcAuth.login(kullaniciAdi: 'mehmet', sifre: password)).success,
      false,
    );
    expect(await (await pcAuth.hesapServisi).hesap(), isNull);
    await login(pcAuth, id: two);
    expect((await pc.query('kisiler')).map((r) => r['id']), [one, two]);
    await pcAuth.logout();
    await login(pcAuth);
    expect(pcAuth.currentUser!.id, two);
  });

  test(
    '20 belge iki yonde ortak Mehmet hesabina gider, yerel ID ve mevcutlar korunur',
    () async {
      final pcId = await person(pc);
      await phone.insert('kisiler', {
        ...fixture.kisi(ad: 'Başka', user: 'baska'),
        'sifre': null,
      });
      final phoneId = await person(phone, upper: true);
      await document(phone, phoneId, 1000);
      final oldPhone = (await phone.query('belgeler')).single;
      for (var i = 0; i < 20; i++) {
        await document(pc, pcId, i);
      }
      await login(pcAuth);
      await login(phoneAuth);
      final host = HesapEslesmeServisi(pcAuth);
      final client = HesapEslesmeServisi(phoneAuth);
      final account = await link(host, client);
      expect((await phoneAuth.hesapTanitim())['arsiv_id'], account['arsiv_id']);
      expect(
        (await phoneAuth.hesapTanitim())['yonetici_id'],
        account['yonetici_id'],
      );
      expect(jsonEncode(account), isNot(contains(secureHash)));
      await host.yetkiKontrol('phone');
      await client.yetkiKontrol('pc');
      final sender = GuvenliAktarimServisi(
        pc,
        Directory(p.join(root.path, 'pc-files')),
      );
      final receiver = GuvenliAktarimServisi(
        phone,
        Directory(p.join(root.path, 'phone-files')),
      );
      for (final row in await pc.query('belgeler')) {
        final packet = await sender.paketOlustur(row['id'] as int);
        expect(packet['kisi']['evrensel_id'], account['yonetici_id']);
        await receiver.onKontrol(packet);
        final bytes = await File(row['dosya_yolu'] as String).readAsBytes();
        final result = await receiver.al(packet, Stream.value(bytes));
        expect(GuvenliAktarimServisi.onayGecerli(packet, result), true);
        final imported =
            (await phone.query(
              'belgeler',
              where: 'dosya_hash = ?',
              whereArgs: [row['dosya_hash']],
            )).single;
        expect(imported['kisi_id'], phoneId);
        expect(
          await File(imported['dosya_yolu'] as String).readAsBytes(),
          bytes,
        );
        final reverse = await receiver.paketOlustur(imported['id'] as int);
        expect(
          (await sender.al(reverse, Stream.value(bytes)))['durum'],
          'zaten_var',
        );
      }
      expect(await phone.query('belgeler'), hasLength(21));
      expect(
        (await phone.query(
          'belgeler',
          where: 'id = ?',
          whereArgs: [oldPhone['id']],
        )).single,
        oldPhone,
      );
      expect(await phone.query('kisiler'), hasLength(2));
      expect(await pc.query('belgeler'), hasLength(20));
      expect((await pc.query('kisiler')).single['id'], pcId);
      expect(
        (await (await phoneAuth.hesapServisi).hesap())!['yerel_kisi_id'],
        phoneId,
      );
    },
  );

  test('QR sure, tekrar, oturum ve parola degisikligi denetimleri', () async {
    await person(pc);
    await person(phone);
    await login(pcAuth);
    await login(phoneAuth);
    var now = DateTime.now();
    final host = HesapEslesmeServisi(pcAuth, saat: () => now);
    var ticket = await host.biletOlustur();
    expect(host.biletGecerli(ticket['pair_ticket'] as String), true);
    final remote = await phoneAuth.hesapTanitim();
    Map<String, dynamic> body() => {
      'account_version': 1,
      'pair_ticket': ticket['pair_ticket'],
      'account': remote,
    };
    now = now.add(const Duration(minutes: 6));
    expect(host.biletGecerli(ticket['pair_ticket'] as String), false);
    await expectLater(
      host.kabulEt('phone', body()),
      throwsA(isA<HesapHatasi>()),
    );
    ticket = await host.biletOlustur();
    await host.kabulEt('phone', body());
    expect(host.biletGecerli(ticket['pair_ticket'] as String), false);
    await expectLater(
      host.kabulEt('phone', body()),
      throwsA(isA<HesapHatasi>()),
    );
    await host.yetkiKontrol('phone');
    expect(
      (await pcAuth.changePassword(
        eskiSifre: password,
        yeniSifre: 'Yeni-Sifre-456',
      )).success,
      true,
    );
    await expectLater(host.yetkiKontrol('phone'), throwsA(isA<HesapHatasi>()));
    expect((await pcAuth.yoneticiDogrula(password)).success, false);
    expect((await pcAuth.yoneticiDogrula('Yeni-Sifre-456')).success, true);
    await pcAuth.logout();
    await expectLater(host.biletOlustur(), throwsA(isA<HesapHatasi>()));
  });

  test(
    'yanlis yonetici ayni ada veya kullanici adina dayanarak eslesemez',
    () async {
      await person(pc);
      await person(phone, name: 'Başka');
      await login(pcAuth);
      await login(phoneAuth);
      final host = HesapEslesmeServisi(pcAuth);
      final ticket = await host.biletOlustur();
      final before = await (await pcAuth.hesapServisi).hesap();
      await expectLater(
        host.kabulEt('phone', {
          'account_version': 1,
          'pair_ticket': ticket['pair_ticket'],
          'account': await phoneAuth.hesapTanitim(),
        }),
        throwsA(isA<HesapHatasi>()),
      );
      expect(await (await pcAuth.hesapServisi).hesap(), before);
      await expectLater(
        host.yetkiKontrol('phone'),
        throwsA(isA<HesapHatasi>()),
      );
    },
  );

  test('baska arsive bagli cihaz sessizce yeni arsive gecemez', () async {
    await person(pc);
    await person(phone);
    await login(pcAuth);
    await login(phoneAuth);
    final local = await phoneAuth.hesapTanitim();
    await (await phoneAuth.hesapServisi).bagla(
      phoneAuth.currentUser!.id!,
      local,
    );
    final host = HesapEslesmeServisi(pcAuth);
    final ticket = await host.biletOlustur();
    await expectLater(
      host.kabulEt('phone', {
        'account_version': 1,
        'pair_ticket': ticket['pair_ticket'],
        'account': await phoneAuth.hesapTanitim(),
      }),
      throwsA(isA<HesapHatasi>()),
    );
    expect((await phoneAuth.hesapTanitim())['arsiv_id'], local['arsiv_id']);
  });

  test(
    'eslesme yaniti kaybolursa yeni QR ile ayni hesaba devam edilir',
    () async {
      await person(pc);
      await person(phone);
      await login(pcAuth);
      await login(phoneAuth);
      final host = HesapEslesmeServisi(pcAuth);
      final ticket = await host.biletOlustur();
      await host.kabulEt('phone', {
        'account_version': 1,
        'pair_ticket': ticket['pair_ticket'],
        'account': await phoneAuth.hesapTanitim(),
      });
      final client = HesapEslesmeServisi(phoneAuth);
      await link(host, client);
      expect(
        (await phoneAuth.hesapTanitim())['arsiv_id'],
        (await pcAuth.hesapTanitim())['arsiv_id'],
      );
      expect(await pc.query('kisiler'), hasLength(1));
      expect(await phone.query('kisiler'), hasLength(1));
    },
  );

  test('DB hatasi kimlik eslemesini geri alir, belgeler degismez', () async {
    final id = await person(pc);
    await person(phone);
    await document(pc, id, 11);
    await login(pcAuth);
    await login(phoneAuth);
    final before = await pc.query('belgeler');
    final oldAccount = await (await pcAuth.hesapServisi).hesap();
    await pc.execute(
      "CREATE TRIGGER hesap_test_hatasi BEFORE UPDATE ON arsiv_hesabi BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(
      (await pcAuth.hesapServisi).bagla(id, await phoneAuth.hesapTanitim()),
      throwsA(anything),
    );
    expect(await pc.query('belgeler'), before);
    expect(await (await pcAuth.hesapServisi).hesap(), oldAccount);
    expect(await pc.query('aktarim_kimlikleri'), isEmpty);
  });

  test(
    'yonetici kisisi silinemez, pasife alinamaz, eski oturum yukselemez',
    () async {
      final id = await person(pc);
      SharedPreferences.setMockInitialValues({'current_user_id': id});
      expect(await pcAuth.checkAutoLogin(), false);
      await login(pcAuth);
      await expectLater(
        pc.delete('kisiler', where: 'id = ?', whereArgs: [id]),
        throwsA(anything),
      );
      await expectLater(
        pc.update('kisiler', {'aktif': 0}, where: 'id = ?', whereArgs: [id]),
        throwsA(anything),
      );
      expect(await pcAuth.checkAutoLogin(), true);
      await expectLater(
        pcAuth.hesapTanitim(yeniDogrulama: true),
        throwsA(isA<HesapHatasi>()),
      );
      expect((await pc.query('kisiler')).single['id'], id);
    },
  );

  test(
    'ayni sifre farkli tuzla saklanir; sifre buyuk kucuk harfe duyarlidir',
    () async {
      final other = await ParolaServisi.olustur(password);
      expect(other, isNot(secureHash));
      expect(await ParolaServisi.dogrula(password, secureHash), true);
      expect(
        await ParolaServisi.dogrula(password.toLowerCase(), secureHash),
        false,
      );
      expect(
        await ParolaServisi.dogrula(password, 'pbkdf2-sha256\$999999999\$a\$b'),
        false,
      );
    },
  );

  test('eszamanli ilk kayitta tek yonetici ve tek hesap olusur', () async {
    final second = AuthServisi.test(pc);
    final results = await Future.wait([
      pcAuth.register(
        ad: 'Mehmet',
        soyad: 'Karataş',
        kullaniciAdi: 'mehmet',
        sifre: password,
      ),
      second.register(
        ad: 'Mehmet',
        soyad: 'Karataş',
        kullaniciAdi: 'MEHMET',
        sifre: password,
      ),
    ]);
    expect(results.where((r) => r.success), hasLength(1));
    expect(await pc.query('arsiv_hesabi'), hasLength(1));
    expect(await pc.query('kisiler'), hasLength(1));
    await login(pcAuth);
  });

  test(
    'normal kisinin Turkce harf eslesmesi onaydan sonra kalici olur',
    () async {
      final pcId = await person(pc);
      final phoneId = await person(phone, upper: true);
      final id = await document(pc, pcId, 7);
      final sender = GuvenliAktarimServisi(
        pc,
        Directory(p.join(root.path, 'pc-files')),
      );
      final receiver = GuvenliAktarimServisi(
        phone,
        Directory(p.join(root.path, 'phone-files')),
      );
      final packet = await sender.paketOlustur(id);
      await expectLater(
        receiver.onKontrol(packet),
        throwsA(
          isA<AktarimHatasi>().having((e) => e.kod, 'kod', 'KISI_SECIMI'),
        ),
      );
      packet['hedef_kisi_id'] = phoneId;
      final file = File(
        (await pc.query('belgeler')).single['dosya_yolu'] as String,
      );
      await receiver.al(packet, file.openRead());
      packet.remove('hedef_kisi_id');
      expect((await receiver.onKontrol(packet))['success'], true);
      expect(await phone.query('kisiler'), hasLength(1));
      final guarded = GuvenliAktarimServisi(
        phone,
        receiver.belgeler,
        yetkiKontrol: () async => throw HesapHatasi('Oturum kapandi'),
      );
      await expectLater(
        guarded.al(packet, file.openRead()),
        throwsA(isA<HesapHatasi>()),
      );
      expect(await phone.query('belgeler'), hasLength(1));
    },
  );
}
