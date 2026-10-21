import 'package:flutter/material.dart';
import '../../models/sync_overview.dart';
import '../../theme/app_tones.dart';
import '../common/tone_widgets.dart';
import 'sync_section.dart';

class SyncActivity extends StatelessWidget {
  const SyncActivity({super.key, required this.events, required this.onAll});
  final List<SyncEvent> events;
  final VoidCallback onAll;
  @override
  Widget build(BuildContext context) => SyncSection(
    title: 'Son aktiviteler',
    subtitle: 'Kayıtlı belge aktarım sonuçları',
    icon: Icons.history,
    tone: AppTone.blue,
    trailing: IconButton(
      tooltip: 'Tüm aktarım kayıtları',
      onPressed: onAll,
      icon: const Icon(Icons.open_in_full, size: 18),
    ),
    child:
        events.isEmpty
            ? const Text('Henüz kayıtlı aktarım yok.')
            : Column(
              children: [
                for (final event in events.take(5)) SyncEventTile(event: event),
              ],
            ),
  );
}

class SyncEventTile extends StatelessWidget {
  const SyncEventTile({super.key, required this.event});
  final SyncEvent event;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToneBadge(
          icon: event.failed ? Icons.error_outline : Icons.cloud_done_outlined,
          tone: event.failed ? AppTone.danger : AppTone.primary,
          size: 34,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: event.title,
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${event.failed
                    ? 'Aktarılamadı'
                    : event.status == 'zaten_var'
                    ? 'Mevcut kopya doğrulandı'
                    : 'Aktarım doğrulandı'} · ${syncDate(event.time, clock: true)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (event.failed && event.message != null)
                Text(
                  event.message!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
