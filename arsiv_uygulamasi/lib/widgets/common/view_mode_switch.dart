import 'package:flutter/material.dart';

class ViewModeSwitch extends StatelessWidget {
  const ViewModeSwitch({
    super.key,
    required this.grid,
    required this.onChanged,
  });
  final bool grid;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in [
          (false, 'Liste görünümü', Icons.view_list_rounded),
          (true, 'Kart görünümü', Icons.grid_view_rounded),
        ])
          IconButton(
            isSelected: grid == item.$1,
            tooltip: item.$2,
            style: IconButton.styleFrom(
              backgroundColor:
                  grid == item.$1
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
              foregroundColor:
                  grid == item.$1
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => onChanged(item.$1),
            icon: Icon(item.$3, size: 20),
          ),
      ],
    ),
  );
}
