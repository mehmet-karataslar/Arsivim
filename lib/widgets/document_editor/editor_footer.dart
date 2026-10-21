import 'package:flutter/material.dart';

class EditorFooter extends StatelessWidget {
  const EditorFooter({
    super.key,
    required this.busy,
    required this.editing,
    required this.onCancel,
    required this.onDraft,
    required this.onSave,
  });
  final bool busy, editing;
  final VoidCallback onCancel, onDraft, onSave;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final cancel = TextButton.icon(
              onPressed: busy ? null : onCancel,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('İptal'),
            );
            final draft = OutlinedButton.icon(
              onPressed: busy ? null : onDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Taslak kaydet'),
            );
            final save = FilledButton.icon(
              onPressed: busy ? null : onSave,
              icon:
                  busy
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.check, size: 18),
              label: Text(
                busy
                    ? 'Kaydediliyor…'
                    : editing
                    ? 'Değişiklikleri kaydet'
                    : 'Belgeyi kaydet',
              ),
            );
            if (compact) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      cancel,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: draft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(width: double.infinity, child: save),
                ],
              );
            }
            if (largeText) {
              return Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [cancel, draft, save],
              );
            }
            return Row(
              children: [
                cancel,
                const Spacer(),
                draft,
                const SizedBox(width: 12),
                save,
              ],
            );
          },
        ),
      ),
    ),
  );
}
