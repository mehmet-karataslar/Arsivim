import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/kisi_modeli.dart';
import '../../theme/app_tones.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 48});
  final KisiModeli person;
  final double size;
  @override
  Widget build(BuildContext context) {
    final tone =
        [
          AppTone.primary,
          AppTone.blue,
          AppTone.purple,
          AppTone.amber,
          AppTone.teal,
          AppTone.danger,
        ][(person.id ?? 0) % 6];
    final colors = ToneColors.of(context, tone);
    final initials =
        [person.ad, person.soyad]
            .where((word) => word.trim().isNotEmpty)
            .map((word) => word.trim().characters.first.toUpperCase())
            .join();
    Widget fallback() => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.foreground,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * .36,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final file = person.profilFotografi;
    return ExcludeSemantics(
      child:
          file == null || file.isEmpty
              ? fallback()
              : ClipOval(
                child: Image.file(
                  File(file),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  errorBuilder: (_, _, _) => fallback(),
                ),
              ),
    );
  }
}
