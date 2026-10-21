import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/models/ana_sayfa_ozeti.dart';
import 'package:arsiv_uygulamasi/models/category_overview.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/screens/kategoriler_ekrani.dart';
import 'package:arsiv_uygulamasi/services/category_repository.dart';
import 'package:arsiv_uygulamasi/providers/categories_controller.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/common/metric_grid.dart';
import 'package:arsiv_uygulamasi/widgets/app_navigation_bar.dart';
import 'package:arsiv_uygulamasi/widgets/categories/category_mobile_filters.dart';
import 'package:arsiv_uygulamasi/widgets/categories/category_card.dart';

class FakeCategories extends CategoryRepository {
  int reads = 0, saves = 0;
  late List<CategoryEntry> entries = List.generate(8, (i) {
    final category = KategoriModeli.ontanimliKategoriler().firstWhere(
      (c) =>
          c.kategoriAdi ==
          [
            'Belgeler',
            'Ev',
            'Hastane',
            'Hukuki',
            'Kişisel',
            'Mali',
            'Müzik',
            'Hobi',
          ][i],
    );
    category.id = i + 1;
    category.belgeSayisi = [12, 12, 7, 6, 5, 8, 4, 6][i];
    category.olusturmaTarihi = DateTime.now().subtract(Duration(days: i));
    return CategoryEntry(
      category: category,
      updated: category.olusturmaTarihi,
      group:
          i == 3
              ? CategoryGroup.official
              : i == 0
              ? CategoryGroup.general
              : CategoryGroup.personal,
      favorite: [1, 2, 5].contains(i),
    );
  });
  @override
  Future<CategoryOverview> read() async {
    reads++;
    return CategoryOverview(entries, [
      for (final entry in entries)
        CategoryEvent(entry.category, 'kategorisi güncellendi', entry.updated),
    ]);
  }

  @override
  Future<void> favorite(CategoryEntry entry) async {
    entries =
        entries
            .map(
              (e) =>
                  e.category.id != entry.category.id
                      ? e
                      : CategoryEntry(
                        category: e.category,
                        updated: e.updated,
                        group: e.group,
                        favorite: !e.favorite,
                      ),
            )
            .toList();
  }

  @override
  Future<void> save(KategoriModeli category, CategoryGroup group) async {
    saves++;
    category.id ??= entries.length + 1;
    entries = [
      ...entries.where((e) => e.category.id != category.id),
      CategoryEntry(category: category, updated: DateTime.now(), group: group),
    ];
  }
}

class DelayedCategories extends FakeCategories {
  Completer<CategoryOverview>? pending;
  @override
  Future<CategoryOverview> read() => pending?.future ?? super.read();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Yenileme sırasında yıldız değişikliği eski sonuçla kaybolmaz',
    () async {
      final repository = DelayedCategories();
      final controller = CategoriesController(repository);
      await controller.refresh();
      final pending = Completer<CategoryOverview>();
      repository.pending = pending;
      final snapshot = CategoryOverview([...repository.entries], []);
      final refresh = controller.refresh();
      final change = controller.favorite(controller.overview!.entries.first);
      repository.pending = null;
      pending.complete(snapshot);
      await Future.wait([refresh, change]);
      expect(controller.overview!.entries.first.favorite, true);
      controller.dispose();
    },
  );
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_CATEGORIES_PREVIEW') &&
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
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1672.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Kategoriler $width px / yazı $scale', (tester) async {
        tester.view.physicalSize = Size(width, 941);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FakeCategories();
        final boundary = GlobalKey();
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
              key: boundary,
              child: Scaffold(
                appBar:
                    width < 600
                        ? AppBar(
                          centerTitle: true,
                          title: const Text(
                            'Kategoriler',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        : null,
                bottomNavigationBar:
                    width < 600
                        ? AppNavigationBar(selectedIndex: 2, onSelected: (_) {})
                        : null,
                body: Row(
                  children: [
                    if (width >= 1100 && scale == 1)
                      AppSidebar(
                        selectedIndex: 2,
                        onSelected: (_) {},
                        summary: const AnaSayfaOzeti(
                          belgeSayisi: 60,
                          dosyaBoyutu: 7549747,
                          sonBelgeler: [],
                        ),
                        onStorage: () {},
                        onLogout: () {},
                      ),
                    Expanded(
                      child: KategorilerEkrani(
                        repository: repository,
                        showHeading: width >= 600,
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
        if (width >= 600) {
          final metrics = find.byType(MetricCard);
          if (metrics.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.byWidgetPredicate(
                (w) => w is MetricCard && w.data.label == 'Toplam kategori',
              ),
              300,
              scrollable:
                  find
                      .descendant(
                        of: find.byType(CustomScrollView),
                        matching: find.byType(Scrollable),
                      )
                      .first,
            );
            await tester.pumpAndSettle();
          }
          expect(
            tester.getTopLeft(metrics.at(0)).dy,
            tester.getTopLeft(metrics.at(1)).dy,
          );
          expect(
            tester.getTopLeft(metrics.at(1)).dx,
            greaterThan(tester.getTopLeft(metrics.at(0)).dx),
          );
        } else {
          expect(find.byType(MetricCard), findsNothing);
          expect(find.byTooltip('Kategori ekle'), findsOneWidget);
        }
        if (const bool.fromEnvironment('CAPTURE_CATEGORIES_PREVIEW') &&
            scale == 1 &&
            (width == 1672 || width == 390)) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('artifacts/categories').create(recursive: true);
            await File(
              'artifacts/categories/kategoriler-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final first = find.byWidgetPredicate(
          (w) => w is CategoryCard && w.entry.category.id == 1,
        );
        await tester.scrollUntilVisible(
          first,
          350,
          scrollable:
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final second = find.byWidgetPredicate(
          (w) => w is CategoryCard && w.entry.category.id == 2,
        );
        if (width < 600) {
          expect(tester.getRect(first).left, 0);
          expect(tester.getRect(second).right, width);
          final actions = find.descendant(
            of: first,
            matching: find.byKey(const ValueKey('category-actions')),
          );
          final otherActions = find.descendant(
            of: second,
            matching: find.byKey(const ValueKey('category-actions')),
          );
          expect(
            tester.getTopLeft(actions).dy,
            tester.getTopLeft(otherActions).dy,
          );
          final buttons = [
            for (final label in ['Aç', 'Düzenle', 'Kategori seçenekleri'])
              find.descendant(of: actions, matching: find.byTooltip(label)),
          ];
          for (final button in buttons) {
            expect(
              tester.getTopLeft(button).dy,
              tester.getTopLeft(buttons.first).dy,
            );
          }
        }
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(
          tester.getTopLeft(second).dx,
          greaterThan(tester.getTopLeft(first).dx),
        );
      });
    }
  }

  testWidgets(
    'Mobil kategori filtresi, sıralama, görünüm ve ekleme erişilebilir',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeCategories();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: Scaffold(body: KategorilerEkrani(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryMobileFilters), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('Tüm kategoriler (8)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sık kullanılanlar (3)').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CategoryCard>(find.byType(CategoryCard))
            .every((card) => card.entry.favorite),
        isTrue,
      );
      await tester.tap(find.byTooltip('Liste görünümü'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kart görünümü'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtreleri kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryMobileFilters), findsNothing);
      await tester.tap(find.byTooltip('Kategori ekle'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Kategori adı'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [844.0, 1200.0]) {
    testWidgets('Kategoriler kısa yatay ekran $width', (tester) async {
      tester.view.physicalSize = Size(width, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: Scaffold(body: KategorilerEkrani(repository: FakeCategories())),
        ),
      );
      await tester.pumpAndSettle();
      if (width < 1100) expect(find.byType(MetricCard), findsNothing);
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (widget) => widget is CategoryCard && widget.entry.category.id == 1,
        ),
        250,
        scrollable:
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Yıldız, arama, kategori ekleme ve açma çalışır', (tester) async {
    tester.view.physicalSize = const Size(1672, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeCategories();
    final opened = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        home: Scaffold(
          body: KategorilerEkrani(
            repository: repository,
            onOpenCategory: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byWidgetPredicate(
      (w) => w is CategoryCard && w.entry.category.id == 1,
    );
    await tester.tap(
      find.descendant(
        of: first,
        matching: find.byTooltip('Sık kullanılanlara ekle'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.entries.first.favorite, true);
    await tester.tap(find.descendant(of: first, matching: find.text('Aç')));
    expect(opened, [1]);
    await tester.enterText(find.byType(TextField), 'olmayan kategori');
    await tester.pumpAndSettle();
    expect(find.text('Bu filtreye uygun kategori bulunamadı.'), findsOneWidget);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategori ekle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('En az iki karakter girin.'), findsOneWidget);
    expect(repository.saves, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kategori adı'),
      'Yeni kategori',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(repository.entries.length, 9);
    expect(tester.takeException(), isNull);
  });
}
