import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/belge_modeli.dart';
import '../services/veritabani_servisi.dart';

class BelgeIslemleriServisi {
  static final BelgeIslemleriServisi _instance =
      BelgeIslemleriServisi._internal();
  factory BelgeIslemleriServisi() => _instance;
  BelgeIslemleriServisi._internal();

  final VeriTabaniServisi _veritabaniServisi = VeriTabaniServisi();

  /// Belgeyi sistem varsayılan uygulamasıyla açar
  Future<void> belgeAc(BelgeModeli belge, BuildContext context) async {
    try {
      final dosya = File(belge.dosyaYolu);

      if (!await dosya.exists()) {
        _hataGoster(context, 'Dosya bulunamadı: ${belge.orijinalDosyaAdi}');
        return;
      }

      final sonuc = await OpenFilex.open(belge.dosyaYolu);

      if (sonuc.type != ResultType.done) {
        _hataGoster(context, 'Dosya açılamadı. Uygun uygulama bulunamadı.');
      }
    } catch (e) {
      _hataGoster(context, 'Dosya açılırken hata oluştu: $e');
    }
  }

  /// Belgeyi sistem paylaşma menüsüyle paylaşır
  Future<void> belgePaylas(BelgeModeli belge, BuildContext context) async {
    try {
      final dosya = File(belge.dosyaYolu);

      if (!await dosya.exists()) {
        _hataGoster(context, 'Dosya bulunamadı: ${belge.orijinalDosyaAdi}');
        return;
      }

      final xFile = XFile(belge.dosyaYolu);

      await Share.shareXFiles([
        xFile,
      ], text: belge.baslik ?? belge.orijinalDosyaAdi);
    } catch (e) {
      _hataGoster(context, 'Dosya paylaşılırken hata oluştu: $e');
    }
  }

  /// Belgeyi siler (onay dialoguyla)
  Future<void> belgeSil(BelgeModeli belge, BuildContext context) async {
    final onay = await _silmeOnayiAl(
      context,
      belge.baslik ?? belge.orijinalDosyaAdi,
    );

    if (!onay) return;

    try {
      // Dosyayı sil
      final dosya = File(belge.dosyaYolu);
      if (await dosya.exists()) {
        await dosya.delete();
      }

      // Veritabanından sil
      await _veritabaniServisi.belgeSil(belge.id!);

      _basariGoster(context, 'Belge başarıyla silindi');
    } catch (e) {
      _hataGoster(context, 'Belge silinirken hata oluştu: $e');
    }
  }

  /// Silme onayı dialogu
  Future<bool> _silmeOnayiAl(BuildContext context, String belgeAdi) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Belgeyi Sil'),
                content: Text(
                  '$belgeAdi dosyasını silmek istediğinizden emin misiniz?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('İptal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Sil'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _hataGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _basariGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
 