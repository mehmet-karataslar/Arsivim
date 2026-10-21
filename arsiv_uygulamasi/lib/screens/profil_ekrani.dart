import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kisi_modeli.dart';
import '../providers/theme_controller.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_card.dart';

/// Hesap ve görünüm, tek Profil sekmesinde bağımsız bölümler olarak tutulur.
class ProfilEkrani extends StatelessWidget {
  const ProfilEkrani({super.key, this.kullanici});
  final KisiModeli? kullanici;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        return ListView(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hesap bilgilerinizi ve uygulamanın görünümünü buradan yönetin.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 300,
                            child: _HesapBilgileri(kullanici: kullanici),
                          ),
                          const SizedBox(width: 24),
                          const Expanded(child: _GorunumTercihleri()),
                        ],
                      )
                    else ...[
                      _HesapBilgileri(kullanici: kullanici),
                      const SizedBox(height: 20),
                      const _GorunumTercihleri(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HesapBilgileri extends StatelessWidget {
  const _HesapBilgileri({this.kullanici});
  final KisiModeli? kullanici;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ProfilBolumu(
      title: 'Hesap bilgileri',
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: const Icon(Icons.person_outline_rounded, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            kullanici?.tamAd ?? 'Kullanıcı',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Text(
            'Kullanıcı adı',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SelectableText(kullanici?.kullaniciAdi ?? '—'),
        ],
      ),
    );
  }
}

class _GorunumTercihleri extends StatelessWidget {
  const _GorunumTercihleri();

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
    return _ProfilBolumu(
      title: 'Görünüm tercihleri',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Renk paleti', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Açık zemin üzerinde mat renkler. Seçiminiz bu cihazda saklanır.',
            style: TextStyle(color: colors.onSurfaceVariant),
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
                      child: _PaletKarti(
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
          _TemaOnizleme(palette: controller.palette),
          const SizedBox(height: 20),
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
                controller.saving || controller.palette == AppPalette.forest
                    ? null
                    : () => _select(context, AppPalette.forest),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Varsayılan yeşile dön'),
          ),
        ],
      ),
    );
  }
}

class _ProfilBolumu extends StatelessWidget {
  const _ProfilBolumu({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    ),
  );
}

class _PaletKarti extends StatelessWidget {
  const _PaletKarti({
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

class _TemaOnizleme extends StatelessWidget {
  const _TemaOnizleme({required this.palette});
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
