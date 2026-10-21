import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/models/people_overview.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/providers/people_controller.dart';
import 'package:arsiv_uygulamasi/services/people_repository.dart';
import 'package:arsiv_uygulamasi/screens/kisiler_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/common/metric_grid.dart';
import 'package:arsiv_uygulamasi/widgets/app_navigation_bar.dart';
import 'package:arsiv_uygulamasi/widgets/people/person_card.dart';
import 'package:arsiv_uygulamasi/widgets/people/person_detail_panel.dart';

class FakePeople extends PeopleRepository {
  int reads = 0;
  final detailReads = <int>[];
  late List<PersonSummary> people = List.generate(9, (i) {
    final names = [
      'Nejdet Karataş',
      'Mehmet Karataş',
      'Özlem Karataş',
      'Nesih Karataş',
      'Ahmet Kaya',
      'Sema Kaya',
      'Ayşe Yılmaz',
      'Burak Demir',
      'Eren Demir',
    ];
    final name = names[i].split(' ');
    final category =
        KategoriModeli.ontanimliKategoriler()[i % 6]..id = i % 6 + 1;
    return PersonSummary(
      person: KisiModeli(
        id: i + 1,
        ad: name.first,
        soyad: name.last,
        olusturmaTarihi: DateTime(2026, 10, 15),
        guncellemeTarihi: DateTime(2026, 10, 21),
      ),
      documentCount: [10, 20, 10, 10, 8, 6, 5, 12, 7][i],
      categories: [category],
      updated: DateTime(2026, 10, 21).subtract(Duration(days: i)),
    );
  });
  @override
  Future<PeopleOverview> read() async {
    reads++;
    return PeopleOverview(people);
  }

  @override
  Future<PersonDetails> details(int personId) async {
    detailReads.add(personId);
    return PersonDetails(
      personId: personId,
      documents: [
        for (var i = 0; i < 3; i++)
          BelgeModeli(
            id: personId * 10 + i,
            kisiId: personId,
            dosyaAdi: 'belge-$personId-$i.pdf',
            orijinalDosyaAdi: 'belge-$personId-$i.pdf',
            baslik:
                [
                  'Kimlik_Ön_Yüz.pdf',
                  'Nüfus_Kayıt_Örneği.pdf',
                  'Adres_Bilgisi.pdf',
                ][i],
            dosyaYolu: 'unused',
            dosyaBoyutu: 124000,
            dosyaTipi: 'pdf',
            dosyaHash: '$personId-$i',
            olusturmaTarihi: DateTime(2026, 10, 15),
            guncellemeTarihi: DateTime(2026, 10, 21),
          ),
      ],
      folders: const [PersonFolder('C:/Arsiv/Belgeler', 'Belgeler', 3)],
      notes: [],
    );
  }

  @override
  Future<void> remove(int id) async {
    people = people.where((entry) => entry.person.id != id).toList();
  }
}

class DelayedPeople extends FakePeople {
  final pending = <int, Completer<PersonDetails>>{};
  @override
  Future<PersonDetails> details(int id) =>
      pending[id]?.future ?? super.details(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_PEOPLE_PREVIEW') &&
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
  test('Hızlı seçimde eski kişinin yanıtı yeni paneli değiştirmez', () async {
    final repository = DelayedPeople();
    final controller = PeopleController(repository);
    await controller.refresh();
    repository.pending[1] = Completer<PersonDetails>();
    final old = controller.select(1);
    await controller.select(2);
    repository.pending[1]!.complete(
      const PersonDetails(personId: 1, documents: [], folders: [], notes: []),
    );
    await old;
    expect(controller.selectedId, 2);
    expect(controller.details!.personId, 2);
    controller.close();
    expect(controller.selected, isNull);
    controller.dispose();
  });
  test(
    'Arama ve filtreler Türkçe adları, kategori ve belge durumunu korur',
    () async {
      final controller = PeopleController(FakePeople());
      await controller.refresh();
      controller.search('ÖZLEM');
      expect(controller.visible.single.person.ad, 'Özlem');
      controller.search('');
      controller.filterCategory(1);
      expect(
        controller.visible.every(
          (entry) => entry.categories.any((c) => c.id == 1),
        ),
        true,
      );
      controller.filterDocuments(PeopleDocumentFilter.withoutDocuments);
      expect(controller.visible, isEmpty);
      controller.filterCategory(null);
      controller.filterDocuments(PeopleDocumentFilter.all);
      controller.order(PeopleSort.documents);
      expect(controller.visible.first.documentCount, 20);
      controller.dispose();
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1672.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Kişiler $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = FakePeople();
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
                    width < 1100
                        ? AppBar(
                          title: const Text('Kişiler'),
                          centerTitle: true,
                        )
                        : null,
                bottomNavigationBar:
                    width < 1100
                        ? AppNavigationBar(selectedIndex: 4, onSelected: (_) {})
                        : null,
                body: Row(
                  children: [
                    if (width >= 1100 && scale == 1)
                      AppSidebar(
                        selectedIndex: 4,
                        summary: null,
                        onSelected: (_) {},
                        onStorage: () {},
                        onLogout: () {},
                      ),
                    Expanded(
                      child: KisilerEkrani(
                        repository: repository,
                        showHeading: width >= 1100,
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
        expect(repository.reads, 1);
        if (width < 600) {
          expect(find.byType(MetricCard), findsNothing);
          expect(find.byTooltip('Kişi ekle'), findsOneWidget);
          final cards = find.byType(PersonCard);
          expect(
            tester.getTopLeft(cards.at(0)).dy,
            tester.getTopLeft(cards.at(1)).dy,
          );
          expect(tester.getRect(cards.at(0)).left, 0);
          expect(tester.getRect(cards.at(1)).right, width);
        }
        if (const bool.fromEnvironment('CAPTURE_PEOPLE_PREVIEW') &&
            scale == 1 &&
            [390.0, 1672.0].contains(width)) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('artifacts/people').create(recursive: true);
            await File(
              'artifacts/people/kisiler-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
  testWidgets(
    'Ada tıklamak sağ paneli günceller; belgeler seçilen kişiye gider',
    (tester) async {
      tester.view.physicalSize = const Size(1672, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: Scaffold(
            body: KisilerEkrani(
              repository: FakePeople(),
              onOpenDocuments: opened.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byWidgetPredicate(
        (widget) => widget is PersonCard && widget.person.person.id == 2,
      );
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable:
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tester.tap(
        find.descendant(of: card, matching: find.text('Mehmet Karataş')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('person-detail-name')))
            .data,
        'Mehmet Karataş',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PersonDetailPanel),
          matching: find.text('Klasörler'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('C:/Arsiv/Belgeler'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(PersonDetailPanel),
              matching: find.text('Belgeler'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm belgeleri aç (20)'));
      expect(opened, [2]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Mobil kişi ayrıntısı panelde açılır, silme iptal edilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakePeople();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        home: Scaffold(body: KisilerEkrani(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PersonCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(PersonDetailPanel), findsOneWidget);
    await tester.tap(find.byTooltip('Kişi panelini kapat'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PersonCard).first,
        matching: find.byKey(const ValueKey('person-action-delete')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(repository.people.length, 9);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Dar ekranda büyük yazıyla kişi filtreleri açılır ve uygulanır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
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
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
        home: Scaffold(body: KisilerEkrani(repository: FakePeople())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filtreler'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.byType(DropdownButtonFormField<PeopleDocumentFilter>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belgesi olmayanlar').last);
    await tester.pumpAndSettle();
    expect(find.byType(PersonCard), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Filtreleri kapat'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Kişi ekle'), findsOneWidget);
  });
}
