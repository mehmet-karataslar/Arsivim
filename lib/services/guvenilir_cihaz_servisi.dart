import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import 'arsiv_hesap_servisi.dart';

/// Atomic, confidential storage; implementations must never silently reset on error.
/// Tests can inject an in-memory implementation without platform channels.
abstract class GuvenilirCihazDeposu {
  Future<String?> oku();
  Future<void> yaz(String deger);
}

class GuvenilirCihazGuvenliDeposu implements GuvenilirCihazDeposu {
  static const _key = 'arsivim.trusted_devices.v1';
  final FlutterSecureStorage storage;

  const GuvenilirCihazGuvenliDeposu({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'arsivim_trusted_devices_v1',
        resetOnError: false,
        migrateWithBackup: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
    ),
  });

  @override
  Future<String?> oku() => storage.read(key: _key);

  @override
  Future<void> yaz(String deger) async {
    await storage.write(key: _key, value: deger);
    if (await oku() != deger) {
      throw HesapHatasi('Guvenli cihaz kaydi dogrulanamadi.');
    }
  }
}

/// Never log [gizliAnahtar] or include it in discovery, UI, backups or resume bodies.
class GuvenilirCihaz {
  final String guvenId;
  final String gizliAnahtar;
  final String arsivId;
  final String yoneticiId;
  final String cihazId;
  final String cihazAdi;
  final String? platform;
  final String? sonIp;
  final int port;
  final DateTime olusturmaTarihi;

  GuvenilirCihaz._(Map<String, dynamic> row)
    : guvenId = row['trust_id'] as String,
      gizliAnahtar = row['secret'] as String,
      arsivId = row['archive_id'] as String,
      yoneticiId = row['owner_id'] as String,
      cihazId = row['device_id'] as String,
      cihazAdi = row['device_name'] as String,
      platform = row['platform'] as String?,
      sonIp = row['last_ip'] as String?,
      port = row['port'] as int,
      olusturmaTarihi = DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      );

  /// Public metadata only; even jsonEncode(record.toMap()) cannot leak the key.
  Map<String, dynamic> toMap() => {
    'trust_id': guvenId,
    'archive_id': arsivId,
    'owner_id': yoneticiId,
    'device_id': cihazId,
    'device_name': cihazAdi,
    'platform': platform,
    'last_ip': sonIp,
    'port': port,
    'created_at': olusturmaTarihi.millisecondsSinceEpoch,
  };

  @override
  String toString() => 'GuvenilirCihaz($guvenId, $cihazId)';
}

/// Persistent trust, not a login bypass or a standalone network authentication API.
///
/// Integration contract:
/// * Use one instance for /challenge and /resume, while keeping local admin auth.
/// * Enroll only after verified QR/account pairing, with a NEW random trust ID and
///   key sent inside the existing authenticated/encrypted pair request.
/// * Look up x-arsiv-trust with [bul], authenticate AND decrypt with AktarimHttp
///   using its gizliAnahtar, then issue/consume the challenge. Never return the
///   secret in an HTTP response. Bind responses to AktarimHttp's request nonce.
/// * Consume the challenge before authorizing resume or exchanging fresh session
///   tokens. Check auth session generation around awaits in the HTTP integration.
/// * Logout/disconnect can clear challenges without revoking persistent trust.
///   Forget must also drop any already-authorized HTTP/manager sessions.
///
/// The secure vault is authoritative. The public archive DB is metadata only;
/// copying, modifying or restoring it cannot grant/revive device trust. All writes
/// are additive to existing archive tables. No password is accepted or stored.
/// Use this service on the app's owning isolate; the lock is not cross-process.
class GuvenilirCihazServisi {
  final Database db;
  final GuvenilirCihazDeposu depo;
  final DateTime Function() saat;

  static const challengeOmru = Duration(seconds: 60);
  static const azamiChallenge = 256;
  static const _azamiCihazChallenge = 8;
  static const _tablo = 'guvenilir_cihazlar_v1';
  static final _id = RegExp(r'^[a-f0-9]{48}$');
  static final _key = RegExp(r'^[a-f0-9]{64}$');
  static Future<void> _sira = Future<void>.value();
  final Map<String, _Challenge> _challenges = {};
  int _challengeNesli = 0;

  GuvenilirCihazServisi(
    this.db, {
    GuvenilirCihazDeposu? depo,
    DateTime Function()? saat,
  }) : depo = depo ?? const GuvenilirCihazGuvenliDeposu(),
       saat = saat ?? DateTime.now;

  static String _rastgele(int bytes) {
    final random = Random.secure();
    return List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String yeniGuvenId() => _rastgele(24);
  static String yeniGuvenAnahtari() => _rastgele(32);

  // Covers all instances sharing the same OS vault, including identity creation.
  static Future<T> _sirali<T>(Future<T> Function() action) {
    final result = _sira.then((_) => action());
    _sira = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<_Kasa> _kasa() async {
    final value = await depo.oku();
    if (value == null) {
      final vault = _Kasa(yeniGuvenId(), {});
      await depo.yaz(vault.kodla());
      return vault;
    }
    try {
      if (value.length > 4 * 1024 * 1024) throw const FormatException();
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 || !_kimlikGecerli(data['device_id'])) {
        throw const FormatException();
      }
      final rows = data['records'] as Map<String, dynamic>;
      final records = <String, Map<String, dynamic>>{};
      for (final entry in rows.entries) {
        final row = Map<String, dynamic>.from(entry.value as Map);
        if (!_kimlikGecerli(entry.key) ||
            row['trust_id'] != entry.key ||
            row['local_device_id'] != data['device_id'] ||
            !_kimlikGecerli(row['archive_id']) ||
            !_kimlikGecerli(row['owner_id']) ||
            !_kimlikGecerli(row['device_id']) ||
            row['device_id'] == data['device_id'] ||
            row['created_at'] is! int ||
            row['created_at'] < 0 ||
            row['created_at'] > 8640000000000000 ||
            (row['revoked_at'] != null && row['revoked_at'] is! int)) {
          throw const FormatException();
        }
        _metadataDogrula(
          row['device_name'],
          row['platform'],
          row['last_ip'],
          row['port'],
        );
        if (row['revoked_at'] == null) {
          if (row['secret'] is! String || !_key.hasMatch(row['secret'])) {
            throw const FormatException();
          }
        } else if (row.containsKey('secret')) {
          throw const FormatException();
        }
        records[entry.key] = row;
      }
      return _Kasa(data['device_id'] as String, records);
    } catch (_) {
      // Corrupt/unsupported data is retained, never replaced with an empty vault.
      throw HesapHatasi('Guvenli cihaz deposu okunamadi; kayitlar korunuyor.');
    }
  }

  static bool _kimlikGecerli(dynamic value) =>
      value is String && _id.hasMatch(value);

  static void _metadataDogrula(
    dynamic name,
    dynamic platform,
    dynamic ip,
    dynamic port,
  ) {
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 256 ||
        (platform != null && (platform is! String || platform.length > 64)) ||
        (ip != null && (ip is! String || ip.isEmpty || ip.length > 255)) ||
        port is! int ||
        port < 1 ||
        port > 65535) {
      throw HesapHatasi('Cihaz bilgileri gecersiz.');
    }
  }

  Future<({String arsiv, String yonetici})> _hesap() async {
    // Do not invoke account migrations or touch legacy people/documents here.
    final rows = await db.query(
      'arsiv_hesabi',
      columns: ['arsiv_id', 'yonetici_id'],
    );
    if (rows.length != 1 ||
        !_kimlikGecerli(rows.single['arsiv_id']) ||
        !_kimlikGecerli(rows.single['yonetici_id'])) {
      throw HesapHatasi('Dogrulanmis arsiv hesabi gerekli.');
    }
    return (
      arsiv: rows.single['arsiv_id'] as String,
      yonetici: rows.single['yonetici_id'] as String,
    );
  }

  Future<void> _hazirla() => db.execute('''
    CREATE TABLE IF NOT EXISTS $_tablo (
      trust_id TEXT PRIMARY KEY, archive_id TEXT NOT NULL,
      owner_id TEXT NOT NULL, device_id TEXT NOT NULL,
      device_name TEXT NOT NULL, platform TEXT, last_ip TEXT,
      port INTEGER NOT NULL, created_at INTEGER NOT NULL, revoked_at INTEGER)
  ''');

  Future<void> _yansit(Map<String, dynamic> row) async {
    await db.insert(_tablo, {
      for (final key in [
        'trust_id',
        'archive_id',
        'owner_id',
        'device_id',
        'device_name',
        'platform',
        'last_ip',
        'port',
        'created_at',
        'revoked_at',
      ])
        key: row[key],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> cihazKimligi() => _sirali(() async => (await _kasa()).cihazId);

  /// The supplied account must ALREADY be bound and verified by pairing/auth.
  /// Re-pair with a new trust ID/key; old trust for the same peer is revoked.
  /// An identical ID/key/peer retry is idempotent and can update address metadata.
  Future<void> kaydet({
    required String guvenId,
    required String gizliAnahtar,
    required Map<String, dynamic> hesap,
    required String cihazId,
    required String cihazAdi,
    String? platform,
    String? sonIp,
    int port = 8080,
  }) => _sirali(() async {
    if (!_kimlikGecerli(guvenId) ||
        !_kimlikGecerli(cihazId) ||
        !_key.hasMatch(gizliAnahtar)) {
      throw HesapHatasi('Guven kimligi veya anahtari gecersiz.');
    }
    _metadataDogrula(cihazAdi, platform, sonIp, port);
    final scope = await _hesap();
    if (hesap['arsiv_id'] != scope.arsiv ||
        hesap['yonetici_id'] != scope.yonetici) {
      throw HesapHatasi('Cihaz guveni farkli bir arsive kaydedilemez.');
    }
    final vault = await _kasa();
    if (cihazId == vault.cihazId) {
      throw HesapHatasi('Cihaz kendisiyle eslesemez.');
    }
    final old = vault.records[guvenId];
    if (old != null &&
        (old['revoked_at'] != null ||
            old['secret'] != gizliAnahtar ||
            old['device_id'] != cihazId ||
            old['archive_id'] != scope.arsiv ||
            old['owner_id'] != scope.yonetici)) {
      throw HesapHatasi(
        'Guven kimligi yeniden kullanilamaz. Yeni QR ile eslestirin.',
      );
    }
    final now = saat().millisecondsSinceEpoch;
    final changed = <Map<String, dynamic>>[];
    for (final row in vault.records.values) {
      if (row['trust_id'] != guvenId &&
          row['revoked_at'] == null &&
          row['archive_id'] == scope.arsiv &&
          row['owner_id'] == scope.yonetici &&
          row['device_id'] == cihazId) {
        row.remove('secret');
        row['revoked_at'] = now;
        changed.add(row);
      }
    }
    final row = <String, dynamic>{
      'trust_id': guvenId,
      'secret': gizliAnahtar,
      'local_device_id': vault.cihazId,
      'archive_id': scope.arsiv,
      'owner_id': scope.yonetici,
      'device_id': cihazId,
      'device_name': cihazAdi.trim(),
      'platform': platform,
      'last_ip': sonIp,
      'port': port,
      'created_at': old?['created_at'] ?? now,
      'revoked_at': null,
    };
    vault.records[guvenId] = row;
    await _hazirla();
    if (await _hesap() != scope) throw HesapHatasi('Arsiv hesabi degisti.');
    // Prepare metadata before committing new authority; a failed vault write must
    // never leave an authorized peer based solely on the public database.
    await _yansit(row);
    await depo.yaz(vault.kodla());
    for (final revoked in changed) {
      _challenges.removeWhere((_, c) => c.guvenId == revoked['trust_id']);
      await _yansit(revoked);
    }
    if (await _hesap() != scope) throw HesapHatasi('Arsiv hesabi degisti.');
  });

  Future<GuvenilirCihaz?> _bul(String guvenId) async {
    if (!_kimlikGecerli(guvenId)) return null;
    final scope = await _hesap();
    final vault = await _kasa();
    final row = vault.records[guvenId];
    if (row == null ||
        row['revoked_at'] != null ||
        row['archive_id'] != scope.arsiv ||
        row['owner_id'] != scope.yonetici ||
        await _hesap() != scope) {
      return null;
    }
    return GuvenilirCihaz._(row);
  }

  Future<GuvenilirCihaz?> bul(String guvenId) => _sirali(() => _bul(guvenId));

  Future<List<GuvenilirCihaz>> listele() => _sirali(() async {
    final scope = await _hesap();
    final vault = await _kasa();
    final result =
        vault.records.values
            .where(
              (row) =>
                  row['revoked_at'] == null &&
                  row['archive_id'] == scope.arsiv &&
                  row['owner_id'] == scope.yonetici,
            )
            .map(GuvenilirCihaz._)
            .toList();
    if (await _hesap() != scope) throw HesapHatasi('Arsiv hesabi degisti.');
    result.sort((a, b) => a.cihazAdi.compareTo(b.cihazAdi));
    return result;
  });

  /// Revocation is durable before touching the public DB; stale backups cannot undo it.
  Future<void> unut(String guvenId) => _sirali(() async {
    if (!_kimlikGecerli(guvenId)) throw HesapHatasi('Guven kimligi gecersiz.');
    final scope = await _hesap();
    final vault = await _kasa();
    final row = vault.records[guvenId];
    if (row == null) return;
    if (row['archive_id'] != scope.arsiv || row['owner_id'] != scope.yonetici) {
      throw HesapHatasi('Baska arsivin cihaz guveni degistirilemez.');
    }
    row.remove('secret');
    row['revoked_at'] ??= saat().millisecondsSinceEpoch;
    await depo.yaz(vault.kodla());
    _challenges.removeWhere((_, c) => c.guvenId == guvenId);
    await _hazirla();
    await _yansit(row);
  });

  /// Call ONLY after authenticating and decrypting /challenge with the trust key.
  /// Return this nonce in an encrypted, request-nonce-bound response.
  Future<String> challengeOlustur(String guvenId) {
    final generation = _challengeNesli;
    return _sirali(() async {
      final trust = await _bul(guvenId);
      if (trust == null || generation != _challengeNesli) {
        throw HesapHatasi('Cihaz guveni bulunamadi veya iptal edildi.');
      }
      final now = saat();
      _challenges.removeWhere((_, c) => !c.gecerli(now));
      if (_challenges.length >= azamiChallenge ||
          _challenges.values.where((c) => c.guvenId == guvenId).length >=
              _azamiCihazChallenge) {
        throw HesapHatasi(
          'Cok sayida baglanti denemesi. Biraz sonra yeniden deneyin.',
        );
      }
      final nonce = _rastgele(32);
      _challenges[nonce] = _Challenge(trust, now);
      return nonce;
    });
  }

  /// Call ONLY after authenticating AND decrypting /resume with the trust key.
  /// Failed attempts consume the nonce too. A process/service restart invalidates
  /// every outstanding challenge, unlike the transport's replay cache alone.
  Future<GuvenilirCihaz> challengeTuket({
    required String guvenId,
    required String challenge,
    required String cihazId,
  }) {
    final generation = _challengeNesli;
    return _sirali(() async {
      if (!_key.hasMatch(challenge)) {
        throw HesapHatasi('Baglanti kaniti gecersiz.');
      }
      final pending = _challenges.remove(challenge);
      if (pending == null ||
          !pending.gecerli(saat()) ||
          pending.guvenId != guvenId ||
          pending.trust.cihazId != cihazId) {
        throw HesapHatasi('Baglanti kaniti kullanilmis veya suresi dolmus.');
      }
      final current = await _bul(guvenId);
      if (current == null ||
          generation != _challengeNesli ||
          !pending.gecerli(saat()) ||
          current.cihazId != cihazId ||
          current.arsivId != pending.trust.arsivId ||
          current.yoneticiId != pending.trust.yoneticiId ||
          current.gizliAnahtar != pending.trust.gizliAnahtar) {
        throw HesapHatasi('Cihaz guveni degisti. Yeni QR ile eslestirin.');
      }
      return current;
    });
  }

  void challengeTemizle() {
    _challengeNesli++;
    _challenges.clear();
  }
}

class _Kasa {
  final String cihazId;
  final Map<String, Map<String, dynamic>> records;
  _Kasa(this.cihazId, this.records);
  String kodla() {
    final value = jsonEncode({
      'version': 1,
      'device_id': cihazId,
      'records': records,
    });
    if (value.length > 4 * 1024 * 1024) {
      throw HesapHatasi('Guvenli cihaz deposu dolu; mevcut kayitlar korundu.');
    }
    return value;
  }
}

class _Challenge {
  final GuvenilirCihaz trust;
  final DateTime zaman;
  _Challenge(this.trust, this.zaman);
  String get guvenId => trust.guvenId;
  bool gecerli(DateTime now) =>
      !now.isBefore(zaman) &&
      now.difference(zaman) < GuvenilirCihazServisi.challengeOmru;
}
