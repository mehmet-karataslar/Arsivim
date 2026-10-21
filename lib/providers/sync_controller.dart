import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sync_overview.dart';
import '../models/sync_comparison.dart';
import '../services/sync_gateway.dart';
import '../services/sync_repository.dart';
import '../widgets/senkronizasyon_progress_dialog.dart';

class SyncController extends ChangeNotifier {
  SyncController(this.repository, this.gateway) {
    gateway.initialize();
    gateway.changes.addListener(_onChange);
  }
  final SyncRepository repository;
  final SyncGateway gateway;
  SyncOverview? overview;
  String? error, actionMessage;
  String ip = '—', query = '';
  bool loading = false, busy = false, transferring = false, stopping = false;
  bool _disposed = false;
  DateTime? updatedAt;
  final selected = <String>{};
  Future<void>? _read;
  Timer? _debounce;
  SenkronizasyonIlerleme? progress;
  StreamSubscription<SenkronizasyonIlerleme>? _progressSubscription;
  List<SyncDevice> get devices => gateway.devices;
  List<SyncDevice> get visibleDevices =>
      devices
          .where(
            (d) => '${d.name} ${d.ip} ${d.platform}'.toLowerCase().contains(
              query.toLowerCase().trim(),
            ),
          )
          .toList();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onChange() {
    if (!transferring && !gateway.transferring) stopping = false;
    selected.removeWhere((id) => !devices.any((d) => d.id == id));
    _notify();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  Future<void> refresh() => _read ??= _load().whenComplete(() => _read = null);
  Future<void> _load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.read();
      final address = await gateway.address();
      if (_disposed) return;
      overview = result;
      ip = address;
      updatedAt = DateTime.now();
      selected.removeWhere((id) => !devices.any((d) => d.id == id));
    } catch (_) {
      error = 'Senkronizasyon bilgileri yüklenemedi. Yeniden deneyin.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void search(String value) {
    query = value;
    _notify();
  }

  void select(String id, bool value) {
    if (transferring) return;
    value ? selected.add(id) : selected.remove(id);
    _notify();
  }

  void automatic(bool value) {
    gateway.autoDisconnect = value;
    _notify();
  }

  Future<void> server() async {
    if (busy || transferring || gateway.transferring) return;
    busy = true;
    actionMessage = null;
    _notify();
    try {
      await gateway.setServer(!gateway.running);
      await refresh();
    } catch (_) {
      actionMessage = 'Sunucu durumu değiştirilemedi. Bağlantıyı kontrol edin.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> disconnect(String id) async {
    if (busy || transferring || gateway.transferring) return;
    busy = true;
    _notify();
    try {
      if (!await gateway.disconnect(id)) {
        actionMessage = 'Cihaz bağlantısı kesilemedi.';
      }
      await refresh();
    } catch (_) {
      actionMessage = 'Cihaz bağlantısı kesilemedi.';
    } finally {
      busy = false;
      _notify();
    }
  }

  List<SyncDevice> targets(SyncMode mode) =>
      devices
          .where(
            (d) =>
                d.canSend && (mode == SyncMode.all || selected.contains(d.id)),
          )
          .toList();
  Future<void> transfer(SyncMode mode, List<SyncDevice> targets) async {
    if (busy || transferring || gateway.transferring || targets.isEmpty) return;
    transferring = true;
    stopping = false;
    actionMessage = null;
    progress = null;
    _notify();
    var completed = 0;
    final stopVersion = gateway.stopVersion;
    try {
      final docs =
          mode == SyncMode.pending ? await repository.pendingDocuments() : null;
      if (docs != null && docs.isEmpty) {
        actionMessage = 'Gönderilmeyi bekleyen yerel değişiklik yok.';
        return;
      }
      _progressSubscription = gateway.progress().listen((value) {
        progress = value;
        _notify();
      });
      for (final target in targets) {
        if (stopping || stopVersion != gateway.stopVersion) {
          stopping = true;
          break;
        }
        if (await gateway.send(target, documents: docs)) completed++;
        if (stopVersion != gateway.stopVersion) stopping = true;
      }
      actionMessage =
          stopping
              ? 'Aktarım durduruldu. Tamamlanan belgeler korundu.'
              : '$completed / ${targets.length} cihazla aktarım tamamlandı.';
    } catch (_) {
      actionMessage =
          'Aktarım tamamlanamadı. Bağlantıyı ve aktarım sonuçlarını kontrol edin.';
    } finally {
      unawaited(_progressSubscription?.cancel());
      _progressSubscription = null;
      transferring = false;
      stopping = false;
      _notify();
      if (!_disposed) await refresh();
    }
  }

  void stop() {
    if (!transferring && !gateway.transferring) return;
    stopping = true;
    gateway.stop();
    _notify();
  }

  Future<void> transferDirection(SyncDevice device, SyncDirectionChoice choice) async {
    if (busy || transferring || gateway.transferring) {
      actionMessage = 'Başka bir aktarım devam ediyor.';
      _notify();
      return;
    }
    transferring = true;
    stopping = false;
    actionMessage = null;
    progress = null;
    _notify();
    try {
      _progressSubscription = gateway.progress().listen((value) {
        progress = value;
        _notify();
      });
      final success = choice.direction == SyncDirection.send
          ? await gateway.sendIds(device, choice.comparison.sendIds)
          : await gateway.receive(device, choice.comparison.receiveIds);
      actionMessage = stopping
          ? 'Aktarım durduruldu. Tamamlanan belgeler korundu.'
          : success ? 'Seçilen yöndeki yeni belgeler aktarıldı ve doğrulandı.'
          : 'Aktarım tam olarak tamamlanamadı. Sonuçları kontrol edip yeniden karşılaştırın.';
    } catch (_) {
      actionMessage = 'Aktarım tamamlanamadı. Mevcut belgeler korundu; yeniden karşılaştırın.';
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      transferring = false;
      stopping = false;
      _notify();
      if (!_disposed) await refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    gateway.changes.removeListener(_onChange);
    _debounce?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
}
