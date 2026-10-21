import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/backup_overview.dart';
import 'veritabani_servisi.dart';
import 'yedekleme_servisi.dart';

class BackupRepository {
  BackupRepository({VeriTabaniServisi? database})
    : database = database ?? VeriTabaniServisi();
  final VeriTabaniServisi database;
  static const historyKey = 'backup.history.v1';
  Future<BackupOverview> load() async {
    final people = await database.kisileriGetir();
    final categories = await database.kategorileriGetir();
    final documents = await database.belgeleriGetir(limit: null);
    return BackupOverview(people, categories, documents);
  }

  Future<BackupRecord> run(
    List<int> people,
    String path,
    Map<int, List<int>> categories,
    void Function(double, String) onProgress,
  ) => YedeklemeServisi(veriTabani: database).kisiVeKategoriYedeklemeYap(
    people,
    path,
    kategoriSecimi: categories,
    onProgress: onProgress,
  );

  Future<List<BackupRecord>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <BackupRecord>[];
    for (final raw in prefs.getStringList(historyKey) ?? <String>[]) {
      try {
        result.add(
          BackupRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return result;
  }

  Future<void> saveHistory(List<BackupRecord> records) async {
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      historyKey,
      records.take(50).map((r) => jsonEncode(r.toJson())).toList(),
    );
    if (!saved) throw StateError('Yedekleme geçmişi kaydedilemedi.');
  }
}
