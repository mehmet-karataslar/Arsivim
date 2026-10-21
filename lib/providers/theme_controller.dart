import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences) {
    _palette = AppPalette.fromId(_preferences?.get(preferenceKey));
  }

  static const preferenceKey = 'appearance.palette.v1';
  final SharedPreferences? _preferences;
  late AppPalette _palette;
  bool _saving = false;
  AppPalette get palette => _palette;
  bool get saving => _saving;
  ThemeData get theme => AppTheme.forPalette(_palette);

  /// İlk kareden önce okunur; depolama hatası uygulamanın açılmasını engellemez.
  static Future<ThemeController> load() async {
    try {
      return ThemeController(await SharedPreferences.getInstance());
    } catch (_) {
      return ThemeController(null);
    }
  }

  /// Paralel yazmayı engeller; kayıt başarısızsa etkin paleti değiştirmez.
  Future<bool> selectPalette(AppPalette palette) async {
    if (_saving) return false;
    if (_palette == palette) return true;
    _saving = true;
    notifyListeners();
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      final saved = await preferences.setString(preferenceKey, palette.id);
      if (saved) _palette = palette;
      return saved;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
