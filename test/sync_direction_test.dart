import 'dart:async';

import 'package:arsiv_uygulamasi/models/sync_comparison.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/sync/sync_direction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sendKey = ValueKey('sync-direction-send');
const _receiveKey = ValueKey('sync-direction-receive');
const _cancelLabel = '\u015eimdi de\u011fil';
const _comparison = SyncComparison(
  sendIds: [11, 13],
  receiveIds: [21, 25, 28],
  same: 7,
  conflicts: ['Conflicting document 91.pdf', 'Conflicting document 92.pdf'],
  issues: ['Invalid document 93.pdf'],
);

class _DialogHost {
  SyncDirectionChoice? result;
  bool completed = false;
  final selectedTransfers = <List<int>>[];

  Future<void> open(
    WidgetTester tester, {
    required Future<SyncComparison> Function() compare,
    Size size = const Size(800, 1000),
    double scale = 1,
    String localName = 'Local computer',
    String remoteName = 'Remote phone',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<SyncDirectionChoice>(
                      context: context,
                      builder:
                          (_) => SyncDirectionDialog(
                            localName: localName,
                            remoteName: remoteName,
                            compare: compare,
                          ),
                    );
                    completed = true;
                    final choice = result;
                    // Model the caller's transfer boundary: only a choice starts it.
                    if (choice != null) {
                      selectedTransfers.add(
                        choice.direction == SyncDirection.send
                            ? choice.comparison.sendIds
                            : choice.comparison.receiveIds,
                      );
                    }
                  },
                  child: const Text('Open comparison'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open comparison'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tapDirection(WidgetTester tester, Key key) async {
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void _expectNoSelection(_DialogHost host) {
  expect(host.completed, isFalse);
  expect(host.result, isNull);
  expect(host.selectedTransfers, isEmpty);
}

void main() {
  for (final direction in SyncDirection.values) {
    testWidgets('${direction.name} returns only the correct source IDs', (
      tester,
    ) async {
      final host = _DialogHost();
      var comparisons = 0;
      await host.open(
        tester,
        compare: () async {
          comparisons++;
          return _comparison;
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Local computer: 2 yeni belge'), findsOneWidget);
      expect(find.text('Remote phone: 3 yeni belge'), findsOneWidget);
      expect(find.text('7 belge iki cihazda da mevcut.'), findsOneWidget);
      _expectNoSelection(host);

      await _tapDirection(
        tester,
        direction == SyncDirection.send ? _sendKey : _receiveKey,
      );

      expect(host.completed, isTrue);
      expect(host.result!.direction, direction);
      expect(host.result!.comparison, same(_comparison));
      expect(host.selectedTransfers, [
        direction == SyncDirection.send ? [11, 13] : [21, 25, 28],
      ]);
      expect(comparisons, 1);
      expect(find.byType(SyncDirectionDialog), findsNothing);
    });
  }

  for (final dismissal in ['cancel', 'barrier', 'back', 'loading cancel']) {
    testWidgets('$dismissal returns null and starts no transfer', (
      tester,
    ) async {
      final pending = Completer<SyncComparison>();
      final host = _DialogHost();
      await host.open(
        tester,
        compare:
            () =>
                dismissal == 'loading cancel'
                    ? pending.future
                    : Future.value(_comparison),
      );
      if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(_cancelLabel));
      }
      await tester.pumpAndSettle();
      expect(host.completed, isTrue);
      expect(host.result, isNull);
      expect(host.selectedTransfers, isEmpty);
      expect(find.byType(SyncDirectionDialog), findsNothing);

      pending.complete(_comparison);
      await tester.pump();
      expect(host.selectedTransfers, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading waits; failure retries with the fresh comparison', (
    tester,
  ) async {
    final first = Completer<SyncComparison>();
    final retry = Completer<SyncComparison>();
    var comparisons = 0;
    final host = _DialogHost();
    await host.open(
      tester,
      compare: () {
        comparisons++;
        return comparisons == 1 ? first.future : retry.future;
      },
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(_sendKey), findsNothing);
    expect(find.byKey(_receiveKey), findsNothing);
    _expectNoSelection(host);

    first.completeError(StateError('Peer unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Peer unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(_sendKey), findsNothing);
    expect(find.byKey(_receiveKey), findsNothing);
    _expectNoSelection(host);

    await tester.tap(find.text('Yeniden dene'));
    await tester.pump();
    expect(comparisons, 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    _expectNoSelection(host);

    const fresh = SyncComparison(sendIds: [42], receiveIds: [84], same: 0);
    retry.complete(fresh);
    await tester.pumpAndSettle();
    expect(find.textContaining('Peer unavailable'), findsNothing);
    await _tapDirection(tester, _receiveKey);
    expect(host.result!.comparison, same(fresh));
    expect(host.selectedTransfers, [
      [84],
    ]);
  });

  for (final ids in [
    (<int>[], <int>[]),
    (<int>[], <int>[21]),
    (<int>[11], <int>[]),
  ]) {
    testWidgets('empty counts disable only their direction: $ids', (
      tester,
    ) async {
      final host = _DialogHost();
      await host.open(
        tester,
        compare:
            () async =>
                SyncComparison(sendIds: ids.$1, receiveIds: ids.$2, same: 0),
      );
      await tester.pumpAndSettle();
      final send = tester.widget<ButtonStyleButton>(find.byKey(_sendKey));
      final receive = tester.widget<ButtonStyleButton>(find.byKey(_receiveKey));
      expect(send.onPressed == null, ids.$1.isEmpty);
      expect(receive.onPressed == null, ids.$2.isEmpty);
      for (final key in [
        if (ids.$1.isEmpty) _sendKey,
        if (ids.$2.isEmpty) _receiveKey,
      ]) {
        await _tapDirection(tester, key);
        _expectNoSelection(host);
      }
      await tester.tap(find.text(_cancelLabel));
      await tester.pumpAndSettle();
      expect(host.selectedTransfers, isEmpty);
    });
  }

  for (final direction in SyncDirection.values) {
    testWidgets(
      'conflicts and invalid entries are listed, excluded from ${direction.name}',
      (tester) async {
        final host = _DialogHost();
        await host.open(tester, compare: () async => _comparison);
        await tester.pumpAndSettle();
        expect(
          find.text('2 \u00e7ak\u0131\u015fan kay\u0131t aktar\u0131lmayacak.'),
          findsOneWidget,
        );
        expect(
          find.text('1 kay\u0131t do\u011frulanamad\u0131 ve atlanacak.'),
          findsOneWidget,
        );
        for (final title in [..._comparison.conflicts, ..._comparison.issues]) {
          expect(find.text(title), findsOneWidget);
        }
        await _tapDirection(
          tester,
          direction == SyncDirection.send ? _sendKey : _receiveKey,
        );
        expect(
          host.selectedTransfers.single,
          direction == SyncDirection.send ? [11, 13] : [21, 25, 28],
        );
        expect(
          host.selectedTransfers.single,
          isNot(contains(anyOf(91, 92, 93))),
        );
      },
    );
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final state in ['loading', 'error', 'ready']) {
        testWidgets('$state fits $width at text scale $scale', (tester) async {
          final pending = Completer<SyncComparison>();
          final host = _DialogHost();
          await host.open(
            tester,
            size: Size(width, width == 320 ? 640 : 900),
            scale: scale,
            localName: 'Mehmet family archive computer',
            remoteName: 'Family document backup phone',
            compare: () => pending.future,
          );
          expect(tester.takeException(), isNull);
          if (state == 'error') {
            pending.completeError(StateError('Connection unavailable. Retry.'));
            await tester.pumpAndSettle();
            expect(find.text('Yeniden dene'), findsOneWidget);
          } else if (state == 'ready') {
            pending.complete(
              SyncComparison(
                sendIds: _comparison.sendIds,
                receiveIds: _comparison.receiveIds,
                same: _comparison.same,
                conflicts: List.generate(
                  12,
                  (i) => 'Conflicting archive document $i.pdf',
                ),
                issues: List.generate(
                  12,
                  (i) => 'Invalid archive document $i.pdf',
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final key in [_sendKey, _receiveKey]) {
              await tester.ensureVisible(find.byKey(key));
              await tester.pumpAndSettle();
              expect(find.byKey(key).hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          } else {
            expect(find.byType(LinearProgressIndicator), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          expect(find.text(_cancelLabel).hitTestable(), findsOneWidget);
          _expectNoSelection(host);
          await tester.tap(find.text(_cancelLabel));
          await tester.pumpAndSettle();
          if (!pending.isCompleted) {
            pending.complete(_comparison);
            await tester.pump();
          }
          expect(host.completed, isTrue);
          expect(host.selectedTransfers, isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
