import 'package:flutter/material.dart';
import '../../models/people_overview.dart';
import '../../providers/people_controller.dart';
import '../common/view_mode_switch.dart';

class PeopleFilters extends StatelessWidget {
  const PeopleFilters({
    super.key,
    required this.controller,
    required this.grid,
    required this.onView,
  });
  final PeopleController controller;
  final bool grid;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fields = [
        DropdownButtonFormField<int>(
          key: ValueKey(controller.categoryId),
          initialValue: controller.categoryId ?? -1,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: [
            const DropdownMenuItem(value: -1, child: Text('Tüm kategoriler')),
            for (final category in controller.overview?.categories ?? [])
              DropdownMenuItem(
                value: category.id,
                child: Text(
                  category.kategoriAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged:
              (value) => controller.filterCategory(value == -1 ? null : value),
        ),
        DropdownButtonFormField<PeopleDocumentFilter>(
          initialValue: controller.documentFilter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Belge durumu'),
          items: const [
            DropdownMenuItem(
              value: PeopleDocumentFilter.all,
              child: Text('Tüm kişiler'),
            ),
            DropdownMenuItem(
              value: PeopleDocumentFilter.withDocuments,
              child: Text('Belgesi olanlar'),
            ),
            DropdownMenuItem(
              value: PeopleDocumentFilter.withoutDocuments,
              child: Text(
                'Belgesi olmayanlar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) controller.filterDocuments(value);
          },
        ),
        DropdownButtonFormField<PeopleSort>(
          initialValue: controller.sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sıralama'),
          items: [
            for (final item
                in const {
                  PeopleSort.name: 'Ada göre',
                  PeopleSort.updated: 'Son güncellenen',
                  PeopleSort.documents: 'Belge sayısı',
                  PeopleSort.newest: 'Son eklenen',
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
      ];
      final wide =
          constraints.maxWidth > 760 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: fields[i]),
                ],
              ],
            )
          else ...[
            for (final field in fields)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${controller.visible.length} kişi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Kişileri yenile',
                onPressed: controller.loading ? null : controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
              ViewModeSwitch(grid: grid, onChanged: onView),
            ],
          ),
        ],
      );
    },
  );
}
