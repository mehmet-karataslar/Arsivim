import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/backup_controller.dart';
import '../../theme/app_tones.dart';
import '../common/adaptive_card_layout.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';
import 'backup_section.dart';

class BackupSelection extends StatefulWidget {
  const BackupSelection({super.key, required this.data});
  final BackupController data;
  @override
  State<BackupSelection> createState() => _BackupSelectionState();
}

class _BackupSelectionState extends State<BackupSelection> {
  String _query = '';
  int _limit = 24, _categoryLimit = 24;
  String normalize(String value) =>
      value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final people =
        data.people
            .where((p) => normalize(p.tamAd).contains(normalize(_query)))
            .toList();
    final categories = data.availableCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BackupSection(
          number: 2,
          title: 'Yedeklenecek Kişiler',
          subtitle: 'Yedeklemek istediğiniz kişileri seçin.',
          controls: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 255),
                child: TextField(
                  key: const ValueKey('backup-person-search'),
                  onChanged:
                      (value) => setState(() {
                        _query = value;
                        _limit = 24;
                      }),
                  decoration: const InputDecoration(
                    hintText: 'Kişilerde ara…',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    data.running || data.people.isEmpty
                        ? null
                        : data.toggleAllPeople,
                icon: Icon(
                  data.selectedPeople.length == data.people.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                label: Text(
                  data.selectedPeople.isNotEmpty &&
                          data.selectedPeople.length == data.people.length
                      ? 'Seçimi kaldır'
                      : 'Tümünü Seç',
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (people.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    data.people.isEmpty
                        ? 'Henüz kişi eklenmemiş.'
                        : 'Aramanızla eşleşen kişi bulunamadı.',
                  ),
                ),
              AdaptiveCardLayout(
                minCardWidth: 180,
                maxColumns: 4,
                spacing: 10,
                children: [
                  for (var i = 0; i < people.length && i < _limit; i++)
                    Builder(
                      builder: (context) {
                        final p = people[i];
                        final selected = data.selectedPeople.contains(p.id);
                        final tone =
                            [
                              AppTone.blue,
                              AppTone.danger,
                              AppTone.purple,
                              AppTone.amber,
                            ][i % 4];
                        final colors = ToneColors.of(context, tone);
                        return _SelectionCard(
                          key: ValueKey('backup-person-${p.id}'),
                          selected: selected,
                          label: p.tamAd,
                          onTap:
                              data.running
                                  ? null
                                  : () => data.togglePerson(p.id!),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 23,
                                    backgroundColor: colors.iconBackground,
                                    foregroundColor: colors.foreground,
                                    child: Text(
                                      p.ad.trim().isEmpty
                                          ? '?'
                                          : p.ad
                                              .trim()
                                              .characters
                                              .first
                                              .toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.tamAd,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _Detail(
                                Icons.description_outlined,
                                '${data.personDocuments(p.id!)} belge',
                              ),
                              _Detail(
                                Icons.folder_outlined,
                                '${data.personCategories(p.id!)} kategori',
                              ),
                              _Detail(
                                Icons.schedule,
                                DateFormat(
                                  'dd.MM.yyyy',
                                ).format(p.guncellemeTarihi),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (people.length > _limit)
                TextButton(
                  onPressed: () => setState(() => _limit += 24),
                  child: Text(
                    'Daha fazla kişi göster (${people.length - _limit})',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BackupSection(
          number: 3,
          title: 'Kategori Seçimi',
          subtitle:
              'Seçili kişilerin hangi kategorilerdeki belgelerinin yedekleneceğini belirleyin.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categories.isEmpty)
                Text(
                  data.selectedPeople.isEmpty
                      ? 'Kategorileri görmek için önce kişi seçin.'
                      : 'Seçili kişilerin yedeklenecek belgesi bulunmuyor.',
                ),
              AdaptiveCardLayout(
                minCardWidth: 180,
                maxColumns: 4,
                spacing: 10,
                children: [
                  for (
                    var i = 0;
                    i < categories.length && i < _categoryLimit;
                    i++
                  )
                    Builder(
                      builder: (context) {
                        final c = categories[i];
                        return _SelectionCard(
                          key: ValueKey('backup-category-${c.id}'),
                          selected: data.selectedCategories.contains(c.id),
                          label: c.kategoriAdi,
                          onTap:
                              data.running
                                  ? null
                                  : () => data.toggleCategory(c.id!),
                          child: Row(
                            children: [
                              ToneBadge(
                                icon: Icons.folder_outlined,
                                tone:
                                    [
                                      AppTone.primary,
                                      AppTone.blue,
                                      AppTone.purple,
                                      AppTone.amber,
                                    ][i % 4],
                                size: 38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.kategoriAdi,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${data.categoryCounts[c.id] ?? 0} belge',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (categories.length > _categoryLimit)
                TextButton(
                  onPressed: () => setState(() => _categoryLimit += 24),
                  child: const Text('Daha fazla kategori göster'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: selected,
      label: label,
      enabled: onTap != null,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        color:
            selected
                ? Color.lerp(scheme.primaryContainer, scheme.surface, .8)
                : scheme.surface,
        borderColor:
            selected
                ? scheme.primary.withValues(alpha: .65)
                : scheme.outlineVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 19,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
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
