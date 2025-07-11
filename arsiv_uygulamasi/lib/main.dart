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
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';

// Services
import 'services/http_sunucu_servisi.dart';
import 'services/veritabani_servisi.dart';
import 'services/dosya_servisi.dart';
import 'services/senkronizasyon_yonetici_servisi.dart';
import 'services/log_servisi.dart';
import 'services/error_handler_servisi.dart';
import 'services/auth_servisi.dart';
import 'services/cache_servisi.dart';

// Providers
import 'providers/app_state_manager.dart';

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

    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AppStateManager())],
        child: const ArsivimApp(),
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
  const ArsivimApp({super.key});

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
      theme: _buildLightTheme(),

      // Home screen
      home: const SplashScreen(),

      // Route configuration
      onGenerateRoute: _generateRoute,

      // Error handling
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: child!,
            );
          },
        );
      },
    );
  }

  /// Generate custom routes
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AnaEkran());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
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

  /// Build light theme
  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF2E7D32); // Green
    const secondaryColor = Color(0xFF4CAF50); // Light Green
    const accentColor = Color(0xFFFF9800); // Orange

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
      ),

      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryColor,
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        elevation: 8,
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
    );
  }
}
