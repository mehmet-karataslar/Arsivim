import 'package:flutter/material.dart';
import '../../models/sync_comparison.dart';

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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Aktarım yönünü seçin'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(child: FutureBuilder<SyncComparison>(
        future: _comparison,
        builder: (context, state) {
          if (state.hasError) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Belgeler karşılaştırılamadı. Hiçbir aktarım başlatılmadı.'),
              const SizedBox(height: 12),
              Text(state.error.toString()),
              TextButton.icon(
                onPressed: () => setState(() { _comparison = widget.compare(); }),
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden dene'),
              ),
            ]);
          }
          final comparison = state.data;
          if (comparison == null) {
            return const Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text('İki cihazdaki belgeler karşılaştırılıyor…'),
            ]);
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${widget.localName}: ${comparison.sendIds.length} yeni belge'),
                Text('${widget.remoteName}: ${comparison.receiveIds.length} yeni belge'),
                const SizedBox(height: 8),
                Text('${comparison.same} belge iki cihazda da mevcut.'),
                if (comparison.conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('${comparison.conflicts.length} çakışan kayıt aktarılmayacak.'),
                  for (final title in comparison.conflicts.take(10)) Text(title),
                ],
                if (comparison.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('${comparison.issues.length} kayıt doğrulanamadı ve atlanacak.'),
                  for (final title in comparison.issues.take(10)) Text(title),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('sync-direction-send'),
                  onPressed: comparison.sendIds.isEmpty ? null : () => Navigator.pop(
                    context, SyncDirectionChoice(SyncDirection.send, comparison)),
                  icon: const Icon(Icons.upload_outlined),
                  label: Text('${widget.localName} → ${widget.remoteName}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('sync-direction-receive'),
                  onPressed: comparison.receiveIds.isEmpty ? null : () => Navigator.pop(
                    context, SyncDirectionChoice(SyncDirection.receive, comparison)),
                  icon: const Icon(Icons.download_outlined),
                  label: Text('${widget.remoteName} → ${widget.localName}'),
                ),
              ],
            ),
          );
        },
      )),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Şimdi değil'))],
  );
}
