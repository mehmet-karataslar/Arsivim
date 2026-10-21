import 'package:flutter/material.dart';
import '../../models/kategori_modeli.dart';
import '../simge_secici_widget.dart';

Color categoryColor(BuildContext context, String hex) {
  final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (parsed == null) return Theme.of(context).colorScheme.primary;
  final color = Color(0xFF000000 | parsed);
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0, .8))
      .withLightness(hsl.lightness.clamp(.25, .48))
      .toColor();
}

IconData categoryIcon(String code) {
  final item =
      SimgeSeciciWidget.simgeler.where((s) => s['kod'] == code).firstOrNull;
  return item?['icon'] as IconData? ??
      switch (code) {
        'local_hospital' => Icons.local_hospital,
        'account_balance' => Icons.account_balance,
        'gavel' => Icons.gavel,
        'business' => Icons.business,
        'security' => Icons.security,
        'person' => Icons.person,
        'flight' => Icons.flight,
        'sports_esports' => Icons.sports_esports,
        _ => Icons.folder_rounded,
      };
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, this.size = 58});
  final KategoriModeli category;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = categoryColor(context, category.renkKodu);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.lerp(
          color,
          Theme.of(context).colorScheme.surfaceContainerLowest,
          .85,
        ),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        categoryIcon(category.simgeKodu),
        color: color,
        size: size * .52,
      ),
    );
  }
}
