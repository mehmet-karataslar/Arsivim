import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/belge_modeli.dart';
import '../../models/document_filters.dart';
import '../../providers/documents_controller.dart';
import '../../services/document_repository.dart';
import '../common/document_tile.dart';
import '../common/section_surface.dart';

/// Ana sayfadaki arama da Belgeler ile aynı sorguları ve sayfalamayı kullanır.
class HomeSearchResults extends StatefulWidget {
  const HomeSearchResults({
    super.key,
    required this.query,
    required this.summary,
    required this.onAction,
    this.repository,
  });

  final String query;
  final AnaSayfaOzeti? summary;
  final DocumentRepository? repository;
  final void Function(BelgeModeli, HomeDocumentAction) onAction;

  @override
  State<HomeSearchResults> createState() => _HomeSearchResultsState();
}

class _HomeSearchResultsState extends State<HomeSearchResults> {
  late final DocumentsController _data;

  @override
  void initState() {
    super.initState();
    _data = DocumentsController(
      widget.repository ?? DocumentRepository(),
      const DocumentFilters(),
    );
    _data.search(widget.query);
  }

  @override
  void didUpdateWidget(covariant HomeSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _data.search(widget.query);
    } else if (oldWidget.summary != widget.summary) {
      _data.refresh();
    }
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _data,
    builder:
        (context, _) => SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _data.loading
                      ? 'Tüm belgelerde aranıyor…'
                      : 'Arama sonuçları: ${_data.total} belge',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_data.loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Belgeler yükleniyor',
                ),
              if (_data.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
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
              if (!_data.loading &&
                  _data.error == null &&
                  _data.documents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Bu aramayla eşleşen belge bulunamadı.'),
                ),
              if (!_data.loading)
                for (final document in _data.documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DocumentTile(
                      document: document,
                      onAction: widget.onAction,
                      showRelativeTime: true,
                    ),
                  ),
              if (!_data.loading && _data.hasMore)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        _data.loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                              onPressed: _data.loadMore,
                              child: const Text('Daha fazla belge yükle'),
                            ),
                  ),
                ),
            ],
          ),
        ),
  );
}
