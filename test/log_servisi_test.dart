import 'dart:async';
import 'dart:io';

import 'package:arsiv_uygulamasi/services/log_servisi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  late Directory temp;
  late File logFile;
  late LogServisi logs;
  late Level previousLevel;

  setUp(() async {
    previousLevel = Logger.root.level;
    temp = await Directory.systemTemp.createTemp('arsiv-log-test-');
    logFile = File('${temp.path}/app.txt');
    logs = LogServisi.test(logFile: logFile);
  });

  tearDown(() async {
    await logs.flush();
    await logs.dispose();
    Logger.root.level = previousLevel;
    await temp.delete(recursive: true);
  });

  test('Konsol sessizken hata, yığın izi ve dosya kaydı korunur', () async {
    final console = <String>[];
    final error = StateError('örnek hata');
    final stack = StackTrace.current;
    await runZoned(
      () async {
        await logs.init();
        logs.error('İşlem tamamlanamadı', error, stack);
        logs.debug('geliştirme çıktısı');
        await logs.flush();
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, message) => console.add(message),
      ),
    );

    expect(console, isEmpty);
    final entry = logs.getMemoryLogs(filterLevel: Level.SEVERE).single;
    expect(entry.error, same(error));
    expect(entry.stackTrace, same(stack));
    final text = await logFile.readAsString();
    expect(text, contains('İşlem tamamlanamadı'));
    expect(text, contains('örnek hata'));
    expect(text, contains('Stack trace:'));
    expect(text, isNot(contains('geliştirme çıktısı')));
  });

  test('Log servisi başlamadan oluşan hata kaybolmaz', () async {
    logs.error('Başlangıç hatası', StateError('başlatılamadı'));
    expect(logs.getMemoryLogs().single.message, 'Başlangıç hatası');
    await logs.init();
    expect(
      logs.getMemoryLogs().any((e) => e.message == 'Başlangıç hatası'),
      true,
    );
  });

  test(
    'Dosya yazılamazsa hata bellekte kalır ve tekrar yazma döngüsü oluşmaz',
    () async {
      logs = LogServisi.test(logFile: File('${temp.path}/eksik/app.txt'));
      final console = <String>[];
      await runZoned(
        () async {
          await logs.init();
          logs.error('Korunacak hata');
          await logs.flush();
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, message) => console.add(message),
        ),
      );
      expect(console, isEmpty);
      final entries = logs.getMemoryLogs();
      expect(entries.any((e) => e.message == 'Korunacak hata'), true);
      expect(entries.any((e) => e.error is FileSystemException), true);
      expect(entries.length, lessThan(10));
    },
  );

  test('Kapatılan log servisi yeni kayıt dinlemez', () async {
    await logs.init();
    await logs.dispose();
    Logger('test').severe('Kapanış sonrası');
    expect(logs.getMemoryLogs(), isEmpty);
  });
}
