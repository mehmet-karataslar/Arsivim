import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/senkron_cihazi.dart';

class SenkronDialogs {
  // PC için özel bağlantı dialog'u
  static void showPCConnectionDialog(
    BuildContext context,
    Map<String, dynamic> deviceInfo,
    VoidCallback onSyncPressed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.smartphone_rounded,
                      color: Colors.green[600],
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎉 Bağlantı Başarılı!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Mobil cihaz bağlandı',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: Container(
              constraints: const BoxConstraints(minWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cihaz bilgileri kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.devices,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Cihaz Bilgileri',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('📱 Cihaz Adı', deviceInfo['clientName']),
                        _buildInfoRow('🌐 IP Adresi', deviceInfo['ip']),
                        _buildInfoRow(
                          '💻 Platform',
                          deviceInfo['platform'] ?? 'Mobil',
                        ),
                        _buildInfoRow(
                          '📄 Belge Sayısı',
                          '${deviceInfo['belgeSayisi'] ?? 0}',
                        ),
                        _buildInfoRow(
                          '⏰ Bağlantı Zamanı',
                          DateTime.now().toString().substring(11, 19),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Durum göstergesi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Cihazlar başarıyla bağlandı ve senkronizasyon için hazır',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Daha Sonra'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSyncPressed();
                },
                icon: const Icon(Icons.sync, color: Colors.white),
                label: const Text('Şimdi Senkronize Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Başarı bildirimi dialog'u
  static void showSuccessDialog(
    BuildContext context,
    SenkronCihazi? bagliBulunanCihaz,
    VoidCallback onSyncPressed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bağlantı Başarılı!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cihaz bağlantısı başarıyla kuruldu!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.devices,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bagliBulunanCihaz?.ad ?? 'Bilinmeyen Cihaz',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.computer,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${bagliBulunanCihaz?.platform ?? "Bilinmeyen"}',
                          ),
                          const Spacer(),
                          Icon(Icons.folder, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text('${bagliBulunanCihaz?.belgeSayisi ?? 0} belge'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🎉 Artık dosyalarınızı senkronize edebilirsiniz!',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSyncPressed();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Şimdi Senkronize Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  // İlerleme dialog'u
  static void showProgressDialog(
    BuildContext context,
    ValueNotifier<double> progressNotifier,
    ValueNotifier<String> currentOperationNotifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: progressNotifier,
                    builder: (context, progress, child) {
                      return Column(
                        children: [
                          Text(
                            '${(progress * 100).toInt()}% Tamamlandı',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String>(
                            valueListenable: currentOperationNotifier,
                            builder: (context, operation, child) {
                              return Text(
                                operation,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // QR Kod gösterme
  static void showQRCode(BuildContext context, String? localIP) {
    if (localIP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP adresi henüz alınamadı')),
      );
      return;
    }

    final qrData = json.encode({
      'type': 'arsivim_connection',
      'ip': localIP,
      'port': 8080,
      'url': '$localIP:8080',
      'name': 'Arşivim Cihazı',
      'timestamp': DateTime.now().toIso8601String(),
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Kod ile Bağlantı'),
            content: SizedBox(
              width: 300,
              height: 350,
              child: Column(
                children: [
                  const Text(
                    'Bu QR kodu telefon ile tarayın:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$localIP:8080',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  // Cihaz bağlantısını kesme
  static void showDisconnectDialog(
    BuildContext context,
    SenkronCihazi? bagliBulunanCihaz,
    VoidCallback onDisconnect,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bağlantıyı Kes'),
            content: Text(
              '${bagliBulunanCihaz?.ad ?? "Cihaz"} ile bağlantıyı kesmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDisconnect();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Kes', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  // Bilgi satırı widget'ı
  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
