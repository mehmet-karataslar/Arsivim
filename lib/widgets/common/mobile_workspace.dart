import 'package:flutter/material.dart';

/// Mobilde tek arama satırı; filtre formu yalnızca istendiğinde açılır.
class MobileWorkspaceToolbar extends StatelessWidget {
  const MobileWorkspaceToolbar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
    required this.onToggleFilters,
    required this.filtersOpen,
    this.hasFilters = false,
    this.searchHint = 'Belge ara…',
  });
  final TextEditingController controller;
  final ValueChanged<String> onSearch, onChanged;
  final VoidCallback onToggleFilters;
  final bool filtersOpen, hasFilters;
  final String searchHint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder:
                (context, _) => TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: IconButton(
                      tooltip: 'Ara',
                      onPressed: () => onSearch(controller.text),
                      icon: const Icon(Icons.search),
                    ),
                    suffixIcon:
                        controller.text.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Aramayı temizle',
                              onPressed: () {
                                controller.clear();
                                onChanged('');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                  ),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          expanded: filtersOpen,
          child: IconButton.filledTonal(
            tooltip: filtersOpen ? 'Filtreleri kapat' : 'Filtreler',
            onPressed: onToggleFilters,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Badge(
              isLabelVisible: hasFilters,
              child: Icon(filtersOpen ? Icons.close : Icons.tune),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Ekle düğmesi kaydırmadan bağımsızdır. İçerikte 88 px alt boşluk bırakılır.
class MobileWorkspace extends StatelessWidget {
  const MobileWorkspace({
    super.key,
    required this.child,
    required this.onAdd,
    this.showAdd = true,
    this.addTooltip = 'Yeni belge ekle',
  });
  final Widget child;
  final VoidCallback onAdd;
  final bool showAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (showAdd)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: null,
            tooltip: addTooltip,
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
        ),
    ],
  );
}
