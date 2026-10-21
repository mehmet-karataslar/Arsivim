import 'package:flutter/material.dart';
import '../../models/sync_overview.dart';
import '../../providers/sync_controller.dart';
import 'sync_activity.dart';

class SyncMobileView extends StatelessWidget {
  const SyncMobileView({
    super.key,
    required this.controller,
    required this.showHeading,
    required this.blocked,
    required this.connecting,
    required this.connectionStatus,
    required this.onDifferences,
    required this.onScan,
    required this.onTrusted,
    required this.onCompare,
    required this.onDisconnect,
    required this.onHistory,
  });

  final SyncController controller;
  final bool showHeading, blocked, connecting;
  final String connectionStatus;
  final VoidCallback onDifferences, onScan, onTrusted, onHistory;
  final ValueChanged<SyncDevice> onCompare, onDisconnect;

  @override
  Widget build(BuildContext context) {
    final data = controller;
    final active = data.transferring || data.gateway.transferring;
    final unavailable = blocked || data.busy || active;
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: data.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    showHeading ? 'Senkronizasyon' : 'Cihazlar arası aktarım',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Senkronizasyonu yenile',
                  onPressed: data.loading ? null : data.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  data.devices.isEmpty ? Icons.link_off : Icons.link,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.devices.isEmpty
                        ? 'Bağlı cihaz yok'
                        : '${data.devices.length} cihaz bağlı',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                _metric(context, 'Telefonda bekleyen', data.overview?.pending),
                _metric(context, 'Bugün doğrulanan', data.overview?.today),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('sync-show-differences'),
              onPressed: unavailable ? null : onDifferences,
              icon: const Icon(Icons.compare_arrows),
              label: Text(connecting ? 'Kontrol ediliyor…' : 'Farkları gör'),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('sync-mobile-scan'),
                  onPressed: unavailable ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR kod tara'),
                ),
                TextButton.icon(
                  key: const ValueKey('sync-trusted-devices'),
                  onPressed: unavailable ? null : onTrusted,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Tanınan cihazlar'),
                ),
              ],
            ),
            if (data.loading ||
                (connecting && connectionStatus.isNotEmpty)) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (connecting && connectionStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(connectionStatus),
              ),
            if (data.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  data.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (active || data.actionMessage != null) ...[
              const Divider(height: 32),
              Text('Aktarım', style: theme.textTheme.titleMedium),
              if (active) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: data.progress?.yuzde),
                const SizedBox(height: 8),
                Text(data.progress?.aciklama ?? 'Aktarım hazırlanıyor…'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('sync-mobile-stop'),
                  onPressed: data.stopping ? null : data.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    data.stopping ? 'Durduruluyor…' : 'Aktarımı durdur',
                  ),
                ),
              ],
              if (data.progress?.hataMesaji != null)
                Text(data.progress!.hataMesaji!),
              if (data.actionMessage != null)
                Semantics(liveRegion: true, child: Text(data.actionMessage!)),
            ],
            if (data.devices.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Bağlı cihazlar', style: theme.textTheme.titleMedium),
              for (final device in data.devices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.devices),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  [device.ip, device.platform]
                                      .where((value) => value.isNotEmpty)
                                      .join(' · '),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '${device.name} bağlantısını kes',
                            onPressed:
                                unavailable ? null : () => onDisconnect(device),
                            icon: const Icon(Icons.link_off),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              unavailable || !device.canSend
                                  ? null
                                  : () => onCompare(device),
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('Belgeleri karşılaştır'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Son aktarımlar',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Tüm aktarım kayıtları',
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
            if (data.overview?.events.isNotEmpty ?? false)
              for (final event in data.overview!.events.take(3))
                SyncEventTile(event: event)
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Henüz kayıtlı aktarım yok.'),
              ),
            const Divider(height: 24),
            ExpansionTile(
              key: const ValueKey('sync-mobile-settings'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Bağlantı ayarları'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText('IP: ${data.ip}\nPort: 8080'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bu telefonu bağlantılara aç'),
                  value: data.gateway.running,
                  onChanged: unavailable ? null : (_) => data.server(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktarım sonrası bağlantıyı kes'),
                  value: data.gateway.autoDisconnect,
                  onChanged: unavailable ? null : data.automatic,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, int? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value?.toString() ?? '—',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
