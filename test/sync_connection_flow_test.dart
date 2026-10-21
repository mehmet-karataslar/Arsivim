import 'dart:async';

import 'package:arsiv_uygulamasi/models/sync_comparison.dart';
import 'package:arsiv_uygulamasi/models/sync_overview.dart';
import 'package:arsiv_uygulamasi/providers/sync_controller.dart';
import 'package:arsiv_uygulamasi/screens/senkronizasyon_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/senkronizasyon_progress_dialog.dart';
import 'package:arsiv_uygulamasi/widgets/sync/sync_direction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show FakeSyncGateway, FakeSyncRepository;

const _device = SyncDevice(
  id: 'remote-session',
  name: 'Remote phone',
  ip: '192.168.1.105',
  platform: 'Android',
);
const _comparison = SyncComparison(
  sendIds: [11, 13],
  receiveIds: [21, 25, 28],
  same: 7,
  conflicts: ['Conflicting document'],
  issues: ['Unverified document'],
);
const _cancelLabel = '\u015eimdi de\u011fil';

class _ConnectionGateway extends FakeSyncGateway {
  _ConnectionGateway() {
    devices = [];
  }

  final compared = <SyncDevice>[];
  final transfers = <(SyncDirection, SyncDevice, List<int>)>[];
  SyncComparison comparison = _comparison;
  Completer<SyncComparison>? comparing;
  Object? comparisonError;
  Object? transferError;
  bool transferResult = true;
  int stopCalls = 0;

  void connectDevice([SyncDevice device = _device]) {
    devices = [...devices, device];
    changes.value++;
  }

  @override
  Future<SyncComparison> compare(SyncDevice device) async {
    compared.add(device);
    if (comparisonError != null) throw comparisonError!;
    return comparing == null ? comparison : await comparing!.future;
  }

  @override
  Future<bool> sendIds(SyncDevice device, List<int> ids) =>
      _transfer(SyncDirection.send, device, ids);

  @override
  Future<bool> receive(SyncDevice device, List<int> ids) =>
      _transfer(SyncDirection.receive, device, ids);

  Future<bool> _transfer(
    SyncDirection direction,
    SyncDevice device,
    List<int> ids,
  ) async {
    transfers.add((direction, device, List<int>.of(ids)));
    transferring = true;
    try {
      if (transferError != null) throw transferError!;
      return waiting == null ? transferResult : await waiting!.future;
    } finally {
      transferring = false;
    }
  }

  @override
  void stop() {
    stopCalls++;
    stopped = true;
    stopVersion++;
    // Stop requests do not imply that the transport has already settled.
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void _expectTransfer(_ConnectionGateway gateway, SyncDirection direction) {
  expect(gateway.transfers, hasLength(1));
  expect(gateway.transfers.single.$1, direction);
  expect(gateway.transfers.single.$2, same(_device));
  expect(
    gateway.transfers.single.$3,
    direction == SyncDirection.send ? [11, 13] : [21, 25, 28],
  );
  expect(
    gateway.sent,
    isEmpty,
    reason: 'Do not fall back to sending all files.',
  );
}

void _expectNoTransfer(_ConnectionGateway gateway) {
  expect(gateway.transfers, isEmpty);
  expect(gateway.sent, isEmpty);
  expect(gateway.stopCalls, 0);
}

Future<void> _mountScreen(
  WidgetTester tester,
  _ConnectionGateway gateway,
) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    final waiting = gateway.waiting;
    if (waiting != null && !waiting.isCompleted) waiting.complete(false);
    final comparing = gateway.comparing;
    if (comparing != null && !comparing.isCompleted) {
      comparing.complete(_comparison);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await gateway.updates.close();
    gateway.changes.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.forPalette(AppPalette.forest),
      home: Scaffold(
        body: SenkronizasyonEkrani(
          repository: FakeSyncRepository(),
          gateway: gateway,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(SyncDirectionDialog), findsNothing);
  expect(gateway.compared, isEmpty);
  _expectNoTransfer(gateway);
}

void main() {
  group('SyncController.transferDirection', () {
    late _ConnectionGateway gateway;
    late FakeSyncRepository repository;
    late SyncController controller;

    setUp(() {
      gateway = _ConnectionGateway();
      repository = FakeSyncRepository();
      controller = SyncController(repository, gateway);
    });

    tearDown(() async {
      final waiting = gateway.waiting;
      if (waiting != null && !waiting.isCompleted) {
        waiting.complete(false);
        await _flush();
      }
      controller.dispose();
      await gateway.updates.close();
      gateway.changes.dispose();
    });

    for (final direction in SyncDirection.values) {
      test('${direction.name} forwards only the chosen source IDs', () async {
        await controller.transferDirection(
          _device,
          SyncDirectionChoice(direction, _comparison),
        );
        _expectTransfer(gateway, direction);
        expect(controller.actionMessage, contains('yeni belgeler'));
        expect(controller.transferring, isFalse);
        expect(controller.stopping, isFalse);
        expect(gateway.updates.hasListener, isFalse);
        expect(repository.reads, 1);
      });

      for (final guard in ['busy', 'controller transfer', 'gateway transfer']) {
        test('${direction.name} rejects when $guard is active', () async {
          controller.busy = guard == 'busy';
          controller.transferring = guard == 'controller transfer';
          gateway.transferring = guard == 'gateway transfer';
          await controller.transferDirection(
            _device,
            SyncDirectionChoice(direction, _comparison),
          );
          _expectNoTransfer(gateway);
          expect(controller.actionMessage, contains('devam ediyor'));
          expect(controller.busy, guard == 'busy');
          expect(controller.transferring, guard == 'controller transfer');
          expect(gateway.transferring, guard == 'gateway transfer');
          expect(gateway.updates.hasListener, isFalse);
          expect(repository.reads, 0);
        });
      }

      for (final failure in ['false result', 'exception']) {
        test('${direction.name} handles $failure and allows retry', () async {
          gateway.transferResult = false;
          if (failure == 'exception') {
            gateway.transferError = StateError('transport failed');
          }
          final choice = SyncDirectionChoice(direction, _comparison);
          await controller.transferDirection(_device, choice);
          _expectTransfer(gateway, direction);
          expect(controller.actionMessage, contains('tamamlanamad'));
          expect(controller.transferring, isFalse);
          expect(controller.stopping, isFalse);
          expect(gateway.updates.hasListener, isFalse);
          expect(repository.reads, 1);

          gateway.transferResult = true;
          gateway.transferError = null;
          await controller.transferDirection(_device, choice);
          expect(gateway.transfers, hasLength(2));
          expect(controller.actionMessage, contains('yeni belgeler'));
          expect(repository.reads, 2);
        });
      }

      test(
        '${direction.name} keeps busy until a stopped transfer settles',
        () async {
          gateway.waiting = Completer<bool>();
          final transfer = controller.transferDirection(
            _device,
            SyncDirectionChoice(direction, _comparison),
          );
          await _flush();
          expect(controller.transferring, isTrue);
          expect(gateway.updates.hasListener, isTrue);
          final progress = SenkronizasyonIlerleme(
            asama: SenkronizasyonAsamasi.belgelerGonderiliyor,
            aciklama: 'Sending selected documents',
            toplamIslem: 3,
            tamamlananIslem: 1,
          );
          gateway.updates.add(progress);
          await _flush();
          expect(controller.progress, same(progress));

          controller.stop();
          expect(controller.stopping, isTrue);
          expect(controller.transferring, isTrue);
          expect(gateway.stopCalls, 1);
          expect(gateway.stopVersion, 1);
          await controller.transferDirection(
            _device,
            const SyncDirectionChoice(SyncDirection.receive, _comparison),
          );
          _expectTransfer(gateway, direction);

          gateway.waiting!.complete(false);
          await transfer;
          expect(controller.actionMessage, contains('durduruldu'));
          expect(controller.transferring, isFalse);
          expect(controller.stopping, isFalse);
          expect(gateway.updates.hasListener, isFalse);
          gateway.updates.add(
            SenkronizasyonIlerleme(
              asama: SenkronizasyonAsamasi.tamamlandi,
              aciklama: 'Late update',
            ),
          );
          await _flush();
          expect(controller.progress, same(progress));
          controller.stop();
          expect(gateway.stopCalls, 1);
        },
      );

      test('${direction.name} honors a stop from another controller', () async {
        gateway.waiting = Completer<bool>();
        final transfer = controller.transferDirection(
          _device,
          SyncDirectionChoice(direction, _comparison),
        );
        await _flush();
        final otherController = SyncController(repository, gateway);
        try {
          otherController.stop();
          expect(gateway.stopCalls, 1);
          gateway.waiting!.complete(false);
          await transfer;
          _expectTransfer(gateway, direction);
          expect(controller.actionMessage, contains('durduruldu'));
          expect(controller.transferring, isFalse);
          expect(gateway.updates.hasListener, isFalse);
        } finally {
          otherController.dispose();
        }
      });
    }

    test('idle stop does not reach the gateway', () {
      controller.stop();
      _expectNoTransfer(gateway);
      expect(controller.stopping, isFalse);
    });
  });

  group('New connection direction prompt', () {
    testWidgets('empty screen prompts on add/emit but never auto-transfers', (
      tester,
    ) async {
      final gateway = _ConnectionGateway();
      await _mountScreen(tester, gateway);
      expect(gateway.devices, isEmpty);
      gateway.connectDevice();
      await tester.pumpAndSettle();

      expect(find.byType(SyncDirectionDialog), findsOneWidget);
      expect(gateway.compared, [_device]);
      expect(find.text('Remote phone: 3 yeni belge'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-direction-send')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sync-direction-receive')),
        findsOneWidget,
      );
      _expectNoTransfer(gateway);

      gateway.changes.value++;
      gateway.changes.value++;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SyncDirectionDialog), findsOneWidget);
      expect(gateway.compared, hasLength(1));
      _expectNoTransfer(gateway);
      expect(tester.takeException(), isNull);
    });

    for (final dismissal in ['cancel', 'barrier', 'back', 'loading cancel']) {
      testWidgets('$dismissal starts nothing and does not reopen on refresh', (
        tester,
      ) async {
        final gateway = _ConnectionGateway();
        if (dismissal == 'loading cancel') {
          gateway.comparing = Completer<SyncComparison>();
        }
        await _mountScreen(tester, gateway);
        gateway.connectDevice();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(SyncDirectionDialog), findsOneWidget);
        if (dismissal == 'barrier') {
          await tester.tapAt(const Offset(5, 5));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text(_cancelLabel));
        }
        await tester.pumpAndSettle();
        expect(find.byType(SyncDirectionDialog), findsNothing);
        _expectNoTransfer(gateway);

        gateway.comparing?.complete(_comparison);
        gateway.changes.value++;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(SyncDirectionDialog), findsNothing);
        expect(gateway.compared, [_device]);
        _expectNoTransfer(gateway);
        expect(tester.takeException(), isNull);
      });
    }

    for (final direction in SyncDirection.values) {
      testWidgets(
        '${direction.name} choice calls only the selected direction',
        (tester) async {
          final gateway = _ConnectionGateway();
          await _mountScreen(tester, gateway);
          gateway.connectDevice();
          await tester.pumpAndSettle();
          _expectNoTransfer(gateway);

          final button = find.byKey(
            ValueKey('sync-direction-${direction.name}'),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          // Awaited stream cancellation can finish outside the fake clock.
          await tester.runAsync(_flush);
          await tester.pumpAndSettle();
          _expectTransfer(gateway, direction);
          expect(find.byType(SyncDirectionDialog), findsNothing);
          expect(gateway.compared, [_device]);
          gateway.changes.value++;
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          _expectTransfer(gateway, direction);
          expect(find.byType(SyncDirectionDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('comparison failure starts nothing; retry uses fresh IDs', (
      tester,
    ) async {
      final gateway =
          _ConnectionGateway()
            ..comparisonError = StateError('Peer unavailable');
      await _mountScreen(tester, gateway);
      gateway.connectDevice();
      await tester.pumpAndSettle();
      expect(find.textContaining('Peer unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-direction-send')), findsNothing);
      _expectNoTransfer(gateway);

      gateway.comparisonError = null;
      gateway.comparison = const SyncComparison(
        sendIds: [101],
        receiveIds: [201, 202],
        same: 4,
      );
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(gateway.compared, [_device, _device]);
      _expectNoTransfer(gateway);
      await tester.tap(find.byKey(const ValueKey('sync-direction-receive')));
      await tester.pump();
      // Awaited stream cancellation can finish outside the fake clock.
      await tester.runAsync(_flush);
      await tester.pumpAndSettle();
      expect(gateway.transfers, hasLength(1));
      expect(gateway.transfers.single.$1, SyncDirection.receive);
      expect(gateway.transfers.single.$2, same(_device));
      expect(gateway.transfers.single.$3, [201, 202]);
      expect(gateway.sent, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
