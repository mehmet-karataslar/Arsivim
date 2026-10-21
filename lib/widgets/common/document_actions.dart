import 'package:flutter/material.dart';
import '../../theme/app_tones.dart';

enum HomeDocumentAction { open, share, edit, delete }

/// Dört işlem aynı satırda, eşit alan ve en az 48 px dokunma yüksekliğiyle.
class DocumentActions extends StatelessWidget {
  const DocumentActions({super.key, required this.onAction});
  final ValueChanged<HomeDocumentAction> onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final iconOnly =
          constraints.maxWidth / 4 < 110 &&
          MediaQuery.textScalerOf(context).scale(12) > 16;
      return Row(
        children: [
          for (final item in const [
            (HomeDocumentAction.open, 'Aç', Icons.open_in_new, AppTone.primary),
            (
              HomeDocumentAction.share,
              'Paylaş',
              Icons.share_outlined,
              AppTone.blue,
            ),
            (
              HomeDocumentAction.edit,
              'Düzenle',
              Icons.edit_outlined,
              AppTone.amber,
            ),
            (
              HomeDocumentAction.delete,
              'Sil',
              Icons.delete_outline,
              AppTone.danger,
            ),
          ]) ...[
            if (item.$1 != HomeDocumentAction.open) const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message: item.$2,
                child: TextButton(
                  key: ValueKey('document-action-${item.$1.name}'),
                  onPressed: () => onAction(item.$1),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    foregroundColor: ToneColors.of(context, item.$4).foreground,
                    backgroundColor: ToneColors.of(context, item.$4).background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Semantics(
                    label: item.$2,
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.$3, size: 19),
                        if (!iconOnly) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
