class SyncComparison {
  const SyncComparison({
    required this.sendIds,
    required this.receiveIds,
    required this.same,
    this.conflicts = const [],
    this.issues = const [],
    this.localDocuments = const [],
    this.remoteDocuments = const [],
  });
  final List<int> sendIds, receiveIds;
  final int same;
  final List<String> conflicts, issues;
  final List<SyncDocumentPreview> localDocuments, remoteDocuments;

  factory SyncComparison.fromInventoryResult({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> remote,
    required Map<String, dynamic> result,
  }) {
    final send = List<int>.from(result['localNewIds'] as List);
    final receive = List<int>.from(result['remoteNewIds'] as List);
    final localConflicts = <int, String>{};
    final remoteConflicts = <int, String>{};
    final summaries = <String>[];
    final localById = {for (final item in local) item['id']: item};
    final remoteById = {for (final item in remote) item['id']: item};
    for (final conflict in result['conflicts'] as List) {
      final reason = SyncDocumentPreview.conflictLabel(conflict['reason']);
      final names = <String>{};
      for (final id in (conflict['localIds'] as List).cast<int>()) {
        localConflicts[id] = reason;
        names.add(SyncDocumentPreview.fromInventory(localById[id]!).title);
      }
      for (final id in (conflict['remoteIds'] as List).cast<int>()) {
        remoteConflicts[id] = reason;
        names.add(SyncDocumentPreview.fromInventory(remoteById[id]!).title);
      }
      summaries.add('${names.join(', ')}: $reason');
    }
    List<SyncDocumentPreview> previews(
      Map<Object?, Map<String, dynamic>> entries,
      List<int> newIds,
      Map<int, String> conflicts,
    ) => [
      for (final id in newIds) SyncDocumentPreview.fromInventory(entries[id]!),
      for (final entry in conflicts.entries)
        SyncDocumentPreview.fromInventory(
          entries[entry.key]!,
          reason: entry.value,
        ),
    ];
    return SyncComparison(
      sendIds: send,
      receiveIds: receive,
      same: result['same'] as int,
      conflicts: summaries,
      localDocuments: previews(localById, send, localConflicts),
      remoteDocuments: previews(remoteById, receive, remoteConflicts),
    );
  }
}

class SyncDocumentPreview {
  const SyncDocumentPreview({
    required this.id,
    required this.title,
    required this.fileName,
    this.people = const [],
    this.categories = const [],
    this.size,
    this.createdAt,
    this.updatedAt,
    this.hasDetails = true,
    this.conflictReason,
  });

  final int id;
  final String title, fileName;
  final List<String> people, categories;
  final int? size;
  final DateTime? createdAt, updatedAt;
  final bool hasDetails;
  final String? conflictReason;
  bool get isConflict => conflictReason != null;

  factory SyncDocumentPreview.fromInventory(
    Map<String, dynamic> item, {
    String? reason,
  }) {
    String text(Object? value) => value is String ? value.trim() : '';
    List<String> names(String kind) {
      final links = item['links'];
      final refs = links is Map ? links[kind] : null;
      return refs is List
          ? refs
              .whereType<Map>()
              .map((ref) => text(ref['name']))
              .where((name) => name.isNotEmpty)
              .toList()
          : const [];
    }

    final fileName = text(item['fileName']);
    final title = text(item['title']);
    return SyncDocumentPreview(
      id: item['id'] as int,
      title:
          title.isNotEmpty
              ? title
              : (fileName.isNotEmpty ? fileName : 'Belge #${item['id']}'),
      fileName: fileName,
      people: names('kisi'),
      categories: names('kategori'),
      size: item['size'] is int ? item['size'] as int : null,
      createdAt: DateTime.tryParse(text(item['createdAt'])),
      updatedAt: DateTime.tryParse(text(item['updatedAt'])),
      hasDetails: item['displayVersion'] == 1,
      conflictReason: reason,
    );
  }

  static String conflictLabel(Object? reason) => switch (reason) {
    'content_changed' => 'Dosya içeriği farklı',
    'metadata_changed' => 'Belge bilgileri farklı',
    'link_identity_unconfirmed' => 'Kişi veya kategori eşleşmesi doğrulanamadı',
    'same_content_distinct_ids' =>
      'Aynı içerik farklı belge kimliğiyle kayıtlı',
    'ambiguous_identity' => 'Birden fazla kayıtla eşleşiyor',
    _ => 'Kayıtlar arasında çakışma var',
  };
}

enum SyncDirection { send, receive }

class SyncDirectionChoice {
  const SyncDirectionChoice(this.direction, this.comparison);
  final SyncDirection direction;
  final SyncComparison comparison;
}
