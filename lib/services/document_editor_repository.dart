import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import 'auth_servisi.dart';
import 'document_links.dart';
import 'document_scan_service.dart';
import 'dosya_servisi.dart';
import 'veritabani_servisi.dart';

class EditorOptions {
  const EditorOptions(this.categories, this.people);
  final List<KategoriModeli> categories;
  final List<KisiModeli> people;
}

class DocumentEditorRepository {
  DocumentEditorRepository({
    Future<Database> Function()? database,
    Future<BelgeModeli> Function(PlatformFile)? importFile,
    String? owner,
  }) : _database = database ?? (() => VeriTabaniServisi().database),
       _import = importFile ?? DosyaServisi().dosyaKopyalaVeHashHesapla,
       _owner = owner ?? '${AuthServisi.instance.currentUser?.id ?? 'local'}';
  final Future<Database> Function() _database;
  final Future<BelgeModeli> Function(PlatformFile) _import;
  final String _owner;

  Future<EditorOptions> options() async {
    final db = await _database();
    await DocumentLinks.prepare(db);
    // Keep inactive existing links visible, but do not offer them for new links.
    final categories = await db.query('kategoriler', orderBy: 'kategori_adi');
    final people = await db.query(
      'kisiler',
      columns: [
        'id',
        'ad',
        'soyad',
        'kullanici_adi',
        'kullanici_tipi',
        'olusturma_tarihi',
        'guncelleme_tarihi',
        'aktif',
      ],
      orderBy: 'ad, soyad',
    );
    return EditorOptions(
      categories.map(KategoriModeli.fromMap).toList(),
      people.map(KisiModeli.fromMap).toList(),
    );
  }

  Future<void> _validate(
    DatabaseExecutor db,
    BelgeModeli doc,
    BelgeModeli? old,
  ) async {
    for (final entry in [
      ('kisiler', doc.tumKisiIds, old?.tumKisiIds ?? <int>[]),
      ('kategoriler', doc.tumKategoriIds, old?.tumKategoriIds ?? <int>[]),
    ]) {
      for (final id in entry.$2) {
        final rows = await db.query(
          entry.$1,
          columns: ['aktif'],
          where: 'id=?',
          whereArgs: [id],
        );
        if (rows.isEmpty ||
            (rows.single['aktif'] != 1 && !entry.$3.contains(id))) {
          throw StateError(
            'Seçilen kişi veya kategori artık kullanılamıyor. Seçimi yenileyin.',
          );
        }
      }
    }
  }

  Future<void> update(BelgeModeli original, BelgeModeli edited) async {
    final db = await _database();
    await DocumentLinks.prepare(db);
    await db.transaction((tx) async {
      final rows = await tx.query(
        'belgeler',
        where: 'id=? AND aktif=1',
        whereArgs: [original.id],
      );
      if (rows.isEmpty ||
          rows.single['guncelleme_tarihi'] !=
              original.guncellemeTarihi.toIso8601String()) {
        throw StateError(
          'Belge başka bir işlemde değişti. Ekranı yeniden açın.',
        );
      }
      await _validate(tx, edited, original);
      await tx.update(
        'belgeler',
        edited.toMap(),
        where: 'id=?',
        whereArgs: [original.id],
      );
    });
  }

  Future<void> import(
    PlatformFile source,
    BelgeModeli Function(BelgeModeli) edit,
  ) async {
    final db = await _database();
    await DocumentLinks.prepare(db);
    if (source.path == null || !await File(source.path!).exists()) {
      throw StateError('Kaynak dosya bulunamadı. Dosyayı yeniden seçin.');
    }
    BelgeModeli? copy;
    var committed = false;
    try {
      copy = await _import(source);
      final doc = edit(copy);
      await db.transaction((tx) async {
        await _validate(tx, doc, null);
        if ((await tx.query(
          'belgeler',
          columns: ['id'],
          where: 'dosya_hash=?',
          whereArgs: [doc.dosyaHash],
        )).isNotEmpty) {
          throw StateError('Bu dosya arşivde zaten kayıtlı.');
        }
        await tx.insert('belgeler', doc.toMap()..remove('id'));
      });
      committed = true;
    } finally {
      if (!committed && copy != null && copy.dosyaYolu != source.path) {
        final file = File(copy.dosyaYolu);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<Database> _draftDatabase() async {
    final db = await _database();
    await db.execute(
      'CREATE TABLE IF NOT EXISTS belge_taslaklari (owner TEXT NOT NULL, document_key TEXT NOT NULL, content TEXT NOT NULL, PRIMARY KEY(owner,document_key))',
    );
    return db;
  }

  String _key(int? id) => id == null ? 'new' : 'edit:$id';

  Future<void> releaseScanDraft(String pdfPath) =>
      DocumentScanService.releaseDraft(pdfPath);

  Future<Map<String, dynamic>?> draft(int? id) async {
    final db = await _draftDatabase();
    final rows = await db.query(
      'belge_taslaklari',
      where: 'owner=? AND document_key=?',
      whereArgs: [_owner, _key(id)],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.single['content'] as String) as Map<String, dynamic>;
  }

  Future<void> saveDraft(int? id, Map<String, dynamic> data) async {
    final db = await _draftDatabase();
    await db.insert('belge_taslaklari', {
      'owner': _owner,
      'document_key': _key(id),
      'content': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDraft(int? id) async {
    final db = await _draftDatabase();
    await db.delete(
      'belge_taslaklari',
      where: 'owner=? AND document_key=?',
      whereArgs: [_owner, _key(id)],
    );
  }
}
