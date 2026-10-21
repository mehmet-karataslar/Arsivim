import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/sync_comparison.dart';
import '../../utils/kimlik_normalizasyonu.dart';

class SyncDirectionDialog extends StatefulWidget {
  const SyncDirectionDialog({
    super.key,
    required this.localName,
    required this.remoteName,
    required this.compare,
  });
  final String localName, remoteName;
  final Future<SyncComparison> Function() compare;

  @override
  State<SyncDirectionDialog> createState() => _SyncDirectionDialogState();
}

class _SyncDirectionDialogState extends State<SyncDirectionDialog> {
  late Future<SyncComparison> _comparison = widget.compare();
  final _search = TextEditingController();
  String _query = '';
  int _device = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = size.width < 700 ? 8.0 : 24.0;
    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      constraints: const BoxConstraints(maxWidth: 1160),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1160,
        height: math.min(920, size.height - inset * 2),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aktarım yönünü seçin',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<SyncComparison>(
                future: _comparison,
                builder: (context, state) {
                  if (state.connectionState == ConnectionState.done &&
                      state.hasError) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Belgeler karşılaştırılamadı. Hiçbir aktarım başlatılmadı.',
                          ),
                          const SizedBox(height: 12),
                          Text(state.error.toString()),
                          TextButton.icon(
                            onPressed:
                                () => setState(() {
                                  _comparison = widget.compare();
                                }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yeniden dene'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.connectionState != ConnectionState.done ||
                      state.data == null) {
                    return const SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          LinearProgressIndicator(),
                          SizedBox(height: 16),
                          Text('İki cihazdaki belgeler karşılaştırılıyor…'),
                        ],
                      ),
                    );
                  }
                  return _results(state.data!);
                },
              ),
            ),
            const Divider(height: 1),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Şimdi değil'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SyncDocumentPreview> _filter(List<SyncDocumentPreview> documents) =>
      _query.isEmpty
          ? documents
          : documents.where((document) {
            final text = [
              document.title,
              document.fileName,
              ...document.people,
              ...document.categories,
            ].join(' ');
            return KimlikNormalizasyonu.metin(text).contains(_query);
          }).toList();

  Widget _results(SyncComparison comparison) {
    final local = _filter(comparison.localDocuments);
    final remote = _filter(comparison.remoteDocuments);
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide =
            bounds.maxWidth >= 800 &&
            MediaQuery.textScalerOf(context).scale(14) <= 22;
        final visible = _device == 0 ? local : remote;
        return CustomScrollView(
          key: const ValueKey('sync-comparison-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${widget.localName}: ${comparison.sendIds.length} yeni belge',
                    ),
                    Text(
                      '${widget.remoteName}: ${comparison.receiveIds.length} yeni belge',
                    ),
                    const SizedBox(height: 6),
                    Text('${comparison.same} belge iki cihazda da mevcut.'),
                    if (comparison.conflicts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${comparison.conflicts.length} çakışan kayıt aktarılmayacak.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (comparison.localDocuments.isEmpty &&
                          comparison.remoteDocuments.isEmpty)
                        for (final title in comparison.conflicts) Text(title),
                    ],
                    if (comparison.issues.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${comparison.issues.length} kayıt doğrulanamadı ve atlanacak.',
                      ),
                      for (final title in comparison.issues) Text(title),
                    ],
                    const SizedBox(height: 16),
                    _directions(comparison, wide),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('sync-document-search'),
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Kişi veya dosya ara',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged:
                          (value) => setState(
                            () => _query = KimlikNormalizasyonu.metin(value),
                          ),
                    ),
                    if (!wide) ...[
                      const SizedBox(height: 12),
                      DefaultTabController(
                        length: 2,
                        initialIndex: _device,
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          onTap: (value) => setState(() => _device = value),
                          tabs: const [
                            Tab(text: 'Bu cihaz'),
                            Tab(text: 'Karşı cihaz'),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _deviceHeading(
                              widget.localName,
                              local.length,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _deviceHeading(
                              widget.remoteName,
                              remote.length,
                            ),
                          ),
                        ],
                      )
                    else
                      _deviceHeading(
                        _device == 0 ? widget.localName : widget.remoteName,
                        visible.length,
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList.builder(
                itemCount:
                    wide
                        ? math.max(1, math.max(local.length, remote.length))
                        : math.max(1, visible.length),
                itemBuilder: (context, index) {
                  Widget entry(List<SyncDocumentPreview> documents) =>
                      index < documents.length
                          ? _DocumentRow(document: documents[index])
                          : index == 0
                          ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _query.isEmpty
                                  ? 'Listelenecek yeni veya farklı belge yok.'
                                  : 'Aramayla eşleşen belge yok.',
                            ),
                          )
                          : const SizedBox.shrink();
                  return wide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: entry(local)),
                          const SizedBox(width: 24),
                          Expanded(child: entry(remote)),
                        ],
                      )
                      : entry(visible);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _deviceHeading(String name, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name, style: Theme.of(context).textTheme.titleMedium),
      Text('$count yeni / farklı belge'),
      const SizedBox(height: 8),
      const Divider(height: 1),
    ],
  );

  Widget _directions(SyncComparison comparison, bool wide) {
    final send = FilledButton.icon(
      key: const ValueKey('sync-direction-send'),
      onPressed:
          comparison.sendIds.isEmpty
              ? null
              : () => Navigator.pop(
                context,
                SyncDirectionChoice(SyncDirection.send, comparison),
              ),
      icon: const Icon(Icons.upload_outlined),
      label: Text(
        '${widget.localName} → ${widget.remoteName}\n${comparison.sendIds.length} yeni belge gönder',
        textAlign: TextAlign.center,
      ),
    );
    final receive = OutlinedButton.icon(
      key: const ValueKey('sync-direction-receive'),
      onPressed:
          comparison.receiveIds.isEmpty
              ? null
              : () => Navigator.pop(
                context,
                SyncDirectionChoice(SyncDirection.receive, comparison),
              ),
      icon: const Icon(Icons.download_outlined),
      label: Text(
        '${widget.remoteName} → ${widget.localName}\n${comparison.receiveIds.length} yeni belge al',
        textAlign: TextAlign.center,
      ),
    );
    return wide
        ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: send),
            const SizedBox(width: 24),
            Expanded(child: receive),
          ],
        )
        : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [send, const SizedBox(height: 10), receive],
        );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});
  final SyncDocumentPreview document;

  String _date(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.title, style: theme.textTheme.titleSmall),
          if (document.fileName.isNotEmpty) Text('Dosya: ${document.fileName}'),
          const SizedBox(height: 6),
          Text(
            'Kişi: ${document.people.isNotEmpty
                ? document.people.join(', ')
                : document.hasDetails
                ? 'Atanmamış'
                : 'Karşı cihaz kişi ayrıntısı göndermedi'}',
          ),
          Text(
            'Kategori: ${document.categories.isNotEmpty
                ? document.categories.join(', ')
                : document.hasDetails
                ? 'Atanmamış'
                : 'Ayrıntı alınamadı'}',
          ),
          if (document.createdAt != null)
            Text('Eklenme: ${_date(document.createdAt!)}'),
          if (document.updatedAt != null)
            Text('Güncelleme: ${_date(document.updatedAt!)}'),
          if (document.size != null) Text('Boyut: ${_size(document.size!)}'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                document.isConflict
                    ? Icons.warning_amber
                    : Icons.add_circle_outline,
                size: 18,
                color:
                    document.isConflict
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  document.isConflict
                      ? '${document.conflictReason} · Aktarılmayacak'
                      : 'Yeni belge',
                  style: TextStyle(
                    color:
                        document.isConflict
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
