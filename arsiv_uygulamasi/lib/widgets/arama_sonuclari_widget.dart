import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/veritabani_servisi.dart';
import 'belge_karti_widget.dart';
import 'belge_detay_dialog.dart';
import '../screens/yeni_belge_ekle_ekrani.dart';

enum AramaSiralamaTuru {
  tarihYeni,
  tarihEski,
  adAZ,
  adZA,
  boyutKucuk,
  boyutBuyuk,
}

enum AramaGorunumTuru { liste, grid, kompakt }

class AramaSonuclariWidget extends StatelessWidget {
  final List<BelgeModeli> belgeler;
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

  const AramaSonuclariWidget({
    Key? key,
    required this.belgeler,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve kontroller
          _buildBaslikVeKontroller(),

          // İçerik
          Expanded(child: _buildIcerik()),
        ],
      ),
    );
  }

  Widget _buildBaslikVeKontroller() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Üst satır - başlık ve sonuç sayısı
          Row(
            children: [
              Icon(Icons.search, color: Colors.indigo[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Arama Sonuçları',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              if (!yukleniyor && hata == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${belgeler.length} belge',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo[700],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Alt satır - sıralama ve görünüm kontrolleri
          Row(
            children: [
              // Sıralama dropdown
              Expanded(flex: 2, child: _buildSiralamaDropdown()),
              const SizedBox(width: 12),

              // Görünüm seçici
              _buildGorunumSecici(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiralamaDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AramaSiralamaTuru>(
          value: siralamaTuru,
          onChanged: (value) {
            if (value != null) onSiralamaSecildi(value);
          },
          icon: Icon(Icons.sort, color: Colors.grey[600], size: 16),
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          items: [
            DropdownMenuItem(
              value: AramaSiralamaTuru.tarihYeni,
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.blue[600]),
                  const SizedBox(width: 6),
                  const Text('Yeni → Eski'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AramaSiralamaTuru.tarihEski,
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: Colors.blue[600]),
                  const SizedBox(width: 6),
                  const Text('Eski → Yeni'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AramaSiralamaTuru.adAZ,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  const Text('A → Z'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AramaSiralamaTuru.adZA,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  const Text('Z → A'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AramaSiralamaTuru.boyutKucuk,
              child: Row(
                children: [
                  Icon(
                    Icons.trending_down,
                    size: 14,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(width: 6),
                  const Text('Küçük → Büyük'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AramaSiralamaTuru.boyutBuyuk,
              child: Row(
                children: [
                  Icon(Icons.trending_up, size: 14, color: Colors.orange[600]),
                  const SizedBox(width: 6),
                  const Text('Büyük → Küçük'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGorunumSecici() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGorunumButonu(AramaGorunumTuru.liste, Icons.view_list, 'Liste'),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          _buildGorunumButonu(AramaGorunumTuru.grid, Icons.grid_view, 'Grid'),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          _buildGorunumButonu(
            AramaGorunumTuru.kompakt,
            Icons.view_compact,
            'Kompakt',
          ),
        ],
      ),
    );
  }

  Widget _buildGorunumButonu(
    AramaGorunumTuru tur,
    IconData icon,
    String tooltip,
  ) {
    final secili = gorunumTuru == tur;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onGorunumSecildi(tur),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 16,
            color: secili ? Colors.indigo[600] : Colors.grey[600],
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[600]!),
          ),
          const SizedBox(height: 16),
          Text(
            'Belgeler aranıyor...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHataDurumu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Arama Hatası',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hata!,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBosDurum() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arama kriterlerinize uygun belge bulunamadı.\nFiltreleri değiştirmeyi deneyin.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBelgelerListesi() {
    final siraliBegleler = _belgelerSirala(belgeler);

    switch (gorunumTuru) {
      case AramaGorunumTuru.liste:
        return _buildListeGorunumu(siraliBegleler);
      case AramaGorunumTuru.grid:
        return _buildGridGorunumu(siraliBegleler);
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BelgeKartiWidget(
            belge: belge,
            onTap: () => _belgeDetayGoster(context, belge),
            onLongPress: () => _belgeDetayGoster(context, belge),
            onAc: () => _belgeAc(context, belge),
            onPaylas: () => _belgePaylas(context, belge),
            onDuzenle: () => _belgeDuzenle(context, belge),
            onSil: () => _belgeSil(context, belge),
          ),
        );
      },
    );
  }

  Widget _buildGridGorunumu(List<BelgeModeli> belgeler) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: belgeler.length,
      itemBuilder: (context, index) {
        final belge = belgeler[index];
        return BelgeKartiWidget(
          belge: belge,
          onTap: () => _belgeAc(context, belge),
          onLongPress: () => _belgeDetayGoster(context, belge),
          onAc: () => _belgeAc(context, belge),
          onPaylas: () => _belgePaylas(context, belge),
          onDuzenle: () => _belgeDuzenle(context, belge),
          onSil: () => _belgeSil(context, belge),
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

        return InkWell(
          onTap: () => _belgeDetayGoster(context, belge),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                // Dosya ikonu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.description,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 12),

                // Belge bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        belge.baslik ?? belge.dosyaAdi,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (kategori != null) ...[
                            Text(
                              kategori.kategoriAdi,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[600],
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 11)),
                          ],
                          if (kisi != null) ...[
                            Text(
                              kisi.tamAd,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green[600],
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 11)),
                          ],
                          Text(
                            _formatBoyut(belge.dosyaBoyutu),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tarih
                Text(
                  _formatTarih(belge.olusturmaTarihi),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        );
      },
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
      case AramaSiralamaTuru.adAZ:
        liste.sort((a, b) {
          final aAd = a.baslik ?? a.dosyaAdi;
          final bAd = b.baslik ?? b.dosyaAdi;
          return aAd.toLowerCase().compareTo(bAd.toLowerCase());
        });
        break;
      case AramaSiralamaTuru.adZA:
        liste.sort((a, b) {
          final aAd = a.baslik ?? a.dosyaAdi;
          final bAd = b.baslik ?? b.dosyaAdi;
          return bAd.toLowerCase().compareTo(aAd.toLowerCase());
        });
        break;
      case AramaSiralamaTuru.boyutKucuk:
        liste.sort((a, b) => a.dosyaBoyutu.compareTo(b.dosyaBoyutu));
        break;
      case AramaSiralamaTuru.boyutBuyuk:
        liste.sort((a, b) => b.dosyaBoyutu.compareTo(a.dosyaBoyutu));
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
            title: const Text('Belge Sil'),
            content: Text(
              '${belge.baslik ?? belge.dosyaAdi} belgesi silinsin mi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sil'),
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
        content: Text(mesaj),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _basariMesajiGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
