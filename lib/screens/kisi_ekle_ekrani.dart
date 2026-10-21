import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/kisi_modeli.dart';
import '../providers/person_editor_controller.dart';
import '../services/person_editor_repository.dart';
import '../widgets/common/form_page_shell.dart';
import '../widgets/common/workspace_layout.dart';
import '../widgets/document_editor/editor_navigation.dart';
import '../widgets/person_editor/person_form.dart';

class KisiEkleEkrani extends StatefulWidget {
  const KisiEkleEkrani({
    super.key,
    this.kisi,
    this.navigation,
    this.repository,
  });
  final KisiModeli? kisi;
  final EditorNavigation? navigation;
  final PersonEditorRepository? repository;
  @override
  State<KisiEkleEkrani> createState() => _KisiEkleEkraniState();
}

class _KisiEkleEkraniState extends State<KisiEkleEkrani> {
  late final c = PersonEditorController(
    original: widget.kisi,
    repository: widget.repository,
  );
  final form = GlobalKey<FormState>();
  bool leaving = false, confirming = false, picking = false;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _pop([bool? result, VoidCallback? action]) {
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(result);
      action?.call();
    });
  }

  Future<void> _leave([VoidCallback? action]) async {
    if (c.busy || picking || confirming || leaving) return;
    confirming = true;
    final discard =
        !c.dirty ||
        await showDialog<bool>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text('Değişiklikler kaydedilmedi'),
                    content: const Text('Kaydetmeden çıkmak istiyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Düzenlemeye devam et'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Kaydetmeden çık'),
                      ),
                    ],
                  ),
            ) ==
            true;
    confirming = false;
    if (mounted && discard) _pop(null, action);
  }

  Future<void> _save() async {
    if (c.busy || picking || leaving || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (await c.save() && mounted) _pop(true);
  }

  Future<void> _photo() async {
    if (c.busy || picking) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Fotoğraf seç'),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                if (Platform.isAndroid || Platform.isIOS)
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Fotoğraf çek'),
                    onTap: () => Navigator.pop(ctx, 'camera'),
                  ),
                if (c.photo != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Fotoğrafı kaldır'),
                    onTap: () => Navigator.pop(ctx, 'remove'),
                  ),
              ],
            ),
          ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      c.setPhoto(null);
      return;
    }
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (mounted && file != null) c.setPhoto(file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğraf alınamadı. Yeniden deneyebilirsiniz.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final compact = WorkspaceLayout.compact(context);
      final desktop =
          MediaQuery.sizeOf(context).width >= 1100 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      final title = widget.kisi == null ? 'Kişi Ekle' : 'Kişiyi Düzenle';
      return PopScope(
        canPop: leaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: FormPageShell(
          title: title,
          selectedIndex: 3,
          navigation: widget.navigation,
          onLeave: _leave,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 12 : 28),
                  child: AutofillGroup(
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (desktop) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.home_outlined,
                                  size: 19,
                                  color: colors.onSurfaceVariant,
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                                TextButton(
                                  onPressed: () => _leave(),
                                  child: const Text('Kişiler'),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                                const Text('Kişi Ekle / Düzenle'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 42,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 26),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Kişi Ekle / Düzenle',
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Kişi bilgilerini girin veya mevcut kişiyi düzenleyin.',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (c.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                c.error!,
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          AbsorbPointer(
                            absorbing: c.busy || picking,
                            child: PersonForm(controller: c, onPhoto: _photo),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (c.busy || picking) const LinearProgressIndicator(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 28,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      fit: compact ? FlexFit.tight : FlexFit.loose,
                      child: OutlinedButton.icon(
                        onPressed: c.busy || picking ? null : () => _leave(),
                        icon: const Icon(Icons.close),
                        label: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      fit: compact ? FlexFit.tight : FlexFit.loose,
                      child: FilledButton.icon(
                        key: const ValueKey('person-save'),
                        onPressed: c.busy || picking ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(c.busy ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
