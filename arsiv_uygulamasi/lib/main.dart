import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/ana_ekran.dart';
import 'services/http_sunucu_servisi.dart';
import 'services/ayarlar_servisi.dart';
import 'services/tema_yoneticisi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux/macOS için SQLite FFI başlatma
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AyarlarServisi.instance.init();

  // HTTP sunucusunu arka planda güvenli şekilde başlat
  Future.microtask(() async {
    try {
      final httpSunucu = HttpSunucuServisi.instance;
      await httpSunucu.sunucuyuBaslat();
      print('✅ HTTP sunucusu başarıyla başlatıldı');
    } catch (error) {
      print('❌ HTTP sunucusu başlatma hatası: $error');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  TemaSecenek _currentTema = TemaSecenek.sistem;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final tema = await AyarlarServisi.instance.getTemaSecenegi();
    setState(() {
      _currentTema = tema;
    });
  }

  void changeTema(TemaSecenek yeniTema) {
    setState(() {
      _currentTema = yeniTema;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arşivim',
      theme: TemaYoneticisi.acikTema,
      darkTheme: TemaYoneticisi.koyuTema,
      themeMode: AyarlarServisi.instance.getThemeMode(_currentTema),
      home: const AnaEkran(),
      debugShowCheckedModeBanner: false,
    );
  }
}
