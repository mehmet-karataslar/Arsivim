import 'package:flutter/material.dart';
import '../../models/sync_overview.dart';
import '../../theme/app_tones.dart';
import '../common/adaptive_card_layout.dart';
import '../common/metric_grid.dart';
import 'sync_section.dart';

class SyncStatistics extends StatelessWidget {
  const SyncStatistics({super.key, this.overview});
  final SyncOverview? overview;
  @override
  Widget build(BuildContext context) => SyncSection(
    title: 'Senkronizasyon istatistikleri',
    icon: Icons.bar_chart,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveCardLayout(
          minCardWidth: 120,
          maxColumns: 4,
          allowedColumns: const [2, 4],
          equalHeightRows: true,
          spacing: 8,
          children: [
            for (final data in [
              MetricData(
                'Bekleyen',
                overview?.pending.toString() ?? '—',
                'Yerel değişiklikler',
                Icons.description_outlined,
                AppTone.primary,
              ),
              MetricData(
                'Senkronize',
                overview?.synced.toString() ?? '—',
                'En az bir cihaz için doğrulandı',
                Icons.check_circle_outline,
                AppTone.blue,
              ),
              MetricData(
                'Diğer',
                overview == null
                    ? '—'
                    : '${overview!.total - overview!.pending - overview!.synced}',
                'Hata, çakışma veya uzak değişiklik',
                Icons.info_outline,
                AppTone.amber,
              ),
              MetricData(
                'Toplam',
                overview?.total.toString() ?? '—',
                'Arşivdeki aktif belgeler',
                Icons.folder_outlined,
                AppTone.purple,
              ),
            ])
              MetricCard(data: data, compact: true),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Son doğrulanan aktarım: ${syncDate(overview?.lastTransfer, clock: true)}',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
