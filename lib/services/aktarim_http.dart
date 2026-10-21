import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import 'guvenli_aktarim_servisi.dart';

/// Buyuk dosyalar JSON/base64 olarak bellekte biriktirilmez.
class AktarimHttp {
  static const bekleme = Duration(seconds: 60);
  static final _cipher = AesGcm.with256bits();
  static final Map<String, DateTime> _kullanilanIstekler = {};

  static SecretKey _key(String token) => SecretKey(
    crypto.sha256.convert(utf8.encode('arsiv-v2-encryption:$token')).bytes,
  );

  static String _imza(
    String token,
    String method,
    String path,
    String id,
    String time,
  ) =>
      crypto.Hmac(
        crypto.sha256,
        utf8.encode('arsiv-v2-auth:$token'),
      ).convert(utf8.encode('$method\n$path\n$id\n$time')).toString();

  static String _basliklar(HttpClientRequest req, String token, Uri uri) {
    final id = GuvenliAktarimServisi.kimlik();
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    req.headers.set('x-arsiv-id', id);
    req.headers.set('x-arsiv-time', time);
    req.headers.set(
      'x-arsiv-proof',
      _imza(token, req.method, uri.path, id, time),
    );
    return id;
  }

  static bool yetkili(HttpRequest request, String token) {
    final id = request.headers.value('x-arsiv-id');
    final time = request.headers.value('x-arsiv-time');
    final proof = request.headers.value('x-arsiv-proof');
    if (id == null ||
        time == null ||
        proof == null ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(id))
      return false;
    final milliseconds = int.tryParse(time);
    final now = DateTime.now();
    if (milliseconds == null ||
        (now.millisecondsSinceEpoch - milliseconds).abs() > 600000)
      return false;
    final expected = _imza(token, request.method, request.uri.path, id, time);
    if (proof.length != expected.length) return false;
    var fark = 0;
    for (var i = 0; i < expected.length; i++) {
      fark |= proof.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    if (fark != 0) return false;
    _kullanilanIstekler.removeWhere(
      (_, value) => now.difference(value).inMinutes > 20,
    );
    if (_kullanilanIstekler.containsKey(id) ||
        _kullanilanIstekler.length > 100000)
      return false;
    _kullanilanIstekler[id] = now;
    return true;
  }

  static Stream<List<int>> sifrele(
    Stream<List<int>> source,
    String token,
    String context,
  ) async* {
    var index = 0;
    final key = _key(token);
    Future<List<int>> frame(List<int> bytes, bool son) async {
      final box = await _cipher.encrypt(
        bytes,
        secretKey: key,
        aad: utf8.encode('$context:$index:${son ? 1 : 0}'),
      );
      index++;
      final body = box.concatenation();
      final prefix =
          ByteData(5)
            ..setUint32(0, body.length)
            ..setUint8(4, son ? 1 : 0);
      return [...prefix.buffer.asUint8List(), ...body];
    }

    await for (final chunk in source) {
      for (var offset = 0; offset < chunk.length; offset += 65536) {
        final end =
            offset + 65536 < chunk.length ? offset + 65536 : chunk.length;
        yield await frame(chunk.sublist(offset, end), false);
      }
    }
    yield await frame(const [], true);
  }

  static Stream<List<int>> coz(
    Stream<List<int>> source,
    String token,
    String context,
  ) async* {
    final reader = _AkisOkuyucu(source.timeout(bekleme));
    final key = _key(token);
    var index = 0;
    try {
      while (true) {
        final prefix = ByteData.sublistView(await reader.oku(5));
        final length = prefix.getUint32(0);
        final son = prefix.getUint8(4);
        if (length < 28 || length > 65536 + 28 || son > 1)
          throw AktarimHatasi(
            'SIFRELEME',
            'Sifreli aktarim cercevesi gecersiz.',
          );
        final box = SecretBox.fromConcatenation(
          await reader.oku(length),
          nonceLength: 12,
          macLength: 16,
        );
        final bytes = await _cipher.decrypt(
          box,
          secretKey: key,
          aad: utf8.encode('$context:$index:$son'),
        );
        index++;
        if (son == 1) {
          if (bytes.isNotEmpty)
            throw AktarimHatasi('SIFRELEME', 'Bitis cercevesi gecersiz.');
          await for (final extra in reader.kalan()) {
            if (extra.isNotEmpty)
              throw AktarimHatasi(
                'SIFRELEME',
                'Aktarim sonuna ek veri eklenmis.',
              );
          }
          break;
        }
        yield bytes;
      }
    } finally {
      await reader.kapat();
    }
  }

  static Stream<List<int>> istekOku(HttpRequest request, String token) =>
      coz(request, token, '${request.headers.value('x-arsiv-id')}:request');

  static Future<void> yanit(
    HttpRequest request,
    String token,
    Map<String, dynamic> result, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.binary;
    await request.response.addStream(
      sifrele(
        Stream.value(utf8.encode(jsonEncode(result))),
        token,
        '${request.headers.value('x-arsiv-id')}:response',
      ),
    );
    await request.response.close();
  }

  static Future<Map<String, dynamic>> jsonOku(
    Stream<List<int>> stream, {
    int max = GuvenliAktarimServisi.azamiMetadata,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(bekleme)) {
      if (bytes.length + chunk.length > max) {
        throw AktarimHatasi('BOYUT', 'Istek veya yanit cok buyuk.');
      }
      bytes.add(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map)
      throw AktarimHatasi('SEMA', 'JSON nesnesi bekleniyor.');
    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> al(
    HttpRequest request,
    GuvenliAktarimServisi servis,
    String token,
  ) async {
    final okuyucu = _AkisOkuyucu(istekOku(request, token));
    try {
      final length = ByteData.sublistView(await okuyucu.oku(4)).getUint32(0);
      if (length == 0 || length > GuvenliAktarimServisi.azamiMetadata) {
        throw AktarimHatasi('BOYUT', 'Metadata boyutu gecersiz.');
      }
      final paket = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(await okuyucu.oku(length))) as Map,
      );
      GuvenliAktarimServisi.dogrula(paket);
      return await servis.al(paket, okuyucu.kalan());
    } finally {
      await okuyucu.kapat();
    }
  }

  static Future<Map<String, dynamic>> jsonIstek(
    Uri uri,
    String token, {
    Map<String, dynamic>? body,
    String? guvenId,
  }) async {
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(bekleme);
      req.followRedirects = false;
      final id = _basliklar(req, token, uri);
      if (guvenId != null) req.headers.set('x-arsiv-trust', guvenId);
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        final max =
            uri.path == '/sync/v2/entity'
                ? GuvenliAktarimServisi.azamiReferans
                : GuvenliAktarimServisi.azamiMetadata;
        if (bytes.length > max)
          throw AktarimHatasi('BOYUT', 'Metadata cok buyuk.');
        req.headers.contentType = ContentType.binary;
        await req
            .addStream(sifrele(Stream.value(bytes), token, '$id:request'))
            .timeout(bekleme);
      }
      final response = await req.close().timeout(bekleme);
      if (response.statusCode == 401 || response.statusCode == 426) {
        throw AktarimHatasi(
          'ESLESME',
          'Iki cihazi guncelleyip QR koduyla yeniden eslestirin. Cihaz saatlerini de kontrol edin.',
        );
      }
      final result = await jsonOku(coz(response, token, '$id:response'));
      if (response.statusCode != 200 && result['success'] != false) {
        throw AktarimHatasi('HTTP', 'HTTP ${response.statusCode}');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> gonder(
    Uri uri,
    String token,
    Map<String, dynamic> paket,
    File kaynak,
  ) async {
    GuvenliAktarimServisi.dogrula(paket);
    if (!await kaynak.exists() ||
        await kaynak.length() != paket['belge']['dosya_boyutu'] ||
        await GuvenliAktarimServisi.hash(kaynak) !=
            paket['belge']['dosya_hash']) {
      throw AktarimHatasi(
        'KAYNAK_HASH',
        'Kaynak dosya eksik veya kayittaki boyut/hash ile uyusmuyor.',
      );
    }
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(uri).timeout(bekleme);
      req.followRedirects = false;
      final id = _basliklar(req, token, uri);
      req.headers.contentType = ContentType.binary;
      final metadata = utf8.encode(jsonEncode(paket));
      final prefix = ByteData(4)..setUint32(0, metadata.length);
      Stream<List<int>> plain() async* {
        yield prefix.buffer.asUint8List();
        yield metadata;
        yield* kaynak.openRead();
      }

      // Her flush yavas baglantida beklemeyi sinirlar, tum video icin sabit sure koymaz.
      await for (final chunk in sifrele(plain(), token, '$id:request')) {
        req.add(chunk);
        await req.flush().timeout(bekleme);
      }
      final response = await req.close().timeout(bekleme);
      if (response.statusCode == 401 || response.statusCode == 426) {
        throw AktarimHatasi(
          'ESLESME',
          'Eslesme gecersiz veya karsi surum eski. Aktarim onaylanmadi.',
        );
      }
      return await jsonOku(coz(response, token, '$id:response'));
    } finally {
      client.close(force: true);
    }
  }
}

class _AkisOkuyucu {
  final StreamIterator<List<int>> iterator;
  List<int> _chunk = const [];
  int _offset = 0;
  _AkisOkuyucu(Stream<List<int>> stream) : iterator = StreamIterator(stream);

  Future<Uint8List> oku(int length) async {
    final result = Uint8List(length);
    var written = 0;
    while (written < length) {
      if (_offset == _chunk.length) {
        if (!await iterator.moveNext())
          throw AktarimHatasi('EKSIK', 'Aktarim basligi yarida kesildi.');
        _chunk = iterator.current;
        _offset = 0;
      }
      final count =
          (length - written) < (_chunk.length - _offset)
              ? length - written
              : _chunk.length - _offset;
      result.setRange(written, written + count, _chunk, _offset);
      written += count;
      _offset += count;
    }
    return result;
  }

  Stream<List<int>> kalan() async* {
    if (_offset < _chunk.length) yield _chunk.sublist(_offset);
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  Future<void> kapat() => iterator.cancel();
}
