import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_overview.dart';

/// Yıldız ve gruplama bu cihaza ait görünüm tercihleridir; kategori kimliğiyle saklanır.
class CategoryPreferences {
  static const key = 'categories.preferences.v1';
  static Future<Map<String, dynamic>> read() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
    } on FormatException {
      return {};
    }
  }

  static Future<void> update(
    int id, {
    bool? favorite,
    CategoryGroup? group,
    DateTime? edited,
  }) async {
    final data = await read();
    final row = Map<String, dynamic>.from(data['$id'] as Map? ?? {});
    if (favorite != null) row['favorite'] = favorite;
    if (group != null) row['group'] = group.name;
    if (edited != null) row['edited'] = edited.toIso8601String();
    data['$id'] = row;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(data))) {
      throw StateError('Tercihler kaydedilemedi');
    }
  }

  static CategoryGroup defaultGroup(String name) => switch (name) {
    'İş' => CategoryGroup.work,
    'Resmi' || 'Hukuki' => CategoryGroup.official,
    'Ev' ||
    'Hastane' ||
    'Mali' ||
    'Kişisel' ||
    'Seyahat' ||
    'Hobi' ||
    'Müzik' ||
    'Sigorta' => CategoryGroup.personal,
    _ => CategoryGroup.general,
  };
}
