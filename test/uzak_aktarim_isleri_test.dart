import 'dart:async';
import 'dart:convert';

import 'package:arsiv_uygulamasi/services/uzak_aktarim_isleri.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = 'random-connection-session-token-a';
const other = 'random-connection-session-token-b';

Future<void> flushJobs() => Future<void>.delayed(Duration.zero);

void main() {
  late DateTime now;
  late UzakAktarimIsleri jobs;
  late List<Completer<Map<String, dynamic>>> pending;
  late List<(String, List<int>)> calls;
  late int stops;

  setUp(() {
    now = DateTime.utc(2026, 10, 21);
    pending = [];
    calls = [];
    stops = 0;
    jobs = UzakAktarimIsleri(
      send: (who, ids) {
        calls.add((who, ids));
        final completer = Completer<Map<String, dynamic>>();
        pending.add(completer);
        return completer.future;
      },
      stop: () => stops++,
      saat: () => now,
    );
  });

  tearDown(() async {
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete({'status': 'cancelled'});
      }
    }
    await flushJobs();
  });

  String start({String who = owner, String request = 'request-1'}) =>
      jobs.baslat(who, request, [1, 2])['job_id'] as String;

  test(
    'queues, copies IDs, passes session owner, and preserves results',
    () async {
      final ids = [1, 2];
      final started = jobs.baslat(owner, 'request-1', ids);
      final id = started['job_id'] as String;
      expect(id, matches(RegExp(r'^[a-f0-9]{48}$')));
      expect(started['status'], 'queued');
      expect(calls, isEmpty);
      ids.clear();
      started['status'] = 'changed';
      await flushJobs();
      expect(calls.single.$1, owner);
      expect(calls.single.$2, [1, 2]);
      expect(() => calls.single.$2.add(3), throwsUnsupportedError);
      expect(jobs.status(owner, id)['status'], 'running');
      final result = <String, dynamic>{
        'status': 'partial',
        'completed_count': 1,
        'failed_count': 1,
        'errors': [
          {'id': 2, 'message': 'rejected'},
        ],
        'sonAktarimSonuclari': [
          {'dosya': 'a.pdf', 'durum': 'hata'},
        ],
      };
      pending.single.complete(result);
      await flushJobs();
      expect(jobs.status(owner, id)['status'], 'partial');
      expect(jobs.status(owner, id)['result'], result);
      (jobs.status(owner, id)['result']['errors'] as List).clear();
      (result['errors'] as List).clear();
      expect(jobs.status(owner, id)['result']['errors'], hasLength(1));
      expect(jobs.status(owner, id).containsKey('owner'), isFalse);
    },
  );

  test(
    'same-owner exact retries are idempotent before and after finish',
    () async {
      final id = start();
      expect(start(), id);
      expect(
        jobs.baslat(owner, 'request-1', [2, 1])['error'],
        'request_conflict',
      );
      expect(jobs.baslat(owner, 'request-1', [1])['error'], 'request_conflict');
      expect(
        jobs.baslat(owner, 'request-1', [1, 3])['error'],
        'request_conflict',
      );
      await flushJobs();
      expect(start(), id);
      pending.single.complete({'status': 'completed', 'completed_count': 2});
      await flushJobs();
      expect(start(), id);
      expect(calls, hasLength(1));
      expect(jobs.status(owner, id)['status'], 'completed');
    },
  );

  test(
    'busy rejects same or different owners without disclosing job ID',
    () async {
      final id = start();
      for (final who in [owner, other]) {
        final response = jobs.baslat(who, 'another-request', [3]);
        expect(response, {
          'success': false,
          'error': 'busy',
          'http_status': 409,
        });
      }
      expect(jobs.baslat(other, 'request-1', [1, 2])['error'], 'busy');
      await flushJobs();
      expect(jobs.baslat(other, 'request-1', [1, 2])['error'], 'busy');
      pending.single.complete({'status': 'completed'});
      await flushJobs();
      final second = start(who: other);
      expect(second, isNot(id));
      await flushJobs();
      expect(calls.last.$1, other);
      expect(start(), id);
      expect(calls, hasLength(2));
    },
  );

  test(
    'another connection cannot poll or cancel even on the same IP',
    () async {
      final id = start();
      final missing = jobs.status(owner, 'missing');
      expect(jobs.status(other, id), missing);
      expect(jobs.stop(other, id), missing);
      expect(jobs.status('192.168.1.5', id), missing);
      expect(stops, 0);
      await flushJobs();
      expect(jobs.stop(other, id), missing);
      expect(jobs.status(owner, id)['status'], 'running');
      expect(stops, 0);
    },
  );

  test(
    'cancel before dispatch never sends or stops a replacement job',
    () async {
      final first = start();
      expect(jobs.stop(owner, first)['status'], 'cancelled');
      final second = start(request: 'replacement');
      expect(jobs.stop(owner, first)['status'], 'cancelled');
      await flushJobs();
      expect(calls, hasLength(1));
      expect(stops, 0);
      expect(jobs.status(owner, second)['status'], 'running');
      expect(jobs.baslat(owner, 'third', [3])['error'], 'busy');
      expect(start(), first);
    },
  );

  test(
    'stop is owner-only, once-only, and busy until sender settles',
    () async {
      final id = start();
      await flushJobs();
      expect(jobs.stop(owner, id)['status'], 'stopping');
      expect(jobs.stop(owner, id)['status'], 'stopping');
      expect(stops, 1);
      expect(jobs.baslat(owner, 'next', [3])['error'], 'busy');
      now = now.add(const Duration(days: 1));
      expect(jobs.status(owner, id)['status'], 'stopping');
      expect(jobs.baslat(other, 'next', [3])['error'], 'busy');
      pending.single.complete({'status': 'partial', 'completed_count': 1});
      await flushJobs();
      final finished = jobs.status(owner, id);
      expect(finished['status'], 'cancelled');
      expect(finished['result']['completed_count'], 1);
      final second = start(request: 'next');
      expect(jobs.stop(owner, id)['status'], 'cancelled');
      await flushJobs();
      expect(jobs.status(owner, second)['status'], 'running');
      expect(stops, 1);
    },
  );

  test('throwing stop retains busy lock until sender finishes', () async {
    final done = Completer<Map<String, dynamic>>();
    jobs = UzakAktarimIsleri(
      send: (_, _) => done.future,
      stop: () {
        stops++;
        throw StateError('stop failed');
      },
      saat: () => now,
    );
    final id = start();
    await flushJobs();
    final response = jobs.stop(owner, id);
    expect(response['success'], isFalse);
    expect(response['error'], 'stop_failed');
    expect(response['http_status'], 500);
    expect(response['status'], 'stopping');
    expect(response['stop_error'], contains('stop failed'));
    expect(jobs.stop(owner, id), response);
    expect(stops, 1);
    now = now.add(const Duration(days: 1));
    expect(jobs.baslat(owner, 'next', [3])['error'], 'busy');
    expect(jobs.status(owner, id)['status'], 'stopping');
    done.complete({
      'status': 'failed',
      'errors': ['transport failed'],
    });
    await flushJobs();
    expect(jobs.status(owner, id)['status'], 'cancelled');
    expect(jobs.baslat(owner, 'next', [3])['success'], isTrue);
    await flushJobs();
  });

  for (final terminal in ['completed', 'partial', 'failed', 'cancelled']) {
    test('preserves explicit terminal outcome $terminal', () async {
      final id = start();
      await flushJobs();
      final result = {
        'status': terminal,
        'errors': ['detail'],
        'count': 1,
      };
      pending.single.complete(result);
      await flushJobs();
      expect(jobs.status(owner, id)['status'], terminal);
      expect(jobs.status(owner, id)['result'], result);
      expect(jobs.stop(owner, id)['status'], terminal);
      expect(stops, 0);
    });
  }

  test('supports success boolean without guessing partial outcomes', () async {
    for (final success in [true, false]) {
      final id = start(request: '$success');
      await flushJobs();
      pending.last.complete({'success': success});
      await flushJobs();
      expect(
        jobs.status(owner, id)['status'],
        success ? 'completed' : 'failed',
      );
    }
  });

  test(
    'sync and async send failures are recorded and release busy lock',
    () async {
      for (final synchronous in [true, false]) {
        jobs = UzakAktarimIsleri(
          send: (_, _) {
            if (synchronous) throw StateError('sync failure');
            return Future<Map<String, dynamic>>.error(
              StateError('async failure'),
            );
          },
          stop: () {},
        );
        final id = start();
        await flushJobs();
        final response = jobs.status(owner, id);
        expect(response['status'], 'failed');
        expect(response['result']['error'], 'send_failed');
        expect(response['result']['message'], contains('failure'));
        expect(jobs.baslat(owner, 'next', [3])['success'], isTrue);
        await flushJobs();
      }
    },
  );

  test(
    'cancelled send error cannot escape or clear a subsequent job',
    () async {
      final id = start();
      await flushJobs();
      jobs.stop(owner, id);
      pending.single.completeError(StateError('cancelled transport'));
      await flushJobs();
      expect(jobs.status(owner, id)['status'], 'cancelled');
      expect(jobs.status(owner, id)['result']['error'], 'send_failed');
      final second = start(request: 'next');
      await flushJobs();
      expect(jobs.status(owner, second)['status'], 'running');
      expect(jobs.baslat(owner, 'third', [3])['error'], 'busy');
    },
  );

  test('validates bounds without reserving jobs or calling sender', () async {
    expect(jobs.baslat('', 'r', [1])['error'], 'invalid_owner');
    expect(jobs.baslat(' ' * 513, 'r', [1])['error'], 'invalid_owner');
    expect(jobs.baslat(owner, '', [1])['error'], 'invalid_request_id');
    expect(jobs.baslat(owner, 'r' * 129, [1])['error'], 'invalid_request_id');
    for (final ids in [
      <int>[],
      [0],
      [-1],
      List.generate(201, (i) => i + 1),
    ]) {
      expect(jobs.baslat(owner, 'r', ids)['error'], 'invalid_ids');
    }
    await flushJobs();
    expect(calls, isEmpty);
    expect(
      jobs.baslat(owner, 'r', List.generate(200, (i) => i + 1))['success'],
      isTrue,
    );
    await flushJobs();
    expect(calls.single.$2, hasLength(200));
  });

  test('retains at most 32 jobs and evicts oldest completed only', () async {
    final ids = <String>[];
    for (var i = 0; i < 32; i++) {
      final id = start(request: 'r$i');
      ids.add(id);
      jobs.stop(owner, id);
      now = now.add(const Duration(seconds: 1));
    }
    expect(ids.toSet(), hasLength(32));
    for (final id in ids) {
      expect(jobs.status(owner, id)['status'], 'cancelled');
    }
    final active = start(request: 'active');
    expect(jobs.status(owner, ids.first)['error'], 'not_found');
    for (final id in ids.skip(1)) {
      expect(jobs.status(owner, id)['status'], 'cancelled');
    }
    expect(jobs.baslat(other, 'extra', [1])['error'], 'busy');
    expect(jobs.status(owner, ids[1])['status'], 'cancelled');
    await flushJobs();
    expect(calls, hasLength(1));
    expect(jobs.status(owner, active)['status'], 'running');
  });

  test(
    'expiry is 30 minutes after completion, never while queued or running',
    () async {
      final id = start();
      now = now.add(const Duration(hours: 1));
      expect(jobs.status(owner, id)['status'], 'queued');
      await flushJobs();
      now = now.add(const Duration(hours: 1));
      expect(jobs.status(owner, id)['status'], 'running');
      expect(jobs.baslat(other, 'next', [1])['error'], 'busy');
      pending.single.complete({'status': 'completed'});
      await flushJobs();
      now = now.add(
        const Duration(minutes: 30) - const Duration(microseconds: 1),
      );
      expect(start(), id);
      now = now.add(const Duration(microseconds: 1));
      expect(jobs.status(owner, id)['error'], 'not_found');
      expect(jobs.stop(owner, id)['error'], 'not_found');
      expect(start(), isNot(id));
      await flushJobs();
    },
  );

  test('malformed and oversized callback results fail closed', () async {
    final invalid = <Map<String, dynamic>>[
      {'count': 1},
      {'status': 'running'},
      {'status': 'completed', 'value': Object()},
      {'status': 'completed', 'errors': 'x' * 65536},
      {'status': 'completed', 'errors': '\u00e9' * 32768},
    ];
    for (var i = 0; i < invalid.length; i++) {
      final id = start(request: 'r$i');
      await flushJobs();
      pending.last.complete(invalid[i]);
      await flushJobs();
      final response = jobs.status(owner, id);
      expect(response['status'], 'failed');
      expect(response['result']['error'], isNotNull);
      expect(
        utf8.encode(jsonEncode(response['result'])).length,
        lessThanOrEqualTo(UzakAktarimIsleri.azamiSonucBayt),
      );
    }
  });

  test('exception text retained in memory is bounded', () async {
    final id = start();
    await flushJobs();
    pending.single.completeError(StateError('x' * 100000));
    await flushJobs();
    expect(jobs.status(owner, id)['result']['message'].length, 1024);
  });
}
