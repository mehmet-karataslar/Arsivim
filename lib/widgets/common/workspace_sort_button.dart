import 'package:flutter/material.dart';

class WorkspaceSortButton<T> extends StatelessWidget {
  const WorkspaceSortButton({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.tooltip,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final String tooltip;
  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: tooltip,
    initialValue: value,
    onSelected: onChanged,
    itemBuilder:
        (_) => [
          for (final entry in options.entries)
            PopupMenuItem(value: entry.key, child: Text(entry.value)),
        ],
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 24,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              options[value] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ],
      ),
    ),
  );
}
