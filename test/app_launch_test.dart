import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arsiv_uygulamasi/services/app_launch_service.dart';
import 'package:arsiv_uygulamasi/services/auth_servisi.dart';
import 'package:arsiv_uygulamasi/screens/app_entry_screen.dart';
import 'package:arsiv_uygulamasi/screens/splash_screen.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AppLaunchService service({bool signedIn = false, bool existing = false}) =>
      AppLaunchService(
        restoreSession: () async => signedIn,
        hasExistingAccount: () async => existing,
      );
  test(
    'First installation shows welcome once; restarting does not repeat it',
    () async {
      final first = await service().prepare();
      expect(first.showWelcome, true);
      expect(first.signedIn, false);
      await service().markWelcomeSeen();
      final second = await service().prepare();
      expect(second.showWelcome, false);
      expect(second.signedIn, false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getBool(AppLaunchService.welcomeSeenKey), true);
    },
  );
  test(
    'Existing signed-in installation skips welcome even without the new preference',
    () async {
      final launch = await service(signedIn: true).prepare();
      expect(launch.showWelcome, false);
      expect(launch.signedIn, true);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AppLaunchService.welcomeSeenKey,
        ),
        true,
      );
    },
  );
  test(
    'Existing signed-out installation skips welcome but cannot enter home',
    () async {
      final launch = await service(existing: true).prepare();
      expect(launch.showWelcome, false);
      expect(launch.signedIn, false);
    },
  );
  test(
    'Logout keeps welcome preference; known installation still verifies the session',
    () async {
      await service().markWelcomeSeen();
      await AuthServisi.instance.logout();
      var checks = 0;
      final startup = AppLaunchService(
        restoreSession: () async {
          checks++;
          return false;
        },
        hasExistingAccount:
            () async => throw StateError('unnecessary account query'),
      );
      final launch = await startup.prepare();
      expect(checks, 1);
      expect(launch.showWelcome, false);
      expect(launch.signedIn, false);
    },
  );
  Widget app(AppLaunchState launch, AppLaunchService startup) => MaterialApp(
    theme: AppTheme.forPalette(AppPalette.forest),
    home: AppEntryScreen(
      launch: launch,
      service: startup,
      homeBuilder: (_) => const Scaffold(body: Text('Home destination')),
      loginBuilder: (_) => const Scaffold(body: Text('Login destination')),
    ),
  );
  for (final signedIn in [false, true]) {
    testWidgets('Returning user routes immediately, signedIn=$signedIn', (
      tester,
    ) async {
      final startup = service(signedIn: signedIn, existing: true);
      final launch = await startup.prepare();
      await tester.pumpWidget(app(launch, startup));
      expect(find.byType(SplashScreen), findsNothing);
      expect(
        find.text(signedIn ? 'Home destination' : 'Login destination'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Welcome records display and automatically leaves once', (
    tester,
  ) async {
    final startup = service();
    await tester.pumpWidget(app(await startup.prepare(), startup));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        AppLaunchService.welcomeSeenKey,
      ),
      true,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Login destination'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Login destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Skip immediately completes welcome; disposed timer cannot navigate again',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onComplete: () => completed++)),
      );
      await tester.tap(find.text('Devam et'));
      await tester.pump(const Duration(seconds: 2));
      expect(completed, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            key: const ValueKey('other'),
            onComplete: () => completed++,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 640), const Size(900, 390)]) {
    testWidgets('Welcome adapts to $size at 2x text', (tester) async {
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
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
          home: SplashScreen(onComplete: () {}),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Devam et'));
      expect(find.text('Devam et').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
