import 'dart:convert';
import 'dart:io';
import '../services/arsiv_hesap_servisi.dart';
import '../services/guvenli_aktarim_servisi.dart';

class QrReadException implements Exception {
  const QrReadException(this.message);
  final String message;
}

/// Presentation preflight only; the server still verifies the ticket and account.
class ConnectionQr {
  const ConnectionQr({
    required this.raw,
    required this.device,
    required this.address,
    required this.owner,
    required this.expires,
  });
  final String raw, device, address, owner;
  final DateTime expires;
  bool expired(DateTime now) => !now.isBefore(expires);

  factory ConnectionQr.parse(String raw, {DateTime? now}) {
    const invalid = QrReadException(
      'Bu bir Arşivim bağlantı kodu değil. Senkronizasyon sayfasındaki QR kodunu tarayın.',
    );
    try {
      if (raw.length > 16384) throw invalid;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['type'] != 'arsivim_connection')
        throw invalid;
      if (data['account_version'] != 1 ||
          data['session_version'] != 1 ||
          data['transfer_version'] != GuvenliAktarimServisi.surum) {
        throw const QrReadException(
          'Bu QR kodu eski bir sürüme ait. İki cihazı güncelleyip yeni kod oluşturun.',
        );
      }
      for (final key in ['pair_ticket', 'transfer_token']) {
        if (data[key] is! String ||
            !RegExp(r'^[a-f0-9]{48}$').hasMatch(data[key]))
          throw invalid;
      }
      if (data['pair_expires'] is! int ||
          data['account'] is! Map ||
          data['ip'] is! String ||
          data['port'] != 8080 ||
          InternetAddress.tryParse(data['ip'])?.type !=
              InternetAddressType.IPv4)
        throw invalid;
      final account = Map<String, dynamic>.from(data['account']);
      ArsivHesapServisi.tanitimDogrula(account);
      final result = ConnectionQr(
        raw: raw,
        device:
            data['device_name'] is String &&
                    (data['device_name'] as String).trim().isNotEmpty
                ? (data['device_name'] as String).trim().substring(
                  0,
                  (data['device_name'] as String).trim().length.clamp(0, 120),
                )
                : 'Arşivim cihazı',
        address: '${data['ip']}:8080',
        owner: '${account['ad']} ${account['soyad']}',
        expires: DateTime.fromMillisecondsSinceEpoch(data['pair_expires']),
      );
      if (result.expired(now ?? DateTime.now())) {
        throw const QrReadException(
          'QR kodunun süresi dolmuş. Diğer cihazda yeni kod oluşturup tekrar tarayın.',
        );
      }
      return result;
    } on QrReadException {
      rethrow;
    } catch (_) {
      throw invalid;
    }
  }
}
