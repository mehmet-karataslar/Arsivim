import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../models/belge_modeli.dart';
import '../../theme/app_tones.dart';
import 'app_card.dart';
import 'tone_widgets.dart';

enum HomeDocumentAction { open, share, edit, delete }

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
    final categoryTone = ToneColors.of(context, AppTone.primary);
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FileBadge(extension: file.dosyaTipi),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: title,
                child: InkWell(
                  onTap: () => onAction(file, HomeDocumentAction.open),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
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
              ),
              const SizedBox(height: 5),
              Text(
                '${file.dosyaTipi.toUpperCase()}  ·  ${file.formatliDosyaBoyutu}  ·  ${file.formatliGuncellemeTarihi}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (document.kisi?.isNotEmpty == true)
                    Text(
                      '♙ ${document.kisi}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  if (document.kategori?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryTone.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        document.kategori!,
                        style: TextStyle(
                          fontSize: 12,
                          color: categoryTone.foreground,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (final item in [
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
        ])
          ToneButton(
            label: item.$2,
            icon: item.$3,
            tone: item.$4,
            onPressed: () => onAction(file, item.$1),
          ),
      ],
    );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >= 760 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showRelativeTime) ...[
                Text(
                  file.zamanFarki,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              actions,
            ],
          );
          return inline
              ? Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  controls,
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 14), controls],
              );
        },
      ),
    );
  }
}
