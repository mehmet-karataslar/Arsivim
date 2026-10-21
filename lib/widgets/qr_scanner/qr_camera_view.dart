import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qr_scanner_notice.dart';

class QrCameraView extends StatefulWidget {
  const QrCameraView({super.key, required this.onDetected});
  final ValueChanged<String> onDetected;
  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<QrCameraView>
    with WidgetsBindingObserver {
  final camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  Future<void> _pending = Future.value();
  bool _foreground = true, _settings = false, _disposed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCamera());
  }

  void _updateCamera() {
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        if (_foreground) {
          await camera.start();
        } else {
          await camera.stop();
        }
      } catch (_) {
        /* Camera state exposes startup errors to the error builder. */
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Permission dialogs also change lifecycle; do not request permission in a loop.
    if (camera.value.hasCameraPermission || (_settings && _foreground)) {
      _settings = false;
      _updateCamera();
    }
  }

  Future<void> _openSettings() async {
    _settings = true;
    if (!await openAppSettings() && mounted) {
      _settings = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Uygulama ayarları açılamadı. Kamera iznini telefon ayarlarından açabilirsiniz.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pending.then((_) => camera.dispose()).catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight) * .7;
      final window = Rect.fromCenter(
        center: constraints.biggest.center(Offset.zero),
        width: side,
        height: side,
      );
      return MobileScanner(
        controller: camera,
        tapToFocus: true,
        scanWindow: window,
        useAppLifecycleState: false,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              widget.onDetected(value);
              break;
            }
          }
        },
        onDetectError: (_, _) {},
        placeholderBuilder:
            (_) => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Kamera açılıyor',
              ),
            ),
        errorBuilder: (context, error) {
          final denied =
              error.errorCode == MobileScannerErrorCode.permissionDenied;
          return QrScannerNotice(
            icon:
                denied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
            title: denied ? 'Kamera izni gerekli' : 'Kamera açılamadı',
            message:
                denied
                    ? 'QR kodunu okumak için uygulamanın kamera erişimini açın.'
                    : 'Kamerayı kullanan diğer uygulamaları kapatıp yeniden deneyin.',
            actions: [
              FilledButton(
                onPressed: _updateCamera,
                child: const Text('Yeniden dene'),
              ),
              if (denied)
                TextButton(
                  onPressed: _openSettings,
                  child: const Text('Ayarları aç'),
                ),
            ],
          );
        },
        overlayBuilder:
            (context, _) => Stack(
              children: [
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ValueListenableBuilder(
                    valueListenable: camera,
                    builder:
                        (context, value, _) => IconButton.filledTonal(
                          tooltip:
                              value.torchState == TorchState.on
                                  ? 'Feneri kapat'
                                  : 'Feneri aç',
                          onPressed:
                              value.torchState == TorchState.unavailable ||
                                      !value.isRunning
                                  ? null
                                  : () async {
                                    try {
                                      await camera.toggleTorch();
                                    } catch (_) {
                                      if (context.mounted)
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Fener bu kamerada kullanılamıyor.',
                                            ),
                                          ),
                                        );
                                    }
                                  },
                          icon: Icon(
                            value.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off,
                          ),
                        ),
                  ),
                ),
              ],
            ),
      );
    },
  );
}
