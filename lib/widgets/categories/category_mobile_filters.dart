import 'package:flutter/material.dart';
import '../../models/category_overview.dart';
import '../../providers/categories_controller.dart';
import '../common/view_mode_switch.dart';
import 'category_filters.dart';

class CategoryMobileFilters extends StatelessWidget {
  const CategoryMobileFilters({
    super.key,
    required this.controller,
    required this.grid,
    required this.onView,
    required this.actions,
  });
  final CategoriesController controller;
  final bool grid;
  final ValueChanged<bool> onView;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<CategoryFilter>(
          initialValue: controller.filter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kategori filtresi'),
          items: [
            for (final filter in CategoryFilter.values)
              DropdownMenuItem(
                value: filter,
                child: Text(
                  '${categoryFilterLabel(filter)} (${controller.count(filter)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.select(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CategorySort>(
          initialValue: controller.sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sıralama'),
          items: [
            for (final item
                in const {
                  CategorySort.updated: 'Son güncellenen',
                  CategorySort.name: 'Ada göre',
                  CategorySort.mostUsed: 'Belge sayısına göre',
                  CategorySort.newest: 'Son eklenen',
                }.entries)
              DropdownMenuItem(
                value: item.key,
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.order(value);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ViewModeSwitch(grid: grid, onChanged: onView),
            IconButton(
              tooltip: 'Kategorileri yenile',
              onPressed: controller.loading ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
            actions,
          ],
        ),
      ],
    ),
  );
}
