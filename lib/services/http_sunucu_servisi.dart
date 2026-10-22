import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'veritabani_servisi.dart';
import 'depolama_konumu_servisi.dart';
import 'guvenli_aktarim_servisi.dart';
import 'aktarim_http.dart';
import 'auth_servisi.dart';
import 'arsiv_hesap_servisi.dart';
import 'hesap_eslesme_servisi.dart';
import 'aktarim_envanter_servisi.dart';
import 'guvenilir_cihaz_servisi.dart';
import 'uzak_aktarim_isleri.dart';
import 'log_servisi.dart';
import 'yerel_ag_servisi.dart';

class HttpSunucuServisi {
  static const int SUNUCU_PORTU = 8080;
  static const String UYGULAMA_KODU = 'arsivim';

  // Timeout ayarları
  static const Duration REQUEST_TIMEOUT = Duration(seconds: 30);
  static const Duration CONNECTION_TIMEOUT = Duration(minutes: 5);
  static const Duration KEEPALIVE_TIMEOUT = Duration(minutes: 2);

  // Dosya boyutu limitleri (güncellenmiş)
  static const int MAX_FILE_SIZE_MOBILE = 10 * 1024 * 1024; // 10MB
  static const int MAX_FILE_SIZE_DESKTOP = 50 * 1024 * 1024; // 50MB
  static const int MAX_PROFILE_PHOTO_SIZE = 5 * 1024 * 1024; // 5MB
  static const int BATCH_SIZE = 10; // Batch processing boyutu

  static HttpSunucuServisi? _instance;
  static HttpSunucuServisi get instance => _instance ??= HttpSunucuServisi._();
  HttpSunucuServisi._() {
    _yetkiKontrolunuBagla();
  }

  @visibleForTesting
  HttpSunucuServisi.test({
    required AuthServisi auth,
    required GuvenilirCihazServisi guven,
    required Directory belgeler,
    Future<void> Function(String ip, String token)? reverseCheck,
  }) {
    _testAuth = auth;
    _testDb = guven.db;
    _testDocuments = belgeler;
    _testReverseCheck = reverseCheck;
    _guvenServisi = Future.value(guven);
    _yetkiKontrolunuBagla();
  }

  AuthServisi? _testAuth;
  Database? _testDb;
  Directory? _testDocuments;
  Future<void> Function(String ip, String token)? _testReverseCheck;
  AuthServisi get _auth => _testAuth ?? AuthServisi.instance;
  Future<Database> get _database async => _testDb ?? await _veriTabani.database;

  void _yetkiKontrolunuBagla() {
    hesapEslesmesi.ekYetkiKontrol = (ip) async {
      final id = guvenBaglantilari[ip];
      final connection = hesapEslesmesi.baglantiKimligi(ip);
      if (id != null && await (await guvenServisi).bul(id) == null) {
        if (_ayniBaglanti(ip, connection) && guvenBaglantilari[ip] == id) {
          hesapEslesmesi.baglantiKes(ip);
          eslesmisAnahtarlar.remove(ip);
          gelenAnahtarlar.remove(ip);
        }
        throw HesapHatasi('Cihaz güveni kaldırıldı. Yeniden eşleştirin.');
      }
    };
  }

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  String aktarimAnahtari = GuvenliAktarimServisi.kimlik();
  final Map<String, String> eslesmisAnahtarlar = {};
  final Map<String, String> gelenAnahtarlar = {};
  late final hesapEslesmesi = HesapEslesmeServisi(_auth);
  final Map<String, int> _aktifIstekler = {};
  final Set<String> _baglantiDenemeleri = {};
  final Set<String> aktifAktarimCihazlari = {};
  final Map<String, String> guvenBaglantilari = {};
  final Map<String, Map<String, dynamic>> _bekleyenCihazlar = {};
  Future<GuvenilirCihazServisi>? _guvenServisi;
  Future<GuvenilirCihazServisi> get guvenServisi =>
      _guvenServisi ??= _database.then(GuvenilirCihazServisi.new);
  Future<Map<String, dynamic>> Function(String ip, List<int> ids)?
  onUzakGonderim;
  void Function()? onUzakDurdur;
  late final UzakAktarimIsleri uzakIsler = UzakAktarimIsleri(
    send: (owner, ids) async {
      final candidates =
          eslesmisAnahtarlar.keys.where((ip) {
            try {
              return hesapEslesmesi.baglantiKimligi(ip) == owner;
            } catch (_) {
              return false;
            }
          }).toList();
      if (candidates.length != 1 || onUzakGonderim == null) {
        throw HesapHatasi('Aktarım bağlantısı sona erdi.');
      }
      await hesapEslesmesi.yetkiKontrol(candidates.single);
      return onUzakGonderim!(candidates.single, ids);
    },
    stop: () => onUzakDurdur?.call(),
  );

  void _cihazBaglandi(String ip, Map<String, dynamic> data) {
    final device = <String, dynamic>{
      'device_id': data['device_id'],
      'device_name': data['device_name'],
      'platform': data['platform'],
      'ip': ip,
      'status': 'connected',
      'connected_at': DateTime.now().toIso8601String(),
      'last_seen': DateTime.now().toIso8601String(),
    };
    _bagliCihazlar.removeWhere(
      (d) => d['ip'] == ip || d['device_id'] == data['device_id'],
    );
    _bagliCihazlar.add(device);
    _onDeviceConnected?.call(device);
  }

  Future<void> _guvenilirYenidenBaglan(HttpRequest request) async {
    String? key;
    final ip = request.connectionInfo!.remoteAddress.address;
    var resumed = false;
    var ownsAttempt = false;
    String? resumedConnection;
    var stage = 'yerel yönetici oturumu';
    try {
      if (request.method != 'POST' || request.headers.value('Origin') != null) {
        throw HesapHatasi('Geçersiz bağlantı isteği.');
      }
      if (request.uri.path == '/sync/v2/trust-resume') {
        if (!_baglantiDenemeleri.add(ip))
          throw HesapHatasi('Cihaz bağlantısı zaten sürüyor.');
        ownsAttempt = true;
      }
      final session = _auth.sessionGeneration;
      final account = await _auth.hesapTanitim();
      stage = 'kayıtlı cihaz anahtarı';
      final service = await guvenServisi;
      final trustId = request.headers.value('x-arsiv-trust') ?? '';
      final trust = await service.bul(trustId);
      if (trust == null || !AktarimHttp.yetkili(request, trust.gizliAnahtar)) {
        throw HesapHatasi('Cihaz tanınmadı. Yeni QR ile eşleştirin.');
      }
      key = trust.gizliAnahtar;
      stage = 'cihaz ve arşiv kimliği';
      final body = await AktarimHttp.jsonOku(
        AktarimHttp.istekOku(request, key),
      );
      if (body['device_id'] != trust.cihazId ||
          body['archive_id'] != trust.arsivId ||
          body['owner_id'] != trust.yoneticiId ||
          body['trust_version'] != 1 ||
          session != _auth.sessionGeneration) {
        throw HesapHatasi('Cihaz veya hesap bilgisi değişti.');
      }
      Map<String, dynamic> response;
      if (request.uri.path == '/sync/v2/trust-challenge') {
        response = {
          'success': true,
          'trust_version': 1,
          'challenge': await service.challengeOlustur(trustId),
          'device_id': await service.cihazKimligi(),
          'archive_id': trust.arsivId,
          'owner_id': trust.yoneticiId,
        };
      } else {
        stage = 'tek kullanımlık bağlantı kanıtı';
        final token = body['reverse_token'];
        if (body['challenge'] is! String ||
            token is! String ||
            !RegExp(r'^[a-f0-9]{48}$').hasMatch(token)) {
          throw HesapHatasi('Bağlantı anahtarı geçersiz.');
        }
        await service.challengeTuket(
          guvenId: trustId,
          challenge: body['challenge'] as String,
          cihazId: trust.cihazId,
        );
        if (session != _auth.sessionGeneration)
          throw HesapHatasi('Oturum değişti.');
        await hesapEslesmesi.guvenilirBaglanti(ip, account);
        resumed = true;
        resumedConnection = hesapEslesmesi.baglantiKimligi(ip);
        await service.kaydet(
          guvenId: trustId,
          gizliAnahtar: key,
          hesap: account,
          cihazId: trust.cihazId,
          cihazAdi: trust.cihazAdi,
          platform: trust.platform,
          sonIp: ip,
        );
        if (session != _auth.sessionGeneration)
          throw HesapHatasi('Oturum değişti.');
        if (!_ayniBaglanti(ip, resumedConnection))
          throw HesapHatasi('Cihaz oturumu değişti.');
        eslesmisAnahtarlar[ip] = token;
        final inboundToken = GuvenliAktarimServisi.kimlik();
        gelenAnahtarlar[ip] = inboundToken;
        guvenBaglantilari[ip] = trustId;
        _bekleyenCihazlar[ip] = trust.toMap();
        response = {
          'success': true,
          'trust_version': 1,
          'account': account,
          'device_id': await service.cihazKimligi(),
          'transfer_token': inboundToken,
          'surum': GuvenliAktarimServisi.surum,
        };
      }
      if (session != _auth.sessionGeneration)
        throw HesapHatasi('Oturum değişti.');
      await AktarimHttp.yanit(request, key, response);
    } catch (error) {
      LogServisi.instance.warning(
        'BAGLANTI SUNUCU: $stage (${error.runtimeType})',
      );
      if (resumed && _ayniBaglanti(ip, resumedConnection)) {
        hesapEslesmesi.baglantiKes(ip);
        eslesmisAnahtarlar.remove(ip);
        gelenAnahtarlar.remove(ip);
        guvenBaglantilari.remove(ip);
        _bekleyenCihazlar.remove(ip);
      }
      if (key == null) {
        await _sendResponse(
          request.response,
          jsonEncode({
            'success': false,
            'error': 'Cihaz güveni doğrulanamadı. Yeni QR ile eşleştirin.',
          }),
          401,
        );
      } else {
        await AktarimHttp.yanit(request, key, {
          'success': false,
          'error':
              error is HesapHatasi
                  ? '$stage: ${error.mesaj}'
                  : '$stage: Cihaz doğrulanamadı (${error.runtimeType}).',
        }, status: 409);
      }
    } finally {
      if (ownsAttempt) _baglantiDenemeleri.remove(ip);
    }
  }

  bool _ayniBaglanti(String ip, String? connection) {
    try {
      return hesapEslesmesi.baglantiKimligi(ip) == connection;
    } catch (_) {
      return false;
    }
  }

  Future<GuvenliAktarimServisi> _aktarimServisi(
    String ip, {
    String? beklenenBaglanti,
  }) async {
    final connection = beklenenBaglanti ?? hesapEslesmesi.baglantiKimligi(ip);
    return GuvenliAktarimServisi(
      await _database,
      _testDocuments ?? await DepolamaKonumuServisi.instance.belgelerKlasoru(),
      yetkiKontrol: () async {
        await hesapEslesmesi.yetkiKontrol(ip);
        if (!_ayniBaglanti(ip, connection))
          throw HesapHatasi('Aktarım sırasında cihaz oturumu değişti.');
      },
    );
  }

  Future<void> _guvenliAktarim(
    HttpRequest request,
    String aktarimAnahtari,
  ) async {
    final ip = request.connectionInfo!.remoteAddress.address;
    var ownsAttempt = false;
    _aktifIstekler[ip] = (_aktifIstekler[ip] ?? 0) + 1;
    try {
      if (request.uri.path == '/sync/v2/pair') {
        if (!_baglantiDenemeleri.add(ip))
          throw HesapHatasi('Cihaz bağlantısı zaten sürüyor.');
        ownsAttempt = true;
      }
      final uzakIP = request.connectionInfo!.remoteAddress.address;
      final connection =
          request.uri.path == '/sync/v2/pair'
              ? null
              : hesapEslesmesi.baglantiKimligi(ip);
      if (request.uri.path != '/sync/v2/pair' &&
          !eslesmisAnahtarlar.containsKey(uzakIP)) {
        throw AktarimHatasi(
          'ESLESME',
          'Bu cihazla etkin eslesme yok. QR kodunu yeniden tarayin.',
        );
      }
      if (request.uri.path != '/sync/v2/pair') {
        await hesapEslesmesi.yetkiKontrol(uzakIP);
        if (!_ayniBaglanti(ip, connection) ||
            gelenAnahtarlar[ip] != aktarimAnahtari)
          throw HesapHatasi('Cihaz oturumu değişti.');
      }
      Future<Map<String, dynamic>> oku({
        int max = GuvenliAktarimServisi.azamiMetadata,
      }) async {
        final data = await AktarimHttp.jsonOku(
          AktarimHttp.istekOku(request, aktarimAnahtari),
          max: max,
        );
        if (connection != null) {
          await hesapEslesmesi.yetkiKontrol(ip);
          if (!_ayniBaglanti(ip, connection) ||
              gelenAnahtarlar[ip] != aktarimAnahtari)
            throw HesapHatasi('Cihaz oturumu değişti.');
        }
        return data;
      }

      Map<String, dynamic> result;
      switch (request.uri.path) {
        case '/sync/v2/capabilities':
          if (request.method != 'GET')
            throw AktarimHatasi('METHOD', 'GET gerekli.');
          result = {
            'success': true,
            'surum': GuvenliAktarimServisi.surum,
            'inventory_version': 1,
            'direction_version': 1,
          };
          break;
        case '/sync/v2/inventory':
          if (request.method != 'POST') {
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          }
          final query = await oku();
          if (query['after'] != null && query['after'] is! int) {
            throw AktarimHatasi('ENVANTER', 'Envanter sayfasi gecersiz.');
          }
          result = await AktarimEnvanterServisi(
            await _aktarimServisi(uzakIP),
          ).page(afterId: query['after'] as int?);
          break;
        case '/sync/v2/send-request':
        case '/sync/v2/send-status':
        case '/sync/v2/send-stop':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          final command = await oku();
          final owner = hesapEslesmesi.baglantiKimligi(uzakIP);
          if (request.uri.path == '/sync/v2/send-request') {
            if (command['ids'] is! List ||
                (command['ids'] as List).any((id) => id is! int) ||
                command['request_id'] is! String ||
                onUzakGonderim == null) {
              throw AktarimHatasi(
                'ISTEK',
                'Aktarım seçimi geçersiz veya aktarım ekranı kapalı.',
              );
            }
            result = uzakIsler.baslat(
              owner,
              command['request_id'] as String,
              List<int>.from(command['ids'] as List),
            );
          } else {
            if (command['job_id'] is! String)
              throw AktarimHatasi('ISTEK', 'Aktarım kimliği eksik.');
            result =
                request.uri.path == '/sync/v2/send-stop'
                    ? uzakIsler.stop(owner, command['job_id'] as String)
                    : uzakIsler.status(owner, command['job_id'] as String);
          }
          break;
        case '/sync/v2/pair':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          final data = await oku();
          final token = data['reverse_token'];
          if (data['session_version'] != 1)
            throw HesapHatasi(
              'Güvenli cihaz oturumu için iki cihazı da güncelleyin.',
            );
          if (token is! String || !RegExp(r'^[a-f0-9]{48}$').hasMatch(token)) {
            throw AktarimHatasi('ESLESME', 'Karsi cihaz anahtari gecersiz.');
          }
          final ip = request.connectionInfo!.remoteAddress.address;
          final session = _auth.sessionGeneration;
          final hesap = await hesapEslesmesi.kabulEt(ip, data);
          guvenBaglantilari.remove(ip);
          if (data['trust_version'] == 1) {
            try {
              await (await guvenServisi).kaydet(
                guvenId: data['trust_id'] as String,
                gizliAnahtar: data['trust_secret'] as String,
                hesap: hesap,
                cihazId: data['device_id'] as String,
                cihazAdi: data['device_name'] as String,
                platform: data['platform'] as String?,
                sonIp: ip,
              );
              if (session != _auth.sessionGeneration)
                throw HesapHatasi('Oturum değişti.');
              guvenBaglantilari[ip] = data['trust_id'] as String;
            } catch (_) {
              hesapEslesmesi.baglantiKes(ip);
              rethrow;
            }
          }
          eslesmisAnahtarlar[ip] = token;
          final inboundToken = GuvenliAktarimServisi.kimlik();
          gelenAnahtarlar[ip] = inboundToken;
          if (data['trust_version'] == 1) {
            _bekleyenCihazlar[ip] = {
              'device_id': data['device_id'],
              'device_name': data['device_name'],
              'platform': data['platform'],
            };
          } else {
            _cihazBaglandi(ip, data);
          }
          result = {
            'success': true,
            'surum': GuvenliAktarimServisi.surum,
            'account_version': 1,
            'account': hesap,
            'session_version': 1,
            'transfer_token': inboundToken,
            'trust_version': data['trust_version'] == 1 ? 1 : 0,
            if (data['trust_version'] == 1) 'trust_id': data['trust_id'],
          };
          break;
        case '/sync/v2/ready':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          final readiness = await oku();
          if (readiness['reverse_check'] == 1) {
            try {
              final reverseToken = eslesmisAnahtarlar[uzakIP]!;
              if (_testReverseCheck != null) {
                await _testReverseCheck!(uzakIP, reverseToken);
              } else {
                final reverse = await AktarimHttp.jsonIstek(
                  Uri.parse(
                    'http://$uzakIP:$SUNUCU_PORTU/sync/v2/capabilities',
                  ),
                  reverseToken,
                );
                if (reverse['success'] != true ||
                    reverse['surum'] != GuvenliAktarimServisi.surum) {
                  throw HesapHatasi('Ters yön oturumu doğrulanamadı.');
                }
              }
              await hesapEslesmesi.yetkiKontrol(uzakIP);
              if (!_ayniBaglanti(ip, connection) ||
                  gelenAnahtarlar[ip] != aktarimAnahtari) {
                throw HesapHatasi('Kontrol sırasında cihaz oturumu değişti.');
              }
            } catch (_) {
              throw AktarimHatasi(
                'TERS_BAGLANTI',
                'İlk bağlantı kuruldu ancak karşı yöndeki 8080 bağlantısı doğrulanamadı. İki cihazda sunucuyu açık ve uygulamayı ön planda tutun; güvenlik duvarını ve güncel Wi-Fi/hotspot adreslerini kontrol edin.',
              );
            }
          }
          final waiting = _bekleyenCihazlar.remove(uzakIP);
          if (waiting != null) _cihazBaglandi(uzakIP, waiting);
          result = {'success': true};
          break;
        case '/sync/v2/prepare':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          result = await (await _aktarimServisi(
            uzakIP,
            beklenenBaglanti: connection,
          )).onKontrol(await oku());
          break;
        case '/sync/v2/disconnect':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          await oku();
          eslesmisAnahtarlar.remove(uzakIP);
          gelenAnahtarlar.remove(uzakIP);
          guvenBaglantilari.remove(uzakIP);
          _bekleyenCihazlar.remove(uzakIP);
          hesapEslesmesi.baglantiKes(uzakIP);
          final devices =
              _bagliCihazlar.where((d) => d['ip'] == uzakIP).toList();
          _bagliCihazlar.removeWhere((d) => d['ip'] == uzakIP);
          for (final device in devices) {
            _onDeviceDisconnected?.call(device);
          }
          result = {'success': true};
          break;
        case '/sync/v2/file':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          result = await AktarimHttp.al(
            request,
            await _aktarimServisi(uzakIP, beklenenBaglanti: connection),
            aktarimAnahtari,
          );
          break;
        case '/sync/v2/entity':
          if (request.method != 'POST')
            throw AktarimHatasi('METHOD', 'POST gerekli.');
          result = await (await _aktarimServisi(
            uzakIP,
            beklenenBaglanti: connection,
          )).referansAl(await oku(max: GuvenliAktarimServisi.azamiReferans));
          break;
        default:
          throw AktarimHatasi('ENDPOINT', 'Aktarim adresi bulunamadi.');
      }
      await AktarimHttp.yanit(request, aktarimAnahtari, result);
    } on HesapHatasi catch (e) {
      await AktarimHttp.yanit(request, aktarimAnahtari, {
        'success': false,
        'kod': 'HESAP',
        'error': e.mesaj,
      }, status: 409);
    } on AktarimHatasi catch (e) {
      await AktarimHttp.yanit(request, aktarimAnahtari, e.toMap(), status: 409);
    } catch (_) {
      await AktarimHttp.yanit(request, aktarimAnahtari, {
        'success': false,
        'kod': 'AKTARIM_HATASI',
        'error':
            'Aktarim tamamlanamadi. Disk, izin ve baglanti durumunu kontrol edin.',
      }, status: 500);
    } finally {
      if (ownsAttempt) _baglantiDenemeleri.remove(ip);
      if (request.uri.path == '/sync/v2/file' ||
          request.uri.path == '/sync/v2/entity') {
        dataChanges.value++;
      }
      final remaining = (_aktifIstekler[ip] ?? 1) - 1;
      if (remaining == 0) {
        _aktifIstekler.remove(ip);
      } else {
        _aktifIstekler[ip] = remaining;
      }
      for (final device in _bagliCihazlar.where((d) => d['ip'] == ip)) {
        device['last_seen'] = DateTime.now().toIso8601String();
      }
    }
  }

  /// The production dispatcher also serves isolated loopback protocol tests.
  Future<void> aktarimIstegiIsle(HttpRequest request) async {
    if ([
      '/sync/v2/trust-challenge',
      '/sync/v2/trust-resume',
    ].contains(request.uri.path)) {
      await _guvenilirYenidenBaglan(request);
      return;
    }
    final ip = request.connectionInfo!.remoteAddress.address;
    final key =
        request.uri.path == '/sync/v2/pair'
            ? aktarimAnahtari
            : gelenAnahtarlar[ip];
    if (key == null ||
        (request.uri.path != '/sync/v2/pair' &&
            _baglantiDenemeleri.contains(ip)) ||
        request.headers.value('Origin') != null ||
        !AktarimHttp.yetkili(request, key)) {
      await _sendResponse(
        request.response,
        jsonEncode({
          'success': false,
          'error': 'Cihaz bağlantısı doğrulanamadı.',
        }),
        401,
      );
      return;
    }
    await _guvenliAktarim(request, key);
  }

  HttpServer? _sunucu;
  String? _cihazId;
  String? _cihazAdi;
  String? _platform;
  bool _calisiyorMu = false;
  Timer? _cleanupTimer;

  // Manuel IP override özelliği
  String? _manuelIP;

  // Callback fonksiyonları
  Function(String)? onConnectionReceived;
  Function(String)? onDeviceConnected;
  Function(String, Map<String, dynamic>)? onDeviceDisconnected;

  final ValueNotifier<int> dataChanges = ValueNotifier(0);
  DateTime? startedAt;
  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;
  String? get cihazAdi => _cihazAdi;
  String? get platform => _platform;
  int get port => SUNUCU_PORTU;

  // Manuel IP ayarlama
  void setManuelIP(String? ip) {
    _manuelIP = ip;
  }

  String? get manuelIP => _manuelIP;

  // Baglanti callback'leri
  Function(Map<String, dynamic>)? _onDeviceConnected;
  Function(Map<String, dynamic>)? _onDeviceDisconnected;

  // Bagli cihazlar listesi
  final List<Map<String, dynamic>> _bagliCihazlar = [];

  List<Map<String, dynamic>> get bagliCihazlar =>
      List.unmodifiable(_bagliCihazlar);

  // Callback'leri ayarla
  void baglantiCallbackleri({
    Function(Map<String, dynamic>)? onDeviceConnected,
    Function(String, Map<String, dynamic>)? onDeviceDisconnected,
  }) {
    _onDeviceConnected = onDeviceConnected;
    // Disconnection callback'ini wrap ediyoruz
    if (onDeviceDisconnected != null) {
      _onDeviceDisconnected = (deviceInfo) {
        final deviceId = deviceInfo['device_id'] as String? ?? 'unknown';
        onDeviceDisconnected(deviceId, deviceInfo);
      };
    }
  }

  // Callback ayarlama metodlari
  void setOnDeviceConnected(Function(Map<String, dynamic>) callback) {
    _onDeviceConnected = callback;
  }

  void setOnDeviceDisconnected(Function(Map<String, dynamic>) callback) {
    _onDeviceDisconnected = callback;
  }

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) {
      return;
    }

    try {
      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      _cihazId = await (await guvenServisi).cihazKimligi();

      // Sunucuyu başlat
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);

      // Sunucu timeout ayarları
      _sunucu!.idleTimeout = KEEPALIVE_TIMEOUT;

      _calisiyorMu = true;
      startedAt = DateTime.now();
      dataChanges.value++;

      // Cleanup timer başlat
      _startCleanupTimer();

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          if (request.uri.path.startsWith('/sync/v2/')) {
            await aktarimIstegiIsle(request);
            return;
          }
          if (!['/ping', '/info'].contains(request.uri.path)) {
            if (!AktarimHttp.yetkili(request, aktarimAnahtari) ||
                request.headers.value('Origin') != null) {
              await _sendResponse(
                request.response,
                jsonEncode({
                  'success': false,
                  'error': 'Cihazlari guncel QR koduyla yeniden eslestirin.',
                }),
                401,
              );
              return;
            }
          }
          if (request.uri.path.startsWith('/sync/')) {
            await _sendResponse(
              request.response,
              jsonEncode({
                'success': false,
                'error': 'Guvenli aktarim icin iki cihaz da guncellenmeli.',
              }),
              426,
            );
            return;
          }
          if (!['/ping', '/info'].contains(request.uri.path)) {
            await _sendResponse(
              request.response,
              jsonEncode({
                'success': false,
                'error':
                    'Eski baglanti ve QR giris yollari kapatildi. Iki cihazi guncelleyin.',
              }),
              426,
            );
            return;
          }

          // Request timeout kontrolü (HttpServer kendi timeout yönetimi yapıyor)

          // CORS headers ekle
          _addCORSHeaders(request.response);

          // OPTIONS request için CORS preflight
          if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
            await request.response.close();
            return;
          }

          String responseBody;
          int statusCode = 200;

          // Route handling - Tüm endpoint'ler eklendi
          switch (request.uri.path) {
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/connect':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleConnect,
              );
              break;
            case '/disconnect':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDisconnect,
              );
              break;
            case '/status':
              responseBody = await _handleStatus();
              break;
            case '/devices':
              responseBody = await _handleDevices();
              break;
            case '/device-connected':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDeviceConnected,
              );
              break;
            case '/device-disconnected':
              responseBody = await _handleMethodValidation(
                request,
                'POST',
                _handleDeviceDisconnected,
              );
              break;
            default:
              statusCode = 404;
              responseBody = _createErrorResponse(
                'Endpoint bulunamadı',
                'Belirtilen endpoint mevcut değil: ${request.uri.path}',
              );
          }

          // Response gönder
          await _sendResponse(request.response, responseBody, statusCode);
        } catch (e, stackTrace) {
          LogServisi.instance.error('İstek işleme hatası', e, stackTrace);
          await _sendErrorResponse(
            request.response,
            'Sunucu hatası',
            e.toString(),
          );
        }
      });
    } catch (e, stackTrace) {
      LogServisi.instance.error('Sunucu başlatma hatası', e, stackTrace);
      throw Exception('HTTP sunucusu başlatılamadı: $e');
    }
  }

  Future<void> sunucuyuDurdur() async {
    try {
      // Cleanup timer'ı durdur
      _cleanupTimer?.cancel();
      _cleanupTimer = null;

      // Sunucuyu durdur
      final sunucu = _sunucu;
      if (sunucu != null) {
        await sunucu.close(force: true);
        _sunucu = null;
      }

      _calisiyorMu = false;
      startedAt = null;
      dataChanges.value++;
      _bagliCihazlar.clear();
      eslesmisAnahtarlar.clear();
      gelenAnahtarlar.clear();
      aktarimAnahtari = GuvenliAktarimServisi.kimlik();
      guvenBaglantilari.clear();
      _bekleyenCihazlar.clear();
      if (_guvenServisi != null) (await _guvenServisi!).challengeTemizle();
      hesapEslesmesi.temizle();
    } catch (e) {
      LogServisi.instance.error('❌ Sunucu durdurma hatası: $e');
    }
  }

  // Cleanup timer başlat
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _cleanupConnections();
    });
  }

  // Bağlantı temizleme
  void _cleanupConnections() {
    try {
      final now = DateTime.now();
      final removedDevices = <Map<String, dynamic>>[];

      _bagliCihazlar.removeWhere((device) {
        if (_aktifIstekler.containsKey(device['ip']) ||
            aktifAktarimCihazlari.contains(device['ip']))
          return false;
        final lastSeenStr = device['last_seen'] as String?;
        if (lastSeenStr == null) {
          removedDevices.add(device);
          return true;
        }

        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) {
          removedDevices.add(device);
          return true;
        }

        final isTimedOut = now.difference(lastSeen) > CONNECTION_TIMEOUT;
        if (isTimedOut) {
          removedDevices.add(device);
        }
        return isTimedOut;
      });

      // Timeout olan cihazlar için bildirim gönder
      for (final device in removedDevices) {
        final ip = device['ip'];
        if (ip is String) {
          eslesmisAnahtarlar.remove(ip);
          gelenAnahtarlar.remove(ip);
          guvenBaglantilari.remove(ip);
          _bekleyenCihazlar.remove(ip);
          hesapEslesmesi.baglantiKes(ip);
        }
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': device['device_id'],
            'device_name': device['device_name'],
            'reason': 'Connection timeout',
            'timestamp': DateTime.now().toIso8601String(),
          };
          _onDeviceDisconnected!(disconnectionInfo);
        }
      }
    } catch (e) {
      LogServisi.instance.error('❌ Cleanup hatası: $e');
    }
  }

  // CORS headers ekle
  void _addCORSHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
    response.headers.add('Content-Type', 'application/json; charset=utf-8');
  }

  // HTTP method validasyonu
  Future<String> _handleMethodValidation(
    HttpRequest request,
    String allowedMethod,
    Function(HttpRequest) handler,
  ) async {
    if (request.method != allowedMethod) {
      return _createErrorResponse(
        'Method not allowed',
        'Only $allowedMethod method is supported for this endpoint',
      );
    }
    return await handler(request);
  }

  // Error response oluştur
  String _createErrorResponse(String error, String message) {
    return json.encode({
      'success': false,
      'error': error,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Response gönder
  Future<void> _sendResponse(
    HttpResponse response,
    String body,
    int statusCode,
  ) async {
    try {
      final responseBytes = utf8.encode(body);
      response
        ..statusCode = statusCode
        ..add(responseBytes);
      await response.close();
    } catch (e) {
      LogServisi.instance.error('❌ Response gönderme hatası: $e');
    }
  }

  // Error response gönder
  Future<void> _sendErrorResponse(
    HttpResponse response,
    String error,
    String message,
  ) async {
    try {
      final errorResponse = _createErrorResponse(error, message);
      await _sendResponse(response, errorResponse, 500);
    } catch (e) {
      LogServisi.instance.error('❌ Error response gönderme hatası: $e');
    }
  }

  Future<void> _cihazBilgileriniAl() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cihazAdi = '${androidInfo.brand} ${androidInfo.model}';
        _platform = 'Android ${androidInfo.version.release}';
        _cihazId = androidInfo.id;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cihazAdi = windowsInfo.computerName;
        _platform = 'Windows';
        _cihazId = windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cihazAdi = linuxInfo.name;
        _platform = 'Linux';
        _cihazId =
            linuxInfo.machineId ??
            'linux-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cihazAdi = macInfo.computerName;
        _platform = 'macOS';
        _cihazId =
            macInfo.systemGUID ??
            'mac-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _cihazAdi = 'Bilinmeyen Cihaz';
        _platform = Platform.operatingSystem;
        _cihazId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Cihaz ID'sini hash'le (güvenlik için)
      final cihazId = _cihazId ?? 'unknown-device';
      final bytes = utf8.encode(cihazId);
      final digest = sha256.convert(bytes);
      _cihazId = digest.toString().substring(0, 16);
    } catch (e) {
      LogServisi.instance.error('❌ Cihaz bilgisi alınamadı: $e');
      _cihazAdi = 'Arsivim Cihazı';
      _platform = Platform.operatingSystem;
      _cihazId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // HTTP Handler metodları
  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _cihazId,
      'device_name': _cihazAdi,
      'platform': _platform,
      'server_version': '2.0.0',
    });
  }

  Future<String> _handleInfo() async {
    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();
      final serverIP = await getRealIPAddress();

      return json.encode({
        'success': true,
        'app': UYGULAMA_KODU,
        'version': '2.0.0',
        'device_id': _cihazId,
        'device_name': _cihazAdi,
        'platform': _platform,
        'document_count': belgeSayisi,
        'total_size': toplamBoyut,
        'server_ip': serverIP,
        'server_port': SUNUCU_PORTU,
        'timestamp': DateTime.now().toIso8601String(),
        'server_running': true,
        'connected_devices': _bagliCihazlar.length,
        'max_file_size': GuvenliAktarimServisi.azamiDosya,
      });
    } catch (e) {
      LogServisi.instance.error('❌ Info endpoint hatası: $e');
      return json.encode({
        'success': false,
        'error': 'Info alınamadı',
        'message': e.toString(),
        'app': UYGULAMA_KODU,
        'version': '2.0.0',
        'device_id': _cihazId,
        'device_name': _cihazAdi,
        'platform': _platform,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Connection handler methods
  Future<String> _handleConnect(HttpRequest request) async {
    try {
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final platform = data['platform'] as String?;
      final clientIP =
          request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor';

      if (deviceId == null || deviceName == null) {
        return _createErrorResponse(
          'Missing parameters',
          'device_id ve device_name gerekli',
        );
      }

      // Cihaz zaten bağlı mı kontrol et
      final mevcutCihazIndex = _bagliCihazlar.indexWhere(
        (device) => device['device_id'] == deviceId,
      );

      if (mevcutCihazIndex != -1) {
        // Mevcut cihazın bilgilerini güncelle
        _bagliCihazlar[mevcutCihazIndex].addAll({
          'last_seen': DateTime.now().toIso8601String(),
          'status': 'connected',
          'online': true,
          'ip': clientIP,
          'platform': platform ?? _bagliCihazlar[mevcutCihazIndex]['platform'],
        });

        // Güncelleme için UI bildirimini gönder
        if (_onDeviceConnected != null) {
          Future.microtask(
            () => _onDeviceConnected!(_bagliCihazlar[mevcutCihazIndex]),
          );
        }
      } else {
        // Yeni cihaz ekle
        final yeniCihaz = {
          'device_id': deviceId,
          'device_name': deviceName,
          'platform': platform ?? 'Unknown',
          'ip': clientIP,
          'connected_at': DateTime.now().toIso8601String(),
          'last_seen': DateTime.now().toIso8601String(),
          'status': 'connected',
          'connection_type': 'incoming',
          'online': true,
        };

        _bagliCihazlar.add(yeniCihaz);

        // UI'ya bildirim gönder
        if (_onDeviceConnected != null) {
          Future.microtask(() => _onDeviceConnected!(yeniCihaz));
        }
      }

      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'success': true,
        'message': 'Bağlantı kuruldu',
        'server_device_id': _cihazId,
        'server_device_name': _cihazAdi,
        'server_ip': serverIP,
        'server_port': SUNUCU_PORTU,
        'server_info': {
          'platform': _platform,
          'document_count': belgeSayisi,
          'total_size': toplamBoyut,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogServisi.instance.error('❌ Connect handler hatası: $e');
      return _createErrorResponse('Bağlantı hatası', e.toString());
    }
  }

  Future<String> _handleDisconnect(HttpRequest request) async {
    try {
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final reason = data['reason'] as String?;

      if (deviceId == null) {
        return _createErrorResponse('Missing parameter', 'device_id gerekli');
      }

      // Cihazı listeden kaldır
      final removedDevice = _bagliCihazlar.firstWhere(
        (device) => device['device_id'] == deviceId,
        orElse: () => <String, dynamic>{},
      );

      if (removedDevice.isNotEmpty) {
        _bagliCihazlar.removeWhere((device) => device['device_id'] == deviceId);

        // UI'ya bildirim gönder
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': deviceId,
            'device_name': removedDevice['device_name'],
            'reason': reason ?? 'Bağlantı kesildi',
            'timestamp': DateTime.now().toIso8601String(),
          };
          Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
        }

        return json.encode({
          'success': true,
          'message': 'Bağlantı kesildi',
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        return _createErrorResponse(
          'Device not found',
          'Belirtilen cihaz bağlı cihazlar listesinde yok',
        );
      }
    } catch (e) {
      LogServisi.instance.error('❌ Disconnect handler hatası: $e');
      return _createErrorResponse('Bağlantı kesme hatası', e.toString());
    }
  }

  Future<String> _handleStatus() async {
    try {
      final serverIP = await getRealIPAddress();
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'success': true,
        'status': 'running',
        'server_info': {
          'device_id': _cihazId,
          'device_name': _cihazAdi,
          'platform': _platform,
          'ip': serverIP,
          'port': SUNUCU_PORTU,
          'document_count': belgeSayisi,
          'total_size': toplamBoyut,
        },
        'connected_devices': _bagliCihazlar.length,
        'uptime': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogServisi.instance.error('❌ Status handler hatası: $e');
      return _createErrorResponse('Status alınamadı', e.toString());
    }
  }

  Future<String> _handleDevices() async {
    try {
      // Bağlı cihazların son görülme zamanlarını kontrol et (cleanup timer zaten yapıyor ama extra kontrol)
      final now = DateTime.now();
      final removedDevices = <Map<String, dynamic>>[];

      _bagliCihazlar.removeWhere((device) {
        final lastSeenStr = device['last_seen'] as String?;
        if (lastSeenStr == null) return true;

        final lastSeen = DateTime.tryParse(lastSeenStr);
        if (lastSeen == null) return true;

        final isTimedOut = now.difference(lastSeen) > CONNECTION_TIMEOUT;
        if (isTimedOut) {
          removedDevices.add(device);
        }
        return isTimedOut;
      });

      // Timeout olan cihazlar için bildirim gönder
      for (final device in removedDevices) {
        if (_onDeviceDisconnected != null) {
          final disconnectionInfo = {
            'device_id': device['device_id'],
            'device_name': device['device_name'],
            'reason': 'Connection timeout',
            'timestamp': DateTime.now().toIso8601String(),
          };
          Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
        }
      }

      return json.encode({
        'success': true,
        'devices': _bagliCihazlar,
        'total_count': _bagliCihazlar.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogServisi.instance.error('❌ Devices handler hatası: $e');
      return _createErrorResponse('Cihaz listesi alınamadı', e.toString());
    }
  }

  Future<String> _handleDeviceConnected(HttpRequest request) async {
    try {
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final deviceName = data['device_name'] as String?;
      final platform = data['platform'] as String?;
      final clientIP =
          request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor';

      if (deviceId == null || deviceName == null) {
        return _createErrorResponse(
          'Missing parameters',
          'device_id ve device_name gerekli',
        );
      }

      // UI'ya bildirim gönder
      final deviceInfo = {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform ?? 'Unknown',
        'ip': clientIP,
        'timestamp': DateTime.now().toIso8601String(),
        'connection_type': 'incoming',
      };

      // Callback'i çağır
      if (_onDeviceConnected != null) {
        Future.microtask(() => _onDeviceConnected!(deviceInfo));
      }

      return json.encode({
        'success': true,
        'message': 'Bağlantı bildirimi alındı',
        'server_device_id': _cihazId,
        'server_device_name': _cihazAdi,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogServisi.instance.error('❌ Device connected handler hatası: $e');
      return _createErrorResponse('Bağlantı bildirimi hatası', e.toString());
    }
  }

  Future<String> _handleDeviceDisconnected(HttpRequest request) async {
    try {
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final deviceId = data['device_id'] as String?;
      final message = data['message'] as String?;

      if (deviceId == null) {
        return _createErrorResponse('Missing parameter', 'device_id gerekli');
      }

      // UI'ya bildirim gönder
      final disconnectionInfo = {
        'device_id': deviceId,
        'message': message ?? 'Bağlantı kesildi',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Callback'i çağır
      if (_onDeviceDisconnected != null) {
        Future.microtask(() => _onDeviceDisconnected!(disconnectionInfo));
      }

      return json.encode({
        'success': true,
        'message': 'Bağlantı kesme bildirimi alındı',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LogServisi.instance.error('❌ Device disconnected handler hatası: $e');
      return _createErrorResponse(
        'Bağlantı kesme bildirimi hatası',
        e.toString(),
      );
    }
  }

  // IP adresini gerçek zamanlı al
  Future<String?> getRealIPAddress() async {
    try {
      return (await getLocalIPAddresses()).firstOrNull;
    } catch (e) {
      LogServisi.instance.error('❌ IP adresi alınamadı: $e');
    }

    return null;
  }

  Future<List<String>> getLocalIPAddresses() async {
    final addresses = await YerelAgServisi.adresler();
    final manual = _manuelIP;
    if (manual != null && addresses.remove(manual)) addresses.insert(0, manual);
    return addresses;
  }

  // Utility metodları
  void clearConnectedDevices() {
    _bagliCihazlar.clear();
  }

  void updateDeviceLastSeen(String deviceId) {
    final device = _bagliCihazlar.firstWhere(
      (device) => device['device_id'] == deviceId,
      orElse: () => <String, dynamic>{},
    );

    if (device.isNotEmpty) {
      device['last_seen'] = DateTime.now().toIso8601String();
    }
  }
}
