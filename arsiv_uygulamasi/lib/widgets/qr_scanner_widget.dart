import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final Function(String) onQRScanned;

  const QRScannerScreen({Key? key, required this.onQRScanned})
    : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Tara'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: const Icon(Icons.flip_camera_android),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (isScanning && capture.barcodes.isNotEmpty) {
                      final String? code = capture.barcodes.first.rawValue;
                      if (code != null) {
                        isScanning = false;
                        widget.onQRScanned(code);
                      }
                    }
                  },
                ),
                // Custom overlay
                Container(
                  decoration: ShapeDecoration(
                    shape: QRScannerOverlayShape(
                      borderColor: Colors.green,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'QR kodu kamera ile tarayın',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Arşivim bağlantı QR kodunu tarayın',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom QR Scanner Overlay
class QRScannerOverlayShape extends ShapeBorder {
  const QRScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    Path holePath =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center,
              width: cutOutSize,
              height: cutOutSize,
            ),
            Radius.circular(borderRadius),
          ),
        );
    return Path.combine(PathOperation.difference, path, holePath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint =
        Paint()
          ..color = overlayColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(getOuterPath(rect), paint);

    // Draw border
    final Paint borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final double centerX = rect.center.dx;
    final double centerY = rect.center.dy;
    final double halfSize = cutOutSize / 2;

    // Top-left corner
    canvas.drawLine(
      Offset(centerX - halfSize, centerY - halfSize),
      Offset(centerX - halfSize + borderLength, centerY - halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX - halfSize, centerY - halfSize),
      Offset(centerX - halfSize, centerY - halfSize + borderLength),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(centerX + halfSize, centerY - halfSize),
      Offset(centerX + halfSize - borderLength, centerY - halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX + halfSize, centerY - halfSize),
      Offset(centerX + halfSize, centerY + halfSize + borderLength),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(centerX - halfSize, centerY + halfSize),
      Offset(centerX - halfSize + borderLength, centerY + halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX - halfSize, centerY + halfSize),
      Offset(centerX - halfSize, centerY + halfSize - borderLength),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(centerX + halfSize, centerY + halfSize),
      Offset(centerX + halfSize - borderLength, centerY + halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX + halfSize, centerY + halfSize),
      Offset(centerX + halfSize, centerY + halfSize - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
