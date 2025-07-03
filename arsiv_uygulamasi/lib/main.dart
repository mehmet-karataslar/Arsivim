import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/ana_ekran.dart';
import 'services/http_sunucu_servisi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux/macOS için SQLite FFI başlatma
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // HTTP sunucusunu arka planda güvenli şekilde başlat
  Future.microtask(() async {
    try {
      final httpSunucu = HttpSunucuServisi.instance;

      // Global callback ayarla (tüm ekranlar için)
      httpSunucu.setOnDeviceConnected((deviceInfo) {
        print('🎉 GLOBAL: Yeni cihaz bağlandı - ${deviceInfo['clientName']}');
        print('📱 IP: ${deviceInfo['ip']}');
        print('💻 Platform: ${deviceInfo['platform']}');

        // TODO: Burada global bildirim gösterebiliriz
        // Şimdilik sadece log'a yazdırıyoruz
      });

      await httpSunucu.sunucuyuBaslat();
      print('✅ HTTP sunucusu başarıyla başlatıldı');
    } catch (error) {
      print('❌ HTTP sunucusu başlatma hatası: $error');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arşivim',
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AnaEkran(),
      debugShowCheckedModeBanner: false,
    );
  }
}
