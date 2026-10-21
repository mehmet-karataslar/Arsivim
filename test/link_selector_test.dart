import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/widgets/document_editor/link_selector.dart';
import 'package:arsiv_uygulamasi/widgets/document_editor/link_selection_panel.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_EDITOR_PREVIEW')) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Büyük seçim paneli $size × $scale; klavye ve dar yükseklik', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final boundary = GlobalKey();
        Set<int> chosen = {1};
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: AppTheme.forPalette(AppPalette.forest),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Yeni Belge Ekle')),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LinkSelector(
                      label: 'Kişi bağlantısı',
                      icon: Icons.person_outline,
                      options: [
                        const LinkOption(1, 'Mehmet Karataş'),
                        const LinkOption(2, 'Nesih Karataş'),
                        for (var i = 3; i < 80; i++)
                          LinkOption(i, 'Kişi $i · Uzun ad soyad bilgisi'),
                      ],
                      selected: chosen,
                      onChanged: (ids) => chosen = ids,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ara ve seç (1)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(LinkSelectionPanel)).height,
          greaterThan(size.height * .9),
        );
        if (const bool.fromEnvironment('CAPTURE_EDITOR_PREVIEW') &&
            size.width == 390 &&
            scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/editor/mobile-link-selection.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Small viewports scroll the search with the header, keeping Apply fixed.
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Nesih');
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height < 500 ? 150 : 280,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Seçimi uygula (1)').hitTestable(), findsOneWidget);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Nesih Karataş'));
        await tester.tap(find.text('Nesih Karataş'));
        await tester.pumpAndSettle();
        expect(chosen, {1});
        await tester.tap(find.text('Seçimi uygula (2)'));
        await tester.pumpAndSettle();
        expect(chosen, {1, 2});
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Mobil kapatma seçimi uygulamaz; seçilenler filtresi ve temizleme çalışır',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Set<int> chosen = {1};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkSelector(
              label: 'Kategori bağlantısı',
              options: const [LinkOption(1, 'Okul'), LinkOption(2, 'Eğitim')],
              selected: chosen,
              onChanged: (ids) => chosen = ids,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ara ve seç (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eğitim'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Seçimi uygulamadan kapat'));
      await tester.pumpAndSettle();
      expect(chosen, {1});
      await tester.tap(find.text('Ara ve seç (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seçilenler (1)'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(LinkSelectionPanel),
          matching: find.text('Eğitim'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Seçimi temizle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seçimi uygula (0)'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
    },
  );
}
