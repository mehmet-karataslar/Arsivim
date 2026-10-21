import 'package:flutter/material.dart';
import '../../theme/app_tones.dart';
import '../common/section_surface.dart';
import '../common/tone_widgets.dart';

class HomeActions extends StatelessWidget {
  const HomeActions({
    super.key,
    required this.onNavigate,
    required this.onBackup,
  });
  final ValueChanged<int> onNavigate;
  final VoidCallback onBackup;
  @override
  Widget build(BuildContext context) => SectionSurface(
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 0,
          ),
          child: Row(
            children: [
              const ToneBadge(
                icon: Icons.bolt_outlined,
                tone: AppTone.amber,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hızlı işlemler',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En sık kullandığınız işlemler.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final item in [
          (
            'Belgeler',
            'Ara, filtrele ve düzenle',
            Icons.folder_rounded,
            AppTone.primary,
            1,
          ),
          (
            'Kategoriler',
            'Arşivini düzenle',
            Icons.category_outlined,
            AppTone.blue,
            2,
          ),
          (
            'Kişiler',
            'Kişilere ait belgeler',
            Icons.people_rounded,
            AppTone.purple,
            4,
          ),
          (
            'Senkronizasyon',
            'Cihazlar arasında aktar',
            Icons.sync,
            AppTone.teal,
            3,
          ),
          (
            'Yedekleme',
            'Belgelerinin kopyasını al',
            Icons.cloud_outlined,
            AppTone.amber,
            6,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Action(
              title: item.$1,
              subtitle: item.$2,
              icon: item.$3,
              tone: item.$4,
              onTap: item.$5 == 6 ? onBackup : () => onNavigate(item.$5),
            ),
          ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final AppTone tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, tone);
    return Material(
      color: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: colors.foreground, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 19, color: colors.foreground),
            ],
          ),
        ),
      ),
    );
  }
}
