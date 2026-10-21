import 'package:flutter/material.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchController,
    required this.onSearch,
    required this.onAdd,
    required this.onFilter,
    this.onSearchChanged,
    this.onAddPerson,
    this.onNotifications,
    this.extra = const [],
  });
  final String title, subtitle;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onAdd, onFilter;
  final VoidCallback? onAddPerson, onNotifications;
  final List<Widget> extra;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1050 &&
          MediaQuery.textScalerOf(context).scale(14) <= 17;
      final scheme = Theme.of(context).colorScheme;
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      );
      final controls = Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width:
                wide
                    ? (title == 'Belgeler' ? 300 : 340)
                    : constraints.maxWidth.clamp(0, 440),
            child: TextField(
              controller: searchController,
              onSubmitted: onSearch,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Belgelerde ara...',
                prefixIcon: const Icon(Icons.search, size: 21),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon:
                    searchController.text.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Aramayı temizle',
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged?.call('');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
              ),
            ),
          ),
          _square(context, 'Filtreler', Icons.tune, onFilter),
          ...extra,
          if (onNotifications != null)
            _square(
              context,
              'Arşiv durumu',
              Icons.notifications_none,
              onNotifications!,
            ),
          Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 21),
                  label: const Text('Yeni belge ekle'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
                if (onAddPerson != null)
                  PopupMenuButton<String>(
                    tooltip: 'Ekleme seçenekleri',
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: scheme.onPrimary,
                      size: 19,
                    ),
                    onSelected:
                        (value) => value == 'person' ? onAddPerson!() : onAdd(),
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'file',
                            child: Text('Belge ekle'),
                          ),
                          const PopupMenuItem(
                            value: 'person',
                            child: Text('Kişi ekle'),
                          ),
                        ],
                  ),
              ],
            ),
          ),
        ],
      );
      return wide
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 24),
              controls,
            ],
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 18), controls],
          );
    },
  );

  Widget _square(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) => IconButton.outlined(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 21),
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
