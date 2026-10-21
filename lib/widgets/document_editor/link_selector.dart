import 'package:flutter/material.dart';
import '../common/workspace_layout.dart';
import 'link_selection_panel.dart';
export 'link_selection_panel.dart' show LinkOption;

class LinkSelector extends StatelessWidget {
  const LinkSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon = Icons.folder_outlined,
  });
  final String label;
  final IconData icon;
  final List<LinkOption> options;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () async {
          final mobile = WorkspaceLayout.compact(context);
          Widget panel(bool mobile) => LinkSelectionPanel(
            label: label,
            options: options,
            selected: selected,
            icon: icon,
            mobile: mobile,
          );
          final Set<int>? result;
          if (mobile) {
            result = await showModalBottomSheet<Set<int>>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              constraints: const BoxConstraints(maxWidth: double.infinity),
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder:
                  (sheetContext) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                    ),
                    child: FractionallySizedBox(
                      heightFactor: .95,
                      child: panel(true),
                    ),
                  ),
            );
          } else {
            result = await showDialog<Set<int>>(
              context: context,
              builder:
                  (dialogContext) => Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 600,
                      height: MediaQuery.sizeOf(dialogContext).height * .8,
                      child: panel(false),
                    ),
                  ),
            );
          }
          if (result != null && context.mounted) onChanged(result);
        },
        icon: const Icon(Icons.search, size: 19),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('Ara ve seç (${selected.length})'),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final id in selected)
            InputChip(
              label: Text(
                options.where((o) => o.id == id).firstOrNull?.label ??
                    'Bulunamayan kayıt #$id',
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: () => onChanged({...selected}..remove(id)),
            ),
        ],
      ),
    ],
  );
}
