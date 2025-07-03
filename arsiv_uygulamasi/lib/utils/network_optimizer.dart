import 'dart:io';
import 'dart:math';
import 'dart:async';

/// Ağ optimizasyonu ve network performance utilities
class NetworkOptimizer {
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  static NetworkOptimizer get instance => _instance;
  NetworkOptimizer._internal();

  // Network state
  ConnectionQuality _currentQuality = ConnectionQuality.unknown;
  double _bandwidth = 0.0; // bytes per second
  int _latency = 0; // milliseconds
  double _packetLoss = 0.0; // percentage
  DateTime? _lastQualityCheck;

  // Configuration
  int _maxConcurrentConnections = 3;
  Duration _connectionTimeout = const Duration(seconds: 30);
  Duration _readTimeout = const Duration(seconds: 60);
  int _maxRetries = 3;
  Duration _retryDelay = const Duration(seconds: 2);

  /// Network kalitesini test et
  Future<NetworkQualityResult> testNetworkQuality(String serverUrl) async {
    try {
      final startTime = DateTime.now();

      // Latency test
      final latency = await _measureLatency(serverUrl);

      // Bandwidth test
      final bandwidth = await _measureBandwidth(serverUrl);

      // Packet loss test (simplified)
      final packetLoss = await _measurePacketLoss(serverUrl);

      final endTime = DateTime.now();
      final testDuration = endTime.difference(startTime);

      // Quality assessment
      final quality = _assessConnectionQuality(bandwidth, latency, packetLoss);

      // Cache results
      _currentQuality = quality;
      _bandwidth = bandwidth;
      _latency = latency;
      _packetLoss = packetLoss;
      _lastQualityCheck = endTime;

      return NetworkQualityResult(
        quality: quality,
        bandwidth: bandwidth,
        latency: latency,
        packetLoss: packetLoss,
        testDuration: testDuration,
        timestamp: endTime,
      );
    } catch (e) {
      return NetworkQualityResult(
        quality: ConnectionQuality.poor,
        bandwidth: 0.0,
        latency: 9999,
        packetLoss: 100.0,
        testDuration: Duration.zero,
        timestamp: DateTime.now(),
        error: 'Network test hatası: $e',
      );
    }
  }

  /// Latency ölçümü
  Future<int> _measureLatency(String serverUrl) async {
    final pings = <int>[];

    for (int i = 0; i < 3; i++) {
      try {
        final startTime = DateTime.now().millisecondsSinceEpoch;

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);

        final request = await client.headUrl(Uri.parse(serverUrl));
        final response = await request.close();

        final endTime = DateTime.now().millisecondsSinceEpoch;
        final ping = endTime - startTime;

        if (response.statusCode == 200 || response.statusCode == 404) {
          pings.add(ping);
        }

        client.close();
      } catch (e) {
        pings.add(9999); // High latency for failed pings
      }
    }

    return pings.isEmpty
        ? 9999
        : (pings.reduce((a, b) => a + b) / pings.length).round();
  }

  /// Bandwidth ölçümü
  Future<double> _measureBandwidth(String serverUrl) async {
    try {
      const testSize = 1024 * 100; // 100KB test
      final startTime = DateTime.now();

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$serverUrl/test'));
      final response = await request.close();

      int bytesReceived = 0;
      await for (final chunk in response) {
        bytesReceived += chunk.length;
        if (bytesReceived >= testSize) break;
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      client.close();

      if (duration.inMilliseconds > 0) {
        return bytesReceived / (duration.inMilliseconds / 1000.0);
      }
    } catch (e) {
      // Fallback to minimal bandwidth
    }

    return 1024.0; // 1KB/s fallback
  }

  /// Packet loss ölçümü (basitleştirilmiş)
  Future<double> _measurePacketLoss(String serverUrl) async {
    int successful = 0;
    const totalTests = 5;

    for (int i = 0; i < totalTests; i++) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);

        final request = await client.headUrl(Uri.parse(serverUrl));
        final response = await request.close();

        if (response.statusCode < 500) {
          successful++;
        }

        client.close();
      } catch (e) {
        // Failed request counts as packet loss
      }
    }

    return ((totalTests - successful) / totalTests) * 100.0;
  }

  /// Connection quality assessment
  ConnectionQuality _assessConnectionQuality(
    double bandwidth,
    int latency,
    double packetLoss,
  ) {
    if (packetLoss > 5.0 || latency > 1000) {
      return ConnectionQuality.poor;
    } else if (bandwidth > 1024 * 1024 && latency < 100 && packetLoss < 1.0) {
      return ConnectionQuality.excellent;
    } else if (bandwidth > 512 * 1024 && latency < 300 && packetLoss < 2.0) {
      return ConnectionQuality.good;
    } else if (bandwidth > 128 * 1024 && latency < 500 && packetLoss < 3.0) {
      return ConnectionQuality.fair;
    } else {
      return ConnectionQuality.poor;
    }
  }

  /// Optimal transfer parametrelerini hesapla
  TransferParameters calculateOptimalParameters() {
    final quality = _currentQuality;

    switch (quality) {
      case ConnectionQuality.excellent:
        return TransferParameters(
          maxConcurrentConnections: 5,
          chunkSize: 1024 * 1024, // 1MB
          timeout: const Duration(seconds: 60),
          retryAttempts: 2,
          retryDelay: const Duration(seconds: 1),
        );

      case ConnectionQuality.good:
        return TransferParameters(
          maxConcurrentConnections: 3,
          chunkSize: 512 * 1024, // 512KB
          timeout: const Duration(seconds: 45),
          retryAttempts: 3,
          retryDelay: const Duration(seconds: 2),
        );

      case ConnectionQuality.fair:
        return TransferParameters(
          maxConcurrentConnections: 2,
          chunkSize: 256 * 1024, // 256KB
          timeout: const Duration(seconds: 30),
          retryAttempts: 3,
          retryDelay: const Duration(seconds: 3),
        );

      case ConnectionQuality.poor:
        return TransferParameters(
          maxConcurrentConnections: 1,
          chunkSize: 128 * 1024, // 128KB
          timeout: const Duration(seconds: 20),
          retryAttempts: 5,
          retryDelay: const Duration(seconds: 5),
        );

      case ConnectionQuality.unknown:
      default:
        return TransferParameters(
          maxConcurrentConnections: 2,
          chunkSize: 256 * 1024, // 256KB
          timeout: const Duration(seconds: 30),
          retryAttempts: 3,
          retryDelay: const Duration(seconds: 3),
        );
    }
  }

  /// Transfer hızını optimize et
  Future<OptimizedTransferResult> optimizeTransfer({
    required int totalBytes,
    required Function(int bytes) onChunkTransferred,
    Function(double progress)? onProgress,
  }) async {
    final parameters = calculateOptimalParameters();
    final startTime = DateTime.now();

    try {
      int transferredBytes = 0;
      final chunkSize = parameters.chunkSize;
      final totalChunks = (totalBytes / chunkSize).ceil();

      // Adaptive chunk size based on performance
      var adaptiveChunkSize = chunkSize;
      var performanceHistory = <double>[];

      for (int i = 0; i < totalChunks; i++) {
        final chunkStart = DateTime.now();

        final currentChunkSize = min(
          adaptiveChunkSize,
          totalBytes - transferredBytes,
        );

        // Simulate chunk transfer
        await onChunkTransferred(currentChunkSize);
        transferredBytes += currentChunkSize;

        final chunkEnd = DateTime.now();
        final chunkDuration = chunkEnd.difference(chunkStart);

        // Calculate performance and adapt
        final chunkSpeed =
            currentChunkSize / chunkDuration.inMilliseconds * 1000;
        performanceHistory.add(chunkSpeed);

        // Adaptive chunk size adjustment
        if (performanceHistory.length >= 3) {
          final avgSpeed =
              performanceHistory.take(3).reduce((a, b) => a + b) / 3;

          if (avgSpeed > _bandwidth * 0.8) {
            // Good performance, increase chunk size
            adaptiveChunkSize =
                min(adaptiveChunkSize * 1.2, 2 * 1024 * 1024).round();
          } else if (avgSpeed < _bandwidth * 0.3) {
            // Poor performance, decrease chunk size
            adaptiveChunkSize = max(adaptiveChunkSize * 0.8, 64 * 1024).round();
          }

          // Keep only recent history
          if (performanceHistory.length > 5) {
            performanceHistory.removeAt(0);
          }
        }

        // Progress update
        if (onProgress != null) {
          final progress = transferredBytes / totalBytes;
          onProgress(progress);
        }

        // Break if complete
        if (transferredBytes >= totalBytes) break;
      }

      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime);
      final averageSpeed = totalBytes / totalDuration.inMilliseconds * 1000;

      return OptimizedTransferResult(
        success: true,
        transferredBytes: transferredBytes,
        totalDuration: totalDuration,
        averageSpeed: averageSpeed,
        chunksUsed: totalChunks,
        adaptiveChunkSize: adaptiveChunkSize,
      );
    } catch (e) {
      return OptimizedTransferResult(
        success: false,
        transferredBytes: 0,
        totalDuration: Duration.zero,
        averageSpeed: 0.0,
        chunksUsed: 0,
        adaptiveChunkSize: 0,
        error: 'Transfer optimization hatası: $e',
      );
    }
  }

  /// Connection pooling optimization
  ConnectionPool createConnectionPool(String serverUrl) {
    final parameters = calculateOptimalParameters();

    return ConnectionPool(
      serverUrl: serverUrl,
      maxConnections: parameters.maxConcurrentConnections,
      connectionTimeout: parameters.timeout,
      idleTimeout: const Duration(minutes: 5),
    );
  }

  /// Retry strategy oluştur
  RetryStrategy createRetryStrategy() {
    final parameters = calculateOptimalParameters();

    return RetryStrategy(
      maxAttempts: parameters.retryAttempts,
      baseDelay: parameters.retryDelay,
      maxDelay: const Duration(minutes: 5),
      backoffMultiplier: 2.0,
      jitter: true,
    );
  }

  /// Network stats
  NetworkStats getCurrentStats() {
    return NetworkStats(
      quality: _currentQuality,
      bandwidth: _bandwidth,
      latency: _latency,
      packetLoss: _packetLoss,
      lastCheck: _lastQualityCheck,
      optimalChunkSize: calculateOptimalParameters().chunkSize,
      maxConcurrentConnections:
          calculateOptimalParameters().maxConcurrentConnections,
    );
  }

  /// Reset optimizations
  void reset() {
    _currentQuality = ConnectionQuality.unknown;
    _bandwidth = 0.0;
    _latency = 0;
    _packetLoss = 0.0;
    _lastQualityCheck = null;
  }
}

/// Network quality sonucu
class NetworkQualityResult {
  final ConnectionQuality quality;
  final double bandwidth; // bytes per second
  final int latency; // milliseconds
  final double packetLoss; // percentage
  final Duration testDuration;
  final DateTime timestamp;
  final String? error;

  NetworkQualityResult({
    required this.quality,
    required this.bandwidth,
    required this.latency,
    required this.packetLoss,
    required this.testDuration,
    required this.timestamp,
    this.error,
  });

  String get formattedBandwidth {
    if (bandwidth > 1024 * 1024) {
      return '${(bandwidth / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (bandwidth > 1024) {
      return '${(bandwidth / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${bandwidth.toStringAsFixed(2)} B/s';
    }
  }

  @override
  String toString() {
    return 'NetworkQuality(${quality.name}, $formattedBandwidth, ${latency}ms, ${packetLoss.toStringAsFixed(1)}% loss)';
  }
}

/// Transfer parametreleri
class TransferParameters {
  final int maxConcurrentConnections;
  final int chunkSize;
  final Duration timeout;
  final int retryAttempts;
  final Duration retryDelay;

  TransferParameters({
    required this.maxConcurrentConnections,
    required this.chunkSize,
    required this.timeout,
    required this.retryAttempts,
    required this.retryDelay,
  });
}

/// Optimized transfer sonucu
class OptimizedTransferResult {
  final bool success;
  final int transferredBytes;
  final Duration totalDuration;
  final double averageSpeed;
  final int chunksUsed;
  final int adaptiveChunkSize;
  final String? error;

  OptimizedTransferResult({
    required this.success,
    required this.transferredBytes,
    required this.totalDuration,
    required this.averageSpeed,
    required this.chunksUsed,
    required this.adaptiveChunkSize,
    this.error,
  });

  String get formattedSpeed {
    if (averageSpeed > 1024 * 1024) {
      return '${(averageSpeed / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else if (averageSpeed > 1024) {
      return '${(averageSpeed / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${averageSpeed.toStringAsFixed(2)} B/s';
    }
  }
}

/// Connection pool
class ConnectionPool {
  final String serverUrl;
  final int maxConnections;
  final Duration connectionTimeout;
  final Duration idleTimeout;
  final List<HttpClient> _pool = [];
  final List<DateTime> _lastUsed = [];

  ConnectionPool({
    required this.serverUrl,
    required this.maxConnections,
    required this.connectionTimeout,
    required this.idleTimeout,
  });

  /// Get connection from pool
  HttpClient getConnection() {
    _cleanupIdleConnections();

    if (_pool.isNotEmpty) {
      final client = _pool.removeAt(0);
      _lastUsed.removeAt(0);
      return client;
    }

    final client = HttpClient();
    client.connectionTimeout = connectionTimeout;
    return client;
  }

  /// Return connection to pool
  void returnConnection(HttpClient client) {
    if (_pool.length < maxConnections) {
      _pool.add(client);
      _lastUsed.add(DateTime.now());
    } else {
      client.close();
    }
  }

  /// Cleanup idle connections
  void _cleanupIdleConnections() {
    final now = DateTime.now();
    final toRemove = <int>[];

    for (int i = 0; i < _lastUsed.length; i++) {
      if (now.difference(_lastUsed[i]) > idleTimeout) {
        toRemove.add(i);
      }
    }

    for (int i = toRemove.length - 1; i >= 0; i--) {
      final index = toRemove[i];
      _pool[index].close();
      _pool.removeAt(index);
      _lastUsed.removeAt(index);
    }
  }

  /// Close all connections
  void dispose() {
    for (final client in _pool) {
      client.close();
    }
    _pool.clear();
    _lastUsed.clear();
  }
}

/// Retry strategy
class RetryStrategy {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool jitter;

  RetryStrategy({
    required this.maxAttempts,
    required this.baseDelay,
    required this.maxDelay,
    required this.backoffMultiplier,
    required this.jitter,
  });

  /// Calculate delay for attempt
  Duration calculateDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    var delay = baseDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1);
    delay = min(delay, maxDelay.inMilliseconds.toDouble());

    if (jitter) {
      final jitterAmount = delay * 0.1;
      final random = Random();
      delay += (random.nextDouble() * 2 - 1) * jitterAmount;
    }

    return Duration(milliseconds: delay.round());
  }

  /// Execute with retry
  Future<T> execute<T>(Future<T> Function() operation) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt < maxAttempts) {
          final delay = calculateDelay(attempt);
          await Future.delayed(delay);
        }
      }
    }

    throw lastException!;
  }
}

/// Network istatistikleri
class NetworkStats {
  final ConnectionQuality quality;
  final double bandwidth;
  final int latency;
  final double packetLoss;
  final DateTime? lastCheck;
  final int optimalChunkSize;
  final int maxConcurrentConnections;

  NetworkStats({
    required this.quality,
    required this.bandwidth,
    required this.latency,
    required this.packetLoss,
    this.lastCheck,
    required this.optimalChunkSize,
    required this.maxConcurrentConnections,
  });

  Map<String, dynamic> toJson() {
    return {
      'quality': quality.name,
      'bandwidth': bandwidth,
      'latency': latency,
      'packetLoss': packetLoss,
      'lastCheck': lastCheck?.toIso8601String(),
      'optimalChunkSize': optimalChunkSize,
      'maxConcurrentConnections': maxConcurrentConnections,
    };
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

  String get description {
    switch (this) {
      case ConnectionQuality.unknown:
        return 'Bağlantı kalitesi test edilmedi';
      case ConnectionQuality.poor:
        return 'Yavaş bağlantı, düşük performans';
      case ConnectionQuality.fair:
        return 'Orta kalite bağlantı';
      case ConnectionQuality.good:
        return 'İyi kalite bağlantı';
      case ConnectionQuality.excellent:
        return 'Mükemmel kalite bağlantı';
    }
  }
}
