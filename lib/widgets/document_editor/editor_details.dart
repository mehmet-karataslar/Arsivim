import '../common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../../providers/document_editor_controller.dart';
import '../common/document_tile.dart';
import 'editor_section.dart';
import 'link_selector.dart';

class EditorFileInfo extends StatelessWidget {
  const EditorFileInfo({super.key, required this.controller});
  final DocumentEditorController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return EditorSection(
      number: 2,
      title: 'Dosya bilgileri',
      child: EditorColumns(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sistem tarafından algılanan dosya türü'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FileBadge(extension: c.extension, size: 44),
                  Text(
                    c.extension.isEmpty
                        ? 'Dosya bekleniyor'
                        : c.extension.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (c.extension.isNotEmpty)
                    const Chip(
                      avatar: Icon(Icons.check_circle_outline, size: 16),
                      label: Text('Otomatik algılandı'),
                    ),
                ],
              ),
            ],
          ),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Dosya türü',
              helperText: 'Dosyanın gerçek uzantısı korunur.',
            ),
            child: Text(
              c.files.length > 1
                  ? '${c.files.length} dosya · her dosyanın türü ayrı algılanır'
                  : c.extension.isEmpty
                  ? '—'
                  : c.extension.toUpperCase(),
            ),
          ),
        ],
      ),
    );
  }
}

class EditorDetails extends StatelessWidget {
  const EditorDetails({super.key, required this.controller, this.number = 3});
  final int number;
  final DocumentEditorController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return EditorSection(
      number: number,
      title: 'Belge detayları',
      child: EditorColumns(
        children: [
          Column(
            children: [
              if (WorkspaceLayout.compact(context) && c.files.length > 1)
                const Text(
                  'Her dosya kendi adıyla kaydedilir. Kişi, kategori ve etiket seçimleri tüm dosyalara uygulanır.',
                )
              else
                TextFormField(
                  controller: c.title,
                  decoration: InputDecoration(
                    labelText: 'Belge başlığı *',
                    helperText:
                        c.files.length > 1
                            ? 'Çoklu eklemede her dosyanın adı başlık olarak kullanılır.'
                            : 'Belgeyi kolayca bulabileceğiniz bir başlık girin.',
                  ),
                  maxLength: 240,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Başlık girin'
                              : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: c.description,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  alignLabelWithHint: true,
                  helperText: 'Belge hakkında ek bilgi ekleyebilirsiniz.',
                ),
                minLines: 4,
                maxLines: 7,
                maxLength: 4000,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinkSelector(
                label: 'Kategori bağlantısı',
                options:
                    c.options.categories
                        .map(
                          (k) =>
                              LinkOption(k.id!, k.kategoriAdi, active: k.aktif),
                        )
                        .toList(),
                selected: c.categories,
                onChanged: (ids) => c.setLinks(false, ids),
              ),
              const SizedBox(height: 16),
              LinkSelector(
                label: 'Kişi bağlantısı *',
                icon: Icons.person_outline,
                options:
                    c.options.people
                        .map((p) => LinkOption(p.id!, p.tamAd, active: p.aktif))
                        .toList(),
                selected: c.people,
                onChanged: (ids) => c.setLinks(true, ids),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c.tagInput,
                decoration: InputDecoration(
                  labelText: 'Etiketler',
                  hintText: 'Etiket yazın ve Enter’a basın',
                  suffixIcon: IconButton(
                    tooltip: 'Etiketi ekle',
                    onPressed: c.commitTags,
                    icon: const Icon(Icons.add),
                  ),
                ),
                onSubmitted: (_) => c.commitTags(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in c.tags)
                    InputChip(
                      label: Text(tag, overflow: TextOverflow.ellipsis),
                      onDeleted: () => c.removeTag(tag),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
