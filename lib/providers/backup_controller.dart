import 'package:flutter/foundation.dart';
import '../models/backup_overview.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/backup_repository.dart';

class BackupController extends ChangeNotifier {
  BackupController(this.repository);
  final BackupRepository repository;
  List<KisiModeli> people = [];
  List<KategoriModeli> categories = [];
  List<BackupRecord> history = [];
  final Map<int, List<BelgeModeli>> _byPerson = {};
  final Set<int> selectedPeople = {}, selectedCategories = {};
  Map<int, int> categoryCounts = {};
  int documentCount = 0, estimatedBytes = 0;
  bool loading = true, running = false, _disposed = false;
  String? error, message, target;
  String operation = '';
  double progress = 0;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (running) return;
    loading = true;
    error = null;
    _emit();
    try {
      final data = await repository.load();
      if (_disposed) return;
      people = data.people.where((p) => p.id != null).toList();
      categories = data.categories.where((c) => c.id != null).toList();
      _byPerson.clear();
      for (final d in data.documents) {
        for (final person in d.tumKisiIds) {
          _byPerson.putIfAbsent(person, () => []).add(d);
        }
      }
      selectedPeople.retainAll(people.map((p) => p.id!));
      _recalculate();
      try {
        history = await repository.history();
      } catch (_) {
        message = 'Yedekleme geçmişi okunamadı.';
      }
    } catch (_) {
      error = 'Yedeklenecek veriler yüklenemedi. Yeniden deneyin.';
    } finally {
      loading = false;
      _emit();
    }
  }

  int personDocuments(int id) => (_byPerson[id] ?? []).length;
  int personCategories(int id) =>
      (_byPerson[id] ?? [])
          .expand((d) => d.tumKategoriIds.isEmpty ? [0] : d.tumKategoriIds)
          .toSet()
          .length;
  List<KategoriModeli> get availableCategories => [
    ...categories.where((c) => categoryCounts.containsKey(c.id)),
    if (categoryCounts.containsKey(0))
      KategoriModeli(
        id: 0,
        kategoriAdi: 'Kategorisiz',
        olusturmaTarihi: DateTime(2000),
      ),
  ];
  void togglePerson(int id) {
    if (running) return;
    final previous = categoryCounts.keys.toSet();
    if (!selectedPeople.remove(id)) selectedPeople.add(id);
    _recalculate(addNew: previous);
    _emit();
  }

  void toggleAllPeople() {
    if (running) return;
    final previous = categoryCounts.keys.toSet();
    if (selectedPeople.length == people.length) {
      selectedPeople.clear();
    } else {
      selectedPeople.addAll(people.map((p) => p.id!));
    }
    _recalculate(addNew: previous);
    _emit();
  }

  void toggleCategory(int id) {
    if (running) return;
    if (!selectedCategories.remove(id)) selectedCategories.add(id);
    _recalculate();
    _emit();
  }

  void clear() {
    if (running) return;
    selectedPeople.clear();
    selectedCategories.clear();
    _recalculate();
    _emit();
  }

  void setTarget(String? value) {
    if (!running) {
      target = value;
      _emit();
    }
  }

  void _recalculate({Set<int>? addNew}) {
    final documents = <int, BelgeModeli>{};
    for (final p in selectedPeople) {
      for (final d in _byPerson[p] ?? <BelgeModeli>[]) {
        documents[d.id!] = d;
      }
    }
    categoryCounts = {};
    for (final d in documents.values) {
      for (final c in d.tumKategoriIds.isEmpty ? [0] : d.tumKategoriIds) {
        categoryCounts.update(c, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    selectedCategories.retainAll(categoryCounts.keys);
    if (addNew != null) {
      selectedCategories.addAll(categoryCounts.keys.toSet().difference(addNew));
    }
    final filter = selectedCategories.toList();
    documentCount =
        documents.values.where((d) => backupIncludes(d, filter)).length;
    // A shared document is copied into each selected person's folder by the existing service.
    estimatedBytes = 0;
    for (final p in selectedPeople) {
      for (final d in _byPerson[p] ?? <BelgeModeli>[]) {
        if (backupIncludes(d, filter)) estimatedBytes += d.dosyaBoyutu;
      }
    }
  }

  bool get canStart =>
      !loading &&
      !running &&
      error == null &&
      target != null &&
      selectedPeople.isNotEmpty &&
      documentCount > 0;
  Future<void> start() async {
    if (!canStart) return;
    running = true;
    message = null;
    progress = 0;
    operation = 'Yedekleme hazırlanıyor…';
    _emit();
    final peopleIds = selectedPeople.toList();
    final categoryIds = selectedCategories.toList();
    final destination = target!;
    try {
      final result = await repository.run(
        peopleIds,
        destination,
        {
          for (final id in peopleIds) id: [...categoryIds],
        },
        (value, text) {
          progress = value.clamp(0, 1);
          operation = text;
          _emit();
        },
      );
      history.insert(0, result);
      progress = 1;
      operation = 'Yedekleme tamamlandı';
      message = 'Yedeğiniz kaydedildi: ${result.path}';
    } catch (e) {
      operation = 'Yedekleme tamamlanamadı';
      message = '$e';
      history.insert(
        0,
        BackupRecord(
          time: DateTime.now(),
          path: destination,
          people: peopleIds.length,
          categories: categoryIds.length,
          documents: documentCount,
          bytes: 0,
          error: '$e',
        ),
      );
    }
    try {
      await repository.saveHistory(history);
    } catch (_) {
      message = '${message ?? ''}\nİşlem geçmişi kaydedilemedi.';
    }
    running = false;
    _emit();
  }
}
