import 'package:flutter/material.dart';
import '../../services/app_update_service.dart';
import 'profile_section.dart';

class ProfileUpdate extends StatefulWidget {
  const ProfileUpdate({super.key, this.service});
  final AppUpdateService? service;
  @override
  State<ProfileUpdate> createState() => _ProfileUpdateState();
}

class _ProfileUpdateState extends State<ProfileUpdate> {
  late final AppUpdateService service;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? AppUpdateService.instance;
    service.initialize();
  }

  Future<void> _confirmInstall() async {
    final android = service.platform == UpdatePlatform.android;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Güncellemeyi kur'),
            content: Text(
              android
                  ? 'Android kurulum ekranı açılacak. “Güncelle” seçeneğini onaylayın. Uygulamayı kaldırmanız gerekmez; arşiviniz korunur.'
                  : 'Kurulum penceresi açılacak. Devam etmeden önce açık işlemlerinizi kaydedin, aktarımları tamamlayın ve Arşivim’i kapatın. Kurulum mevcut arşivinizi kullanmaya devam eder.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Şimdi değil'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kurulumu aç'),
              ),
            ],
          ),
    );
    if (confirmed == true) await service.install();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final release = service.update;
      final downloading = service.stage == UpdateStage.downloading;
      final ready = service.stage == UpdateStage.ready;
      return ProfileSection(
        title: 'Uygulama güncellemeleri',
        icon: Icons.system_update_alt_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.installedVersion == null
                  ? 'Yüklü sürüm kontrol sırasında okunacak.'
                  : 'Yüklü sürüm: ${service.installedVersion} (${service.installedBuild})',
            ),
            const SizedBox(height: 8),
            Text(
              service.supported
                  ? 'Yeni sürümleri GitHub’dan kontrol edin ve buradan indirin.'
                  : 'Uygulama içi güncelleme Android ve Windows’ta kullanılabilir.',
            ),
            if (service.message != null) ...[
              const SizedBox(height: 12),
              Text(service.message!, semanticsLabel: service.message),
            ],
            if (service.error != null) ...[
              const SizedBox(height: 12),
              Text(
                service.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (release != null) ...[
              const SizedBox(height: 12),
              Text(
                'Yeni sürüm: ${release.version} · ${(release.size / (1024 * 1024)).toStringAsFixed(1)} MB',
              ),
              if (release.notes.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.notes_rounded),
                  label: const Text('Sürüm notları'),
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('${release.version} sürüm notları'),
                              content: SingleChildScrollView(
                                child: SelectableText(release.notes),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Kapat'),
                                ),
                              ],
                            ),
                      ),
                ),
            ],
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: service.progress),
              const SizedBox(height: 8),
              Text('İndiriliyor: %${((service.progress ?? 0) * 100).floor()}'),
              const Text(
                'İndirme sırasında uygulamayı açık tutun. Diğer sekmeleri kullanabilirsiniz.',
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      service.supported && !service.busy ? service.check : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    service.stage == UpdateStage.checking
                        ? 'Kontrol ediliyor…'
                        : 'Güncellemeleri kontrol et',
                  ),
                ),
                if (release != null && !downloading)
                  FilledButton.icon(
                    onPressed:
                        service.busy
                            ? null
                            : ready
                            ? _confirmInstall
                            : service.download,
                    icon: Icon(
                      ready
                          ? Icons.install_mobile_rounded
                          : Icons.download_rounded,
                    ),
                    label: Text(
                      service.stage == UpdateStage.installing
                          ? 'Kurulum açılıyor…'
                          : ready
                          ? 'Güncellemeyi kur'
                          : 'Güncellemeyi indir',
                    ),
                  ),
                if (downloading)
                  TextButton(
                    onPressed: service.cancelDownload,
                    child: const Text('İndirmeyi iptal et'),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
