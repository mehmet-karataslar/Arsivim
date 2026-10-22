import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

// Screens
import 'screens/ana_ekran.dart';
import 'screens/app_entry_screen.dart';
import 'services/app_launch_service.dart';
import 'screens/belge_duzenle_ekrani.dart';

// Services
import 'services/notification_service.dart';
import 'services/veritabani_servisi.dart';
import 'services/log_servisi.dart';
import 'services/error_handler_servisi.dart';
import 'services/cache_servisi.dart';
import 'services/depolama_izni.dart';

// Providers
import 'providers/app_state_manager.dart';
import 'providers/theme_controller.dart';

// Models
import 'models/belge_modeli.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash handling setup
  FlutterError.onError = (FlutterErrorDetails details) {
    LogServisi.instance.error(
      'Flutter hatası',
      details.exception,
      details.stack,
    );
  };

  try {
    // Platform-specific initialization
    await _platformInit();

    // Request permissions
    await _requestPermissions();

    // Initialize core services
    await _initializeServices();

    final themeController = await ThemeController.load();
    final launchService = AppLaunchService();
    final launch = await launchService.prepare();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStateManager()),
          ChangeNotifierProvider<ThemeController>(
            create: (_) => themeController,
          ),
        ],
        child: ArsivimApp(launch: launch, launchService: launchService),
      ),
    );
  } catch (e, stackTrace) {
    LogServisi.instance.error('Uygulama başlatılamadı', e, stackTrace);

    // Show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Uygulama başlatılamadı',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hata: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Platform-specific initialization
Future<void> _platformInit() async {
  // Windows/Linux/macOS için SQLite FFI başlatma
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Status bar ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Orientation ayarları
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  ]);
}

/// Request necessary permissions
Future<void> _requestPermissions() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  await Permission.camera.request();
  if (Platform.isAndroid) {
    final android = await DeviceInfoPlugin().androidInfo;
    await androidDepolamaIzniIste(android.version.sdkInt);
  }
  // Bildirim izni NotificationService tarafından tek noktadan istenir.
}

/// Initialize core services without opening a network listener at startup.
Future<void> _initializeServices() async {
  await LogServisi.instance.init();
  await ErrorHandlerServisi.instance.init();
  await CacheServisi().initialize();
  await VeriTabaniServisi().baslat();

  // 8080 yalnızca senkronizasyon bağlantısı açıldığında dinlenir.
  if (Platform.isAndroid || Platform.isIOS) {
    final notifications = NotificationService.instance;
    if (await notifications.initialize()) {
      await notifications.requestPermissions();
    }
  }
}

class ArsivimApp extends StatelessWidget {
  const ArsivimApp({
    super.key,
    required this.launch,
    required this.launchService,
  });
  final AppLaunchState launch;
  final AppLaunchService launchService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arşivim - Kişisel Belge Arşivi',
      debugShowCheckedModeBanner: false,

      // Localization
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Theme configuration
      theme: context.watch<ThemeController>().theme,

      // Home screen
      home: AppEntryScreen(launch: launch, service: launchService),

      // Route configuration
      onGenerateRoute: _generateRoute,
    );
  }

  /// Generate custom routes
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AnaEkran());
      case '/belge-duzenle':
        final belge = settings.arguments as BelgeModeli?;
        if (belge != null) {
          return MaterialPageRoute(
            builder: (_) => BelgeDuzenleEkrani(belge: belge),
          );
        } else {
          return MaterialPageRoute(
            builder:
                (_) => Scaffold(
                  appBar: AppBar(title: const Text('Hata')),
                  body: const Center(child: Text('Belge bilgisi bulunamadı!')),
                ),
          );
        }
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Sayfa bulunamadı: ${settings.name}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
        );
    }
  }
}
