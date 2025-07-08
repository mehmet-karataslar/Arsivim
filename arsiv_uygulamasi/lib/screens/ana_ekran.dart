import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../services/auth_servisi.dart';
import '../services/cache_servisi.dart';
import '../services/log_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../utils/screen_utils.dart';
import '../utils/sabitler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'belgeler_ekrani.dart';
import 'kategoriler_ekrani.dart';
import 'kisiler_ekrani.dart';
import 'yeni_belge_ekle_ekrani.dart';
import 'yedekleme_ekrani.dart';
import 'senkronizasyon_ekrani.dart';
import 'auth/login_screen.dart';
import '../widgets/belge_karti_widget.dart';
import 'tarayici_ekrani.dart';

// Ana dashboard ve navigasyon
class AnaEkran extends StatefulWidget {
  const AnaEkran({Key? key}) : super(key: key);

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> with TickerProviderStateMixin {
  int _secilenTab = 0;
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final CacheServisi _cacheServisi = CacheServisi();
  final LogServisi _logServisi = LogServisi.instance;

  int _toplamBelgeSayisi = 0;
  int _toplamDosyaBoyutu = 0;
  List<BelgeModeli> _sonBelgeler = [];
  List<Map<String, dynamic>> _detayliSonBelgeler = [];
  bool _yukleniyor = true;

  List<BelgeModeli> _tumBelgeler = [];
  List<BelgeModeli> _filtrelenmsBelgeler = [];
  List<Map<String, dynamic>> _detayliBelgeler = [];
  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  String _aramaMetni = '';
  bool _dahaFazlaVarMi = true;

  int _mevcutSayfa = 0;
  final int _sayfaBoyutu = 20;
  bool _dahaFazlaYukleniyor = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _verileriYukle();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      // Cache'i bypassla ve her zaman gerçek verileri al
      _logServisi.info('Ana ekran verileri yükleniyor...');

      final futures = await Future.wait([
        _veriTabani.belgeIstatistikleriGetir(),
        _veriTabani.onceakliBelgeleriDetayliGetir(limit: 5),
      ]);

      if (!mounted) return;

      final istatistikler = futures[0] as Map<String, dynamic>;
      final detayliBelgeler = futures[1] as List<Map<String, dynamic>>;

      // Detaylı belgelerden normal belge modellerini oluştur
      final sonBelgeler =
          detayliBelgeler.map((data) => BelgeModeli.fromMap(data)).toList();

      setState(() {
        _toplamBelgeSayisi = istatistikler['toplam_belge_sayisi'] ?? 0;
        _toplamDosyaBoyutu = istatistikler['toplam_dosya_boyutu'] ?? 0;
        _sonBelgeler = sonBelgeler;
        _detayliSonBelgeler = detayliBelgeler;
        _yukleniyor = false;
      });

      _logServisi.info(
        'Ana ekran verileri yüklendi: $_toplamBelgeSayisi belge, ${(_toplamDosyaBoyutu / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Veriler yüklenirken hata oluştu: $e');
      _logServisi.error('Ana ekran veri yükleme hatası', e);
    }
  }

  // Verileri yenileme metodu
  Future<void> _verileriYenile() async {
    try {
      // Animasyonu sıfırla
      _animationController.reset();

      // Gerçek verilerle yenile
      await _verileriYukle();

      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Veriler yenilendi! $_toplamBelgeSayisi belge bulundu.'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _hataGoster('Yenileme sırasında hata oluştu: $e');
    }
  }

  // Pull-to-refresh metodu
  Future<void> _onRefresh() async {
    await _verileriYenile();
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _veriTabaniKonumunuGoster() async {
    try {
      final bilgiler = await _veritabaniBilgileriAl();
      final platformAciklama = await _platformYolAciklamasiAl();

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.storage_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Veritabanı Konumu'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      color: Colors.orange.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📁 Dosya Bilgileri',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildBilgiSatiri(
                              'Dosya Adı',
                              bilgiler['dosya_adi'],
                            ),
                            _buildBilgiSatiri(
                              'Boyut',
                              '${bilgiler['boyut_mb']} MB',
                            ),
                            _buildBilgiSatiri(
                              'Versiyon',
                              bilgiler['versiyon'].toString(),
                            ),
                            _buildBilgiSatiri(
                              'Durum',
                              bilgiler['var_mi'] ? 'Mevcut' : 'Bulunamadı',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.blue.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📍 Konum Bilgileri',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              bilgiler['tam_yol'],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.green.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💡 Platform Açıklaması',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              platformAciklama,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            ),
      );
    } catch (e) {
      _hataGoster('Veritabanı konumu alınamadı: $e');
    }
  }

  Widget _buildBilgiSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$baslik:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(deger, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  /// Çıkış yap işlemi
  void _cikisYap() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Çıkış Yap'),
            content: const Text(
              'Uygulamadan çıkmak istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  // Çıkış işlemi
                  await AuthServisi.instance.logout();

                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child:
                    _yukleniyor
                        ? const Center(child: CircularProgressIndicator())
                        : _secilenTab == 0
                        ? RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: _buildTabContent(),
                        )
                        : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildModernBottomNav(),
      floatingActionButton: _secilenTab == 0 ? _buildModernFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arşiv Uygulaması',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  'Belgelerinizi organize edin',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
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
            child: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _secilenTab = 1; // Belgeler sekmesine git
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Yenileme butonu - sadece desktop platformlarda göster
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            Container(
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
              child: IconButton(
                icon:
                    _yukleniyor
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                        : const Icon(Icons.refresh),
                onPressed: _yukleniyor ? null : _verileriYenile,
                tooltip: 'Yenile',
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Çıkış yap butonu
          Container(
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
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _cikisYap,
              tooltip: 'Çıkış Yap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _secilenTab,
        onTap: (index) {
          setState(() {
            _secilenTab = index;
          });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Belgeler',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.category_rounded),
            label: 'Kategoriler',
          ),
          // Tarayıcı sekmesi sadece Windows'da görünür
          if (Platform.isWindows)
            const BottomNavigationBarItem(
              icon: Icon(Icons.scanner_rounded),
              label: 'Tarayıcı',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Kişiler',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.sync_rounded),
            label: 'Senkron',
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _yeniBelgeEkle,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildTabContent() {
    if (Platform.isWindows) {
      // Windows'da tarayıcı sekmesi var
      switch (_secilenTab) {
        case 0:
          return _buildAnaEkran();
        case 1:
          return _buildBelgelerEkrani();
        case 2:
          return _buildKategorilerEkrani();
        case 3:
          return const TarayiciEkrani();
        case 4:
          return _buildKisilerEkrani();
        case 5:
          return _buildSenkronizasyonEkrani();
        default:
          return _buildAnaEkran();
      }
    } else {
      // Diğer platformlarda tarayıcı sekmesi yok
      switch (_secilenTab) {
        case 0:
          return _buildAnaEkran();
        case 1:
          return _buildBelgelerEkrani();
        case 2:
          return _buildKategorilerEkrani();
        case 3:
          return _buildKisilerEkrani();
        case 4:
          return _buildSenkronizasyonEkrani();
        default:
          return _buildAnaEkran();
      }
    }
  }

  Widget _buildAnaEkran() {
    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _verileriYukle,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(
            isDesktop ? 32.0 : 20.0,
          ), // PC'de daha geniş padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIstatistikKartlari(),
              SizedBox(height: isDesktop ? 24 : 32),
              _buildHizliIslemler(), // Hızlı işlemler üste taşındı
              SizedBox(height: isDesktop ? 24 : 32),
              _buildSonBelgeler(), // Son belgeler alta taşındı
              const SizedBox(height: 100), // FAB için boşluk
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIstatistikKartlari() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genel Bakış',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernIstatistikKarti(
                'Toplam Belge',
                _toplamBelgeSayisi.toString(),
                Icons.description_rounded,
                [Colors.blue, Colors.lightBlue],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernIstatistikKarti(
                'Toplam Boyut',
                ScreenUtils.formatFileSize(_toplamDosyaBoyutu),
                Icons.storage_rounded,
                [Colors.green, Colors.lightGreen],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildVeriTabaniKonumKarti()),
          ],
        ),
      ],
    );
  }

  Widget _buildVeriTabaniKonumKarti() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.deepOrange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: _veriTabaniKonumunuGoster,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 24,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Veritabanı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Konum Göster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dokun ve gör',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernIstatistikKarti(
    String baslik,
    String deger,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradientColors.first.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              baslik,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              deger,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSonBelgeler() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Son Belgeler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _secilenTab = 1; // Belgeler sekmesine git
                });
              },
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_sonBelgeler.isEmpty && !_yukleniyor)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz belge eklenmemiş',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İlk belgenizi eklemek için + butonuna dokunun',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_yukleniyor)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Son belgeler yükleniyor...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sonBelgeler.length,
            itemBuilder: (context, index) {
              final belge = _sonBelgeler[index];

              // Detaylı veri varsa onu kullan
              Map<String, dynamic>? extraData;
              if (index < _detayliSonBelgeler.length) {
                extraData = _detayliSonBelgeler[index];
              }

              return OptimizedBelgeKartiWidget(
                belge: belge,
                extraData: extraData,
                compactMode: true,
                onTap: () {
                  setState(() {
                    _secilenTab = 1; // Belgeler sekmesine git
                  });
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildHizliIslemler() {
    // PC için farklı layout
    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı İşlemler',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        if (isDesktop)
          // PC için kompakt grid layout
          GridView.count(
            crossAxisCount: 4, // PC'de 4 sütun
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2, // Daha kompakt
            children: [
              _buildKompaktHizliIslemKarti(
                'Belge Ekle',
                Icons.add_circle_rounded,
                [Colors.blue, Colors.lightBlue],
                () => _yeniBelgeEkle(),
              ),
              _buildKompaktHizliIslemKarti(
                'Belgeler',
                Icons.folder_rounded,
                [Colors.green, Colors.lightGreen],
                () => setState(() => _secilenTab = 1),
              ),
              _buildKompaktHizliIslemKarti(
                'Kategoriler',
                Icons.category_rounded,
                [Colors.orange, Colors.deepOrange],
                () => setState(() => _secilenTab = 2),
              ),
              _buildKompaktHizliIslemKarti('Kişiler', Icons.people_rounded, [
                Colors.purple,
                Colors.deepPurple,
              ], () => setState(() => _secilenTab = 4)),
            ],
          )
        else
          // Mobil için orijinal layout
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildHizliIslemKarti('Belge Ekle', Icons.add_circle_rounded, [
                Colors.blue,
                Colors.lightBlue,
              ], () => _yeniBelgeEkle()),
              _buildHizliIslemKarti(
                'Belgeler',
                Icons.folder_rounded,
                [Colors.green, Colors.lightGreen],
                () => setState(() => _secilenTab = 1),
              ),
              _buildHizliIslemKarti(
                'Kategoriler',
                Icons.category_rounded,
                [Colors.orange, Colors.deepOrange],
                () => setState(() => _secilenTab = 2),
              ),
              _buildHizliIslemKarti('Kişiler', Icons.people_rounded, [
                Colors.purple,
                Colors.deepPurple,
              ], () => setState(() => _secilenTab = 4)),
            ],
          ),

        // PC için ek modüller
        if (isDesktop) ...[
          const SizedBox(height: 24),
          Text(
            'Diğer Modüller',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModulKarti(
                  'Senkronizasyon',
                  'Cihazlar arası veri senkronizasyonu',
                  Icons.sync_rounded,
                  [Colors.teal, Colors.cyan],
                  () => setState(() => _secilenTab = 5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModulKarti(
                  'Yedekleme',
                  'Kişi ve kategori bazında yedekleme',
                  Icons.backup_rounded,
                  [Colors.green, Colors.lightGreen],
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const YedeklemeEkrani(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(), // Boş alan için
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(), // Boş alan için
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHizliIslemKarti(
    String baslik,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gradientColors.first.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                baslik,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PC için kompakt buton
  Widget _buildKompaktHizliIslemKarti(
    String baslik,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gradientColors.first.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                baslik,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PC için modül kartı
  Widget _buildModulKarti(
    String baslik,
    String aciklama,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gradientColors.first.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aciklama,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBelgelerEkrani() {
    return const BelgelerEkrani();
  }

  Widget _buildKategorilerEkrani() {
    return const KategorilerEkrani();
  }

  Widget _buildKisilerEkrani() {
    return const KisilerEkrani();
  }

  Widget _buildSenkronizasyonEkrani() {
    return const SenkronizasyonEkrani();
  }

  Future<void> _yeniBelgeEkle() async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const YeniBelgeEkleEkrani()),
    );

    // Eğer başarılı bir şekilde belge eklendiyse verileri yenile
    if (sonuc == true) {
      _verileriYukle();
    }
  }

  /// Veritabanı bilgilerini al
  Future<Map<String, dynamic>> _veritabaniBilgileriAl() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, Sabitler.VERITABANI_ADI);

    final varMi = await File(dbPath).exists();
    final boyut = varMi ? await File(dbPath).length() : 0;

    return {
      'tam_yol': dbPath,
      'klasor': documentsDirectory.path,
      'dosya_adi': Sabitler.VERITABANI_ADI,
      'var_mi': varMi,
      'boyut_byte': boyut,
      'boyut_mb': (boyut / 1024 / 1024).toStringAsFixed(2),
      'versiyon': Sabitler.VERITABANI_VERSIYONU,
    };
  }

  /// Platform yol açıklaması al
  Future<String> _platformYolAciklamasiAl() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final klasor = documentsDirectory.path;

    if (Platform.isAndroid) {
      return '''
🤖 ANDROID:
- Konum: $klasor
- Uygulama verisi: /data/data/com.example.arsiv_uygulamasi/files/Documents/
- Sadece uygulama erişebilir (private storage)
- Uygulama silinirse veritabanı da silinir
''';
    } else if (Platform.isWindows) {
      return '''
🖥️ WINDOWS:
- Konum: $klasor
- Genellikle: C:\\Users\\[Username]\\Documents\\
- Windows Explorer'dan erişilebilir
- Uygulama silinse bile veritabanı kalır
''';
    } else if (Platform.isLinux) {
      return '''
🐧 LINUX:
- Konum: $klasor
- Genellikle: /home/[username]/Documents/
- Dosya yöneticisinden erişilebilir
- Uygulama silinse bile veritabanı kalır
''';
    } else if (Platform.isMacOS) {
      return '''
🍎 MACOS:
- Konum: $klasor
- Genellikle: /Users/[username]/Documents/
- Finder'dan erişilebilir
- Uygulama silinse bile veritabanı kalır
''';
    } else {
      return '''
📱 PLATFORM BİLİNMİYOR:
- Konum: $klasor
- Platform-specific açıklama mevcut değil
''';
    }
  }
}
