import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/models/ana_sayfa_ozeti.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/document_filters.dart';
import 'package:arsiv_uygulamasi/services/document_repository.dart';
import 'package:arsiv_uygulamasi/widgets/common/document_tile.dart';
import 'package:arsiv_uygulamasi/widgets/home/home_content.dart';
import 'package:arsiv_uygulamasi/widgets/home/home_search_results.dart';
import 'package:arsiv_uygulamasi/widgets/home/recent_documents.dart';
import 'home_test.dart' show sample;

class SearchRepository extends DocumentRepository {
  final queries = <String>[];
  bool fail = false;
  final documents = List.generate(
    30,
    (index) => SonBelgeOzeti(
      belge: BelgeModeli(
        id: 100 + index,
        baslik: 'Eski sözleşme $index',
        dosyaAdi: 'eski-$index.pdf',
        orijinalDosyaAdi: 'eski-$index.pdf',
        dosyaYolu: 'unused',
        dosyaBoyutu: 100,
        dosyaTipi: 'pdf',
        dosyaHash: 'old-$index',
        olusturmaTarihi: DateTime(2020),
        guncellemeTarihi: DateTime(2020),
      ),
    ),
  );

  @override
  Future<DocumentOverview> overview({DateTime? now}) async =>
      DocumentOverview(summary: sample());

  @override
  Future<DocumentPage> fetch(
    DocumentFilters filters, {
    int offset = 0,
    int limit = 25,
    List<int> sharedIds = const [],
  }) async {
    queries.add(filters.query);
    if (fail) throw StateError('offline');
    final matches =
        documents
            .where((item) => item.belge.baslik!.contains(filters.query))
            .toList();
    return DocumentPage(
      matches.skip(offset).take(limit).toList(),
      matches.length,
    );
  }
}

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Ana sayfa tüm arşivde canlı arama yapar: $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = SearchRepository();
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeContent(
              summary: sample(),
              loading: false,
              repository: repository,
              onRefresh: () async {},
              onAdd: () {},
              onNavigate: (_) {},
              onBackup: () {},
              onStorage: () {},
              onDocumentAction: (_, _) {},
              onSearch: submitted.add,
            ),
          ),
        ),
      );
      expect(repository.queries, isEmpty);
      expect(find.byType(RecentDocuments), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Eski');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(find.byType(TextField), 'Eski sözleşme');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repository.queries, ['Eski sözleşme']);
      expect(find.text('Arama sonuçları: 30 belge'), findsOneWidget);
      expect(find.byType(RecentDocuments), findsNothing);
      expect(find.byType(DocumentTile), findsNWidgets(25));
      expect(find.text('Eski sözleşme 0'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, ['Eski sözleşme']);

      await tester.ensureVisible(find.text('Daha fazla belge yükle'));
      await tester.tap(find.text('Daha fazla belge yükle'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentTile), findsNWidgets(30));
      expect(find.text('Daha fazla belge yükle'), findsNothing);

      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'bulunmayan');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu aramayla eşleşen belge bulunamadı.'),
        findsOneWidget,
      );

      repository.fail = true;
      await tester.enterText(find.byType(TextField), 'Eski');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      repository.fail = false;
      await tester.ensureVisible(find.text('Tekrar dene'));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Arama sonuçları: 30 belge'), findsOneWidget);

      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byTooltip('Aramayı temizle'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSearchResults), findsNothing);
      expect(find.byType(RecentDocuments), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
