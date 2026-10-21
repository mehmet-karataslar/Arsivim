import 'package:flutter/material.dart';
import '../common/adaptive_card_layout.dart';
import '../common/app_card.dart';
import '../common/metric_grid.dart';
import '../common/tone_widgets.dart';
import '../../theme/app_tones.dart';

class BackupMetrics extends StatelessWidget {
  const BackupMetrics({super.key, required this.items});
  final List<MetricData> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final four = constraints.maxWidth >= 190 * scale.clamp(1.0, 1.6) * 4 + 36;
      final cardWidth =
          (constraints.maxWidth - (four ? 36 : 12)) / (four ? 4 : 2);
      return AdaptiveCardLayout(
        minCardWidth: 190,
        maxColumns: 4,
        allowedColumns: const [2, 4],
        spacing: 12,
        equalHeightRows: true,
        children: [
          for (final data in items)
            AppCard(
              padding: const EdgeInsets.all(14),
              borderColor: ToneColors.of(context, data.tone).border,
              child: Builder(
                builder: (context) {
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        data.value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        data.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                  final badge = ToneBadge(
                    icon: data.icon,
                    tone: data.tone,
                    size: 48,
                  );
                  if (cardWidth - 28 < 160 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [badge, const SizedBox(height: 10), text],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      badge,
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
