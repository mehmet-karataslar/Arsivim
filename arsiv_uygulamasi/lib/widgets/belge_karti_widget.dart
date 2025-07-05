import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../utils/screen_utils.dart';
import '../services/belge_islemleri_servisi.dart';

class OptimizedBelgeKartiWidget extends StatefulWidget {
  final BelgeModeli belge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAc;
  final VoidCallback? onPaylas;
  final VoidCallback? onDuzenle;
  final VoidCallback? onSil;
  final bool compactMode;

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
            subtitle: _buildSubtitle(),
            onTap:
                widget.onTap ??
                () => _belgeIslemleri.belgeAc(widget.belge, context),
            onLongPress: widget.onLongPress,
          ),
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
              child: Row(
                children: [
                  // Dosya ikonu
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                          widget.belge.baslik ?? widget.belge.orijinalDosyaAdi,
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
        color: Theme.of(context).primaryColor.withOpacity(0.1),
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

  Widget _buildSubtitle() {
    return Text(
      '${widget.belge.dosyaTipi.toUpperCase()} • ${widget.belge.formatliDosyaBoyutu}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.grey[600],
        fontSize: widget.compactMode ? 12 : 14,
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

  void _belgeDuzenle(BuildContext context) {
    // Belge düzenleme sayfasına git
    Navigator.pushNamed(context, '/belge-duzenle', arguments: widget.belge);
  }
}
