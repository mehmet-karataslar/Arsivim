import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/veritabani_servisi.dart';
import '../utils/screen_utils.dart';
import 'belge_karti_widget.dart';
import 'belge_detay_dialog.dart';

enum AramaSiralamaTuru { tarihYeni, tarihEski }

enum AramaGorunumTuru { liste, kompakt }

class AramaSonuclariWidget extends StatelessWidget {
  final List<BelgeModeli> belgeler;
  final List<Map<String, dynamic>>? detayliBelgeler;
  final List<KategoriModeli> kategoriler;
  final List<KisiModeli> kisiler;
  final AramaSiralamaTuru siralamaTuru;
  final AramaGorunumTuru gorunumTuru;
  final Function(AramaSiralamaTuru) onSiralamaSecildi;
  final Function(AramaGorunumTuru) onGorunumSecildi;
  final Function(BelgeModeli)? onBelgeDuzenle;
  final Function()? onBelgelerGuncellendi;
  final bool yukleniyor;
  final String? hata;

  final int? secilenAy;
  final int? secilenYil;
  final Function(int?, int?)? onAyYilSecimi;

  const AramaSonuclariWidget({
    Key? key,
    required this.belgeler,
    this.detayliBelgeler,
    required this.kategoriler,
    required this.kisiler,
    required this.siralamaTuru,
    required this.gorunumTuru,
    required this.onSiralamaSecildi,
    required this.onGorunumSecildi,
    this.onBelgeDuzenle,
    this.onBelgelerGuncellendi,
    this.yukleniyor = false,
    this.hata,
    this.secilenAy,
    this.secilenYil,
    this.onAyYilSecimi,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildIcerik(),
      ),
    );
  }

  Widget _buildIcerik() {
    if (yukleniyor) {
      return _buildYukleniyorDurumu();
    }

    if (hata != null) {
      return _buildHataDurumu();
    }

    if (belgeler.isEmpty) {
      return _buildBosDurum();
    }

    return _buildBelgelerListesi();
  }

  Widget _buildYukleniyorDurumu() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.purple[400]!],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.blue[600]!, Colors.purple[600]!],
                  ).createShader(bounds),
              child: const Text(
                'Belgeler aranıyor...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHataDurumu() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[300]!, Colors.pink[300]!],
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 35,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arama Hatası',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Text(
                hata!,
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 13,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBosDurum() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[300]!, Colors.grey[400]!],
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sonuç Bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Arama kriterlerinize uygun belge bulunamadı.\nFiltreleri değiştirmeyi deneyin.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBelgelerListesi() {
    final siraliBegleler = _belgelerSirala(belgeler);

    switch (gorunumTuru) {
      case AramaGorunumTuru.liste:
        return _buildListeGorunumu(siraliBegleler);
      case AramaGorunumTuru.kompakt:
        return _buildKompaktGorunumu(siraliBegleler);
    }
  }

  Widget _buildListeGorunumu(List<BelgeModeli> belgeler) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: belgeler.length,
      itemBuilder: (context, index) {
        final belge = belgeler[index];

        Map<String, dynamic>? extraData;
        if (detayliBelgeler != null && index < detayliBelgeler!.length) {
          extraData = detayliBelgeler![index];
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: OptimizedBelgeKartiWidget(
            belge: belge,
            extraData: extraData,
            onTap: () => _belgeDetayGoster(context, belge),
            onLongPress: () => _belgeDetayGoster(context, belge),
            onAc: () => _belgeAc(context, belge),
            onPaylas: () => _belgePaylas(context, belge),
            onDuzenle: () => _belgeDuzenle(context, belge),
            onSil: () => _belgeSil(context, belge),
            compactMode: true,
          ),
        );
      },
    );
  }

  Widget _buildKompaktGorunumu(List<BelgeModeli> belgeler) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: belgeler.length,
      itemBuilder: (context, index) {
        final belge = belgeler[index];
        final kategori = _getKategori(belge.kategoriId);
        final kisi = _getKisi(belge.kisiId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _belgeDetayGoster(context, belge),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Modern dosya ikonu
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.indigo[400]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Belge bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Başlık ve tarih
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  belge.baslik ?? belge.dosyaAdi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
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
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[100]!,
                                      Colors.grey[200]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatTarih(belge.olusturmaTarihi),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Kategori, kişi ve boyut
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (kategori != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue[100]!,
                                        Colors.blue[200]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    kategori.kategoriAdi,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (kisi != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green[100]!,
                                        Colors.green[200]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    kisi.tamAd,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange[100]!,
                                      Colors.orange[200]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatBoyut(belge.dosyaBoyutu),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Modern aksiyon butonları
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAksiyonButonu(
                              icon: Icons.open_in_new_rounded,
                              gradient: [Colors.blue[400]!, Colors.blue[600]!],
                              onTap: () => _belgeAc(context, belge),
                            ),
                            const SizedBox(width: 3),
                            _buildAksiyonButonu(
                              icon: Icons.share_rounded,
                              gradient: [
                                Colors.green[400]!,
                                Colors.green[600]!,
                              ],
                              onTap: () => _belgePaylas(context, belge),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAksiyonButonu(
                              icon: Icons.edit_rounded,
                              gradient: [
                                Colors.orange[400]!,
                                Colors.orange[600]!,
                              ],
                              onTap: () => _belgeDuzenle(context, belge),
                            ),
                            const SizedBox(width: 3),
                            _buildAksiyonButonu(
                              icon: Icons.delete_rounded,
                              gradient: [Colors.red[400]!, Colors.red[600]!],
                              onTap: () => _belgeSil(context, belge),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAksiyonButonu({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  List<BelgeModeli> _belgelerSirala(List<BelgeModeli> belgeler) {
    final liste = List<BelgeModeli>.from(belgeler);

    switch (siralamaTuru) {
      case AramaSiralamaTuru.tarihYeni:
        liste.sort((a, b) => b.olusturmaTarihi.compareTo(a.olusturmaTarihi));
        break;
      case AramaSiralamaTuru.tarihEski:
        liste.sort((a, b) => a.olusturmaTarihi.compareTo(b.olusturmaTarihi));
        break;
    }

    return liste;
  }

  KategoriModeli? _getKategori(int? kategoriId) {
    if (kategoriId == null) return null;
    try {
      return kategoriler.firstWhere((k) => k.id == kategoriId);
    } catch (e) {
      return null;
    }
  }

  KisiModeli? _getKisi(int? kisiId) {
    if (kisiId == null) return null;
    try {
      return kisiler.firstWhere((k) => k.id == kisiId);
    } catch (e) {
      return null;
    }
  }

  void _belgeDetayGoster(BuildContext context, BelgeModeli belge) {
    showDialog(
      context: context,
      builder:
          (context) => BelgeDetayDialog(
            belge: belge,
            kategori: _getKategori(belge.kategoriId),
            kisi: _getKisi(belge.kisiId),
            onDuzenle:
                onBelgeDuzenle != null
                    ? () {
                      Navigator.of(context).pop();
                      onBelgeDuzenle!(belge);
                    }
                    : null,
          ),
    );
  }

  void _belgeAc(BuildContext context, BelgeModeli belge) async {
    try {
      final belgeIslemleri = BelgeIslemleriServisi();
      await belgeIslemleri.belgeAc(belge, context);
    } catch (e) {
      _hataGoster(context, 'Belge açılırken hata oluştu: $e');
    }
  }

  void _belgePaylas(BuildContext context, BelgeModeli belge) async {
    try {
      final belgeIslemleri = BelgeIslemleriServisi();
      await belgeIslemleri.belgePaylas(belge, context);
    } catch (e) {
      _hataGoster(context, 'Belge paylaşılırken hata oluştu: $e');
    }
  }

  void _belgeDuzenle(BuildContext context, BelgeModeli belge) {
    if (onBelgeDuzenle != null) {
      onBelgeDuzenle!(belge);
    }
  }

  void _belgeSil(BuildContext context, BelgeModeli belge) async {
    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Belge Sil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              '${belge.baslik ?? belge.dosyaAdi} belgesi kalıcı olarak silinsin mi?',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[400]!, Colors.red[600]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Sil',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
    );

    if (onay == true) {
      try {
        final veriTabani = VeriTabaniServisi();
        await veriTabani.belgeSil(belge.id!);

        if (onBelgelerGuncellendi != null) {
          onBelgelerGuncellendi!();
        }

        _basariMesajiGoster(context, 'Belge başarıyla silindi');
      } catch (e) {
        _hataGoster(context, 'Belge silinirken hata oluştu: $e');
      }
    }
  }

  void _hataGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _basariMesajiGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatBoyut(int boyut) {
    if (boyut < 1024) return '$boyut B';
    if (boyut < 1024 * 1024) return '${(boyut / 1024).toStringAsFixed(1)} KB';
    if (boyut < 1024 * 1024 * 1024) {
      return '${(boyut / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(boyut / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTarih(DateTime tarih) {
    final simdi = DateTime.now();
    final fark = simdi.difference(tarih);

    if (fark.inDays == 0) {
      return '${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}';
    } else if (fark.inDays == 1) {
      return 'Dün';
    } else if (fark.inDays < 7) {
      return '${fark.inDays} gün önce';
    } else {
      return '${tarih.day}/${tarih.month}/${tarih.year}';
    }
  }
}
