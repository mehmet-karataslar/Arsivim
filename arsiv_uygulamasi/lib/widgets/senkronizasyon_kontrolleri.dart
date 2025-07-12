import 'package:flutter/material.dart';
import 'dart:io';
import '../services/senkronizasyon_yonetici_servisi.dart';

class SenkronizasyonKontrolleri extends StatelessWidget {
  final SenkronizasyonYoneticiServisi yonetici;
  final VoidCallback? onTumSistemSenkron;

  const SenkronizasyonKontrolleri({
    Key? key,
    required this.yonetici,
    this.onTumSistemSenkron,
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
            Text(
              'Senkronizasyon Kontrolleri',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _pcPlatform
                ? _buildPCKontroller(context)
                : _buildMobileKontroller(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPCKontroller(BuildContext context) {
    return Column(
      children: [
        Row(
      children: [
        Expanded(
          child: _buildKontrolButonu(
            context,
            'Sunucuyu Başlat',
            yonetici.sunucuCalisiyorMu ? 'Durdur' : 'Başlat',
            yonetici.sunucuCalisiyorMu ? Icons.stop : Icons.play_arrow,
            yonetici.sunucuCalisiyorMu ? Colors.red : Colors.green,
            yonetici.sunucuToggle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKontrolButonu(
            context,
            'Senkronizasyon',
            yonetici.senkronizasyonAktif ? 'Durdur' : 'Başlat',
            yonetici.senkronizasyonAktif ? Icons.pause : Icons.sync,
            yonetici.senkronizasyonAktif ? Colors.orange : Colors.blue,
            yonetici.senkronizasyonToggle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKontrolButonu(
            context,
            'Hızlı Senkron',
            'Başlat',
            Icons.flash_on,
            Colors.purple,
            yonetici.hizliSenkronizasyon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildKontrolButonu(
            context,
            'Tüm Sistemi Senkron Et',
            'Başlat',
            Icons.cloud_sync,
            Colors.indigo,
            onTumSistemSenkron ?? () {},
          ),
        ),
      ],
    );
  }

  Widget _buildMobileKontroller(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKontrolButonu(
                context,
                'Sunucu',
                yonetici.sunucuCalisiyorMu ? 'Durdur' : 'Başlat',
                yonetici.sunucuCalisiyorMu ? Icons.stop : Icons.play_arrow,
                yonetici.sunucuCalisiyorMu ? Colors.red : Colors.green,
                yonetici.sunucuToggle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKontrolButonu(
                context,
                'Senkron',
                yonetici.senkronizasyonAktif ? 'Durdur' : 'Başlat',
                yonetici.senkronizasyonAktif ? Icons.pause : Icons.sync,
                yonetici.senkronizasyonAktif ? Colors.orange : Colors.blue,
                yonetici.senkronizasyonToggle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildKontrolButonu(
            context,
            'Hızlı Senkronizasyon',
            'Başlat',
            Icons.flash_on,
            Colors.purple,
            yonetici.hizliSenkronizasyon,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildKontrolButonu(
            context,
            'Tüm Sistemi Senkron Et',
            'Başlat',
            Icons.cloud_sync,
            Colors.indigo,
            onTumSistemSenkron ?? () {},
          ),
        ),
      ],
    );
  }

  Widget _buildKontrolButonu(
    BuildContext context,
    String baslik,
    String butonText,
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
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                baslik,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                butonText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
