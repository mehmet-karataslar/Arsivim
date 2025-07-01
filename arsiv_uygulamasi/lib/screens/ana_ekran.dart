import 'package:flutter/material.dart';
import 'dart:io';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../utils/yardimci_fonksiyonlar.dart';
import 'belgeler_ekrani.dart';
import 'kategoriler_ekrani.dart';
import 'kisiler_ekrani.dart';
import 'yeni_belge_ekle_ekrani.dart';
import 'ayarlar_ekrani.dart';
import 'usb_senkron_ekrani.dart';

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

  int _toplamBelgeSayisi = 0;
  int _toplamDosyaBoyutu = 0;
  List<BelgeModeli> _sonBelgeler = [];
  bool _yukleniyor = true;

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
    setState(() {
      _yukleniyor = true;
    });

    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final dosyaBoyutu = await _veriTabani.toplamDosyaBoyutu();
      final sonBelgeler = await _veriTabani.belgeleriGetir(limit: 5);

      setState(() {
        _toplamBelgeSayisi = belgeSayisi;
        _toplamDosyaBoyutu = dosyaBoyutu;
        _sonBelgeler = sonBelgeler;
        _yukleniyor = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Veriler yüklenirken hata oluştu: $e');
    }
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
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AyarlarEkrani(),
                  ),
                );
              },
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Belgeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_rounded),
            label: 'Kategoriler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: 'Kişiler',
          ),
          BottomNavigationBarItem(
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
        return _buildSenkronEkrani();
      default:
        return _buildAnaEkran();
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
              _buildSonBelgeler(),
              SizedBox(height: isDesktop ? 24 : 32),
              _buildHizliIslemler(),
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
                YardimciFonksiyonlar.dosyaBoyutuFormatla(_toplamDosyaBoyutu),
                Icons.storage_rounded,
                [Colors.green, Colors.lightGreen],
              ),
            ),
          ],
        ),
      ],
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
        if (_sonBelgeler.isEmpty)
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
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sonBelgeler.length,
            itemBuilder: (context, index) {
              return _buildModernBelgeKarti(_sonBelgeler[index]);
            },
          ),
      ],
    );
  }

  Widget _buildModernBelgeKarti(BelgeModeli belge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            belge.dosyaTipiSimgesi,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          belge.baslik ?? belge.orijinalDosyaAdi,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${belge.dosyaTipi.toUpperCase()} • ${belge.formatliDosyaBoyutu}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: () {
          setState(() {
            _secilenTab = 1; // Belgeler sekmesine git
          });
        },
      ),
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
              ], () => setState(() => _secilenTab = 3)),
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
              ], () => setState(() => _secilenTab = 3)),
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
                  () => setState(() => _secilenTab = 4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModulKarti(
                  'Ayarlar',
                  'Uygulama ayarları ve konfigürasyon',
                  Icons.settings_rounded,
                  [Colors.grey, Colors.blueGrey],
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AyarlarEkrani(),
                    ),
                  ),
                ),
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

  Widget _buildSenkronEkrani() {
    return const UsbSenkronEkrani();
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
}
