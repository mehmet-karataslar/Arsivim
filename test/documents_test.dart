import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/models/ana_sayfa_ozeti.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/document_filters.dart';
import 'package:arsiv_uygulamasi/screens/belgeler_ekrani.dart';
import 'package:arsiv_uygulamasi/services/document_repository.dart';
import 'package:arsiv_uygulamasi/services/document_activity_service.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/common/document_tile.dart';
import 'package:arsiv_uygulamasi/widgets/common/metric_grid.dart';
import 'package:arsiv_uygulamasi/widgets/app_navigation_bar.dart';
import 'package:arsiv_uygulamasi/widgets/documents/document_filter_bar.dart';
import 'package:arsiv_uygulamasi/widgets/documents/document_filter_dialog.dart';

class PreviewRepository extends DocumentRepository {
  final queries = <DocumentFilters>[];
  late final documents = List.generate(
    30,
    (i) => SonBelgeOzeti(
      belge: BelgeModeli(
        id: i + 1,
        baslik:
            [
              '5_Sinif_Turkce_20_Soruluk_Sinav',
              'e9324738-6',
              'class_distribution',
              'confidence_distribution',
              'confusion_matrix',
              'membership_function_comparison',
            ][i % 6],
        dosyaAdi: 'belge-$i',
        orijinalDosyaAdi: 'belge-$i',
        dosyaYolu: 'unused',
        dosyaTipi: ['docx', 'pdf', 'png', 'png', 'png', 'docx'][i % 6],
        dosyaHash: '$i',
        dosyaBoyutu: 124000 + i * 1000,
        olusturmaTarihi: DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      ),
      kategori: i % 3 == 0 ? 'Okul' : 'Belgeler',
      kisi: 'Nesih Karataş',
    ),
  );
  late final summary = AnaSayfaOzeti(
    belgeSayisi: 30,
    dosyaBoyutu: 7549747,
    kategoriSayisi: 4,
    sonBelgeler: documents.take(5).toList(),
    turBoyutlari: const {'documents': 6291456, 'images': 1258291},
  );
  @override
  Future<DocumentOverview> overview({DateTime? now}) async => DocumentOverview(
    summary: summary,
    today: 3,
    week: 8,
    large: 1,
    types: const {'docx': 10, 'pdf': 5, 'png': 15},
    categories: const [
      DocumentOption(1, 'Okul', 6),
      DocumentOption(2, 'İş', 3),
    ],
    people: const [DocumentOption(1, 'Nesih Karataş')],
    activities: [
      for (final d in documents.take(5))
        RecentActivity(
          d,
          DocumentActivity(
            d.belge.id!,
            'open',
            DateTime.now().subtract(const Duration(minutes: 3)),
          ),
        ),
    ],
  );
  @override
  Future<DocumentPage> fetch(
    DocumentFilters filters, {
    int offset = 0,
    int limit = 25,
    List<int> sharedIds = const [],
  }) async {
    queries.add(filters);
    final rows =
        documents
            .where(
              (d) =>
                  (filters.extension == null ||
                      d.belge.dosyaTipi == filters.extension) &&
                  (filters.query.isEmpty ||
                      d.belge.baslik!.contains(filters.query)),
            )
            .toList();
    return DocumentPage(rows.skip(offset).take(limit).toList(), rows.length);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Kısa yatay pencerede tüm içerik kaydırılır', (tester) async {
    tester.view.physicalSize = const Size(1200, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        home: BelgelerEkrani(repository: PreviewRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (w) => w is DocumentTile && w.document.belge.id == 1,
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
    expect(tester.takeException(), isNull);
  });
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_DOCUMENTS_PREVIEW') &&
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
      testWidgets('Belgeler yerleşimi $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 941);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = PreviewRepository();
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
                            'Belgeler',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        : null,
                bottomNavigationBar:
                    width < 600
                        ? AppNavigationBar(selectedIndex: 1, onSelected: (_) {})
                        : null,
                body: Row(
                  children: [
                    if (width >= 1100 && scale == 1)
                      AppSidebar(
                        selectedIndex: 1,
                        onSelected: (_) {},
                        summary: repository.summary,
                        onStorage: () {},
                        onLogout: () {},
                      ),
                    Expanded(
                      child: BelgelerEkrani(
                        embedded: true,
                        repository: repository,
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
        expect(find.textContaining('10 GB'), findsNothing);
        if (width < 600) {
          expect(
            find.descendant(
              of: find.byType(BelgelerEkrani),
              matching: find.text('Belgeler'),
            ),
            findsNothing,
          );
          expect(find.byType(MetricCard), findsNothing);
          expect(find.byType(DocumentFilterBar), findsNothing);
          expect(find.byType(FloatingActionButton), findsOneWidget);
          final tile = find.byType(DocumentTile).first;
          final buttons = [
            for (final action in HomeDocumentAction.values)
              find.descendant(
                of: tile,
                matching: find.byKey(
                  ValueKey('document-action-${action.name}'),
                ),
              ),
          ];
          final top = tester.getTopLeft(buttons.first).dy;
          for (final button in buttons) {
            expect(tester.getTopLeft(button).dy, top);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          }
        }

        if (const bool.fromEnvironment('CAPTURE_DOCUMENTS_PREVIEW') &&
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
            await Directory('artifacts/documents').create(recursive: true);
            await File(
              'artifacts/documents/belgeler-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final scroll =
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first;
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (widget) => widget is DocumentTile && widget.document.belge.id == 1,
          ),
          400,
          scrollable: scroll,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Mobil filtre aç/kapat, iptal, uygula, sıfırla / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PreviewRepository();
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
          home: BelgelerEkrani(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentFilterPanel), findsOneWidget);
      await tester.tap(find.text('Tüm türler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('İptal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.extension, isNull);
      expect(find.byType(DocumentFilterPanel), findsNothing);
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm türler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Uygula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.extension, 'pdf');
      expect(find.byType(DocumentFilterPanel), findsNothing);
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sıfırla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sıfırla'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Uygula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.hasFilters, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Arama gecikmesi, sıfırlama, filtre, görünüm ve sıralama çalışır',
    (tester) async {
      tester.view.physicalSize = const Size(1672, 941);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PreviewRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: BelgelerEkrani(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.queries.length, 1);
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump(const Duration(milliseconds: 150));
      expect(repository.queries.length, 1);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu aramayla eşleşen belge bulunamadı.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(repository.queries.last.query, '');
      await tester.tap(find.text('PDF (5)'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.extension, 'pdf');
      await tester.tap(find.byTooltip('Kart görünümü'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Belgeleri sırala'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boyuta göre').last);
      await tester.pumpAndSettle();
      expect(repository.queries.last.sort, DocumentSort.largest);
      await tester.tap(find.byTooltip('Filtreler'));
      await tester.pumpAndSettle();
      expect(find.text('Belgeleri filtrele'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Uygula'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.extension, 'pdf');
    },
  );
}
