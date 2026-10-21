import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

class PaletteCard extends StatelessWidget {
  const PaletteCard({
    super.key,
    required this.palette,
    required this.selected,
    this.onTap,
  });
  final AppPalette palette;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '${palette.label} renk paleti',
      child: Material(
        color:
            selected ? colors.primaryContainer : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        palette.description,
                        style: TextStyle(
                          color:
                              selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_outline,
                    color: colors.onPrimaryContainer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PalettePreview extends StatelessWidget {
  const PalettePreview({super.key, required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.forPalette(palette).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Palet önizlemesi',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sample in [
                (
                  label: 'Ana renk',
                  color: colors.primary,
                  foreground: colors.onPrimary,
                ),
                (
                  label: 'Vurgu',
                  color: colors.primaryContainer,
                  foreground: colors.onPrimaryContainer,
                ),
                (
                  label: 'Yüzey',
                  color: colors.surface,
                  foreground: colors.onSurface,
                ),
              ])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sample.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sample.label,
                    style: TextStyle(color: sample.foreground),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
