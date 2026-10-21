import '../widgets/common/workspace_layout.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/document_editor_controller.dart';
import '../services/document_scan_service.dart';
import '../models/scan_page.dart';
import 'scan_review_screen.dart';
import 'scan_preview_screen.dart';
import 'package:path/path.dart' as paths;
import '../widgets/common/app_sidebar.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/document_editor/editor_navigation.dart';
import '../widgets/document_editor/editor_source.dart';
import '../widgets/document_editor/editor_details.dart';
import '../widgets/document_editor/editor_summary.dart';
import '../widgets/document_editor/editor_footer.dart';

class DocumentEditorScreen extends StatefulWidget {
  const DocumentEditorScreen({
    super.key,
    required this.controller,
    this.navigation,
    this.scanner,
  });
  final DocumentEditorController controller;
  final EditorNavigation? navigation;
  final DocumentScanService? scanner;
  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  late final c = widget.controller;
  late final scanner = widget.scanner ?? DocumentScanService();
  bool _leaving = false, _picking = false, _reviewOpen = false;
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    scroll.dispose();
    c.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _pick() async {
    if (c.busy || _picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (mounted && result != null) c.addFiles(result.files);
    } catch (e) {
      _error('Dosya seçilemedi: $e');
    } finally {
      if (mounted)
        setState(() {
          _picking = false;
          _reviewOpen = false;
        });
    }
  }

  Future<void> _scan() async {
    if (c.busy || _picking) return;
    setState(() => _picking = true);
    try {
      final pictures = await scanner.capturePages();
      if (!mounted || pictures == null || pictures.isEmpty) return;
      setState(() => _reviewOpen = true);
      final result = await Navigator.of(context).push<ScannedPdf>(
        MaterialPageRoute(
          builder:
              (_) => ScanReviewScreen(
                pages: pictures.map(ScanPage.new).toList(),
                scanner: scanner,
              ),
        ),
      );
      if (mounted && result != null) {
        c.addScan(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.pageCount} sayfa tek PDF olarak hazırlandı. Belge bilgilerini tamamlayıp kaydedebilirsiniz.',
            ),
          ),
        );
      }
    } catch (e) {
      _error('Tarama tamamlanamadı: $e');
    } finally {
      if (mounted)
        setState(() {
          _picking = false;
          _reviewOpen = false;
        });
    }
  }

  Future<void> _editScan(String path) async {
    final pages = c.scanPages[path];
    if (pages == null || pages.isEmpty || c.busy || _picking) return;
    setState(() => _picking = true);
    try {
      final file = c.files.firstWhere((f) => f.path == path);
      setState(() => _reviewOpen = true);
      final result = await Navigator.of(context).push<ScannedPdf>(
        MaterialPageRoute(
          builder:
              (_) => ScanReviewScreen(
                pages: pages,
                scanner: scanner,
                name: paths.basenameWithoutExtension(file.name),
              ),
        ),
      );
      if (mounted && result != null) c.addScan(result, replacing: path);
    } finally {
      if (mounted)
        setState(() {
          _picking = false;
          _reviewOpen = false;
        });
    }
  }

  Future<void> _preview(String path) async {
    final pages = c.scanPages[path];
    if (pages != null && pages.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => ScanPreviewScreen(
                pages: pages,
                name: c.files.firstWhere((f) => f.path == path).name,
              ),
        ),
      );
      return;
    }
    try {
      if (!await File(path).exists()) throw StateError('Dosya bulunamadı.');
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        _error('Önizleme açılamadı: ${result.message}');
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _leave([VoidCallback? after]) async {
    if (c.busy || _picking) return;
    if (c.dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Kaydedilmemiş değişiklikler'),
              content: const Text(
                'Çıkarsanız bu ekrandaki kaydedilmemiş değişiklikler silinir. Devam edilsin mi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Düzenlemeye dön'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kaydetmeden çık'),
                ),
              ],
            ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(c.anySaved);
      after?.call();
    });
  }

  Future<void> _save() async {
    c.commitTags();
    if (form.currentState?.validate() != true) {
      if (scroll.hasClients) scroll.jumpTo(0);
      return;
    }
    if (await c.save() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.message ?? 'Belge başarıyla kaydedildi.')),
      );
      await _leave();
    } else if (mounted && scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final width = MediaQuery.sizeOf(context).width;
      final desktop =
          width >= 1100 && MediaQuery.textScalerOf(context).scale(14) <= 20;
      final nav = widget.navigation;
      final title = c.original == null ? 'Yeni Belge Ekle' : 'Belgeyi Düzenle';
      final disabled = c.busy || _picking;
      final content = Column(
        children: [
          Expanded(
            child:
                c.loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      controller: scroll,
                      padding: EdgeInsets.all(width < 600 ? 8 : 20),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  children: [
                                    Icon(
                                      c.original == null
                                          ? Icons.note_add_outlined
                                          : Icons.edit_document,
                                      color: colors.primary,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              color: colors.primary,
                                            ),
                                          ),
                                          Text(
                                            'Belgelerinizi sisteme ekleyin ve detaylarını düzenleyin.',
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (c.savedDraft != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Kaydedilmiş bir taslağınız var.',
                                    ),
                                    TextButton(
                                      onPressed:
                                          disabled ? null : c.restoreDraft,
                                      child: const Text('Taslağı aç'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          disabled ? null : c.discardDraft,
                                      child: const Text('Taslağı sil'),
                                    ),
                                  ],
                                ),
                              ),
                            if (c.error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                color: colors.errorContainer,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.error!,
                                      style: TextStyle(
                                        color: colors.onErrorContainer,
                                      ),
                                    ),
                                    if (c.options.people.isEmpty)
                                      TextButton(
                                        onPressed: disabled ? null : c.load,
                                        child: const Text('Yeniden dene'),
                                      ),
                                  ],
                                ),
                              ),
                            if (c.message != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  c.message!,
                                  style: TextStyle(color: colors.primary),
                                ),
                              ),
                            if (_picking && !_reviewOpen)
                              const LinearProgressIndicator(),
                            AbsorbPointer(
                              absorbing: disabled,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final sections = Column(
                                    children: [
                                      EditorSource(
                                        controller: c,
                                        onFiles: () => _pick(),
                                        onScan:
                                            scanner.isSupported ? _scan : null,
                                        onPreview: _preview,
                                        onEditScan: _editScan,
                                        onDrop: (files) {
                                          if (mounted && !disabled) {
                                            c.addFiles(files);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      if (!WorkspaceLayout.compact(
                                        context,
                                      )) ...[
                                        EditorFileInfo(controller: c),
                                        const SizedBox(height: 16),
                                      ],
                                      EditorDetails(
                                        controller: c,
                                        number:
                                            WorkspaceLayout.compact(context)
                                                ? 2
                                                : 3,
                                      ),
                                    ],
                                  );
                                  final summary = EditorSummary(
                                    controller: c,
                                    onPreview: _preview,
                                  );
                                  if (constraints.maxWidth >= 1000 &&
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) <=
                                          20) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections),
                                        const SizedBox(width: 16),
                                        SizedBox(width: 350, child: summary),
                                      ],
                                    );
                                  }
                                  if (WorkspaceLayout.compact(context)) {
                                    return sections;
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      sections,
                                      const SizedBox(height: 16),
                                      ExpansionTile(
                                        title: const Text(
                                          'Belge Önizleme ve Özet',
                                        ),
                                        tilePadding: EdgeInsets.zero,
                                        children: [summary],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
          if (c.busy)
            LinearProgressIndicator(semanticsLabel: 'Belge kaydediliyor'),
          EditorFooter(
            busy: disabled || c.loading,
            editing: c.original != null,
            onCancel: () => _leave(),
            onDraft: () {
              c.commitTags();
              c.saveDraft();
            },
            onSave: _save,
          ),
        ],
      );
      return PopScope(
        canPop: _leaving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar:
              desktop
                  ? null
                  : AppBar(
                    centerTitle: true,
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    leading: BackButton(onPressed: () => _leave()),
                  ),
          bottomNavigationBar:
              !desktop &&
                      nav != null &&
                      MediaQuery.viewInsetsOf(context).bottom == 0
                  ? AppNavigationBar(
                    selectedIndex: 1,
                    onSelected: (index) => _leave(() => nav.onSelected(index)),
                  )
                  : null,
          body: SafeArea(
            child: Row(
              children: [
                if (desktop && nav != null)
                  AppSidebar(
                    selectedIndex: 1,
                    summary: nav.summary,
                    onSelected: (index) => _leave(() => nav.onSelected(index)),
                    onStorage: nav.onStorage,
                    onLogout: () => _leave(nav.onLogout),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (desktop)
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border(
                              bottom: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Geri dön',
                                onPressed: () => _leave(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Text(
                                'Arşivim',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed:
                                    () => _leave(
                                      nav == null
                                          ? null
                                          : () => nav.onSelected(1),
                                    ),
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('Belgelerde ara'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
