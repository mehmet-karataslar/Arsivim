import 'package:flutter/material.dart';

Future<int?> aktarimKisiSecimi(
  BuildContext context,
  String mesaj,
  List<Map<String, dynamic>> adaylar,
) => showDialog<int>(
  context: context,
  barrierDismissible: false,
  builder:
      (dialogContext) => AlertDialog(
        title: const Text('Hedef kişiyi doğrulayın'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mesaj),
                const SizedBox(height: 12),
                for (final aday in adaylar)
                  ListTile(
                    enabled: aday['aktif'] == 1,
                    title: Text('${aday['ad']} ${aday['soyad']}'),
                    subtitle: Text(
                      'Kullanıcı: ${aday['kullanici_adi'] ?? '-'} | Kayıt: ${aday['id']}',
                    ),
                    onTap:
                        aday['aktif'] == 1
                            ? () =>
                                Navigator.pop(dialogContext, aday['id'] as int)
                            : null,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Atla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Yeni kişi oluştur'),
          ),
        ],
      ),
);
