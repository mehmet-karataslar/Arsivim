import 'package:flutter/material.dart';
import '../../services/sync_gateway.dart';

class TrustedDevicesDialog extends StatefulWidget {
  const TrustedDevicesDialog({super.key, required this.gateway});
  final SyncGateway gateway;
  @override
  State<TrustedDevicesDialog> createState() => _TrustedDevicesDialogState();
}

class _TrustedDevicesDialogState extends State<TrustedDevicesDialog> {
  late Future<List<Map<String, dynamic>>> _devices =
      widget.gateway.trustedDevices();
  bool _busy = false;
  String? _error;

  Future<void> _connect(Map<String, dynamic> device) async {
    final address = TextEditingController(
      text: device['last_ip'] as String? ?? '',
    );
    final ip = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('${device['device_name']} cihazına bağlan'),
            content: TextField(
              controller: address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Yerel IP adresi',
                hintText: '192.168.1.100',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, address.text.trim()),
                child: const Text('Bağlan'),
              ),
            ],
          ),
    );
    // The route may still be animating out while its TextField is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => address.dispose());
    if (ip == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await widget.gateway.reconnect(device['trust_id'] as String, ip)) {
        if (mounted) Navigator.pop(context, true);
      } else if (mounted) {
        setState(
          () =>
              _error =
                  'Bağlanılamadı. Karşı cihazda uygulama ve sunucu açık, iki cihaz aynı ağda olmalı. Cihaz unutulduysa yeniden eşleştirin.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error =
                  'Cihaz doğrulanamadı. IP adresini ve cihaz güvenini kontrol edin.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget(Map<String, dynamic> device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cihazı unut'),
            content: Text(
              '${device['device_name']} için kayıtlı bağlantı izni kaldırılacak. Kişiler ve belgeler silinmez.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Unut'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gateway.forget(device['trust_id'] as String);
      if (mounted)
        setState(() {
          _devices = widget.gateway.trustedDevices();
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Cihaz izni kaldırılamadı. Yeniden deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Tanınan cihazlar'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) Text(_error!),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _devices,
                builder: (context, state) {
                  if (state.hasError)
                    return const Text(
                      'Tanınan cihazlar okunamadı. Kayıtlar değiştirilmedi.',
                    );
                  if (!state.hasData) return const LinearProgressIndicator();
                  if (state.data!.isEmpty)
                    return const Text(
                      'Henüz kayıtlı cihaz yok. İlk bağlantıyı QR kod ile kurun.',
                    );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final device in state.data!)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${device['device_name']}'),
                                    Text('${device['last_ip'] ?? ''}'),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    '${device['device_name']} cihazına bağlan',
                                onPressed:
                                    _busy ? null : () => _connect(device),
                                icon: const Icon(Icons.link),
                              ),
                              IconButton(
                                tooltip:
                                    '${device['device_name']} cihazını unut',
                                onPressed: _busy ? null : () => _forget(device),
                                icon: const Icon(Icons.phonelink_erase),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}
