import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/backup_controller.dart';
import '../services/backup_repository.dart';
import '../theme/app_tones.dart';
import '../utils/screen_utils.dart';
import '../widgets/common/metric_grid.dart';
import '../widgets/common/tone_widgets.dart';
import '../widgets/backup/backup_target.dart';
import '../widgets/backup/backup_metrics.dart';
import '../widgets/backup/backup_selection.dart';
import '../widgets/backup/backup_summary.dart';
import '../widgets/backup/backup_history.dart';

class YedeklemeEkrani extends StatefulWidget {
  const YedeklemeEkrani({
    super.key,
    this.showHeading = true,
    this.repository,
    this.pickDirectory,
  });
  final bool showHeading;
  final BackupRepository? repository;
  final Future<String?> Function()? pickDirectory;
  @override
  State<YedeklemeEkrani> createState() => _YedeklemeEkraniState();
}

class _YedeklemeEkraniState extends State<YedeklemeEkrani> {
  late final BackupController _data;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    _data = BackupController(widget.repository ?? BackupRepository())..load();
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking || _data.running) return;
    setState(() => _picking = true);
    try {
      final path =
          await (widget.pickDirectory?.call() ??
              FilePicker.platform.getDirectoryPath());
      if (mounted && path != null) _data.setTarget(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Klasör seçilemedi. Yeniden deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _data,
    builder: (context, _) {
      if (_data.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_data.error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_data.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _data.load,
                child: const Text('Yeniden dene'),
              ),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeading) ...[
              Row(
                children: [
                  const ToneBadge(icon: Icons.cloud_outlined, size: 68),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yedekleme',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Belgelerinizi kişi ve kategori bazında güvenle yedekleyin.',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Verileri yenile',
                    onPressed: _data.running ? null : _data.load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = BackupMetrics(
                  items: [
                    MetricData(
                      'Seçili kişi',
                      '${_data.selectedPeople.length}',
                      'Toplam ${_data.people.length} kişi',
                      Icons.person_outline,
                      AppTone.blue,
                    ),
                    MetricData(
                      'Seçili kategori',
                      '${_data.selectedCategories.length}',
                      'Seçili kişilerin kategorileri',
                      Icons.folder_outlined,
                      AppTone.primary,
                    ),
                    MetricData(
                      'Toplam belge',
                      '${_data.documentCount}',
                      'Seçilen öğelerde',
                      Icons.description_outlined,
                      AppTone.purple,
                    ),
                    MetricData(
                      'Tahmini boyut',
                      ScreenUtils.formatFileSize(_data.estimatedBytes),
                      'Kopyalanacak dosyalar',
                      Icons.storage_outlined,
                      AppTone.amber,
                    ),
                  ],
                );
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    metrics,
                    const SizedBox(height: 16),
                    BackupTarget(data: _data, onPick: _pick, picking: _picking),
                    const SizedBox(height: 16),
                    BackupSelection(data: _data),
                  ],
                );
                final aside = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BackupSummary(data: _data),
                    const SizedBox(height: 16),
                    BackupHistory(records: _data.history),
                  ],
                );
                if (constraints.maxWidth < 1050 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [main, const SizedBox(height: 16), aside],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: main),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: (constraints.maxWidth * .33).clamp(350, 470),
                      child: aside,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
