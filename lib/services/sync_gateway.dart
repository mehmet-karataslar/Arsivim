import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/sync_overview.dart';
import '../models/belge_modeli.dart';
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
  Stream<SenkronizasyonIlerleme> progress() => manager.createProgressStream();
  Future<bool> send(SyncDevice device, {List<BelgeModeli>? documents}) =>
      manager.belgeleriSenkronEt(device.ip, belgeler: documents);
  void stop() => manager.requestStop();
}
