import 'dart:io';
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kisi_modeli.dart';
import 'person_contact_schema.dart';
import 'veritabani_servisi.dart';

class PersonEditorRepository {
  PersonEditorRepository({Future<Database> Function()? database})
    : _database = database ?? (() => VeriTabaniServisi().database);
  final Future<Database> Function() _database;

  Future<String> storePhoto(String source) async {
    final support = await getApplicationDocumentsDirectory();
    final directory = await Directory(
      paths.join(support.path, 'profile_photos'),
    ).create(recursive: true);
    final target = paths.join(
      directory.path,
      'profile_${DateTime.now().microsecondsSinceEpoch}${paths.extension(source)}',
    );
    return (await File(source).copy(target)).path;
  }

  Future<void> save(
    KisiModeli person, {
    KisiModeli? original,
    String? newPhoto,
  }) async {
    final db = await _database();
    await PersonContactSchema.prepare(db);
    String? copied;
    try {
      if (newPhoto != null) copied = await storePhoto(newPhoto);
      final values = <String, Object?>{
        'ad': person.ad,
        'soyad': person.soyad,
        'eposta': person.eposta,
        'telefon': person.telefon,
        'adres': person.adres,
        'profil_fotografi': copied ?? person.profilFotografi,
        'guncelleme_tarihi': person.guncellemeTarihi.toIso8601String(),
      };
      await db.transaction((tx) async {
        if (original == null) {
          await tx.insert('kisiler', {
            ...values,
            'olusturma_tarihi': person.olusturmaTarihi.toIso8601String(),
            'aktif': 1,
            'kullanici_tipi': 'NORMAL',
          });
        } else {
          final rows = await tx.query(
            'kisiler',
            where: 'id = ? AND aktif = 1',
            whereArgs: [original.id],
          );
          final currentTime =
              rows.isEmpty
                  ? null
                  : DateTime.tryParse(
                    rows.single['guncelleme_tarihi'] as String? ?? '',
                  );
          if (currentTime == null ||
              !currentTime.isAtSameMomentAs(original.guncellemeTarihi)) {
            throw StateError(
              'Kişi başka bir işlemde değişti. Listeye dönüp yeniden açın.',
            );
          }
          await tx.update(
            'kisiler',
            values,
            where: 'id = ?',
            whereArgs: [original.id],
          );
        }
      });
    } catch (_) {
      if (copied != null) {
        try {
          await File(copied).delete();
        } catch (_) {
          /* Keep original error. */
        }
      }
      rethrow;
    }
  }
}
