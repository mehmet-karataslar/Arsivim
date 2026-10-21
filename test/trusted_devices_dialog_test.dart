import 'dart:async';

import 'package:arsiv_uygulamasi/services/sync_gateway.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/sync/trusted_devices_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cancel = 'Vazge\u00e7';
const _connect = 'Ba\u011flan';
const _deviceName = 'Family archive computer';

class _FakeGateway extends SyncGateway {
  final remembered = <Map<String, dynamic>>[
    {
      'trust_id': 'trusted-computer',
      'device_name': _deviceName,
      'last_ip': '192.168.1.100',
    },
    {
      'trust_id': 'trusted-phone',
      'device_name': 'Backup phone',
      'last_ip': '192.168.1.101',
    },
  ];
  int reads = 0;
  int pairingCalls = 0;
  final reconnects = <(String, String)>[];
  final forgotten = <String>[];
  Completer<List<Map<String, dynamic>>>? pendingRead;
  Completer<bool>? pendingReconnect;
  Completer<void>? pendingForget;
  Object? readError;
  Object? reconnectError;
  Object? forgetError;
  bool reconnectResult = true;

  @override
  Future<List<Map<String, dynamic>>> trustedDevices() async {
    reads++;
    if (pendingRead != null) return pendingRead!.future;
    if (readError != null) throw readError!;
    return remembered.map((device) => Map<String, dynamic>.of(device)).toList();
  }

  @override
  Future<bool> reconnect(String trustId, String address) async {
    reconnects.add((trustId, address));
    if (pendingReconnect != null) return pendingReconnect!.future;
    if (reconnectError != null) throw reconnectError!;
    return reconnectResult;
  }

  @override
  Future<void> forget(String trustId) async {
    forgotten.add(trustId);
    if (pendingForget != null) await pendingForget!.future;
    if (forgetError != null) throw forgetError!;
    remembered.removeWhere((device) => device['trust_id'] == trustId);
  }

  @override
  Future<bool> connect(String qr) async {
    pairingCalls++;
    return false;
  }

  @override
  Future<String> createQr() async {
    pairingCalls++;
    return '';
  }
}

class _Host {
  bool? result;
  bool completed = false;

  Future<void> open(
    WidgetTester tester,
    _FakeGateway gateway, {
    Size size = const Size(800, 1000),
    double scale = 1,
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
                    result = await showDialog<bool>(
                      context: context,
                      builder: (_) => TrustedDevicesDialog(gateway: gateway),
                    );
                    completed = true;
                  },
                  child: const Text('Open trusted devices'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trusted devices'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _connectIcon() => find.widgetWithIcon(IconButton, Icons.link).first;

Finder _forgetIcon() =>
    find.widgetWithIcon(IconButton, Icons.phonelink_erase).first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openAddress(WidgetTester tester) async {
  await _tap(tester, _connectIcon());
  expect(find.byType(TextField), findsOneWidget);
}

void _expectIdle(_Host host, _FakeGateway gateway) {
  expect(host.completed, isFalse);
  expect(host.result, isNull);
  expect(gateway.reconnects, isEmpty);
  expect(gateway.forgotten, isEmpty);
  expect(gateway.pairingCalls, 0);
}

void main() {
  for (final edited in [false, true]) {
    testWidgets(
      'remembered reconnect uses ${edited ? 'edited' : 'saved'} IP without password',
      (tester) async {
        final gateway = _FakeGateway()..pendingReconnect = Completer<bool>();
        final host = _Host();
        await host.open(tester, gateway);
        await _openAddress(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, '192.168.1.100');
        expect(field.obscureText, isFalse);
        expect(field.keyboardType, TextInputType.url);
        expect(find.byType(TextField), findsOneWidget);
        if (edited) {
          await tester.enterText(find.byType(TextField), '  192.168.1.222  ');
        }
        await _tap(tester, find.text(_connect));
        expect(gateway.reconnects, [
          ('trusted-computer', edited ? '192.168.1.222' : '192.168.1.100'),
        ]);
        expect(gateway.pairingCalls, 0);
        expect(host.completed, isFalse);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
        for (final button in tester.widgetList<IconButton>(
          find.byType(IconButton),
        )) {
          expect(button.onPressed, isNull);
        }
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Kapat'))
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(host.completed, isFalse);

        gateway.pendingReconnect!.complete(true);
        await tester.pumpAndSettle();
        expect(host.completed, isTrue);
        expect(host.result, isTrue);
        expect(find.byType(TrustedDevicesDialog), findsNothing);
        expect(gateway.forgotten, isEmpty);
        expect(gateway.remembered, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dismissal in ['cancel', 'back', 'barrier']) {
    testWidgets(
      'edited IP $dismissal preserves remembered address and makes no request',
      (tester) async {
        final gateway = _FakeGateway();
        final host = _Host();
        await host.open(tester, gateway);
        await _openAddress(tester);
        await tester.enterText(find.byType(TextField), '192.168.1.222');
        if (dismissal == 'cancel') {
          await tester.tap(find.text(_cancel));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        _expectIdle(host, gateway);
        expect(gateway.remembered.first['last_ip'], '192.168.1.100');
        await _openAddress(tester);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '192.168.1.100',
        );
        await _tap(tester, find.text(_cancel));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final submit in [false, true]) {
    testWidgets(
      'IP controller lives through ${submit ? 'submit' : 'cancel'} exit animation',
      (tester) async {
        final gateway = _FakeGateway()..pendingReconnect = Completer<bool>();
        await _Host().open(tester, gateway);
        await _openAddress(tester);
        final controller =
            tester.widget<TextField>(find.byType(TextField)).controller!;
        await tester.tap(find.text(submit ? _connect : _cancel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        void listener() {}
        expect(() => controller.addListener(listener), returnsNormally);
        controller.removeListener(listener);
        await tester.pump(const Duration(milliseconds: 300));
        expect(() => controller.addListener(listener), throwsFlutterError);
        if (submit) {
          gateway.pendingReconnect!.complete(false);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dismissal in ['cancel', 'back', 'barrier']) {
    testWidgets(
      'forget confirmation $dismissal preserves all remembered devices',
      (tester) async {
        final gateway = _FakeGateway();
        final host = _Host();
        await host.open(tester, gateway);
        await _tap(tester, _forgetIcon());
        expect(find.textContaining('belgeler silinmez'), findsOneWidget);
        if (dismissal == 'cancel') {
          await tester.tap(find.text(_cancel));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        _expectIdle(host, gateway);
        expect(gateway.remembered, hasLength(2));
        expect(gateway.reads, 1);
        expect(find.text(_deviceName), findsOneWidget);
        expect(find.text('Backup phone'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'confirmed forget removes only selected trust and refreshes after completion',
    (tester) async {
      final gateway = _FakeGateway()..pendingForget = Completer<void>();
      final host = _Host();
      await host.open(tester, gateway);
      await _tap(tester, _forgetIcon());
      expect(gateway.forgotten, isEmpty);
      await _tap(tester, find.text('Unut'));
      expect(gateway.forgotten, ['trusted-computer']);
      expect(gateway.reads, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(host.completed, isFalse);
      gateway.pendingForget!.complete();
      await tester.pumpAndSettle();
      expect(gateway.reads, 2);
      expect(gateway.remembered.single['trust_id'], 'trusted-phone');
      expect(find.text(_deviceName), findsNothing);
      expect(find.text('Backup phone'), findsOneWidget);
      expect(gateway.reconnects, isEmpty);
      expect(gateway.pairingCalls, 0);
      await _tap(tester, find.text('Kapat'));
      expect(host.completed, isTrue);
      expect(host.result, isNull);
    },
  );

  testWidgets('forget failure preserves list and permits retry', (
    tester,
  ) async {
    final gateway = _FakeGateway()..forgetError = StateError('offline');
    final host = _Host();
    await host.open(tester, gateway);
    await _tap(tester, _forgetIcon());
    await _tap(tester, find.text('Unut'));
    expect(find.textContaining('Yeniden deneyin.'), findsOneWidget);
    expect(gateway.remembered, hasLength(2));
    expect(gateway.reads, 1);
    expect(host.completed, isFalse);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    gateway.forgetError = null;
    await _tap(tester, _forgetIcon());
    await _tap(tester, find.text('Unut'));
    expect(gateway.forgotten, ['trusted-computer', 'trusted-computer']);
    expect(gateway.remembered, hasLength(1));
    expect(find.textContaining('Yeniden deneyin.'), findsNothing);
  });

  for (final throws in [false, true]) {
    testWidgets(
      'reconnect ${throws ? 'exception' : 'rejection'} keeps dialog open and allows retry',
      (tester) async {
        final gateway =
            _FakeGateway()
              ..reconnectResult = false
              ..reconnectError = throws ? StateError('untrusted peer') : null;
        final host = _Host();
        await host.open(tester, gateway);
        await _openAddress(tester);
        await _tap(tester, find.text(_connect));
        expect(
          find.textContaining(
            throws
                ? 'Cihaz do\u011frulanamad\u0131.'
                : 'Ba\u011flan\u0131lamad\u0131.',
          ),
          findsOneWidget,
        );
        expect(host.completed, isFalse);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
        expect(gateway.remembered, hasLength(2));
        gateway.reconnectError = null;
        gateway.reconnectResult = true;
        await _openAddress(tester);
        await _tap(tester, find.text(_connect));
        await tester.pumpAndSettle();
        expect(host.result, isTrue);
        expect(host.completed, isTrue);
        expect(gateway.reconnects, hasLength(2));
      },
    );
  }

  for (final outcome in ['ready', 'empty', 'error', 'cancel']) {
    testWidgets('device loading resolves to $outcome without side effects', (
      tester,
    ) async {
      final pending = Completer<List<Map<String, dynamic>>>();
      final gateway = _FakeGateway()..pendingRead = pending;
      final host = _Host();
      await host.open(tester, gateway, size: const Size(320, 640), scale: 2);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      _expectIdle(host, gateway);
      if (outcome == 'cancel') {
        await _tap(tester, find.text('Kapat'));
        expect(host.completed, isTrue);
        expect(host.result, isNull);
      }
      if (outcome == 'error') {
        pending.completeError(StateError('storage unavailable'));
      } else {
        pending.complete(outcome == 'empty' ? [] : gateway.remembered);
      }
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      if (outcome == 'ready') {
        expect(find.text(_deviceName), findsOneWidget);
      } else if (outcome == 'empty') {
        expect(find.textContaining('QR kod'), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
      } else if (outcome == 'error') {
        expect(
          find.textContaining('Kay\u0131tlar de\u011fi\u015ftirilmedi.'),
          findsOneWidget,
        );
        expect(find.byType(IconButton), findsNothing);
      }
      expect(gateway.reconnects, isEmpty);
      expect(gateway.forgotten, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'trusted devices and nested dialogs fit ${size.width} at scale $scale',
        (tester) async {
          final gateway = _FakeGateway()..reconnectResult = false;
          final host = _Host();
          await host.open(tester, gateway, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await _openAddress(tester);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField));
          await tester.pumpAndSettle();
          expect(find.byType(TextField).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(find.text(_connect).hitTestable(), findsOneWidget);
          await tester.enterText(find.byType(TextField), '192.168.1.222');
          tester.view.resetViewInsets();
          await _tap(tester, find.text(_connect));
          expect(tester.takeException(), isNull);
          expect(host.completed, isFalse);
          expect(
            find.textContaining('Ba\u011flan\u0131lamad\u0131.'),
            findsOneWidget,
          );
          await _tap(tester, _forgetIcon());
          expect(tester.takeException(), isNull);
          expect(find.text('Unut').hitTestable(), findsOneWidget);
          await _tap(tester, find.text(_cancel));
          expect(gateway.forgotten, isEmpty);
          expect(tester.takeException(), isNull);
          await _tap(tester, find.text('Kapat'));
          expect(host.completed, isTrue);
        },
      );
    }
  }
}
