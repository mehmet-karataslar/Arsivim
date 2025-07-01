import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/senkron_cihazi.dart';

class SenkronCards {
  // Sunucu kartı (PC için)
  static Widget buildServerCard({
    required bool sunucuCalisiyorMu,
    required String? localIP,
    required VoidCallback onStartServer,
    required VoidCallback onShowQRCode,
  }) {
    return Card(
      elevation: sunucuCalisiyorMu ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              sunucuCalisiyorMu
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
          width: sunucuCalisiyorMu ? 2 : 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient:
              sunucuCalisiyorMu
                  ? LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (sunucuCalisiyorMu ? Colors.green : Colors.grey)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      sunucuCalisiyorMu ? Icons.wifi : Icons.wifi_off,
                      color:
                          sunucuCalisiyorMu
                              ? Colors.green[600]
                              : Colors.grey[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sunucuCalisiyorMu
                              ? '🌐 Sunucu Aktif'
                              : '⚠️ Sunucu Kapalı',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (sunucuCalisiyorMu && localIP != null)
                          Text(
                            'Dinleniyor: $localIP:8080',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (sunucuCalisiyorMu)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        '✅ Online',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (sunucuCalisiyorMu && localIP != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Bu IP adresini telefonda girin:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        '$localIP:8080',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: '$localIP:8080'),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Kopyala'),
                          ),
                          ElevatedButton.icon(
                            onPressed: onShowQRCode,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('QR Kod'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Diğer cihazların bağlanabilmesi için sunucuyu başlatın.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onStartServer,
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Sunucuyu Başlat'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Bağlantı kartı
  static Widget buildConnectionCard({
    required TextEditingController ipController,
    required bool baglantiDeneniyor,
    required VoidCallback onConnect,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cihaza Bağlan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bağlanmak istediğiniz cihazın IP adresini girin:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Adresi',
                hintText: '192.168.1.100:8080',
                helperText: 'Örnek: 192.168.1.100:8080 (port isteğe bağlı)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: baglantiDeneniyor ? null : onConnect,
                icon:
                    baglantiDeneniyor
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.link),
                label: Text(baglantiDeneniyor ? 'Bağlanıyor...' : 'Bağlan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bağlı cihaz kartı
  static Widget buildConnectedDeviceCard({
    required SenkronCihazi? bagliBulunanCihaz,
    required VoidCallback onSync,
    required VoidCallback onDisconnect,
    required String Function(int) formatFileSize,
  }) {
    if (bagliBulunanCihaz == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Bağlı Cihaz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'BAĞLI',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bağlı cihaz bilgileri
            _buildDeviceInfoRow(Icons.computer, 'Cihaz', bagliBulunanCihaz.ad),
            _buildDeviceInfoRow(
              Icons.phone_android,
              'Platform',
              bagliBulunanCihaz.platform,
            ),
            _buildDeviceInfoRow(Icons.wifi, 'IP Adresi', bagliBulunanCihaz.ip),
            _buildDeviceInfoRow(
              Icons.folder,
              'Belgeler',
              '${bagliBulunanCihaz.belgeSayisi} adet',
            ),
            _buildDeviceInfoRow(
              Icons.storage,
              'Boyut',
              formatFileSize(bagliBulunanCihaz.toplamBoyut),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Senkronizasyon butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Senkronizasyon Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDisconnect,
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Bağlantıyı Kes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // QR Kod tarama kartı (mobil cihazlar için)
  static Widget buildQRScanCard({required VoidCallback onStartQRScan}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'QR Kod ile Bağlan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bilgisayardaki QR kodu tarayarak hızlı bağlantı kurun.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartQRScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QR Kod Tara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Log kartı
  static Widget buildLogCard({
    required List<String> logMesajlari,
    required VoidCallback onClearLog,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktivite Günlüğü',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton(onPressed: onClearLog, child: const Text('Temizle')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child:
                  logMesajlari.isEmpty
                      ? const Center(
                        child: Text(
                          'Henüz aktivite yok',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: logMesajlari.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              logMesajlari[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // Cihaz bilgi satırı
  static Widget _buildDeviceInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
