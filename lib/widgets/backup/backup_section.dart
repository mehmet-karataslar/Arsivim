import 'package:flutter/material.dart';
import '../common/app_card.dart';

class BackupSection extends StatelessWidget {
  const BackupSection({
    super.key,
    required this.title,
    required this.child,
    this.number,
    this.subtitle,
    this.trailing,
    this.controls,
    this.icon = Icons.cloud_outlined,
  });
  final String title;
  final String? subtitle;
  final int? number;
  final IconData icon;
  final Widget child;
  final Widget? trailing, controls;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inline =
            controls != null &&
            constraints.maxWidth >= 800 &&
            MediaQuery.textScalerOf(context).scale(14) <= 17;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null)
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(
                      '$number',
                      style: const TextStyle(fontSize: 15),
                    ),
                  )
                else
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (inline) ...[
                  const SizedBox(width: 16),
                  SizedBox(width: 440, child: controls!),
                ],
              ],
            ),
            if (controls != null && !inline) ...[
              const SizedBox(height: 14),
              controls!,
            ],
            const SizedBox(height: 18),
            child,
          ],
        );
      },
    ),
  );
}
