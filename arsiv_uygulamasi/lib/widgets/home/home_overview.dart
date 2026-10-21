import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../theme/app_tones.dart';
import '../../utils/screen_utils.dart';
import '../common/adaptive_card_layout.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.summary,
    required this.onStorage,
    this.todayCount,
  });
  final AnaSayfaOzeti? summary;
  final VoidCallback onStorage;
  final int? todayCount;

  @override
  Widget build(BuildContext context) => AdaptiveCardLayout(
    minCardWidth: 220,
    maxColumns: 4,
    spacing: 14,
    children: [
      MetricCard(
        label: 'Toplam belge',
        value: summary?.belgeSayisi.toString() ?? '—',
        description: 'Arşivinizdeki aktif belgeler',
        icon: Icons.description_rounded,
        tone: AppTone.primary,
      ),
      MetricCard(
        label: todayCount == null ? 'Dosya boyutu' : 'Toplam boyut',
        value:
            summary == null
                ? '—'
                : ScreenUtils.formatFileSize(summary!.dosyaBoyutu),
        description: 'Arşivdeki belgelerin toplamı',
        icon: Icons.storage_rounded,
        tone: AppTone.blue,
      ),
      if (todayCount != null)
        MetricCard(
          label: 'Bugün eklenen',
          value: todayCount.toString(),
          description: 'Bugün eklenen yeni belgeler',
          icon: Icons.calendar_today_outlined,
          tone: AppTone.amber,
        )
      else
        MetricCard(
          label: 'Son yedekleme',
          value:
              summary == null
                  ? '—'
                  : summary!.sonYedekleme == null
                  ? 'Kayıt yok'
                  : formatBackupDate(summary!.sonYedekleme!),
          description:
              summary?.sonYedekleme == null
                  ? 'Henüz kayıtlı yedek yok'
                  : 'Başarıyla tamamlandı',
          icon: Icons.cloud_outlined,
          tone: AppTone.amber,
        ),
      MetricCard(
        label: 'Kullanılan kategoriler',
        value: summary?.kategoriSayisi.toString() ?? '—',
        description: 'Arşivinizdeki kategori sayısı',
        icon: Icons.sell_outlined,
        tone: AppTone.purple,
      ),
    ],
  );

  static String formatBackupDate(DateTime date) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.tone,
  });
  final String label, value, description;
  final IconData icon;
  final AppTone tone;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, tone);
    return AppCard(
      color: Color.lerp(
        colors.background,
        Theme.of(context).colorScheme.surfaceContainerLowest,
        .4,
      ),
      borderColor: colors.border,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ToneBadge(icon: icon, tone: tone, size: 58),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
