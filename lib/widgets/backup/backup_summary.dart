import 'package:flutter/material.dart';
import '../../providers/backup_controller.dart';
import '../../utils/screen_utils.dart';
import 'backup_section.dart';

class BackupSummary extends StatelessWidget {
  const BackupSummary({super.key, required this.data});
  final BackupController data;
  @override
  Widget build(BuildContext context) {
    final people = data.people
        .where((p) => data.selectedPeople.contains(p.id))
        .map((p) => p.tamAd)
        .join(', ');
    final categories = data.availableCategories
        .where((c) => data.selectedCategories.contains(c.id))
        .map((c) => c.kategoriAdi)
        .join(', ');
    return BackupSection(
      title: 'Yedekleme Özeti',
      icon: Icons.snippet_folder_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            Icons.person_outline,
            'Seçili kişiler',
            '${data.selectedPeople.length} kişi',
            people,
          ),
          _SummaryRow(
            Icons.folder_outlined,
            'Seçili kategoriler',
            '${data.selectedCategories.length} kategori',
            categories,
          ),
          _SummaryRow(
            Icons.description_outlined,
            'Toplam belge',
            '${data.documentCount} belge',
            'Ortak bağlantılı belgeler bir kez sayılır.',
          ),
          _SummaryRow(
            Icons.storage_outlined,
            'Tahmini boyut',
            ScreenUtils.formatFileSize(data.estimatedBytes),
            'Kişi klasörlerindeki kopyaların toplamı; kayıt bilgileri hariç.',
          ),
          const _SummaryRow(
            Icons.inventory_2_outlined,
            'Yedekleme formatı',
            'Klasör + kayıt bilgileri',
            'Dosyalar ve kişi/kategori bağlantıları korunur.',
          ),
          _SummaryRow(
            Icons.folder_open,
            'Hedef klasör',
            data.target ?? 'Seçilmedi',
            '',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Seçilen kişilerin, işaretlediğiniz kategorilerdeki belgeleri yeni bir yedek klasöründe toplanır.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          if (data.operation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(data.operation, style: const TextStyle(fontSize: 13)),
            ),
            if (data.running) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: data.progress),
              const SizedBox(height: 6),
              Text(
                '%${(data.progress * 100).round()}',
                textAlign: TextAlign.right,
              ),
            ],
          ],
          if (data.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                data.message!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final clear = OutlinedButton.icon(
                onPressed:
                    data.running || data.selectedPeople.isEmpty
                        ? null
                        : data.clear,
                icon: const Icon(Icons.delete_outline, size: 19),
                label: const Text('Seçimi Temizle'),
              );
              final start = FilledButton.icon(
                key: const ValueKey('backup-start'),
                onPressed: data.canStart ? data.start : null,
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: Text(
                  data.running ? 'Yedekleniyor…' : 'Yedeklemeyi Başlat',
                ),
              );
              if (constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [start, const SizedBox(height: 10), clear],
                );
              }
              return Row(
                children: [
                  Expanded(child: clear),
                  const SizedBox(width: 10),
                  Expanded(child: start),
                ],
              );
            },
          ),
          if (!data.canStart && !data.running)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                data.target == null
                    ? 'Başlamak için hedef klasör seçin.'
                    : 'En az bir belge içeren kişi ve kategori seçin.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.icon, this.label, this.value, this.detail);
  final IconData icon;
  final String label, value, detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          ],
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Tooltip(
                message: detail,
                child: Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        );
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 8), content],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: heading),
            const SizedBox(width: 10),
            Expanded(flex: 6, child: content),
          ],
        );
      },
    ),
  );
}
