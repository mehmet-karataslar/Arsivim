import 'package:flutter/material.dart';
import '../../models/category_overview.dart';
import '../../providers/categories_controller.dart';
import '../common/app_card.dart';
import '../home/home_overview.dart';
import 'category_badge.dart';
import 'category_filters.dart';

class CategorySidePanels extends StatelessWidget {
  const CategorySidePanels({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onFavorite,
  });
  final CategoriesController controller;
  final ValueChanged<CategoryEntry> onOpen, onFavorite;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final favorites =
        controller.overview?.entries.where((e) => e.favorite).toList() ??
        <CategoryEntry>[];
    final events = controller.overview?.events ?? <CategoryEvent>[];
    Widget title(IconData icon, String label) => Row(
      children: [
        Icon(icon, color: colors.onSurface, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              title(Icons.filter_alt_outlined, 'Hızlı filtreler'),
              const SizedBox(height: 14),
              for (final filter in CategoryFilter.values.where(
                (f) => f != CategoryFilter.active,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color:
                        controller.filter == filter
                            ? colors.primaryContainer
                            : colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => controller.select(filter),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical:
                              MediaQuery.sizeOf(context).width < 600 ? 12 : 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              categoryFilterIcon(filter),
                              size: 20,
                              color:
                                  filter == CategoryFilter.favorites
                                      ? const Color(0xFFD38A00)
                                      : colors.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                categoryFilterLabel(filter),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${controller.count(filter)}',
                              style: const TextStyle(fontSize: 12),
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
              title(Icons.star_rounded, 'Sık kullanılan kategoriler'),
              const SizedBox(height: 12),
              if (favorites.isEmpty)
                const Text(
                  'Kategorilerdeki yıldıza dokunarak buraya ekleyebilirsiniz.',
                  style: TextStyle(fontSize: 12),
                ),
              for (final entry in favorites.take(5))
                InkWell(
                  onTap: () => onOpen(entry),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CategoryBadge(category: entry.category, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.category.kategoriAdi,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${entry.count} belge',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sık kullanılanlardan kaldır',
                          onPressed: () => onFavorite(entry),
                          icon: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFD38A00),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (favorites.length > 5)
                TextButton(
                  onPressed: () => controller.select(CategoryFilter.favorites),
                  child: const Text('Tümünü gör'),
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
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.history, size: 23),
                  const Text(
                    'Son işlemler',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Son kategori işlemleri'),
                                content: SizedBox(
                                  width: 480,
                                  height: 440,
                                  child: ListView(
                                    children: [
                                      for (final event in events)
                                        _EventRow(event),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Kapat'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Tümünü gör'),
                  ),
                ],
              ),
              if (events.isEmpty)
                const Text(
                  'Henüz kayıtlı işlem yok.',
                  style: TextStyle(fontSize: 12),
                ),
              for (final event in events.take(4)) _EventRow(event),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);
  final CategoryEvent event;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        CategoryBadge(category: event.category, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event.category.kategoriAdi} ${event.label}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${HomeOverview.formatBackupDate(event.time)} · ${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
