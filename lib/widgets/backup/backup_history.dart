import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/backup_overview.dart';
import '../../utils/screen_utils.dart';
import 'backup_section.dart';

class BackupHistory extends StatelessWidget {
  const BackupHistory({
    super.key,
    required this.records,
    this.expanded = false,
  });
  final List<BackupRecord> records;
  final bool expanded;
  @override
  Widget build(BuildContext context) => BackupSection(
    title: 'Son Yedeklemeler',
    icon: Icons.history,
    trailing:
        expanded || records.length <= 4
            ? null
            : TextButton(
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (ctx) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 720,
                              maxHeight: 650,
                            ),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Kapat',
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: BackupHistory(
                                      records: records,
                                      expanded: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
              child: const Text('Tümünü Gör', style: TextStyle(fontSize: 12)),
            ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Henüz kayıtlı yedekleme yok. Yeni işlemler burada listelenecek.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        for (final record in records.take(expanded ? 50 : 4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  record.error == null
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color:
                      record.error == null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                  size: 23,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.error == null
                            ? 'Yedekleme tamamlandı'
                            : 'Yedekleme tamamlanamadı',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.people} kişi · ${record.categories} kategori · ${record.documents} belge',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('dd.MM.yyyy HH:mm').format(record.time)}${record.error == null ? ' · ${ScreenUtils.formatFileSize(record.bytes)}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Tooltip(
                        message: record.error ?? record.path,
                        child: Text(
                          record.error ?? record.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
