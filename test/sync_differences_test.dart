import 'dart:async';
import 'dart:io';

import 'package:arsiv_uygulamasi/models/sync_comparison.dart';
import 'package:arsiv_uygulamasi/models/sync_overview.dart';
import 'package:arsiv_uygulamasi/screens/senkronizasyon_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/sync/sync_direction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_test.dart' show FakeSyncGateway, FakeSyncRepository;

const _button = ValueKey('sync-show-differences');
const _device = SyncDevice(
  id: 'phone',
  name: 'Samsung phone',
  ip: '192.168.88.121',
);

Map<String, dynamic> _saved(String id) => {
  'trust_id': 'trust-$id',
  'device_id': id,
  'device_name': '$id archive',
  'last_ip': id == 'phone' ? '192.168.88.121' : '192.168.88.122',
  'platform': 'Android',
};

class _Gateway extends FakeSyncGateway {
  _Gateway() {
    devices = [];
  }
  List<Map<String, dynamic>> saved = [_saved('phone')];
  final reconnects = <(String, String)>[];
  final compared = <SyncDevice>[];
  final selectedTransfers = <List<int>>[];
  Completer<bool>? connecting;
  bool accepted = true;
  bool wrongIdentity = false;
  bool failLookup = false;

  @override
  String? get connectionError =>
      'Cihaz doğrulanamadı. Ağ adresini kontrol edin.';
  @override
  Future<List<Map<String, dynamic>>> trustedDevices() async {
    if (failLookup) throw StateError('Cihaz listesi okunamadı.');
    return saved;
  }

  @override
  Future<bool> reconnect(String trustId, String address) async {
    reconnects.add((trustId, address));
    final success = connecting != null ? await connecting!.future : accepted;
    if (success) {
      final entry = saved.singleWhere((row) => row['trust_id'] == trustId);
      devices = [
        SyncDevice(
          id: wrongIdentity ? 'different-device' : entry['device_id'] as String,
          name: entry['device_name'] as String,
          ip: address,
        ),
      ];
      changes.value++;
    }
    return success;
  }

  @override
  Future<SyncComparison> compare(SyncDevice device) async {
    compared.add(device);
    return const SyncComparison(sendIds: [11], receiveIds: [21], same: 10);
  }

  @override
  Future<bool> sendIds(SyncDevice device, List<int> ids) async {
    selectedTransfers.add(ids);
    return true;
  }

  @override
  Future<bool> receive(SyncDevice device, List<int> ids) async {
    selectedTransfers.add(ids);
    return true;
  }
}

void _dispose(_Gateway gateway) {
  gateway.changes.dispose();
  unawaited(gateway.updates.close());
}

Future<void> _mount(
  WidgetTester tester,
  _Gateway gateway, {
  Size size = const Size(1440, 1000),
  double scale = 1,
  bool mobile = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    _dispose(gateway);
  });
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
        body: SenkronizasyonEkrani(
          repository: FakeSyncRepository(),
          gateway: gateway,
          mobileDevice: mobile,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noTransfer(_Gateway gateway) {
  expect(gateway.sent, isEmpty);
  expect(gateway.selectedTransfers, isEmpty);
}

void main() {
  test(
    'Stale connected entries require a verified reconnect before comparing',
    () async {
      final gateway =
          _Gateway()
            ..devices = [_device]
            ..connectionAlive = false;
      addTearDown(() => _dispose(gateway));
      final target = (await gateway.comparisonTargets()).single;
      final connected = await gateway.prepareComparison(target);
      expect(gateway.connectionChecks, 1);
      expect(gateway.reconnects, [('trust-phone', _device.ip)]);
      expect(connected.id, _device.id);
      _noTransfer(gateway);
    },
  );

  test(
    'A stale connection and failed reconnect never become a successful comparison',
    () async {
      final gateway =
          _Gateway()
            ..devices = [_device]
            ..connectionAlive = false
            ..accepted = false;
      addTearDown(() => _dispose(gateway));
      final target = (await gateway.comparisonTargets()).single;
      await expectLater(gateway.prepareComparison(target), throwsStateError);
      expect(gateway.connectionChecks, 1);
      expect(gateway.compared, isEmpty);
      _noTransfer(gateway);
    },
  );
  final capture = Platform.environment['ARSIV_CAPTURE_PREVIEWS'] == '1';
  if (capture) {
    setUpAll(() async {
      final font = FontLoader('Roboto');
      font.addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 390),
    const Size(1024, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('mobile roles and layout $size scale=$scale', (tester) async {
        final gateway = _Gateway()..devices = [_device];
        await _mount(tester, gateway, size: size, scale: scale, mobile: true);
        expect(find.byKey(const ValueKey('sync-pair-device')), findsNothing);
        expect(find.byKey(const ValueKey('sync-server-button')), findsNothing);
        expect(find.text('QR kodu aç'), findsNothing);
        expect(find.text('Yeni cihaz eşleştir'), findsNothing);
        expect(find.text('Tümünü senkron et'), findsNothing);
        expect(find.byKey(const ValueKey('sync-mobile-scan')), findsOneWidget);
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.byKey(const ValueKey('sync-mobile-scan')),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byKey(_button), findsOneWidget);
        expect(
          find.byKey(const ValueKey('sync-mobile-listener')),
          findsOneWidget,
        );
        expect(find.text('Telefonda bekleyen'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (capture && size == const Size(390, 844) && scale == 1) {
          await expectLater(
            find.byType(SenkronizasyonEkrani),
            matchesGoldenFile('../build/sync_preview/mobile-page.png'),
          );
        }
        final settings = find.byKey(const ValueKey('sync-mobile-settings'));
        await tester.ensureVisible(settings);
        await tester.tap(settings);
        await tester.pumpAndSettle();
        final access = find.widgetWithText(
          SwitchListTile,
          'Bu telefonu bağlantılara aç',
        );
        await tester.ensureVisible(access);
        await tester.tap(access);
        await tester.pumpAndSettle();
        expect(gateway.toggles, 1);
        expect(gateway.running, isFalse);
        expect(tester.takeException(), isNull);
        _noTransfer(gateway);
      });
    }
  }

  testWidgets(
    'mobile differences opens phone comparison without QR or auto-transfer',
    (tester) async {
      final gateway = _Gateway();
      await _mount(tester, gateway, size: const Size(390, 844), mobile: true);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(gateway.reconnects.length, 1);
      expect(find.byType(SyncDirectionDialog), findsOneWidget);
      expect(find.text('Bu telefon: 1 yeni belge'), findsOneWidget);
      _noTransfer(gateway);
    },
  );

  testWidgets(
    'desktop retains QR display and server controls beside differences',
    (tester) async {
      final gateway = _Gateway()..devices = [_device];
      await _mount(tester, gateway);
      expect(find.byKey(const ValueKey('sync-pair-device')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-server-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-mobile-scan')), findsNothing);
      expect(find.byKey(_button), findsOneWidget);
      if (capture) {
        await expectLater(
          find.byType(SenkronizasyonEkrani),
          matchesGoldenFile('../build/sync_preview/desktop-page.png'),
        );
      }
      expect(tester.takeException(), isNull);
      _noTransfer(gateway);
    },
  );

  testWidgets(
    'mobile keeps stop accessible and disables connection actions during transfer',
    (tester) async {
      final gateway = _Gateway();
      await _mount(tester, gateway, size: const Size(390, 844), mobile: true);
      gateway.transferring = true;
      gateway.changes.value++;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(_button)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('sync-mobile-scan')),
            )
            .onPressed,
        isNull,
      );
      final stop = find.byKey(const ValueKey('sync-mobile-stop'));
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pump();
      expect(gateway.stopped, isTrue);
      gateway.transferring = false;
      gateway.changes.value++;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'targets merge saved and connected devices by ID, retaining live address',
    () async {
      final gateway = _Gateway()..saved.add(_saved('pc'));
      addTearDown(() => _dispose(gateway));
      gateway.devices = [
        const SyncDevice(id: 'phone', name: 'Live phone', ip: '192.168.88.130'),
      ];
      final targets = await gateway.comparisonTargets();
      expect(targets.length, 2);
      final phone = targets.singleWhere((t) => t.device.id == 'phone');
      expect(phone.connected, isTrue);
      expect(phone.device.ip, '192.168.88.130');
      expect(phone.trustId, 'trust-phone');
      expect(
        await gateway.prepareComparison(phone),
        same(gateway.devices.single),
      );
      expect(gateway.reconnects, isEmpty);
      _noTransfer(gateway);
    },
  );

  test(
    'successful reconnect must expose the expected authenticated identity',
    () async {
      final gateway = _Gateway()..wrongIdentity = true;
      addTearDown(() => _dispose(gateway));
      final target = (await gateway.comparisonTargets()).single;
      await expectLater(gateway.prepareComparison(target), throwsStateError);
      expect(gateway.compared, isEmpty);
      _noTransfer(gateway);
    },
  );

  test(
    'missing address and active transfer fail before reconnecting',
    () async {
      final gateway = _Gateway();
      addTearDown(() => _dispose(gateway));
      gateway.saved.single['last_ip'] = '';
      final target = (await gateway.comparisonTargets()).single;
      await expectLater(gateway.prepareComparison(target), throwsStateError);
      gateway.transferring = true;
      await expectLater(
        gateway.prepareComparison(
          const SyncComparisonTarget(device: _device, trustId: 'trust-phone'),
        ),
        throwsStateError,
      );
      expect(gateway.reconnects, isEmpty);
    },
  );

  for (final connected in [false, true]) {
    testWidgets(
      'one click compares without transfer; already connected=$connected',
      (tester) async {
        final gateway = _Gateway();
        if (connected) gateway.devices = [_device];
        await _mount(tester, gateway);
        await tester.tap(find.byKey(_button));
        await tester.pumpAndSettle();
        expect(find.byType(SyncDirectionDialog), findsOneWidget);
        expect(gateway.compared.single.id, 'phone');
        expect(gateway.reconnects.length, connected ? 0 : 1);
        _noTransfer(gateway);
        await tester.tap(find.text('Şimdi değil'));
        await tester.pumpAndSettle();
        gateway.changes.value++;
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(SyncDirectionDialog), findsNothing);
        expect(gateway.compared.length, 1);
        _noTransfer(gateway);
      },
    );
  }

  testWidgets('explicit direction is still required to start sending', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _mount(tester, gateway);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    _noTransfer(gateway);
    await tester.tap(find.byKey(const ValueKey('sync-direction-send')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(gateway.selectedTransfers, [
      [11],
    ]);
    expect(gateway.sent, isEmpty);
  });

  testWidgets('double click cannot start two reconnects or duplicate dialogs', (
    tester,
  ) async {
    final gateway = _Gateway()..connecting = Completer<bool>();
    await _mount(tester, gateway);
    final callback =
        tester.widget<ButtonStyleButton>(find.byKey(_button)).onPressed!;
    callback();
    callback();
    await tester.pump(const Duration(milliseconds: 300));
    expect(gateway.reconnects.length, 1);
    expect(
      tester.widget<ButtonStyleButton>(find.byKey(_button)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const ValueKey('sync-server-button')),
          )
          .onPressed,
      isNull,
    );
    gateway.connecting!.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(SyncDirectionDialog), findsOneWidget);
    expect(gateway.compared.length, 1);
    _noTransfer(gateway);
  });

  for (final choose in [false, true]) {
    testWidgets('multiple devices require selection, choose=$choose', (
      tester,
    ) async {
      final gateway = _Gateway()..saved.add(_saved('pc'));
      await _mount(tester, gateway, size: const Size(320, 640), scale: 2);
      await tester.ensureVisible(find.byKey(_button));
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.text('Karşılaştırılacak cihaz'), findsOneWidget);
      expect(gateway.reconnects, isEmpty);
      expect(tester.takeException(), isNull);
      if (choose) {
        final target = find.byKey(const ValueKey('sync-difference-target-pc'));
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable:
              find
                  .descendant(
                    of: find.byKey(const ValueKey('sync-target-picker')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(gateway.reconnects.single.$1, 'trust-pc');
        expect(gateway.compared.single.id, 'pc');
      } else {
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(gateway.reconnects, isEmpty);
        expect(gateway.compared, isEmpty);
      }
      _noTransfer(gateway);
      expect(tester.takeException(), isNull);
    });
  }

  for (final failure in ['empty', 'lookup', 'reconnect']) {
    testWidgets('$failure leaves data untouched and permits retry', (
      tester,
    ) async {
      final gateway = _Gateway();
      if (failure == 'empty') gateway.saved = [];
      if (failure == 'lookup') gateway.failLookup = true;
      if (failure == 'reconnect') gateway.accepted = false;
      await _mount(tester, gateway);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.byType(SyncDirectionDialog), findsNothing);
      expect(gateway.compared, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      _noTransfer(gateway);
      gateway.saved = [_saved('phone')];
      gateway.failLookup = false;
      gateway.accepted = true;
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.byType(SyncDirectionDialog), findsOneWidget);
      expect(gateway.compared.length, 1);
      _noTransfer(gateway);
    });
  }

  testWidgets(
    'leaving during reconnect cannot open a dialog on another screen',
    (tester) async {
      final gateway = _Gateway()..connecting = Completer<bool>();
      await _mount(tester, gateway);
      await tester.tap(find.byKey(_button));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const MaterialApp(home: Text('Another screen')));
      gateway.connecting!.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(SyncDirectionDialog), findsNothing);
      expect(gateway.compared, isEmpty);
      expect(tester.takeException(), isNull);
      _noTransfer(gateway);
    },
  );
}
