import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arsiv_uygulamasi/models/kisi_modeli.dart';
import 'package:arsiv_uygulamasi/services/person_contact_schema.dart';
import 'package:arsiv_uygulamasi/services/person_editor_repository.dart';
import 'package:arsiv_uygulamasi/providers/person_editor_controller.dart';
import 'package:arsiv_uygulamasi/screens/kisi_ekle_ekrani.dart';
import 'package:arsiv_uygulamasi/widgets/common/app_sidebar.dart';
import 'package:arsiv_uygulamasi/widgets/document_editor/editor_navigation.dart';
import 'package:arsiv_uygulamasi/theme/app_theme.dart';
import 'package:arsiv_uygulamasi/theme/app_palette.dart';
import 'guvenli_aktarim_test.dart' show testDb, kisi;

class MemoryPeople extends PersonEditorRepository {
  bool fail = false;
  int saves = 0;
  KisiModeli? saved;
  Completer<void>? pending;
  @override
  Future<void> save(
    KisiModeli person, {
    KisiModeli? original,
    String? newPhoto,
  }) async {
    saves++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('disk full');
    saved = person;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'Additive contact migration retains credentials; edit clears contact/photo only',
    () async {
      final root = await Directory.systemTemp.createTemp('person-editor-');
      final db = await testDb('${root.path}/test.db');
      addTearDown(() async {
        await db.close();
        await root.delete(recursive: true);
      });
      await db.insert('kisiler', {
        'id': 1,
        ...kisi(ad: 'Ayşe', user: 'ayse'),
        'sifre': 'existing-hash',
        'kullanici_tipi': 'ADMIN',
        'profil_fotografi': '/existing.png',
      });
      final before = (await db.query('kisiler')).single;
      await PersonContactSchema.prepare(db);
      await PersonContactSchema.prepare(db);
      expect((await db.query('kisiler')).single['sifre'], 'existing-hash');
      final original = KisiModeli.fromMap(before);
      final edited = original.copyWith(
        eposta: 'ayse@example.com',
        telefon: '+90 555 000 00 00',
        adres: 'Ankara',
        guncellemeTarihi: DateTime(2026, 10, 22),
      );
      final repository = PersonEditorRepository(database: () async => db);
      await repository.save(edited, original: original);
      var row = (await db.query('kisiler')).single;
      expect(row['eposta'], 'ayse@example.com');
      expect(row['kullanici_tipi'], 'ADMIN');
      expect(row['sifre'], 'existing-hash');
      final loaded = KisiModeli.fromMap(row);
      final updated = loaded.copyWith(
        eposta: '',
        telefon: '',
        adres: '',
        guncellemeTarihi: DateTime(2026, 10, 23),
      );
      updated.profilFotografi = null;
      await repository.save(updated, original: loaded);
      row = (await db.query('kisiler')).single;
      expect(row['profil_fotografi'], isNull);
      expect(row['eposta'], '');
      expect(row['sifre'], 'existing-hash');
      await expectLater(
        repository.save(edited, original: original),
        throwsStateError,
      );
      expect(
        (await db.query('kisiler')).single['guncelleme_tarihi'],
        updated.guncellemeTarihi.toIso8601String(),
      );
      await repository.save(
        KisiModeli(
          ad: 'Yeni',
          soyad: 'Kişi',
          eposta: '',
          telefon: '555',
          adres: 'İzmir',
          olusturmaTarihi: DateTime(2026),
          guncellemeTarihi: DateTime(2026),
        ),
      );
      expect((await db.query('kisiler')).length, 2);
      expect(
        KisiModeli.fromMap((await db.query('kisiler')).last).adres,
        'İzmir',
      );
    },
  );
  test(
    'Save failure keeps form; double save and malformed email are blocked',
    () async {
      final repository =
          MemoryPeople()
            ..fail = true
            ..pending = Completer<void>();
      final c = PersonEditorController(repository: repository);
      addTearDown(c.dispose);
      c.ad.text = 'Mehmet';
      c.soyad.text = 'Karataş';
      c.email.text = 'invalid';
      expect(await c.save(), false);
      expect(repository.saves, 0);
      c.email.text = 'mehmet@example.com';
      final operation = c.save();
      expect(await c.save(), false);
      repository.pending!.complete();
      expect(await operation, false);
      expect(c.ad.text, 'Mehmet');
      expect(c.dirty, true);
      repository.fail = false;
      expect(await c.save(), true);
      expect(repository.saved!.eposta, 'mehmet@example.com');
    },
  );
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_PERSON')) {
      await (FontLoader('Roboto')..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      )).load();
      await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(900, 390),
    const Size(1672, 941),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Person form ${size.width}x${size.height} text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final repo = MemoryPeople();
        final nav = EditorNavigation(
          onSelected: (_) {},
          onStorage: () {},
          onLogout: () {},
        );
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
              key: key,
              child: KisiEkleEkrani(repository: repo, navigation: nav),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BackButton), findsNothing);
        expect(find.byTooltip('Geri dön'), findsNothing);
        if (size.width >= 1100 && scale == 1)
          expect(find.byType(AppSidebar), findsOneWidget);
        if (const bool.fromEnvironment('CAPTURE_PERSON') &&
            scale == 1 &&
            (size.width == 1672 || size.width == 390)) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/person-form-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byKey(const ValueKey('person-save')));
        await tester.pumpAndSettle();
        expect(repo.saves, 0);
        expect(find.text('En az 2 karakter girin.'), findsNWidgets(2));
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('person-save')).hitTestable(),
          findsOneWidget,
        );
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'Successful create returns true; cancellation keeps unsaved fields',
    (tester) async {
      final repo = MemoryPeople();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => KisiEkleEkrani(repository: repo),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('person-Ad')), 'Mehmet');
      await tester.enterText(
        find.byKey(const ValueKey('person-Soyad')),
        'Karataş',
      );
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikler kaydedilmedi'), findsOneWidget);
      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person-save')));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(repo.saved!.ad, 'Mehmet');
    },
  );
}
