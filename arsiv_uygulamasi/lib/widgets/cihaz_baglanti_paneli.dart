import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import '../services/senkronizasyon_yonetici_servisi.dart';
import '../utils/timestamp_manager.dart';
// QR widget'ları kaldırıldı
// import '../widgets/qr_generator_widget.dart';
// import '../widgets/qr_scanner_widget.dart';

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
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildConnectionButtons(context),
              const SizedBox(height: 20),
              _buildDeviceList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.devices_rounded,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cihaz Bağlantıları',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${yonetici.bagliCihazlar.length} aktif bağlantı',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Tüm bağlantıları kes butonu
        if (yonetici.bagliCihazlar.isNotEmpty) ...[
          ElevatedButton.icon(
            onPressed: () => _tumBaglantilarinKes(context),
            icon: const Icon(Icons.link_off_rounded, size: 16),
            label: const Text('Tümünü Kes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                yonetici.bagliCihazlar.isNotEmpty
                    ? Colors.green
                    : Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                yonetici.bagliCihazlar.isNotEmpty ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                yonetici.bagliCihazlar.isNotEmpty ? 'Bağlı' : 'Bekleniyor',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            _pcPlatform ? 'Bağlantı Yönetimi' : 'Sunucuya Bağlan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          if (_pcPlatform) ...[
            // PC için butonlar
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    'QR Kod Göster',
                    Icons.qr_code_rounded,
                    Colors.blue,
                    onQRKodGoster,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Tam Ekran QR',
                    Icons.fullscreen_rounded,
                    Colors.purple,
                    onTamEkranQR,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Mobil için butonlar
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    'QR Kod Tara',
                    Icons.qr_code_scanner_rounded,
                    Colors.green,
                    onQRKodTara,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Cihaz Listesi',
                    Icons.list_rounded,
                    Colors.orange,
                    () => _showDeviceList(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context) {
    if (yonetici.bagliCihazlar.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bağlı Cihazlar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...yonetici.bagliCihazlar.map(
          (device) => _buildDeviceCard(context, device),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.devices_other_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz cihaz bağlı değil',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _pcPlatform
                ? 'Mobil cihazınızla QR kodunu tarayarak bağlanın'
                : 'QR kodu tarayarak sunucuya bağlanın',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, Map<String, dynamic> device) {
    final deviceName = device['name'] ?? 'Bilinmeyen Cihaz';
    final deviceType = device['platform'] ?? device['type'] ?? 'unknown';

    // Online durumunu belirleme - status ve online field'larını kontrol et
    final status = device['status'] ?? '';
    final onlineField = device['online'] ?? false;
    final isOnline = status == 'connected' || onlineField;

    // Son görülme zamanını formatlama
    final connectedAt = device['connected_at'];
    String lastSeen = 'Bilinmiyor';

    if (connectedAt != null) {
      if (connectedAt is DateTime) {
        final now = DateTime.now();
        final difference = now.difference(connectedAt);

        if (difference.inMinutes < 1) {
          lastSeen = 'Az önce';
        } else if (difference.inMinutes < 60) {
          lastSeen = '${difference.inMinutes} dakika önce';
        } else if (difference.inHours < 24) {
          lastSeen = '${difference.inHours} saat önce';
        } else {
          lastSeen = '${difference.inDays} gün önce';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getDeviceColor(deviceType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getDeviceIcon(deviceType),
                  color: _getDeviceColor(deviceType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bağlantı: $lastSeen',
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
                  color: isOnline ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.circle : Icons.circle_outlined,
                      color: isOnline ? Colors.white : Colors.grey[600],
                      size: 8,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                      style: TextStyle(
                        color: isOnline ? Colors.white : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bağlantı kesme butonları
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _senkronizasyonBaslat(context, device),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Senkronize Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _baglantiKes(context, device),
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Bağlantı Kes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
      case 'android':
      case 'ios':
        return Icons.smartphone_rounded;
      case 'desktop':
      case 'windows':
      case 'linux':
      case 'macos':
        return Icons.computer_rounded;
      case 'tablet':
        return Icons.tablet_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  Color _getDeviceColor(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
      case 'android':
        return Colors.green;
      case 'ios':
        return Colors.blue;
      case 'desktop':
      case 'windows':
        return Colors.purple;
      case 'linux':
        return Colors.orange;
      case 'macos':
        return Colors.grey;
      case 'tablet':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showDeviceList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.devices_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tüm Cihazlar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      yonetici.bagliCihazlar.isEmpty
                          ? _buildEmptyState(context)
                          : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: yonetici.bagliCihazlar.length,
                            itemBuilder: (context, index) {
                              return _buildDeviceCard(
                                context,
                                yonetici.bagliCihazlar[index],
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  /// Cihaz ile senkronizasyon başlat
  void _senkronizasyonBaslat(
    BuildContext context,
    Map<String, dynamic> device,
  ) async {
    final deviceName = device['name'] ?? 'Bilinmeyen Cihaz';

    // Onay dialog göster
    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Senkronizasyon Onayı'),
            content: Text('$deviceName ile senkronizasyon başlatılsın mı?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Başlat'),
              ),
            ],
          ),
    );

    if (onay == true) {
      // Senkronizasyon başlat
      final basarili = await yonetici.cihazlaSenkronizasyonBaslat(device);

      if (basarili) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $deviceName ile senkronizasyon başlatıldı'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $deviceName ile senkronizasyon başarısız'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Cihaz bağlantısını kes
  void _baglantiKes(BuildContext context, Map<String, dynamic> device) async {
    final deviceName = device['name'] ?? 'Bilinmeyen Cihaz';
    final deviceId = device['device_id'] ?? '';

    // Onay dialog göster
    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bağlantı Kesme Onayı'),
            content: Text('$deviceName cihazının bağlantısı kesilsin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Bağlantıyı Kes'),
              ),
            ],
          ),
    );

    if (onay == true) {
      // Bağlantı kes
      final basarili = await yonetici.cihazBaglantiKes(deviceId);

      if (basarili) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔌 $deviceName bağlantısı kesildi'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $deviceName bağlantısı kesilemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Tüm bağlantıları kes
  void _tumBaglantilarinKes(BuildContext context) async {
    // Onay dialog göster
    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tüm Bağlantıları Kesme Onayı'),
            content: Text('Tüm bağlantıları kesilsin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tümünü Kes'),
              ),
            ],
          ),
    );

    if (onay == true) {
      // Tüm bağlantıları kes
      final basarili = await yonetici.tumBaglantilarinKes();

      if (basarili) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔌 Tüm bağlantılar kesildi'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Tüm bağlantılar kesilemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
