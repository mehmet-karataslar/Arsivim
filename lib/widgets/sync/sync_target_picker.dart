import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/sync_overview.dart';

class SyncTargetPicker extends StatelessWidget {
  const SyncTargetPicker({super.key, required this.targets});
  final List<SyncComparisonTarget> targets;

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('sync-target-picker'),
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 520,
      height: math.min(600, MediaQuery.sizeOf(context).height - 32),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Karşılaştırılacak cihaz',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: targets.length,
              itemBuilder: (_, index) {
                final target = targets[index];
                return ListTile(
                  key: ValueKey('sync-difference-target-${target.device.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(target.device.name),
                  subtitle: Text(
                    '${target.device.ip}\n${target.connected ? 'Bağlı' : 'Tanınan cihaz'}',
                  ),
                  onTap: () => Navigator.pop(context, target),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Vazgeç'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
