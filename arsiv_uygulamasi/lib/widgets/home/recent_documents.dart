import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/belge_modeli.dart';
import '../common/app_card.dart';
import '../common/adaptive_card_layout.dart';
import '../common/document_tile.dart';
import '../common/tone_widgets.dart';
import '../common/view_mode_switch.dart';
export '../common/document_tile.dart' show HomeDocumentAction;

class RecentDocuments extends StatefulWidget {
  const RecentDocuments({
    super.key,
    required this.documents,
    required this.onAll,
    required this.onAdd,
    required this.onAction,
    this.filtered = false,
  });
  final List<SonBelgeOzeti> documents;
  final VoidCallback onAll, onAdd;
  final void Function(BelgeModeli, HomeDocumentAction) onAction;
  final bool filtered;
  @override
  State<RecentDocuments> createState() => _RecentDocumentsState();
}

class _RecentDocumentsState extends State<RecentDocuments> {
  bool _grid = false;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Row(
              children: [
                const ToneBadge(icon: Icons.description_rounded, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Son eklenen belgeler',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Son güncellenen belgeleriniz. Hızlı işlemlerle hemen erişin.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final controls = Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: widget.onAll,
                  label: const Text('Tümünü gör'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  iconAlignment: IconAlignment.end,
                ),
                ViewModeSwitch(
                  grid: _grid,
                  onChanged: (value) => setState(() => _grid = value),
                ),
              ],
            );
            return constraints.maxWidth > 700
                ? Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    controls,
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), controls],
                );
          },
        ),
        const SizedBox(height: 20),
        if (widget.documents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.filtered
                      ? 'Bu filtreye uygun belge yok.'
                      : 'Henüz belge eklenmemiş',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Belge ekle'),
                ),
              ],
            ),
          )
        else if (_grid)
          AdaptiveCardLayout(
            minCardWidth: 340,
            maxColumns: 2,
            spacing: 10,
            children: [
              for (final doc in widget.documents)
                DocumentTile(document: doc, onAction: widget.onAction),
            ],
          )
        else
          Column(
            children: [
              for (final doc in widget.documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DocumentTile(document: doc, onAction: widget.onAction),
                ),
            ],
          ),
      ],
    ),
  );
}
