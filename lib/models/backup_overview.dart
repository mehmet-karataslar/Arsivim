import 'belge_modeli.dart';
import 'kategori_modeli.dart';
import 'kisi_modeli.dart';

/// An explicit empty category selection includes nothing. Null means all.
bool backupIncludes(BelgeModeli document, List<int>? categories) =>
    categories == null ||
    document.tumKategoriIds.any(categories.contains) ||
    (document.tumKategoriIds.isEmpty && categories.contains(0));

class BackupOverview {
  const BackupOverview(this.people, this.categories, this.documents);
  final List<KisiModeli> people;
  final List<KategoriModeli> categories;
  final List<BelgeModeli> documents;
}

class BackupRecord {
  const BackupRecord({
    required this.time,
    required this.path,
    required this.people,
    required this.categories,
    required this.documents,
    required this.bytes,
    this.error,
  });
  final DateTime time;
  final String path;
  final int people, categories, documents, bytes;
  final String? error;
  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'path': path,
    'people': people,
    'categories': categories,
    'documents': documents,
    'bytes': bytes,
    'error': error,
  };
  factory BackupRecord.fromJson(Map<String, dynamic> value) => BackupRecord(
    time: DateTime.parse(value['time'] as String),
    path: value['path'] as String,
    people: value['people'] as int,
    categories: value['categories'] as int,
    documents: value['documents'] as int,
    bytes: value['bytes'] as int,
    error: value['error'] as String?,
  );
}
