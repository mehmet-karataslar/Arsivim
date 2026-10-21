import '../widgets/common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../models/category_overview.dart';
import '../providers/categories_controller.dart';
import '../services/category_repository.dart';
import '../theme/app_tones.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/metric_grid.dart';
import '../widgets/common/mobile_workspace.dart';
import '../widgets/categories/category_mobile_filters.dart';
import '../widgets/common/workspace_toolbar.dart';
import '../widgets/common/workspace_sort_button.dart';
import '../widgets/categories/category_actions.dart';
import '../widgets/categories/category_card.dart';
import '../widgets/categories/category_editor.dart';
import '../widgets/categories/category_filters.dart';
import '../widgets/categories/category_side_panels.dart';
import '../widgets/home/home_overview.dart';
import 'belgeler_ekrani.dart';

class KategorilerEkrani extends StatefulWidget {
  const KategorilerEkrani({
    super.key,
    this.repository,
    this.onDataChanged,
    this.onOpenCategory,
    this.showHeading = true,
  });
  final CategoryRepository? repository;
  final bool showHeading;
  final Future<void> Function()? onDataChanged;
  final ValueChanged<int>? onOpenCategory;
  @override
  State<KategorilerEkrani> createState() => _KategorilerEkraniState();
}

class _KategorilerEkraniState extends State<KategorilerEkrani> {
  late final CategoriesController _data;
  final _search = TextEditingController();
  bool _grid = true, _acting = false, _filtersOpen = false;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _data = CategoriesController(widget.repository ?? CategoryRepository());
    _data.refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _data.dispose();
    super.dispose();
  }

  Future<void> _edit([CategoryEntry? entry]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryEditor(entry: entry, onSave: _data.save),
    );
    if (changed == true) await widget.onDataChanged?.call();
  }

  Future<void> _open(CategoryEntry entry) async {
    if (widget.onOpenCategory != null) {
      widget.onOpenCategory!(entry.category.id!);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BelgelerEkrani(kategoriId: entry.category.id),
      ),
    );
    if (mounted) await _data.refresh();
  }

  Future<void> _favorite(CategoryEntry entry) async {
    try {
      await _data.favorite(entry);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yıldız tercihi kaydedilemedi. Tekrar deneyin.'),
          ),
        );
      }
    }
  }

  Future<void> _action(String action, [CategoryEntry? entry]) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final changed = await CategoryActions.run(
        context,
        action,
        entry == null
            ? (_data.overview?.entries.map((e) => e.category).toList() ?? [])
            : [entry.category],
      );
      if (changed && mounted) {
        await _data.refresh();
        await widget.onDataChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem tamamlanamadı. Lütfen tekrar deneyin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _filters() => showDialog<void>(
    context: context,
    builder:
        (context) => SimpleDialog(
          title: const Text('Kategorileri filtrele'),
          children: [
            for (final filter in CategoryFilter.values)
              SimpleDialogOption(
                onPressed: () {
                  _data.select(filter);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${categoryFilterLabel(filter)} (${_data.count(filter)})',
                  ),
                ),
              ),
          ],
        ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _data,
    builder:
        (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final mobile = WorkspaceLayout.compact(context);
            final wide =
                constraints.maxWidth >= 1180 &&
                constraints.maxHeight >= 720 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            final padding = constraints.maxWidth < 600 ? 16.0 : 22.0;
            final actions = PopupMenuButton<String>(
              tooltip: 'Kategori işlemleri',
              enabled: !_acting,
              onSelected: (value) => _action(value),
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'tum_kisiler',
                      child: Text(
                        'Tüm kategorilerin kişi bağlantılarını kaldır',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tum_belgeler',
                      child: Text('Tüm kategori belgelerini sil'),
                    ),
                    PopupMenuItem(
                      value: 'tum_hepsi',
                      child: Text(
                        'Tüm kategori belgeleri ve kişi bağlantılarını sil',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset_db',
                      child: Text('Veritabanını sıfırla'),
                    ),
                  ],
            );
            final toolbar =
                mobile
                    ? MobileWorkspaceToolbar(
                      controller: _search,
                      searchHint: 'Kategori ara…',
                      onSearch: _data.search,
                      onChanged: _data.search,
                      filtersOpen: _filtersOpen,
                      hasFilters:
                          _data.filter != CategoryFilter.all ||
                          _data.sort != CategorySort.updated,
                      onToggleFilters: () {
                        if (_filtersOpen && _scroll.hasClients) {
                          _scroll.jumpTo(0);
                        }
                        setState(() => _filtersOpen = !_filtersOpen);
                      },
                    )
                    : WorkspaceToolbar(
                      showHeading: widget.showHeading,
                      title: 'Kategoriler',
                      subtitle:
                          'Belgelerinizi kategorilere ayırın, yönetin ve hızlıca erişin.',
                      searchController: _search,
                      searchHint: 'Kategori ara...',
                      addLabel: 'Kategori ekle',
                      onSearch: _data.search,
                      onSearchChanged: _data.search,
                      onFilter: _filters,
                      onAdd: () => _edit(),
                      extra: [
                        WorkspaceSortButton<CategorySort>(
                          value: _data.sort,
                          tooltip: 'Kategorileri sırala',
                          options: {
                            for (final sort in CategorySort.values)
                              sort: _sortLabel(sort),
                          },
                          onChanged: _data.order,
                        ),
                        actions,
                      ],
                    );
            final overview = MetricGrid(
              items: [
                MetricData(
                  'Toplam kategori',
                  _data.overview?.entries.length.toString() ?? '—',
                  'Tüm kategoriler',
                  Icons.folder_rounded,
                  AppTone.primary,
                ),
                MetricData(
                  'Toplam belge',
                  _data.overview?.documents.toString() ?? '—',
                  'Kategorilerdeki toplam belge',
                  Icons.description_rounded,
                  AppTone.blue,
                ),
                MetricData(
                  'En yoğun kategori',
                  _data.overview?.busiest?.count.toString() ?? '—',
                  _data.overview?.busiest?.category.kategoriAdi ??
                      'Henüz kategori yok',
                  Icons.bar_chart,
                  AppTone.amber,
                ),
                MetricData(
                  'Son güncelleme',
                  _data.overview?.latest == null
                      ? '—'
                      : HomeOverview.formatBackupDate(
                        _data.overview!.latest!.updated,
                      ),
                  _data.overview?.latest?.category.kategoriAdi ??
                      'Henüz kayıt yok',
                  Icons.schedule,
                  AppTone.purple,
                ),
              ],
            );
            final panels = CategorySidePanels(
              controller: _data,
              onOpen: _open,
              onFavorite: _favorite,
            );
            Widget content(
              double width, {
              bool includeHeader = false,
            }) => RefreshIndicator(
              onRefresh: _data.refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (includeHeader)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: mobile ? 0 : 22),
                        child: Column(
                          children: [
                            toolbar,
                            if (mobile && _filtersOpen)
                              CategoryMobileFilters(
                                controller: _data,
                                grid: _grid,
                                onView:
                                    (value) => setState(() => _grid = value),
                                actions: actions,
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (!mobile) SliverToBoxAdapter(child: overview),
                  if (!mobile)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: CategoryFilters(
                          controller: _data,
                          grid: _grid,
                          onView: (value) => setState(() => _grid = value),
                        ),
                      ),
                    ),
                  if (_data.loading || _acting)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Kategoriler yükleniyor',
                      ),
                    ),
                  if (_data.error != null)
                    SliverToBoxAdapter(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_data.error!),
                            TextButton(
                              onPressed: _data.refresh,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_data.loading &&
                      _data.error == null &&
                      _data.visible.isEmpty)
                    SliverToBoxAdapter(
                      child: AppCard(
                        child: Column(
                          children: [
                            const Icon(Icons.folder_open, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _data.overview?.entries.isEmpty == true
                                  ? 'Henüz kategori eklenmedi.'
                                  : 'Bu filtreye uygun kategori bulunamadı.',
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _edit(),
                              icon: const Icon(Icons.add),
                              label: const Text('Kategori ekle'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _cards(width),
                  if (!wide && !mobile)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: panels,
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: mobile ? 88 : 20)),
                ],
              ),
            );
            final layout = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 0 : padding,
                vertical: mobile ? 0 : padding,
              ),
              child:
                  wide
                      ? Column(
                        children: [
                          toolbar,
                          const SizedBox(height: 22),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder:
                                        (context, c) => content(c.maxWidth),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                SizedBox(
                                  width: 292,
                                  child: SingleChildScrollView(child: panels),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                      : content(
                        constraints.maxWidth - (mobile ? 0 : padding * 2),
                        includeHeader: true,
                      ),
            );
            return mobile
                ? MobileWorkspace(
                  onAdd: () => _edit(),
                  addTooltip: 'Kategori ekle',
                  showAdd: !_filtersOpen,
                  child: layout,
                )
                : layout;
          },
        ),
  );
  Widget _cards(double width) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final columns =
        _grid
            ? ((width + 14) / (240 * scale.clamp(1.0, 1.4) + 14)).floor().clamp(
              2,
              4,
            )
            : 1;
    final gap = WorkspaceLayout.compact(context) ? 8.0 : 14.0;
    final cardWidth = (width - gap * (columns - 1)) / columns;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, row) => Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) SizedBox(width: gap),
                  Expanded(
                    child:
                        row * columns + col >= _data.visible.length
                            ? const SizedBox()
                            : _card(
                              _data.visible[row * columns + col],
                              cardWidth < 230 || scale > 1.4,
                            ),
                  ),
                ],
              ],
            ),
          ),
        ),
        childCount: (_data.visible.length / columns).ceil(),
      ),
    );
  }

  Widget _card(CategoryEntry entry, bool compact) => CategoryCard(
    entry: entry,
    compact: compact,
    list: !_grid,
    onOpen: () => _open(entry),
    onEdit: () => _edit(entry),
    onFavorite: () => _favorite(entry),
    onMenu: (value) => _action(value, entry),
  );
  String _sortLabel(CategorySort sort) => switch (sort) {
    CategorySort.updated => 'Son güncellenen',
    CategorySort.name => 'Ada göre',
    CategorySort.mostUsed => 'En çok kullanılan',
    CategorySort.newest => 'Son eklenen',
  };
}
