import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:arsiv_uygulamasi/models/belge_modeli.dart';
import 'package:arsiv_uygulamasi/models/kategori_modeli.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/providers/document_editor_controller.dart';
import 'package:arsiv_uygulamasi/services/document_editor_repository.dart';
import 'package:arsiv_uygulamasi/screens/document_editor_screen.dart';
import 'package:arsiv_uygulamasi/services/document_scan_service.dart';
import 'package:arsiv_uygulamasi/models/scan_page.dart';
import 'package:arsiv_uygulamasi/widgets/document_editor/editor_navigation.dart';
import 'package:arsiv_uygulamasi/widgets/document_editor/link_selector.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';

class FakeEditorRepository extends DocumentEditorRepository {
  Map<String, dynamic>? saved;
  int updates = 0;
  final date = DateTime(2026, 10, 21);
  @override
  Future<EditorOptions> options() async => EditorOptions(
    [
      KategoriModeli(id: 1, kategoriAdi: 'Okul', olusturmaTarihi: date),
      KategoriModeli(id: 2, kategoriAdi: 'Eğitim', olusturmaTarihi: date),
    ],
    [
      KisiModeli(
        id: 1,
        ad: 'Nesih',
        soyad: 'Karataş',
        olusturmaTarihi: date,
        guncellemeTarihi: date,
      ),
      KisiModeli(
        id: 2,
        ad: 'Mehmet',
        soyad: 'Karataş',
        olusturmaTarihi: date,
        guncellemeTarihi: date,
      ),
    ],
  );
  @override
  Future<Map<String, dynamic>?> draft(int? id) async => saved;
  @override
  Future<void> saveDraft(int? id, Map<String, dynamic> data) async {
    saved = data;
  }

  @override
  Future<void> deleteDraft(int? id) async {
    saved = null;
  }

  @override
  Future<void> update(BelgeModeli original, BelgeModeli edited) async {
    updates++;
  }
}

class FakePageScanner extends DocumentScanService {
  int calls = 0;
  @override
  bool get isSupported => true;
  @override
  Future<List<String>?> capturePages() async {
    calls++;
    return ['C:/page1.png', 'C:/page2.png', 'C:/page3.png'];
  }

  @override
  Future<ScannedPdf> createPdf(List<ScanPage> pages, {String? name}) async {
    return ScannedPdf(
      PlatformFile(name: 'Tarama.pdf', path: 'C:/scan.pdf', size: 1024),
      pages.length,
      pages: pages,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_EDITOR_PREVIEW')) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('desktop_drop'),
          (call) async => null,
        );
  });
  testWidgets(
    'Fotoğraf Çek kartı tarayıcıyı açar ve sayfaları tek PDF olarak ekler',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scanner = FakePageScanner();
      final c = DocumentEditorController(repository: FakeEditorRepository());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: DocumentEditorScreen(controller: c, scanner: scanner),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraf Seç'), findsNothing);
      expect(find.text('Kamera ile tara · PDF oluştur'), findsNothing);
      await tester.tap(find.text('Fotoğraf Çek'));
      await tester.pumpAndSettle();
      expect(scanner.calls, 1);
      expect(c.files, isEmpty);
      expect(find.text('Taramayı kontrol et'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-create-pdf')));
      await tester.pumpAndSettle();
      expect(c.files.length, 1);
      expect(c.files.single.extension, 'pdf');
      expect(find.textContaining('3 sayfa tek PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0, 600.0, 900.0, 1100.0, 1672.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Editor $width px, metin $scale: taşma yok ve alt alanlar erişilebilir',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final c = DocumentEditorController(
            repository: FakeEditorRepository(),
          );
          c.addFiles([
            PlatformFile(
              name: '5_Sinif_Turkce_20_Soruluk_Sinav.pdf',
              path: 'C:/test.pdf',
              size: 124100,
            ),
          ]);
          c.title.text = '5. Sınıf Türkçe 20 Soruluk Sınav';
          c.description.text =
              '5. sınıf Türkçe dersi deneme sınavı. 20 soruluk değerlendirme sınavı.';
          c.people.addAll([1, 2]);
          c.categories.addAll([1, 2]);
          c.tags.addAll(['resmi', 'önemli', 'okul', 'sınav']);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.forPalette(AppPalette.forest),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: RepaintBoundary(
                key: boundary,
                child: DocumentEditorScreen(
                  controller: c,
                  navigation: EditorNavigation(
                    onSelected: (_) {},
                    onStorage: () {},
                    onLogout: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width < 600) {
            expect(find.text('Dosya seçmek için dokunun'), findsNothing);
            expect(
              find.text('Dosyayı buraya sürükleyin veya seçin'),
              findsNothing,
            );
            expect(
              find.text('Sistem tarafından algılanan dosya türü'),
              findsNothing,
            );
            expect(find.text('Belge Önizleme ve Özet'), findsNothing);
            expect(find.text('PDF · 121.2 KB'), findsOneWidget);
          } else {
            expect(
              find.text('Dosyayı buraya sürükleyin veya seçin'),
              findsOneWidget,
            );
          }

          expect(
            (tester.getTopLeft(find.text('Dosya Seç')).dy -
                    tester.getTopLeft(find.text('Fotoğraf Çek')).dy)
                .abs(),
            lessThan(1),
          );
          if (const bool.fromEnvironment('CAPTURE_EDITOR_PREVIEW') &&
              scale == 1 &&
              [390.0, 1672.0].contains(width)) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('artifacts/editor').create(recursive: true);
              await File(
                'artifacts/editor/editor-${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'Aramalı çoklu seçim iptal edilince değişmez; uygula iki kişiyi korur',
    (tester) async {
      Set<int> selected = {1};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkSelector(
              label: 'Kişiler',
              options: const [
                LinkOption(1, 'Mehmet Karataş'),
                LinkOption(2, 'Nesih Karataş'),
              ],
              selected: selected,
              onChanged: (ids) => selected = ids,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ara ve seç (1)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nesih');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nesih Karataş'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seçimi uygula (2)'));
      await tester.pumpAndSettle();
      expect(selected, {1, 2});
    },
  );
  testWidgets(
    'Düzenleme kaydeder ve çağıran ekrana true döner; mevcut dosya değişmez',
    (tester) async {
      final repo = FakeEditorRepository();
      final original = BelgeModeli(
        id: 8,
        dosyaAdi: 'arsiv.pdf',
        orijinalDosyaAdi: 'arsiv.pdf',
        dosyaYolu: 'C:/arsiv.pdf',
        dosyaBoyutu: 42,
        dosyaTipi: 'pdf',
        dosyaHash: 'hash',
        kisiId: 1,
        kisiIds: [1, 2],
        kategoriId: 1,
        baslik: 'Eski başlık',
        olusturmaTarihi: DateTime(2026, 10, 20),
        guncellemeTarihi: DateTime(2026, 10, 21),
      );
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forPalette(AppPalette.forest),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder:
                              (_) => DocumentEditorScreen(
                                controller: DocumentEditorController(
                                  original: original,
                                  repository: repo,
                                ),
                              ),
                        ),
                      );
                    },
                    child: const Text('Düzenle'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Yeni başlık');
      await tester.tap(find.text('Değişiklikleri kaydet'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(repo.updates, 1);
      expect(original.dosyaYolu, 'C:/arsiv.pdf');
      expect(original.baslik, 'Eski başlık');
      expect(original.tumKisiIds, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Taslak tüm bağlantıları saklar; yeni belge için eksik dosyada kayıt engellenir',
    () async {
      final repo = FakeEditorRepository();
      final c = DocumentEditorController(repository: repo);
      await c.load();
      c.title.text = 'Deneme';
      c.people.addAll([1, 2]);
      c.categories.addAll([1, 2]);
      await c.saveDraft();
      expect(repo.saved!['people'], [1, 2]);
      expect(repo.saved!['categories'], [1, 2]);
      expect(await c.save(), false);
      expect(c.error, contains('Dosya'));
      c.dispose();
    },
  );
}
