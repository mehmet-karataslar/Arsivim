import '../../theme/app_tones.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as paths;
import '../../providers/document_editor_controller.dart';
import '../../utils/yardimci_fonksiyonlar.dart';
import '../common/app_card.dart';
import '../common/document_tile.dart';
import 'editor_section.dart';
import '../common/workspace_layout.dart';

class EditorSource extends StatelessWidget {
  const EditorSource({
    super.key,
    required this.controller,
    required this.onFiles,
    required this.onScan,
    required this.onPreview,
    required this.onEditScan,
    required this.onDrop,
  });
  final DocumentEditorController controller;
  final VoidCallback onFiles;
  final VoidCallback? onScan;
  final ValueChanged<String> onPreview, onEditScan;
  final ValueChanged<List<PlatformFile>> onDrop;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = Theme.of(context).colorScheme;
    Widget source(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback? tap,
      Color color,
      bool compact,
    ) => AppCard(
      onTap: tap,
      padding: const EdgeInsets.all(14),
      color: Color.lerp(color, colors.surface, .94),
      borderColor: color.withValues(alpha: .25),
      child:
          compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const Spacer(),
                      Icon(Icons.add_circle_outline, size: 18, color: color),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )
              : Row(
                children: [
                  Icon(icon, color: color, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline, size: 20),
                ],
              ),
    );
    final existing = c.original;
    return EditorSection(
      number: 1,
      title: existing == null ? 'Belge kaynağını seçin' : 'Belge dosyası',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing == null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 650 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: source(
                          'Dosya Seç',
                          'Bir veya birden fazla dosya ekleyin',
                          Icons.insert_drive_file_outlined,
                          onFiles,
                          colors.primary,
                          compact,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: source(
                          'Fotoğraf Çek',
                          onScan == null
                              ? 'Telefonunuzdan çok sayfalı PDF tarayın'
                              : 'Sayfaları çekin, tek PDF oluşturun',
                          Icons.document_scanner_outlined,
                          onScan,
                          onScan == null
                              ? colors.onSurfaceVariant
                              : ToneColors.of(
                                context,
                                AppTone.purple,
                              ).foreground,
                          compact,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (WorkspaceLayout.compact(context))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  onScan == null
                      ? 'Fotoğraf çekerek tarama telefonda kullanılabilir.'
                      : 'Birden fazla sayfa çekip düzenleyin; tüm sayfalar tek PDF olarak eklenir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!WorkspaceLayout.compact(context)) ...[
              const SizedBox(height: 12),
              DropTarget(
                enable: !c.busy,
                onDragDone: (details) async {
                  try {
                    final files = <PlatformFile>[];
                    for (final file in details.files) {
                      if (await File(file.path).exists()) {
                        files.add(
                          PlatformFile(
                            name: paths.basename(file.path),
                            path: file.path,
                            size: await File(file.path).length(),
                          ),
                        );
                      }
                    }
                    onDrop(files);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Dosya okunamadı. Dosya Seç düğmesini kullanın.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 38,
                        color: colors.onSurfaceVariant,
                      ),
                      TextButton(
                        onPressed: onFiles,
                        child: Text(
                          Platform.isWindows ||
                                  Platform.isMacOS ||
                                  Platform.isLinux
                              ? 'Dosyayı buraya sürükleyin veya seçin'
                              : 'Dosya seçmek için dokunun',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        'PDF, DOCX, XLSX, PNG, JPG ve diğer dosyalar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (existing != null)
            _file(
              context,
              existing.orijinalDosyaAdi,
              existing.dosyaBoyutu,
              existing.dosyaYolu,
              null,
            ),
          for (final file in c.files)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _file(
                context,
                file.name,
                file.size,
                file.path!,
                () => c.removeFile(file),
              ),
            ),
        ],
      ),
    );
  }

  Widget _file(
    BuildContext context,
    String name,
    int size,
    String path,
    VoidCallback? remove,
  ) => Row(
    children: [
      FileBadge(extension: paths.extension(name), size: 42),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              [
                if (WorkspaceLayout.compact(context) &&
                    paths.extension(name).isNotEmpty)
                  paths.extension(name).substring(1).toUpperCase(),
                if (controller.scanPages[path]?.isNotEmpty ?? false)
                  '${controller.scanPages[path]!.length} sayfa',
                YardimciFonksiyonlar.dosyaBoyutuFormatla(size),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Önizlemeyi aç',
        onPressed: () => onPreview(path),
        icon: const Icon(Icons.open_in_new, size: 20),
      ),
      if (controller.scanPages[path]?.isNotEmpty ?? false)
        IconButton(
          tooltip: 'Sayfaları düzenle',
          onPressed: () => onEditScan(path),
          icon: const Icon(Icons.edit_note, size: 20),
        ),
      if (remove != null)
        IconButton(
          tooltip: 'Dosyayı seçimden kaldır',
          onPressed: remove,
          icon: const Icon(Icons.close, size: 20),
        ),
    ],
  );
}
