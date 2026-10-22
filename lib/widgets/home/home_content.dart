import '../common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/belge_modeli.dart';
import '../../services/document_repository.dart';
import '../common/app_card.dart';
import '../common/mobile_workspace.dart';
import 'recent_document_filters.dart';
import '../common/workspace_toolbar.dart';
import 'home_actions.dart';
import 'home_overview.dart';
import 'home_storage.dart';
import 'home_search_results.dart';
import 'recent_documents.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({
    super.key,
    required this.summary,
    required this.loading,
    this.error,
    required this.onRefresh,
    required this.onAdd,
    required this.onNavigate,
    required this.onBackup,
    required this.onStorage,
    required this.onDocumentAction,
    this.onSearch,
    this.onAddPerson,
    this.showHeading = true,
    this.repository,
  });
  final AnaSayfaOzeti? summary;
  final DocumentRepository? repository;
  final bool showHeading;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd, onBackup, onStorage;
  final VoidCallback? onAddPerson;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String>? onSearch;
  final void Function(BelgeModeli, HomeDocumentAction) onDocumentAction;
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _search = TextEditingController();
  String? _type;
  bool _filtersOpen = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _filter() async {
    final value = await showDialog<String>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Son belgeleri filtrele'),
            children: [
              for (final type in [
                'Tümü',
                ...{
                  for (final item
                      in widget.summary?.sonBelgeler ?? <SonBelgeOzeti>[])
                    item.belge.dosyaTipi.toUpperCase(),
                },
              ])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, type),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(type),
                  ),
                ),
            ],
          ),
    );
    if (value != null && mounted) {
      setState(() => _type = value == 'Tümü' ? null : value);
    }
  }

  void _status() => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Arşiv durumu'),
          content: Text(
            widget.loading
                ? 'Arşiv bilgileri yenileniyor.'
                : widget.error ??
                    '${widget.summary?.belgeSayisi ?? 0} aktif belge bulunuyor.\n${widget.summary?.sonYedekleme == null ? 'Kayıtlı yedekleme tarihi bulunmuyor.' : 'Son yedekleme: ${HomeOverview.formatBackupDate(widget.summary!.sonYedekleme!)}'}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onRefresh();
              },
              child: const Text('Yenile'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final mobile = WorkspaceLayout.compact(context);
      final wide =
          constraints.maxWidth >= 1050 &&
          MediaQuery.textScalerOf(context).scale(14) < 21;
      final actions = Column(
        children: [
          HomeActions(onNavigate: widget.onNavigate, onBackup: widget.onBackup),
          const SizedBox(height: 16),
          HomeStorage(summary: widget.summary, onSettings: widget.onStorage),
        ],
      );
      final recent =
          _search.text.trim().isNotEmpty
              ? HomeSearchResults(
                query: _search.text,
                repository: widget.repository,
                summary: widget.summary,
                onAction: widget.onDocumentAction,
              )
              : widget.summary == null
              ? AppCard(
                child: Text(
                  widget.loading
                      ? 'Son belgeler yükleniyor…'
                      : 'Son belgeler şu anda gösterilemiyor.',
                ),
              )
              : RecentDocuments(
                documents:
                    widget.summary!.sonBelgeler
                        .where(
                          (item) =>
                              _type == null ||
                              item.belge.dosyaTipi.toUpperCase() == _type,
                        )
                        .toList(),
                filtered: _type != null,
                onAll: () => widget.onNavigate(1),
                onAdd: widget.onAdd,
                onAction: widget.onDocumentAction,
              );
      final content = RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          key: const PageStorageKey('home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              mobile
                  ? const EdgeInsets.only(bottom: 88)
                  : const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mobile) ...[
                MobileWorkspaceToolbar(
                  controller: _search,
                  onSearch: widget.onSearch ?? (_) => widget.onNavigate(1),
                  onChanged: (_) => setState(() {}),
                  filtersOpen: _filtersOpen,
                  hasFilters: _type != null,
                  onToggleFilters:
                      () => setState(() => _filtersOpen = !_filtersOpen),
                ),
                if (_filtersOpen)
                  RecentDocumentFilters(
                    types: {
                      for (final item
                          in widget.summary?.sonBelgeler ?? <SonBelgeOzeti>[])
                        item.belge.dosyaTipi.toUpperCase(),
                    },
                    value: _type,
                    onChanged: (value) => setState(() => _type = value),
                    onAll: () => widget.onNavigate(1),
                  ),
              ] else
                WorkspaceToolbar(
                  showHeading: widget.showHeading,
                  title: 'Ana Sayfa',
                  subtitle: 'Arşivinizin özeti ve sık kullandığınız işlemler.',
                  searchController: _search,
                  onSearch: widget.onSearch ?? (_) => widget.onNavigate(1),
                  onSearchChanged: (_) => setState(() {}),
                  onFilter: _filter,
                  onAdd: widget.onAdd,
                  onAddPerson: widget.onAddPerson,
                  onNotifications: _status,
                ),
              if (!mobile) const SizedBox(height: 26),
              if (widget.loading) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Arşiv bilgileri yükleniyor',
                ),
                const SizedBox(height: 12),
              ],
              if (widget.error != null) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.error!),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: widget.loading ? null : widget.onRefresh,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!mobile) ...[
                HomeOverview(
                  summary: widget.summary,
                  onStorage: widget.onStorage,
                ),
                const SizedBox(height: 20),
              ],
              if (_type != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InputChip(
                    label: Text('Son belgeler: $_type'),
                    onDeleted: () => setState(() => _type = null),
                  ),
                ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recent),
                    const SizedBox(width: 16),
                    SizedBox(width: 320, child: actions),
                  ],
                )
              else ...[
                recent,
                if (!mobile) ...[const SizedBox(height: 20), actions],
              ],
            ],
          ),
        ),
      );
      return mobile
          ? MobileWorkspace(onAdd: widget.onAdd, child: content)
          : content;
    },
  );
}
