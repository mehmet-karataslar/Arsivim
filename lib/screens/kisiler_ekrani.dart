import '../widgets/document_editor/editor_navigation.dart';
import 'package:flutter/material.dart';
import '../models/people_overview.dart';
import '../models/kisi_modeli.dart';
import '../models/belge_modeli.dart';
import '../providers/people_controller.dart';
import '../services/people_repository.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/document_activity_service.dart';
import '../theme/app_tones.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/document_tile.dart';
import '../widgets/common/metric_grid.dart';
import '../widgets/common/mobile_workspace.dart';
import '../widgets/common/workspace_layout.dart';
import '../widgets/common/workspace_toolbar.dart';
import '../widgets/people/person_card.dart';
import '../widgets/people/person_detail_panel.dart';
import '../widgets/people/people_filters.dart';
import 'kisi_ekle_ekrani.dart';
import 'belge_duzenle_ekrani.dart';
import 'belgeler_ekrani.dart';

class KisilerEkrani extends StatefulWidget {
  const KisilerEkrani({
    super.key,
    this.showHeading = true,
    this.repository,
    this.onDataChanged,
    this.onOpenDocuments,
  });
  final bool showHeading;
  final PeopleRepository? repository;
  final Future<void> Function()? onDataChanged;
  final ValueChanged<int>? onOpenDocuments;
  @override
  State<KisilerEkrani> createState() => _KisilerEkraniState();
}

class _KisilerEkraniState extends State<KisilerEkrani> {
  late final PeopleController _data;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _grid = true,
      _filtersOpen = false,
      _desktopFilters = true,
      _sheetOpen = false,
      _deleting = false;
  @override
  void initState() {
    super.initState();
    _data = PeopleController(widget.repository ?? PeopleRepository());
    _data.refresh();
  }

  @override
  void dispose() {
    _data.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _changed() async {
    await _data.refresh();
    await widget.onDataChanged?.call();
  }

  Future<void> _edit([KisiModeli? person]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => KisiEkleEkrani(kisi: person)),
    );
    if (changed == true && mounted) await _changed();
  }

  void _closeSheet() {
    if (_sheetOpen && mounted) {
      Navigator.of(context).pop();
      _sheetOpen = false;
    }
  }

  Future<void> _documents(int personId) async {
    _closeSheet();
    if (widget.onOpenDocuments != null) {
      widget.onOpenDocuments!(personId);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BelgelerEkrani(kisiId: personId)));
    if (mounted) await _changed();
  }

  Future<void> _select(PersonSummary person, bool sideBySide) async {
    _data.select(person.person.id!);
    if (sideBySide || _sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (_) => FractionallySizedBox(
            heightFactor: .9,
            child: AnimatedBuilder(
              animation: _data,
              builder:
                  (_, _) => _panel(onClose: () => Navigator.of(context).pop()),
            ),
          ),
    );
    _sheetOpen = false;
  }

  void _action(PersonSummary person, PersonAction action, bool sideBySide) {
    switch (action) {
      case PersonAction.edit:
        _edit(person.person);
      case PersonAction.documents:
        _documents(person.person.id!);
      case PersonAction.view:
        _select(person, sideBySide);
      case PersonAction.delete:
        _delete(person);
    }
  }

  Future<void> _delete(PersonSummary person) async {
    if (_deleting) return;
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kişiyi sil'),
            content: Text(
              '${person.person.tamAd} kişisini silmek istiyor musunuz? Bu kişiye ait belgeler silinmeyecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (approved != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _data.repository.remove(person.person.id!);
      if (!mounted) return;
      await _changed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kişi silindi. Belgeler arşivde saklanıyor.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kişi silinemedi. Yeniden deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _documentAction(
    BelgeModeli file,
    HomeDocumentAction action,
  ) async {
    final service = BelgeIslemleriServisi();
    switch (action) {
      case HomeDocumentAction.open:
        await service.belgeAc(file, context);
      case HomeDocumentAction.share:
        await service.belgePaylas(file, context);
      case HomeDocumentAction.edit:
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder:
                (_) => BelgeDuzenleEkrani(
                  belge: file,
                  navigation: EditorNavigationScope.maybeOf(context),
                ),
          ),
        );
        if (changed != true || !mounted) return;
        await DocumentActivityService.record(file, 'edit');
      case HomeDocumentAction.delete:
        await service.belgeSil(file, context);
    }
    if (mounted) await _changed();
  }

  Widget _panel({required VoidCallback onClose}) {
    final person = _data.selected;
    if (person == null) return const SizedBox.shrink();
    return PersonDetailPanel(
      key: ValueKey(person.person.id),
      person: person,
      details: _data.details,
      loading: _data.detailLoading,
      error: _data.detailError,
      onClose: onClose,
      onEdit: () => _edit(person.person),
      onAllDocuments: () => _documents(person.person.id!),
      onRetry: () => _data.select(person.person.id!, force: true),
      onDocumentAction: _documentAction,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _data,
    builder:
        (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final mobile = WorkspaceLayout.compact(context);
            final sideBySide =
                constraints.maxWidth >= 1100 &&
                constraints.maxHeight >= 660 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            final showSide = sideBySide && _data.selected != null;
            final toolbar =
                mobile
                    ? MobileWorkspaceToolbar(
                      controller: _search,
                      searchHint: 'Kişilerde ara…',
                      onSearch: _data.search,
                      onChanged: _data.search,
                      filtersOpen: _filtersOpen,
                      hasFilters:
                          _data.categoryId != null ||
                          _data.documentFilter != PeopleDocumentFilter.all ||
                          _data.sort != PeopleSort.name,
                      onToggleFilters: () {
                        if (_filtersOpen && _scroll.hasClients) {
                          _scroll.jumpTo(0);
                        }
                        setState(() => _filtersOpen = !_filtersOpen);
                      },
                    )
                    : WorkspaceToolbar(
                      title: 'Kişiler',
                      subtitle:
                          'Arşivdeki kişileri yönetin, belgelerini ve bilgilerini görüntüleyin.',
                      showHeading: widget.showHeading,
                      searchController: _search,
                      searchHint: 'Kişi adı veya kategoride ara…',
                      onSearch: _data.search,
                      onSearchChanged: _data.search,
                      onFilter:
                          () => setState(
                            () => _desktopFilters = !_desktopFilters,
                          ),
                      onAdd: () => _edit(),
                      addLabel: 'Yeni kişi ekle',
                    );
            final overview = _data.overview;
            final metrics = MetricGrid(
              items: [
                MetricData(
                  'Toplam kişi',
                  overview?.people.length.toString() ?? '—',
                  'Arşivinizdeki aktif kişiler',
                  Icons.people_rounded,
                  AppTone.primary,
                ),
                MetricData(
                  'Toplam belge',
                  overview?.documentCount.toString() ?? '—',
                  'Aktif kişilere ait belgeler',
                  Icons.folder_rounded,
                  AppTone.blue,
                ),
                MetricData(
                  'Kategori',
                  overview?.categories.length.toString() ?? '—',
                  'Kişilerin belgelerinde kullanılan',
                  Icons.category_rounded,
                  AppTone.purple,
                ),
                MetricData(
                  'Ortalama belge',
                  overview?.average.toStringAsFixed(1).replaceAll('.', ',') ??
                      '—',
                  'Kişi başına belge',
                  Icons.description_rounded,
                  AppTone.amber,
                ),
              ],
            );
            Widget list(double width, {bool header = false}) =>
                RefreshIndicator(
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
                              if (!mobile) ...[
                                const SizedBox(height: 20),
                                metrics,
                                const SizedBox(height: 18),
                              ],
                            ],
                          ),
                        ),
                      if (mobile ? _filtersOpen : _desktopFilters)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 12 : 0,
                              vertical: 12,
                            ),
                            child: PeopleFilters(
                              controller: _data,
                              grid: _grid,
                              onView: (value) => setState(() => _grid = value),
                            ),
                          ),
                        ),
                      if (_data.loading || _deleting)
                        const SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            semanticsLabel: 'Kişiler yükleniyor',
                          ),
                        ),
                      if (_data.error != null)
                        SliverToBoxAdapter(
                          child: AppCard(
                            child: Column(
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
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  overview?.people.isEmpty == true
                                      ? 'Henüz kişi eklenmedi.'
                                      : 'Aramanızla eşleşen kişi yok.',
                                ),
                                TextButton.icon(
                                  onPressed: () => _edit(),
                                  icon: const Icon(Icons.person_add_outlined),
                                  label: const Text('Kişi ekle'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _cards(width, sideBySide, mobile),
                      SliverToBoxAdapter(
                        child: SizedBox(height: mobile ? 88 : 24),
                      ),
                    ],
                  ),
                );
            final body = Padding(
              padding: mobile ? EdgeInsets.zero : const EdgeInsets.all(22),
              child:
                  sideBySide
                      ? Column(
                        children: [
                          toolbar,
                          const SizedBox(height: 20),
                          metrics,
                          const SizedBox(height: 18),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (_, box) => list(box.maxWidth),
                                  ),
                                ),
                                if (showSide) ...[
                                  const SizedBox(width: 18),
                                  SizedBox(
                                    width: 344,
                                    child: _panel(onClose: _data.close),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                      : list(
                        constraints.maxWidth - (mobile ? 0 : 44),
                        header: true,
                      ),
            );
            return mobile
                ? MobileWorkspace(
                  onAdd: () => _edit(),
                  addTooltip: 'Kişi ekle',
                  showAdd: !_filtersOpen,
                  child: body,
                )
                : body;
          },
        ),
  );

  Widget _cards(double width, bool sideBySide, bool mobile) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final gap = mobile ? 8.0 : 14.0;
    final columns =
        _grid
            ? ((width + gap) / (280 * scale.clamp(1.0, 1.4) + gap))
                .floor()
                .clamp(mobile ? 2 : 1, 3)
            : 1;
    final compact =
        (width - (columns - 1) * gap) / columns < 250 || scale > 1.3;
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
                            : Builder(
                              builder: (_) {
                                final person =
                                    _data.visible[row * columns + col];
                                return PersonCard(
                                  person: person,
                                  selected:
                                      _data.selectedId == person.person.id,
                                  compact: compact,
                                  onSelect: () => _select(person, sideBySide),
                                  onAction:
                                      (action) =>
                                          _action(person, action, sideBySide),
                                );
                              },
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
}
