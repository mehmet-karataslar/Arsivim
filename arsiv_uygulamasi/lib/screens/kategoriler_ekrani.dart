import 'package:flutter/material.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../widgets/kategori_karti_widget.dart';
import '../widgets/kategori_form_dialog.dart';
import '../utils/screen_utils.dart';
import '../screens/belgeler_ekrani.dart';

class KategorilerEkrani extends StatefulWidget {
  const KategorilerEkrani({Key? key}) : super(key: key);

  @override
  State<KategorilerEkrani> createState() => _KategorilerEkraniState();
}

class _KategorilerEkraniState extends State<KategorilerEkrani>
    with TickerProviderStateMixin {
  final VeriTabaniServisi _veriTabaniServisi = VeriTabaniServisi();

  List<KategoriModeli> _kategoriler = [];
  bool _yukleniyor = true;
  bool _gridGorunum = false;
  String _aramaMetni = '';
  String _seciliSiralama = 'ad';

  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _kategorileriYukle();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _kategorileriYukle() async {
    setState(() => _yukleniyor = true);

    try {
      final kategoriler = await _veriTabaniServisi.kategorileriGetir();

      if (kategoriler.isEmpty) {
        await _defaultKategorileriEkle();
        final yeniKategoriler = await _veriTabaniServisi.kategorileriGetir();

        setState(() {
          _kategoriler = yeniKategoriler;
          _yukleniyor = false;
        });
        _animationController.forward();
        _fabAnimationController.forward();
        return;
      }

      final kategoriBelgeSayilari =
          await _veriTabaniServisi.kategoriBelgeSayilari();

      for (var kategori in kategoriler) {
        kategori.belgeSayisi = kategoriBelgeSayilari[kategori.id] ?? 0;
      }

      setState(() {
        _kategoriler = kategoriler;
        _yukleniyor = false;
      });
      _animationController.forward();
      _fabAnimationController.forward();
    } catch (e) {
      setState(() => _yukleniyor = false);
      _hataGoster('Kategoriler yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _defaultKategorileriEkle() async {
    try {
      final defaultKategoriler = KategoriModeli.ontanimliKategoriler();
      for (final kategori in defaultKategoriler) {
        await _veriTabaniServisi.kategoriEkle(kategori);
      }
    } catch (e) {
      print('Default kategoriler eklenirken hata: $e');
    }
  }

  List<KategoriModeli> get _filtrelenmisKategoriler {
    var liste =
        _kategoriler.where((kategori) {
          return kategori.kategoriAdi.toLowerCase().contains(
            _aramaMetni.toLowerCase(),
          );
        }).toList();

    switch (_seciliSiralama) {
      case 'ad':
        liste.sort((a, b) => a.kategoriAdi.compareTo(b.kategoriAdi));
        break;
      case 'belge_sayisi':
        liste.sort(
          (a, b) => (b.belgeSayisi ?? 0).compareTo(a.belgeSayisi ?? 0),
        );
        break;
      case 'tarih':
        // En yeni eklenen önce (ID'ye göre)
        liste.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
    }

    return liste;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo[50]!, Colors.purple[50]!, Colors.pink[50]!],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            if (_yukleniyor) _buildYukleniyorSliver(),
            if (!_yukleniyor) ...[
              _buildAramaVeFiltreler(),
              _buildIstatistiklerSliver(),
              if (_kategoriler.isEmpty)
                _buildBosListeSliver()
              else
                _buildKategorilerSliver(),
            ],
          ],
        ),
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo[600]!,
                Colors.purple[600]!,
                Colors.pink[600]!,
              ],
            ),
          ),
          child: const Center(
            child: Text(
              'Kategoriler',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
      actions: [_buildGorunumDegistirButonu(), _buildMenuButonu()],
    );
  }

  Widget _buildGorunumDegistirButonu() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () {
          setState(() {
            _gridGorunum = !_gridGorunum;
          });
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            _gridGorunum ? Icons.view_list_rounded : Icons.grid_view_rounded,
            key: ValueKey(_gridGorunum),
            color: Colors.white,
          ),
        ),
        tooltip: _gridGorunum ? 'Liste Görünümü' : 'Grid Görünümü',
      ),
    );
  }

  Widget _buildMenuButonu() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return PopupMenuButton<String>(
            onSelected: _menuSecimYap,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder:
                (context) => [
                  _buildMenuOgesi(
                    'toplu_sil',
                    'Toplu Silme İşlemleri',
                    Icons.delete_sweep_rounded,
                    Colors.orange[600]!,
                  ),
                  const PopupMenuDivider(),
                  _buildMenuOgesi(
                    'reset_db',
                    'Veritabanını Sıfırla',
                    Icons.refresh_rounded,
                    Colors.red[600]!,
                  ),
                ],
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildMenuOgesi(
    String value,
    String text,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildAramaVeFiltreler() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Arama kutusu
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[50]!, Colors.grey[100]!],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _aramaMetni = value),
                decoration: InputDecoration(
                  hintText: 'Kategori ara...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[500],
                  ),
                  suffixIcon:
                      _aramaMetni.isNotEmpty
                          ? IconButton(
                            onPressed: () => setState(() => _aramaMetni = ''),
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.grey[500],
                            ),
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sıralama seçenekleri
            Row(
              children: [
                Icon(Icons.sort_rounded, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sırala:',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSiralamaChip(
                          'ad',
                          'A-Z',
                          Icons.sort_by_alpha_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildSiralamaChip(
                          'belge_sayisi',
                          'Belge Sayısı',
                          Icons.description_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildSiralamaChip(
                          'tarih',
                          'En Yeni',
                          Icons.access_time_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiralamaChip(String value, String label, IconData icon) {
    final bool secili = _seciliSiralama == value;
    return GestureDetector(
      onTap: () => setState(() => _seciliSiralama = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              secili
                  ? LinearGradient(
                    colors: [Colors.indigo[400]!, Colors.purple[400]!],
                  )
                  : null,
          color: secili ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: secili ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: secili ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: secili ? Colors.white : Colors.grey[700],
                fontWeight: secili ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYukleniyorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo[400]!, Colors.purple[400]!],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [Colors.indigo[600]!, Colors.purple[600]!],
                  ).createShader(bounds),
              child: const Text(
                'Kategoriler yükleniyor...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIstatistiklerSliver() {
    final toplamKategori = _kategoriler.length;
    final toplamBelge = _kategoriler.fold(
      0,
      (sum, k) => sum + (k.belgeSayisi ?? 0),
    );
    final filtrelenmisKategoriler = _filtrelenmisKategoriler;

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildIstatistikKarti(
                    'Kategoriler',
                    '${filtrelenmisKategoriler.length}/$toplamKategori',
                    Icons.category_rounded,
                    [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildIstatistikKarti(
                    'Toplam Belge',
                    toplamBelge.toString(),
                    Icons.description_rounded,
                    [Colors.green[400]!, Colors.green[600]!],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildIstatistikKarti(
                    'Ortalama',
                    toplamKategori > 0
                        ? '${(toplamBelge / toplamKategori).toStringAsFixed(1)}'
                        : '0',
                    Icons.analytics_rounded,
                    [Colors.orange[400]!, Colors.orange[600]!],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIstatistikKarti(
    String baslik,
    String deger,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[1].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            deger,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baslik,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBosListeSliver() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[300]!, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Henüz kategori eklenmemiş',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'İlk kategorinizi eklemek için + butonuna tıklayın',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKategorilerSliver() {
    final filtrelenmisKategoriler = _filtrelenmisKategoriler;

    if (_gridGorunum) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final kategori = filtrelenmisKategoriler[index];
            return _buildGridKarti(kategori, index);
          }, childCount: filtrelenmisKategoriler.length),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final kategori = filtrelenmisKategoriler[index];
            return _buildListeKarti(kategori, index);
          }, childCount: filtrelenmisKategoriler.length),
        ),
      );
    }
  }

  Widget _buildGridKarti(KategoriModeli kategori, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
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
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _kategoriDetayGoster(kategori),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getKategoriRenkleri(index),
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        _getKategoriIkonu(kategori.kategoriAdi),
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      kategori.kategoriAdi,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getKategoriRenkleri(index),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${kategori.belgeSayisi ?? 0} belge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListeKarti(KategoriModeli kategori, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.5, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: KategoriKartiWidget(
            kategori: kategori,
            onTap: () => _kategoriDetayGoster(kategori),
            onLongPress: () => _kategoriDuzenle(kategori),
            onDuzenle: () => _kategoriDuzenle(kategori),
            onSil: () => _kategoriSil(kategori),
            onSilmeSecimi:
                (secimTipi) => _hizliSilmeSecimi(secimTipi, kategori),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return ScaleTransition(
      scale: _fabAnimationController,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo[400]!, Colors.purple[400]!],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _yeniKategoriEkle,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Kategori Ekle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  List<Color> _getKategoriRenkleri(int index) {
    final renkler = [
      [Colors.blue[400]!, Colors.blue[600]!],
      [Colors.green[400]!, Colors.green[600]!],
      [Colors.orange[400]!, Colors.orange[600]!],
      [Colors.purple[400]!, Colors.purple[600]!],
      [Colors.red[400]!, Colors.red[600]!],
      [Colors.teal[400]!, Colors.teal[600]!],
      [Colors.indigo[400]!, Colors.indigo[600]!],
      [Colors.pink[400]!, Colors.pink[600]!],
    ];
    return renkler[index % renkler.length];
  }

  IconData _getKategoriIkonu(String kategoriAdi) {
    final ikon = {
      'Faturalar': Icons.receipt_rounded,
      'Sözleşmeler': Icons.description_rounded,
      'Kimlik Belgeleri': Icons.badge_rounded,
      'Sağlık Raporları': Icons.local_hospital_rounded,
      'Eğitim Belgeleri': Icons.school_rounded,
      'Mali Belgeler': Icons.account_balance_rounded,
      'Sigorta Poliçeleri': Icons.security_rounded,
      'Resmi Evraklar': Icons.gavel_rounded,
    };
    return ikon[kategoriAdi] ?? Icons.folder_rounded;
  }

  void _kategoriDetayGoster(KategoriModeli kategori) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BelgelerEkrani(kategoriId: kategori.id),
      ),
    );
  }

  Future<void> _yeniKategoriEkle() async {
    final sonuc = await showDialog<KategoriModeli>(
      context: context,
      builder: (context) => const KategoriFormDialog(),
    );

    if (sonuc != null) {
      try {
        await _veriTabaniServisi.kategoriEkle(sonuc);
        _basariGoster('Kategori başarıyla eklendi');
        _kategorileriYukle();
      } catch (e) {
        _hataGoster('Kategori eklenirken hata oluştu: $e');
      }
    }
  }

  Future<void> _kategoriDuzenle(KategoriModeli kategori) async {
    final sonuc = await showDialog<KategoriModeli>(
      context: context,
      builder: (context) => KategoriFormDialog(kategori: kategori),
    );

    if (sonuc != null) {
      try {
        await _veriTabaniServisi.kategoriGuncelle(sonuc);
        _basariGoster('Kategori başarıyla güncellendi');
        _kategorileriYukle();
      } catch (e) {
        _hataGoster('Kategori güncellenirken hata oluştu: $e');
      }
    }
  }

  Future<void> _kategoriSil(KategoriModeli kategori) async {
    final secim = await showDialog<String>(
      context: context,
      builder: (context) => _buildSilmeSecimiDialog(kategori),
    );

    if (secim != null) {
      final onay = await _onayDialog(secim, kategori);
      if (onay == true) {
        try {
          await _silmeIsleminiGerceklestir(secim, kategori);
          _kategorileriYukle();
        } catch (e) {
          _hataGoster('Silme işlemi sırasında hata oluştu: $e');
        }
      }
    }
  }

  Widget _buildSilmeSecimiDialog(KategoriModeli kategori) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${kategori.kategoriAdi} Kategorisi',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bu kategoride ${kategori.belgeSayisi ?? 0} belge bulunuyor.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Hangi verileri silmek istiyorsunuz?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSilmeSecenegi(
            'kisiler',
            'Kişileri Sil',
            'Sadece kategoriye ait kişileri siler',
            Icons.person_remove_rounded,
            [Colors.orange[400]!, Colors.orange[600]!],
          ),
          const SizedBox(height: 12),
          _buildSilmeSecenegi(
            'belgeler',
            'Belgeleri Sil',
            'Sadece kategoriye ait belgeleri siler',
            Icons.description_rounded,
            [Colors.blue[400]!, Colors.blue[600]!],
          ),
          const SizedBox(height: 12),
          _buildSilmeSecenegi(
            'hepsi',
            'Hepsini Sil',
            'Hem kişileri hem belgeleri siler',
            Icons.delete_forever_rounded,
            [Colors.red[400]!, Colors.red[600]!],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('İptal'),
        ),
      ],
    );
  }

  Widget _buildSilmeSecenegi(
    String value,
    String baslik,
    String aciklama,
    IconData icon,
    List<Color> gradient,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        aciklama,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _onayDialog(String secim, KategoriModeli kategori) async {
    String baslik = '';
    String mesaj = '';
    List<Color> gradient = [];
    IconData icon = Icons.warning;

    switch (secim) {
      case 'kisiler':
        baslik = 'Kişileri Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki kişiler silinecek. Emin misiniz?';
        gradient = [Colors.orange[400]!, Colors.orange[600]!];
        icon = Icons.person_remove;
        break;
      case 'belgeler':
        baslik = 'Belgeleri Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki belgeler silinecek. Emin misiniz?';
        gradient = [Colors.blue[400]!, Colors.blue[600]!];
        icon = Icons.delete_sweep;
        break;
      case 'hepsi':
        baslik = 'Hepsini Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki hem kişiler hem belgeler silinecek. Emin misiniz?';
        gradient = [Colors.red[400]!, Colors.red[600]!];
        icon = Icons.delete_forever;
        break;
    }

    return await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    baslik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mesaj, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient[0].withOpacity(0.1),
                        gradient[1].withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gradient[1].withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: gradient[1], size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Bu işlem geri alınamaz!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Sil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _hizliSilmeSecimi(String secim, KategoriModeli kategori) async {
    final onay = await _onayDialog(secim, kategori);
    if (onay == true) {
      try {
        await _silmeIsleminiGerceklestir(secim, kategori);
        _kategorileriYukle();
      } catch (e) {
        _hataGoster('Silme işlemi sırasında hata oluştu: $e');
      }
    }
  }

  Future<void> _silmeIsleminiGerceklestir(
    String secim,
    KategoriModeli kategori,
  ) async {
    switch (secim) {
      case 'kisiler':
        final silinenKisiSayisi = await _veriTabaniServisi.kategoriKisileriSil(
          kategori.id!,
        );
        _basariGoster('$silinenKisiSayisi kişi başarıyla silindi');
        break;
      case 'belgeler':
        final silinenBelgeSayisi = await _veriTabaniServisi
            .kategoriBelgeleriSil(kategori.id!);
        _basariGoster('$silinenBelgeSayisi belge başarıyla silindi');
        break;
      case 'hepsi':
        final sonuc = await _veriTabaniServisi.kategoriHepsiniSil(kategori.id!);
        _basariGoster(
          '${sonuc['kisiSayisi']} kişi ve ${sonuc['belgeSayisi']} belge başarıyla silindi',
        );
        break;
    }
  }

  Future<void> _menuSecimYap(String value) async {
    if (value == 'reset_db') {
      final onay = await showDialog<bool>(
        context: context,
        builder: (context) => _buildVenitabaniSifirlaDialog(),
      );

      if (onay == true) {
        await _veriTabaniServisi.veritabaniniSifirla();
        _kategorileriYukle();
        _basariGoster('Veritabanı sıfırlandı');
      }
    } else if (value == 'toplu_sil') {
      _topluSilmeDialogGoster();
    }
  }

  Widget _buildVenitabaniSifirlaDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Veritabanını Sıfırla',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tüm veriler silinecek. Emin misiniz?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.red[100]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bu işlem geri alınamaz ve tüm verileri kalıcı olarak siler!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              'Sıfırla',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _topluSilmeDialogGoster() async {
    final secim = await showDialog<String>(
      context: context,
      builder: (context) => _buildTopluSilmeDialog(),
    );

    if (secim != null) {
      await _topluSilmeOnayDialog(secim);
    }
  }

  Widget _buildTopluSilmeDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[400]!, Colors.orange[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Toplu Silme İşlemleri',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tüm kategorilerdeki verileri silmek istediğiniz alanları seçin:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _buildTopluSilmeSecenegi(
            'tum_kisiler',
            'Tüm Kişileri Sil',
            'Bütün kategorilerdeki kişileri siler',
            Icons.person_remove_rounded,
            [Colors.orange[400]!, Colors.orange[600]!],
          ),
          const SizedBox(height: 12),
          _buildTopluSilmeSecenegi(
            'tum_belgeler',
            'Tüm Belgeleri Sil',
            'Bütün kategorilerdeki belgeleri siler',
            Icons.description_rounded,
            [Colors.blue[400]!, Colors.blue[600]!],
          ),
          const SizedBox(height: 12),
          _buildTopluSilmeSecenegi(
            'tum_veriler',
            'Tüm Verileri Sil',
            'Hem kişileri hem belgeleri siler',
            Icons.delete_forever_rounded,
            [Colors.red[400]!, Colors.red[600]!],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.red[100]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red[600], size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bu işlemler geri alınamaz ve tüm kategorileri etkiler!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('İptal'),
        ),
      ],
    );
  }

  Widget _buildTopluSilmeSecenegi(
    String value,
    String baslik,
    String aciklama,
    IconData icon,
    List<Color> gradient,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        baslik,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        aciklama,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _topluSilmeOnayDialog(String secim) async {
    String baslik = '';
    String mesaj = '';
    List<Color> gradient = [];
    IconData icon = Icons.warning;

    switch (secim) {
      case 'tum_kisiler':
        baslik = 'Tüm Kişileri Sil';
        mesaj =
            'Tüm kategorilerdeki kişiler silinecek. Bu işlem geri alınamaz!';
        gradient = [Colors.orange[400]!, Colors.orange[600]!];
        icon = Icons.person_remove;
        break;
      case 'tum_belgeler':
        baslik = 'Tüm Belgeleri Sil';
        mesaj =
            'Tüm kategorilerdeki belgeler silinecek. Bu işlem geri alınamaz!';
        gradient = [Colors.blue[400]!, Colors.blue[600]!];
        icon = Icons.delete_sweep;
        break;
      case 'tum_veriler':
        baslik = 'Tüm Verileri Sil';
        mesaj =
            'Tüm kategorilerdeki kişiler ve belgeler silinecek. Bu işlem geri alınamaz!';
        gradient = [Colors.red[400]!, Colors.red[600]!];
        icon = Icons.delete_forever;
        break;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    baslik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mesaj, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradient[0].withOpacity(0.1),
                        gradient[1].withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gradient[1].withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: gradient[1], size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Bu işlem TÜM kategorileri etkiler ve geri alınamaz!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Sil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    if (onay == true) {
      await _topluSilmeIslemiGerceklestir(secim);
    }
  }

  Future<void> _topluSilmeIslemiGerceklestir(String secim) async {
    try {
      setState(() => _yukleniyor = true);

      int toplamKisiSayisi = 0;
      int toplamBelgeSayisi = 0;

      switch (secim) {
        case 'tum_kisiler':
          for (final kategori in _kategoriler) {
            final silinenKisiSayisi = await _veriTabaniServisi
                .kategoriKisileriSil(kategori.id!);
            toplamKisiSayisi += silinenKisiSayisi;
          }
          _basariGoster('Toplam $toplamKisiSayisi kişi başarıyla silindi');
          break;

        case 'tum_belgeler':
          for (final kategori in _kategoriler) {
            final silinenBelgeSayisi = await _veriTabaniServisi
                .kategoriBelgeleriSil(kategori.id!);
            toplamBelgeSayisi += silinenBelgeSayisi;
          }
          _basariGoster('Toplam $toplamBelgeSayisi belge başarıyla silindi');
          break;

        case 'tum_veriler':
          for (final kategori in _kategoriler) {
            final sonuc = await _veriTabaniServisi.kategoriHepsiniSil(
              kategori.id!,
            );
            toplamKisiSayisi += sonuc['kisiSayisi'] ?? 0;
            toplamBelgeSayisi += sonuc['belgeSayisi'] ?? 0;
          }
          _basariGoster(
            'Toplam $toplamKisiSayisi kişi ve $toplamBelgeSayisi belge başarıyla silindi',
          );
          break;
      }

      await _kategorileriYukle();
    } catch (e) {
      _hataGoster('Toplu silme işlemi sırasında hata oluştu: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  void _basariGoster(String mesaj) {
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

  void _hataGoster(String mesaj) {
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
}
