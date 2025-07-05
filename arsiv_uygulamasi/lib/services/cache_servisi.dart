import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/belge_modeli.dart';
import '../utils/sabitler.dart';

class CacheServisi {
  static final CacheServisi _instance = CacheServisi._internal();
  factory CacheServisi() => _instance;
  CacheServisi._internal();

  static const String _belgeCacheKey = 'belge_cache';
  static const String _cacheTimeKey = 'cache_time';
  static const String _istatistikCacheKey = 'istatistik_cache';

  void _debugPrint(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // Belgeler cache'i
  Future<void> belgeleriCacheEt(List<BelgeModeli> belgeler) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Sadece ilk N belgeyi cache'le
      final cachedBelgeler =
          belgeler.take(Sabitler.MAKSIMUM_BELGE_CACHE).toList();

      final belgelerJson = cachedBelgeler.map((b) => b.toMap()).toList();
      await prefs.setString(_belgeCacheKey, json.encode(belgelerJson));
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      _debugPrint('Cache: ${cachedBelgeler.length} belge kaydedildi');
    } catch (e) {
      _debugPrint('Cache hatasi: $e');
    }
  }

  // Belgeler cache'ini getir
  Future<List<BelgeModeli>?> cachedBelgeleriGetir() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache süresi kontrolü
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = Duration(milliseconds: now - cacheTime);

      if (cacheAge.inMinutes > Sabitler.CACHE_SURESI_DAKIKA) {
        _debugPrint('Cache suresi doldu, temizleniyor');
        await cacheyiTemizle();
        return null;
      }

      final cachedData = prefs.getString(_belgeCacheKey);
      if (cachedData != null) {
        final List<dynamic> belgelerJson = json.decode(cachedData);
        final belgeler =
            belgelerJson.map((json) => BelgeModeli.fromMap(json)).toList();
        _debugPrint('Cache: ${belgeler.length} belge alindi');
        return belgeler;
      }

      return null;
    } catch (e) {
      _debugPrint('Cache okuma hatasi: $e');
      return null;
    }
  }

  // İstatistik cache'i
  Future<void> istatistikleriCacheEt(Map<String, dynamic> istatistikler) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_istatistikCacheKey, json.encode(istatistikler));
      await prefs.setInt(
        '${_istatistikCacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _debugPrint('Istatistik cache hatasi: $e');
    }
  }

  // İstatistik cache'ini getir
  Future<Map<String, dynamic>?> cachedIstatistikleriGetir() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache süresi kontrolü
      final cacheTime = prefs.getInt('${_istatistikCacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = Duration(milliseconds: now - cacheTime);

      if (cacheAge.inMinutes > Sabitler.CACHE_SURESI_DAKIKA) {
        return null;
      }

      final cachedData = prefs.getString(_istatistikCacheKey);
      if (cachedData != null) {
        return json.decode(cachedData);
      }

      return null;
    } catch (e) {
      _debugPrint('Istatistik cache okuma hatasi: $e');
      return null;
    }
  }

  // Cache'i temizle
  Future<void> cacheyiTemizle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_belgeCacheKey);
      await prefs.remove(_cacheTimeKey);
      await prefs.remove(_istatistikCacheKey);
      await prefs.remove('${_istatistikCacheKey}_time');
      _debugPrint('Cache temizlendi');
    } catch (e) {
      _debugPrint('Cache temizleme hatasi: $e');
    }
  }
}
