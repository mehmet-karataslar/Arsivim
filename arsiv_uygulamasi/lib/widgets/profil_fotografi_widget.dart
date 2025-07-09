import 'package:flutter/material.dart';
import 'dart:io';

class ProfilFotografiWidget extends StatelessWidget {
  final String? profilFotografi;
  final double size;
  final String? kisininAdi;
  final bool showBorder;
  final Color? borderColor;

  const ProfilFotografiWidget({
    Key? key,
    this.profilFotografi,
    this.size = 40,
    this.kisininAdi,
    this.showBorder = false,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Eğer profil fotoğrafı varsa ve dosya mevcutsa göster
    if (profilFotografi != null && File(profilFotografi!).existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              showBorder
                  ? Border.all(
                    color: borderColor ?? Theme.of(context).primaryColor,
                    width: 2,
                  )
                  : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.file(
            File(profilFotografi!),
            fit: BoxFit.cover,
            width: size,
            height: size,
          ),
        ),
      );
    }

    // Fotoğraf yoksa kişinin adından avatar oluştur
    return buildInitialsAvatar(context);
  }

  /// Kişinin adından avatar oluştur (alternatif)
  Widget buildInitialsAvatar(BuildContext context) {
    String initials = '';
    if (kisininAdi != null && kisininAdi!.isNotEmpty) {
      final words = kisininAdi!.split(' ');
      if (words.isNotEmpty) {
        initials = words[0][0].toUpperCase();
        if (words.length > 1) {
          initials += words[1][0].toUpperCase();
        }
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.7),
        border:
            showBorder
                ? Border.all(
                  color: borderColor ?? Theme.of(context).primaryColor,
                  width: 2,
                )
                : null,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
