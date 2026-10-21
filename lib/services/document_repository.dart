import 'document_links.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/ana_sayfa_ozeti.dart';
import '../models/document_filters.dart';
import 'document_activity_service.dart';
import 'home_summary_service.dart';
import 'veritabani_servisi.dart';

class DocumentOption {
  const DocumentOption(this.id, this.label, [this.count = 0]);
  final int id, count;
  final String label;
}

class RecentActivity {
  const RecentActivity(this.document, this.activity);
  final SonBelgeOzeti document;
  final DocumentActivity activity;
}

class DocumentOverview {
  const DocumentOverview({
    required this.summary,
    this.today = 0,
    this.large = 0,
    this.week = 0,
    this.types = const {},
    this.categories = const [],
    this.people = const [],
    this.sharedIds = const [],
    this.activities = const [],
  });
  final AnaSayfaOzeti summary;
  final int today, week, large;
  final Map<String, int> types;
  final List<DocumentOption> categories, people;
  final List<int> sharedIds;
  final List<RecentActivity> activities;
}

class DocumentPage {
  const DocumentPage(this.documents, this.total);
  final List<SonBelgeOzeti> documents;
  final int total;
}

class DocumentRepository {
  DocumentRepository({Future<Database> Function()? database})
    : _database = database ?? (() => VeriTabaniServisi().database);
  final Future<Database> Function() _database;
  static const _joins = '''FROM belgeler b
    LEFT JOIN kategoriler k ON k.id=b.kategori_id AND k.aktif=1
    LEFT JOIN kisiler p ON p.id=b.kisi_id AND p.aktif=1''';
  static const _select = '''SELECT b.*, k.kategori_adi,
    p.ad AS kisi_ad, p.soyad AS kisi_soyad''';

  Future<DocumentPage> fetch(
    DocumentFilters filters, {
    int offset = 0,
    int limit = 25,
    List<int> sharedIds = const [],
  }) async {
    final db = await _database();
    await DocumentLinks.prepare(db);
    final where = <String>['b.aktif=1'];
    final args = <Object?>[];
    if (filters.query.trim().isNotEmpty) {
      // SQLite LOWER yalnızca ASCII'yi dönüştürür; Türkçe harfleri de eşleştir.
      final columns =
          "COALESCE(b.baslik,'') || ' ' || b.orijinal_dosya_adi || ' ' || COALESCE(b.aciklama,'') || ' ' || COALESCE(b.etiketler,'') || ' ' || COALESCE(k.kategori_adi,'') || ' ' || COALESCE(p.ad,'') || ' ' || COALESCE(p.soyad,'') || ' ' || COALESCE(p.kullanici_adi,'') || ' ' || COALESCE((SELECT GROUP_CONCAT(lp.ad || ' ' || lp.soyad || ' ' || COALESCE(lp.kullanici_adi,''), ' ') FROM kisiler lp WHERE lp.aktif=1 AND ${DocumentLinks.contains('kisi', 'lp.id')}),'') || ' ' || COALESCE((SELECT GROUP_CONCAT(lk.kategori_adi,' ') FROM kategoriler lk WHERE lk.aktif=1 AND ${DocumentLinks.contains('kategori', 'lk.id')}),'')";
      var normalized = columns;
      const upper = ['İ', 'I', 'Ş', 'Ğ', 'Ü', 'Ö', 'Ç'];
      const lower = ['i', 'ı', 'ş', 'ğ', 'ü', 'ö', 'ç'];
      for (var i = 0; i < upper.length; i++) {
        normalized = "REPLACE($normalized,'${upper[i]}','${lower[i]}')";
      }
      where.add("LOWER($normalized) LIKE ? ESCAPE '\\'");
      final query = filters.query
          .trim()
          .replaceAll('İ', 'i')
          .replaceAll('I', 'ı')
          .toLowerCase()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      args.add('%$query%');
    }
    if (filters.extension != null) {
      where.add("LOWER(LTRIM(b.dosya_tipi,'.'))=?");
      args.add(filters.extension!.toLowerCase());
    }
    if (filters.categoryId != null) {
      where.add(DocumentLinks.contains('kategori', '?'));
      args.add(filters.categoryId);
    }
    if (filters.personId != null) {
      where.add(DocumentLinks.contains('kisi', '?'));
      args.add(filters.personId);
    }
    if (filters.from != null) {
      where.add('b.olusturma_tarihi>=?');
      args.add(filters.from!.toIso8601String());
    }
    if (filters.until != null) {
      where.add('b.olusturma_tarihi<?');
      args.add(filters.until!.toIso8601String());
    }
    if (filters.large) where.add('b.dosya_boyutu>1048576');
    if (filters.shared) {
      where.add(
        sharedIds.isEmpty
            ? '0=1'
            : 'b.id IN (${List.filled(sharedIds.length, '?').join(',')})',
      );
      args.addAll(sharedIds);
    }
    final order = switch (filters.sort) {
      DocumentSort.newest => 'b.olusturma_tarihi DESC, b.id DESC',
      DocumentSort.oldest => 'b.olusturma_tarihi ASC, b.id ASC',
      DocumentSort.name =>
        "LOWER(COALESCE(NULLIF(b.baslik,''), b.orijinal_dosya_adi)) ASC, b.id ASC",
      DocumentSort.largest => 'b.dosya_boyutu DESC, b.id DESC',
    };
    final clause = '$_joins WHERE ${where.join(' AND ')}';
    final count = await db.rawQuery('SELECT COUNT(*) AS total $clause', args);
    final rows = await db.rawQuery(
      '$_select $clause ORDER BY $order LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return DocumentPage(
      rows.map(SonBelgeOzeti.fromMap).toList(),
      count.single['total'] as int,
    );
  }

  Future<DocumentOverview> overview({DateTime? now}) async {
    final db = await _database();
    await DocumentLinks.prepare(db);
    final date = now ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final tomorrow = today.add(const Duration(days: 1));
    final stats = await HomeSummaryService.aggregate(db);
    final counts =
        (await db.rawQuery(
          '''SELECT
      COALESCE(SUM(CASE WHEN olusturma_tarihi>=? AND olusturma_tarihi<? THEN 1 ELSE 0 END),0) AS today,
      COALESCE(SUM(CASE WHEN olusturma_tarihi>=? AND olusturma_tarihi<? THEN 1 ELSE 0 END),0) AS week,
      COALESCE(SUM(CASE WHEN dosya_boyutu>1048576 THEN 1 ELSE 0 END),0) AS large
      FROM belgeler WHERE aktif=1''',
          [
            today.toIso8601String(),
            tomorrow.toIso8601String(),
            week.toIso8601String(),
            tomorrow.toIso8601String(),
          ],
        )).single;
    final types = await db.rawQuery(
      "SELECT LOWER(LTRIM(dosya_tipi,'.')) AS type, COUNT(*) AS count FROM belgeler WHERE aktif=1 GROUP BY type ORDER BY count DESC",
    );
    final categories = await db.rawQuery(
      '''SELECT k.id, k.kategori_adi AS label, COUNT(b.id) AS count
      FROM kategoriler k LEFT JOIN belgeler b ON ${DocumentLinks.contains('kategori', 'k.id')} AND b.aktif=1
      WHERE k.aktif=1 GROUP BY k.id ORDER BY label''',
    );
    final people = await db.rawQuery(
      "SELECT id, TRIM(ad || ' ' || COALESCE(soyad,'')) AS label FROM kisiler WHERE aktif=1 ORDER BY label",
    );
    final history = await DocumentActivityService.read();
    final ids = history.map((a) => a.id).toSet().toList();
    final active =
        ids.isEmpty
            ? <Map<String, Object?>>[]
            : await db.rawQuery(
              '$_select $_joins WHERE b.aktif=1 AND b.id IN (${List.filled(ids.length, '?').join(',')})',
              ids,
            );
    final documents = {
      for (final row in active) row['id'] as int: SonBelgeOzeti.fromMap(row),
    };
    return DocumentOverview(
      summary: AnaSayfaOzeti(
        belgeSayisi: stats['count'] as int,
        dosyaBoyutu: stats['bytes'] as int,
        kategoriSayisi: stats['categories'] as int,
        sonBelgeler: const [],
        turBoyutlari: {
          for (final k in ['documents', 'images', 'videos', 'other'])
            k: stats[k] as int,
        },
      ),
      today: counts['today'] as int,
      week: counts['week'] as int,
      large: counts['large'] as int,
      types: {for (final t in types) t['type'] as String: t['count'] as int},
      categories:
          categories
              .map(
                (r) => DocumentOption(
                  r['id'] as int,
                  r['label'] as String,
                  r['count'] as int,
                ),
              )
              .toList(),
      people:
          people
              .map((r) => DocumentOption(r['id'] as int, r['label'] as String))
              .toList(),
      sharedIds:
          history
              .where((a) => a.action == 'share' && documents.containsKey(a.id))
              .map((a) => a.id)
              .toSet()
              .toList(),
      activities:
          history
              .where((a) => documents.containsKey(a.id))
              .take(5)
              .map((a) => RecentActivity(documents[a.id]!, a))
              .toList(),
    );
  }
}
