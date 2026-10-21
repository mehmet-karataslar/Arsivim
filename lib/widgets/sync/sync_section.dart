import 'package:flutter/material.dart';
import '../../theme/app_tones.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';

class SyncSection extends StatelessWidget {
  const SyncSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
    this.tone = AppTone.primary,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final AppTone tone;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToneBadge(icon: icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

String syncDate(DateTime? time, {bool clock = false}) {
  if (time == null) return 'Henüz yok';
  final date =
      '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
  return clock
      ? '$date ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
      : date;
}
