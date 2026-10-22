import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arsiv_uygulamasi/services/aktarim_http.dart';
import 'package:arsiv_uygulamasi/services/arsiv_hesap_servisi.dart';
import 'package:arsiv_uygulamasi/services/auth_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenilir_cihaz_servisi.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/services/http_sunucu_servisi.dart';
import 'package:arsiv_uygulamasi/services/parola_servisi.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'guvenli_aktarim_test.dart' as fixture;

class _NetworkTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Vault implements GuvenilirCihazDeposu {
  String? value;
  @override
  Future<String?> oku() async => value;
  @override
  Future<void> yaz(String deger) async => value = deger;
}

/// Real trust persistence with an injected post-save delay/failure to exercise
/// overlapping HTTP connection attempts and lock cleanup deterministically.
class _DelayedTrust extends GuvenilirCihazServisi {
  Future<void> Function()? afterSave;
  _DelayedTrust(super.db, {required super.depo});

  @override
  Future<void> kaydet({
    required String guvenId,
    required String gizliAnahtar,
    required Map<String, dynamic> hesap,
    required String cihazId,
    required String cihazAdi,
    String? platform,
    String? sonIp,
    int port = 8080,
  }) async {
    final hook = afterSave;
    afterSave = null;
    await super.kaydet(
      guvenId: guvenId,
      gizliAnahtar: gizliAnahtar,
      hesap: hesap,
      cihazId: cihazId,
      cihazAdi: cihazAdi,
      platform: platform,
      sonIp: sonIp,
      port: port,
    );
    await hook?.call();
  }
}

/// Only the header signing is reproduced: production encryption/decryption and
/// dispatch still run on real sockets. Needed for Origin and exact nonce replay,
/// which the normal client intentionally does not expose.
Future<({int status, Map<String, dynamic> body, List<int> wire})> _raw(
  Uri uri, {
  String? key,
  String? trustId,
  String? origin,
  String? nonce,
  required Map<String, dynamic> body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.followRedirects = false;
    final id = nonce ?? GuvenliAktarimServisi.kimlik();
    if (key != null) {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      request.headers.set('x-arsiv-id', id);
      request.headers.set('x-arsiv-time', time);
      request.headers.set(
        'x-arsiv-proof',
        Hmac(
          sha256,
          utf8.encode('arsiv-v2-auth:$key'),
        ).convert(utf8.encode('POST\n${uri.path}\n$id\n$time')).toString(),
      );
    }
    if (trustId != null) request.headers.set('x-arsiv-trust', trustId);
    if (origin != null) request.headers.set('Origin', origin);
    final plain = utf8.encode(jsonEncode(body));
    final bytes =
        key == null
            ? plain
            : await AktarimHttp.sifrele(
              Stream.value(plain),
              key,
              '$id:request',
            ).expand((chunk) => chunk).toList();
    if (key != null) {
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains(jsonEncode(body))),
      );
    }
    request.headers.contentType = ContentType.binary;
    request.add(bytes);
    final response = await request.close().timeout(const Duration(seconds: 10));
    final wire = await response.expand((chunk) => chunk).toList();
    final decoded =
        response.headers.contentType?.mimeType == ContentType.binary.mimeType
            ? await AktarimHttp.jsonOku(
              AktarimHttp.coz(Stream.value(wire), key!, '$id:response'),
            )
            : (jsonDecode(utf8.decode(wire)) as Map).cast<String, dynamic>();
    return (status: response.statusCode, body: decoded, wire: wire);
  } finally {
    client.close(force: true);
  }
}

void main() {
  _NetworkTestBinding();
  sqfliteFfiInit();
  late Directory root;
  late Database db;
  late AuthServisi loggedInAuth;
  late AuthServisi auth;
  late Map<String, Object> savedPreferences;
  late List<Map<String, Object?>> originalDocuments;
  late List<Map<String, Object?>> originalPeople;
  late _Vault vault;
  late GuvenilirCihazServisi trust;
  late HttpSunucuServisi handler;
  HttpServer? listener;
  StreamSubscription<HttpRequest>? subscription;
  late String trustId;
  late String secret;
  late String peerId;
  late String reverseToken;
  String? transportToken;
  late Map<String, dynamic> account;
  late List<Map<String, dynamic>> connected;
  late List<Map<String, dynamic>> disconnected;
  var reverseChecks = 0;
  var reverseFails = false;

  Uri uri(String endpoint) =>
      Uri.parse('http://127.0.0.1:${listener!.port}/sync/v2/$endpoint');

  Future<void> closeServer() async {
    await listener?.close(force: true);
    await subscription?.cancel();
    listener = null;
    subscription = null;
  }

  Future<void> startServer() async {
    transportToken = null;
    handler = HttpSunucuServisi.test(
      auth: auth,
      guven: trust,
      belgeler: Directory(p.join(root.path, 'documents')),
      reverseCheck: (ip, token) async {
        reverseChecks++;
        expect(ip, '127.0.0.1');
        expect(token, reverseToken);
        if (reverseFails) throw const SocketException('reverse refused');
      },
    );
    handler.setOnDeviceConnected((device) => connected.add(Map.from(device)));
    handler.setOnDeviceDisconnected(
      (device) => disconnected.add(Map.from(device)),
    );
    listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    subscription = listener!.listen(handler.aktarimIstegiIsle);
  }

  Future<Map<String, dynamic>> request(
    String endpoint, {
    Map<String, dynamic> body = const {},
    String? key,
    String? credential,
  }) => AktarimHttp.jsonIstek(
    uri(endpoint),
    key ??
        (endpoint == 'pair'
            ? handler.aktarimAnahtari
            : transportToken ?? handler.aktarimAnahtari),
    body: body,
    guvenId: credential,
  ).timeout(const Duration(seconds: 15));

  Future<Map<String, dynamic>> pairBody() async {
    reverseToken = GuvenliAktarimServisi.kimlik();
    final ticket = await handler.hesapEslesmesi.biletOlustur();
    return {
      'account_version': 1,
      'session_version': 1,
      'pair_ticket': ticket['pair_ticket'],
      'account': await auth.hesapTanitim(yeniDogrulama: true),
      'reverse_token': reverseToken,
      'trust_version': 1,
      'trust_id': trustId,
      'trust_secret': secret,
      'device_id': peerId,
      'device_name': 'HTTP test phone',
      'platform': 'test',
    };
  }

  Future<void> pair({bool ready = true}) async {
    final response = await request('pair', body: await pairBody());
    expect(response['success'], true, reason: '$response');
    expect(response['trust_id'], trustId);
    expect(response['session_version'], 1);
    transportToken = response['transfer_token'] as String;
    expect(transportToken, isNot(handler.aktarimAnahtari));
    account = Map<String, dynamic>.from(response['account'] as Map);
    if (ready) expect((await request('ready'))['success'], true);
  }

  Map<String, dynamic> trustBody() => {
    'trust_version': 1,
    'device_id': peerId,
    'archive_id': account['arsiv_id'],
    'owner_id': account['yonetici_id'],
  };

  Future<String> challenge() async {
    final response = await request(
      'trust-challenge',
      key: secret,
      credential: trustId,
      body: trustBody(),
    );
    expect(response['success'], true, reason: '$response');
    expect(response['device_id'], await trust.cihazKimligi());
    expect(jsonEncode(response), isNot(contains(secret)));
    return response['challenge'] as String;
  }

  Future<Map<String, dynamic>> resume(
    String nonce, {
    Map<String, dynamic>? overrides,
  }) async {
    reverseToken = GuvenliAktarimServisi.kimlik();
    final response = await request(
      'trust-resume',
      key: secret,
      credential: trustId,
      body: {
        ...trustBody(),
        'challenge': nonce,
        'reverse_token': reverseToken,
        ...?overrides,
      },
    );
    if (response['success'] == true) {
      transportToken = response['transfer_token'] as String;
    }
    return response;
  }

  Future<void> inventoryDenied({String? key}) async {
    final response = await _raw(
      uri('inventory'),
      key: key ?? transportToken ?? handler.aktarimAnahtari,
      body: {},
    );
    expect(response.status, anyOf(401, 409));
    expect(response.body['success'], false);
    expect(response.body, isNot(contains('items')));
  }

  Future<void> disconnect() async =>
      expect((await request('disconnect'))['success'], true);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('trusted-http-test-');
    db = await fixture.testDb(p.join(root.path, 'isolated.db'));
    const password = 'Fixture-Only-Password-123';
    await db.insert('kisiler', {
      ...fixture.kisi(),
      'sifre': await ParolaServisi.olustur(password),
    });
    loggedInAuth = AuthServisi.test(db);
    final login = await loggedInAuth.login(
      kullaniciAdi: 'ali',
      sifre: password,
    );
    expect(login.success, true, reason: login.message);
    final prefs = await SharedPreferences.getInstance();
    savedPreferences = {
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    };
    final batch = db.batch();
    for (var id = 1; id <= 205; id++) {
      batch.insert('belgeler', {
        'id': id,
        'dosya_adi': '$id.pdf',
        'orijinal_dosya_adi': '$id.pdf',
        'dosya_yolu': p.join(root.path, 'not-read-$id.pdf'),
        'dosya_boyutu': 1,
        'dosya_tipi': 'pdf',
        'dosya_hash': sha256.convert(utf8.encode('fixture-$id')).toString(),
        'baslik': 'Fixture $id',
        'etiketler': '[]',
        'aktif': 1,
        'senkron_durumu': 4,
        'olusturma_tarihi': '2020-01-01T00:00:00Z',
        'guncelleme_tarihi': '2021-01-01T00:00:00Z',
      });
    }
    await batch.commit(noResult: true);
    originalDocuments = await db.query('belgeler', orderBy: 'id');
    originalPeople = await db.query('kisiler', orderBy: 'id');
  });

  setUp(() async {
    reverseChecks = 0;
    reverseFails = false;
    SharedPreferences.setMockInitialValues(savedPreferences);
    auth = loggedInAuth;
    vault = _Vault();
    trust = GuvenilirCihazServisi(db, depo: vault);
    trustId = GuvenilirCihazServisi.yeniGuvenId();
    secret = GuvenilirCihazServisi.yeniGuvenAnahtari();
    peerId = GuvenilirCihazServisi.yeniGuvenId();
    reverseToken = GuvenliAktarimServisi.kimlik();
    connected = [];
    disconnected = [];
    account = await auth.hesapTanitim();
    await startServer();
  });

  tearDown(() async {
    await closeServer();
    expect(await db.query('belgeler', orderBy: 'id'), originalDocuments);
    expect(await db.query('kisiler', orderBy: 'id'), originalPeople);
  });

  tearDownAll(() async {
    loggedInAuth.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'Reverse connection failure prevents connected status and preserves archive',
    () async {
      await pair(ready: false);
      reverseFails = true;
      final failed = await request('ready', body: {'reverse_check': 1});
      expect(failed['success'], false);
      expect(failed['kod'], 'TERS_BAGLANTI');
      expect(connected, isEmpty);
      expect(handler.bagliCihazlar, isEmpty);
      reverseFails = false;
      expect(
        (await request('ready', body: {'reverse_check': 1}))['success'],
        true,
      );
      expect(reverseChecks, 2);
      expect(connected.single['device_id'], peerId);
    },
  );

  test(
    'Trusted resume also verifies the reverse direction before announcing connection',
    () async {
      await pair();
      await disconnect();
      connected.clear();
      expect((await resume(await challenge()))['success'], true);
      expect(connected, isEmpty);
      expect(
        (await request('ready', body: {'reverse_check': 1}))['success'],
        true,
      );
      expect(reverseChecks, 1);
      expect(connected.single['device_id'], peerId);
    },
  );

  test(
    'encrypted QR enrollment persists secret; ready callback fires exactly once',
    () async {
      final body = await pairBody();
      final response = await _raw(
        uri('pair'),
        key: handler.aktarimAnahtari,
        body: body,
      );
      expect(response.status, 200);
      expect(response.body['success'], true);
      expect(response.body['trust_version'], 1);
      expect(response.body['session_version'], 1);
      transportToken = response.body['transfer_token'] as String;
      expect(
        utf8.decode(response.wire, allowMalformed: true),
        isNot(contains('success')),
      );
      expect(connected, isEmpty);
      expect(handler.bagliCihazlar, isEmpty);
      expect((await trust.bul(trustId))!.gizliAnahtar, secret);
      expect(vault.value, contains(secret));
      expect(
        jsonEncode(await db.query('guvenilir_cihazlar_v1')),
        isNot(contains(secret)),
      );
      expect(jsonEncode(response.body), isNot(contains(secret)));
      expect((await request('ready'))['success'], true);
      expect(connected.single['device_id'], peerId);
      expect(handler.bagliCihazlar, hasLength(1));
      expect((await request('ready'))['success'], true);
      expect(connected, hasLength(1));
      // A new encrypted request must not make a consumed QR ticket reusable.
      expect((await request('pair', body: body))['success'], false);
      await disconnect();
      expect(disconnected.single['device_id'], peerId);
      expect(handler.bagliCihazlar, isEmpty);
      expect(await trust.bul(trustId), isNotNull);
    },
  );

  test(
    'restart restores trusted connection without recent password and pages inventory',
    () async {
      await pair();
      final oldToken = transportToken!;
      final oldDevice = await trust.cihazKimligi();
      await disconnect();
      await inventoryDenied();
      await closeServer();
      auth = AuthServisi.test(db);
      expect(await auth.checkAutoLogin(), true);
      await expectLater(
        auth.hesapTanitim(yeniDogrulama: true),
        throwsA(isA<HesapHatasi>()),
      );
      trust = GuvenilirCihazServisi(db, depo: vault);
      await startServer();
      expect(await trust.cihazKimligi(), oldDevice);
      expect(await trust.bul(trustId), isNotNull);
      final nonce = await challenge();
      reverseToken = GuvenliAktarimServisi.kimlik();
      final response = await resume(nonce);
      expect(response['success'], true);
      expect(response['transfer_token'], handler.gelenAnahtarlar['127.0.0.1']);
      expect(response['transfer_token'], isNot(oldToken));
      expect(handler.eslesmisAnahtarlar['127.0.0.1'], reverseToken);
      expect(connected, hasLength(1));
      expect((await request('ready'))['success'], true);
      expect(connected, hasLength(2));
      await expectLater(
        request('inventory', key: oldToken),
        throwsA(isA<AktarimHatasi>()),
      );
      final first = await request('inventory');
      expect(first['success'], true);
      expect(first['items'], hasLength(200));
      expect(first['next'], 200);
      final last = await request('inventory', body: {'after': first['next']});
      expect((last['items'] as List).map((item) => item['id']).toList(), [
        201,
        202,
        203,
        204,
        205,
      ]);
      expect(last['next'], isNull);
      final capabilities = await AktarimHttp.jsonIstek(
        uri('capabilities'),
        transportToken!,
      );
      expect(capabilities['inventory_version'], 1);
      expect(capabilities['direction_version'], 1);
    },
  );

  test(
    'unsigned inventory, unpaired transport, wrong secret and unknown trust fail',
    () async {
      final unsigned = await _raw(uri('inventory'), body: {});
      expect(unsigned.status, 401);
      expect(unsigned.body['success'], false);
      await inventoryDenied();
      await pair();
      await disconnect();
      for (final credential in [trustId, GuvenilirCihazServisi.yeniGuvenId()]) {
        await expectLater(
          request(
            'trust-challenge',
            key:
                credential == trustId
                    ? GuvenilirCihazServisi.yeniGuvenAnahtari()
                    : secret,
            credential: credential,
            body: trustBody(),
          ),
          throwsA(isA<AktarimHatasi>()),
        );
      }
      expect(handler.eslesmisAnahtarlar, isEmpty);
      await inventoryDenied();
      expect(await trust.bul(trustId), isNotNull);
    },
  );

  test('Origin is rejected on pair, inventory, challenge and resume', () async {
    final pairRequest = await _raw(
      uri('pair'),
      key: handler.aktarimAnahtari,
      origin: 'https://attacker.invalid',
      body: await pairBody(),
    );
    expect(pairRequest.status, 401);
    expect(await trust.bul(trustId), isNull);
    await pair();
    final nonce = await challenge();
    for (final endpoint in ['inventory', 'trust-challenge', 'trust-resume']) {
      final response = await _raw(
        uri(endpoint),
        key: endpoint == 'inventory' ? transportToken! : secret,
        trustId: trustId,
        origin: 'null',
        body: {
          ...trustBody(),
          'challenge': nonce,
          'reverse_token': reverseToken,
        },
      );
      expect(response.status, 401, reason: endpoint);
      expect(response.body['success'], false);
    }
    await disconnect();
    expect((await resume(nonce))['success'], true);
  });

  test(
    'consumed and pre-restart challenges and exact HTTP nonce replay fail',
    () async {
      await pair();
      await disconnect();
      final nonce = await challenge();
      expect((await resume(nonce))['success'], true);
      // Fresh signed HTTP nonce, same consumed challenge: challenge replay layer.
      expect((await resume(nonce))['success'], false);
      final requestNonce = GuvenliAktarimServisi.kimlik();
      final first = await _raw(
        uri('ready'),
        key: transportToken!,
        nonce: requestNonce,
        body: {},
      );
      expect(first.status, 200);
      final replay = await _raw(
        uri('ready'),
        key: transportToken!,
        nonce: requestNonce,
        body: {},
      );
      expect(replay.status, 401);
      final captured = await challenge();
      await closeServer();
      trust = GuvenilirCihazServisi(db, depo: vault);
      await startServer();
      expect((await resume(captured))['success'], false);
      expect(handler.eslesmisAnahtarlar, isEmpty);
      expect((await resume(await challenge()))['success'], true);
    },
  );

  test(
    'resume rejects wrong device, archive, owner and reverse token',
    () async {
      await pair();
      await disconnect();
      for (final field in [
        'device_id',
        'archive_id',
        'owner_id',
        'reverse_token',
      ]) {
        final nonce = await challenge();
        final response = await resume(
          nonce,
          overrides: {
            field:
                field == 'reverse_token'
                    ? 'invalid'
                    : GuvenilirCihazServisi.yeniGuvenId(),
          },
        );
        expect(response['success'], false, reason: field);
        expect(handler.eslesmisAnahtarlar, isEmpty);
        await inventoryDenied();
      }
    },
  );

  test(
    'revocation rejects live inventory and captured resume across restart',
    () async {
      await pair();
      final nonce = await challenge();
      await GuvenilirCihazServisi(db, depo: vault).unut(trustId);
      final response = await request('inventory');
      expect(response['success'], false);
      expect(response, isNot(contains('items')));
      expect(handler.eslesmisAnahtarlar, isEmpty);
      await expectLater(resume(nonce), throwsA(isA<AktarimHatasi>()));
      await closeServer();
      trust = GuvenilirCihazServisi(db, depo: vault);
      await startServer();
      await expectLater(challenge(), throwsA(isA<AktarimHatasi>()));
      expect(await trust.bul(trustId), isNull);
      expect(vault.value, isNot(contains(secret)));
    },
  );

  test(
    'old connection key cannot authorize or decrypt a replacement session',
    () async {
      await pair();
      final qrKey = handler.aktarimAnahtari;
      final pairedKey = transportToken!;
      await disconnect();
      expect((await resume(await challenge()))['success'], true);
      final resumedKey = transportToken!;
      expect(resumedKey, isNot(pairedKey));
      await inventoryDenied(key: pairedKey);
      await inventoryDenied(key: qrKey);

      final revokedId = trustId;
      final revokedSecret = secret;
      final captured = await challenge();
      final revokedBody = {
        ...trustBody(),
        'challenge': captured,
        'reverse_token': GuvenliAktarimServisi.kimlik(),
      };
      await trust.unut(revokedId);
      await inventoryDenied(key: resumedKey);
      trustId = GuvenilirCihazServisi.yeniGuvenId();
      secret = GuvenilirCihazServisi.yeniGuvenAnahtari();
      await pair();
      final newKey = transportToken!;
      expect(newKey, isNot(resumedKey));
      await inventoryDenied(key: resumedKey);
      final nonce = GuvenliAktarimServisi.kimlik();
      final current = await _raw(
        uri('inventory'),
        key: newKey,
        nonce: nonce,
        body: {'after': 200},
      );
      expect(current.status, 200);
      expect(current.body['items'], hasLength(5));
      await expectLater(
        AktarimHttp.jsonOku(
          AktarimHttp.coz(
            Stream.value(current.wire),
            resumedKey,
            '$nonce:response',
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        request(
          'trust-resume',
          key: revokedSecret,
          credential: revokedId,
          body: revokedBody,
        ),
        throwsA(isA<AktarimHatasi>()),
      );
      expect(handler.gelenAnahtarlar['127.0.0.1'], newKey);
      expect(
        (await request('inventory', body: {'after': 200}))['success'],
        true,
      );
    },
  );

  test(
    'overlapping pair and resume are rejected; failure releases connection lock',
    () async {
      await closeServer();
      final delayed = _DelayedTrust(db, depo: vault);
      trust = delayed;
      await startServer();
      await pair();
      await disconnect();
      final entered = Completer<void>();
      final release = Completer<void>();
      delayed.afterSave = () async {
        entered.complete();
        await release.future;
        throw StateError('Injected late old-resume failure');
      };
      final pending = resume(await challenge());
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await pending;
      });
      await entered.future.timeout(const Duration(seconds: 5));
      final oldSession = handler.hesapEslesmesi.baglantiKimligi('127.0.0.1');
      final overlapping = await request('pair', body: await pairBody());
      expect(overlapping['success'], false);
      expect(overlapping['kod'], 'HESAP');
      await expectLater(
        resume(await challenge()),
        throwsA(isA<AktarimHatasi>()),
      );
      expect(handler.hesapEslesmesi.baglantiKimligi('127.0.0.1'), oldSession);
      release.complete();
      expect((await pending)['success'], false);
      expect(handler.eslesmisAnahtarlar, isEmpty);
      expect(handler.gelenAnahtarlar, isEmpty);
      await pair();
      final newSession = handler.hesapEslesmesi.baglantiKimligi('127.0.0.1');
      final newKey = transportToken;
      expect(newSession, isNot(oldSession));
      expect(handler.hesapEslesmesi.baglantiKimligi('127.0.0.1'), newSession);
      expect(handler.gelenAnahtarlar['127.0.0.1'], newKey);
      expect(handler.guvenBaglantilari['127.0.0.1'], trustId);
      expect(
        (await request('inventory', body: {'after': 200}))['success'],
        true,
      );
    },
  );

  test(
    'send commands validate IDs and retry once; status and stop use session owner',
    () async {
      await pair();
      var sends = 0;
      var stops = 0;
      final started = Completer<void>();
      final finish = Completer<Map<String, dynamic>>();
      addTearDown(() async {
        if (!finish.isCompleted) finish.complete({'status': 'cancelled'});
        await Future<void>.delayed(Duration.zero);
      });
      handler.onUzakGonderim = (ip, ids) async {
        sends++;
        expect(ip, '127.0.0.1');
        expect(ids, [1, 2]);
        started.complete();
        return finish.future;
      };
      handler.onUzakDurdur = () => stops++;
      for (final ids in <dynamic>[
        '1',
        [],
        [0],
        [-1],
        ['1'],
        [1.0],
        List.generate(201, (i) => i + 1),
      ]) {
        expect(
          (await request(
            'send-request',
            body: {'request_id': 'invalid', 'ids': ids},
          ))['success'],
          false,
        );
      }
      for (final id in <dynamic>[null, 1, '', 'x' * 129]) {
        expect(
          (await request(
            'send-request',
            body: {
              'request_id': id,
              'ids': [1],
            },
          ))['success'],
          false,
        );
      }
      expect(sends, 0);
      final command = {
        'request_id': 'valid-request',
        'ids': [1, 2],
      };
      final response = await request('send-request', body: command);
      expect(response['success'], true);
      await started.future.timeout(const Duration(seconds: 5));
      final job = response['job_id'] as String;
      expect((await request('send-request', body: command))['job_id'], job);
      expect(sends, 1);
      expect(
        (await request('send-status', body: {'job_id': job}))['status'],
        'running',
      );
      expect(
        (await request(
          'send-request',
          body: {
            'request_id': 'valid-request',
            'ids': [2, 1],
          },
        ))['success'],
        false,
      );
      expect(
        (await request('send-stop', body: {'job_id': job}))['status'],
        'stopping',
      );
      expect(
        (await request('send-stop', body: {'job_id': job}))['status'],
        'stopping',
      );
      expect(stops, 1);
      finish.complete({'status': 'cancelled', 'sent': 0});
      Map<String, dynamic> status = {};
      for (var attempt = 0; attempt < 10; attempt++) {
        status = await request('send-status', body: {'job_id': job});
        if (status['status'] == 'cancelled') break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(status['status'], 'cancelled');
      final oldOwner = handler.hesapEslesmesi.baglantiKimligi('127.0.0.1');
      await disconnect();
      expect((await resume(await challenge()))['success'], true);
      expect(
        handler.hesapEslesmesi.baglantiKimligi('127.0.0.1'),
        isNot(oldOwner),
      );
      for (final endpoint in ['send-status', 'send-stop']) {
        final foreign = await request(
          endpoint,
          body: {'job_id': job, 'owner': oldOwner},
        );
        final missing = await request(endpoint, body: {'job_id': 'missing'});
        expect(foreign, missing);
        expect(foreign['error'], 'not_found');
        expect(
          (await request(endpoint, body: {'job_id': 123}))['success'],
          false,
        );
      }
      expect(stops, 1);
    },
  );
}
