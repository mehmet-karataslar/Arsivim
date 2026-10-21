import 'package:flutter/material.dart';
import '../../models/people_overview.dart';
import '../../models/kategori_modeli.dart';
import '../../theme/app_tones.dart';
import '../common/app_card.dart';
import '../categories/category_badge.dart';
import 'person_avatar.dart';

enum PersonAction { edit, documents, view, delete }

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.selected,
    required this.onSelect,
    required this.onAction,
    this.compact = false,
  });
  final PersonSummary person;
  final bool selected, compact;
  final VoidCallback onSelect;
  final ValueChanged<PersonAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = Tooltip(
      message: person.person.tamAd,
      child: Text(
        person.person.tamAd,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 14 : 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final count = Text(
      '${person.documentCount} belge',
      style: TextStyle(
        color: ToneColors.of(context, AppTone.blue).foreground,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
    final menu = PopupMenuButton<PersonAction>(
      tooltip: 'Kişi seçenekleri',
      onSelected: onAction,
      itemBuilder:
          (_) => const [
            PopupMenuItem(value: PersonAction.edit, child: Text('Düzenle')),
            PopupMenuItem(
              value: PersonAction.documents,
              child: Text('Belgeler'),
            ),
            PopupMenuItem(value: PersonAction.view, child: Text('Görüntüle')),
            PopupMenuItem(value: PersonAction.delete, child: Text('Sil')),
          ],
      icon: const Icon(Icons.more_vert, size: 20),
    );
    return Semantics(
      selected: selected,
      child: AppCard(
        onTap: onSelect,
        borderColor: selected ? colors.primary : colors.outlineVariant,
        padding: EdgeInsets.all(compact ? 8 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              Row(
                children: [
                  PersonAvatar(person: person.person, size: 38),
                  const Spacer(),
                  menu,
                ],
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.textScalerOf(context).scale(14) * 2.6,
                ),
                child: name,
              ),
              const SizedBox(height: 4),
              count,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PersonAvatar(person: person.person),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [name, const SizedBox(height: 5), count],
                    ),
                  ),
                  menu,
                ],
              ),
            const SizedBox(height: 12),
            PersonCategories(
              categories: person.categories,
              limit: compact ? 1 : 2,
            ),
            const SizedBox(height: 10),
            Tooltip(
              message:
                  'Son güncelleme: ${person.updated.day}/${person.updated.month}/${person.updated.year}',
              child: Text(
                '${compact ? '' : 'Son güncelleme: '}${person.updated.day}/${person.updated.month}/${person.updated.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final item in const [
                  (
                    PersonAction.edit,
                    'Düzenle',
                    Icons.edit_outlined,
                    AppTone.blue,
                  ),
                  (
                    PersonAction.documents,
                    'Belgeler',
                    Icons.folder_outlined,
                    AppTone.primary,
                  ),
                  (
                    PersonAction.view,
                    'Görüntüle',
                    Icons.visibility_outlined,
                    AppTone.purple,
                  ),
                  (
                    PersonAction.delete,
                    'Sil',
                    Icons.delete_outline,
                    AppTone.danger,
                  ),
                ])
                  Expanded(
                    child: Tooltip(
                      message: item.$2,
                      child: TextButton(
                        key: ValueKey('person-action-${item.$1.name}'),
                        onPressed: () => onAction(item.$1),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 1,
                          ),
                          foregroundColor:
                              ToneColors.of(context, item.$4).foreground,
                        ),
                        child: Semantics(
                          label: item.$2,
                          excludeSemantics: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.$3, size: 18),
                              if (!compact) ...[
                                const SizedBox(height: 5),
                                Text(
                                  item.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PersonCategories extends StatelessWidget {
  const PersonCategories({super.key, required this.categories, this.limit});
  final List<KategoriModeli> categories;
  final int? limit;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      if (categories.isEmpty)
        Text(
          'Kategori yok',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      for (final category in categories.take(limit ?? categories.length))
        Tooltip(
          message: category.kategoriAdi,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: categoryColor(
                context,
                category.renkKodu,
              ).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              category.kategoriAdi,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      if (limit != null && categories.length > limit!)
        Text(
          '+${categories.length - limit!}',
          style: const TextStyle(fontSize: 11),
        ),
    ],
  );
}
