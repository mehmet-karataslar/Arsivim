import 'package:flutter/material.dart';
import '../../models/category_overview.dart';
import '../../providers/categories_controller.dart';
import '../common/view_mode_switch.dart';

String categoryFilterLabel(CategoryFilter value) => switch (value) {
  CategoryFilter.all => 'Tüm kategoriler',
  CategoryFilter.active => 'Aktif',
  CategoryFilter.favorites => 'Sık kullanılanlar',
  CategoryFilter.recent => 'Son eklenenler',
  CategoryFilter.mostUsed => 'En çok kullanılan',
  CategoryFilter.personal => 'Kişisel',
  CategoryFilter.work => 'İş',
  CategoryFilter.official => 'Resmi',
};
IconData categoryFilterIcon(CategoryFilter value) => switch (value) {
  CategoryFilter.all || CategoryFilter.active => Icons.folder_outlined,
  CategoryFilter.favorites => Icons.star_outline,
  CategoryFilter.recent => Icons.schedule,
  CategoryFilter.mostUsed => Icons.bar_chart,
  CategoryFilter.personal => Icons.person_outline,
  CategoryFilter.work => Icons.work_outline,
  CategoryFilter.official => Icons.business_outlined,
};

class CategoryFilters extends StatelessWidget {
  const CategoryFilters({
    super.key,
    required this.controller,
    required this.grid,
    required this.onView,
  });
  final CategoriesController controller;
  final bool grid;
  final ValueChanged<bool> onView;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final filters = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in [
            CategoryFilter.all,
            CategoryFilter.active,
            CategoryFilter.mostUsed,
            CategoryFilter.recent,
            CategoryFilter.personal,
            CategoryFilter.work,
            CategoryFilter.official,
          ])
            FilterChip(
              label: Text(
                filter == CategoryFilter.all
                    ? 'Tümü (${controller.count(filter)})'
                    : filter == CategoryFilter.active
                    ? 'Aktif (${controller.count(filter)})'
                    : categoryFilterLabel(filter),
              ),
              selected: controller.filter == filter,
              showCheckmark: false,
              onSelected: (_) => controller.select(filter),
              avatar:
                  filter == CategoryFilter.all ||
                          filter == CategoryFilter.active
                      ? null
                      : Icon(
                        categoryFilterIcon(filter),
                        size: 16,
                        color:
                            controller.filter == filter
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                      ),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerLow,
              labelStyle: TextStyle(
                fontSize: 12,
                color:
                    controller.filter == filter
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
              ),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      );
      if (constraints.maxWidth >= 1000 &&
          MediaQuery.textScalerOf(context).scale(14) <= 17) {
        return Row(
          children: [
            Expanded(child: filters),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Kategorileri yenile',
              onPressed: controller.loading ? null : controller.refresh,
              icon: const Icon(Icons.refresh, size: 19),
            ),
            ViewModeSwitch(grid: grid, onChanged: onView),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filters,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${controller.visible.length} kategori',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kategorileri yenile',
                onPressed: controller.loading ? null : controller.refresh,
                icon: const Icon(Icons.refresh, size: 19),
              ),
              ViewModeSwitch(grid: grid, onChanged: onView),
            ],
          ),
        ],
      );
    },
  );
}
