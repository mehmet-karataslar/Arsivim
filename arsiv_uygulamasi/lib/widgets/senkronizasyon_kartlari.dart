import 'package:flutter/material.dart';
import 'dart:io';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
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
    VoidCallback bekleyenBelgeleriGoster, {
    List<BelgeModeli>? bekleyenBelgeler,
    List<KisiModeli>? bekleyenKisiler,
    List<KategoriModeli>? bekleyenKategoriler,
    VoidCallback? bekleyenKisileriGoster,
    VoidCallback? bekleyenKategorileriGoster,
  }) {
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
                  bekleyenBelgeler: bekleyenBelgeler,
                  bekleyenKisiler: bekleyenKisiler,
                  bekleyenKategoriler: bekleyenKategoriler,
                  bekleyenKisileriGoster: bekleyenKisileriGoster,
                  bekleyenKategorileriGoster: bekleyenKategorileriGoster,
                )
                : _buildMobileIstatistikler(
                  context,
                  yonetici,
                  bekleyenBelgeleriGoster,
                  bekleyenBelgeler: bekleyenBelgeler,
                  bekleyenKisiler: bekleyenKisiler,
                  bekleyenKategoriler: bekleyenKategoriler,
                  bekleyenKisileriGoster: bekleyenKisileriGoster,
                  bekleyenKategorileriGoster: bekleyenKategorileriGoster,
                ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPCIstatistikler(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    VoidCallback bekleyenBelgeleriGoster, {
    List<BelgeModeli>? bekleyenBelgeler,
    List<KisiModeli>? bekleyenKisiler,
    List<KategoriModeli>? bekleyenKategoriler,
    VoidCallback? bekleyenKisileriGoster,
    VoidCallback? bekleyenKategorileriGoster,
  }) {
    final bekleyenBelgeSayisi =
        bekleyenBelgeler?.length ?? yonetici.bekleyenDosyaSayisi;

    return Column(
      children: [
        // Sadece belgeler ve senkronize bilgisi gösterilir
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTiklanabilirStatItem(
                context,
                'Bekleyen Belgeler',
                '$bekleyenBelgeSayisi',
                Icons.description,
                bekleyenBelgeleriGoster,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                context,
                'Senkronize Belgeler',
                '${yonetici.senkronizeDosyaSayisi}',
                Icons.check_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bilgilendirme kartı
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kişiler ve kategoriler belgelerle birlikte otomatik senkronize edilir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildMobileIstatistikler(
    BuildContext context,
    SenkronizasyonYoneticiServisi yonetici,
    VoidCallback bekleyenBelgeleriGoster, {
    List<BelgeModeli>? bekleyenBelgeler,
    List<KisiModeli>? bekleyenKisiler,
    List<KategoriModeli>? bekleyenKategoriler,
    VoidCallback? bekleyenKisileriGoster,
    VoidCallback? bekleyenKategorileriGoster,
  }) {
    final bekleyenBelgeSayisi =
        bekleyenBelgeler?.length ?? yonetici.bekleyenDosyaSayisi;

    return Column(
      children: [
        // Sadece belgeler ve senkronize bilgisi gösterilir
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildTiklanabilirStatItem(
                context,
                'Bekleyen Belgeler',
                '$bekleyenBelgeSayisi',
                Icons.description,
                bekleyenBelgeleriGoster,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatItem(
                context,
                'Senkronize Belgeler',
                '${yonetici.senkronizeDosyaSayisi}',
                Icons.check_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bilgilendirme kartı
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kişiler ve kategoriler belgelerle birlikte otomatik senkronize edilir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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

  // Bekleyen senkronizasyon belgelerini göster
  static Widget buildBekleyenBelgeler(
    BuildContext context,
    List<BelgeModeli> bekleyenBelgeler,
    Function(List<BelgeModeli>) onBelgeleriGonder,
    SenkronizasyonYoneticiServisi yonetici,
  ) {
    if (bekleyenBelgeler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tüm belgeler senkronize!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Şu anda senkronizasyon bekleyen belge yok.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Üst bilgi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${bekleyenBelgeler.length} belge senkronizasyon bekliyor',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Belgeler listesi
        ...bekleyenBelgeler.map((belge) => _buildBelgeItem(context, belge)),
        const SizedBox(height: 16),
        // Aksiyon butonları
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    yonetici.bagliCihazlar.isNotEmpty
                        ? () => onBelgeleriGonder(bekleyenBelgeler)
                        : null,
                icon: const Icon(Icons.sync),
                label: const Text('Tümünü Senkronize Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Kişi senkronizasyonu build fonksiyonu
  static Widget buildBekleyenKisiler(
    BuildContext context,
    List<KisiModeli> kisiler,
    Function(List<KisiModeli>) onKisileriGonder,
    SenkronizasyonYoneticiServisi yonetici,
  ) {
    if (kisiler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Senkronizasyon bekleyen kişi yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni eklenen kişiler burada görünecek',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.blue[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${kisiler.length} kişi senkronizasyon bekliyor',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content - Sabit yükseklik ile
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: kisiler.length,
            itemBuilder: (context, index) {
              final kisi = kisiler[index];

              return Container(
                decoration: BoxDecoration(
                  border:
                      index > 0
                          ? Border(
                            top: BorderSide(color: Colors.grey[200]!, width: 1),
                          )
                          : null,
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${kisi.ad} ${kisi.soyad}',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    kisi.kullaniciAdi ?? 'Kullanıcı adı yok',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    // Kişi detaylarını göster
                    _showKisiDetay(context, kisi);
                  },
                ),
              );
            },
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
          child: Column(
            children: [
              // İstatistik
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kisiler.length} kişi hazır',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          yonetici.bagliCihazlar.isNotEmpty
                              ? () {
                                Navigator.pop(context);
                                onKisileriGonder(kisiler);
                              }
                              : null,
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Gönder (${kisiler.length})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Kişi detaylarını göster
  static void _showKisiDetay(BuildContext context, KisiModeli kisi) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${kisi.ad} ${kisi.soyad}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ad: ${kisi.ad}'),
                Text('Soyad: ${kisi.soyad}'),
                Text('Kullanıcı Adı: ${kisi.kullaniciAdi ?? 'Belirtilmemiş'}'),
                Text('Oluşturulma Tarihi: ${kisi.formatliOlusturmaTarihi}'),
                Text('Güncelleme Tarihi: ${kisi.formatliGuncellemeTarihi}'),
              ],
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

  // Kategori senkronizasyonu build fonksiyonu
  static Widget buildBekleyenKategoriler(
    BuildContext context,
    List<KategoriModeli> kategoriler,
    Function(List<KategoriModeli>) onKategorileriGonder,
    SenkronizasyonYoneticiServisi yonetici,
  ) {
    if (kategoriler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Senkronizasyon bekleyen kategori yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni eklenen kategoriler burada görünecek',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.category, color: Colors.purple[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${kategoriler.length} kategori senkronizasyon bekliyor',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content - Sabit yükseklik ile
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: kategoriler.length,
            itemBuilder: (context, index) {
              final kategori = kategoriler[index];

              return Container(
                decoration: BoxDecoration(
                  border:
                      index > 0
                          ? Border(
                            top: BorderSide(color: Colors.grey[200]!, width: 1),
                          )
                          : null,
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.category,
                      color: Colors.purple[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    kategori.kategoriAdi,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    kategori.aciklama ?? 'Açıklama yok',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () {
                    // Kategori detaylarını göster
                    _showKategoriDetay(context, kategori);
                  },
                ),
              );
            },
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
          child: Column(
            children: [
              // İstatistik
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kategoriler.length} kategori hazır',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          yonetici.bagliCihazlar.isNotEmpty
                              ? () {
                                Navigator.pop(context);
                                onKategorileriGonder(kategoriler);
                              }
                              : null,
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Gönder (${kategoriler.length})',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildBelgeItem(BuildContext context, BelgeModeli belge) {
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
                  belge.dosyaAdi,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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

  static Widget _buildKisiItem(BuildContext context, KisiModeli kisi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person, color: Colors.blue[600], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kisi.tamAd,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${kisi.kullaniciTipi ?? 'Kullanıcı'} • ${kisi.zamanFarki}',
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
              color: kisi.aktif ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              kisi.aktif ? 'Aktif' : 'Pasif',
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

  static Widget _buildKategoriItem(
    BuildContext context,
    KategoriModeli kategori,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.folder, color: Colors.purple[600], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kategori.ad,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${kategori.belgeSayisi ?? 0} belge • ${kategori.zamanFarki}',
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
              color: kategori.aktif ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              kategori.aktif ? 'Aktif' : 'Pasif',
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

  // Kategori detaylarını göster
  static void _showKategoriDetay(
    BuildContext context,
    KategoriModeli kategori,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(kategori.kategoriAdi),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kategori Adı: ${kategori.kategoriAdi}'),
                Text('Açıklama: ${kategori.aciklama ?? 'Belirtilmemiş'}'),
                Text('Oluşturulma Tarihi: ${kategori.formatliOlusturmaTarihi}'),
              ],
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
                          child: Column(
                            children: [
                              // İstatistik
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${secilenBelgeler.length} / ${tumBelgeler.length} belge seçildi',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Butonlar
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('İptal'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          secilenBelgeler.isNotEmpty
                                              ? () {
                                                Navigator.pop(context);
                                                onBelgeleriGonder(
                                                  secilenBelgeler,
                                                );
                                              }
                                              : null,
                                      icon: const Icon(Icons.send, size: 18),
                                      label: Text(
                                        'Gönder (${secilenBelgeler.length})',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
