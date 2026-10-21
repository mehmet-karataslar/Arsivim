import 'package:flutter/material.dart';
import '../models/scan_page.dart';
import '../providers/scan_review_controller.dart';
import '../services/document_scan_service.dart';
import '../widgets/document_editor/scan_page_view.dart';

class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.pages,
    required this.scanner,
    this.name,
  });
  final List<ScanPage> pages;
  final DocumentScanService scanner;
  final String? name;
  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final data = ScanReviewController(widget.pages, widget.scanner);
  late final name = TextEditingController(
    text:
        widget.name ??
        'Tarama_${DateTime.now().toIso8601String().substring(0, 10)}',
  );
  bool _leaving = false, _closing = false;
  @override
  void dispose() {
    data.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (data.busy || _closing) return;
    _closing = true;
    final discard =
        data.pages.isEmpty ||
        await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Taramadan çıkılsın mı?'),
                    content: const Text(
                      'Bu ekrandaki değişiklikler PDF’ye uygulanmayacak. Belge formunuz korunur.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Devam et'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Taramadan çık'),
                      ),
                    ],
                  ),
            ) ==
            true;
    _closing = false;
    if (mounted && discard) _pop();
  }

  void _pop([ScannedPdf? result]) {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    final result = await data.finish(name.text);
    if (mounted && result != null) _pop(result);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: data,
    builder:
        (context, _) => PopScope(
          canPop: _leaving,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _close();
          },
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('Taramayı kontrol et'),
              leading: IconButton(
                tooltip: 'Taramadan çık',
                onPressed: data.busy ? null : _close,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scroll =
                      constraints.maxHeight < 650 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  final canvas = ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: SizedBox.expand(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child:
                            data.current == null
                                ? const Center(
                                  child: Text('Sayfa ekleyerek başlayın.'),
                                )
                                : ScanPageView(page: data.current!),
                      ),
                    ),
                  );
                  final children = <Widget>[
                    if (data.busy) const LinearProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: name,
                        enabled: !data.busy,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'PDF adı',
                          suffixText: '.pdf',
                          counterText: '',
                        ),
                      ),
                    ),
                    if (data.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          data.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (scroll)
                      SizedBox(height: 260, child: canvas)
                    else
                      Expanded(child: canvas),
                    if (data.pages.isNotEmpty)
                      ScanPageStrip(
                        pages: data.pages,
                        selected: data.selected,
                        onSelected: data.busy ? null : data.select,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Öne taşı',
                            onPressed:
                                data.busy || data.selected == 0
                                    ? null
                                    : () => data.move(-1),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          IconButton(
                            tooltip: 'Arkaya taşı',
                            onPressed:
                                data.busy ||
                                        data.selected >= data.pages.length - 1
                                    ? null
                                    : () => data.move(1),
                            icon: const Icon(Icons.arrow_forward),
                          ),
                          IconButton(
                            tooltip: 'Sayfayı döndür',
                            onPressed:
                                data.busy || data.pages.isEmpty
                                    ? null
                                    : data.rotate,
                            icon: const Icon(Icons.rotate_right),
                          ),
                          IconButton(
                            tooltip: 'Sayfayı kaldır',
                            onPressed:
                                data.busy || data.pages.isEmpty
                                    ? null
                                    : data.remove,
                            icon: const Icon(Icons.delete_outline),
                          ),
                          if (data.canUndo)
                            IconButton(
                              tooltip: 'Silmeyi geri al',
                              onPressed: data.undo,
                              icon: const Icon(Icons.undo),
                            ),
                          if (widget.scanner.isSupported)
                            TextButton.icon(
                              key: const ValueKey('scan-add-pages'),
                              onPressed: data.busy ? null : data.addPages,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Sayfa ekle'),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${data.pages.length} sayfa · Tek PDF · Henüz arşive kaydedilmedi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const ValueKey('scan-create-pdf'),
                            onPressed:
                                data.busy || data.pages.isEmpty
                                    ? null
                                    : _finish,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(
                              data.busy
                                  ? 'Hazırlanıyor…'
                                  : 'PDF oluştur ve belgeye ekle',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                  return scroll
                      ? SingleChildScrollView(child: Column(children: children))
                      : Column(children: children);
                },
              ),
            ),
          ),
        ),
  );
}
