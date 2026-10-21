import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/sync_overview.dart';
import '../models/belge_modeli.dart';
import '../models/sync_comparison.dart';
import '../widgets/senkronizasyon_progress_dialog.dart';
import 'http_sunucu_servisi.dart';
import 'senkronizasyon_yonetici_servisi.dart';

/// Ağ işlemleri sunumdan ayrıdır; mevcut hesap ve aktarım doğrulaması korunur.
class SyncGateway {
  SenkronizasyonYoneticiServisi get manager =>
      SenkronizasyonYoneticiServisi.instance;
  ValueListenable<int> get changes => manager.changes;
  void initialize() => manager.initializeConnections();
  bool get running => HttpSunucuServisi.instance.calisiyorMu;
  bool get transferring => manager.transferRunning;
  int get stopVersion => manager.stopVersion;
  DateTime? get startedAt => HttpSunucuServisi.instance.startedAt;
  bool get autoDisconnect => manager.otomatikBaglantiKes;
  set autoDisconnect(bool value) => manager.otomatikBaglantiKes = value;
  List<SyncDevice> get devices =>
      manager.bagliCihazlar.map(SyncDevice.fromMap).toList();
  Future<String> address() async =>
      await HttpSunucuServisi.instance.getRealIPAddress() ??
      'Ağ adresi bulunamadı';
  Future<void> setServer(bool value) => manager.setServerRunning(value);
  Future<bool> disconnect(String id) => manager.cihazBaglantiKes(id);
  Future<String> createQr() => manager.connectionDataOlustur();
  bool isQrValid(String code) {
    if (!running) return false;
    try {
      final data = jsonDecode(code) as Map<String, dynamic>;
      return HttpSunucuServisi.instance.hesapEslesmesi.biletGecerli(
        data['pair_ticket'] as String,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect(String qr) => manager.qrKoduTarandi(qr);
  Future<List<Map<String, dynamic>>> trustedDevices() async =>
      (await manager.taninanCihazlar())
          .map((device) => device.toMap())
          .toList();
  Future<bool> reconnect(String trustId, String address) =>
      manager.taninanCihazaBaglan(trustId, adres: address);

  Future<List<SyncComparisonTarget>> comparisonTargets() async {
    final saved = await trustedDevices();
    final targets = <String, SyncComparisonTarget>{};
    for (final row in saved) {
      final id = row['device_id'];
      final trust = row['trust_id'];
      if (id is! String || id.isEmpty || trust is! String || trust.isEmpty) {
        continue;
      }
      targets[id] = SyncComparisonTarget(
        trustId: trust,
        device: SyncDevice(
          id: id,
          name: row['device_name'] as String? ?? 'Tanınan cihaz',
          ip: row['last_ip'] as String? ?? '',
          platform: row['platform'] as String? ?? '',
        ),
      );
    }
    for (final device in devices.where((device) => device.canSend)) {
      targets[device.id] = SyncComparisonTarget(
        device: device,
        trustId: targets[device.id]?.trustId,
        connected: true,
      );
    }
    return targets.values.toList();
  }

  Future<SyncDevice> prepareComparison(SyncComparisonTarget target) async {
    if (transferring) {
      throw StateError('Aktarım devam ediyor. Bitmesini bekleyin.');
    }
    SyncDevice? current() =>
        devices
            .where((device) => device.id == target.device.id && device.canSend)
            .firstOrNull;
    final connected = current();
    if (connected != null) return connected;
    final trustId = target.trustId;
    if (trustId == null) {
      throw StateError(
        'Cihazın bağlantısı kesildi. QR koduyla yeniden eşleştirin.',
      );
    }
    if (target.device.ip.isEmpty) {
      throw StateError(
        'Cihazın ağ adresi kayıtlı değil. Tanınan cihazlar bölümünden adresini güncelleyin.',
      );
    }
    if (!await reconnect(trustId, target.device.ip)) {
      throw StateError(
        connectionError ??
            'Cihaza bağlanılamadı. Karşı cihazda uygulama ve sunucu açık olmalı. Tanınan cihazlar bölümünden ağ adresini kontrol edin.',
      );
    }
    final result = current();
    if (result == null) {
      throw StateError(
        'Beklenen cihaz bağlantısı doğrulanamadı. Yeniden deneyin.',
      );
    }
    if (transferring) {
      throw StateError(
        'Aktarım başladı. Karşılaştırmadan önce bitmesini bekleyin.',
      );
    }
    return result;
  }

  String? get connectionError => manager.sonBaglantiHatasi;
  Future<void> forget(String trustId) => manager.cihaziUnut(trustId);
  Future<SyncComparison> compare(SyncDevice device) =>
      manager.cihazlaKarsilastir(device.ip);
  Future<bool> sendIds(SyncDevice device, List<int> ids) =>
      manager.seciliBelgeleriGonder(device.ip, ids);
  Future<bool> receive(SyncDevice device, List<int> ids) =>
      manager.karsiCihazdanAl(device.ip, ids);
  Stream<SenkronizasyonIlerleme> progress() => manager.createProgressStream();
  Future<bool> send(SyncDevice device, {List<BelgeModeli>? documents}) =>
      manager.belgeleriSenkronEt(device.ip, belgeler: documents);
  void stop() => manager.requestStop();
}
