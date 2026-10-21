import 'package:flutter/material.dart';

/// Kalıcı kimlikler değişmemeli: cihazdaki tercihler bu kimliklerle saklanır.
enum AppPalette {
  forest(
    'forest',
    'Orman yeşili',
    'Arşivim’in özgün yeşili',
    Color(0xFF008557),
    Color(0xFF0D3B1A),
  ),
  slate(
    'slate',
    'Arduvaz mavisi',
    'Dengeli ve sade',
    Color(0xFF46617A),
    Color(0xFF202F40),
  ),
  petrol(
    'petrol',
    'Petrol',
    'Yumuşak mavi ve yeşil',
    Color(0xFF356B65),
    Color(0xFF163B37),
  ),
  plum(
    'plum',
    'Mürdüm',
    'Sakin mor tonları',
    Color(0xFF72566D),
    Color(0xFF362531),
  ),
  earth(
    'earth',
    'Toprak',
    'Sıcak doğal tonlar',
    Color(0xFF796149),
    Color(0xFF392C21),
  );

  const AppPalette(
    this.id,
    this.label,
    this.description,
    this.primary,
    this.brandBackground,
  );
  final String id;
  final String label;
  final String description;
  final Color primary;
  final Color brandBackground;

  static AppPalette fromId(Object? id) =>
      values.firstWhere((palette) => palette.id == id, orElse: () => forest);
}

/// ColorScheme dışındaki markaya özel yüzeyler. Sayfalar renk kodu tutmaz.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({required this.background, required this.accent});
  final Color background;
  final Color accent;

  @override
  BrandColors copyWith({Color? background, Color? accent}) => BrandColors(
    background: background ?? this.background,
    accent: accent ?? this.accent,
  );

  @override
  BrandColors lerp(covariant BrandColors? other, double t) =>
      other == null
          ? this
          : BrandColors(
            background: Color.lerp(background, other.background, t)!,
            accent: Color.lerp(accent, other.accent, t)!,
          );
}
