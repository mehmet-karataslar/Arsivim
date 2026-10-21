import 'package:flutter/material.dart';
import '../../models/category_overview.dart';
import '../../models/kategori_modeli.dart';
import '../simge_secici_widget.dart';
import 'category_badge.dart';

class CategoryEditor extends StatefulWidget {
  const CategoryEditor({super.key, this.entry, required this.onSave});
  final CategoryEntry? entry;
  final Future<void> Function(KategoriModeli, CategoryGroup) onSave;
  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.entry?.category.kategoriAdi,
  );
  late final _description = TextEditingController(
    text: widget.entry?.category.aciklama,
  );
  late String _color = widget.entry?.category.renkKodu ?? '#008557';
  late String _icon = widget.entry?.category.simgeKodu ?? 'folder';
  late CategoryGroup _group = widget.entry?.group ?? CategoryGroup.general;
  late int? _id = widget.entry?.category.id;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final model = KategoriModeli(
      id: _id,
      kategoriAdi: _name.text.trim(),
      aciklama: _description.text.trim(),
      renkKodu: _color,
      simgeKodu: _icon,
      olusturmaTarihi: widget.entry?.category.olusturmaTarihi ?? DateTime.now(),
    );
    try {
      await widget.onSave(model, _group);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _id = model.id;
          _saving = false;
          _error =
              error.toString().contains('UNIQUE')
                  ? 'Bu isimde bir kategori zaten var.'
                  : 'Kategori kaydedilemedi. Bilgilerinizi kontrol edip tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final icons = {
      for (final item in SimgeSeciciWidget.simgeler)
        item['kod'] as String: item['ad'] as String,
      'local_hospital': 'Hastane',
      'account_balance': 'Mali',
      'gavel': 'Hukuki',
      'business': 'Resmi',
      'security': 'Güvenlik',
      'person': 'Kişi',
      'flight': 'Uçuş',
      'sports_esports': 'Hobi',
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.entry == null ? 'Kategori ekle' : 'Kategori düzenle',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Kategori adı',
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().length < 2
                                ? 'En az iki karakter girin.'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    enabled: !_saving,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CategoryGroup>(
                    initialValue: _group,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori grubu',
                    ),
                    items: [
                      for (final group in CategoryGroup.values)
                        DropdownMenuItem(
                          value: group,
                          child: Text(group.label),
                        ),
                    ],
                    onChanged:
                        _saving ? null : (v) => setState(() => _group = v!),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Renk',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in {
                        '#008557',
                        '#2588F5',
                        '#E05585',
                        '#DC584D',
                        '#E88535',
                        '#7852BE',
                        '#9360AA',
                        '#6F9D48',
                        _color,
                      })
                        Semantics(
                          selected: _color == color,
                          child: Tooltip(
                            message: 'Renk $color',
                            child: InkWell(
                              onTap:
                                  _saving
                                      ? null
                                      : () => setState(() => _color = color),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: categoryColor(context, color),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    _color == color
                                        ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Simge',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final item in icons.entries)
                        IconButton.filledTonal(
                          tooltip: item.value,
                          isSelected: _icon == item.key,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                _icon == item.key
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                    : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                          ),
                          onPressed:
                              _saving
                                  ? null
                                  : () => setState(() => _icon = item.key),
                          icon: Icon(categoryIcon(item.key), size: 22),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}
