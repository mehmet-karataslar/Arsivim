import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/widgets/aktarim_kisi_secimi.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('$width genislikte kisi secimi tasmaz ve atlanabilir', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      selected = await aktarimKisiSecimi(
                        context,
                        'Ayni ada sahip kisilerin hedef kaydini dogrulayin.',
                        List.generate(
                          50,
                          (i) => {
                            'id': i + 1,
                            'ad': 'Uzun kisi adi ve ikinci adi',
                            'soyad': 'Uzun soyadi',
                            'kullanici_adi': 'kullanici-$i',
                            'aktif': 1,
                          },
                        ),
                      );
                    },
                    child: const Text('Ac'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Ac'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });
  }
}
