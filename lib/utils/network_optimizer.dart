import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import '../services/log_servisi.dart';

/// Gelişmiş Network optimization utilities
/// HTTP client pooling, retry mechanism, circuit breaker, adaptive timeouts
class NetworkOptimizer {
  static final NetworkOptimizer _instance = NetworkOptimizer._internal();
  static NetworkOptimizer get instance => _instance;
  NetworkOptimizer._internal();

  final LogServisi _logServisi = LogServisi.instance;

  // Network state
  ConnectionQuality _currentQuality = ConnectionQuality.unknown;
  DateTime? _lastQualityCheck;
  bool _isOnline = true;

  // Connection pooling
  final Map<String, http.Client> _clientPool = {};
  final Map<String, DateTime> _clientLastUsed = {};
  static const int _maxPoolSize = 5;
  static const Duration _clientIdleTimeout = Duration(minutes: 5);

  // Circuit breaker
  final Map<String, CircuitBreakerState> _circuitBreakers = {};

  // Request queue for poor network conditions
  final Queue<QueuedRequest> _requestQueue = Queue<QueuedRequest>();
  bool _processingQueue = false;
  Timer? _queueProcessor;

  // Adaptive timeout settings
  Duration _baseTimeout = const Duration(seconds: 30);
  Duration _currentTimeout = const Duration(seconds: 30);

  /// Initialize network optimizer
  Future<void> initialize() async {
    try {
      _logServisi.info('🌐 NetworkOptimizer başlatılıyor...');

      // Start periodic cleanup
      Timer.periodic(const Duration(minutes: 2), (_) => _cleanupIdleClients());

      // Start queue processor
      _startQueueProcessor();

      // Initial network quality check
      await _performInitialQualityCheck();

      _logServisi.info('✅ NetworkOptimizer başlatıldı');
    } catch (e) {
      _logServisi.error('❌ NetworkOptimizer başlatma hatası: $e');
    }
  }

  /// Perform initial network quality check
  Future<void> _performInitialQualityCheck() async {
    try {
      // Try to connect to common servers to assess quality
      final servers = ['8.8.8.8', '1.1.1.1'];

      for (final server in servers) {
        try {
          final quality = await testNetworkQuality('http://$server');
          if (quality.quality != ConnectionQuality.unknown) {
            break;
          }
        } catch (e) {
          _logServisi.warning('⚠️ Server $server test hatası: $e');
        }
      }
    } catch (e) {
      _logServisi.error('❌ Initial quality check hatası: $e');
    }
  }

  /// Enhanced network quality test
  Future<NetworkQualityResult> testNetworkQuality(String serverUrl) async {
    try {
      _logServisi.info('📡 Network kalitesi test ediliyor: $serverUrl');
      final startTime = DateTime.now();

      // Multiple test measurements
      final latencies = <int>[];
      const testCount = 3;

      for (int i = 0; i < testCount; i++) {
        try {
          final latency = await _measureLatency(serverUrl);
          if (latency < 10000) {
            // Valid latency
            latencies.add(latency);
          }
        } catch (e) {
          _logServisi.warning('⚠️ Latency test $i hatası: $e');
        }

        if (i < testCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final avgLatency =
          latencies.isNotEmpty
              ? latencies.reduce((a, b) => a + b) ~/ latencies.length
              : 9999;

      final quality = _assessConnectionQuality(avgLatency);
      final endTime = DateTime.now();
      final testDuration = endTime.difference(startTime);

      _currentQuality = quality;
      _lastQualityCheck = endTime;
      _adaptTimeoutBasedOnQuality(quality);
      _isOnline = avgLatency < 10000;

      _logServisi.info(
        '📊 Network kalitesi: ${quality.displayName} (${avgLatency}ms)',
      );

      return NetworkQualityResult(
        quality: quality,
        latency: avgLatency,
        testDuration: testDuration,
        timestamp: endTime,
        successfulTests: latencies.length,
        totalTests: testCount,
      );
    } catch (e) {
      _logServisi.error('❌ Network test hatası: $e');
      _isOnline = false;

      return NetworkQualityResult(
        quality: ConnectionQuality.poor,
        latency: 9999,
        testDuration: Duration.zero,
        timestamp: DateTime.now(),
        error: 'Network test hatası: $e',
        successfulTests: 0,
        totalTests: 3,
      );
    }
  }

  /// Measure latency with better error handling
  Future<int> _measureLatency(String serverUrl) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      final uri = Uri.parse(serverUrl);
      final request = http.Request('HEAD', uri);

      final client = _getOrCreateClient(serverUrl);
      final streamedResponse = await client
          .send(request)
          .timeout(_currentTimeout);

      final endTime = DateTime.now().millisecondsSinceEpoch;

      // Read response to complete the request
      await streamedResponse.stream.drain();

      if (streamedResponse.statusCode < 500) {
        return endTime - startTime;
      }
    } catch (e) {
      _logServisi.warning('⚠️ Latency measurement hatası: $e');
    }

    return 9999;
  }

  /// Get or create HTTP client with pooling
  http.Client _getOrCreateClient(String serverUrl) {
    final host = Uri.parse(serverUrl).host;

    // Check if we have an existing client
    if (_clientPool.containsKey(host)) {
      _clientLastUsed[host] = DateTime.now();
      return _clientPool[host]!;
    }

    // Create new client if pool is not full
    if (_clientPool.length < _maxPoolSize) {
      final client = http.Client();
      _clientPool[host] = client;
      _clientLastUsed[host] = DateTime.now();

      _logServisi.info('🔗 Yeni HTTP client oluşturuldu: $host');
      return client;
    }

    // Pool is full, find oldest client to replace
    final oldestHost =
        _clientLastUsed.entries
            .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
            .key;

    // Close and replace oldest client
    _clientPool[oldestHost]?.close();
    _clientPool.remove(oldestHost);
    _clientLastUsed.remove(oldestHost);

    final client = http.Client();
    _clientPool[host] = client;
    _clientLastUsed[host] = DateTime.now();

    _logServisi.info('🔄 HTTP client değiştirildi: $oldestHost → $host');
    return client;
  }

  /// Cleanup idle clients
  void _cleanupIdleClients() {
    try {
      final now = DateTime.now();
      final hostsToRemove = <String>[];

      for (final entry in _clientLastUsed.entries) {
        if (now.difference(entry.value) > _clientIdleTimeout) {
          hostsToRemove.add(entry.key);
        }
      }

      for (final host in hostsToRemove) {
        _clientPool[host]?.close();
        _clientPool.remove(host);
        _clientLastUsed.remove(host);

        _logServisi.info('🧹 Idle HTTP client temizlendi: $host');
      }
    } catch (e) {
      _logServisi.error('❌ Client cleanup hatası: $e');
    }
  }

  /// Enhanced connection quality assessment
  ConnectionQuality _assessConnectionQuality(int latency) {
    if (latency > 5000) {
      return ConnectionQuality.poor;
    } else if (latency > 2000) {
      return ConnectionQuality.fair;
    } else if (latency > 1000) {
      return ConnectionQuality.good;
    } else if (latency > 300) {
      return ConnectionQuality.excellent;
    } else {
      return ConnectionQuality.superb;
    }
  }

  /// Adapt timeout based on network quality
  void _adaptTimeoutBasedOnQuality(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.superb:
        _currentTimeout = const Duration(seconds: 15);
        break;
      case ConnectionQuality.excellent:
        _currentTimeout = const Duration(seconds: 20);
        break;
      case ConnectionQuality.good:
        _currentTimeout = const Duration(seconds: 30);
        break;
      case ConnectionQuality.fair:
        _currentTimeout = const Duration(seconds: 45);
        break;
      case ConnectionQuality.poor:
        _currentTimeout = const Duration(seconds: 60);
        break;
      case ConnectionQuality.unknown:
        _currentTimeout = _baseTimeout;
        break;
    }

    _logServisi.info('⏱️ Timeout adapted: ${_currentTimeout.inSeconds}s');
  }

  /// Resilient HTTP request with retry mechanism
  Future<http.Response> resilientRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    int maxRetries = 3,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(url);
    final host = uri.host;

    // Check circuit breaker
    if (_isCircuitBreakerOpen(host)) {
      throw NetworkException('Circuit breaker open for $host');
    }

    final effectiveTimeout = timeout ?? _currentTimeout;
    Exception? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        _logServisi.info(
          '🌐 HTTP ${method.toUpperCase()} $url (attempt ${attempt + 1}/${maxRetries + 1})',
        );

        final client = _getOrCreateClient(url);
        final request = http.Request(method.toUpperCase(), uri);

        if (headers != null) {
          request.headers.addAll(headers);
        }

        if (body != null) {
          if (body is String) {
            request.body = body;
          } else if (body is Map) {
            request.body = json.encode(body);
            request.headers['content-type'] = 'application/json';
          }
        }

        final streamedResponse = await client
            .send(request)
            .timeout(effectiveTimeout);

        final response = await http.Response.fromStream(streamedResponse);

        // Update circuit breaker on success
        _recordSuccess(host);

        _logServisi.info('✅ HTTP request successful: ${response.statusCode}');
        return response;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        _logServisi.warning(
          '⚠️ HTTP request attempt ${attempt + 1} failed: $e',
        );

        // Record failure for circuit breaker
        _recordFailure(host);

        // Don't retry on client errors (4xx)
        if (e is http.ClientException && e.message.contains('4')) {
          break;
        }

        // Calculate backoff delay
        if (attempt < maxRetries) {
          final backoffDelay = _calculateBackoffDelay(attempt);
          _logServisi.info(
            '⏳ Backing off for ${backoffDelay.inMilliseconds}ms...',
          );
          await Future.delayed(backoffDelay);
        }
      }
    }

    throw lastException ??
        NetworkException('Network request failed after $maxRetries retries');
  }

  /// Calculate exponential backoff delay
  Duration _calculateBackoffDelay(int attempt) {
    final baseDelay = 1000; // 1 second
    final maxDelay = 30000; // 30 seconds
    final jitter = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000;

    final delay = (baseDelay * (1 << attempt)) + (jitter * 1000);
    return Duration(milliseconds: delay.clamp(baseDelay, maxDelay).toInt());
  }

  /// Circuit breaker implementation
  bool _isCircuitBreakerOpen(String host) {
    final state = _circuitBreakers[host];
    if (state == null) return false;

    final now = DateTime.now();

    switch (state.status) {
      case CircuitStatus.closed:
        return false;

      case CircuitStatus.open:
        // Check if we should try half-open
        if (now.difference(state.lastFailure) > state.timeout) {
          state.status = CircuitStatus.halfOpen;
          _logServisi.info('🔄 Circuit breaker half-open: $host');
          return false;
        }
        return true;

      case CircuitStatus.halfOpen:
        return false;
    }
  }

  /// Record successful request for circuit breaker
  void _recordSuccess(String host) {
    final state = _circuitBreakers[host];
    if (state != null) {
      state.successCount++;
      state.failureCount = 0;

      if (state.status == CircuitStatus.halfOpen) {
        state.status = CircuitStatus.closed;
        _logServisi.info('✅ Circuit breaker closed: $host');
      }
    }
  }

  /// Record failed request for circuit breaker
  void _recordFailure(String host) {
    final state = _circuitBreakers[host] ?? CircuitBreakerState(host);
    _circuitBreakers[host] = state;

    state.failureCount++;
    state.lastFailure = DateTime.now();

    // Open circuit after threshold failures
    if (state.failureCount >= state.failureThreshold &&
        state.status != CircuitStatus.open) {
      state.status = CircuitStatus.open;
      _logServisi.warning('🚫 Circuit breaker opened: $host');
    }
  }

  /// Queue request for poor network conditions
  Future<http.Response> queueRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    int priority = 5,
  }) async {
    final completer = Completer<http.Response>();
    final request = QueuedRequest(
      method: method,
      url: url,
      headers: headers,
      body: body,
      priority: priority,
      completer: completer,
      timestamp: DateTime.now(),
    );

    _requestQueue.add(request);
    _logServisi.info(
      '📋 Request queued: ${method.toUpperCase()} $url (priority: $priority)',
    );

    return completer.future;
  }

  /// Start queue processor
  void _startQueueProcessor() {
    _queueProcessor = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_processingQueue && _requestQueue.isNotEmpty && _isOnline) {
        await _processRequestQueue();
      }
    });
  }

  /// Process queued requests
  Future<void> _processRequestQueue() async {
    if (_processingQueue || _requestQueue.isEmpty) return;

    _processingQueue = true;
    _logServisi.info(
      '⚡ Processing request queue (${_requestQueue.length} items)',
    );

    try {
      // Sort by priority (lower number = higher priority)
      final sortedRequests =
          _requestQueue.toList()
            ..sort((a, b) => a.priority.compareTo(b.priority));

      _requestQueue.clear();

      for (final request in sortedRequests) {
        try {
          final response = await resilientRequest(
            method: request.method,
            url: request.url,
            headers: request.headers,
            body: request.body,
            maxRetries: 1, // Reduced retries for queued requests
          );

          request.completer.complete(response);
        } catch (e) {
          request.completer.completeError(e);
        }

        // Small delay between requests to avoid overwhelming
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _processingQueue = false;
    }
  }

  /// Enhanced connection test
  Future<bool> testConnection(String remoteIP, {int port = 8080}) async {
    try {
      _logServisi.info('🔍 Testing connection: $remoteIP:$port');

      final uri = Uri.parse('http://$remoteIP:$port/ping');
      final response = await resilientRequest(
        method: 'GET',
        url: uri.toString(),
        maxRetries: 2,
        timeout: const Duration(seconds: 10),
      );

      final success = response.statusCode == 200;
      _logServisi.info(
        success ? '✅ Connection test successful' : '❌ Connection test failed',
      );

      return success;
    } catch (e) {
      _logServisi.error('❌ Connection test error: $e');
      return false;
    }
  }

  /// Network monitoring
  Future<void> startNetworkMonitoring({
    Duration interval = const Duration(minutes: 2),
    List<String>? testServers,
  }) async {
    final servers = testServers ?? ['http://8.8.8.8', 'http://1.1.1.1'];

    Timer.periodic(interval, (timer) async {
      try {
        for (final server in servers) {
          final result = await testNetworkQuality(server);

          // Log significant quality changes
          if (_lastQualityCheck != null) {
            final timeSinceLastCheck = DateTime.now().difference(
              _lastQualityCheck!,
            );
            if (timeSinceLastCheck > const Duration(minutes: 5)) {
              _logServisi.info(
                '📊 Network monitoring: ${result.quality.displayName} (${result.latency}ms)',
              );
            }
          }

          break; // Use first successful server
        }
      } catch (e) {
        _logServisi.error('❌ Network monitoring error: $e');
      }
    });

    _logServisi.info(
      '📡 Network monitoring started (interval: ${interval.inMinutes}m)',
    );
  }

  /// Get current network statistics
  Map<String, dynamic> getNetworkStats() {
    return {
      'quality': _currentQuality.name,
      'isOnline': _isOnline,
      'currentTimeout': _currentTimeout.inSeconds,
      'lastQualityCheck': _lastQualityCheck?.toIso8601String(),
      'activeClients': _clientPool.length,
      'queuedRequests': _requestQueue.length,
      'circuitBreakers': _circuitBreakers.length,
      'openCircuits':
          _circuitBreakers.values
              .where((cb) => cb.status == CircuitStatus.open)
              .length,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _queueProcessor?.cancel();

      // Close all clients
      for (final client in _clientPool.values) {
        client.close();
      }
      _clientPool.clear();
      _clientLastUsed.clear();

      // Clear queued requests
      for (final request in _requestQueue) {
        request.completer.completeError(
          NetworkException('NetworkOptimizer disposed'),
        );
      }
      _requestQueue.clear();

      _circuitBreakers.clear();

      _logServisi.info('🔄 NetworkOptimizer disposed');
    } catch (e) {
      _logServisi.error('❌ NetworkOptimizer dispose error: $e');
    }
  }

  // Getters
  ConnectionQuality get currentQuality => _currentQuality;
  bool get isOnline => _isOnline;
  Duration get currentTimeout => _currentTimeout;
  int get queuedRequestCount => _requestQueue.length;
  int get activeClientCount => _clientPool.length;
}

/// Enhanced Network quality result
class NetworkQualityResult {
  final ConnectionQuality quality;
  final int latency;
  final Duration testDuration;
  final DateTime timestamp;
  final String? error;
  final int successfulTests;
  final int totalTests;

  NetworkQualityResult({
    required this.quality,
    required this.latency,
    required this.testDuration,
    required this.timestamp,
    this.error,
    required this.successfulTests,
    required this.totalTests,
  });

  double get successRate => totalTests > 0 ? successfulTests / totalTests : 0.0;

  @override
  String toString() {
    return 'NetworkQuality(${quality.name}, ${latency}ms, ${(successRate * 100).toStringAsFixed(1)}% success)';
  }
}

/// Enhanced Connection quality enum
enum ConnectionQuality { unknown, poor, fair, good, excellent, superb }

/// Connection quality extensions
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
      case ConnectionQuality.superb:
        return 'Harika';
    }
  }

  String get emoji {
    switch (this) {
      case ConnectionQuality.unknown:
        return '❓';
      case ConnectionQuality.poor:
        return '🔴';
      case ConnectionQuality.fair:
        return '🟡';
      case ConnectionQuality.good:
        return '🟢';
      case ConnectionQuality.excellent:
        return '💚';
      case ConnectionQuality.superb:
        return '⚡';
    }
  }
}

/// Circuit breaker state
class CircuitBreakerState {
  final String host;
  CircuitStatus status = CircuitStatus.closed;
  int failureCount = 0;
  int successCount = 0;
  DateTime lastFailure = DateTime.now();
  final int failureThreshold = 5;
  final Duration timeout = const Duration(minutes: 1);

  CircuitBreakerState(this.host);
}

/// Circuit breaker status
enum CircuitStatus { closed, open, halfOpen }

/// Queued request
class QueuedRequest {
  final String method;
  final String url;
  final Map<String, String>? headers;
  final dynamic body;
  final int priority;
  final Completer<http.Response> completer;
  final DateTime timestamp;

  QueuedRequest({
    required this.method,
    required this.url,
    this.headers,
    this.body,
    required this.priority,
    required this.completer,
    required this.timestamp,
  });
}

/// Network exception
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
