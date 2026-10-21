import 'package:flutter/material.dart';
import '../../providers/document_editor_controller.dart';
import '../../utils/yardimci_fonksiyonlar.dart';
import '../common/document_tile.dart';
import 'editor_section.dart';

class EditorSummary extends StatelessWidget {
  const EditorSummary({
    super.key,
    required this.controller,
    required this.onPreview,
  });
  final DocumentEditorController controller;
  final ValueChanged<String> onPreview;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = Theme.of(context).colorScheme;
    Widget line(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: Text(value)),
        ],
      ),
    );
    final path = c.files.firstOrNull?.path ?? c.original?.dosyaYolu;
    Widget chips(String title, List<String> labels) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${labels.length})',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                labels
                    .map(
                      (s) =>
                          Chip(label: Text(s, overflow: TextOverflow.ellipsis)),
                    )
                    .toList(),
          ),
        ],
      ),
    );
    return EditorSection(
      title: 'Belge Önizleme ve Özet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FileBadge(extension: c.extension, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.filename,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(YardimciFonksiyonlar.dosyaBoyutuFormatla(c.bytes)),
                    if (c.files.length > 1)
                      Text('${c.files.length} dosya seçildi'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: path == null ? null : () => onPreview(path),
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('Önizlemeyi Aç'),
          ),
          const Divider(height: 30),
          const Text(
            'Temel Bilgiler',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          line('Dosya adı', c.filename),
          line('Dosya türü', c.extension.toUpperCase()),
          line(
            'Toplam boyut',
            YardimciFonksiyonlar.dosyaBoyutuFormatla(c.bytes),
          ),
          line(
            c.original == null ? 'Kayıt durumu' : 'Eklenme tarihi',
            c.original == null
                ? 'Henüz kaydedilmedi'
                : c.original!.formatliOlusturmaTarihi,
          ),
          const Divider(height: 28),
          const Text(
            'Bağlantılar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          chips('Kategoriler', [
            for (final id in c.categories)
              c.options.categories
                      .where((k) => k.id == id)
                      .firstOrNull
                      ?.kategoriAdi ??
                  'Kayıt #$id',
          ]),
          chips('Kişiler', [
            for (final id in c.people)
              c.options.people.where((p) => p.id == id).firstOrNull?.tamAd ??
                  'Kayıt #$id',
          ]),
          chips('Etiketler', c.tags),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  c.ready ? Icons.check_circle_outline : Icons.info_outline,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.ready
                        ? 'Hazır\nBelge kaydedilmeye hazır.'
                        : 'Dosya, başlık ve kişi seçimini tamamlayın.',
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
