import 'package:flutter/material.dart';
import '../../theme/app_tones.dart';
import 'adaptive_card_layout.dart';
import 'app_card.dart';
import 'tone_widgets.dart';

class MetricData {
  const MetricData(
    this.label,
    this.value,
    this.description,
    this.icon,
    this.tone,
  );
  final String label, value, description;
  final IconData icon;
  final AppTone tone;
}

/// Bilgi kartları daima 2 veya 4 sütun; büyük yazıda yükseklik serbest büyür.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.items});
  final List<MetricData> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final spacing = constraints.maxWidth < 600 ? 8.0 : 14.0;
      final four =
          constraints.maxWidth >= 165 * scale.clamp(1.0, 1.6) * 4 + spacing * 3;
      final compact =
          (constraints.maxWidth - spacing * (four ? 3 : 1)) / (four ? 4 : 2) <
              250 ||
          scale > 1.4;
      return AdaptiveCardLayout(
        minCardWidth: 165,
        maxColumns: 4,
        allowedColumns: const [2, 4],
        equalHeightRows: true,
        spacing: spacing,
        children: [
          for (final item in items) MetricCard(data: item, compact: compact),
        ],
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.data, this.compact = false});
  final MetricData data;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, data.tone);
    final label = Text(
      data.label,
      style: TextStyle(
        fontSize: compact ? 12 : 13,
        fontWeight: FontWeight.w600,
      ),
    );
    final value = Text(
      data.value,
      style: TextStyle(
        fontSize: compact ? 23 : 27,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
    return AppCard(
      color: Color.lerp(
        colors.background,
        Theme.of(context).colorScheme.surfaceContainerLowest,
        .4,
      ),
      borderColor: colors.border,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child:
          compact
              ? Tooltip(
                message: data.description,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToneBadge(icon: data.icon, tone: data.tone, size: 34),
                    const SizedBox(height: 10),
                    label,
                    const SizedBox(height: 7),
                    value,
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ToneBadge(icon: data.icon, tone: data.tone, size: 58),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 8), value],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.description,
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
