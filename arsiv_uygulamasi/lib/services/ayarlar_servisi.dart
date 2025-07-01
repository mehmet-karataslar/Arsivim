import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'veritabani_servisi.dart';

enum TemaSecenek { sistem, acik, koyu }

class AyarlarServisi {
  static const String _temaAnahtari = 'tema_secenegi';
  static const String _otomatikYedeklemeAnahtari = 'otomatik_yedekleme';
  static const String _yedeklemeAraligi = 'yedekleme_araligi';
  static const String _bildirimlereIzinAnahtari = 'bildirimler_izin';

  static AyarlarServisi? _instance;
  static AyarlarServisi get instance => _instance ??= AyarlarServisi._();
  AyarlarServisi._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // TEMA YÖNETİMİ
  Future<TemaSecenek> getTemaSecenegi() async {
    await init();
    final index = _prefs!.getInt(_temaAnahtari) ?? 0;
    return TemaSecenek.values[index];
  }

  Future<void> setTemaSecenegi(TemaSecenek tema) async {
    await init();
    await _prefs!.setInt(_temaAnahtari, tema.index);
  }

  ThemeMode getThemeMode(TemaSecenek tema) {
    switch (tema) {
      case TemaSecenek.sistem:
        return ThemeMode.system;
      case TemaSecenek.acik:
        return ThemeMode.light;
      case TemaSecenek.koyu:
        return ThemeMode.dark;
    }
  }

  // DİL YÖNETİMİ - Sadece Türkçe destekleniyor
  String getDilSecenegi() {
    return 'tr'; // Sabit Türkçe
  }

  // YEDEKLEME AYARLARI
  Future<bool> getOtomatikYedekleme() async {
    await init();
    return _prefs!.getBool(_otomatikYedeklemeAnahtari) ?? false;
  }

  Future<void> setOtomatikYedekleme(bool aktif) async {
    await init();
    await _prefs!.setBool(_otomatikYedeklemeAnahtari, aktif);
  }

  Future<int> getYedeklemeAraligi() async {
    await init();
    return _prefs!.getInt(_yedeklemeAraligi) ?? 7; // Varsayılan 7 gün
  }

  Future<void> setYedeklemeAraligi(int gun) async {
    await init();
    await _prefs!.setInt(_yedeklemeAraligi, gun);
  }

  // BİLDİRİM AYARLARI
  Future<bool> getBildirimlereIzin() async {
    await init();
    return _prefs!.getBool(_bildirimlereIzinAnahtari) ?? true;
  }

  Future<void> setBildirimlereIzin(bool izin) async {
    await init();
    await _prefs!.setBool(_bildirimlereIzinAnahtari, izin);
  }

  // VERİTABANI YEDEKLEME/GERİ YÜKLEME
  Future<String> veritabaniYedekle() async {
    try {
      final veriTabani = VeriTabaniServisi();
      final dbPath = await VeriTabaniServisi.veritabaniYolu();

      // Yedekleme klasörü oluştur
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(documentsDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Yedek dosya adı (tarih ile)
      final now = DateTime.now();
      final backupFileName =
          'arsiv_yedek_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.db';
      final backupPath = join(backupDir.path, backupFileName);

      // Veritabanı dosyasını kopyala
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        return backupPath;
      } else {
        throw Exception('Veritabanı dosyası bulunamadı');
      }
    } catch (e) {
      throw Exception('Yedekleme hatası: $e');
    }
  }

  Future<void> veritabaniGeriYukle(String yedekDosyaYolu) async {
    try {
      final veriTabani = VeriTabaniServisi();
      final dbPath = await VeriTabaniServisi.veritabaniYolu();

      // Mevcut veritabanını kapat
      await veriTabani.kapat();

      // Yedek dosyasını kontrol et
      final backupFile = File(yedekDosyaYolu);
      if (!await backupFile.exists()) {
        throw Exception('Yedek dosyası bulunamadı');
      }

      // Yedek dosyasını veritabanı konumuna kopyala
      await backupFile.copy(dbPath);

      // Veritabanını yeniden başlat
      await veriTabani.database;
    } catch (e) {
      throw Exception('Geri yükleme hatası: $e');
    }
  }

  Future<List<String>> yedekDosyalariniListele() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(documentsDir.path, 'backups'));

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      final backupFiles =
          files
              .where((file) => file is File && file.path.endsWith('.db'))
              .map((file) => file.path)
              .toList();

      // Tarihe göre sırala (en yeni önce)
      backupFiles.sort((a, b) => b.compareTo(a));

      return backupFiles;
    } catch (e) {
      return [];
    }
  }

  Future<void> yedekDosyasiniSil(String dosyaYolu) async {
    try {
      final file = File(dosyaYolu);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Yedek dosyası silinirken hata: $e');
    }
  }

  // UYGULAMA BİLGİLERİ
  Map<String, dynamic> getUygulamaBilgileri() {
    return {
      'versiyon': '1.0.0',
      'yapim_tarihi': '2025',
      'gelistirici': 'Arşivim Ekibi',
    };
  }

  // AYARLARI SIFIRLA
  Future<void> ayarlariSifirla() async {
    await init();
    await _prefs!.clear();
  }
}
