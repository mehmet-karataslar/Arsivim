import 'package:arsiv_uygulamasi/models/sync_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> item(int id, String name) => {
  'id': id,
  'title': name,
  'fileName': '$name.pdf',
  'displayVersion': 1,
  'size': 2048,
  'createdAt': '2026-01-01T12:00:00Z',
  'updatedAt': '2026-02-01T12:00:00Z',
  'links': {
    'kisi': [
      {'name': 'Mehmet Karataş'},
      {'name': 'İpek Işık'},
    ],
    'kategori': [
      {'name': 'Resmi belgeler'},
    ],
  },
};

void main() {
  test(
    'previews preserve peer-local IDs, details and both sides of conflicts',
    () {
      final comparison = SyncComparison.fromInventoryResult(
        local: [
          item(1, 'Bilgisayar belgesi'),
          item(2, 'Eski sözleşme'),
          item(3, 'Aynı belge'),
        ],
        remote: [
          item(1, 'Telefon belgesi'),
          item(2, 'Yeni sözleşme'),
          item(8, 'Aynı belge'),
        ],
        result: {
          'localNewIds': [1],
          'remoteNewIds': [1],
          'same': 1,
          'conflicts': [
            {
              'localIds': [2],
              'remoteIds': [2],
              'reason': 'content_changed',
            },
          ],
        },
      );
      expect(comparison.sendIds, [1]);
      expect(comparison.receiveIds, [1]);
      expect(comparison.localDocuments.map((d) => d.title), [
        'Bilgisayar belgesi',
        'Eski sözleşme',
      ]);
      expect(comparison.remoteDocuments.map((d) => d.title), [
        'Telefon belgesi',
        'Yeni sözleşme',
      ]);
      final document = comparison.remoteDocuments.first;
      expect(document.people, ['Mehmet Karataş', 'İpek Işık']);
      expect(document.categories, ['Resmi belgeler']);
      expect(document.fileName, 'Telefon belgesi.pdf');
      expect(document.size, 2048);
      expect(document.createdAt, DateTime.utc(2026, 1, 1, 12));
      expect(document.updatedAt, DateTime.utc(2026, 2, 1, 12));
      expect(document.isConflict, isFalse);
      expect(
        comparison.localDocuments.last.conflictReason,
        'Dosya içeriği farklı',
      );
      expect(comparison.remoteDocuments.last.isConflict, isTrue);
      expect(
        comparison.conflicts.single,
        contains('Eski sözleşme, Yeni sözleşme'),
      );
    },
  );

  test(
    'legacy and malformed optional display fields have honest fallbacks',
    () {
      final document = SyncDocumentPreview.fromInventory({
        'id': 12,
        'title': ' ',
        'fileName': 'legacy.pdf',
        'createdAt': 'not a date',
        'links': {
          'kisi': [
            {'name': 42},
          ],
          'kategori': [],
        },
      });
      expect(document.title, 'legacy.pdf');
      expect(document.hasDetails, isFalse);
      expect(document.people, isEmpty);
      expect(document.createdAt, isNull);
      expect(SyncDocumentPreview.fromInventory({'id': 1}).title, 'Belge #1');
    },
  );

  test('remote-only conflicts never enter either transfer list', () {
    final comparison = SyncComparison.fromInventoryResult(
      local: [],
      remote: [item(4, 'A'), item(5, 'B')],
      result: {
        'localNewIds': [],
        'remoteNewIds': [],
        'same': 0,
        'conflicts': [
          {
            'localIds': [],
            'remoteIds': [4, 5],
            'reason': 'ambiguous_identity',
          },
        ],
      },
    );
    expect(comparison.sendIds, isEmpty);
    expect(comparison.receiveIds, isEmpty);
    expect(comparison.localDocuments, isEmpty);
    expect(comparison.remoteDocuments.every((d) => d.isConflict), isTrue);
    expect(comparison.remoteDocuments.length, 2);
  });
}
