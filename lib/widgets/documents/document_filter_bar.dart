import 'package:flutter/material.dart';
import '../../models/document_filters.dart';
import '../../services/document_repository.dart';
import '../../theme/app_tones.dart';

class DocumentFilterBar extends StatelessWidget {
  const DocumentFilterBar({
    super.key,
    required this.filters,
    required this.overview,
    required this.onChanged,
  });
  final DocumentFilters filters;
  final DocumentOverview? overview;
  final ValueChanged<DocumentFilters> onChanged;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final tomorrow = today.add(const Duration(days: 1));
    Widget chip(
      String label,
      bool selected,
      VoidCallback tap, {
      IconData? icon,
      AppTone tone = AppTone.primary,
    }) {
      final colors = ToneColors.of(context, tone);
      return FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        avatar:
            icon == null
                ? null
                : Icon(
                  icon,
                  size: 18,
                  color:
                      selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : colors.foreground,
                ),
        onSelected: (_) => tap(),
        backgroundColor: colors.background,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          color:
              selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          'Tümü (${overview?.summary.belgeSayisi ?? '—'})',
          !filters.hasFilters,
          () => onChanged(
            DocumentFilters(query: filters.query, sort: filters.sort),
          ),
        ),
        for (final type
            in (overview?.types.entries ?? <MapEntry<String, int>>[]).take(4))
          chip(
            '${type.key.toUpperCase()} (${type.value})',
            filters.extension == type.key,
            () => onChanged(
              filters.copyWith(
                extension: type.key,
                clearExtension: filters.extension == type.key,
              ),
            ),
            icon:
                type.key == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
            tone: type.key == 'pdf' ? AppTone.danger : AppTone.blue,
          ),
        for (final category in (overview?.categories ?? <DocumentOption>[])
            .where((c) => c.count > 0)
            .take(3))
          chip(
            '${category.label} (${category.count})',
            filters.categoryId == category.id,
            () => onChanged(
              filters.copyWith(
                categoryId: category.id,
                clearCategory: filters.categoryId == category.id,
              ),
            ),
            icon: Icons.folder_outlined,
            tone: AppTone.purple,
          ),
        chip(
          'Bugün (${overview?.today ?? '—'})',
          filters.from == today,
          () => onChanged(
            filters.copyWith(
              from: today,
              until: tomorrow,
              clearDates: filters.from == today,
            ),
          ),
          icon: Icons.calendar_today_outlined,
          tone: AppTone.neutral,
        ),
        chip(
          'Bu hafta (${overview?.week ?? '—'})',
          filters.from == week && filters.from != today,
          () => onChanged(
            filters.copyWith(
              from: week,
              until: tomorrow,
              clearDates: filters.from == week,
            ),
          ),
          icon: Icons.date_range_outlined,
          tone: AppTone.neutral,
        ),
        if (filters.hasFilters)
          ActionChip(
            avatar: const Icon(Icons.close, size: 16),
            label: const Text('Filtreleri temizle'),
            onPressed:
                () => onChanged(
                  DocumentFilters(query: filters.query, sort: filters.sort),
                ),
          ),
      ],
    );
  }
}
