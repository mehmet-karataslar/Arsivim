import 'dart:io';
import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../providers/qr_scan_controller.dart';
import 'common/section_surface.dart';
import 'qr_scanner/qr_camera_view.dart';
import 'qr_scanner/qr_scanner_notice.dart';

typedef QrCameraBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onDetected);

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({
    super.key,
    required this.onQRScanned,
    this.cameraBuilder,
  });
  final ValueChanged<String> onQRScanned;
  final QrCameraBuilder? cameraBuilder;
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final data = QrScanController();
  bool _externalBusy = false;
  int _cameraVersion = 0;
  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  void _retry() {
    _cameraVersion++;
    data.retry();
  }

  Future<void> _windowsCamera() async {
    if (_externalBusy) return;
    setState(() => _externalBusy = true);
    try {
      final result = await SimpleBarcodeScanner.scanBarcode(
        context,
        scanType: ScanType.qr,
        scanFormat: ScanFormat.ONLY_QR_CODE,
        cancelButtonText: 'İptal',
        barcodeAppBar: const BarcodeAppBar(
          appBarTitle: 'QR kod tara',
          centerTitle: true,
          enableBackButton: true,
        ),
      );
      if (mounted && result != null) data.detect(result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kamera açılamadı. Kamera erişimini kontrol edip tekrar deneyin.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _externalBusy = false);
    }
  }

  void _confirm() {
    final code = data.confirm();
    if (code != null) widget.onQRScanned(code);
  }

  Widget _camera(BuildContext context) {
    if (widget.cameraBuilder != null)
      return widget.cameraBuilder!(context, data.detect);
    if (Platform.isAndroid || Platform.isIOS)
      return QrCameraView(
        key: ValueKey(_cameraVersion),
        onDetected: data.detect,
      );
    return QrScannerNotice(
      icon: Icons.qr_code_scanner,
      title:
          Platform.isWindows
              ? 'Bilgisayar kamerasıyla tara'
              : 'Telefonunuzla QR kodunu tarayın',
      message:
          Platform.isWindows
              ? 'Diğer cihazdaki Arşivim bağlantı kodunu kameraya gösterin.'
              : 'Bu cihazda kamera ile QR tarama desteklenmiyor. Senkronizasyon sayfasında kodu gösterip telefonunuzla tarayabilirsiniz.',
      actions: [
        if (Platform.isWindows)
          FilledButton.icon(
            onPressed: _externalBusy ? null : _windowsCamera,
            icon: const Icon(Icons.videocam_outlined),
            label: Text(_externalBusy ? 'Kamera açılıyor…' : 'Kamerayı aç'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: data,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final result = data.result;
      final ready = result != null;
      final instructions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ready ? 'Cihaz bulundu' : 'Cihazlarınızı bağlayın',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            ready
                ? 'Bağlanmadan önce cihaz bilgisini kontrol edin.'
                : 'Diğer cihazda Senkronizasyon → QR kod göster seçeneğini açın. Kodu kamera çerçevesine yerleştirin.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (ready) ...[
            _detail(Icons.devices_outlined, 'Cihaz', result.device),
            _detail(Icons.person_outline, 'Yönetici', result.owner),
            _detail(Icons.wifi, 'Ağ adresi', result.address),
            const SizedBox(height: 8),
            const Text(
              'Devam ettiğinizde mevcut hesap doğrulaması açılır. Belgeler otomatik aktarılmaz.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('qr-confirm'),
              onPressed: data.submitted ? null : _confirm,
              icon: const Icon(Icons.link),
              label: Text(
                data.submitted ? 'Devam ediliyor…' : 'Bağlantıya devam et',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: data.submitted ? null : _retry,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Yeniden tara'),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi, size: 22, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('İki cihaz aynı yerel ağa bağlı olmalı.'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.light_mode_outlined,
                  size: 22,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kodu tamamen çerçeveye alın. Gerekirse feneri açın veya odaklamak için ekrana dokunun.',
                  ),
                ),
              ],
            ),
          ],
        ],
      );
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('QR kod tara'),
          leading: IconButton(
            tooltip: 'Taramayı kapat',
            onPressed:
                data.submitted || _externalBusy
                    ? null
                    : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 850 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21;
              final view = SizedBox(
                height:
                    wide
                        ? 420
                        : (constraints.maxWidth * .85).clamp(240.0, 380.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child:
                      data.error != null
                          ? QrScannerNotice(
                            icon: Icons.qr_code_2,
                            title: 'Kod kullanılamıyor',
                            message: data.error!,
                            actions: [
                              FilledButton.icon(
                                key: const ValueKey('qr-retry'),
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Yeniden tara'),
                              ),
                            ],
                          )
                          : ready
                          ? QrScannerNotice(
                            icon: Icons.check_circle_outline,
                            title: 'QR kod okundu',
                            message:
                                'Kamera durduruldu. Cihaz bilgisini kontrol ederek devam edebilirsiniz.',
                            actions: const [],
                          )
                          : _camera(context),
                ),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 28 : 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child:
                        wide
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: view),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: SectionSurface(
                                    padding: const EdgeInsets.all(24),
                                    child: instructions,
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                view,
                                const SizedBox(height: 22),
                                instructions,
                              ],
                            ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}
