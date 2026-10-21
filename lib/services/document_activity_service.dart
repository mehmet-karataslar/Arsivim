import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/belge_modeli.dart';

class DocumentActivity {
  const DocumentActivity(this.id, this.action, this.time);
  final int id;
  final String action;
  final DateTime time;
}

/// Yerel, sınırlı işlem geçmişi. Yalnızca başarıyla tamamlanan işlemler kaydedilir.
class DocumentActivityService {
  static const key = 'documents.activity.v1';
  static Future<void> _pending = Future.value();
  static Future<List<DocumentActivity>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = jsonDecode(prefs.getString(key) ?? '[]') as List;
      return rows
          .map(
            (r) => DocumentActivity(
              r['id'] as int,
              r['action'] as String,
              DateTime.parse(r['time'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> record(BelgeModeli file, String action) {
    if (file.id == null) return Future.value();
    return _pending = _pending.then((_) async {
      try {
        final rows = await read();
        rows.insert(0, DocumentActivity(file.id!, action, DateTime.now()));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          key,
          jsonEncode(
            rows
                .take(100)
                .map(
                  (r) => {
                    'id': r.id,
                    'action': r.action,
                    'time': r.time.toIso8601String(),
                  },
                )
                .toList(),
          ),
        );
      } catch (_) {
        // Geçmiş kaydındaki hata dosya işleminin başarısını değiştirmez.
      }
    });
  }
}
