import 'package:flutter/material.dart';
import '../../models/people_overview.dart';
import '../../models/belge_modeli.dart';
import '../common/document_tile.dart';
import '../common/section_surface.dart';
import 'person_avatar.dart';
import 'person_card.dart';

class PersonDetailPanel extends StatefulWidget {
  const PersonDetailPanel({
    super.key,
    required this.person,
    required this.details,
    required this.loading,
    required this.error,
    required this.onClose,
    required this.onEdit,
    required this.onAllDocuments,
    required this.onRetry,
    required this.onDocumentAction,
  });
  final PersonSummary person;
  final PersonDetails? details;
  final bool loading;
  final String? error;
  final VoidCallback onClose, onEdit, onAllDocuments, onRetry;
  final void Function(BelgeModeli, HomeDocumentAction) onDocumentAction;
  @override
  State<PersonDetailPanel> createState() => _PersonDetailPanelState();
}

class _PersonDetailPanelState extends State<PersonDetailPanel> {
  int _tab = 0;
  String date(DateTime value) =>
      '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: SectionSurface(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PersonAvatar(person: person.person, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.person.tamAd,
                          key: const ValueKey('person-detail-name'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${person.documentCount} belge',
                          style: TextStyle(color: colors.primary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kişi panelini kapat',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Düzenle'),
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item
                        in [
                          'Bilgiler',
                          'Belgeler',
                          'Klasörler',
                          'Notlar',
                        ].asMap().entries)
                      Semantics(
                        selected: _tab == item.key,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color:
                                    _tab == item.key
                                        ? colors.primary
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () => setState(() => _tab = item.key),
                            child: Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _tab == item.key
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_tab == 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _information('Ad Soyad', Text(person.person.tamAd)),
                      for (final item in [
                        ('E-posta', person.person.eposta),
                        ('Telefon', person.person.telefon),
                        ('Adres', person.person.adres),
                      ])
                        if (item.$2?.isNotEmpty == true)
                          _information(item.$1, SelectableText(item.$2!)),
                      if (person.person.kullaniciAdi?.isNotEmpty == true)
                        _information(
                          'Kullanıcı adı',
                          Text(person.person.kullaniciAdi!),
                        ),
                      _information(
                        'Kategoriler',
                        PersonCategories(categories: person.categories),
                      ),
                      _information(
                        'Oluşturulma',
                        Text(date(person.person.olusturmaTarihi)),
                      ),
                      _information(
                        'Son güncelleme',
                        Text(date(person.updated)),
                      ),
                      _information(
                        'Toplam belge',
                        Text('${person.documentCount} belge'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Son belgeler',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onAllDocuments,
                      child: const Text('Tümünü gör'),
                    ),
                  ],
                ),
              ],
              if (widget.loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Kişi ayrıntıları yükleniyor',
                ),
              if (widget.error != null) ...[
                Text(widget.error!),
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('Tekrar dene'),
                ),
              ],
              if (!widget.loading &&
                  widget.error == null &&
                  widget.details != null) ...[
                if (_tab == 0 || _tab == 1) ...[
                  if (_tab == 1)
                    TextButton(
                      onPressed: widget.onAllDocuments,
                      child: Text('Tüm belgeleri aç (${person.documentCount})'),
                    ),
                  if (widget.details!.documents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Bu kişiye ait belge yok.'),
                    ),
                  for (final file in widget.details!.documents.take(
                    _tab == 0 ? 3 : 10,
                  ))
                    _document(file),
                  if (_tab == 1 && person.documentCount > 10)
                    const Text(
                      'Son 10 belge gösteriliyor. Tümünü açarak arayabilir ve filtreleyebilirsiniz.',
                    ),
                ],
                if (_tab == 2) ...[
                  const Text(
                    'Belgelerin bu cihazdaki kayıtlı konumları.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (widget.details!.folders.isEmpty)
                    const Text('Henüz kayıtlı dosya konumu yok.'),
                  for (final folder in widget.details!.folders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(
                        folder.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Tooltip(
                        message: folder.path,
                        child: Text(
                          folder.path,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Text('${folder.count}'),
                    ),
                ],
                if (_tab == 3) ...[
                  const Text(
                    'Açıklaması olan son 20 belge.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (widget.details!.notes.isEmpty)
                    const Text('Bu kişinin belgelerinde kayıtlı açıklama yok.'),
                  for (final file in widget.details!.notes)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        file.baslik ?? file.orijinalDosyaAdi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SelectableText(file.aciklama ?? ''),
                        ),
                      ],
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _information(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
        return MediaQuery.textScalerOf(context).scale(14) > 18 ||
                constraints.maxWidth < 250
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 4), value],
            )
            : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 112, child: heading),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 12),
                    child: value,
                  ),
                ),
              ],
            );
      },
    ),
  );

  Widget _document(BelgeModeli file) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: FileBadge(extension: file.dosyaTipi, size: 38),
      title: Text(
        file.baslik?.isNotEmpty == true ? file.baslik! : file.orijinalDosyaAdi,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${file.dosyaTipi.toUpperCase()} · ${file.formatliDosyaBoyutu}',
        style: const TextStyle(fontSize: 11),
      ),
      onTap: () => widget.onDocumentAction(file, HomeDocumentAction.open),
      trailing: PopupMenuButton<HomeDocumentAction>(
        tooltip: 'Belge işlemleri',
        onSelected: (action) => widget.onDocumentAction(file, action),
        itemBuilder:
            (_) => const [
              PopupMenuItem(value: HomeDocumentAction.open, child: Text('Aç')),
              PopupMenuItem(
                value: HomeDocumentAction.share,
                child: Text('Paylaş'),
              ),
              PopupMenuItem(
                value: HomeDocumentAction.edit,
                child: Text('Düzenle'),
              ),
              PopupMenuItem(
                value: HomeDocumentAction.delete,
                child: Text('Sil'),
              ),
            ],
      ),
    ),
  );
}
