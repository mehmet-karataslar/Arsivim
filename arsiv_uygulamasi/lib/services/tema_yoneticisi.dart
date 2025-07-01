import 'package:flutter/material.dart';

class TemaYoneticisi {
  // Ana renkler
  static const Color anaRenk = Color(0xFF6366F1); // İndigo
  static const Color ikinciRenk = Color(0xFF8B5CF6); // Mor
  static const Color vurguRengi = Color(0xFF10B981); // Yeşil
  static const Color uyariRengi = Color(0xFFF59E0B); // Turuncu
  static const Color hataRengi = Color(0xFFEF4444); // Kırmızı

  // Açık tema
  static ThemeData get acikTema {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: anaRenk,
        brightness: Brightness.light,
      ),

      // AppBar teması
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
        actionsIconTheme: IconThemeData(color: Colors.black87),
      ),

      // Kart teması
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
      ),

      // Buton temaları
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: anaRenk,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: anaRenk,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Input dekorasyon teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: anaRenk, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Scaffold teması
      scaffoldBackgroundColor: Colors.grey[50],

      // BottomNavigationBar teması
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: anaRenk,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Chip teması
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        selectedColor: anaRenk.withOpacity(0.2),
        labelStyle: const TextStyle(color: Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Divider teması
      dividerTheme: DividerThemeData(
        color: Colors.grey[300],
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Koyu tema
  static ThemeData get koyuTema {
    const Color koyuArkaplan = Color(0xFF121212);
    const Color koyuYuzey = Color(0xFF1E1E1E);
    const Color koyuKart = Color(0xFF2D2D2D);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: anaRenk,
        brightness: Brightness.dark,
        background: koyuArkaplan,
        surface: koyuYuzey,
      ),

      // AppBar teması
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),

      // Kart teması
      cardTheme: const CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: koyuKart,
      ),

      // Buton temaları
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: anaRenk,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.grey[600]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: anaRenk,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Input dekorasyon teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: koyuYuzey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: anaRenk, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Scaffold teması
      scaffoldBackgroundColor: koyuArkaplan,

      // BottomNavigationBar teması
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: koyuKart,
        selectedItemColor: anaRenk,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Chip teması
      chipTheme: const ChipThemeData(
        backgroundColor: koyuYuzey,
        selectedColor: Color.fromARGB(255, 99, 102, 241),
        labelStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Divider teması
      dividerTheme: DividerThemeData(
        color: Colors.grey[700],
        thickness: 1,
        space: 1,
      ),

      // Text teması
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.white60),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white70),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white70),
        labelSmall: TextStyle(color: Colors.white60),
      ),

      // Icon teması
      iconTheme: const IconThemeData(color: Colors.white70),

      // ListTile teması
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
        subtitleTextStyle: TextStyle(color: Colors.white60),
      ),

      // Switch teması
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return anaRenk;
          }
          return Colors.grey[400];
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return anaRenk.withOpacity(0.5);
          }
          return Colors.grey[600];
        }),
      ),

      // Slider teması
      sliderTheme: SliderThemeData(
        activeTrackColor: anaRenk,
        inactiveTrackColor: Colors.grey[600],
        thumbColor: anaRenk,
        overlayColor: anaRenk.withOpacity(0.2),
        valueIndicatorColor: anaRenk,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
      ),

      // RadioButton teması
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return anaRenk;
          }
          return Colors.grey[400];
        }),
      ),

      // Dialog teması
      dialogTheme: const DialogTheme(
        backgroundColor: koyuKart,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: Colors.white70, fontSize: 16),
      ),

      // SnackBar teması
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: koyuYuzey,
        contentTextStyle: TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  // Gradient tanımları
  static const LinearGradient anaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [anaRenk, ikinciRenk],
  );

  static const LinearGradient basariGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [vurguRengi, Color(0xFF059669)],
  );

  static const LinearGradient uyariGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [uyariRengi, Color(0xFFD97706)],
  );

  static const LinearGradient hataGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hataRengi, Color(0xFFDC2626)],
  );

  // Özel renkler
  static const Map<String, Color> kategorRenkleri = {
    'belgeler': Color(0xFF3B82F6),
    'resimler': Color(0xFF10B981),
    'videolar': Color(0xFFF59E0B),
    'muzik': Color(0xFF8B5CF6),
    'arsiv': Color(0xFF6B7280),
    'okul': Color(0xFF3730A3),
    'is': Color(0xFF92400E),
    'ev': Color(0xFFBE185D),
    'hastane': Color(0xFFDC2626),
    'kurum': Color(0xFF047857),
    'mali': Color(0xFF059669),
    'hukuki': Color(0xFFEA580C),
    'sigorta': Color(0xFF0891B2),
    'kisisel': Color(0xFF7C3AED),
    'seyahat': Color(0xFFF59E0B),
    'hobi': Color(0xFF65A30D),
  };

  // Yardımcı metodlar
  static Color getRenkKoduIcinRenk(String renkKodu) {
    try {
      return Color(int.parse(renkKodu.replaceFirst('#', '0xFF')));
    } catch (e) {
      return anaRenk;
    }
  }

  static String getRenkIcinRenkKodu(Color renk) {
    return '#${renk.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
