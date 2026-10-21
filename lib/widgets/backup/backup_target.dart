import 'package:flutter/material.dart';
import '../../providers/backup_controller.dart';
import 'backup_section.dart';

class BackupTarget extends StatelessWidget {
  const BackupTarget({
    super.key,
    required this.data,
    required this.onPick,
    required this.picking,
  });
  final BackupController data;
  final VoidCallback onPick;
  final bool picking;
  @override
  Widget build(BuildContext context) => BackupSection(
    number: 1,
    title: 'Hedef Klasör',
    subtitle: 'Yedeğin kaydedileceği klasörü seçin.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final field = InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.folder_outlined),
                suffixIcon:
                    data.target == null
                        ? null
                        : IconButton(
                          tooltip: 'Hedef klasörü temizle',
                          onPressed:
                              data.running || picking
                                  ? null
                                  : () => data.setTarget(null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
              ),
              child: Tooltip(
                message: data.target ?? 'Klasör seçilmedi',
                child: Text(
                  data.target ?? 'Henüz klasör seçilmedi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
            final button = FilledButton.icon(
              key: const ValueKey('backup-folder'),
              onPressed: data.running || picking ? null : onPick,
              icon: const Icon(Icons.folder_open),
              label: Text(picking ? 'Seçiliyor…' : 'Klasör Seç'),
            );
            if (constraints.maxWidth < 600 ||
                MediaQuery.textScalerOf(context).scale(14) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              );
            }
            return Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
        if (data.target != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Hedef klasör seçildi',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
