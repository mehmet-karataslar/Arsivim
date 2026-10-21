import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/sync_overview.dart';
import '../../providers/sync_controller.dart';
import 'sync_section.dart';

class SyncDevices extends StatelessWidget {
  const SyncDevices({
    super.key,
    required this.controller,
    required this.onQr,
    this.pairing = false,
    required this.onDisconnect,
    this.onScan,
    this.qrData,
    this.onCompare,
    this.onTrusted,
  });
  final SyncController controller;
  final VoidCallback onQr;
  final bool pairing;
  final ValueChanged<SyncDevice> onDisconnect;
  final VoidCallback? onScan;
  final String? qrData;
  final ValueChanged<SyncDevice>? onCompare;
  final VoidCallback? onTrusted;
  @override
  Widget build(BuildContext context) => SyncSection(
    title: 'Cihaz bağlantıları',
    subtitle:
        '${controller.devices.length} bağlı cihaz · Aktarım için cihaz seçin.',
    icon: Icons.devices,
    child: LayoutBuilder(
      builder: (context, box) {
        final pairingPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: SyncPairingCode(data: qrData)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('sync-pair-device'),
              onPressed: controller.busy || pairing ? null : onQr,
              icon: const Icon(Icons.qr_code, size: 18),
              label: Text(
                qrData == null ? 'Yeni cihaz eşleştir' : 'QR kodu aç',
              ),
            ),
            if (onScan != null)
              TextButton.icon(
                onPressed: pairing || controller.busy ? null : onScan,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('QR kod tara'),
              ),
            if (onTrusted != null)
              TextButton.icon(
                key: const ValueKey('sync-trusted-devices'),
                onPressed:
                    pairing ||
                            controller.busy ||
                            controller.transferring ||
                            controller.gateway.transferring
                        ? null
                        : onTrusted,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Tanınan cihazlar'),
              ),
          ],
        );
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.visibleDevices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  controller.devices.isEmpty
                      ? 'Henüz bağlı cihaz yok. İki cihazı aynı yerel ağa bağlayıp QR kodunu tarayın.'
                      : 'Aramayla eşleşen cihaz yok.',
                ),
              ),
            for (final device in controller.visibleDevices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: controller.selected.contains(device.id),
                      semanticLabel: '${device.name} cihazını seç',
                      onChanged:
                          controller.transferring || !device.canSend
                              ? null
                              : (value) =>
                                  controller.select(device.id, value ?? false),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap:
                            controller.transferring || !device.canSend
                                ? null
                                : () => controller.select(
                                  device.id,
                                  !controller.selected.contains(device.id),
                                ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${device.ip} · ${device.platform}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'Bağlandı: ${syncDate(device.connectedAt, clock: true)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (onCompare != null)
                                TextButton.icon(
                                  onPressed:
                                      controller.transferring ||
                                              controller.gateway.transferring ||
                                              controller.busy
                                          ? null
                                          : () => onCompare!(device),
                                  icon: const Icon(
                                    Icons.compare_arrows,
                                    size: 18,
                                  ),
                                  label: const Text('Karşılaştır ve aktar'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '${device.name} bağlantısını kes',
                      onPressed:
                          controller.transferring ||
                                  controller.gateway.transferring ||
                                  controller.busy
                              ? null
                              : () => onDisconnect(device),
                      icon: const Icon(Icons.link_off, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        );
        if (box.maxWidth >= 560 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 184, child: pairingPanel),
              const SizedBox(width: 16),
              Expanded(child: list),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [list, const Divider(height: 24), pairingPanel],
        );
      },
    ),
  );
}

/// Süresi dolan eşleştirme kodu ekranda tutulmaz; sürekli animasyon çalışmaz.
class SyncPairingCode extends StatefulWidget {
  const SyncPairingCode({super.key, this.data, this.size = 160});
  final String? data;
  final double size;
  @override
  State<SyncPairingCode> createState() => _SyncPairingCodeState();
}

class _SyncPairingCodeState extends State<SyncPairingCode> {
  Timer? _expiry;
  bool _valid = false;
  void _update() {
    _expiry?.cancel();
    _valid = false;
    try {
      final json = jsonDecode(widget.data ?? '') as Map;
      final expires = DateTime.fromMillisecondsSinceEpoch(
        json['pair_expires'] as int,
      );
      final remaining = expires.difference(DateTime.now());
      _valid = remaining > Duration.zero;
      if (_valid) {
        _expiry = Timer(remaining, () {
          if (mounted) setState(() => _valid = false);
        });
      }
    } catch (_) {
      _valid = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(covariant SyncPairingCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _update();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _valid
          ? Semantics(
            label: 'Cihaz eşleştirme QR kodu',
            child: QrImageView(
              data: widget.data!,
              size: widget.size,
              backgroundColor: Colors.white,
            ),
          )
          : SizedBox(
            width: widget.size,
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, size: 88, color: Color(0xFF758880)),
                Text(
                  widget.data == null
                      ? 'QR kod için hesabınızı doğrulayın.'
                      : 'Kodun süresi doldu. Yeni QR kod oluşturun.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
}
