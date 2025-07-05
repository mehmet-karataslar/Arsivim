import 'package:flutter/material.dart';
import 'dart:io';
import '../services/senkronizasyon_yonetici_servisi.dart';
import '../utils/timestamp_manager.dart';
import '../widgets/qr_generator_widget.dart';
import '../widgets/qr_scanner_widget.dart';

class CihazBaglantiPaneli extends StatelessWidget {
  final SenkronizasyonYoneticiServisi yonetici;
  final VoidCallback onQRKodGoster;
  final VoidCallback onQRKodTara;
  final VoidCallback onTamEkranQR;

  const CihazBaglantiPaneli({
    Key? key,
    required this.yonetici,
    required this.onQRKodGoster,
    required this.onQRKodTara,
    required this.onTamEkranQR,
  }) : super(key: key);

  bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Cihaz Bağlantıları',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${yonetici.bagliCihazlar.length} cihaz',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQRBaglantiButonlari(context),
            const SizedBox(height: 16),
            yonetici.bagliCihazlar.isEmpty
                ? _buildBagliCihazYok(context)
                : _buildBagliCihazListesi(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQRBaglantiButonlari(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQRButon(
            context,
            _pcPlatform ? 'QR Kod Göster' : 'QR Kod Tara',
            _pcPlatform ? Icons.qr_code : Icons.qr_code_scanner,
            Colors.blue,
            _pcPlatform ? onQRKodGoster : onQRKodTara,
          ),
        ),
        // Tam ekran QR butonu sadece PC'de görünsün
        if (_pcPlatform) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildQRButon(
              context,
              'Tam Ekran QR',
              Icons.fullscreen,
              Colors.purple,
              onTamEkranQR,
            ),
          ),
        ],
        // Mobil için cihaz listesi butonu
        if (!_pcPlatform) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildQRButon(
              context,
              'Bağlı Cihazlar',
              Icons.devices,
              Colors.green,
              () => _bagliCihazlariGoster(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQRButon(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBagliCihazYok(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.device_unknown, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Henüz bağlı cihaz yok',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _pcPlatform
                ? 'Diğer cihazlardan bu IP\'ye bağlanabilirsiniz'
                : 'Sunucu açık olduğunda cihazlar görünecek',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBagliCihazListesi(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: yonetici.bagliCihazlar.length,
      itemBuilder: (context, index) {
        final cihaz = yonetici.bagliCihazlar[index];
        return _buildCihazKarti(context, cihaz);
      },
    );
  }

  Widget _buildCihazKarti(BuildContext context, Map<String, dynamic> cihaz) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone, color: Colors.green[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cihaz['name'] ?? 'Bilinmeyen Cihaz',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  cihaz['ip'] ?? 'IP Bilinmiyor',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Bağlı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _bagliCihazlariGoster(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.devices, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'Bağlı Cihazlar (${yonetici.bagliCihazlar.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          yonetici.bagliCihazlar.isEmpty
                              ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.devices_other,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Henüz bağlı cihaz yok',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: yonetici.bagliCihazlar.length,
                                itemBuilder: (context, index) {
                                  final cihaz = yonetici.bagliCihazlar[index];
                                  return _buildDetayliCihazKarti(
                                    context,
                                    cihaz,
                                    index,
                                  );
                                },
                              ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDetayliCihazKarti(
    BuildContext context,
    Map<String, dynamic> cihaz,
    int index,
  ) {
    final isIncoming = cihaz['connection_type'] == 'incoming';
    final connectedAt = cihaz['connected_at'] as DateTime;
    final platform = cihaz['platform'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: isIncoming ? Colors.blue[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPlatformIcon(platform),
                    color: isIncoming ? Colors.blue[600] : Colors.green[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cihaz['name'] ?? 'Bilinmeyen Cihaz',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${cihaz['ip']} • $platform',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Bağlı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Bağlantı: ${TimestampManager.instance.formatRelativeTimestamp(connectedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Icon(
                  isIncoming ? Icons.call_received : Icons.call_made,
                  size: 14,
                  color: isIncoming ? Colors.blue[600] : Colors.green[600],
                ),
                const SizedBox(width: 4),
                Text(
                  isIncoming ? 'Gelen' : 'Giden',
                  style: TextStyle(
                    color: isIncoming ? Colors.blue[600] : Colors.green[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _cihazBaglantisiniKes(context, index),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('Bağlantıyı Kes'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cihazaSenkronBaslat(context, cihaz),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Senkron'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
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

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
      case 'ios':
        return Icons.smartphone;
      case 'windows':
      case 'linux':
      case 'macos':
        return Icons.computer;
      default:
        return Icons.device_unknown;
    }
  }

  void _cihazBaglantisiniKes(BuildContext context, int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bağlantıyı Kes'),
            content: Text(
              '${yonetici.bagliCihazlar[index]['name']} cihazının bağlantısını kesmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  yonetici.cihazBaglantisiniKes(index);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Bottom sheet'i de kapat
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Kes'),
              ),
            ],
          ),
    );
  }

  void _cihazaSenkronBaslat(BuildContext context, Map<String, dynamic> cihaz) {
    Navigator.of(context).pop(); // Bottom sheet'i kapat
    yonetici.cihazaSenkronBaslat(cihaz);
  }
}
