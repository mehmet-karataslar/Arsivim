import 'package:arsiv_uygulamasi/services/depolama_izni.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final calls = <MethodCall>[];
  var status = PermissionStatus.denied;

  setUp(() {
    calls.clear();
    status = PermissionStatus.denied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'checkPermissionStatus') return status.index;
          if (call.method == 'requestPermissions') {
            return <int, int>{
              for (final id in call.arguments as List)
                id as int: PermissionStatus.granted.index,
            };
          }
          throw StateError('Beklenmeyen izin çağrısı: ${call.method}');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final sdk in [28, 29, 30, 32, 33, 36]) {
    test(
      'Android SDK $sdk yalnızca desteklenen depolama iznini ister',
      () async {
        await androidDepolamaIzniIste(sdk);
        final expected =
            sdk < 30
                ? Permission.storage.value
                : Permission.manageExternalStorage.value;
        expect(calls.map((c) => c.method), [
          'checkPermissionStatus',
          'requestPermissions',
        ]);
        expect(calls.first.arguments, expected);
        expect(calls.last.arguments, [expected]);
      },
    );
  }

  test('Verilmiş depolama izni yeniden istenmez', () async {
    status = PermissionStatus.granted;
    await androidDepolamaIzniIste(36);
    expect(calls.map((c) => c.method), ['checkPermissionStatus']);
  });
}
