import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arsiv_uygulamasi/models/ana_sayfa_ozeti.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/providers/theme_controller.dart';
import 'package:arsiv_uygulamasi/screens/ana_ekran.dart';
import 'package:arsiv_uygulamasi/screens/profil_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_card.dart';
import 'package:arsiv_uygulamasi/widgets/common/document_tile.dart';
import 'package:arsiv_uygulamasi/widgets/common/metric_grid.dart';
import 'package:arsiv_uygulamasi/widgets/home/home_content.dart';
import 'package:arsiv_uygulamasi/widgets/home/home_actions.dart';
import 'package:arsiv_uygulamasi/widgets/home/recent_documents.dart';
import 'package:arsiv_uygulamasi/widgets/home/storage_info_dialog.dart';

AnaSayfaOzeti sample({bool empty = false}) => AnaSayfaOzeti(
  belgeSayisi: empty ? 0 : 128,
  dosyaBoyutu: empty ? 0 : 43515904,
  kategoriSayisi: empty ? 0 : 4,
  turBoyutlari: empty ? const {} : const {'documents': 43515904},
  sonBelgeler:
      empty
          ? []
          : List.generate(
            5,
            (index) => SonBelgeOzeti(
              belge: BelgeModeli(
                id: index + 1,
                dosyaAdi: 'ornek-$index.pdf',
                orijinalDosyaAdi: 'Ornek-belge-$index.pdf',
                dosyaYolu: 'unused',
                dosyaBoyutu: 1572864,
                dosyaTipi: 'pdf',
                dosyaHash: 'sample-$index',
                baslik:
                    index == 0
                        ? 'Örnek belge: uzun başlıkların dar pencerede okunabilirliği ve yerleşim kontrolü'
                        : [
                          '',
                          'Elektrik faturası',
                          'Konut sigorta poliçesi',
                          'Bakım ve servis kayıtları',
                          'Eğitim belgeleri',
                        ][index],
                etiketler: index == 0 ? ['örnek', 'arşiv'] : null,
                olusturmaTarihi: DateTime(2026, 10, 21),
                guncellemeTarihi: DateTime(2026, 10, 21),
              ),
              kategori:
                  index == 0
                      ? 'Uzun kategori adı ve açıklaması'
                      : 'Kişisel belgeler',
              kisi: 'Örnek Kullanıcı',
            ),
          ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_HOME_PREVIEW') &&
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
      testWidgets('Ana sayfa: $width px, yazı $scale, uzun belge başlıkları', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
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
              key: boundaryKey,
              child: AnaEkran(loadSummary: () async => sample()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(
          width < 600
              ? find.byTooltip('Yeni belge ekle')
              : find.text('Yeni belge ekle'),
          findsOneWidget,
        );
        final metrics = find.byType(MetricCard);
        if (width >= 600) {
          expect(
            tester.getTopLeft(metrics.at(0)).dy,
            tester.getTopLeft(metrics.at(1)).dy,
          );
        } else {
          expect(metrics, findsNothing);
          expect(find.byType(HomeActions), findsNothing);
        }
        if (width < 600) {
          final pageTitle = find.byKey(const ValueKey('mobile-page-title'));
          expect(tester.getCenter(pageTitle).dx, closeTo(width / 2, 1));
          expect(tester.getTopLeft(pageTitle).dy, lessThan(60));
          expect(find.byType(Drawer), findsNothing);
          expect(find.byKey(const ValueKey('navigation-6')), findsNothing);
          for (final index in [0, 1, 2, 4, 3, 5]) {
            expect(find.byKey(ValueKey('navigation-$index')), findsOneWidget);
          }
          if (const bool.fromEnvironment('CAPTURE_HOME_PREVIEW') &&
              scale == 1) {
            final lastTab = find.byKey(const ValueKey('navigation-5'));
            expect(
              tester.getRect(lastTab).right,
              lessThanOrEqualTo(width + 0.1),
            );
          }
          final tile = find.byType(DocumentTile).first;
          expect(tester.getRect(tile).left, 0);
          expect(tester.getRect(tile).right, width);
          expect(
            find.ancestor(of: tile, matching: find.byType(AppCard)),
            findsNothing,
          );
        }
        await tester.ensureVisible(find.text('Eğitim belgeleri'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_HOME_PREVIEW') &&
            scale == 1 &&
            (width == 320 || width == 390 || width == 1440 || width == 1672)) {
          final scrollable = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(HomeContent),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scrollable.position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('artifacts/home').create(recursive: true);
            await File(
              'artifacts/home/ana-sayfa-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }

  testWidgets(
    'Yenileme içeriği korur, paralel sorgu açmaz, hata sonrası tekrar denenir',
    (tester) async {
      var calls = 0;
      final pending = Completer<AnaSayfaOzeti>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: AnaEkran(
            loadSummary: () {
              calls++;
              return calls == 1
                  ? Future.value(sample())
                  : calls == 2
                  ? pending.future
                  : Future.value(sample(empty: true));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final refresh =
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh;
      final first = refresh();
      final second = refresh();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('128'), findsOneWidget);
      pending.completeError(StateError('offline'));
      await Future.wait([first, second]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Son yüklenen bilgiler'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      await tester.ensureVisible(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Henüz belge eklenmemiş'), findsOneWidget);
    },
  );

  testWidgets('İlk yükleme hatası boş arşiv gibi gösterilmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        home: AnaEkran(loadSummary: () async => throw StateError('offline')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Arşiv bilgileri yüklenemedi'), findsOneWidget);
    expect(find.text('Henüz belge eklenmemiş'), findsNothing);
  });

  testWidgets(
    'Yükleme sırasında Profil açılır; palet değişimi yeni sorgu başlatmaz',
    (tester) async {
      final controller = await ThemeController.load();
      final pending = Completer<AnaSayfaOzeti>();
      var calls = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: Consumer<ThemeController>(
            builder:
                (context, theme, _) => MaterialApp(
                  theme: theme.theme,
                  home: AnaEkran(
                    loadSummary: () {
                      calls++;
                      return pending.future;
                    },
                  ),
                ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('navigation-5')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilEkrani), findsOneWidget);
      expect(find.text('Profil'), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('mobile-page-title')))
            .data,
        'Profil',
      );
      await controller.selectPalette(AppPalette.slate);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        Theme.of(tester.element(find.byType(ProfilEkrani))).colorScheme.primary,
        AppPalette.slate.primary,
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(sample());
      await tester.pump();
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );

  testWidgets('Hızlı işlemler bütün hedeflere ulaşır', (tester) async {
    final selected = <int>[];
    var backups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeActions(
              onNavigate: selected.add,
              onBackup: () => backups++,
            ),
          ),
        ),
      ),
    );
    for (final label in [
      'Belgeler',
      'Kategoriler',
      'Kişiler',
      'Senkronizasyon',
      'Yedekleme',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
    }
    expect(selected, [1, 2, 4, 3]);
    expect(backups, 1);
  });

  testWidgets(
    'Belge menüsü açma, paylaşma, düzenleme ve silme hedeflerini korur',
    (tester) async {
      final actions = <HomeDocumentAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentDocuments(
              documents: [sample().sonBelgeler.first],
              onAll: () {},
              onAdd: () {},
              onAction: (_, action) => actions.add(action),
            ),
          ),
        ),
      );
      for (final label in ['Aç', 'Paylaş', 'Düzenle', 'Sil']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(actions, HomeDocumentAction.values);
    },
  );

  testWidgets('Tüm paletlerde ortak kart rengi ve ana sayfa teması eşleşir', (
    tester,
  ) async {
    for (final palette in AppPalette.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(palette),
          home: AnaEkran(
            key: ValueKey(palette),
            loadSummary: () async => sample(empty: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppCard).first);
      expect(Theme.of(context).colorScheme.primary, palette.primary);
      expect(
        CardTheme.of(context).color,
        Theme.of(context).colorScheme.surfaceContainerLowest,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Veritabanı penceresi dar ekranda uzun yolu taşırmadan gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (_) => const StorageInfoDialog(
                              path:
                                  'C:/Users/OrnekKullanici/Documents/arsiv/veritabani/cok-uzun-bir-klasor/arsiv.db',
                              size: '12 MB',
                              version: 3,
                              exists: true,
                            ),
                      ),
                  child: const Text('Göster'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Göster'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
