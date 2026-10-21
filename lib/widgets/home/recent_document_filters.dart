import 'package:flutter/material.dart';

class RecentDocumentFilters extends StatelessWidget {
  const RecentDocumentFilters({
    super.key,
    required this.types,
    required this.value,
    required this.onChanged,
    required this.onAll,
  });
  final Set<String> types;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value ?? '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Son belgelerde dosya türü',
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Tüm türler')),
            for (final type in {...types, if (value != null) value!})
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) => onChanged(value == '' ? null : value),
        ),
        TextButton(
          onPressed: onAll,
          child: const Text('Tüm arşivde ara ve filtrele'),
        ),
      ],
    ),
  );
}
