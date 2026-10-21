import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/ana_sayfa_ozeti.dart';
import 'home_preferences.dart';
import 'veritabani_servisi.dart';

class HomeSummaryService {
  Future<AnaSayfaOzeti> read() async {
    final database = VeriTabaniServisi();
    final db = await database.database;
    final results = await Future.wait<Object?>([
      aggregate(db),
      database.onceakliBelgeleriDetayliGetir(limit: 5),
      HomePreferences.read(),
    ]);
    final stats = results[0] as Map<String, Object?>;
    return AnaSayfaOzeti(
      belgeSayisi: stats['count'] as int,
      dosyaBoyutu: stats['bytes'] as int,
      kategoriSayisi: stats['categories'] as int,
      sonYedekleme: results[2] as DateTime?,
      turBoyutlari: {
        for (final key in ['documents', 'images', 'videos', 'other'])
          key: stats[key] as int,
      },
      sonBelgeler: (results[1] as List<Map<String, dynamic>>)
          .map(SonBelgeOzeti.fromMap)
          .toList(growable: false),
    );
  }

  /// Toplamlar tüm aktif arşivden hesaplanır; son beş kayıtla sınırlanmaz.
  static Future<Map<String, Object?>> aggregate(Database db) async {
    final rows = await db.rawQuery('''
      WITH files AS (
        SELECT b.dosya_boyutu, CASE WHEN k.aktif = 1 THEN k.id END AS category,
          CASE
            WHEN LOWER(LTRIM(b.dosya_tipi, '.')) IN ('pdf','doc','docx','xls','xlsx','ppt','pptx','txt','csv','odt','rtf') THEN 'documents'
            WHEN LOWER(LTRIM(b.dosya_tipi, '.')) IN ('jpg','jpeg','png','gif','webp','bmp','heic','tif','tiff') THEN 'images'
            WHEN LOWER(LTRIM(b.dosya_tipi, '.')) IN ('mp4','avi','mov','mkv','webm','wmv') THEN 'videos'
            ELSE 'other' END AS kind
        FROM belgeler b LEFT JOIN kategoriler k ON k.id = b.kategori_id
        WHERE b.aktif = 1
      )
      SELECT COUNT(*) AS count, COALESCE(SUM(dosya_boyutu),0) AS bytes,
        COUNT(DISTINCT category) AS categories,
        COALESCE(SUM(CASE WHEN kind='documents' THEN dosya_boyutu ELSE 0 END),0) AS documents,
        COALESCE(SUM(CASE WHEN kind='images' THEN dosya_boyutu ELSE 0 END),0) AS images,
        COALESCE(SUM(CASE WHEN kind='videos' THEN dosya_boyutu ELSE 0 END),0) AS videos,
        COALESCE(SUM(CASE WHEN kind='other' THEN dosya_boyutu ELSE 0 END),0) AS other
      FROM files
    ''');
    return rows.single;
  }
}
