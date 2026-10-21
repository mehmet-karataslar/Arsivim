import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/kategori_modeli.dart';
import '../../services/category_preferences.dart';
import '../../services/document_activity_service.dart';
import '../../services/veritabani_servisi.dart';

/// Mevcut toplu işlemler, açık kapsamlı onaylarla ayrı tutulur.
class CategoryActions {
  static Future<bool> run(
    BuildContext context,
    String action,
    List<KategoriModeli> categories,
  ) async {
    final reset = action == 'reset_db';
    final operation = action.replaceFirst('tum_', '');
    final scope =
        categories.length == 1
            ? '“${categories.single.kategoriAdi}” kategorisindeki'
            : 'Seçili ${categories.length} kategorideki';
    final message =
        reset
            ? 'Arşiv veritabanındaki bütün kayıtlar sıfırlanacak. Bu işlemi onaylıyor musunuz?'
            : switch (operation) {
              'kisiler' =>
                '$scope kişi bağlantıları kaldırılacak; başka belgelerde kullanılmayan kişiler silinecek. Devam edilsin mi?',
              'belgeler' =>
                '$scope belgeler arşivden kaldırılacak. Devam edilsin mi?',
              _ =>
                '$scope belgeler ve kişi bağlantıları kaldırılacak; başka belgelerde kullanılmayan kişiler silinecek. Devam edilsin mi?',
            };
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              reset ? 'Veritabanını sıfırla' : 'Silme işlemini onayla',
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(reset ? 'Sıfırla' : 'Onayla'),
              ),
            ],
          ),
    );
    if (accepted != true) return false;
    final db = VeriTabaniServisi();
    if (reset) {
      await db.veritabaniniSifirla();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CategoryPreferences.key);
      await prefs.remove(DocumentActivityService.key);
    } else {
      for (final category in categories) {
        if (operation == 'kisiler') {
          await db.kategoriKisileriSil(category.id!);
        } else if (operation == 'belgeler') {
          await db.kategoriBelgeleriSil(category.id!);
        } else {
          await db.kategoriHepsiniSil(category.id!);
        }
      }
    }
    return true;
  }
}
