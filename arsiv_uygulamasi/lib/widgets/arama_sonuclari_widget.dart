import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/veritabani_servisi.dart';
import 'belge_karti_widget.dart';
import 'belge_detay_dialog.dart';

enum AramaSiralamaTuru { tarihYeni, tarihEski }

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
    // Platform kontrolü: Web/PC'de dropdown, mobilde buton
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // PC/Web için detaylı dropdown
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
            ],
          ),
        ),
      );
    } else {
      // Mobil için basit filtreleme butonu
      return _buildMobilFiltreleButonu();
    }
  }

  Widget _buildMobilFiltreleButonu() {
    return Builder(
      builder:
          (context) => InkWell(
            onTap: () => _mobilSiralamaModalGoster(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list, color: Colors.indigo[600], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Filtrele',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.indigo[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _mobilSiralamaModalGoster(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sıralama Seçin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                _buildMobilSiralamaSecenegi(
                  context,
                  AramaSiralamaTuru.tarihYeni,
                  Icons.schedule,
                  'Yeni → Eski',
                  'En yeni belgeler önce',
                ),
                _buildMobilSiralamaSecenegi(
                  context,
                  AramaSiralamaTuru.tarihEski,
                  Icons.history,
                  'Eski → Yeni',
                  'En eski belgeler önce',
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
    );
  }

  Widget _buildMobilSiralamaSecenegi(
    BuildContext context,
    AramaSiralamaTuru tur,
    IconData icon,
    String baslik,
    String aciklama,
  ) {
    final secili = siralamaTuru == tur;
    return InkWell(
      onTap: () {
        onSiralamaSecildi(tur);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: secili ? Colors.indigo[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secili ? Colors.indigo[200]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: secili ? Colors.indigo[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: secili ? Colors.indigo[600] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: secili ? Colors.indigo[800] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aciklama,
                    style: TextStyle(
                      fontSize: 12,
                      color: secili ? Colors.indigo[600] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (secili)
              Icon(Icons.check_circle, color: Colors.indigo[600], size: 20),
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

        // Hem mobil hem PC için detaylı kart kullan
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
    // Platform kontrolü: Web/PC'de detaylı kart, mobilde basit grid
    if (kIsWeb) {
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
    } else {
      // Mobil için basit grid görünümü
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: belgeler.length,
        itemBuilder: (context, index) {
          final belge = belgeler[index];
          return _buildMobilGridOgesi(context, belge);
        },
      );
    }
  }

  // Mobil için basit grid öğesi
  Widget _buildMobilGridOgesi(BuildContext context, BelgeModeli belge) {
    final kategori = _getKategori(belge.kategoriId);

    return InkWell(
      onTap: () => _belgeDetayGoster(context, belge),
      onLongPress: () => _belgeAc(context, belge),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Dosya ikonu ve aksiyon butonları
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Dosya ikonu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description,
                      size: 24,
                      color: Colors.blue[600],
                    ),
                  ),
                  const Spacer(),
                  // Mini aksiyon butonları
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _belgeAc(context, belge),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.open_in_new,
                            color: Colors.blue[600],
                            size: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _belgePaylas(context, belge),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.share,
                            color: Colors.green[600],
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // İçerik kısmı
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Belge adı
                  Text(
                    belge.baslik ?? belge.dosyaAdi,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Kategori
                  if (kategori != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        kategori.kategoriAdi,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Boyut ve tarih
                  Text(
                    '${belge.formatliDosyaBoyutu}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    belge.zamanFarki,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Alt kısım - Düzenle ve Sil butonları
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _belgeDuzenle(context, belge),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit,
                              color: Colors.orange[600],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Düzenle',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => _belgeSil(context, belge),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete,
                              color: Colors.red[600],
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sil',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                            Flexible(
                              child: Text(
                                kategori.kategoriAdi,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 11)),
                          ],
                          if (kisi != null) ...[
                            Flexible(
                              child: Text(
                                kisi.tamAd,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 11)),
                          ],
                          Flexible(
                            child: Text(
                              _formatBoyut(belge.dosyaBoyutu),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
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

                // Aksiyon butonları
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _belgeAc(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.open_in_new,
                          color: Colors.blue[600],
                          size: 16,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgePaylas(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.share,
                          color: Colors.green[600],
                          size: 16,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgeDuzenle(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit,
                          color: Colors.orange[600],
                          size: 16,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgeSil(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete,
                          color: Colors.red[600],
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Mobil için basit liste öğesi
  Widget _buildMobilListeOgesi(BuildContext context, BelgeModeli belge) {
    final kategori = _getKategori(belge.kategoriId);
    final kisi = _getKisi(belge.kisiId);

    return InkWell(
      onTap: () => _belgeDetayGoster(context, belge),
      onLongPress: () => _belgeAc(context, belge),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dosya ikonu
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  belge.dosyaTipiSimgesi,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Belge bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    belge.baslik ?? belge.orijinalDosyaAdi,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (kategori != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            kategori.kategoriAdi,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '${belge.formatliDosyaBoyutu} • ${belge.zamanFarki}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Aksiyon butonları - Tüm butonlar yatay ve açıklamalı
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Aç butonu
                  InkWell(
                    onTap: () => _belgeAc(context, belge),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            color: Colors.blue[600],
                            size: 18,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aç',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Paylaş butonu
                  InkWell(
                    onTap: () => _belgePaylas(context, belge),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share, color: Colors.green[600], size: 18),
                          const SizedBox(height: 2),
                          Text(
                            'Paylaş',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Düzenle butonu
                  InkWell(
                    onTap: () => _belgeDuzenle(context, belge),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.orange[600], size: 18),
                          const SizedBox(height: 2),
                          Text(
                            'Düzenle',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sil butonu
                  InkWell(
                    onTap: () => _belgeSil(context, belge),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, color: Colors.red[600], size: 18),
                          const SizedBox(height: 2),
                          Text(
                            'Sil',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _basariMesajiGoster(BuildContext context, String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
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
