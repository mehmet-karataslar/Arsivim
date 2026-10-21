import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/people_overview.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/belge_modeli.dart';
import 'veritabani_servisi.dart';

/// Kart başına sorgu yerine kişi sayıları ve kategoriler iki toplu sorguyla okunur.
class PeopleRepository {
  PeopleRepository({Future<Database> Function()? database})
    : _database = database ?? (() => VeriTabaniServisi().database);
  final Future<Database> Function() _database;

  Future<PeopleOverview> read() async {
    final db = await _database();
    final people = await db.rawQuery('''
      SELECT p.id, p.ad, p.soyad, p.kullanici_adi, p.kullanici_tipi,
        p.profil_fotografi, p.olusturma_tarihi, p.guncelleme_tarihi, p.aktif,
        COUNT(b.id) AS document_count, MAX(b.guncelleme_tarihi) AS document_updated
      FROM kisiler p LEFT JOIN belgeler b ON b.kisi_id = p.id AND b.aktif = 1
      WHERE p.aktif = 1 GROUP BY p.id ORDER BY p.ad, p.soyad
    ''');
    final rows = await db.rawQuery('''
      SELECT b.kisi_id, k.*, COUNT(b.id) AS count_in_person
      FROM belgeler b JOIN kisiler p ON p.id = b.kisi_id AND p.aktif = 1
      JOIN kategoriler k ON k.id = b.kategori_id AND k.aktif = 1
      WHERE b.aktif = 1 GROUP BY b.kisi_id, k.id ORDER BY k.kategori_adi
    ''');
    final categories = <int, List<KategoriModeli>>{};
    for (final row in rows) {
      (categories[row['kisi_id'] as int] ??= []).add(
        KategoriModeli.fromMap({
          ...row,
          'belge_sayisi': row['count_in_person'],
        }),
      );
    }
    return PeopleOverview(
      people.map((row) {
        final person = KisiModeli.fromMap(row);
        final documentUpdated = DateTime.tryParse(
          row['document_updated'] as String? ?? '',
        );
        return PersonSummary(
          person: person,
          documentCount: row['document_count'] as int,
          categories: categories[person.id] ?? [],
          updated:
              documentUpdated != null &&
                      documentUpdated.isAfter(person.guncellemeTarihi)
                  ? documentUpdated
                  : person.guncellemeTarihi,
        );
      }).toList(),
    );
  }

  Future<PersonDetails> details(int personId) async {
    final db = await _database();
    final documents = await db.query(
      'belgeler',
      where: 'kisi_id = ? AND aktif = 1',
      whereArgs: [personId],
      orderBy: 'guncelleme_tarihi DESC, id DESC',
      limit: 10,
    );
    final notes = await db.query(
      'belgeler',
      where:
          "kisi_id = ? AND aktif = 1 AND aciklama IS NOT NULL AND TRIM(aciklama) != ''",
      whereArgs: [personId],
      orderBy: 'guncelleme_tarihi DESC, id DESC',
      limit: 20,
    );
    final rows = await db.query(
      'belgeler',
      columns: ['dosya_yolu'],
      where: 'kisi_id = ? AND aktif = 1',
      whereArgs: [personId],
    );
    final files = rows.map((row) => row['dosya_yolu'] as String).toList();
    final folders =
        files.length > 500 ? await compute(_folders, files) : _folders(files);
    return PersonDetails(
      personId: personId,
      documents: documents.map(BelgeModeli.fromMap).toList(),
      folders: folders,
      notes: notes.map(BelgeModeli.fromMap).toList(),
    );
  }

  Future<void> remove(int id) async {
    final db = await _database();
    await db.update('kisiler', {'aktif': 0}, where: 'id = ?', whereArgs: [id]);
  }
}

List<PersonFolder> _folders(List<String> files) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final file in files) {
    final path = paths.Context(
      style: file.contains('\\') ? paths.Style.windows : paths.Style.posix,
    );
    final directory = path.dirname(file);
    counts[directory] = (counts[directory] ?? 0) + 1;
    names[directory] =
        directory == '.' ? 'Arşiv konumu' : path.basename(directory);
  }
  return [
    for (final entry in counts.entries)
      PersonFolder(entry.key, names[entry.key]!, entry.value),
  ]..sort((a, b) => a.name.compareTo(b.name));
}
