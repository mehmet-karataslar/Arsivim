import 'package:shared_preferences/shared_preferences.dart';

class HomePreferences {
  static const backupKey = 'home.last_successful_backup.v1';
  static Future<DateTime?> read() async {
    try {
      final value = (await SharedPreferences.getInstance()).get(backupKey);
      return value is String ? DateTime.tryParse(value) : null;
    } catch (_) {
      return null;
    }
  }

  /// Yedek dosyası tamamlandıktan sonra çağrılır; tercih hatası yedeği bozmaz.
  static Future<bool> recordBackup(DateTime time) async {
    try {
      return await (await SharedPreferences.getInstance()).setString(
        backupKey,
        time.toIso8601String(),
      );
    } catch (_) {
      return false;
    }
  }
}
