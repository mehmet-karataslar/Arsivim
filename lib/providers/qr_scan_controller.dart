import 'package:flutter/foundation.dart';
import '../models/connection_qr.dart';

class QrScanController extends ChangeNotifier {
  QrScanController({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  ConnectionQr? result;
  String? error;
  bool submitted = false;
  bool get scanning => result == null && error == null && !submitted;
  void detect(String raw) {
    if (!scanning || raw.trim().isEmpty || raw == '-1') return;
    try {
      result = ConnectionQr.parse(raw, now: clock());
    } on QrReadException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  void fail(String message) {
    if (!scanning) return;
    error = message;
    notifyListeners();
  }

  void retry() {
    if (submitted) return;
    result = null;
    error = null;
    notifyListeners();
  }

  String? confirm() {
    if (submitted || result == null) return null;
    if (result!.expired(clock())) {
      result = null;
      error = 'QR kodunun süresi dolmuş. Yeni kodu tekrar tarayın.';
      notifyListeners();
      return null;
    }
    submitted = true;
    notifyListeners();
    return result!.raw;
  }
}
