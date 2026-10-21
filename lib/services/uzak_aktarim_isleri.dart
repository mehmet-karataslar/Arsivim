import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// In-memory jobs only; authentication and HTTP routing belong to the caller.
/// [owner] arguments must be authenticated, unpredictable connection-session
/// tokens (baglantiKimligi), never an IP address or a client-supplied owner.
///
/// Sender results must be JSON-safe maps with a terminal `status`: completed,
/// partial, failed, or cancelled. Counts and per-file errors are preserved under
/// `result`. A boolean `success` is also accepted when `status` is absent.
/// Results are limited to 64 KiB of UTF-8 JSON; tokens to 512 characters and
/// request IDs to 128. Idempotency lasts only while the job is retained.
class UzakAktarimIsleri {
  static const azamiIds = 200;
  static const azamiIs = 32;
  static const tamamlananOmru = Duration(minutes: 30);
  static const azamiSonucBayt = 64 * 1024;

  final Future<Map<String, dynamic>> Function(String owner, List<int> ids)
  _send;
  final void Function() _stop;
  final DateTime Function() _saat;
  final Random _random = Random.secure();
  final Map<String, _UzakIs> _isler = {};
  _UzakIs? _aktif;

  UzakAktarimIsleri({
    required Future<Map<String, dynamic>> Function(String owner, List<int> ids)
    send,
    required void Function() stop,
    DateTime Function()? saat,
  }) : _send = send,
       _stop = stop,
       _saat = saat ?? DateTime.now;

  /// Queues a job without calling the sender inline. Retries use exact ordered
  /// ID equality and are scoped to the owner. Returned maps are detached copies.
  Map<String, dynamic> baslat(String owner, String requestId, List<int> ids) {
    _suresiDolanlariSil();
    if (owner.trim().isEmpty || owner.length > 512) {
      return _hata('invalid_owner', 400);
    }
    if (requestId.trim().isEmpty || requestId.length > 128) {
      return _hata('invalid_request_id', 400);
    }
    if (ids.isEmpty || ids.length > azamiIds || ids.any((id) => id <= 0)) {
      return _hata('invalid_ids', 400);
    }
    for (final job in _isler.values) {
      if (job.owner == owner && job.requestId == requestId) {
        if (job.ids.length != ids.length) {
          return _hata('request_conflict', 409);
        }
        for (var i = 0; i < ids.length; i++) {
          if (job.ids[i] != ids[i]) return _hata('request_conflict', 409);
        }
        return _gorunum(job);
      }
    }
    if (_aktif != null) return _hata('busy', 409);
    if (_isler.length >= azamiIs) {
      _UzakIs? oldest;
      for (final job in _isler.values) {
        final end = job.finishedAt;
        if (end != null &&
            (oldest == null || end.isBefore(oldest.finishedAt!))) {
          oldest = job;
        }
      }
      if (oldest == null) return _hata('capacity', 409);
      _isler.remove(oldest.id);
    }
    String id;
    do {
      id =
          List.generate(
            24,
            (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    } while (_isler.containsKey(id));
    final job = _UzakIs(id, owner, requestId, List<int>.unmodifiable(ids));
    _isler[id] = job;
    _aktif = job;
    scheduleMicrotask(() => unawaited(_calistir(job)));
    return _gorunum(job);
  }

  /// Foreign and missing IDs deliberately have indistinguishable responses.
  Map<String, dynamic> status(String owner, String jobId) {
    _suresiDolanlariSil();
    final job = _sahibinIsi(owner, jobId);
    return job == null ? _hata('not_found', 404) : _gorunum(job);
  }

  /// Cancellation is idempotent. A dispatched sender retains the busy slot
  /// until its Future settles, including when the stop callback throws.
  Map<String, dynamic> stop(String owner, String jobId) {
    _suresiDolanlariSil();
    final job = _sahibinIsi(owner, jobId);
    if (job == null) return _hata('not_found', 404);
    if (job.finishedAt != null || job.cancelRequested) return _stopGorunum(job);
    job.cancelRequested = true;
    if (job.state == 'queued') {
      _bitir(job, 'cancelled');
    } else {
      job.state = 'stopping';
      try {
        _stop();
      } catch (error) {
        job.stopError = _hataMetni(error);
      }
    }
    return _stopGorunum(job);
  }

  Future<void> _calistir(_UzakIs job) async {
    // A cancelled queued job may already have been replaced by a new job.
    if (job.finishedAt != null || !identical(_aktif, job)) return;
    job.state = 'running';
    var terminal = 'failed';
    try {
      final result = await _send(job.owner, job.ids);
      final encoded = jsonEncode(result);
      if (utf8.encode(encoded).length > azamiSonucBayt) {
        job.resultJson = jsonEncode({'error': 'result_too_large'});
      } else {
        // Snapshot before storing; the manager may clear/reuse its result list.
        final copy = jsonDecode(encoded) as Map<String, dynamic>;
        final state =
            copy['status'] ??
            (copy['success'] == true
                ? 'completed'
                : copy['success'] == false
                ? 'failed'
                : null);
        if (const {
          'completed',
          'partial',
          'failed',
          'cancelled',
        }.contains(state)) {
          terminal = state as String;
          job.resultJson = encoded;
        } else {
          job.resultJson = jsonEncode({
            'error': 'invalid_result_status',
            'sender_result': copy,
          });
          if (utf8.encode(job.resultJson!).length > azamiSonucBayt) {
            job.resultJson = jsonEncode({'error': 'invalid_result_status'});
          }
        }
      }
    } catch (error) {
      job.resultJson = jsonEncode({
        'error': 'send_failed',
        'message': _hataMetni(error),
      });
    } finally {
      _bitir(job, job.cancelRequested ? 'cancelled' : terminal);
    }
  }

  void _bitir(_UzakIs job, String state) {
    job.state = state;
    job.finishedAt = _saat();
    if (identical(_aktif, job)) _aktif = null;
  }

  void _suresiDolanlariSil() {
    final now = _saat();
    _isler.removeWhere((_, job) {
      final end = job.finishedAt;
      return end != null && now.difference(end) >= tamamlananOmru;
    });
  }

  _UzakIs? _sahibinIsi(String owner, String id) {
    final job = _isler[id];
    return job != null && job.owner == owner ? job : null;
  }

  Map<String, dynamic> _gorunum(_UzakIs job) => {
    'success': true,
    'job_id': job.id,
    'status': job.state,
    if (job.resultJson != null) 'result': jsonDecode(job.resultJson!),
    if (job.stopError != null) 'stop_error': job.stopError,
  };

  Map<String, dynamic> _stopGorunum(_UzakIs job) => {
    ..._gorunum(job),
    if (job.stopError != null) ..._hata('stop_failed', 500),
  };

  static Map<String, dynamic> _hata(String code, int httpStatus) => {
    'success': false,
    'error': code,
    'http_status': httpStatus,
  };

  static String _hataMetni(Object error) {
    final message = error.toString();
    return message.length > 1024 ? message.substring(0, 1024) : message;
  }
}

class _UzakIs {
  final String id;
  final String owner;
  final String requestId;
  final List<int> ids;
  String state = 'queued';
  bool cancelRequested = false;
  DateTime? finishedAt;
  String? resultJson;
  String? stopError;

  _UzakIs(this.id, this.owner, this.requestId, this.ids);
}
