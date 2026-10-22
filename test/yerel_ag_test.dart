import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/services/yerel_ag_servisi.dart';
import 'package:arsiv_uygulamasi/services/baglanti_tanisi.dart';
import 'package:arsiv_uygulamasi/services/guvenli_aktarim_servisi.dart';
import 'package:arsiv_uygulamasi/models/connection_qr.dart';
import 'qr_scanner_test.dart' show payload;

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  test('Android hotspot outranks cellular, VPN and link-local interfaces', () {
    expect(
      YerelAgServisi.sirala([
        (name: 'rmnet_data0', ip: '10.1.2.3'),
        (name: 'tun0', ip: '10.2.3.4'),
        (name: 'swlan0', ip: '192.168.43.1'),
        (name: 'ap0', ip: '192.168.44.1'),
        (name: 'Bluetooth', ip: '169.254.62.164'),
        (name: 'lo', ip: '127.0.0.1'),
      ]),
      ['192.168.43.1', '192.168.44.1'],
    );
  });
  test(
    'PC Wi-Fi and Ethernet are both offered without assuming a /24 subnet',
    () {
      expect(
        YerelAgServisi.sirala([
          (name: 'vEthernet (WSL)', ip: '172.20.32.1'),
          (name: 'Ethernet', ip: '10.20.1.8'),
          (name: 'Wi-Fi', ip: '172.18.4.20'),
        ]),
        ['172.18.4.20', '10.20.1.8'],
      );
    },
  );
  test('Mobile-data-only does not masquerade as a local Wi-Fi connection', () {
    expect(
      YerelAgServisi.sirala([(name: 'rmnet0', ip: '10.12.13.14')]),
      isEmpty,
    );
  });
  for (final ip in [
    '0.0.0.0',
    '127.0.0.1',
    '169.254.5.6',
    '224.1.2.3',
    '255.255.255.255',
    '::1',
    'example.com',
  ]) {
    test('Reject invalid/local-only QR endpoint $ip', () {
      expect(YerelAgServisi.gecerliAdres(ip), isFalse);
      expect(
        () => ConnectionQr.parse(jsonEncode({...payload(), 'ip': ip})),
        throwsA(isA<QrReadException>()),
      );
    });
  }
  test('Legacy single-IP QR and new multi-IP QR remain readable', () {
    expect(YerelAgServisi.qrAdresleri(payload()), ['192.168.1.100']);
    final qr = {
      ...payload(),
      'ips': ['192.168.1.100', '192.168.43.20'],
    };
    expect(YerelAgServisi.qrAdresleri(qr), ['192.168.1.100', '192.168.43.20']);
    expect(ConnectionQr.parse(jsonEncode(qr)).device, isNotEmpty);
    expect(
      () => YerelAgServisi.qrAdresleri({
        ...qr,
        'ips': List.filled(9, '192.168.1.100'),
      }),
      throwsFormatException,
    );
  });
  test(
    'Wrong or unavailable first address falls back to the advertised hotspot address',
    () async {
      final checked = <String>[];
      final result = await YerelAgServisi.ulasilanAdres(
        {
          'ip': '192.168.1.100',
          'ips': ['192.168.43.20'],
          'device_id': 'pc',
        },
        probe: (ip, device) async {
          checked.add(ip);
          expect(device, 'pc');
          if (ip == '192.168.1.100') throw const SocketException('offline');
        },
      );
      expect(result, '192.168.43.20');
      expect(checked, ['192.168.1.100', '192.168.43.20']);
    },
  );
  test('Network failures remain network failures, not password errors', () {
    final text = BaglantiTanisi.mesaj(
      const SocketException('refused', osError: OSError('refused', 10061)),
      'Ağ',
    );
    expect(text, contains('reddetti'));
    expect(text, contains('Bu telefonu bağlantılara aç'));
    expect(text, isNot(contains('şifre')));
  });
  test(
    'Real ping rejects unrelated HTTP services and wrong device IDs',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var response = <String, dynamic>{'status': 'ok', 'device_id': 'pc'};
      final subscription = server.listen((request) async {
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      try {
        await YerelAgServisi.ping('127.0.0.1', 'pc', port: server.port);
        response = {'status': 'ok', 'device_id': 'other'};
        await expectLater(
          YerelAgServisi.ping('127.0.0.1', 'pc', port: server.port),
          throwsA(isA<AktarimHatasi>()),
        );
        response = {'message': 'unrelated HTTP server'};
        await expectLater(
          YerelAgServisi.ping('127.0.0.1', 'pc', port: server.port),
          throwsA(isA<AktarimHatasi>()),
        );
      } finally {
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );
}
