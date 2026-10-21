import 'package:flutter/material.dart';
import '../../models/category_overview.dart';
import '../../theme/app_tones.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';
import '../home/home_overview.dart';
import 'category_badge.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onEdit,
    required this.onFavorite,
    required this.onMenu,
    this.compact = false,
    this.list = false,
  });
  final CategoryEntry entry;
  final VoidCallback onOpen, onEdit, onFavorite;
  final ValueChanged<String> onMenu;
  final bool compact, list;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final favorite = IconButton(
      tooltip:
          entry.favorite
              ? 'Sık kullanılanlardan kaldır'
              : 'Sık kullanılanlara ekle',
      isSelected: entry.favorite,
      onPressed: onFavorite,
      icon: Icon(
        entry.favorite ? Icons.star_rounded : Icons.star_border_rounded,
        color:
            entry.favorite ? const Color(0xFFD38A00) : colors.onSurfaceVariant,
        size: 21,
      ),
    );
    final title = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            compact ? MediaQuery.textScalerOf(context).scale(14) * 2.6 : 0,
      ),
      child: Tooltip(
        message: entry.category.kategoriAdi,
        child: Text(
          entry.category.kategoriAdi,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
    final description = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: compact ? MediaQuery.textScalerOf(context).scale(12) * 3 : 0,
      ),
      child: Tooltip(
        message:
            entry.category.aciklama ?? 'Kategori belgelerini görüntüleyin.',
        child: Text(
          entry.category.aciklama?.isNotEmpty == true
              ? entry.category.aciklama!
              : 'Kategori belgelerini görüntüleyin.',
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
    final menu = PopupMenuButton<String>(
      tooltip: 'Kategori seçenekleri',
      onSelected: onMenu,
      itemBuilder:
          (_) => const [
            PopupMenuItem(
              value: 'kisiler',
              child: Text('Kişi bağlantılarını kaldır'),
            ),
            PopupMenuItem(
              value: 'belgeler',
              child: Text('Kategori belgelerini sil'),
            ),
            PopupMenuItem(
              value: 'hepsi',
              child: Text('Belgeleri ve kişi bağlantılarını sil'),
            ),
          ],
      icon: const Icon(Icons.more_vert, size: 19),
    );
    Widget line(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          Row(
            children: [
              CategoryBadge(category: entry.category, size: 38),
              const Spacer(),
              favorite,
            ],
          ),
          const SizedBox(height: 8),
          title,
          const SizedBox(height: 5),
          description,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBadge(category: entry.category, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 5), description],
                ),
              ),
              favorite,
            ],
          ),
        const SizedBox(height: 18),
        line(Icons.description_outlined, '${entry.count} belge'),
        const SizedBox(height: 12),
        Tooltip(
          message: HomeOverview.formatBackupDate(entry.updated),
          child: line(
            Icons.schedule,
            HomeOverview.formatBackupDate(entry.updated),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Tag(entry.group.label, AppTone.blue),
            if (!compact)
              _Tag(
                entry.favorite ? 'Sık kullanılan' : 'Aktif',
                entry.favorite ? AppTone.amber : AppTone.primary,
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (compact)
          Row(
            key: const ValueKey('category-actions'),
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: IconButton.filledTonal(
                    tooltip: 'Aç',
                    onPressed: onOpen,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: IconButton.filledTonal(
                    tooltip: 'Düzenle',
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: SizedBox(height: 48, child: menu)),
            ],
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ToneButton(
                label: 'Aç',
                dense: true,
                icon: Icons.open_in_new,
                onPressed: onOpen,
              ),
              ToneButton(
                label: 'Düzenle',
                dense: true,
                icon: Icons.edit_outlined,
                tone: AppTone.neutral,
                onPressed: onEdit,
              ),
              menu,
            ],
          ),
      ],
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 3,
              color:
                  Color.lerp(
                    categoryColor(context, entry.category.renkKodu),
                    colors.surfaceContainerLowest,
                    .75,
                  )!,
            ),
          ),
        ),
        padding: EdgeInsets.all(compact ? 8 : 16),
        child: content,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.tone);
  final String label;
  final AppTone tone;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colors.foreground),
      ),
    );
  }
}
