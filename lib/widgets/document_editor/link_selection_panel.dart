import 'package:flutter/material.dart';

class LinkOption {
  const LinkOption(this.id, this.label, {this.active = true});
  final int id;
  final String label;
  final bool active;
}

/// A single selection body for the large mobile sheet and desktop dialog.
/// Changes remain local until the user applies them.
class LinkSelectionPanel extends StatefulWidget {
  const LinkSelectionPanel({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.icon,
    required this.mobile,
  });
  final String label;
  final List<LinkOption> options;
  final Set<int> selected;
  final IconData icon;
  final bool mobile;
  @override
  State<LinkSelectionPanel> createState() => _LinkSelectionPanelState();
}

class _LinkSelectionPanelState extends State<LinkSelectionPanel> {
  late final selected = {...widget.selected};
  late final searchable = {
    for (final option in widget.options) option.id: _normalize(option.label),
  };
  final search = TextEditingController();
  bool selectedOnly = false;
  String _normalize(String text) =>
      text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(
    () => selected.contains(id) ? selected.remove(id) : selected.add(id),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _normalize(search.text.trim());
    final options =
        widget.options
            .where(
              (option) =>
                  (option.active || widget.selected.contains(option.id)) &&
                  (!selectedOnly || selected.contains(option.id)) &&
                  searchable[option.id]!.contains(query),
            )
            .toList();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label.replaceAll(' *', ''),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Seçimi uygulamadan kapat',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    final searchField = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: search,
        autofocus: !widget.mobile,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ad yazarak ara…',
          labelText: 'Ara',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              search.text.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Aramayı temizle',
                    onPressed: () => setState(search.clear),
                    icon: const Icon(Icons.close, size: 20),
                  ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
    final filters = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: Text('Seçilenler (${selected.length})'),
            selected: selectedOnly,
            onSelected: (value) => setState(() => selectedOnly = value),
          ),
          Text(
            '${options.length} kayıt',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(selected.clear),
              child: const Text('Seçimi temizle'),
            ),
        ],
      ),
    );
    Widget row(int index) {
      final option = options[index], checked = selected.contains(option.id);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color:
              checked
                  ? colors.primaryContainer.withValues(alpha: .5)
                  : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color:
                  checked
                      ? colors.primary.withValues(alpha: .45)
                      : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
            value: checked,
            onChanged: (_) => _toggle(option.id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            secondary: Icon(
              widget.icon,
              color: checked ? colors.primary : colors.onSurfaceVariant,
            ),
            title: Tooltip(
              message: option.label,
              child: Text(
                option.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            subtitle: option.active ? null : const Text('Pasif kayıt'),
            controlAffinity: ListTileControlAffinity.trailing,
          ),
        ),
      );
    }

    final empty = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 36, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            selectedOnly ? 'Seçilen kayıt bulunamadı.' : 'Eşleşen kayıt yok.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Aramayı veya seçilenler filtresini değiştirebilirsiniz.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    final footer = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!widget.mobile) ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, selected),
                icon: const Icon(Icons.check, size: 20),
                label: Text('Seçimi uygula (${selected.length})'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      color: colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A landscape keyboard can leave very little height. In that case the
          // header joins the scrollable region while the apply action remains visible.
          final short =
              constraints.maxHeight < 450 ||
              MediaQuery.textScalerOf(context).scale(14) > 23;
          return Column(
            children: [
              if (widget.mobile)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              if (!short) ...[header, searchField, filters],
              Expanded(
                child: CustomScrollView(
                  key: const ValueKey('link-selection-list'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (short) ...[
                      SliverToBoxAdapter(child: header),
                      SliverToBoxAdapter(child: searchField),
                      SliverToBoxAdapter(child: filters),
                    ],
                    if (options.isEmpty)
                      SliverToBoxAdapter(child: empty)
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => row(index),
                          childCount: options.length,
                        ),
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
                  ],
                ),
              ),
              footer,
            ],
          );
        },
      ),
    );
  }
}
