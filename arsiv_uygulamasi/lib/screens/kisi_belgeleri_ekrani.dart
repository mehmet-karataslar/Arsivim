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
      final belgeler = await _veriTabani.kisiBelgeleriniGetir(widget.kisi.id!);
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

    // Minimum karakter kontrolü
    if (_aramaMetni.length < 1) return _belgeler;

    final aramaKelimesi = _aramaMetni.toLowerCase().trim();
    final aramaSozcukleri =
        aramaKelimesi.split(' ').where((s) => s.isNotEmpty).toList();

    // Arama sonuçlarını puanlama sistemi ile sıralama
    final aramaSonuclari = <Map<String, dynamic>>[];

    for (final belge in _belgeler) {
      final puan = _belgeAramaPuani(belge, aramaKelimesi, aramaSozcukleri);
      if (puan > 0) {
        aramaSonuclari.add({'belge': belge, 'puan': puan});
      }
    }

    // Puana göre sıralama (yüksek puan önce)
    aramaSonuclari.sort((a, b) => b['puan'].compareTo(a['puan']));

    return aramaSonuclari.map((item) => item['belge'] as BelgeModeli).toList();
  }

  // Gelişmiş arama puanlama sistemi
  int _belgeAramaPuani(
    BelgeModeli belge,
    String aramaKelimesi,
    List<String> aramaSozcukleri,
  ) {
    int puan = 0;

    // Arama metinlerini hazırla
    final dosyaAdi = belge.dosyaAdi.toLowerCase();
    final orijinalDosyaAdi = belge.orijinalDosyaAdi.toLowerCase();
    final baslik = (belge.baslik ?? '').toLowerCase();
    final aciklama = (belge.aciklama ?? '').toLowerCase();
    final etiketler = (belge.etiketler ?? [])
        .map((e) => e.toLowerCase())
        .join(' ');

    // Kategori adı
    String kategoriAdi = '';
      if (belge.kategoriId != null) {
        try {
          final kategori = _kategoriler.firstWhere(
            (k) => k.id == belge.kategoriId,
          );
        kategoriAdi = kategori.kategoriAdi.toLowerCase();
        } catch (e) {
          // Kategori bulunamadı
        }
      }

    // 1. TAM METIN EŞLEŞMESİ (en yüksek puan)
    if (dosyaAdi == aramaKelimesi) puan += 1000;
    if (orijinalDosyaAdi == aramaKelimesi) puan += 1000;
    if (baslik == aramaKelimesi) puan += 900;
    if (aciklama == aramaKelimesi) puan += 800;
    if (kategoriAdi == aramaKelimesi) puan += 700;

    // 2. TAM KELIME EŞLEŞMESİ (yüksek puan)
    final tamKelimePuani =
        _tamKelimeAramaPuani(aramaKelimesi, aramaSozcukleri, {
          'dosyaAdi': dosyaAdi,
          'orijinalDosyaAdi': orijinalDosyaAdi,
          'baslik': baslik,
          'aciklama': aciklama,
          'etiketler': etiketler,
          'kategoriAdi': kategoriAdi,
        });
    puan += tamKelimePuani;

    // 3. BAŞLANGIC EŞLEŞMESİ (orta puan)
    if (dosyaAdi.startsWith(aramaKelimesi)) puan += 300;
    if (orijinalDosyaAdi.startsWith(aramaKelimesi)) puan += 300;
    if (baslik.startsWith(aramaKelimesi)) puan += 250;
    if (aciklama.startsWith(aramaKelimesi)) puan += 200;
    if (kategoriAdi.startsWith(aramaKelimesi)) puan += 150;

    // 4. IÇERIK EŞLEŞMESİ (düşük puan)
    if (dosyaAdi.contains(aramaKelimesi)) puan += 50;
    if (orijinalDosyaAdi.contains(aramaKelimesi)) puan += 50;
    if (baslik.contains(aramaKelimesi)) puan += 40;
    if (aciklama.contains(aramaKelimesi)) puan += 30;
    if (etiketler.contains(aramaKelimesi)) puan += 25;
    if (kategoriAdi.contains(aramaKelimesi)) puan += 20;

    // 5. FUZZY SEARCH (çok düşük puan)
    puan += _fuzzySearchPuani(aramaKelimesi, dosyaAdi, 10);
    puan += _fuzzySearchPuani(aramaKelimesi, orijinalDosyaAdi, 10);
    puan += _fuzzySearchPuani(aramaKelimesi, baslik, 8);
    puan += _fuzzySearchPuani(aramaKelimesi, aciklama, 6);
    puan += _fuzzySearchPuani(aramaKelimesi, kategoriAdi, 4);

    return puan;
  }

  // Tam kelime arama puanlama sistemi
  int _tamKelimeAramaPuani(
    String aramaKelimesi,
    List<String> aramaSozcukleri,
    Map<String, String> alanlar,
  ) {
    int puan = 0;

    // Tek kelime tam eşleşme
    for (final alan in alanlar.entries) {
      final alanDegeri = alan.value;
      final kelimeler =
          alanDegeri
              .split(RegExp(r'[^a-zA-ZçğıöşüÇĞIİÖŞÜ0-9]+'))
              .where((s) => s.isNotEmpty)
              .toList();

      for (final kelime in kelimeler) {
        if (kelime == aramaKelimesi) {
          switch (alan.key) {
            case 'dosyaAdi':
            case 'orijinalDosyaAdi':
              puan += 500;
              break;
            case 'baslik':
              puan += 450;
              break;
            case 'aciklama':
              puan += 400;
              break;
            case 'etiketler':
              puan += 350;
              break;
            case 'kategoriAdi':
              puan += 300;
              break;
          }
        }
      }
    }

    // Çoklu kelime araması (cümle araması)
    if (aramaSozcukleri.length > 1) {
      for (final alan in alanlar.entries) {
        final alanDegeri = alan.value;
        int eslesen = 0;

        for (final sozcuk in aramaSozcukleri) {
          if (sozcuk.length >= 1) {
            // Minimum 1 karakter
            final alanKelimeler =
                alanDegeri
                    .split(RegExp(r'[^a-zA-ZçğıöşüÇĞIİÖŞÜ0-9]+'))
                    .where((s) => s.isNotEmpty)
                    .toList();

            // Tam kelime eşleşmesi
            if (alanKelimeler.any((k) => k == sozcuk)) {
              eslesen += 3;
            }
            // Başlangıç eşleşmesi
            else if (alanKelimeler.any((k) => k.startsWith(sozcuk))) {
              eslesen += 2;
            }
            // İçerik eşleşmesi
            else if (alanDegeri.contains(sozcuk)) {
              eslesen += 1;
            }
          }
        }

        // Eşleşen kelime sayısına göre puan ver
        if (eslesen > 0) {
          final cokluKelimeBonusu = (eslesen * 100) ~/ aramaSozcukleri.length;
          switch (alan.key) {
            case 'dosyaAdi':
            case 'orijinalDosyaAdi':
              puan += cokluKelimeBonusu;
              break;
            case 'baslik':
              puan += (cokluKelimeBonusu * 0.9).round();
              break;
            case 'aciklama':
              puan += (cokluKelimeBonusu * 0.8).round();
              break;
            case 'etiketler':
              puan += (cokluKelimeBonusu * 0.7).round();
              break;
            case 'kategoriAdi':
              puan += (cokluKelimeBonusu * 0.6).round();
              break;
          }
        }
      }
    }

    return puan;
  }

  // Fuzzy search algoritması (Levenshtein distance)
  int _fuzzySearchPuani(String aranan, String hedef, int maxPuan) {
    if (aranan.isEmpty || hedef.isEmpty) return 0;
    if (aranan.length < 3)
      return 0; // Çok kısa kelimeler için fuzzy search yapma

    final mesafe = _levenshteinDistance(aranan, hedef);
    final maxMesafe = (aranan.length * 0.4).round(); // %40 hata toleransı

    if (mesafe <= maxMesafe) {
      final benzerlikOrani = 1.0 - (mesafe / aranan.length);
      return (maxPuan * benzerlikOrani).round();
    }

    return 0;
  }

  // Levenshtein distance hesaplama
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // silme
          matrix[i][j - 1] + 1, // ekleme
          matrix[i - 1][j - 1] + cost, // değiştirme
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
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
