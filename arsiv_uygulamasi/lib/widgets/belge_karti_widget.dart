import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../services/veritabani_servisi.dart';

class BelgeKartiWidget extends StatefulWidget {
  final BelgeModeli belge;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onAc;
  final VoidCallback onPaylas;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;

  const BelgeKartiWidget({
    Key? key,
    required this.belge,
    required this.onTap,
    required this.onLongPress,
    required this.onAc,
    required this.onPaylas,
    required this.onDuzenle,
    required this.onSil,
  }) : super(key: key);

  @override
  State<BelgeKartiWidget> createState() => _BelgeKartiWidgetState();
}

class _BelgeKartiWidgetState extends State<BelgeKartiWidget> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  String? _kisiAdi;

  @override
  void initState() {
    super.initState();
    _kisiAdiniYukle();
  }

  Future<void> _kisiAdiniYukle() async {
    if (widget.belge.kisiId != null) {
      try {
        final kisi = await _veriTabani.kisiGetir(widget.belge.kisiId!);
        if (kisi != null && mounted) {
          setState(() {
            _kisiAdi = kisi.ad;
          });
        }
      } catch (e) {
        // Hata durumunda sessizce devam et
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Ana belge bilgileri
          InkWell(
            onTap: widget.onTap,
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
                      color: _senkronDurumuRenk(
                        widget.belge.senkronDurumu,
                      ).withOpacity(0.1),
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
                        Row(
                          children: [
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.belge.dosyaTipi.toUpperCase().length >
                                          4
                                      ? widget.belge.dosyaTipi
                                          .toUpperCase()
                                          .substring(0, 4)
                                      : widget.belge.dosyaTipi.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.belge.formatliDosyaBoyutu,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Zaman bilgisi
                        Text(
                          widget.belge.zamanFarki,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),

                        // Kişi bilgisi (varsa)
                        if (_kisiAdi != null && _kisiAdi!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _kisiAdi!,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Etiketler (varsa)
                        if (widget.belge.etiketler != null &&
                            widget.belge.etiketler!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                                widget.belge.etiketler!.take(3).map((etiket) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],

                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      etiket,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],

                        // Açıklama (varsa)
                        if (widget.belge.aciklama != null &&
                            widget.belge.aciklama!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.belge.aciklama!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Üç nokta menüsü
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'open') {
                        widget.onAc();
                      } else if (value == 'share') {
                        widget.onPaylas();
                      } else if (value == 'edit') {
                        widget.onDuzenle();
                      } else if (value == 'delete') {
                        widget.onSil();
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem<String>(
                            value: 'open',
                            child: Text('Aç'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'share',
                            child: Text('Paylaş'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Düzenle'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Sil'),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ),
          // Senkronizasyon durumu göstergesi (sadece senkronize ediliyorsa)
          if (widget.belge.senkronDurumu == 1) // Senkronize ediliyor
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Senkronize Ediliyor...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _senkronDurumuIcon(SenkronDurumu durum) {
    switch (durum) {
      case SenkronDurumu.SENKRONIZE:
        return Icons.check_circle;
      case SenkronDurumu.BEKLEMEDE:
        return Icons.schedule;
      case SenkronDurumu.CAKISMA:
        return Icons.warning;
      case SenkronDurumu.HATA:
        return Icons.error;
      case SenkronDurumu.YEREL_DEGISIM:
        return Icons.upload;
      case SenkronDurumu.UZAK_DEGISIM:
        return Icons.download;
    }
  }

  Color _senkronDurumuRenk(SenkronDurumu durum) {
    switch (durum) {
      case SenkronDurumu.SENKRONIZE:
        return Colors.green;
      case SenkronDurumu.BEKLEMEDE:
        return Colors.orange;
      case SenkronDurumu.CAKISMA:
        return Colors.red;
      case SenkronDurumu.HATA:
        return Colors.red;
      case SenkronDurumu.YEREL_DEGISIM:
        return Colors.blue;
      case SenkronDurumu.UZAK_DEGISIM:
        return Colors.purple;
    }
  }
}
