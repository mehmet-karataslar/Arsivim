import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as paths;
import '../models/belge_modeli.dart';
import '../models/scan_page.dart';
import '../services/document_scan_service.dart';
import '../services/document_editor_repository.dart';

class DocumentEditorController extends ChangeNotifier {
  DocumentEditorController({
    this.original,
    DocumentEditorRepository? repository,
  }) : repository = repository ?? DocumentEditorRepository() {
    title.text = original?.baslik ?? (original?.orijinalDosyaAdi ?? '');
    description.text = original?.aciklama ?? '';
    categories.addAll(original?.tumKategoriIds ?? []);
    people.addAll(original?.tumKisiIds ?? []);
    tags.addAll(original?.etiketler ?? []);
    title.addListener(changed);
    description.addListener(changed);
    tagInput.addListener(changed);
  }
  final BelgeModeli? original;
  final DocumentEditorRepository repository;
  final title = TextEditingController(),
      description = TextEditingController(),
      tagInput = TextEditingController();
  final List<PlatformFile> files = [];
  final Map<String, List<ScanPage>> scanPages = {};
  final Set<int> categories = {}, people = {};
  final List<String> tags = [];
  EditorOptions options = const EditorOptions([], []);
  Map<String, dynamic>? savedDraft;
  bool loading = true, busy = false, dirty = false, _disposed = false;
  bool anySaved = false;
  String? error, message;
  int processed = 0;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void changed() {
    dirty = true;
    message = null;
    _emit();
  }

  bool get ready =>
      (original != null || files.isNotEmpty) &&
      (files.length > 1 || title.text.trim().isNotEmpty) &&
      people.isNotEmpty;
  String get filename =>
      files.firstOrNull?.name ??
      original?.orijinalDosyaAdi ??
      'Henüz dosya seçilmedi';
  int get bytes =>
      original?.dosyaBoyutu ?? files.fold(0, (sum, f) => sum + f.size);
  String get extension =>
      original?.dosyaTipi ??
      paths
          .extension(files.firstOrNull?.name ?? '')
          .replaceFirst('.', '')
          .toLowerCase();

  Future<void> load() async {
    loading = true;
    error = null;
    _emit();
    try {
      options = await repository.options();
      savedDraft = await repository.draft(original?.id);
    } catch (_) {
      error = 'Form bilgileri yüklenemedi. Yeniden deneyin.';
    } finally {
      loading = false;
      _emit();
    }
  }

  void addFiles(List<PlatformFile> selected) {
    for (final file in selected) {
      if (file.path != null && !files.any((f) => f.path == file.path)) {
        files.add(file);
      }
    }
    if (title.text.trim().isEmpty && files.isNotEmpty) {
      title.text = paths.basenameWithoutExtension(files.first.name);
    }
    changed();
  }

  void addScan(ScannedPdf scan, {String? replacing}) {
    final index =
        replacing == null ? -1 : files.indexWhere((f) => f.path == replacing);
    if (index < 0) {
      addFiles([scan.file]);
    } else {
      files[index] = scan.file;
      scanPages.remove(replacing);
    }
    scanPages[scan.file.path!] = List.of(scan.pages);
    changed();
  }

  void removeFile(PlatformFile file) {
    files.remove(file);
    scanPages.remove(file.path);
    changed();
  }

  void setLinks(bool person, Set<int> ids) {
    final selection = person ? people : categories;
    selection
      ..clear()
      ..addAll(ids);
    changed();
  }

  void addTags(String value) {
    for (final tag in value
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)) {
      if (!tags.contains(tag)) tags.add(tag);
    }
    changed();
  }

  void commitTags() {
    if (tagInput.text.trim().isNotEmpty) {
      addTags(tagInput.text);
      tagInput.clear();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    changed();
  }

  Map<String, dynamic> _draft() => {
    'title': title.text,
    'description': description.text,
    'categories': categories.toList(),
    'people': people.toList(),
    'tags': tags,
    'files':
        files
            .map(
              (f) => {
                'name': f.name,
                'path': f.path,
                'size': f.size,
                if (scanPages.containsKey(f.path))
                  'scanPages':
                      scanPages[f.path]!.map((p) => p.toJson()).toList(),
              },
            )
            .toList(),
  };
  Future<void> saveDraft() async {
    busy = true;
    error = null;
    _emit();
    try {
      await repository.saveDraft(original?.id, _draft());
      savedDraft = null;
      dirty = false;
      message = 'Taslak kaydedildi.';
    } catch (_) {
      error = 'Taslak kaydedilemedi. Tekrar deneyin.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> restoreDraft() async {
    final draft = savedDraft;
    if (draft == null) return;
    busy = true;
    _emit();
    try {
      title.text = draft['title'] as String;
      description.text = draft['description'] as String;
      categories
        ..clear()
        ..addAll((draft['categories'] as List).cast<int>());
      people
        ..clear()
        ..addAll((draft['people'] as List).cast<int>());
      tags
        ..clear()
        ..addAll((draft['tags'] as List).cast<String>());
      files.clear();
      scanPages.clear();
      var missing = 0;
      for (final f in draft['files'] as List) {
        if (await File(f['path'] as String).exists()) {
          if (f['scanPages'] is List) {
            final pages =
                (f['scanPages'] as List)
                    .map(
                      (p) => ScanPage.fromJson(
                        Map<String, dynamic>.from(p as Map),
                      ),
                    )
                    .toList();
            var available = true;
            for (final page in pages) {
              if (!await File(page.path).exists()) available = false;
            }
            if (available && pages.isNotEmpty) {
              scanPages[f['path'] as String] = pages;
            }
          }
          files.add(
            PlatformFile(
              name: f['name'] as String,
              path: f['path'] as String,
              size: await File(f['path'] as String).length(),
            ),
          );
        } else {
          missing++;
        }
      }
      savedDraft = null;
      dirty = true;
      if (missing > 0) {
        error =
            '$missing kaynak dosya bulunamadı. Eksik dosyaları yeniden seçin.';
      }
    } catch (_) {
      error = 'Taslak açılamadı. Kaydedilmiş belgeleriniz korunuyor.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> discardDraft() async {
    try {
      await repository.deleteDraft(original?.id);
      savedDraft = null;
      _emit();
    } catch (_) {
      error = 'Taslak silinemedi.';
      _emit();
    }
  }

  BelgeModeli _edited(BelgeModeli doc, {bool batch = false}) => doc.copyWith(
    baslik:
        batch
            ? paths.basenameWithoutExtension(doc.orijinalDosyaAdi)
            : title.text.trim(),
    aciklama: description.text.trim().isEmpty ? null : description.text.trim(),
    kisiId: people.firstOrNull,
    kisiIds: people.toList(),
    kategoriId: categories.firstOrNull,
    kategoriIds: categories.toList(),
    etiketler: List.of(tags),
    guncellemeTarihi: DateTime.now(),
    senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
  );
  Future<bool> save() async {
    if (busy) return false;
    if (!ready) {
      error = 'Dosya, belge başlığı ve en az bir kişi seçimi gereklidir.';
      _emit();
      return false;
    }
    busy = true;
    error = null;
    processed = 0;
    _emit();
    final failures = <String>[];
    try {
      if (original != null) {
        await repository.update(original!, _edited(original!));
        anySaved = true;
      } else {
        final batch = files.length > 1;
        for (final file in List<PlatformFile>.of(files)) {
          try {
            await repository.import(file, (doc) => _edited(doc, batch: batch));
            files.remove(file);
            scanPages.remove(file.path);
            anySaved = true;
          } catch (e) {
            failures.add('${file.name}: $e');
          }
          processed++;
          _emit();
        }
      }
      if (failures.isNotEmpty) {
        if (anySaved && files.isNotEmpty) {
          title.text = paths.basenameWithoutExtension(files.first.name);
          try {
            await repository.saveDraft(null, _draft());
          } catch (_) {
            /* Retry remains available in the open form. */
          }
        }
        error =
            '${anySaved ? 'Başarılı dosyalar kaydedildi. Kalan dosyalar:\n' : ''}${failures.join('\n')}';
        dirty = true;
        return false;
      }
      dirty = false;
      try {
        await repository.deleteDraft(original?.id);
      } catch (_) {
        message = 'Belge kaydedildi; eski taslak temizlenemedi.';
      }
      return true;
    } catch (e) {
      error = '$e';
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    title.dispose();
    description.dispose();
    tagInput.dispose();
    super.dispose();
  }
}
