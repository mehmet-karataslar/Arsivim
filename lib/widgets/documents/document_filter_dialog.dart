import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/document_filters.dart';
import '../../services/document_repository.dart';

Future<DocumentFilters?> showDocumentFilters(
  BuildContext context,
  DocumentFilters filters,
  DocumentOverview? overview,
) => showDialog<DocumentFilters>(
  context: context,
  builder:
      (context) => Dialog(
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: DocumentFilterPanel(
              filters: filters,
              overview: overview,
              onApply: (value) => Navigator.pop(context, value),
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
);

/// Aynı form mobil açılır panelde ve masaüstü iletişim kutusunda kullanılır.
class DocumentFilterPanel extends StatefulWidget {
  const DocumentFilterPanel({
    super.key,
    required this.filters,
    required this.overview,
    required this.onApply,
    required this.onClose,
  });
  final DocumentFilters filters;
  final DocumentOverview? overview;
  final ValueChanged<DocumentFilters> onApply;
  final VoidCallback onClose;
  @override
  State<DocumentFilterPanel> createState() => _DocumentFilterPanelState();
}

class _DocumentFilterPanelState extends State<DocumentFilterPanel> {
  late DocumentFilters value = widget.filters;
  int revision = 0;
  String dateLabel(DateTime date) => '${date.day}.${date.month}.${date.year}';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Belgeleri filtrele',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Filtre panelini kapat',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        SizedBox(
          height: math.min(320, MediaQuery.sizeOf(context).height * .36),
          child: SingleChildScrollView(
            child: KeyedSubtree(
              key: ValueKey(revision),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: value.extension ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Dosya türü'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Tüm türler'),
                      ),
                      for (final type in {
                        ...?widget.overview?.types.keys,
                        if (value.extension != null) value.extension!,
                      })
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        ),
                    ],
                    onChanged:
                        (v) => setState(
                          () =>
                              value = value.copyWith(
                                extension: v,
                                clearExtension: v == '',
                              ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue:
                        widget.overview?.categories.any(
                                  (c) => c.id == value.categoryId,
                                ) ==
                                true
                            ? value.categoryId
                            : -1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Tüm kategoriler'),
                      ),
                      for (final option
                          in widget.overview?.categories ?? <DocumentOption>[])
                        DropdownMenuItem(
                          value: option.id,
                          child: Tooltip(
                            message: option.label,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged:
                        (v) => setState(
                          () =>
                              value = value.copyWith(
                                categoryId: v,
                                clearCategory: v == -1,
                              ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue:
                        widget.overview?.people.any(
                                  (p) => p.id == value.personId,
                                ) ==
                                true
                            ? value.personId
                            : -1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kişi'),
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Tüm kişiler'),
                      ),
                      for (final option
                          in widget.overview?.people ?? <DocumentOption>[])
                        DropdownMenuItem(
                          value: option.id,
                          child: Tooltip(
                            message: option.label,
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged:
                        (v) => setState(
                          () =>
                              value = value.copyWith(
                                personId: v,
                                clearPerson: v == -1,
                              ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      value.from == null
                          ? 'Tarih aralığı seç'
                          : '${dateLabel(value.from!)} – ${value.until == null ? '…' : dateLabel(value.until!.subtract(const Duration(days: 1)))}',
                    ),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (range != null && mounted) {
                        setState(
                          () =>
                              value = value.copyWith(
                                from: range.start,
                                until: range.end.add(const Duration(days: 1)),
                              ),
                        );
                      }
                    },
                  ),
                  if (value.from != null || value.until != null)
                    TextButton(
                      onPressed:
                          () => setState(
                            () => value = value.copyWith(clearDates: true),
                          ),
                      child: const Text('Tarih aralığını kaldır'),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Büyük dosyalar (> 1 MB)'),
                    value: value.large,
                    onChanged:
                        (v) => setState(() => value = value.copyWith(large: v)),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Son paylaşılanlar'),
                    subtitle: const Text(
                      'Bu cihazdaki kayıtlı paylaşım geçmişi',
                    ),
                    value: value.shared,
                    onChanged:
                        (v) =>
                            setState(() => value = value.copyWith(shared: v)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DocumentSort>(
                    initialValue: value.sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sıralama'),
                    items: [
                      for (final item
                          in const {
                            DocumentSort.newest: 'Son eklenenler',
                            DocumentSort.oldest: 'İlk eklenenler',
                            DocumentSort.name: 'Ada göre',
                            DocumentSort.largest: 'Boyuta göre',
                          }.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                    ],
                    onChanged:
                        (sort) =>
                            setState(() => value = value.copyWith(sort: sort)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed:
                  () => setState(() {
                    value = DocumentFilters(query: widget.filters.query);
                    revision++;
                  }),
              child: const Text('Sıfırla'),
            ),
            TextButton(onPressed: widget.onClose, child: const Text('İptal')),
            FilledButton(
              onPressed: () => widget.onApply(value),
              child: const Text('Uygula'),
            ),
          ],
        ),
      ],
    ),
  );
}
