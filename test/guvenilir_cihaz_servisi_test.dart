import 'dart:async';
import 'dart:convert';

import 'package:arsiv_uygulamasi/services/arsiv_hesap_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenilir_cihaz_servisi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BellekDeposu implements GuvenilirCihazDeposu {
  String? value;
  bool readFails = false;
  bool writeFails = false;
  int writes = 0;
  Future<void> Function()? beforeRead;

  @override
  Future<String?> oku() async {
    await beforeRead?.call();
    if (readFails) throw StateError('locked');
    return value;
  }

  @override
  Future<void> yaz(String deger) async {
    if (writeFails) throw StateError('write failed');
    writes++;
    value = deger;
  }
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late BellekDeposu depo;
  late GuvenilirCihazServisi service;
  late DateTime now;
  late String trustId;
  late String secret;
  late String peer;
  late Map<String, dynamic> account;
  final denied = throwsA(isA<HesapHatasi>());

  GuvenilirCihazServisi restart() =>
      GuvenilirCihazServisi(db, depo: depo, saat: () => now);

  Future<void> enroll({
    String? id,
    String? key,
    String? device,
    String? name,
    String? ip,
    int port = 8080,
    Map<String, dynamic>? scope,
  }) => service.kaydet(
    guvenId: id ?? trustId,
    gizliAnahtar: key ?? secret,
    hesap: scope ?? account,
    cihazId: device ?? peer,
    cihazAdi: name ?? 'Telefon',
    platform: 'android',
    sonIp: ip ?? '192.168.1.10',
    port: port,
  );

  Future<GuvenilirCihaz> consume(
    String nonce, {
    String? id,
    String? device,
    GuvenilirCihazServisi? target,
  }) => (target ?? service).challengeTuket(
    guvenId: id ?? trustId,
    challenge: nonce,
    cihazId: device ?? peer,
  );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute(
      'CREATE TABLE arsiv_hesabi(arsiv_id TEXT, yonetici_id TEXT)',
    );
    await db.execute(
      'CREATE TABLE kisiler(id INTEGER PRIMARY KEY, ad TEXT, sifre TEXT)',
    );
    await db.execute(
      'CREATE TABLE belgeler(id INTEGER PRIMARY KEY, kisi_id INTEGER, dosya_yolu TEXT)',
    );
    await db.insert('kisiler', {
      'id': 17,
      'ad': 'Ayse',
      'sifre': 'EXISTING-HASH',
    });
    await db.insert('belgeler', {
      'id': 29,
      'kisi_id': 17,
      'dosya_yolu': '/original/document.pdf',
    });
    account = {
      'arsiv_id': GuvenilirCihazServisi.yeniGuvenId(),
      'yonetici_id': GuvenilirCihazServisi.yeniGuvenId(),
    };
    await db.insert('arsiv_hesabi', account);
    depo = BellekDeposu();
    now = DateTime.utc(2026, 10, 21, 12);
    service = restart();
    trustId = GuvenilirCihazServisi.yeniGuvenId();
    secret = GuvenilirCihazServisi.yeniGuvenAnahtari();
    peer = GuvenilirCihazServisi.yeniGuvenId();
  });

  tearDown(() async => db.close());

  test(
    'identity persists across instances and simultaneous first starts',
    () async {
      final ids = await Future.wait(
        List.generate(20, (_) => restart().cihazKimligi()),
      );
      expect(ids.toSet(), hasLength(1));
      expect(
        ids.singleWhere((_) => false, orElse: () => ids.first),
        matches(r'^[a-f0-9]{48}$'),
      );
      expect(depo.writes, 1);
      expect(await restart().cihazKimligi(), ids.first);
      final other = GuvenilirCihazServisi(db, depo: BellekDeposu());
      expect(await other.cihazKimligi(), isNot(ids.first));
    },
  );

  test(
    'restart preserves trust and public representations exclude secrets',
    () async {
      await enroll();
      final stored = (await restart().bul(trustId))!;
      expect(stored.gizliAnahtar, secret);
      expect(stored.arsivId, account['arsiv_id']);
      expect(stored.yoneticiId, account['yonetici_id']);
      expect(stored.cihazId, peer);
      expect(stored.port, 8080);
      expect(stored.olusturmaTarihi, now);
      expect(jsonEncode(stored.toMap()), isNot(contains(secret)));
      expect(stored.toString(), isNot(contains(secret)));
      expect(
        jsonEncode(await db.query('guvenilir_cihazlar_v1')),
        isNot(contains(secret)),
      );
      expect(depo.value, isNot(contains('EXISTING-HASH')));
      expect(await restart().listele(), hasLength(1));
    },
  );

  test(
    'enroll, update, rotate and revoke preserve all original archive rows',
    () async {
      final before = {
        for (final table in ['arsiv_hesabi', 'kisiler', 'belgeler'])
          table: await db.query(table),
      };
      await enroll();
      await enroll(ip: '10.0.0.7', port: 9090);
      await enroll(id: GuvenilirCihazServisi.yeniGuvenId());
      for (final record in await service.listele()) {
        await service.unut(record.guvenId);
      }
      for (final table in before.keys) {
        expect(await db.query(table), before[table]);
      }
    },
  );

  test(
    'scope includes archive AND owner; switching cannot grant or revoke',
    () async {
      await enroll();
      for (final field in ['arsiv_id', 'yonetici_id']) {
        await db.update('arsiv_hesabi', {
          field: GuvenilirCihazServisi.yeniGuvenId(),
        });
        expect(await service.bul(trustId), isNull);
        expect(await service.listele(), isEmpty);
        await expectLater(service.challengeOlustur(trustId), denied);
        await expectLater(service.unut(trustId), denied);
        await expectLater(enroll(), denied);
        await db.update('arsiv_hesabi', account);
        expect(await service.bul(trustId), isNotNull);
      }
    },
  );

  test(
    'identity stable across account switch with independently scoped trust',
    () async {
      final identity = await service.cihazKimligi();
      await enroll();
      final second = {
        'arsiv_id': GuvenilirCihazServisi.yeniGuvenId(),
        'yonetici_id': GuvenilirCihazServisi.yeniGuvenId(),
      };
      await db.update('arsiv_hesabi', second);
      final id2 = GuvenilirCihazServisi.yeniGuvenId();
      await enroll(id: id2, scope: second);
      expect(await service.cihazKimligi(), identity);
      expect((await service.listele()).single.guvenId, id2);
      await db.update('arsiv_hesabi', account);
      expect((await service.listele()).single.guvenId, trustId);
    },
  );

  test(
    'public DB edits and copied metadata cannot authorize a device',
    () async {
      await enroll();
      await db.update('guvenilir_cihazlar_v1', {
        'device_id': GuvenilirCihazServisi.yeniGuvenId(),
        'device_name': 'FORGED',
        'last_ip': 'evil.invalid',
      });
      final real = (await service.bul(trustId))!;
      expect(real.cihazId, peer);
      expect(real.cihazAdi, 'Telefon');
      expect(real.sonIp, '192.168.1.10');
      final stolenDb = GuvenilirCihazServisi(db, depo: BellekDeposu());
      expect(await stolenDb.bul(trustId), isNull);
      await expectLater(stolenDb.challengeOlustur(trustId), denied);
    },
  );

  test('public metadata loss does not erase protected trust', () async {
    await enroll();
    await db.execute('DROP TABLE guvenilir_cihazlar_v1');
    expect((await restart().bul(trustId))!.gizliAnahtar, secret);
    await enroll();
    expect(await db.query('guvenilir_cihazlar_v1'), hasLength(1));
  });

  test(
    'challenge is random, one-use and concurrently consumable only once',
    () async {
      await enroll();
      final nonce = await service.challengeOlustur(trustId);
      expect(nonce, matches(r'^[a-f0-9]{64}$'));
      expect(nonce, isNot(secret));
      final results = await Future.wait(
        List.generate(12, (_) async {
          try {
            await consume(nonce);
            return true;
          } on HesapHatasi {
            return false;
          }
        }),
      );
      expect(results.where((ok) => ok), hasLength(1));
      await expectLater(consume(nonce), denied);
      expect(await service.challengeOlustur(trustId), isNot(nonce));
    },
  );

  test(
    'captured resume fails after restart even with surviving trust',
    () async {
      await enroll();
      final captured = await service.challengeOlustur(trustId);
      final restarted = restart();
      expect(await restarted.bul(trustId), isNotNull);
      await expectLater(consume(captured, target: restarted), denied);
      final fresh = await restarted.challengeOlustur(trustId);
      expect((await consume(fresh, target: restarted)).guvenId, trustId);
      await expectLater(consume(fresh, target: restarted), denied);
    },
  );

  test(
    'challenge expires exactly at 60 seconds and rejects backward clocks',
    () async {
      await enroll();
      final nonce = await service.challengeOlustur(trustId);
      now = now.add(const Duration(seconds: 60));
      await expectLater(consume(nonce), denied);
      final nonce2 = await service.challengeOlustur(trustId);
      now = now.subtract(const Duration(milliseconds: 1));
      await expectLater(consume(nonce2), denied);
      final nonce3 = await service.challengeOlustur(trustId);
      now = now.add(const Duration(milliseconds: 59999));
      expect(await consume(nonce3), isA<GuvenilirCihaz>());
    },
  );

  test('challenge binds peer, trust, archive and owner', () async {
    await enroll();
    final nonce = await service.challengeOlustur(trustId);
    await expectLater(
      consume(nonce, device: GuvenilirCihazServisi.yeniGuvenId()),
      denied,
    );
    await expectLater(consume(nonce), denied);
    final nonce2 = await service.challengeOlustur(trustId);
    await expectLater(
      consume(nonce2, id: GuvenilirCihazServisi.yeniGuvenId()),
      denied,
    );
    for (final field in ['arsiv_id', 'yonetici_id']) {
      final challenge = await service.challengeOlustur(trustId);
      await db.update('arsiv_hesabi', {
        field: GuvenilirCihazServisi.yeniGuvenId(),
      });
      await expectLater(consume(challenge), denied);
      await db.update('arsiv_hesabi', account);
      await expectLater(consume(challenge), denied);
    }
  });

  test('revocation persists across instances and public DB rollback', () async {
    await enroll();
    final publicSnapshot = (await db.query('guvenilir_cihazlar_v1')).single;
    final nonce = await service.challengeOlustur(trustId);
    await restart().unut(trustId);
    expect(depo.value, isNot(contains(secret)));
    await db.insert(
      'guvenilir_cihazlar_v1',
      publicSnapshot,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    expect(await service.bul(trustId), isNull);
    expect(await restart().listele(), isEmpty);
    await expectLater(consume(nonce), denied);
    await expectLater(enroll(), denied);
    await service.unut(trustId);
  });

  test(
    're-pair rotates trust, rejects old nonce, and retry is idempotent',
    () async {
      await enroll();
      final nonce = await service.challengeOlustur(trustId);
      await enroll(ip: '10.0.0.9');
      expect((await service.bul(trustId))!.sonIp, '10.0.0.9');
      expect((await service.bul(trustId))!.olusturmaTarihi, now);
      final newId = GuvenilirCihazServisi.yeniGuvenId();
      final newSecret = GuvenilirCihazServisi.yeniGuvenAnahtari();
      await enroll(id: newId, key: newSecret);
      expect(await service.bul(trustId), isNull);
      expect((await service.listele()).single.guvenId, newId);
      expect(depo.value, isNot(contains(secret)));
      await expectLater(consume(nonce), denied);
      await expectLater(enroll(), denied);
    },
  );

  test('cannot overwrite trust ID with changed key or peer', () async {
    await enroll();
    final saved = depo.value;
    await expectLater(
      enroll(key: GuvenilirCihazServisi.yeniGuvenAnahtari()),
      denied,
    );
    await expectLater(
      enroll(device: GuvenilirCihazServisi.yeniGuvenId()),
      denied,
    );
    expect(depo.value, saved);
  });

  test('revocation is effective even when metadata write fails', () async {
    await enroll();
    await db.execute(
      '''CREATE TRIGGER fail_trust_write BEFORE INSERT ON guvenilir_cihazlar_v1
      BEGIN SELECT RAISE(ABORT, 'read only metadata'); END''',
    );
    await expectLater(service.unut(trustId), throwsA(isA<DatabaseException>()));
    expect(await restart().bul(trustId), isNull);
    expect(depo.value, isNot(contains(secret)));
  });

  test(
    'failed secure write cannot grant trust from prepared public metadata',
    () async {
      await service.cihazKimligi();
      final saved = depo.value;
      depo.writeFails = true;
      await expectLater(enroll(), throwsStateError);
      expect(depo.value, saved);
      expect(await service.bul(trustId), isNull);
      expect(await db.query('guvenilir_cihazlar_v1'), hasLength(1));
      depo.writeFails = false;
      await enroll();
      expect(await service.bul(trustId), isNotNull);
    },
  );

  test(
    'secure storage read/write errors never reset or fall back to DB',
    () async {
      await enroll();
      final saved = depo.value;
      depo.readFails = true;
      await expectLater(service.bul(trustId), throwsStateError);
      await expectLater(service.cihazKimligi(), throwsStateError);
      await expectLater(service.listele(), throwsStateError);
      expect(depo.value, saved);
      depo.readFails = false;
      depo.writeFails = true;
      await expectLater(service.unut(trustId), throwsStateError);
      expect(depo.value, saved);
      depo.writeFails = false;
      expect(await service.bul(trustId), isNotNull);
    },
  );

  test(
    'corrupt and future-version vaults are preserved and rejected',
    () async {
      await enroll();
      final saved = depo.value!;
      final changes = <String>[
        '{broken',
        '{"version":2}',
        saved.replaceFirst(peer, 'bad'),
        saved.replaceFirst('"port":8080', '"port":0'),
      ];
      final writeCount = depo.writes;
      for (final value in changes) {
        depo.value = value;
        await expectLater(service.cihazKimligi(), denied);
        await expectLater(service.bul(trustId), denied);
        expect(depo.value, value);
        expect(depo.writes, writeCount);
      }
      depo.value = saved;
      expect(await service.bul(trustId), isNotNull);
    },
  );

  test(
    'rejects malformed identifiers, raw passwords, self-pair and invalid metadata',
    () async {
      await expectLater(enroll(id: '../secret'), denied);
      await expectLater(enroll(key: 'ordinary-password'), denied);
      await expectLater(enroll(device: 'unknown-device'), denied);
      await expectLater(enroll(device: await service.cihazKimligi()), denied);
      await expectLater(enroll(name: ' '), denied);
      await expectLater(enroll(name: 'a' * 257), denied);
      await expectLater(enroll(port: 0), denied);
      await expectLater(enroll(port: 65536), denied);
      expect(await service.bul('untrusted'), isNull);
      expect(await service.listele(), isEmpty);
    },
  );

  test(
    'challenge capacity is bounded, expiring entries free capacity',
    () async {
      await enroll();
      for (var i = 0; i < 8; i++) {
        await service.challengeOlustur(trustId);
      }
      await expectLater(service.challengeOlustur(trustId), denied);
      now = now.add(GuvenilirCihazServisi.challengeOmru);
      expect(await service.challengeOlustur(trustId), isA<String>());
    },
  );

  test('clearing challenges does not forget trust', () async {
    await enroll();
    final nonce = await service.challengeOlustur(trustId);
    service.challengeTemizle();
    await expectLater(consume(nonce), denied);
    expect(await service.bul(trustId), isNotNull);
  });

  for (final consuming in [false, true]) {
    test(
      'clearing invalidates an in-flight ${consuming ? 'consume' : 'issue'}',
      () async {
        await enroll();
        final nonce = await service.challengeOlustur(trustId);
        final started = Completer<void>();
        final release = Completer<void>();
        depo.beforeRead = () async {
          started.complete();
          await release.future;
        };
        final operation =
            consuming ? consume(nonce) : service.challengeOlustur(trustId);
        final expectation = expectLater(operation, denied);
        await started.future;
        service.challengeTemizle();
        depo.beforeRead = null;
        release.complete();
        await expectation;
      },
    );
  }

  test('account changes during a protected lookup fail closed', () async {
    await enroll();
    depo.beforeRead = () async {
      await db.update('arsiv_hesabi', {
        'yonetici_id': GuvenilirCihazServisi.yeniGuvenId(),
      });
    };
    expect(await service.bul(trustId), isNull);
    depo.beforeRead = null;
  });

  test(
    'default secure storage uses namespace, device-only keychain and no reset',
    () {
      final storage = const GuvenilirCihazGuvenliDeposu().storage;
      expect(storage.aOptions.toMap()['resetOnError'], 'false');
      expect(
        storage.aOptions.toMap()['storageNamespace'],
        'arsivim_trusted_devices_v1',
      );
      expect(storage.aOptions.toMap()['migrateWithBackup'], 'true');
      expect(storage.iOptions.toMap()['synchronizable'], 'false');
      expect(storage.iOptions.toMap()['accessibility'], 'unlocked_this_device');
    },
  );
}
