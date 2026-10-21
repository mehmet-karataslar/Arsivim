import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_controller.dart';
import '../../theme/app_palette.dart';
import 'profile_section.dart';
import 'palette_widgets.dart';

class ProfileAppearance extends StatelessWidget {
  const ProfileAppearance({super.key});

  Future<void> _select(BuildContext context, AppPalette palette) async {
    final success = await context.read<ThemeController>().selectPalette(
      palette,
    );
    if (!context.mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Renk tercihi kaydedilemedi. Lütfen yeniden deneyin.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final colors = Theme.of(context).colorScheme;
    return ProfileSection(
      title: 'Görünüm tercihleri',
      edgeToEdge: true,
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Renk paleti',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Açık zemin üzerinde mat renkler. Seçiminiz bu cihazda saklanır.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final palette in AppPalette.values)
                    SizedBox(
                      width: width,
                      child: PaletteCard(
                        palette: palette,
                        selected: palette == controller.palette,
                        onTap:
                            controller.saving
                                ? null
                                : () => _select(context, palette),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          PalettePreview(palette: controller.palette),
          const SizedBox(height: 20),
          ProfileInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.saving
                        ? 'Tercihiniz kaydediliyor…'
                        : 'Etkin palet: ${controller.palette.label}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      controller.saving ||
                              controller.palette == AppPalette.forest
                          ? null
                          : () => _select(context, AppPalette.forest),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Varsayılan yeşile dön'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
