import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final Function(String) onQRScanned;

  const QRScannerScreen({Key? key, required this.onQRScanned})
      : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool hasScannedCode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Tara'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 32),
            const Text(
              'QR Kod Tarayıcı',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arşivim bağlantı QR kodunu taramak için butona basın',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: hasScannedCode ? null : _scanQRCode,
              icon: Icon(hasScannedCode ? Icons.hourglass_empty : Icons.qr_code_scanner),
              label: Text(hasScannedCode ? 'İşleniyor...' : 'QR Kod Tara'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasScannedCode)
              const Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'QR kod işleniyor...',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _scanQRCode() async {
    if (hasScannedCode) return;

    try {
      setState(() {
        hasScannedCode = true;
      });

      String? res = await SimpleBarcodeScanner.scanBarcode(
        context,
        barcodeAppBar: const BarcodeAppBar(
          appBarTitle: 'QR Kod Tara',
          centerTitle: false,
          enableBackButton: true,
        ),
        isShowFlashIcon: true,
        delayMillis: 500,
        cameraFace: CameraFace.back,
      );

      if (mounted && res != null && res != '-1' && res.isNotEmpty) {
        // QR kod başarıyla tarandı
        widget.onQRScanned(res);
      } else {
        // Tarama iptal edildi veya hata oluştu
        setState(() {
          hasScannedCode = false;
        });
      }
    } catch (e) {
      // Hata durumunda state'i sıfırla
      if (mounted) {
        setState(() {
          hasScannedCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR kod tarama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}