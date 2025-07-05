import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../widgets/belge_detay_dialog.dart';
import '../utils/screen_utils.dart';
import 'yeni_belge_ekle_ekrani.dart';

class KisiBelgeleriEkrani extends StatefulWidget {
  final KisiModeli kisi;

  const KisiBelgeleriEkrani({Key? key, required this.kisi}) : super(key: key);

  @override
  State<KisiBelgeleriEkrani> createState() => _KisiBelgeleriEkraniState();
}

class _KisiBelgeleriEkraniState extends State<KisiBelgeleriEkrani> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final BelgeIslemleriServisi _belgeIslemleri = BelgeIslemleriServisi();

  List<BelgeModeli> _belgeler = [];
  List<KategoriModeli> _kategoriler = [];
  bool _yukleniyor = true;
  String _aramaMetni = '';

  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      final belgeler = await _veriTabani.kisiBelyeleriniGetir(widget.kisi.id!);
      final kategoriler = await _veriTabani.kategorileriGetir();

      setState(() {
        _belgeler = belgeler;
        _kategoriler = kategoriler;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Belgeler yüklenirken hata oluştu: $e');
    }
  }

  List<BelgeModeli> get _filtrelenmsBelgeler {
    if (_aramaMetni.isEmpty) return _belgeler;

    return _belgeler.where((belge) {
      final aramaKelimesi = _aramaMetni.toLowerCase();

      // Dosya adında arama
      if (belge.orijinalDosyaAdi.toLowerCase().contains(aramaKelimesi) ||
          belge.dosyaAdi.toLowerCase().contains(aramaKelimesi)) {
        return true;
      }

      // Başlıkta arama
      if (belge.baslik?.toLowerCase().contains(aramaKelimesi) ?? false) {
        return true;
      }

      // Açıklamada arama
      if (belge.aciklama?.toLowerCase().contains(aramaKelimesi) ?? false) {
        return true;
      }

      // Etiketlerde arama
      if (belge.etiketler?.any(
            (etiket) => etiket.toLowerCase().contains(aramaKelimesi),
          ) ??
          false) {
        return true;
      }

      // Kategoride arama
      if (belge.kategoriId != null) {
        try {
          final kategori = _kategoriler.firstWhere(
            (k) => k.id == belge.kategoriId,
          );
          if (kategori.kategoriAdi.toLowerCase().contains(aramaKelimesi)) {
            return true;
          }
        } catch (e) {
          // Kategori bulunamadı
        }
      }

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScreenUtils.buildAppBar(
        title: '${widget.kisi.tamAd} - Belgeler',
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _yeniBelgeEkle,
            tooltip: 'Yeni Belge Ekle',
          ),
        ],
      ),
      body: ScreenUtils.buildGradientContainer(
        colors: [Colors.blue.shade50, Colors.white],
        child: Column(
          children: [
            // İstatistik kartı
            _buildIstatistikKarti(),

            // Arama kutusu
            if (_belgeler.isNotEmpty) _buildAramaKutusu(),

            // Belge listesi
            Expanded(child: _buildBelgeListesi()),
          ],
        ),
      ),
    );
  }

  Widget _buildIstatistikKarti() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Text(
              widget.kisi.ad.isNotEmpty ? widget.kisi.ad[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.blue[600],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.kisi.tamAd,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_belgeler.length} belge',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.folder, color: Colors.green[600], size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildAramaKutusu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _aramaController,
        decoration: InputDecoration(
          hintText: 'Belgeler arasında arama yapın...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _aramaMetni.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _aramaController.clear();
                      setState(() => _aramaMetni = '');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() => _aramaMetni = value);
        },
      ),
    );
  }

  Widget _buildBelgeListesi() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_belgeler.isEmpty) {
      return _buildBosList();
    }

    final filtrelenmsBelgeler = _filtrelenmsBelgeler;

    if (filtrelenmsBelgeler.isEmpty && _aramaMetni.isNotEmpty) {
      return _buildAramaSonucuYok();
    }

    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtrelenmsBelgeler.length,
        itemBuilder: (context, index) {
          return _buildBelgeKarti(filtrelenmsBelgeler[index]);
        },
      ),
    );
  }

  Widget _buildBosList() {
    return ScreenUtils.buildEmptyState(
      icon: Icons.folder_open,
      title: 'Henüz belge eklenmemiş',
      message: 'Bu kişi için ilk belgeyi eklemek için + simgesine dokunun',
      actionText: 'Belge Ekle',
      onAction: _yeniBelgeEkle,
    );
  }

  Widget _buildAramaSonucuYok() {
    return ScreenUtils.buildEmptyState(
      icon: Icons.search_off,
      title: 'Arama sonucu bulunamadı',
      message: '"$_aramaMetni" için sonuç bulunamadı',
    );
  }

  Widget _buildBelgeKarti(BelgeModeli belge) {
    final kategori =
        belge.kategoriId != null
            ? _kategoriler.firstWhere(
              (k) => k.id == belge.kategoriId,
              orElse:
                  () => KategoriModeli(
                    kategoriAdi: 'Kategorisiz',
                    renkKodu: '#757575',
                    simgeKodu: 'default',
                    olusturmaTarihi: DateTime.now(),
                  ),
            )
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _belgeDetayGoster(belge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır - dosya bilgisi
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        belge.dosyaTipiSimgesi,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          belge.baslik ?? belge.orijinalDosyaAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          belge.formatliDosyaBoyutu,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Kategori bilgisi
              if (kategori != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse(kategori.renkKodu.replaceFirst('#', '0xFF')),
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Color(
                        int.parse(kategori.renkKodu.replaceFirst('#', '0xFF')),
                      ).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    kategori.kategoriAdi,
                    style: TextStyle(
                      color: Color(
                        int.parse(kategori.renkKodu.replaceFirst('#', '0xFF')),
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              // Açıklama
              if (belge.aciklama != null && belge.aciklama!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  belge.aciklama!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Alt satır - tarih ve butonlar
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    belge.formatliOlusturmaTarihi,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const Spacer(),
                  // Butonlar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAksiyonButonu(
                        Icons.open_in_new,
                        'Aç',
                        Colors.blue,
                        () => _belgeAc(belge),
                      ),
                      const SizedBox(width: 8),
                      _buildAksiyonButonu(
                        Icons.share,
                        'Paylaş',
                        Colors.green,
                        () => _belgePaylas(belge),
                      ),
                      const SizedBox(width: 8),
                      _buildAksiyonButonu(
                        Icons.edit,
                        'Düzenle',
                        Colors.orange,
                        () => _belgeDuzenle(belge),
                      ),
                      const SizedBox(width: 8),
                      _buildAksiyonButonu(
                        Icons.delete,
                        'Sil',
                        Colors.red,
                        () => _belgeSilOnay(belge),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAksiyonButonu(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              tooltip,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İşlem metotları
  Future<void> _yeniBelgeEkle() async {
    final sonuc = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const YeniBelgeEkleEkrani()),
    );

    if (sonuc == true) {
      _verileriYukle();
    }
  }

  void _belgeDetayGoster(BelgeModeli belge) {
    final kategori =
        belge.kategoriId != null
            ? _kategoriler.firstWhere(
              (k) => k.id == belge.kategoriId,
              orElse:
                  () => KategoriModeli(
                    kategoriAdi: 'Kategorisiz',
                    renkKodu: '#757575',
                    simgeKodu: 'default',
                    olusturmaTarihi: DateTime.now(),
                  ),
            )
            : null;

    showDialog(
      context: context,
      builder:
          (context) => BelgeDetayDialog(
            belge: belge,
            kategori: kategori,
            kisi: widget.kisi,
          ),
    );
  }

  Future<void> _belgeAc(BelgeModeli belge) async {
    try {
      await _belgeIslemleri.belgeAc(belge, context);
    } catch (e) {
      _hataGoster('Belge açılamadı: $e');
    }
  }

  Future<void> _belgePaylas(BelgeModeli belge) async {
    try {
      await _belgeIslemleri.belgePaylas(belge, context);
    } catch (e) {
      _hataGoster('Belge paylaşılamadı: $e');
    }
  }

  Future<void> _belgeDuzenle(BelgeModeli belge) async {
    final sonuc = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YeniBelgeEkleEkrani(duzenlenecekBelge: belge),
      ),
    );

    if (sonuc == true) {
      _verileriYukle();
    }
  }

  void _belgeSilOnay(BelgeModeli belge) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Belgeyi Sil'),
            content: Text(
              '${belge.baslik ?? belge.orijinalDosyaAdi} belgesini silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _belgeSil(belge);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  Future<void> _belgeSil(BelgeModeli belge) async {
    try {
      await _belgeIslemleri.belgeSil(belge, context);
      _basariGoster('Belge başarıyla silindi');
      _verileriYukle();
    } catch (e) {
      _hataGoster('Belge silinirken hata oluştu: $e');
    }
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }

  void _basariGoster(String mesaj) {
    ScreenUtils.showSuccessSnackBar(context, mesaj);
  }
}
