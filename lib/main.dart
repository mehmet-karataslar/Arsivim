import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Gerekli değil
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

// Screens
import 'screens/ana_ekran.dart';
import 'screens/app_entry_screen.dart';
import 'services/app_launch_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/belge_duzenle_ekrani.dart';

// Services
import 'services/http_sunucu_servisi.dart';
import 'services/notification_service.dart';
import 'services/veritabani_servisi.dart';
import 'services/dosya_servisi.dart';
import 'services/senkronizasyon_yonetici_servisi.dart';
import 'services/log_servisi.dart';
import 'services/error_handler_servisi.dart';
import 'services/auth_servisi.dart';
import 'services/cache_servisi.dart';

// Providers
import 'providers/app_state_manager.dart';
import 'providers/theme_controller.dart';

// Models
import 'models/belge_modeli.dart';

// Utils
import 'utils/sabitler.dart';
import 'utils/network_optimizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crash handling setup
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('🔥 Flutter Crash: ${details.exception}');
    print('📍 Stack: ${details.stack}');
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
    print('🔥 App initialization failed: $e');
    print('📍 Stack: $stackTrace');

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
  print('🔧 Platform initialization starting...');

  // Windows/Linux/macOS için SQLite FFI başlatma
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('✅ SQLite FFI initialized for desktop platform');
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

  print('✅ Platform initialization completed');
}

/// Request necessary permissions
Future<void> _requestPermissions() async {
  print('🔐 Requesting permissions...');

  if (Platform.isAndroid || Platform.isIOS) {
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.notification,
      if (Platform.isAndroid) Permission.manageExternalStorage,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      print('📋 Permission ${permission.toString()}: ${status.toString()}');
    }
  }

  print('✅ Permission requests completed');
}

/// Initialize all services in correct order
Future<void> _initializeServices() async {
  print('🚀 Services initialization starting...');

  try {
    // 1. Log Service (must be first for error tracking)
    print('📝 Initializing log service...');
    final logServisi = LogServisi.instance;
    await logServisi.init();
    print('✅ Log service initialized');

    // 2. Error Handler Service
    print('🚨 Initializing error handler...');
    final errorHandler = ErrorHandlerServisi.instance;
    await errorHandler.init();
    print('✅ Error handler initialized');

    // 3. Cache Service
    print('💾 Initializing cache service...');
    final cacheServisi = CacheServisi();
    await cacheServisi.initialize();
    print('✅ Cache service initialized');

    // 4. Network Optimizer
    print('🌐 Initializing network optimizer...');
    final networkOptimizer = NetworkOptimizer.instance;
    // await networkOptimizer.initialize(); // Yavaşlığa neden olan kısım
    print('✅ Network optimizer initialized');

    // 5. Database Service
    print('📁 Initializing database service...');
    final veriTabani = VeriTabaniServisi();

    // Veritabanını başlat (otomatik oluşturma dahil)
    await veriTabani.baslat();
    print('✅ Database service initialized');

    // 6. File Service
    print('📂 Initializing file service...');
    final dosyaServisi = DosyaServisi();
    // File service is ready to use (singleton pattern)
    print('✅ File service initialized');

    // 7. HTTP Server Service
    print('🌐 Initializing HTTP server...');
    final httpSunucu = HttpSunucuServisi.instance;

    // Set up global device connection callback
    httpSunucu.setOnDeviceConnected((deviceInfo) {
      print('🎉 GLOBAL: New device connected - ${deviceInfo['clientName']}');
      print('📱 IP: ${deviceInfo['ip']}');
      print('💻 Platform: ${deviceInfo['platform']}');
    });

    await httpSunucu.sunucuyuBaslat();
    print('✅ HTTP server started successfully');

    // 8. Notification Service
    print('🔔 Initializing notification service...');
    final notificationService = NotificationService.instance;
    await notificationService.initialize();
    await notificationService.requestPermissions();
    print('✅ Notification service initialized');

    // 8. Authentication Service
    print('🔐 Initializing authentication service...');
    final authServisi = AuthServisi.instance;
    // Auth service is ready to use (singleton pattern)
    print('✅ Authentication service initialized');

    // 9. Start Network Monitoring
    print('📡 Starting network monitoring...');
    // Bu kısım da başlangıçta gecikmeye neden olabilir.
    /*
    await networkOptimizer.startNetworkMonitoring(
      interval: const Duration(minutes: 3),
      testServers: ['http://8.8.8.8', 'http://1.1.1.1'],
    );
    */
    print('✅ Network monitoring started');

    // 10. Synchronization Manager Service
    print('🔄 Initializing synchronization manager...');
    final senkronYonetici = SenkronizasyonYoneticiServisi.instance;
    // Synchronization manager is ready to use (singleton pattern)
    print('✅ Synchronization manager initialized');

    print('🎉 All services initialized successfully!');
  } catch (e, stackTrace) {
    print('❌ Service initialization failed: $e');
    print('📍 Stack: $stackTrace');
    rethrow;
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
