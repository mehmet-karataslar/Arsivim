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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.bounceOut),
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
      _hataGoster('Kategoriler yüklenirken hata: $e');
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
        liste.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
    }
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 600;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.cyan[100]!,
                  Colors.pink[50]!,
                  Colors.yellow[50]!,
                ],
              ),
            ),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(isDesktop),
                if (_yukleniyor) _buildYukleniyorSliver(),
                if (!_yukleniyor) ...[
                  _buildSearchAndFilter(isDesktop),
                  _buildStatsSliver(isDesktop),
                  if (_kategoriler.isEmpty)
                    _buildEmptyStateSliver()
                  else
                    _buildCategoriesSliver(isDesktop),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  SliverAppBar _buildAppBar(bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 180 : 140,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple[700]!,
                Colors.pink[600]!,
                Colors.orange[600]!,
              ],
            ),
          ),
          child: Center(
            child: Text(
              'Kategoriler',
              style: TextStyle(
                fontSize: isDesktop ? 44 : 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [_buildViewToggleButton(), _buildMenuButton()],
    );
  }

  Widget _buildViewToggleButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () => setState(() => _gridGorunum = !_gridGorunum),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            _gridGorunum ? Icons.view_list_rounded : Icons.grid_view_rounded,
            key: ValueKey(_gridGorunum),
            color: Colors.white,
            size: 28,
          ),
        ),
        tooltip: _gridGorunum ? 'Liste Görünümü' : 'Grid Görünümü',
      ),
    );
  }

  Widget _buildMenuButton() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        onSelected: _menuSecimYap,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 28,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: 'toplu_sil',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Text(
                      'Toplu Silme',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_db',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Text(
                      'Veritabanını Sıfırla',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
      ),
    );
  }

  SliverToBoxAdapter _buildSearchAndFilter(bool isDesktop) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(isDesktop ? 24 : 16),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.cyan[50]!, Colors.blue[50]!],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _aramaMetni = value),
                decoration: InputDecoration(
                  hintText: 'Kategori ara...',
                  hintStyle: TextStyle(color: Colors.blue[300]),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.blue[400],
                  ),
                  suffixIcon:
                      _aramaMetni.isNotEmpty
                          ? IconButton(
                            onPressed: () => setState(() => _aramaMetni = ''),
                            icon: Icon(
                              Icons.clear_rounded,
                              color: Colors.blue[400],
                            ),
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isDesktop ? 18 : 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.sort_rounded, color: Colors.purple[600], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Sırala:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip(
                          'ad',
                          'A-Z',
                          Icons.sort_by_alpha_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip(
                          'belge_sayisi',
                          'Belge Sayısı',
                          Icons.description_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildSortChip(
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

  Widget _buildSortChip(String value, String label, IconData icon) {
    final isSelected = _seciliSiralama == value;
    return GestureDetector(
      onTap: () => setState(() => _seciliSiralama = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? LinearGradient(
                    colors: [Colors.purple[600]!, Colors.pink[500]!],
                  )
                  : LinearGradient(
                    colors: [Colors.grey[100]!, Colors.grey[200]!],
                  ),
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.purple[200]!,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildStatsSliver(bool isDesktop) {
    final toplamKategori = _kategoriler.length;
    final toplamBelge = _kategoriler.fold(
      0,
      (sum, k) => sum + (k.belgeSayisi ?? 0),
    );
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Kategoriler',
                    '${_filtrelenmisKategoriler.length}/$toplamKategori',
                    Icons.category_rounded,
                    [Colors.cyan[600]!, Colors.blue[700]!],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Belgeler',
                    toplamBelge.toString(),
                    Icons.description_rounded,
                    [Colors.pink[600]!, Colors.red[600]!],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Ortalama',
                    toplamKategori > 0
                        ? (toplamBelge / toplamKategori).toStringAsFixed(1)
                        : '0',
                    Icons.analytics_rounded,
                    [Colors.yellow[700]!, Colors.orange[600]!],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors[1].withOpacity(0.4),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  SliverFillRemaining _buildYukleniyorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.pink[600]!],
                ),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Yükleniyor...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverFillRemaining _buildEmptyStateSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow[600]!, Colors.orange[600]!],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kategori Yok',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni kategori eklemek için + butonuna dokunun',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCategoriesSliver(bool isDesktop) {
    final categories = _filtrelenmisKategoriler;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child:
            _gridGorunum
                ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 4 : 2,
                    childAspectRatio: isDesktop ? 1.2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: categories.length,
                  itemBuilder:
                      (context, index) =>
                          _buildGridCard(categories[index], index),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  itemBuilder:
                      (context, index) =>
                          _buildListCard(categories[index], index),
                ),
      ),
    );
  }

  Widget _buildGridCard(KategoriModeli kategori, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () => _kategoriDetayGoster(kategori),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _getCategoryGradient(index)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(
                    _getKategoriIkonu(kategori.kategoriAdi),
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  kategori.kategoriAdi,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${kategori.belgeSayisi ?? 0} belge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(KategoriModeli kategori, int index) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _fabAnimationController,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink[600]!, Colors.purple[600]!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple[300]!,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _yeniKategoriEkle,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          label: const Text(
            'Kategori Ekle',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getCategoryGradient(int index) {
    final gradients = [
      [Colors.cyan[600]!, Colors.blue[700]!],
      [Colors.pink[600]!, Colors.red[600]!],
      [Colors.yellow[600]!, Colors.orange[700]!],
      [Colors.purple[600]!, Colors.indigo[700]!],
      [Colors.green[600]!, Colors.teal[700]!],
      [Colors.amber[600]!, Colors.orange[600]!],
      [Colors.blue[600]!, Colors.cyan[700]!],
      [Colors.red[600]!, Colors.pink[700]!],
    ];
    return gradients[index % gradients.length];
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
        _hataGoster('Kategori eklenemedi: $e');
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
        _hataGoster('Kategori güncellenemedi: $e');
      }
    }
  }

  Future<void> _kategoriSil(KategoriModeli kategori) async {
    final secim = await showDialog<String>(
      context: context,
      builder: (context) => _buildDeleteDialog(kategori),
    );
    if (secim != null) {
      final onay = await _showConfirmDialog(secim, kategori);
      if (onay == true) {
        try {
          await _executeDelete(secim, kategori);
          _kategorileriYukle();
        } catch (e) {
          _hataGoster('Silme işlemi başarısız: $e');
        }
      }
    }
  }

  Widget _buildDeleteDialog(KategoriModeli kategori) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[600]!, Colors.pink[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              '${kategori.kategoriAdi} Sil',
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.cyan[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${kategori.belgeSayisi ?? 0} belge içeriyor',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDeleteOption(
            'kisiler',
            'Kişileri Sil',
            Icons.person_remove_rounded,
            [Colors.orange[400]!, Colors.orange[600]!],
          ),
          const SizedBox(height: 8),
          _buildDeleteOption(
            'belgeler',
            'Belgeleri Sil',
            Icons.description_rounded,
            [Colors.blue[400]!, Colors.blue[600]!],
          ),
          const SizedBox(height: 8),
          _buildDeleteOption(
            'hepsi',
            'Hepsini Sil',
            Icons.delete_forever_rounded,
            [Colors.red[400]!, Colors.red[600]!],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildDeleteOption(
    String value,
    String label,
    IconData icon,
    List<Color> colors,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String secim, KategoriModeli kategori) {
    String title = '';
    String message = '';
    List<Color> colors = [Colors.red[600]!, Colors.red[400]!];
    IconData icon = Icons.warning_rounded;
    switch (secim) {
      case 'kisiler':
        title = 'Kişileri Sil';
        message =
            '${kategori.kategoriAdi} kategorisindeki kişiler silinecek. Onaylıyor musunuz?';
        colors = [Colors.orange[600]!, Colors.orange[400]!];
        icon = Icons.person_remove_rounded;
        break;
      case 'belgeler':
        title = 'Belgeleri Sil';
        message =
            '${kategori.kategoriAdi} kategorisindeki belgeler silinecek. Onaylıyor musunuz?';
        colors = [Colors.blue[600]!, Colors.blue[400]!];
        icon = Icons.description_rounded;
        break;
      case 'hepsi':
        title = 'Hepsini Sil';
        message =
            '${kategori.kategoriAdi} kategorisindeki tüm veriler silinecek. Onaylıyor musunuz?';
        colors = [Colors.red[600]!, Colors.red[400]!];
        icon = Icons.delete_forever_rounded;
        break;
    }
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      title,
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
              children: [
                Text(message, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.1),
                        colors[1].withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors[1].withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors[1], size: 24),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Bu işlem geri alınamaz!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[0],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _executeDelete(String secim, KategoriModeli kategori) async {
    switch (secim) {
      case 'kisiler':
        final count = await _veriTabaniServisi.kategoriKisileriSil(
          kategori.id!,
        );
        _basariGoster('$count kişi başarıyla silindi');
        break;
      case 'belgeler':
        final count = await _veriTabaniServisi.kategoriBelgeleriSil(
          kategori.id!,
        );
        _basariGoster('$count belge başarıyla silindi');
        break;
      case 'hepsi':
        final result = await _veriTabaniServisi.kategoriHepsiniSil(
          kategori.id!,
        );
        _basariGoster(
          '${result['kisiSayisi']} kişi ve ${result['belgeSayisi']} belge silindi',
        );
        break;
    }
  }

  Future<void> _hizliSilmeSecimi(String secim, KategoriModeli kategori) async {
    final onay = await _showConfirmDialog(secim, kategori);
    if (onay == true) {
      try {
        await _executeDelete(secim, kategori);
        _kategorileriYukle();
      } catch (e) {
        _hataGoster('Silme işlemi başarısız: $e');
      }
    }
  }

  Future<void> _menuSecimYap(String value) async {
    if (value == 'reset_db') {
      final onay = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.pink[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Veritabanını Sıfırla',
                        style: TextStyle(
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
                children: [
                  const Text('Tüm veriler silinecek. Onaylıyor musunuz?'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[50]!, Colors.pink[50]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.red[600]),
                        const SizedBox(width: 12),
                        const Flexible(
                          child: Text(
                            'Bu işlem geri alınamaz!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sıfırla',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      if (onay == true) {
        await _veriTabaniServisi.veritabaniniSifirla();
        _kategorileriYukle();
        _basariGoster('Veritabanı sıfırlandı');
      }
    } else if (value == 'toplu_sil') {
      final secim = await showDialog<String>(
        context: context,
        builder: (context) => _buildBulkDeleteDialog(),
      );
      if (secim != null) {
        await _topluSilmeOnayDialog(secim);
      }
    }
  }

  Widget _buildBulkDeleteDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[600]!, Colors.yellow[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Toplu Silme',
                style: TextStyle(
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
        children: [
          const Text(
            'Silmek istediğiniz verileri seçin:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildDeleteOption(
            'tum_kisiler',
            'Tüm Kişileri Sil',
            Icons.person_remove_rounded,
            [Colors.orange[400]!, Colors.orange[600]!],
          ),
          const SizedBox(height: 8),
          _buildDeleteOption(
            'tum_belgeler',
            'Tüm Belgeleri Sil',
            Icons.description_rounded,
            [Colors.blue[400]!, Colors.blue[600]!],
          ),
          const SizedBox(height: 8),
          _buildDeleteOption(
            'tum_veriler',
            'Tüm Verileri Sil',
            Icons.delete_forever_rounded,
            [Colors.red[400]!, Colors.red[600]!],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[50]!, Colors.pink[50]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red[600]),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Bu işlem tüm kategorileri etkiler!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Future<void> _topluSilmeOnayDialog(String secim) async {
    String title = '';
    String message = '';
    List<Color> colors = [Colors.red[600]!, Colors.red[400]!];
    IconData icon = Icons.warning_rounded;
    switch (secim) {
      case 'tum_kisiler':
        title = 'Tüm Kişileri Sil';
        message = 'Tüm kategorilerdeki kişiler silinecek. Onaylıyor musunuz?';
        colors = [Colors.orange[600]!, Colors.orange[400]!];
        icon = Icons.person_remove_rounded;
        break;
      case 'tum_belgeler':
        title = 'Tüm Belgeleri Sil';
        message = 'Tüm kategorilerdeki belgeler silinecek. Onaylıyor musunuz?';
        colors = [Colors.blue[600]!, Colors.blue[400]!];
        icon = Icons.description_rounded;
        break;
      case 'tum_veriler':
        title = 'Tüm Verileri Sil';
        message =
            'Tüm kategorilerdeki tüm veriler silinecek. Onaylıyor musunuz?';
        colors = [Colors.red[600]!, Colors.red[400]!];
        icon = Icons.delete_forever_rounded;
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    title,
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
                Text(message),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors[0].withOpacity(0.1),
                        colors[1].withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors[1].withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors[1], size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Bu işlem geri alınamaz!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[0],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Sil', style: TextStyle(color: Colors.white)),
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
            toplamKisiSayisi += await _veriTabaniServisi.kategoriKisileriSil(
              kategori.id!,
            );
          }
          _basariGoster('$toplamKisiSayisi kişi silindi');
          break;
        case 'tum_belgeler':
          for (final kategori in _kategoriler) {
            toplamBelgeSayisi += await _veriTabaniServisi.kategoriBelgeleriSil(
              kategori.id!,
            );
          }
          _basariGoster('$toplamBelgeSayisi belge silindi');
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
            '$toplamKisiSayisi kişi ve $toplamBelgeSayisi belge silindi',
          );
          break;
      }
      await _kategorileriYukle();
    } catch (e) {
      _hataGoster('Toplu silme hatası: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
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
            const Icon(Icons.error_rounded, color: Colors.white),
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
