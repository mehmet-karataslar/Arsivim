import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arsiv_uygulamasi/services/auth_servisi.dart';
import 'package:arsiv_uygulamasi/widgets/yonetici_dogrulama_dialog.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      '$width yonetici onayi sifresiz gecilmez, hata ve iptal calisir',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? accepted;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        accepted = await yoneticiDogrulamaDialog(
                          context,
                          hedef:
                              'MEHMET KARATAŞ\nmehmet.karatas.uzun.kullanici.adi',
                          dogrula:
                              (_) async => AuthResult(
                                success: false,
                                message: 'Şifre yanlış.',
                              ),
                        );
                      },
                      child: const Text('Aç'),
                    ),
                  ),
            ),
          ),
        );
        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle();
        expect(accepted, isNull);
        await tester.enterText(find.byType(TextField), 'yanlış');
        await tester.tap(find.text('Doğrula ve onayla'));
        await tester.pumpAndSettle();
        expect(find.text('Şifre yanlış.'), findsOneWidget);
        expect(accepted, isNull);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Vazgeç'));
        await tester.pumpAndSettle();
        expect(accepted, false);
      },
    );
  }
}
