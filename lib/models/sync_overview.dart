class SyncEvent {
  const SyncEvent(this.title, this.status, this.time, {this.message});
  final String title, status;
  final DateTime time;
  final String? message;
  bool get failed => status == 'hata';
}

class SyncOverview {
  const SyncOverview({
    this.total = 0,
    this.pending = 0,
    this.synced = 0,
    this.today = 0,
    this.events = const [],
    this.lastBackup,
    this.lastTransfer,
  });
  final int total, pending, synced, today;
  final List<SyncEvent> events;
  final DateTime? lastBackup, lastTransfer;
}

class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.platform = '',
    this.connectedAt,
  });
  final String id, name, ip, platform;
  final DateTime? connectedAt;
  bool get canSend => ip.isNotEmpty && ip != 'incoming';
  factory SyncDevice.fromMap(Map<String, dynamic> row) => SyncDevice(
    id: '${row['device_id'] ?? row['ip']}',
    name: '${row['name'] ?? row['device_name'] ?? 'Cihaz'}',
    ip: '${row['ip'] ?? ''}',
    platform: '${row['platform'] ?? ''}',
    connectedAt:
        row['connected_at'] is DateTime
            ? row['connected_at'] as DateTime
            : DateTime.tryParse(
              '${row['connected_at'] ?? row['timestamp'] ?? ''}',
            ),
  );
}

enum SyncMode { selected, pending, all }

class SyncComparisonTarget {
  const SyncComparisonTarget({
    required this.device,
    this.trustId,
    this.connected = false,
  });
  final SyncDevice device;
  final String? trustId;
  final bool connected;
}
