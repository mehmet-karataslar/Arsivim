import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arsiv_uygulamasi/models/backup_overview.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/providers/backup_controller.dart';
import 'package:arsiv_uygulamasi/services/backup_repository.dart';
import 'package:arsiv_uygulamasi/services/yedekleme_servisi.dart';
import 'package:arsiv_uygulamasi/services/veritabani_servisi.dart';
import 'package:arsiv_uygulamasi/screens/yedekleme_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/backup/backup_summary.dart';

final date = DateTime(2026, 10, 21);
BackupOverview sample() => BackupOverview(
  [
    for (var i = 0; i < 4; i++)
      KisiModeli(
        id: i + 1,
        ad: ['Nejdet', 'Nesih', 'Mehmet', 'Özlem'][i],
        soyad: 'Karataş',
        olusturmaTarihi: date,
        guncellemeTarihi: date,
      ),
  ],
  [
    for (var i = 0; i < 8; i++)
      KategoriModeli(
        id: i + 1,
        kategoriAdi:
            [
              'Okul',
              'Resmi',
              'Kişisel',
              'Sağlık',
              'Finans',
              'Hukuki',
              'Ev',
              'Arşiv',
            ][i],
        olusturmaTarihi: date,
      ),
  ],
  [
    for (var i = 0; i < 8; i++)
      BelgeModeli(
        id: i + 1,
        dosyaAdi: 'belge-$i.pdf',
        orijinalDosyaAdi: 'belge-$i.pdf',
        dosyaYolu: 'unused',
        dosyaBoyutu: 1024 * (i + 1),
        dosyaTipi: 'pdf',
        dosyaHash: 'unused',
        kisiId: i % 4 + 1,
        kisiIds: i == 0 ? [1, 2] : [],
        kategoriId: i + 1,
        kategoriIds: i == 0 ? [1, 2] : [],
        olusturmaTarihi: date,
        guncellemeTarihi: date,
      ),
  ],
);

class FakeRepository extends BackupRepository {
  bool fail = false;
  int calls = 0;
  Completer<void>? completion;
  Map<int, List<int>>? lastCategories;
  @override
  Future<BackupOverview> load() async => sample();
  @override
  Future<BackupRecord> run(
    List<int> people,
    String path,
    Map<int, List<int>> categories,
    void Function(double, String) onProgress,
  ) async {
    calls++;
    lastCategories = categories;
    onProgress(.4, 'Kopyalanıyor');
    if (completion != null) await completion!.future;
    if (fail) throw StateError('Kaynak dosya bulunamadı');
    return BackupRecord(
      time: date,
      path: '$path/Arsiv-Yedek-test',
      people: people.length,
      categories: categories.values.expand((c) => c).toSet().length,
      documents: 8,
      bytes: 36864,
    );
  }
}

class MemoryDatabase implements VeriTabaniServisi {
  MemoryDatabase(this.data);
  final BackupOverview data;
  @override
  Future<List<KisiModeli>> kisileriGetir() async => data.people;
  @override
  Future<List<KategoriModeli>> kategorileriGetir() async => data.categories;
  @override
  Future<List<BelgeModeli>> kisiBelgeleriniGetir(int id) async =>
      data.documents.where((d) => d.tumKisiIds.contains(id)).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_BACKUP_PREVIEW')) {
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
    'Multi links counted once, physical copies estimated, deselection excludes documents',
    () async {
      final data = BackupController(FakeRepository());
      await data.load();
      data.togglePerson(2);
      expect(data.categoryCounts[1], 1); // Secondary person link.
      expect(data.documentCount, 3);
      data.togglePerson(1);
      expect(data.documentCount, 4);
      expect(data.estimatedBytes, 15 * 1024); // Shared file copied twice.
      for (final id in [...data.selectedCategories]) {
        data.toggleCategory(id);
      }
      data.setTarget('C:/Backups');
      expect(data.documentCount, 0);
      expect(data.canStart, false);
      data.toggleCategory(
        2,
      ); // Secondary category link still includes document 1.
      expect(data.documentCount, 2);
      expect(data.canStart, true);
      data.clear();
      expect(data.documentCount, 0);
      expect(data.selectedCategories, isEmpty);
      data.dispose();
    },
  );
  test(
    'Run locks selection, blocks duplicate clicks, stores result across controllers',
    () async {
      final repository = FakeRepository()..completion = Completer<void>();
      final data = BackupController(repository);
      await data.load();
      data.toggleAllPeople();
      data.setTarget('C:/Backups');
      final run = data.start();
      data.clear();
      data.togglePerson(1);
      data.setTarget(null);
      await data.start();
      expect(repository.calls, 1);
      expect(data.selectedPeople.length, 4);
      expect(data.target, 'C:/Backups');
      repository.completion!.complete();
      await run;
      expect(data.history.single.error, isNull);
      final another = BackupController(repository);
      await another.load();
      expect(another.history.single.path, endsWith('Arsiv-Yedek-test'));
      data.dispose();
      another.dispose();
    },
  );
  test(
    'Failure is recorded as failure and finishing after disposal is safe',
    () async {
      final repository =
          FakeRepository()
            ..fail = true
            ..completion = Completer<void>();
      final data = BackupController(repository);
      await data.load();
      data.toggleAllPeople();
      data.setTarget('C:/Backups');
      final run = data.start();
      data.dispose();
      repository.completion!.complete();
      await run;
      expect(
        (await repository.history()).single.error,
        contains('Kaynak dosya'),
      );
    },
  );
  test(
    'Service respects empty and secondary category filters and verifies written bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('backup-test-');
      addTearDown(() => root.delete(recursive: true));
      final content = [1, 2, 3, 4];
      final source = await File(
        '${root.path}/source.pdf',
      ).writeAsBytes(content);
      final output = await Directory('${root.path}/backups').create();
      final original = sample();
      final document = original.documents.first.copyWith(
        dosyaYolu: source.path,
        dosyaBoyutu: content.length,
        dosyaHash: sha256.convert(content).toString(),
      );
      final service = YedeklemeServisi(
        veriTabani: MemoryDatabase(
          BackupOverview(original.people, original.categories, [document]),
        ),
      );
      await expectLater(
        service.kisiVeKategoriYedeklemeYap(
          [2],
          output.path,
          kategoriSecimi: {2: []},
        ),
        throwsException,
      );
      expect(await output.list().toList(), isEmpty);
      final result = await service.kisiVeKategoriYedeklemeYap(
        [2],
        output.path,
        kategoriSecimi: {
          2: [2],
        },
      );
      expect(result.documents, 1);
      expect(result.bytes, 4);
      expect(result.categories, 1);
      final manifest = jsonDecode(
        await File('${result.path}/manifest.json').readAsString(),
      );
      expect(manifest['tamamlandi'], true);
      final row = manifest['belgeler'][0];
      expect(
        await File('${result.path}/${row['dosya_yolu']}').readAsBytes(),
        content,
      );
      expect(jsonDecode(row['kisi_ids']), [1, 2]);
      expect(jsonDecode(row['kategori_ids']), [1, 2]);
    },
  );
  for (final width in [800.0, 1100.0, 1672.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Backup layout $width text $scale and functional selection', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
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
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: Row(
                  children: [
                    if (width == 1672 && scale == 1)
                      AppSidebar(
                        selectedIndex: 6,
                        onSelected: (_) {},
                        summary: null,
                        onStorage: () {},
                        onLogout: () {},
                      ),
                    Expanded(
                      child: YedeklemeEkrani(
                        repository: FakeRepository(),
                        pickDirectory: () async => 'C:/Arşivim/Yedekler',
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
        await tester.ensureVisible(find.byKey(const ValueKey('backup-folder')));
        await tester.tap(find.byKey(const ValueKey('backup-folder')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tümünü Seç'));
        await tester.tap(find.text('Tümünü Seç'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('backup-start')))
              .onPressed,
          isNotNull,
        );
        if (const bool.fromEnvironment('CAPTURE_BACKUP_PREVIEW') &&
            width == 1672 &&
            scale == 1) {
          await tester.ensureVisible(find.byType(YedeklemeEkrani));
          await tester.pumpAndSettle();
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(YedeklemeEkrani),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scroll.position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/backup-1672.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byKey(const ValueKey('backup-start')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('backup-start')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BackupSummary),
            matching: find.text('Yedekleme tamamlandı'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
