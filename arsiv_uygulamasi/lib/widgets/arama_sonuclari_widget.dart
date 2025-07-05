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

  // Tarih filtresi için
  final DateTime? secilenBaslangicTarihi;
  final DateTime? secilenBitisTarihi;
  final Function(DateTime?, DateTime?)? onTarihSecimi;

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
    this.secilenBaslangicTarihi,
    this.secilenBitisTarihi,
    this.onTarihSecimi,
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

              // Tarih filtresi butonu
              if (onTarihSecimi != null) ...[
                _buildTarihFiltresiButonu(),
                const SizedBox(width: 12),
              ],

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

  void _tarihSecimModalGoster(BuildContext context) {
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
                  'Tarih Filtresi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),

                // Başlangıç tarihi seçimi
                _buildTarihSecimButonu(
                  context,
                  'Başlangıç Tarihi',
                  secilenBaslangicTarihi,
                  Icons.event_available,
                  (tarih) {
                    if (onTarihSecimi != null) {
                      onTarihSecimi!(tarih, secilenBitisTarihi);
                    }
                    Navigator.of(context).pop();
                  },
                ),

                const SizedBox(height: 12),

                // Bitiş tarihi seçimi
                _buildTarihSecimButonu(
                  context,
                  'Bitiş Tarihi',
                  secilenBitisTarihi,
                  Icons.event_busy,
                  (tarih) {
                    if (onTarihSecimi != null) {
                      onTarihSecimi!(secilenBaslangicTarihi, tarih);
                    }
                    Navigator.of(context).pop();
                  },
                ),

                const SizedBox(height: 20),

                // Filtreyi temizle butonu
                if (secilenBaslangicTarihi != null ||
                    secilenBitisTarihi != null)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        if (onTarihSecimi != null) {
                          onTarihSecimi!(null, null);
                        }
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Tarih Filtresini Temizle'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),
    );
  }

  Widget _buildTarihSecimButonu(
    BuildContext context,
    String baslik,
    DateTime? secilenTarih,
    IconData icon,
    Function(DateTime?) onTarihSecildi,
  ) {
    return InkWell(
      onTap: () async {
        final tarih = await showDatePicker(
          context: context,
          initialDate: secilenTarih ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          locale: const Locale('tr', 'TR'),
        );
        onTarihSecildi(tarih);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: secilenTarih != null ? Colors.green[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                secilenTarih != null ? Colors.green[200]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    secilenTarih != null ? Colors.green[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    secilenTarih != null ? Colors.green[600] : Colors.grey[600],
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
                      color:
                          secilenTarih != null
                              ? Colors.green[800]
                              : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secilenTarih != null
                        ? '${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}'
                        : 'Tarih seçin',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          secilenTarih != null
                              ? Colors.green[600]
                              : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (secilenTarih != null)
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
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

  Widget _buildTarihFiltresiButonu() {
    return Builder(
      builder:
          (context) => InkWell(
            onTap: () => _tarihSecimModalGoster(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color:
                    (secilenBaslangicTarihi != null ||
                            secilenBitisTarihi != null)
                        ? Colors.green[50]
                        : Colors.white,
              ),
              child: Icon(
                Icons.date_range,
                size: 16,
                color:
                    (secilenBaslangicTarihi != null ||
                            secilenBitisTarihi != null)
                        ? Colors.green[600]
                        : Colors.grey[600],
              ),
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
      case AramaGorunumTuru.kompakt:
        return _buildKompaktGorunumu(siraliBegleler);
    }
  }

  Widget _buildListeGorunumu(List<BelgeModeli> belgeler) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: belgeler.length,
      itemBuilder: (context, index) {
        final belge = belgeler[index];

        // Hem mobil hem PC için detaylı kart kullan
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OptimizedBelgeKartiWidget(
            belge: belge,
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
      padding: EdgeInsets.zero,
      itemCount: belgeler.length,
      itemBuilder: (context, index) {
        final belge = belgeler[index];
        final kategori = _getKategori(belge.kategoriId);
        final kisi = _getKisi(belge.kisiId);

        return InkWell(
          onTap: () => _belgeDetayGoster(context, belge),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                // Dosya ikonu
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description,
                    size: 22,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 16),

                // Belge bilgileri - İki satırlı düzen
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst satır: Belge adı ve tarih
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              belge.baslik ?? belge.dosyaAdi,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15, // 16'dan 15'e düşürüldü
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTarih(belge.olusturmaTarihi),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ), // 13'ten 12'ye düşürüldü
                          ),
                        ],
                      ),
                      const SizedBox(height: 6), // 4'ten 6'ya artırıldı
                      // Alt satır: Kategori, kişi ve boyut
                      Row(
                        children: [
                          // Kategori
                          if (kategori != null) ...[
                            Flexible(
                              child: Container(
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
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4), // 6'dan 4'e düşürüldü
                          ],
                          // Kişi
                          if (kisi != null) ...[
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  kisi.tamAd,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4), // 6'dan 4'e düşürüldü
                          ],
                          // Boyut - daha kompakt
                          if (kategori != null || kisi != null) ...[
                            Text(
                              '• ${_formatBoyut(belge.dosyaBoyutu)}',
                              style: TextStyle(
                                fontSize: 11, // 12'den 11'e düşürüldü
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            Text(
                              _formatBoyut(belge.dosyaBoyutu),
                              style: TextStyle(
                                fontSize: 11, // 12'den 11'e düşürüldü
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Aksiyon butonları - Tüm butonlar
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _belgeAc(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(
                          6,
                        ), // 8'den 6'ya küçültüldü
                        child: Icon(
                          Icons.open_in_new,
                          color: Colors.blue[600],
                          size: 16, // 18'den 16'ya küçültüldü
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgePaylas(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(
                          6,
                        ), // 8'den 6'ya küçültüldü
                        child: Icon(
                          Icons.share,
                          color: Colors.green[600],
                          size: 16, // 18'den 16'ya küçültüldü
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgeDuzenle(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(
                          6,
                        ), // 8'den 6'ya küçültüldü
                        child: Icon(
                          Icons.edit,
                          color: Colors.orange[600],
                          size: 16, // 18'den 16'ya küçültüldü
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _belgeSil(context, belge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(
                          6,
                        ), // 8'den 6'ya küçültüldü
                        child: Icon(
                          Icons.delete,
                          color: Colors.red[600],
                          size: 16, // 18'den 16'ya küçültüldü
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
