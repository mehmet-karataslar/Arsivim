import 'package:flutter/material.dart';
import '../../models/sync_overview.dart';
import '../../providers/sync_controller.dart';
import '../../theme/app_tones.dart';
import '../common/adaptive_card_layout.dart';
import 'sync_section.dart';

class SyncControls extends StatelessWidget {
  const SyncControls({
    super.key,
    required this.controller,
    required this.onTransfer,
  });
  final SyncController controller;
  final ValueChanged<SyncMode> onTransfer;
  @override
  Widget build(BuildContext context) {
    final data = controller;
    final available =
        !data.busy && !data.transferring && !data.gateway.transferring;
    return SyncSection(
      title: 'Senkronizasyon kontrolleri',
      icon: Icons.tune,
      subtitle: 'Cihaz seçin ve göndermek istediğiniz belgeleri belirleyin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveCardLayout(
            minCardWidth: 160,
            maxColumns: 2,
            allowedColumns: const [2],
            equalHeightRows: true,
            spacing: 10,
            children: [
              _button(
                context,
                'Senkronizasyonu başlat',
                'Seçili cihazlara tüm belgeler',
                Icons.sync,
                AppTone.primary,
                available && data.targets(SyncMode.selected).isNotEmpty
                    ? () => onTransfer(SyncMode.selected)
                    : null,
                filled: true,
              ),
              _button(
                context,
                'Hızlı senkron',
                'Bekleyen yerel değişiklikler',
                Icons.bolt,
                AppTone.blue,
                available &&
                        data.targets(SyncMode.pending).isNotEmpty &&
                        (data.overview?.pending ?? 0) > 0
                    ? () => onTransfer(SyncMode.pending)
                    : null,
              ),
              _button(
                context,
                'Tümünü senkron et',
                'Bağlı cihazlara tüm belgeler',
                Icons.devices,
                AppTone.purple,
                available && data.targets(SyncMode.all).isNotEmpty
                    ? () => onTransfer(SyncMode.all)
                    : null,
              ),
              _button(
                context,
                data.stopping ? 'Durduruluyor' : 'Aktarımı durdur',
                'Devam eden dosya tamamlanınca',
                Icons.stop_circle_outlined,
                AppTone.danger,
                (data.transferring || data.gateway.transferring) &&
                        !data.stopping
                    ? data.stop
                    : null,
              ),
            ],
          ),
          if (data.devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Başlamak için QR koduyla bir cihaz bağlayın.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (data.transferring || data.gateway.transferring) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: data.progress?.yuzde),
            const SizedBox(height: 8),
            Text(
              data.progress?.aciklama ?? 'Aktarım hazırlanıyor…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (data.progress?.hataMesaji != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                data.progress!.hataMesaji!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (data.actionMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(data.actionMessage!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    AppTone tone,
    VoidCallback? onPressed, {
    bool filled = false,
  }) {
    final colors = ToneColors.of(context, tone);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(12),
        foregroundColor:
            filled
                ? Theme.of(context).colorScheme.onPrimary
                : colors.foreground,
        backgroundColor:
            filled && onPressed != null ? colors.foreground : colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      child:
          MediaQuery.sizeOf(context).width >= 1300 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18
              ? Row(
                children: [
                  Icon(icon, size: 25),
                  const SizedBox(width: 12),
                  Expanded(child: _labels(title, subtitle)),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 25),
                  const SizedBox(height: 8),
                  _labels(title, subtitle),
                ],
              ),
    );
  }

  Widget _labels(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 11)),
    ],
  );
}
