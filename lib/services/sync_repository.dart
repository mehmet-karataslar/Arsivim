import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/sync_overview.dart';
import '../models/belge_modeli.dart';
import 'home_preferences.dart';
import 'veritabani_servisi.dart';

class SyncRepository {
  SyncRepository({
    Future<Database> Function()? database,
    Future<DateTime?> Function()? backup,
  }) : _database = database ?? (() => VeriTabaniServisi().database),
       _backup = backup ?? HomePreferences.read;
  final Future<Database> Function() _database;
  final Future<DateTime?> Function() _backup;

  Future<SyncOverview> read({DateTime? now}) async {
    final db = await _database();
    final counts =
        (await db.rawQuery(
          '''SELECT COUNT(*) total,
      COALESCE(SUM(CASE WHEN senkron_durumu IN (?,?) THEN 1 ELSE 0 END),0) pending,
      COALESCE(SUM(CASE WHEN senkron_durumu = ? THEN 1 ELSE 0 END),0) synced
      FROM belgeler WHERE aktif = 1''',
          [
            SenkronDurumu.BEKLEMEDE.index,
            SenkronDurumu.YEREL_DEGISIM.index,
            SenkronDurumu.SENKRONIZE.index,
          ],
        )).single;
    final hasHistory =
        (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='aktarim_gecmisi'",
        )).isNotEmpty;
    var today = 0;
    DateTime? last;
    final events = <SyncEvent>[];
    if (hasHistory) {
      final current = (now ?? DateTime.now()).toLocal();
      final start = DateTime(current.year, current.month, current.day);
      final end = DateTime(current.year, current.month, current.day + 1);
      final totals =
          (await db.rawQuery(
            '''SELECT
        COUNT(DISTINCT CASE WHEN julianday(zaman) >= julianday(?) AND julianday(zaman) < julianday(?) THEN dosya_hash END) today,
        MAX(zaman) last FROM aktarim_gecmisi WHERE durum IN ('gonderildi','kaydedildi','zaten_var')''',
            [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()],
          )).single;
      today = totals['today'] as int;
      last = DateTime.tryParse(totals['last'] as String? ?? '')?.toLocal();
      final rows = await db.rawQuery(
        '''SELECT h.*, (SELECT COALESCE(NULLIF(b.baslik,''),b.orijinal_dosya_adi)
        FROM belgeler b WHERE b.dosya_hash = h.dosya_hash AND b.aktif = 1 LIMIT 1) title
        FROM aktarim_gecmisi h ORDER BY h.zaman DESC, h.id DESC LIMIT 30''',
      );
      for (final row in rows) {
        final time = DateTime.tryParse(row['zaman'] as String? ?? '');
        if (time != null) {
          events.add(
            SyncEvent(
              row['title'] as String? ?? 'Belge aktarımı',
              row['durum'] as String,
              time.toLocal(),
              message: row['mesaj'] as String?,
            ),
          );
        }
      }
    }
    return SyncOverview(
      total: counts['total'] as int,
      pending: counts['pending'] as int,
      synced: counts['synced'] as int,
      today: today,
      lastTransfer: last,
      lastBackup: await _backup(),
      events: events,
    );
  }

  Future<List<BelgeModeli>> pendingDocuments() async =>
      (await (await _database()).query(
        'belgeler',
        where: 'aktif = 1 AND senkron_durumu IN (?,?)',
        whereArgs: [
          SenkronDurumu.BEKLEMEDE.index,
          SenkronDurumu.YEREL_DEGISIM.index,
        ],
        orderBy: 'id',
      )).map(BelgeModeli.fromMap).toList();
}
