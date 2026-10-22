import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'guvenli_aktarim_servisi.dart';

class YerelAgServisi {
  static bool gecerliAdres(Object? value) {
    if (value is! String) return false;
    final ip = InternetAddress.tryParse(value);
    if (ip == null || ip.type != InternetAddressType.IPv4 || ip.isLoopback) {
      return false;
    }
    final bytes = ip.rawAddress;
    return bytes[0] != 0 &&
        bytes[0] < 224 &&
        !(bytes[0] == 169 && bytes[1] == 254);
  }

  static List<String> sirala(Iterable<({String name, String ip})> interfaces) {
    final ranked = <({String ip, int score})>[];
    for (final item in interfaces) {
      if (!gecerliAdres(item.ip)) continue;
      final name = item.name.toLowerCase();
      if (RegExp(
        r'virtual|vmware|vbox|docker|hyper-v|vethernet|rmnet|ccmni|pdp|wwan|cellular|tun\d|utun|wg\d',
      ).hasMatch(name)) {
        continue;
      }
      final hotspot = RegExp(
        r'softap|swlan|wlan|wi-fi|wifi|wireless|^ap\d|bridge|^br\d',
      ).hasMatch(name);
      final ethernet = RegExp(r'ethernet|^eth|^en|rndis|usb').hasMatch(name);
      ranked.add((
        ip: item.ip,
        score:
            hotspot
                ? 100
                : ethernet
                ? 80
                : 50,
      ));
    }
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score == 0 ? a.ip.compareTo(b.ip) : score;
    });
    return ranked.map((e) => e.ip).toSet().take(8).toList();
  }

  static Future<List<String>> adresler() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return sirala([
      for (final interface in interfaces)
        for (final ip in interface.addresses)
          (name: interface.name, ip: ip.address),
    ]);
  }

  static List<String> qrAdresleri(Map<String, dynamic> qr) {
    final extra = qr['ips'];
    if (!gecerliAdres(qr['ip']) ||
        (extra != null &&
            (extra is! List ||
                extra.length > 8 ||
                extra.any((ip) => !gecerliAdres(ip))))) {
      throw const FormatException('QR ağ adresleri geçersiz.');
    }
    return <String>{qr['ip'] as String, ...?extra?.cast<String>()}.toList();
  }

  // Discovery is only a reachability hint; pairing still proves the QR secret.
  static Future<void> ping(
    String ip,
    String deviceId, {
    int port = 8080,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(Uri.parse('http://$ip:$port/ping'))
          .timeout(const Duration(seconds: 3));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 3))) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) {
          throw const FormatException('Ping yanıtı çok büyük.');
        }
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (response.statusCode != 200 ||
          data is! Map ||
          data['status'] != 'ok' ||
          data['device_id'] != deviceId) {
        throw AktarimHatasi(
          'CIHAZ_ADRESI',
          'Bu adreste beklenen Arşivim cihazı bulunamadı. Güncel QR kodunu tarayın.',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> ulasilanAdres(
    Map<String, dynamic> qr, {
    Future<void> Function(String ip, String deviceId)? probe,
  }) async {
    final id = qr['device_id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Cihaz kimliği eksik.');
    }
    Object? lastError;
    for (final ip in qrAdresleri(qr)) {
      try {
        await (probe ?? ping)(ip, id);
        return ip;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const SocketException('Cihaz adresi bulunamadı.');
  }
}
