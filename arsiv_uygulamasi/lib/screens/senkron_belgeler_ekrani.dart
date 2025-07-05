import 'package:flutter/material.dart';
import 'dart:io';
import '../services/veritabani_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../utils/screen_utils.dart';
import '../utils/yardimci_fonksiyonlar.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';

class SenkronBelgelerEkrani extends StatefulWidget {
  const SenkronBelgelerEkrani({Key? key}) : super(key: key);

  @override
  State<SenkronBelgelerEkrani> createState() => _SenkronBelgelerEkraniState();
}

class _SenkronBelgelerEkraniState extends State<SenkronBelgelerEkrani>
    with TickerProviderStateMixin {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final BelgeIslemleriServisi _belgeServisi = BelgeIslemleriServisi();

  // Animasyon controller'ları
  late AnimationController _fadeAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _fadeAnimation;

  // Veri listeleri
  List<BelgeModeli> _bekleyenBelgeler = [];
  List<BelgeModeli> _pcBelgeleri = [];
  List<BelgeModeli> _mobilBelgeler = [];
  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];

  // Durum değişkenleri
  bool _yukleniyor = true;
  bool _topluSecim = false;
  Set<int> _secilenBelgeler = {};
  int _aktifTab = 0; // 0: Tümü, 1: PC, 2: Mobil

  // Platform kontrolü
  bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _verileriYukle();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimationController.forward();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      // Tüm belgeleri getir
      final tumBelgeler = await _veriTabani.belgeleriGetir();

      // Bekleyen belgeleri filtrele
      _bekleyenBelgeler =
          tumBelgeler
              .where(
                (belge) =>
                    belge.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                    belge.senkronDurumu == SenkronDurumu.YEREL_DEGISIM ||
                    belge.senkronDurumu == SenkronDurumu.UZAK_DEGISIM,
              )
              .toList();

      // Platform bazlı ayırma (simüle edilmiş - gerçek uygulamada cihaz ID'sine göre ayırılır)
      _pcBelgeleri =
          _bekleyenBelgeler
              .where(
                (belge) =>
                    belge.dosyaYolu.contains('Documents') ||
                    belge.dosyaYolu.contains('Desktop') ||
                    belge.dosyaYolu.contains('\\'), // Windows path separator
              )
              .toList();

      _mobilBelgeler =
          _bekleyenBelgeler
              .where((belge) => !_pcBelgeleri.contains(belge))
              .toList();

      // Kategoriler ve kişiler
      _kategoriler = await _veriTabani.kategorileriGetir();
      _kisiler = await _veriTabani.kisileriGetir();

      setState(() {
        _yukleniyor = false;
      });

      _listAnimationController.forward();
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Veriler yüklenirken hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child:
            _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _pcPlatform ? _buildPCLayout() : _buildMobileLayout(),
                ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Senkron Olacak Belgeler',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      actions: [
        if (_bekleyenBelgeler.isNotEmpty) ...[
          IconButton(
            icon: Icon(_topluSecim ? Icons.close : Icons.checklist),
            onPressed: () {
              setState(() {
                _topluSecim = !_topluSecim;
                if (!_topluSecim) {
                  _secilenBelgeler.clear();
                }
              });
            },
            tooltip: _topluSecim ? 'Seçimi İptal Et' : 'Toplu Seçim',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verileriYukle,
            tooltip: 'Yenile',
          ),
        ],
      ],
    );
  }

  Widget _buildPCLayout() {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: Row(
            children: [
              // Sol panel - Liste
              Expanded(flex: 3, child: _buildBelgeListesi()),
              // Sağ panel - Detay ve işlemler
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(-2, 0),
                    ),
                  ],
                ),
                child: _buildDetayPaneli(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [_buildTabBar(), Expanded(child: _buildBelgeListesi())],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
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
          Expanded(
            child: _buildTabButton(
              'Tümü (${_bekleyenBelgeler.length})',
              0,
              Icons.all_inclusive,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'PC (${_pcBelgeleri.length})',
              1,
              Icons.computer,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'Mobil (${_mobilBelgeler.length})',
              2,
              Icons.phone_android,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, IconData icon) {
    final isActive = _aktifTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _aktifTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isActive ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBelgeListesi() {
    final belgeler = _getAktifBelgeler();

    if (belgeler.isEmpty) {
      return _buildBosListe();
    }

    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: belgeler.length,
        itemBuilder: (context, index) {
          final belge = belgeler[index];
          return _buildBelgeKarti(belge, index);
        },
      ),
    );
  }

  List<BelgeModeli> _getAktifBelgeler() {
    switch (_aktifTab) {
      case 1:
        return _pcBelgeleri;
      case 2:
        return _mobilBelgeler;
      default:
        return _bekleyenBelgeler;
    }
  }

  Widget _buildBosListe() {
    String mesaj;
    IconData icon;

    switch (_aktifTab) {
      case 1:
        mesaj = 'PC\'de bekleyen belge yok';
        icon = Icons.computer;
        break;
      case 2:
        mesaj = 'Mobilde bekleyen belge yok';
        icon = Icons.phone_android;
        break;
      default:
        mesaj = 'Senkronizasyon bekleyen belge yok';
        icon = Icons.sync;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            mesaj,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tüm belgeler senkronize edilmiş!',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBelgeKarti(BelgeModeli belge, int index) {
    final kategori = _kategoriler.firstWhere(
      (k) => k.id == belge.kategoriId,
      orElse:
          () => KategoriModeli(
            kategoriAdi: 'Kategorisiz',
            renkKodu: '#757575',
            simgeKodu: 'folder',
            olusturmaTarihi: DateTime.now(),
          ),
    );

    final kisi =
        belge.kisiId != null
            ? _kisiler.firstWhere(
              (k) => k.id == belge.kisiId,
              orElse:
                  () => KisiModeli(
                    ad: 'Bilinmeyen',
                    soyad: 'Kişi',
                    olusturmaTarihi: DateTime.now(),
                    guncellemeTarihi: DateTime.now(),
                  ),
            )
            : null;

    final isSelected = _secilenBelgeler.contains(belge.id);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (_topluSecim) {
              _toggleBelgeSecimi(belge.id!);
            } else {
              _belgeDetayiniGoster(belge);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      )
                      : null,
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      )
                      : null,
            ),
            child:
                _pcPlatform
                    ? _buildPCBelgeKarti(belge, kategori, kisi, isSelected)
                    : _buildMobilBelgeKarti(belge, kategori, kisi, isSelected),
          ),
        ),
      ),
    );
  }

  Widget _buildPCBelgeKarti(
    BelgeModeli belge,
    KategoriModeli kategori,
    KisiModeli? kisi,
    bool isSelected,
  ) {
    return Row(
      children: [
        // Seçim checkbox'u
        if (_topluSecim) ...[
          Checkbox(
            value: isSelected,
            onChanged: (value) => _toggleBelgeSecimi(belge.id!),
          ),
          const SizedBox(width: 12),
        ],
        // Dosya ikonu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getDosyaTipiRengi(belge.dosyaTipi),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDosyaTipiIkonu(belge.dosyaTipi),
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        // Belge bilgileri
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      belge.baslik ?? belge.orijinalDosyaAdi,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildSenkronDurumChip(belge.senkronDurumu),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    kategori.kategoriAdi,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    YardimciFonksiyonlar.dosyaBoyutuFormatla(belge.dosyaBoyutu),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (kisi != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      kisi.tamAd,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    belge.formatliGuncellemeTarihi,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  _buildPlatformChip(_getPlatform(belge)),
                ],
              ),
            ],
          ),
        ),
        // İşlem butonları
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => _tekBelgeSenkronize(belge),
              tooltip: 'Senkronize Et',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _belgeMenusunu(belge),
              tooltip: 'Daha Fazla',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobilBelgeKarti(
    BelgeModeli belge,
    KategoriModeli kategori,
    KisiModeli? kisi,
    bool isSelected,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Seçim checkbox'u
            if (_topluSecim) ...[
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleBelgeSecimi(belge.id!),
              ),
              const SizedBox(width: 8),
            ],
            // Dosya ikonu
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getDosyaTipiRengi(belge.dosyaTipi),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getDosyaTipiIkonu(belge.dosyaTipi),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Belge başlığı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    belge.baslik ?? belge.orijinalDosyaAdi,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    kategori.kategoriAdi,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildSenkronDurumChip(belge.senkronDurumu),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              YardimciFonksiyonlar.dosyaBoyutuFormatla(belge.dosyaBoyutu),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            const SizedBox(width: 8),
            _buildPlatformChip(_getPlatform(belge)),
            const Spacer(),
            Text(
              belge.formatliGuncellemeTarihi,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSenkronDurumChip(SenkronDurumu durum) {
    Color color;
    String text;

    switch (durum) {
      case SenkronDurumu.BEKLEMEDE:
        color = Colors.orange;
        text = 'Bekliyor';
        break;
      case SenkronDurumu.YEREL_DEGISIM:
        color = Colors.blue;
        text = 'Yerel';
        break;
      case SenkronDurumu.UZAK_DEGISIM:
        color = Colors.purple;
        text = 'Uzak';
        break;
      default:
        color = Colors.grey;
        text = 'Bilinmiyor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: platform == 'PC' ? Colors.blue[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        platform,
        style: TextStyle(
          color: platform == 'PC' ? Colors.blue[800] : Colors.green[800],
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetayPaneli() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toplu İşlemler',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTopluIslemButonu(
            'Seçilenleri Senkronize Et',
            Icons.sync,
            Colors.green,
            _secilenBelgeleriSenkronize,
          ),
          const SizedBox(height: 8),
          _buildTopluIslemButonu(
            'Tümünü Senkronize Et',
            Icons.sync_alt,
            Colors.blue,
            _tumBelgeleriSenkronize,
          ),
          const SizedBox(height: 8),
          _buildTopluIslemButonu(
            'Seçilenleri Sil',
            Icons.delete,
            Colors.red,
            _secilenBelgeleriSil,
          ),
          const SizedBox(height: 24),
          Text(
            'İstatistikler',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildIstatistikItem(
            'Toplam Bekleyen',
            '${_bekleyenBelgeler.length}',
          ),
          _buildIstatistikItem('PC Belgeleri', '${_pcBelgeleri.length}'),
          _buildIstatistikItem('Mobil Belgeleri', '${_mobilBelgeler.length}'),
          _buildIstatistikItem(
            'Seçilen Belgeler',
            '${_secilenBelgeler.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildTopluIslemButonu(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildIstatistikItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_secilenBelgeler.isEmpty) return Container();

    return FloatingActionButton.extended(
      onPressed: _secilenBelgeleriSenkronize,
      backgroundColor: Theme.of(context).primaryColor,
      icon: const Icon(Icons.sync, color: Colors.white),
      label: Text(
        'Senkronize Et (${_secilenBelgeler.length})',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // Yardımcı metodlar
  String _getPlatform(BelgeModeli belge) {
    return belge.dosyaYolu.contains('\\') ? 'PC' : 'Mobil';
  }

  Color _getDosyaTipiRengi(String dosyaTipi) {
    switch (dosyaTipi.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.green;
      case 'mp4':
      case 'avi':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getDosyaTipiIkonu(String dosyaTipi) {
    switch (dosyaTipi.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'avi':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _toggleBelgeSecimi(int belgeId) {
    setState(() {
      if (_secilenBelgeler.contains(belgeId)) {
        _secilenBelgeler.remove(belgeId);
      } else {
        _secilenBelgeler.add(belgeId);
      }
    });
  }

  // Event handlers
  void _belgeDetayiniGoster(BelgeModeli belge) {
    // Belge detay modal'ını göster
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(belge.baslik ?? belge.orijinalDosyaAdi),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dosya Tipi: ${belge.dosyaTipi}'),
                Text('Boyut: ${belge.formatliDosyaBoyutu}'),
                Text('Tarih: ${belge.formatliGuncellemeTarihi}'),
                Text('Durum: ${belge.senkronDurumu.name}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _tekBelgeSenkronize(belge);
                },
                child: const Text('Senkronize Et'),
              ),
            ],
          ),
    );
  }

  void _tekBelgeSenkronize(BelgeModeli belge) {
    _basariMesaji(
      '${belge.baslik ?? belge.orijinalDosyaAdi} senkronize edildi',
    );
    // Gerçek senkronizasyon logic'i buraya
  }

  void _secilenBelgeleriSenkronize() {
    if (_secilenBelgeler.isEmpty) return;

    _basariMesaji('${_secilenBelgeler.length} belge senkronize edildi');
    setState(() {
      _secilenBelgeler.clear();
      _topluSecim = false;
    });
    // Gerçek senkronizasyon logic'i buraya
  }

  void _tumBelgeleriSenkronize() {
    final belgeler = _getAktifBelgeler();
    if (belgeler.isEmpty) return;

    _basariMesaji('${belgeler.length} belge senkronize edildi');
    // Gerçek senkronizasyon logic'i buraya
  }

  void _secilenBelgeleriSil() {
    if (_secilenBelgeler.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Belgeleri Sil'),
            content: Text(
              '${_secilenBelgeler.length} belgeyi silmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _basariMesaji('${_secilenBelgeler.length} belge silindi');
                  setState(() {
                    _secilenBelgeler.clear();
                    _topluSecim = false;
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  void _belgeMenusunu(BelgeModeli belge) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Senkronize Et'),
                onTap: () {
                  Navigator.of(context).pop();
                  _tekBelgeSenkronize(belge);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Detaylar'),
                onTap: () {
                  Navigator.of(context).pop();
                  _belgeDetayiniGoster(belge);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Sil'),
                onTap: () {
                  Navigator.of(context).pop();
                  // Silme logic'i
                },
              ),
            ],
          ),
    );
  }

  void _basariMesaji(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(mesaj),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Text(mesaj),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
