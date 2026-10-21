import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arsiv_uygulamasi/providers/theme_controller.dart';
import 'package:arsiv_uygulamasi/screens/profil_ekrani.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/widgets/app_navigation_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_THEME_PREVIEW') &&
        Platform.isWindows) {
      final font = FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('İlk açılış ve geçersiz tercihler yeşil paleti kullanır', () async {
    for (final value in [null, 'old-palette', 42]) {
      SharedPreferences.setMockInitialValues({
        if (value != null) ThemeController.preferenceKey: value,
      });
      final controller = await ThemeController.load();
      expect(controller.palette, AppPalette.forest);
      controller.dispose();
    }
  });

  test(
    'Palet yeniden yüklenir ve varsayılan tercih kalıcı sıfırlanır',
    () async {
      final controller = await ThemeController.load();
      expect(await controller.selectPalette(AppPalette.slate), isTrue);
      final restored = await ThemeController.load();
      expect(restored.palette, AppPalette.slate);
      expect(restored.theme.colorScheme.primary, AppPalette.slate.primary);
      expect(await restored.selectPalette(AppPalette.forest), isTrue);
      final reset = await ThemeController.load();
      expect(reset.palette, AppPalette.forest);
      controller.dispose();
      restored.dispose();
      reset.dispose();
    },
  );

  test('Hızlı seçimler paralel kayıt oluşturmaz', () async {
    final controller = await ThemeController.load();
    final first = controller.selectPalette(AppPalette.plum);
    expect(controller.saving, isTrue);
    expect(await controller.selectPalette(AppPalette.earth), isFalse);
    expect(await first, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.palette, AppPalette.plum);
    controller.dispose();
  });

  test('Tüm paletlerde ana renk metni okunaklı ve marka renkleri tanımlı', () {
    for (final palette in AppPalette.values) {
      final theme = AppTheme.forPalette(palette);
      final contrast =
          (theme.colorScheme.onPrimary.computeLuminance() + 0.05) /
          (theme.colorScheme.primary.computeLuminance() + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: palette.label);
      expect(
        theme.extension<BrandColors>()!.background,
        palette.brandBackground,
      );
    }
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Profil taşmadan çalışır: genişlik $width / yazı $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await ThemeController.load();
        final previewKey = GlobalKey();
        await tester.pumpWidget(_app(controller, scale, previewKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final choice = find.text('Arduvaz mavisi');
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(controller.palette, AppPalette.slate);
        final profileContext = tester.element(find.byType(ProfilEkrani));
        expect(
          Theme.of(profileContext).colorScheme.primary,
          AppPalette.slate.primary,
        );
        expect(tester.takeException(), isNull);
        final reset = find.text('Varsayılan yeşile dön');
        await tester.ensureVisible(reset);
        await tester.pumpAndSettle();
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(controller.palette, AppPalette.forest);
        expect(tester.takeException(), isNull);

        if (const bool.fromEnvironment('CAPTURE_THEME_PREVIEW') &&
            scale == 1 &&
            (width == 390 || width == 1440)) {
          await tester.drag(find.byType(ListView), const Offset(0, 3000));
          await tester.pumpAndSettle();
          final boundary =
              previewKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('artifacts/theme');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/profil-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }

  testWidgets('Profil gezinme hedefi seçilebilir', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPalette(AppPalette.forest),
        home: Scaffold(
          bottomNavigationBar: AppNavigationBar(
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    expect(selected, 5);
  });
}

Widget _app(ThemeController controller, double scale, GlobalKey previewKey) =>
    ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<ThemeController>(
        builder:
            (context, theme, child) => MaterialApp(
              theme: theme.theme,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: RepaintBoundary(
                key: previewKey,
                child: Scaffold(
                  body: const SafeArea(child: ProfilEkrani()),
                  bottomNavigationBar: AppNavigationBar(
                    selectedIndex: 5,
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
      ),
    );
