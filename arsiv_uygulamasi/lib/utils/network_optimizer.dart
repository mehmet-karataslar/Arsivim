import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

/// SADELEŞTİRİLMİŞ Network optimization utilities
/// Sadece temel network işlemleri
class NetworkOptimizer {
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  static NetworkOptimizer get instance => _instance;
  NetworkOptimizer._internal();

  // Network state
  ConnectionQuality _currentQuality = ConnectionQuality.unknown;
  DateTime? _lastQualityCheck;

  /// Network kalitesini test et
  Future<NetworkQualityResult> testNetworkQuality(String serverUrl) async {
    try {
      final startTime = DateTime.now();

      // Basit ping testi
      final latency = await _measureLatency(serverUrl);

      // Quality assessment - basit yaklaşım
      final quality = _assessConnectionQuality(latency);

      final endTime = DateTime.now();
      final testDuration = endTime.difference(startTime);

      _currentQuality = quality;
      _lastQualityCheck = endTime;

      return NetworkQualityResult(
        quality: quality,
        latency: latency,
        testDuration: testDuration,
        timestamp: endTime,
      );
    } catch (e) {
      return NetworkQualityResult(
        quality: ConnectionQuality.poor,
        latency: 9999,
        testDuration: Duration.zero,
        timestamp: DateTime.now(),
        error: 'Network test hatası: $e',
      );
    }
  }

  /// Basit latency ölçümü
  Future<int> _measureLatency(String serverUrl) async {
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;

      final response = await http
          .head(Uri.parse(serverUrl))
          .timeout(const Duration(seconds: 5));

      final endTime = DateTime.now().millisecondsSinceEpoch;

      if (response.statusCode < 500) {
        return endTime - startTime;
      }
    } catch (e) {
      // Hata durumunda yüksek latency
    }

    return 9999;
  }

  /// Basit connection quality assessment
  ConnectionQuality _assessConnectionQuality(int latency) {
    if (latency > 2000) {
      return ConnectionQuality.poor;
    } else if (latency > 1000) {
      return ConnectionQuality.fair;
    } else if (latency > 500) {
      return ConnectionQuality.good;
    } else {
      return ConnectionQuality.excellent;
    }
  }

  /// Basit bağlantı testi
  Future<bool> testConnection(String remoteIP) async {
    try {
      final uri = Uri.parse('http://$remoteIP:8080/status');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Current quality
  ConnectionQuality get currentQuality => _currentQuality;

  /// Reset
  void reset() {
    _currentQuality = ConnectionQuality.unknown;
    _lastQualityCheck = null;
  }
}

/// Network quality sonucu
class NetworkQualityResult {
  final ConnectionQuality quality;
  final int latency;
  final Duration testDuration;
  final DateTime timestamp;
  final String? error;

  NetworkQualityResult({
    required this.quality,
    required this.latency,
    required this.testDuration,
    required this.timestamp,
    this.error,
  });

  @override
  String toString() {
    return 'NetworkQuality(${quality.name}, ${latency}ms)';
  }
}

/// Connection quality enum
enum ConnectionQuality { unknown, poor, fair, good, excellent }

/// Connection quality uzantıları
extension ConnectionQualityExtension on ConnectionQuality {
  String get displayName {
    switch (this) {
      case ConnectionQuality.unknown:
        return 'Bilinmiyor';
      case ConnectionQuality.poor:
        return 'Zayıf';
      case ConnectionQuality.fair:
        return 'Orta';
      case ConnectionQuality.good:
        return 'İyi';
      case ConnectionQuality.excellent:
        return 'Mükemmel';
    }
  }
}
