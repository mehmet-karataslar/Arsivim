import 'package:flutter/material.dart';
import 'dart:io';
import '../models/belge_modeli.dart';
import '../services/senkronizasyon_yonetici_servisi.dart';
import '../utils/timestamp_manager.dart';
import '../screens/senkron_belgeler_ekrani.dart';
import 'senkronizasyon_progress_dialog.dart';

class SenkronizasyonKartlari {
  static bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Widget buildSunucuDurumKarti(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    Animation<double> pulseAnimation,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              yonetici.sunucuCalisiyorMu
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScaleTransition(
                  scale:
                      yonetici.sunucuCalisiyorMu
                          ? pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          yonetici.sunucuCalisiyorMu
                              ? Colors.green
                              : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      yonetici.sunucuCalisiyorMu
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sunucu Durumu',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        yonetici.sunucuCalisiyorMu
                            ? 'Aktif ve bağlantı kabul ediyor'
                            : 'Şu anda kapalı',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'IP Adresi',
                    yonetici.sunucuCalisiyorMu ? '192.168.1.100' : 'N/A',
                    Icons.router,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Port',
                    yonetici.sunucuCalisiyorMu ? '8080' : 'N/A',
                    Icons.settings_ethernet,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildHizliIstatistikler(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    VoidCallback bekleyenBelgeleriGoster,
  ) {
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
                Text(
                  'Senkronizasyon İstatistikleri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                  ),
                  child: Text(
                    'Anlık',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _pcPlatform
                ? _buildPCIstatistikler(
                  context,
                  yonetici,
                  bekleyenBelgeleriGoster,
                )
                : _buildMobileIstatistikler(
                  context,
                  yonetici,
                  bekleyenBelgeleriGoster,
                ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPCIstatistikler(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    VoidCallback bekleyenBelgeleriGoster,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTiklanabilirStatItem(
            context,
            'Bekleyen',
            '${yonetici.bekleyenDosyaSayisi}',
            Icons.schedule,
            bekleyenBelgeleriGoster,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            context,
            'Senkronize',
            '${yonetici.senkronizeDosyaSayisi}',
            Icons.check_circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            context,
            'Toplam',
            '${yonetici.bekleyenDosyaSayisi + yonetici.senkronizeDosyaSayisi}',
            Icons.folder,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatItem(
            context,
            'Son Senkron',
            yonetici.sonSenkronizasyon,
            Icons.access_time,
          ),
        ),
      ],
    );
  }

  static Widget _buildMobileIstatistikler(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    VoidCallback bekleyenBelgeleriGoster,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTiklanabilirStatItem(
                context,
                'Bekleyen',
                '${yonetici.bekleyenDosyaSayisi}',
                Icons.schedule,
                bekleyenBelgeleriGoster,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                context,
                'Senkronize',
                '${yonetici.senkronizeDosyaSayisi}',
                Icons.check_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                'Toplam',
                '${yonetici.bekleyenDosyaSayisi + yonetici.senkronizeDosyaSayisi}',
                Icons.folder,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                context,
                'Son Senkron',
                yonetici.sonSenkronizasyon,
                Icons.access_time,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  static Widget _buildTiklanabilirStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
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
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: Colors.orange[600]),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[800],
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 12, color: Colors.orange[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Tıkla',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildSenkronizasyonGecmisi(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
  ) {
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
                Icon(Icons.history, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Senkronizasyon Geçmişi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    'Anlık',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: yonetici.getSenkronizasyonGecmisi(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildGecmisItem(
                    context,
                    'Geçmiş yüklenemedi',
                    'Veri alınırken hata oluştu',
                    Icons.error,
                    Colors.red,
                  );
                }

                final gecmis = snapshot.data ?? [];

                if (gecmis.isEmpty) {
                  return _buildGecmisItem(
                    context,
                    'Henüz senkronizasyon yapılmamış',
                    'İlk senkronizasyon için cihaz bağlayın',
                    Icons.info,
                    Colors.blue,
                  );
                }

                return Column(
                  children:
                      gecmis.take(3).map((item) {
                        final tip = item['tip'] ?? 'bilinmiyor';
                        final mesaj = item['mesaj'] ?? 'Bilinmeyen işlem';
                        final zaman = item['zaman'] ?? 'Bilinmeyen zaman';

                        IconData icon;
                        Color color;

                        switch (tip) {
                          case 'basarili':
                            icon = Icons.check_circle;
                            color = Colors.green;
                            break;
                          case 'baglanti':
                            icon = Icons.link;
                            color = Colors.blue;
                            break;
                          case 'dosya':
                            icon = Icons.sync;
                            color = Colors.orange;
                            break;
                          case 'hata':
                            icon = Icons.error;
                            color = Colors.red;
                            break;
                          default:
                            icon = Icons.info;
                            color = Colors.grey;
                        }

                        return _buildGecmisItem(
                          context,
                          mesaj,
                          zaman,
                          icon,
                          color,
                        );
                      }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildGecmisItem(
    BuildContext context,
    String baslik,
    String zaman,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                Text(
                  zaman,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bekleyen senkronizasyon belgelerini göster
  static Widget buildBekleyenBelgeler(
    BuildContext context,
    List<BelgeModeli> bekleyenBelgeler,
    Function(List<BelgeModeli>) onBelgeleriGonder,
    SenkronizasyonYoneticiServisi yonetici,
  ) {
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
                Icon(Icons.sync_problem, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bekleyen Belgeler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${bekleyenBelgeler.length}',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bekleyenBelgeler.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tüm belgeler senkronize! 🎉',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bekleyenBelgeler.length,
                  itemBuilder: (context, index) {
                    final belge = bekleyenBelgeler[index];
                    return _buildBekleyenBelgeItem(context, belge, index);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          () => _belgelerGonderProgressIle(
                            context,
                            bekleyenBelgeler,
                            yonetici,
                            onBelgeleriGonder,
                          ),
                      icon: const Icon(Icons.send, size: 16),
                      label: Text(
                        'Tümü (${bekleyenBelgeler.length})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Seçili belgeleri gönder dialog'u
                        _showSeciliBelgeleriGonderDialog(
                          context,
                          bekleyenBelgeler,
                          onBelgeleriGonder,
                        );
                      },
                      icon: const Icon(Icons.checklist, size: 16),
                      label: const Text(
                        'Seç',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[600],
                        side: BorderSide(color: Colors.orange[600]!),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildBekleyenBelgeItem(
    BuildContext context,
    BelgeModeli belge,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(belge.dosyaTipi),
              color: Colors.orange[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  belge.orijinalDosyaAdi,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${belge.formatliDosyaBoyutu} • ${belge.zamanFarki}',
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
              color: _getSenkronDurumuColor(belge.senkronDurumu),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getSenkronDurumuText(belge.senkronDurumu),
              style: const TextStyle(
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

  static IconData _getFileIcon(String dosyaTipi) {
    switch (dosyaTipi.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color _getSenkronDurumuColor(SenkronDurumu durum) {
    switch (durum) {
      case SenkronDurumu.SENKRONIZE:
        return Colors.green;
      case SenkronDurumu.BEKLEMEDE:
        return Colors.orange;
      case SenkronDurumu.YEREL_DEGISIM:
        return Colors.blue;
      case SenkronDurumu.CAKISMA:
        return Colors.red;
      case SenkronDurumu.HATA:
        return Colors.red[800]!;
      case SenkronDurumu.UZAK_DEGISIM:
        return Colors.purple;
    }
  }

  static String _getSenkronDurumuText(SenkronDurumu durum) {
    switch (durum) {
      case SenkronDurumu.SENKRONIZE:
        return 'Senkronize';
      case SenkronDurumu.BEKLEMEDE:
        return 'Beklemede';
      case SenkronDurumu.YEREL_DEGISIM:
        return 'Yeni';
      case SenkronDurumu.CAKISMA:
        return 'Çakışma';
      case SenkronDurumu.HATA:
        return 'Hata';
      case SenkronDurumu.UZAK_DEGISIM:
        return 'Uzak';
    }
  }

  static void _showSeciliBelgeleriGonderDialog(
    BuildContext context,
    List<BelgeModeli> tumBelgeler,
    Function(List<BelgeModeli>) onBelgeleriGonder,
  ) {
    final secilenBelgeler = <BelgeModeli>[];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: 400,
                    height: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.checklist, color: Colors.orange[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Seçili Belgeleri Gönder',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Select all button
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            if (secilenBelgeler.length ==
                                                tumBelgeler.length) {
                                              secilenBelgeler.clear();
                                            } else {
                                              secilenBelgeler.clear();
                                              secilenBelgeler.addAll(
                                                tumBelgeler,
                                              );
                                            }
                                          });
                                        },
                                        icon: Icon(
                                          secilenBelgeler.length ==
                                                  tumBelgeler.length
                                              ? Icons.deselect
                                              : Icons.select_all,
                                        ),
                                        label: Text(
                                          secilenBelgeler.length ==
                                                  tumBelgeler.length
                                              ? 'Tümünü Kaldır'
                                              : 'Tümünü Seç',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // File list
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListView.builder(
                                      itemCount: tumBelgeler.length,
                                      itemBuilder: (context, index) {
                                        final belge = tumBelgeler[index];
                                        final secilimi = secilenBelgeler
                                            .contains(belge);

                                        return Container(
                                          decoration: BoxDecoration(
                                            border:
                                                index > 0
                                                    ? Border(
                                                      top: BorderSide(
                                                        color:
                                                            Colors.grey[200]!,
                                                        width: 1,
                                                      ),
                                                    )
                                                    : null,
                                          ),
                                          child: CheckboxListTile(
                                            value: secilimi,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  secilenBelgeler.add(belge);
                                                } else {
                                                  secilenBelgeler.remove(belge);
                                                }
                                              });
                                            },
                                            title: Text(
                                              belge.orijinalDosyaAdi,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              belge.formatliDosyaBoyutu,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            secondary: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _getFileIcon(belge.dosyaTipi),
                                                color: Colors.orange[600],
                                                size: 20,
                                              ),
                                            ),
                                            dense: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Selected count
                              Expanded(
                                child: Text(
                                  '${secilenBelgeler.length} / ${tumBelgeler.length} belge seçildi',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Actions
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('İptal'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed:
                                    secilenBelgeler.isNotEmpty
                                        ? () {
                                          Navigator.pop(context);
                                          onBelgeleriGonder(secilenBelgeler);
                                        }
                                        : null,
                                icon: const Icon(Icons.send),
                                label: Text(
                                  'Gönder (${secilenBelgeler.length})',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // Progress dialog ile belge gönder
  static Future<void> _belgelerGonderProgressIle(
    BuildContext context,
    List<BelgeModeli> belgeler,
    SenkronizasyonYoneticiServisi yonetici,
    Function(List<BelgeModeli>) onBelgeleriGonder,
  ) async {
    try {
      // Bağlı cihazları kontrol et
      if (yonetici.bagliCihazlar.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Henüz bağlı cihaz yok! Önce bir cihaz bağlayın.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // İlk bağlı cihazı al
      final hedefCihaz = yonetici.bagliCihazlar.first;
      final hedefIP = hedefCihaz['ip'] as String;

      // Progress stream oluştur
      final progressStream = yonetici.createProgressStream();

      // Progress dialog'u göster
      showSenkronizasyonProgressDialog(
        context,
        progressStream,
        onTamam: () {
          // Başarılı tamamlandığında UI'yi güncelle
          onBelgeleriGonder(belgeler);
        },
        onIptal: () {
          // İptal edildiğinde gerekli cleanup
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senkronizasyon iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      );

      // Senkronizasyonu başlat
      await yonetici.belgeleriSenkronEtProgress(hedefIP, belgeler: belgeler);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Senkronizasyon hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
