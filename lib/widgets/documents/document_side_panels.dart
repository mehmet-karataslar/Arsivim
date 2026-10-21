import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/document_filters.dart';
import '../../services/document_repository.dart';
import '../../theme/app_tones.dart';
import '../common/app_card.dart';
import '../common/document_tile.dart';
import '../common/tone_widgets.dart';
import '../home/home_storage.dart';

class DocumentSidePanels extends StatelessWidget {
  const DocumentSidePanels({
    super.key,
    required this.overview,
    required this.filters,
    required this.onFilter,
    required this.onOpen,
    required this.onStorage,
  });
  final DocumentOverview? overview;
  final DocumentFilters filters;
  final ValueChanged<DocumentFilters> onFilter;
  final ValueChanged<SonBelgeOzeti> onOpen;
  final VoidCallback onStorage;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _PanelTitle(
                'Hızlı filtreler',
                'Sık kullanılan filtrelere hızlı erişim.',
                Icons.bolt,
                AppTone.amber,
              ),
              const SizedBox(height: 14),
              for (final item in [
                (
                  'PDF dosyaları',
                  Icons.picture_as_pdf_outlined,
                  overview?.types['pdf'] ?? 0,
                  filters.extension == 'pdf',
                  () => onFilter(
                    filters.copyWith(
                      extension: 'pdf',
                      clearExtension: filters.extension == 'pdf',
                    ),
                  ),
                ),
                (
                  'Son eklenenler',
                  Icons.schedule,
                  overview?.today ?? 0,
                  filters.from == today,
                  () => onFilter(
                    filters.copyWith(
                      from: today,
                      until: today.add(const Duration(days: 1)),
                      clearDates: filters.from == today,
                    ),
                  ),
                ),
                (
                  'Son paylaşılanlar',
                  Icons.share_outlined,
                  overview?.sharedIds.length ?? 0,
                  filters.shared,
                  () => onFilter(filters.copyWith(shared: !filters.shared)),
                ),
                (
                  'Büyük dosyalar (> 1 MB)',
                  Icons.insert_drive_file_outlined,
                  overview?.large ?? 0,
                  filters.large,
                  () => onFilter(filters.copyWith(large: !filters.large)),
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color:
                        item.$4
                            ? Theme.of(context).colorScheme.primaryContainer
                            : ToneColors.of(context, AppTone.blue).background,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: item.$5,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(
                              item.$2,
                              color:
                                  ToneColors.of(
                                    context,
                                    AppTone.blue,
                                  ).foreground,
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$1,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.$3}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                'Son aktiviteler',
                'Bu cihazdaki son işlemler.',
                Icons.history,
                AppTone.blue,
              ),
              const SizedBox(height: 12),
              if (overview?.activities.isNotEmpty != true)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Henüz kayıtlı işlem yok.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              for (final item in overview?.activities ?? <RecentActivity>[])
                InkWell(
                  onTap: () => onOpen(item.document),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        FileBadge(
                          extension: item.document.belge.dosyaTipi,
                          size: 34,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.document.belge.baslik ??
                                    item.document.belge.orijinalDosyaAdi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.activity.action == 'share'
                                    ? 'Paylaşıldı'
                                    : item.activity.action == 'edit'
                                    ? 'Düzenlendi'
                                    : 'Açıldı'} · ${_time(item.activity.time)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HomeStorage(summary: overview?.summary, onSettings: onStorage),
      ],
    );
  }

  String _time(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inMinutes < 1) return 'Az önce';
    if (duration.inHours < 1) return '${duration.inMinutes} dk önce';
    if (duration.inDays < 1) return '${duration.inHours} sa önce';
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, this.subtitle, this.icon, this.tone);
  final String title, subtitle;
  final IconData icon;
  final AppTone tone;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ToneBadge(icon: icon, tone: tone, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
