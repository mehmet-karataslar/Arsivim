import 'package:flutter/material.dart';

/// İşlem ve bilgi renkleri tek noktada; seçili tema ana vurguyu belirler.
enum AppTone { primary, blue, amber, purple, teal, danger, neutral }

class ToneColors {
  const ToneColors(
    this.foreground,
    this.background,
    this.iconBackground,
    this.border,
  );
  final Color foreground;
  final Color background;
  final Color iconBackground;
  final Color border;

  static ToneColors of(BuildContext context, AppTone tone) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      AppTone.primary => scheme.primary,
      AppTone.blue => const Color(0xFF075BD8),
      AppTone.amber => const Color(0xFF946000),
      AppTone.purple => const Color(0xFF6335C5),
      AppTone.teal => const Color(0xFF007C87),
      AppTone.danger => const Color(0xFFC92539),
      AppTone.neutral => scheme.onSurfaceVariant,
    };
    return ToneColors(
      color,
      Color.lerp(color, scheme.surfaceContainerLowest, 0.95)!,
      Color.lerp(color, scheme.surfaceContainerLowest, 0.85)!,
      Color.lerp(color, scheme.surfaceContainerLowest, 0.90)!,
    );
  }
}
