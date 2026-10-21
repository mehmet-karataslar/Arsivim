import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/belge_modeli.dart';
import '../utils/sabitler.dart';
import 'log_servisi.dart';

/// Gelişmiş cache servisi - LRU, platform optimization, memory management
class CacheServisi {
  static final CacheServisi _instance = CacheServisi._internal();
  factory CacheServisi() => _instance;
  CacheServisi._internal();

  final LogServisi _logServisi = LogServisi.instance;

  // Cache state management
  bool _initialized = false;
  final Map<String, _CacheEntry> _memoryCache = {};
  final Queue<String> _accessOrder = Queue<String>();

  // Platform-specific cache limits
  late final int _maxMemoryItems;
  late final int _maxStorageItems;
  late final Duration _cacheExpiry;

  // Cache metrics
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  // Cache keys
  static const String _belgeCacheKey = 'belge_cache';
  static const String _cacheTimeKey = 'cache_time';
  static const String _istatistikCacheKey = 'istatistik_cache';
  static const String _cacheMetricsKey = 'cache_metrics';

  /// Initialize cache with platform-specific settings
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logServisi.info('🚀 Cache servisi başlatılıyor...');

      // Platform-specific cache limits
      _setPlatformSpecificLimits();

      // Load existing cache metrics
      await _loadCacheMetrics();

      // Auto-cleanup initialization
      _startAutoCleanup();

      _initialized = true;
      _logServisi.info(
        '✅ Cache servisi başlatıldı (Memory: $_maxMemoryItems, Storage: $_maxStorageItems)',
      );
    } catch (e) {
      _logServisi.error('❌ Cache servisi başlatma hatası: $e');
    }
  }

  /// Set platform-specific cache limits
  void _setPlatformSpecificLimits() {
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: Conservative limits
      _maxMemoryItems = 100;
      _maxStorageItems = 500;
      _cacheExpiry = const Duration(minutes: 30);
    } else {
      // Desktop: Generous limits
      _maxMemoryItems = 1000;
      _maxStorageItems = 5000;
      _cacheExpiry = const Duration(hours: 2);
    }
  }

  /// Load cache metrics from storage
  Future<void> _loadCacheMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metricsData = prefs.getString(_cacheMetricsKey);

      if (metricsData != null) {
        final metrics = json.decode(metricsData);
        _hitCount = metrics['hitCount'] ?? 0;
        _missCount = metrics['missCount'] ?? 0;
        _evictionCount = metrics['evictionCount'] ?? 0;
      }
    } catch (e) {
      _logServisi.error('❌ Cache metrics yüklenme hatası: $e');
    }
  }

  /// Save cache metrics to storage
  Future<void> _saveCacheMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metrics = {
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': getHitRate(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_cacheMetricsKey, json.encode(metrics));
    } catch (e) {
      _logServisi.error('❌ Cache metrics kaydetme hatası: $e');
    }
  }

  /// Start auto-cleanup timer
  void _startAutoCleanup() {
    // Cleanup every 5 minutes on mobile, 10 minutes on desktop
    final cleanupInterval =
        Platform.isAndroid || Platform.isIOS
            ? const Duration(minutes: 5)
            : const Duration(minutes: 10);

    Timer.periodic(cleanupInterval, (timer) async {
      await _performAutoCleanup();
    });
  }

  /// Perform automatic cleanup
  Future<void> _performAutoCleanup() async {
    try {
      final beforeCount = _memoryCache.length;

      // Remove expired entries
      await _removeExpiredEntries();

      // Enforce memory limits
      _enforceMemoryLimits();

      // Save metrics
      await _saveCacheMetrics();

      final afterCount = _memoryCache.length;
      if (beforeCount != afterCount) {
        _logServisi.info('🧹 Auto-cleanup: $beforeCount → $afterCount items');
      }
    } catch (e) {
      _logServisi.error('❌ Auto-cleanup hatası: $e');
    }
  }

  /// Remove expired entries from memory cache
  Future<void> _removeExpiredEntries() async {
    final expiredKeys = <String>[];
    final now = DateTime.now();

    for (final entry in _memoryCache.entries) {
      if (now.difference(entry.value.timestamp) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _accessOrder.remove(key);
      _evictionCount++;
    }
  }

  /// Enforce memory limits using LRU eviction
  void _enforceMemoryLimits() {
    while (_memoryCache.length > _maxMemoryItems) {
      final oldestKey = _accessOrder.removeFirst();
      _memoryCache.remove(oldestKey);
      _evictionCount++;
    }
  }

  /// Update access order for LRU
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.addLast(key);
  }

  /// Belgeler cache'i - Enhanced version
  Future<void> belgeleriCacheEt(List<BelgeModeli> belgeler) async {
    await _ensureInitialized();

    try {
      final cacheKey = _belgeCacheKey;
      final timestamp = DateTime.now();

      // Limit the number of items based on platform
      final cachedBelgeler = belgeler.take(_maxStorageItems).toList();

      // Store in memory cache
      _memoryCache[cacheKey] = _CacheEntry(
        data: cachedBelgeler,
        timestamp: timestamp,
        accessCount: 1,
      );
      _updateAccessOrder(cacheKey);

      // Store in persistent storage
      final prefs = await SharedPreferences.getInstance();
      final belgelerJson = cachedBelgeler.map((b) => b.toMap()).toList();
      await prefs.setString(cacheKey, json.encode(belgelerJson));
      await prefs.setInt(_cacheTimeKey, timestamp.millisecondsSinceEpoch);

      _logServisi.info('💾 Cache: ${cachedBelgeler.length} belge kaydedildi');
    } catch (e) {
      _logServisi.error('❌ Cache hatası: $e');
    }
  }

  /// Belgeler cache'ini getir - Enhanced version
  Future<List<BelgeModeli>?> cachedBelgeleriGetir() async {
    await _ensureInitialized();

    try {
      final cacheKey = _belgeCacheKey;

      // Check memory cache first
      final memoryEntry = _memoryCache[cacheKey];
      if (memoryEntry != null && !_isExpired(memoryEntry.timestamp)) {
        memoryEntry.accessCount++;
        _updateAccessOrder(cacheKey);
        _hitCount++;

        _logServisi.info(
          '⚡ Memory cache hit: ${(memoryEntry.data as List).length} belge',
        );
        return memoryEntry.data as List<BelgeModeli>;
      }

      // Check persistent storage
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt(_cacheTimeKey) ?? 0;
      final cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(cacheTime);

      if (_isExpired(cacheTimestamp)) {
        _logServisi.info('⏰ Cache süresi doldu, temizleniyor');
        await cacheyiTemizle();
        _missCount++;
        return null;
      }

      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List<dynamic> belgelerJson = json.decode(cachedData);
        final belgeler =
            belgelerJson.map((json) => BelgeModeli.fromMap(json)).toList();

        // Store in memory cache for future access
        _memoryCache[cacheKey] = _CacheEntry(
          data: belgeler,
          timestamp: cacheTimestamp,
          accessCount: 1,
        );
        _updateAccessOrder(cacheKey);

        _hitCount++;
        _logServisi.info('💽 Storage cache hit: ${belgeler.length} belge');
        return belgeler;
      }

      _missCount++;
      return null;
    } catch (e) {
      _logServisi.error('❌ Cache okuma hatası: $e');
      _missCount++;
      return null;
    }
  }

  /// İstatistik cache'i - Enhanced version
  Future<void> istatistikleriCacheEt(Map<String, dynamic> istatistikler) async {
    await _ensureInitialized();

    try {
      final cacheKey = _istatistikCacheKey;
      final timestamp = DateTime.now();

      // Store in memory cache
      _memoryCache[cacheKey] = _CacheEntry(
        data: istatistikler,
        timestamp: timestamp,
        accessCount: 1,
      );
      _updateAccessOrder(cacheKey);

      // Store in persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, json.encode(istatistikler));
      await prefs.setInt('${cacheKey}_time', timestamp.millisecondsSinceEpoch);

      _logServisi.info('📊 İstatistik cache güncellendi');
    } catch (e) {
      _logServisi.error('❌ İstatistik cache hatası: $e');
    }
  }

  /// İstatistik cache'ini getir - Enhanced version
  Future<Map<String, dynamic>?> cachedIstatistikleriGetir() async {
    await _ensureInitialized();

    try {
      final cacheKey = _istatistikCacheKey;

      // Check memory cache first
      final memoryEntry = _memoryCache[cacheKey];
      if (memoryEntry != null && !_isExpired(memoryEntry.timestamp)) {
        memoryEntry.accessCount++;
        _updateAccessOrder(cacheKey);
        _hitCount++;

        return memoryEntry.data as Map<String, dynamic>;
      }

      // Check persistent storage
      final prefs = await SharedPreferences.getInstance();
      final cacheTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final cacheTimestamp = DateTime.fromMillisecondsSinceEpoch(cacheTime);

      if (_isExpired(cacheTimestamp)) {
        _missCount++;
        return null;
      }

      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final istatistikler = json.decode(cachedData) as Map<String, dynamic>;

        // Store in memory cache
        _memoryCache[cacheKey] = _CacheEntry(
          data: istatistikler,
          timestamp: cacheTimestamp,
          accessCount: 1,
        );
        _updateAccessOrder(cacheKey);

        _hitCount++;
        return istatistikler;
      }

      _missCount++;
      return null;
    } catch (e) {
      _logServisi.error('❌ İstatistik cache okuma hatası: $e');
      _missCount++;
      return null;
    }
  }

  /// Cache'i temizle - Enhanced version
  Future<void> cacheyiTemizle() async {
    await _ensureInitialized();

    try {
      // Clear memory cache
      _memoryCache.clear();
      _accessOrder.clear();

      // Clear persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_belgeCacheKey);
      await prefs.remove(_cacheTimeKey);
      await prefs.remove(_istatistikCacheKey);
      await prefs.remove('${_istatistikCacheKey}_time');

      _logServisi.info('🧹 Cache tamamen temizlendi');
    } catch (e) {
      _logServisi.error('❌ Cache temizleme hatası: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'hitCount': _hitCount,
      'missCount': _missCount,
      'evictionCount': _evictionCount,
      'hitRate': getHitRate(),
      'memoryItems': _memoryCache.length,
      'maxMemoryItems': _maxMemoryItems,
      'maxStorageItems': _maxStorageItems,
      'cacheExpiry': _cacheExpiry.inMinutes,
      'platform': Platform.operatingSystem,
    };
  }

  /// Get cache hit rate
  double getHitRate() {
    final totalRequests = _hitCount + _missCount;
    return totalRequests > 0 ? _hitCount / totalRequests : 0.0;
  }

  /// Check if cache entry is expired
  bool _isExpired(DateTime timestamp) {
    return DateTime.now().difference(timestamp) > _cacheExpiry;
  }

  /// Ensure cache is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Dispose cache resources
  Future<void> dispose() async {
    try {
      await _saveCacheMetrics();
      _memoryCache.clear();
      _accessOrder.clear();
      _initialized = false;

      _logServisi.info('🔄 Cache servisi kapatıldı');
    } catch (e) {
      _logServisi.error('❌ Cache dispose hatası: $e');
    }
  }
}

/// Cache entry with metadata
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  int accessCount;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    this.accessCount = 0,
  });
}
