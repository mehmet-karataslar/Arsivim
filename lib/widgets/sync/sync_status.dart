import 'package:flutter/material.dart';
import '../../providers/sync_controller.dart';
import '../../theme/app_tones.dart';
import '../common/adaptive_card_layout.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';
import 'sync_section.dart';

class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key, required this.controller});
  final SyncController controller;
  @override
  Widget build(BuildContext context) {
    final running = controller.gateway.running;
    final started = controller.gateway.startedAt;
    final duration = started == null ? null : DateTime.now().difference(started);
    return SyncSection(title: 'Sunucu durumu', icon: Icons.cloud_done_outlined,
      subtitle: running ? 'Cihaz bağlantılarına hazır.' : 'Bağlantı için sunucuyu başlatın.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdaptiveCardLayout(minCardWidth: 125, maxColumns: 3, spacing: 12, children: [
          _value(context, 'IP adresi', controller.ip, Icons.lan_outlined),
          _value(context, 'Port', '8080', Icons.code),
          _value(context, 'Çalışma süresi', duration == null ? '—' :
            duration.inHours > 0 ? '${duration.inHours} sa ${duration.inMinutes % 60} dk' : '${duration.inMinutes} dk', Icons.schedule),
        ]),
        const SizedBox(height: 14),
        Text(running ? 'Sunucu aktif' : 'Sunucu kapalı', style: TextStyle(
          color: ToneColors.of(context, running ? AppTone.primary : AppTone.neutral).foreground,
          fontWeight: FontWeight.w600)),
      ]));
  }
  Widget _value(BuildContext context, String label, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      const SizedBox(height: 7), Text(label, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 4), SelectableText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
}

class SyncOptions extends StatelessWidget {
  const SyncOptions({super.key, required this.controller, this.compact = false});
  final SyncController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final automatic = AppCard(padding: const EdgeInsets.all(12), child: Row(children: [
      const ToneBadge(icon: Icons.power_settings_new, size: 36), const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Otomatik bağlantı kesme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text('Başarılı aktarım bitince bağlantıyı kes.', style: TextStyle(fontSize: 12)),
      ])),
      Switch(value: controller.gateway.autoDisconnect, onChanged: controller.transferring ? null : controller.automatic),
    ]));
    if (compact) return automatic;
    return AdaptiveCardLayout(minCardWidth: 300, maxColumns: 3, equalHeightRows: true, spacing: 14, children: [
      automatic,
      _info('Yerel ağ', controller.ip, Icons.wifi),
      _info('Son güncelleme', syncDate(controller.updatedAt, clock: true), Icons.history),
    ]);
  }
  Widget _info(String title, String value, IconData icon) => AppCard(padding: const EdgeInsets.all(12),
    child: Row(children: [ToneBadge(icon: icon, tone: AppTone.blue, size: 36), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 12)),
      ])),
    ]));
}
