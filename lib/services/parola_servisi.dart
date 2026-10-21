import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

class ParolaServisi {
  static const tekrar = 600000;
  static bool esit(String a, String b) {
    if (a.length != b.length) return false;
    var fark = 0;
    for (var i = 0; i < a.length; i++) {
      fark |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return fark == 0;
  }

  static Future<String> _turet(
    String password,
    List<int> salt,
    int rounds,
  ) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return base64Encode(await key.extractBytes());
  }

  static Future<String> olustur(String password) => Isolate.run(() async {
    final random = Random.secure();
    final salt = List.generate(24, (_) => random.nextInt(256));
    return 'pbkdf2-sha256\$$tekrar\$${base64Encode(salt)}\$${await _turet(password, salt, tekrar)}';
  });

  static Future<bool> dogrula(String password, String stored) =>
      Isolate.run(() async {
        if (RegExp(r'^[a-f0-9]{64}$').hasMatch(stored)) {
          return esit(
            crypto.sha256.convert(utf8.encode(password)).toString(),
            stored,
          );
        }
        try {
          final parts = stored.split(r'$');
          if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return false;
          final rounds = int.parse(parts[1]);
          final salt = base64Decode(parts[2]);
          if (rounds < tekrar ||
              rounds > 1200000 ||
              salt.length < 16 ||
              salt.length > 64)
            return false;
          return esit(await _turet(password, salt, rounds), parts[3]);
        } catch (_) {
          return false;
        }
      });
}
