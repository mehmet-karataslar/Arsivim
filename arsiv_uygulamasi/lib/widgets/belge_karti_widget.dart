import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../utils/screen_utils.dart';
import '../services/belge_islemleri_servisi.dart';
import '../utils/yardimci_fonksiyonlar.dart';

class OptimizedBelgeKartiWidget extends StatefulWidget {
  final BelgeModeli belge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAc;
  final VoidCallback? onPaylas;
  final VoidCallback? onDuzenle;
  final VoidCallback? onSil;
  final bool compactMode;
  final Map<String, dynamic>? extraData; // Kategori, kişi bilgileri için

  const OptimizedBelgeKartiWidget({
    Key? key,
    required this.belge,
    this.onTap,
    this.onLongPress,
    this.onAc,
    this.onPaylas,
    this.onDuzenle,
    this.onSil,
    this.compactMode = false,
    this.extraData,
  }) : super(key: key);

  @override
  State<OptimizedBelgeKartiWidget> createState() =>
      _OptimizedBelgeKartiWidgetState();
}

class _OptimizedBelgeKartiWidgetState extends State<OptimizedBelgeKartiWidget> {
  final BelgeIslemleriServisi _belgeIslemleri = BelgeIslemleriServisi();

  @override
  Widget build(BuildContext context) {
    if (widget.compactMode) {
      return _buildCompactCard();
    } else {
      return _buildFullCard();
    }
  }

  Widget _buildCompactCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ana belge bilgileri
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _buildLeading(),
            title: _buildTitle(),
            subtitle: _buildCompactSubtitle(),
            onTap:
                widget.onTap ??
                () => _belgeIslemleri.belgeAc(widget.belge, context),
            onLongPress: widget.onLongPress,
          ),

          // Kategori, kişi ve etiket bilgileri
          if (_hasExtraInfo()) _buildExtraInfoSection(),

          // Aksiyon butonları
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Aç butonu
                _buildCompactActionButton(
                  icon: Icons.open_in_new,
                  label: 'Aç',
                  color: Colors.blue,
                  onTap:
                      widget.onAc ??
                      () => _belgeIslemleri.belgeAc(widget.belge, context),
                ),

                // Paylaş butonu
                _buildCompactActionButton(
                  icon: Icons.share,
                  label: 'Paylaş',
                  color: Colors.green,
                  onTap:
                      widget.onPaylas ??
                      () => _belgeIslemleri.belgePaylas(widget.belge, context),
                ),

                // Düzenle butonu
                _buildCompactActionButton(
                  icon: Icons.edit,
                  label: 'Düzenle',
                  color: Colors.orange,
                  onTap: widget.onDuzenle ?? () => _belgeDuzenle(context),
                ),

                // Sil butonu
                _buildCompactActionButton(
                  icon: Icons.delete,
                  label: 'Sil',
                  color: Colors.red,
                  onTap:
                      widget.onSil ??
                      () => _belgeIslemleri.belgeSil(widget.belge, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Ana belge bilgileri
          InkWell(
            onTap:
                widget.onTap ??
                () => _belgeIslemleri.belgeAc(widget.belge, context),
            onLongPress: widget.onLongPress,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Dosya ikonu
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getKategoriRengi().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            widget.belge.dosyaTipiSimgesi,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Belge bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Başlık
                            Text(
                              widget.belge.baslik ??
                                  widget.belge.orijinalDosyaAdi,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Dosya tipi ve boyut
                            Text(
                              '${widget.belge.dosyaTipi.toUpperCase()} • ${widget.belge.formatliDosyaBoyutu}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),

                            // Zaman bilgisi
                            Text(
                              widget.belge.zamanFarki,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Kategori, kişi ve etiket bilgileri
                  if (_hasExtraInfo()) ...[
                    const SizedBox(height: 12),
                    _buildExtraInfoSection(),
                  ],
                ],
              ),
            ),
          ),

          // Aksiyon butonları
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Aç butonu
                _buildActionButton(
                  icon: Icons.open_in_new,
                  label: 'Aç',
                  color: Colors.blue,
                  onTap:
                      widget.onAc ??
                      () => _belgeIslemleri.belgeAc(widget.belge, context),
                ),

                // Paylaş butonu
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Paylaş',
                  color: Colors.green,
                  onTap:
                      widget.onPaylas ??
                      () => _belgeIslemleri.belgePaylas(widget.belge, context),
                ),

                // Düzenle butonu
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Düzenle',
                  color: Colors.orange,
                  onTap: widget.onDuzenle ?? () => _belgeDuzenle(context),
                ),

                // Sil butonu
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Sil',
                  color: Colors.red,
                  onTap:
                      widget.onSil ??
                      () => _belgeIslemleri.belgeSil(widget.belge, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    return Container(
      padding: EdgeInsets.all(widget.compactMode ? 8 : 12),
      decoration: BoxDecoration(
        color: _getKategoriRengi().withOpacity(0.1),
        borderRadius: BorderRadius.circular(widget.compactMode ? 6 : 10),
      ),
      child: Text(
        widget.belge.dosyaTipiSimgesi,
        style: TextStyle(fontSize: widget.compactMode ? 16 : 20),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.belge.baslik ?? widget.belge.orijinalDosyaAdi,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: widget.compactMode ? 14 : 16,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCompactSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.belge.dosyaTipi.toUpperCase()} • ${widget.belge.formatliDosyaBoyutu}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: widget.compactMode ? 12 : 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.belge.zamanFarki,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: widget.compactMode ? 11 : 13,
          ),
        ),
      ],
    );
  }

  Widget _buildExtraInfoSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kategori bilgisi
          if (_getKategoriAdi() != null) ...[
            Row(
              children: [
                Icon(Icons.category, size: 16, color: _getKategoriRengi()),
                const SizedBox(width: 4),
                Text(
                  _getKategoriAdi()!,
                  style: TextStyle(
                    fontSize: widget.compactMode ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    color: _getKategoriRengi(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Kişi bilgisi
          if (_getKisiAdi() != null) ...[
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _getKisiAdi()!,
                  style: TextStyle(
                    fontSize: widget.compactMode ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Etiketler
          if (_getEtiketler().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.label, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children:
                        _getEtiketler().map((etiket) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              etiket,
                              style: TextStyle(
                                fontSize: widget.compactMode ? 10 : 11,
                                color: Colors.blue[700],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrailing() {
    return Icon(
      Icons.arrow_forward_ios_rounded,
      size: 16,
      color: Colors.grey[400],
    );
  }

  // Aksiyon butonları için widget builder
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kompakt mod için aksiyon butonları
  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yardımcı metodlar
  bool _hasExtraInfo() {
    return _getKategoriAdi() != null ||
        _getKisiAdi() != null ||
        _getEtiketler().isNotEmpty;
  }

  String? _getKategoriAdi() {
    return widget.extraData?['kategori_adi'];
  }

  String? _getKisiAdi() {
    final ad = widget.extraData?['kisi_ad'];
    final soyad = widget.extraData?['kisi_soyad'];
    if (ad != null && soyad != null) {
      return '$ad $soyad';
    }
    return null;
  }

  List<String> _getEtiketler() {
    if (widget.belge.etiketler != null && widget.belge.etiketler!.isNotEmpty) {
      return widget.belge.etiketler!;
    }
    return [];
  }

  Color _getKategoriRengi() {
    final renkKodu = widget.extraData?['renk_kodu'];
    if (renkKodu != null) {
      try {
        return Color(int.parse(renkKodu.replaceFirst('#', '0xFF')));
      } catch (e) {
        return Theme.of(context).primaryColor;
      }
    }
    return Theme.of(context).primaryColor;
  }

  void _belgeDuzenle(BuildContext context) {
    // Belge düzenleme sayfasına git
    Navigator.pushNamed(context, '/belge-duzenle', arguments: widget.belge);
  }
}
