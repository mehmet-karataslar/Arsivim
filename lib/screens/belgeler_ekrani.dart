import '../widgets/common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/document_filters.dart';
import '../providers/documents_controller.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/document_activity_service.dart';
import '../services/document_repository.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/document_tile.dart';
import '../widgets/common/mobile_workspace.dart';
import '../widgets/common/view_mode_switch.dart';
import '../widgets/common/workspace_toolbar.dart';
import '../widgets/common/workspace_sort_button.dart';
import '../widgets/documents/document_filter_bar.dart';
import '../widgets/documents/document_filter_dialog.dart';
import '../widgets/documents/document_side_panels.dart';
import '../widgets/home/home_overview.dart';
import '../widgets/home/home_storage.dart';
import 'belge_duzenle_ekrani.dart';
import 'kisi_ekle_ekrani.dart';
import 'yeni_belge_ekle_ekrani.dart';

/// Sunum ve yönlendirme. Sorgular repository, istek yaşam döngüsü controller içindedir.
class BelgelerEkrani extends StatefulWidget {
  const BelgelerEkrani({
    super.key,
    this.kategoriId,
    this.kisiId,
    this.initialSearch = '',
    this.embedded = false,
    this.onDataChanged,
    this.onStorage,
    this.repository,
    this.showHeading = true,
  });
  final int? kategoriId;
  final int? kisiId;
  final String initialSearch;
  final bool embedded;
  final Future<void> Function()? onDataChanged;
  final VoidCallback? onStorage;
  final DocumentRepository? repository;
  final bool showHeading;
  @override
  State<BelgelerEkrani> createState() => _BelgelerEkraniState();
}

class _BelgelerEkraniState extends State<BelgelerEkrani> {
  late final DocumentsController _data;
  late final TextEditingController _search;
  final _scroll = ScrollController();
  bool _grid = false;
  bool _filtersOpen = false;
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialSearch);
    _data = DocumentsController(
      widget.repository ?? DocumentRepository(),
      DocumentFilters(
        query: widget.initialSearch,
        categoryId: widget.kategoriId,
        personId: widget.kisiId,
      ),
    );
    _data.refresh();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 400 &&
        _data.error == null) {
      _data.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _data.dispose();
    super.dispose();
  }

  void _apply(DocumentFilters filters) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _data.apply(filters);
  }

  void _closeFilters() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _filtersOpen = false);
  }

  Future<void> _filters() async {
    final filters = await showDocumentFilters(
      context,
      _data.filters,
      _data.overview,
    );
    if (filters != null && mounted) _apply(filters);
  }

  Future<void> _add() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const YeniBelgeEkleEkrani()),
    );
    if (changed == true && mounted) await _changed();
  }

  Future<void> _changed() async {
    await _data.refresh();
    await widget.onDataChanged?.call();
  }

  Future<void> _action(BelgeModeli file, HomeDocumentAction action) async {
    final service = BelgeIslemleriServisi();
    switch (action) {
      case HomeDocumentAction.open:
        await service.belgeAc(file, context);
      case HomeDocumentAction.share:
        await service.belgePaylas(file, context);
      case HomeDocumentAction.edit:
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => BelgeDuzenleEkrani(belge: file)),
        );
        if (changed != true || !mounted) return;
        await DocumentActivityService.record(file, 'edit');
      case HomeDocumentAction.delete:
        await service.belgeSil(file, context);
    }
    if (mounted) await _changed();
  }

  void _storage() {
    if (widget.onStorage != null) {
      widget.onStorage!();
      return;
    }
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kullanılan alan'),
            content: HomeStorage(
              summary: _data.overview?.summary,
              compact: true,
              onSettings: () {},
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedBuilder(
      animation: _data,
      builder:
          (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final mobile = WorkspaceLayout.compact(context);
              final wide =
                  constraints.maxWidth >= 1080 &&
                  constraints.maxHeight >= 720 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18;
              final padding = constraints.maxWidth < 600 ? 16.0 : 22.0;
              final toolbar =
                  mobile
                      ? MobileWorkspaceToolbar(
                        controller: _search,
                        onChanged: _data.search,
                        onSearch:
                            (query) =>
                                _apply(_data.filters.copyWith(query: query)),
                        filtersOpen: _filtersOpen,
                        hasFilters:
                            _data.filters.hasFilters ||
                            _data.filters.sort != DocumentSort.newest,
                        onToggleFilters:
                            () => setState(() => _filtersOpen = !_filtersOpen),
                      )
                      : WorkspaceToolbar(
                        showHeading: widget.embedded && widget.showHeading,
                        title: 'Belgeler',
                        subtitle:
                            'Tüm dosyalarınızı yönetin, filtreleyin ve hızlı işlemlerle düzenleyin.',
                        searchController: _search,
                        onSearchChanged: _data.search,
                        onSearch:
                            (query) =>
                                _apply(_data.filters.copyWith(query: query)),
                        onFilter: _filters,
                        onAdd: _add,
                        onAddPerson: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const KisiEkleEkrani(),
                            ),
                          );
                          if (mounted) await _data.refresh();
                        },
                        extra: [
                          WorkspaceSortButton<DocumentSort>(
                            value: _data.filters.sort,
                            tooltip: 'Belgeleri sırala',
                            options: {
                              for (final sort in DocumentSort.values)
                                sort: _sortLabel(sort),
                            },
                            onChanged:
                                (sort) =>
                                    _apply(_data.filters.copyWith(sort: sort)),
                          ),
                          ViewModeSwitch(
                            grid: _grid,
                            onChanged: (value) => setState(() => _grid = value),
                          ),
                        ],
                      );
              final overview = HomeOverview(
                summary: _data.overview?.summary,
                onStorage: _storage,
                todayCount: _data.overview?.today ?? 0,
              );
              final panels = DocumentSidePanels(
                overview: _data.overview,
                filters: _data.filters,
                onFilter: _apply,
                onOpen: (item) => _action(item.belge, HomeDocumentAction.open),
                onStorage: _storage,
              );
              Widget list(
                double width, {
                bool header = false,
              }) => RefreshIndicator(
                onRefresh: _data.refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (header)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            toolbar,
                            if (mobile && _filtersOpen)
                              DocumentFilterPanel(
                                filters: _data.filters,
                                overview: _data.overview,
                                onClose: _closeFilters,
                                onApply: (filters) {
                                  _apply(filters.copyWith(query: _search.text));
                                  setState(() => _filtersOpen = false);
                                },
                              ),
                            if (!mobile) ...[
                              const SizedBox(height: 22),
                              overview,
                              const SizedBox(height: 18),
                            ],
                          ],
                        ),
                      ),
                    if (!mobile)
                      SliverToBoxAdapter(
                        child: DocumentFilterBar(
                          filters: _data.filters,
                          overview: _data.overview,
                          onChanged: _apply,
                        ),
                      ),
                    if (!mobile)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _data.loading
                                      ? 'Belgeler yükleniyor…'
                                      : '${_data.total} belge',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Belgeleri yenile',
                                onPressed:
                                    _data.loading
                                        ? null
                                        : () => _data.refresh(),
                                icon: const Icon(Icons.refresh, size: 19),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_data.loading)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          semanticsLabel: 'Belgeler yükleniyor',
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
                                onPressed: () => _data.refresh(),
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_data.loading &&
                        _data.error == null &&
                        _data.documents.isEmpty)
                      SliverToBoxAdapter(
                        child: AppCard(
                          child: Column(
                            children: [
                              const Icon(Icons.find_in_page_outlined, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _data.filters.hasFilters ||
                                        _data.filters.query.isNotEmpty
                                    ? 'Bu aramayla eşleşen belge bulunamadı.'
                                    : 'Henüz belge eklenmedi.',
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _add,
                                icon: const Icon(Icons.add),
                                label: const Text('Belge ekle'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ..._rows(width),
                    if (_data.hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child:
                                _data.loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(
                                      onPressed:
                                          _data.loading ? null : _data.loadMore,
                                      child: const Text(
                                        'Daha fazla belge yükle',
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    if (header && !mobile)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: panels,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: mobile ? 88 : 24),
                    ),
                  ],
                ),
              );
              final content = Padding(
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
                            overview,
                            const SizedBox(height: 18),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, c) => list(c.maxWidth),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 296,
                                    child: SingleChildScrollView(child: panels),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                        : list(
                          constraints.maxWidth - (mobile ? 0 : 2 * padding),
                          header: true,
                        ),
              );
              return mobile
                  ? MobileWorkspace(
                    onAdd: _add,
                    showAdd: !_filtersOpen,
                    child: content,
                  )
                  : content;
            },
          ),
    );
    return widget.embedded
        ? body
        : Scaffold(
          appBar: AppBar(title: const Text('Belgeler'), centerTitle: true),
          body: SafeArea(child: body),
        );
  }

  List<Widget> _rows(double width) {
    final columns =
        _grid && width >= 720 && MediaQuery.textScalerOf(context).scale(14) < 21
            ? 2
            : 1;
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  Expanded(
                    child:
                        row * columns + col >= _data.documents.length
                            ? const SizedBox()
                            : DocumentTile(
                              document: _data.documents[row * columns + col],
                              onAction: _action,
                              showRelativeTime: true,
                            ),
                  ),
                ],
              ],
            ),
          );
        }, childCount: (_data.documents.length / columns).ceil()),
      ),
    ];
  }

  String _sortLabel(DocumentSort sort) => switch (sort) {
    DocumentSort.newest => 'Son eklenenler',
    DocumentSort.oldest => 'İlk eklenenler',
    DocumentSort.name => 'Ada göre',
    DocumentSort.largest => 'Boyuta göre',
  };
}
