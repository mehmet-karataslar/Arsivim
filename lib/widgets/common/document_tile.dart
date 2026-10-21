import 'workspace_layout.dart';
import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/belge_modeli.dart';
import '../../theme/app_tones.dart';
import 'app_card.dart';
import 'document_actions.dart';
export 'document_actions.dart' show HomeDocumentAction;

class FileBadge extends StatelessWidget {
  const FileBadge({super.key, required this.extension, this.size = 62});
  final String extension;
  final double size;
  @override
  Widget build(BuildContext context) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final image = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'].contains(ext);
    final pdf = ext == 'pdf';
    final excel = ['xls', 'xlsx', 'csv'].contains(ext);
    final tone =
        pdf
            ? AppTone.danger
            : image || excel
            ? AppTone.primary
            : AppTone.blue;
    final colors = ToneColors.of(context, tone);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .18),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.foreground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child:
              image || pdf
                  ? Icon(
                    image ? Icons.image_rounded : Icons.picture_as_pdf_outlined,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: size * .4,
                  )
                  : Text(
                    excel
                        ? 'X'
                        : ['doc', 'docx'].contains(ext)
                        ? 'W'
                        : ext == 'pptx'
                        ? 'P'
                        : ext.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: ext.length > 4 ? size * .16 : size * .32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onAction,
    this.showRelativeTime = false,
  });
  final SonBelgeOzeti document;
  final void Function(BelgeModeli, HomeDocumentAction) onAction;
  final bool showRelativeTime;

  @override
  Widget build(BuildContext context) {
    final file = document.belge;
    final colors = Theme.of(context).colorScheme;
    final title =
        file.baslik?.trim().isNotEmpty == true
            ? file.baslik!
            : file.orijinalDosyaAdi;
    final mobile = WorkspaceLayout.compact(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FileBadge(extension: file.dosyaTipi, size: mobile ? 44 : 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: title,
                    child: InkWell(
                      onTap: () => onAction(file, HomeDocumentAction.open),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${file.dosyaTipi.toUpperCase()} · ${file.formatliDosyaBoyutu}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DocumentDetail(
          icon: Icons.person_outline,
          label: 'Kişi',
          value:
              document.kisi?.trim().isNotEmpty == true
                  ? document.kisi!
                  : 'Atanmamış',
        ),
        _DocumentDetail(
          icon: Icons.folder_outlined,
          label: 'Kategori',
          value:
              document.kategori?.trim().isNotEmpty == true
                  ? document.kategori!
                  : 'Kategorisiz',
        ),
        _DocumentDetail(
          icon: Icons.schedule,
          label: 'Güncelleme',
          value: file.formatliGuncellemeTarihi,
        ),
      ],
    );
    final actions = DocumentActions(
      onAction: (action) => onAction(file, action),
    );
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >= 760 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          return inline
              ? Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 20),
                  SizedBox(width: 348, child: actions),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 12), actions],
              );
        },
      ),
    );
  }
}

class _DocumentDetail extends StatelessWidget {
  const _DocumentDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Tooltip(
      message: '$label: $value',
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
