import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/models/sync_overview.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/providers/sync_controller.dart';
import 'package:arsiv_uygulamasi/services/sync_gateway.dart';
import 'package:arsiv_uygulamasi/services/sync_repository.dart';
import 'package:arsiv_uygulamasi/screens/senkronizasyon_ekrani.dart';
import 'package:arsiv_uygulamasi/widgets/sync/sync_devices.dart';
import 'package:arsiv_uygulamasi/widgets/senkronizasyon_progress_dialog.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/app_navigation_bar.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';

class FakeSyncRepository extends SyncRepository {
  int reads = 0;
  bool fail = false;
  @override
  Future<SyncOverview> read({DateTime? now}) async {
    reads++;
    if (fail) throw StateError('offline');
    return SyncOverview(
      total: 362,
      pending: 50,
      synced: 312,
      today: 18,
      lastBackup: DateTime(2026, 10, 21),
      lastTransfer: DateTime(2026, 10, 21, 19, 47),
      events: [
        for (var i = 0; i < 5; i++)
          SyncEvent(
            'Aile_belgeleri_ve_çok_uzun_bir_başlık_$i.pdf',
            i == 3 ? 'hata' : 'gonderildi',
            DateTime(2026, 10, 21, 19, 47 - i),
            message: i == 3 ? 'Bağlantı kesildi' : null,
          ),
      ],
    );
  }

  @override
  Future<List<BelgeModeli>> pendingDocuments() async => [];
}

class FakeSyncGateway extends SyncGateway {
  @override
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  @override
  void initialize() {}
  @override
  bool running = true;
  @override
  bool transferring = false;
  @override
  bool autoDisconnect = true;
  @override
  DateTime? get startedAt => DateTime.now().subtract(const Duration(hours: 2));
  @override
  List<SyncDevice> devices = [
    SyncDevice(
      id: 'a',
      name: 'iPhone 14',
      ip: '192.168.1.105',
      platform: 'iOS',
      connectedAt: DateTime(2026, 10, 21, 19, 30),
    ),
    SyncDevice(
      id: 'b',
      name: "Ahmet’in Bilgisayarı",
      ip: '192.168.1.102',
      platform: 'Windows',
      connectedAt: DateTime(2026, 10, 21, 19, 10),
    ),
  ];
  @override
  Future<String> address() async => '192.168.1.100';
  bool connectionAlive = true;
  int connectionChecks = 0;
  @override
  Future<bool> verifyConnection(SyncDevice device) async {
    connectionChecks++;
    if (!connectionAlive)
      devices = devices.where((d) => d.id != device.id).toList();
    return connectionAlive;
  }

  int toggles = 0;
  @override
  Future<void> setServer(bool value) async {
    toggles++;
    running = value;
    changes.value++;
  }

  final sent = <String>[];
  Completer<bool>? waiting;
  bool stopped = false;
  @override
  int stopVersion = 0;
  final updates = StreamController<SenkronizasyonIlerleme>.broadcast();
  @override
  Stream<SenkronizasyonIlerleme> progress() => updates.stream;
  @override
  Future<bool> send(SyncDevice device, {List<BelgeModeli>? documents}) async {
    sent.add(device.id);
    transferring = true;
    try {
      if (waiting != null) return await waiting!.future;
      return true;
    } finally {
      transferring = false;
    }
  }

  @override
  void stop() {
    stopped = true;
    stopVersion++;
    waiting?.complete(false);
  }

  @override
  Future<bool> disconnect(String id) async {
    devices = devices.where((d) => d.id != id).toList();
    changes.value++;
    return true;
  }
}

class PairingGateway extends FakeSyncGateway {
  int created = 0;
  String? current;
  bool valid = true;
  bool networkChanged = false;
  @override
  Future<bool> canReuseQr(String code) async =>
      isQrValid(code) && !networkChanged;
  @override
  bool isQrValid(String code) => running && valid && code == current;
  @override
  Future<String> createQr() async {
    created++;
    valid = true;
    networkChanged = false;
    running = true;
    return current = jsonEncode({
      'pair_ticket': 'ticket-$created',
      'pair_expires':
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_SYNC_PREVIEW') &&
        Platform.isWindows) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test(
    'Seçili cihaz aktarımı, boş hızlı aktarım ve durdurma sırayı korur',
    () async {
      final gateway = FakeSyncGateway();
      final data = SyncController(FakeSyncRepository(), gateway);
      await data.refresh();
      data.select('b', true);
      await data.transfer(SyncMode.selected, data.targets(SyncMode.selected));
      expect(gateway.sent, ['b']);
      await data.transfer(SyncMode.pending, data.targets(SyncMode.pending));
      expect(gateway.sent, ['b']);
      gateway.waiting = Completer<bool>();
      final transfer = data.transfer(SyncMode.all, data.targets(SyncMode.all));
      await Future<void>.delayed(Duration.zero);
      data.stop();
      await transfer;
      expect(gateway.sent, ['b', 'a']);
      expect(gateway.stopped, true);
      expect(data.actionMessage, contains('durduruldu'));
      data.dispose();
      await gateway.updates.close();
    },
  );
  test(
    'Yenileme paylaşılır; hata son veriyi silmez; arama sorgu başlatmaz',
    () async {
      final repo = FakeSyncRepository();
      final gateway = FakeSyncGateway();
      final data = SyncController(repo, gateway);
      await Future.wait([data.refresh(), data.refresh()]);
      expect(repo.reads, 1);
      data.search('192.168.1.105');
      expect(data.visibleDevices.single.id, 'a');
      expect(repo.reads, 1);
      repo.fail = true;
      await data.refresh();
      expect(data.error, isNotNull);
      expect(data.overview!.total, 362);
      data.dispose();
      await gateway.updates.close();
    },
  );
  test(
    'Sayfaya dönüldüğünde devam eden aktarım durdurulur, sıradaki cihaz başlamaz',
    () async {
      final gateway = FakeSyncGateway()..waiting = Completer<bool>();
      final first = SyncController(FakeSyncRepository(), gateway);
      final transfer = first.transfer(
        SyncMode.all,
        first.targets(SyncMode.all),
      );
      await Future<void>.delayed(Duration.zero);
      first.dispose();
      final next = SyncController(FakeSyncRepository(), gateway);
      next.stop();
      await transfer;
      expect(gateway.sent, ['a']);
      expect(gateway.stopped, isTrue);
      next.dispose();
      await gateway.updates.close();
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1672.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Senkronizasyon $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeSyncRepository();
        final gateway = FakeSyncGateway();
        final boundary = GlobalKey();
        final desktop = width >= 1100 && scale == 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.forPalette(AppPalette.forest),
            builder:
                (ctx, child) => MediaQuery(
                  data: MediaQuery.of(
                    ctx,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                appBar:
                    desktop
                        ? null
                        : AppBar(
                          centerTitle: true,
                          title: const Text('Senkronizasyon'),
                        ),
                bottomNavigationBar:
                    desktop
                        ? null
                        : AppNavigationBar(
                          selectedIndex: 3,
                          onSelected: (_) {},
                        ),
                body: Row(
                  children: [
                    if (desktop)
                      AppSidebar(
                        summary: null,
                        selectedIndex: 3,
                        onSelected: (_) {},
                        onStorage: () {},
                        onLogout: () {},
                      ),
                    Expanded(
                      child: SenkronizasyonEkrani(
                        showHeading: desktop,
                        repository: repo,
                        gateway: gateway,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repo.reads, 1);
        if (const bool.fromEnvironment('CAPTURE_SYNC_PREVIEW') &&
            scale == 1 &&
            [390.0, 1672.0].contains(width)) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('artifacts/sync').create(recursive: true);
            await File(
              'artifacts/sync/sync-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -2200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await gateway.updates.close();
      });
    }
  }
  testWidgets(
    'Sunucu düğmesi gerçek geçide gider; cihaz seçimi aktarım onayına yansır',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeSyncGateway();
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
      await tester.tap(find.byKey(const ValueKey('sync-server-button')));
      await tester.pumpAndSettle();
      expect(gateway.running, false);
      expect(gateway.toggles, 1);
      await tester.tap(find.text('iPhone 14'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Senkronizasyonu başlat'));
      await tester.pumpAndSettle();
      expect(find.textContaining('iPhone 14').last, findsOneWidget);
      await tester.tap(find.text('Gönder'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(gateway.sent, ['a']);
      await tester.pumpWidget(const SizedBox());
      await gateway.updates.close();
    },
  );
  testWidgets(
    'QR yeniden açma aynı kodu ve doğrulamayı kullanır, geçersiz kod yenilenir',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = PairingGateway();
      var verified = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SenkronizasyonEkrani(
              repository: FakeSyncRepository(),
              gateway: gateway,
              verifyPairing: (_) async {
                verified++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('sync-pair-device'));
      expect(find.text('Tam ekran QR'), findsNothing);
      expect(find.text('Yeni cihaz bağla'), findsNothing);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(verified, 1);
      expect(gateway.created, 1);
      final first = gateway.current;
      expect(find.text('Cihaz bağlantı QR kodu'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(verified, 1);
      expect(gateway.created, 1);
      expect(gateway.current, first);
      // A used/revoked ticket must disappear and cannot be reused.
      gateway.valid = false;
      gateway.changes.value++;
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bu QR kod artık geçerli değil'),
        findsOneWidget,
      );
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(verified, 2);
      expect(gateway.created, 2);
      expect(gateway.current, isNot(first));
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('sync-server-button')),
      );
      await tester.tap(find.byKey(const ValueKey('sync-server-button')));
      await tester.pumpAndSettle();
      expect(gateway.running, false);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(verified, 3);
      expect(gateway.created, 3);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      gateway.networkChanged = true;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(gateway.created, 4);
      expect(verified, 4);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await gateway.updates.close();
    },
  );
  testWidgets(
    'İptal edilen doğrulama kod üretmez; çift tıklama ikinci pencere açmaz',
    (tester) async {
      final gateway = PairingGateway();
      final approval = Completer<bool>();
      var verified = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SenkronizasyonEkrani(
              repository: FakeSyncRepository(),
              gateway: gateway,
              verifyPairing: (_) {
                verified++;
                return approval.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('sync-pair-device'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(verified, 1);
      approval.complete(false);
      await tester.pumpAndSettle();
      expect(gateway.created, 0);
      expect(find.text('Cihaz bağlantı QR kodu'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await gateway.updates.close();
    },
  );
  testWidgets('QR penceresi dar ekranda büyük yazıyla açılır', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = PairingGateway();
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(
          body: SenkronizasyonEkrani(
            repository: FakeSyncRepository(),
            gateway: gateway,
            verifyPairing: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('sync-pair-device'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Cihaz bağlantı QR kodu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await gateway.updates.close();
  });
  testWidgets('Eşleştirme QR kodu süresi dolunca kaldırılır', (tester) async {
    final data = jsonEncode({
      'pair_expires': DateTime.now().millisecondsSinceEpoch + 1000,
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SyncPairingCode(data: data))),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Cihaz eşleştirme QR kodu',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Cihaz eşleştirme QR kodu',
      ),
      findsNothing,
    );
    expect(find.textContaining('Kodun süresi doldu'), findsOneWidget);
  });
}
