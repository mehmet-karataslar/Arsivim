import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';

class YeniBelgeEkleEkrani extends StatefulWidget {
  final BelgeModeli? duzenlenecekBelge;

  const YeniBelgeEkleEkrani({Key? key, this.duzenlenecekBelge})
    : super(key: key);

  @override
  State<YeniBelgeEkleEkrani> createState() => _YeniBelgeEkleEkraniState();
}

class _YeniBelgeEkleEkraniState extends State<YeniBelgeEkleEkrani>
    with TickerProviderStateMixin {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();

  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();
  final TextEditingController _etiketlerController = TextEditingController();

  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  List<dynamic> _secilenDosyalar = [];
  List<String> _etiketler = [];

  KategoriModeli? _secilenKategori;
  KisiModeli? _secilenKisi;
  String? _secilenDosyaTuru;
  bool _yukleniyor = true;
  bool _dosyalarIsleniyor = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Dosya türleri
  final Map<String, Map<String, dynamic>> _dosyaTurleri = {
    'pdf': {
      'ad': 'PDF Belgesi',
      'icon': Icons.picture_as_pdf,
      'color': Colors.red,
      'uzantilar': ['pdf'],
    },
    'doc': {
      'ad': 'Word Belgesi',
      'icon': Icons.description,
      'color': Colors.blue,
      'uzantilar': ['doc', 'docx'],
    },
    'xls': {
      'ad': 'Excel Tablosu',
      'icon': Icons.table_chart,
      'color': Colors.green,
      'uzantilar': ['xls', 'xlsx'],
    },
    'ppt': {
      'ad': 'PowerPoint Sunumu',
      'icon': Icons.slideshow,
      'color': Colors.orange,
      'uzantilar': ['ppt', 'pptx'],
    },
    'jpg': {
      'ad': 'Resim Dosyası',
      'icon': Icons.image,
      'color': Colors.purple,
      'uzantilar': ['jpg', 'jpeg', 'png', 'gif', 'bmp'],
    },
    'video': {
      'ad': 'Video Dosyası',
      'icon': Icons.video_library,
      'color': Colors.indigo,
      'uzantilar': ['mp4', 'avi', 'mkv', 'mov'],
    },
    'audio': {
      'ad': 'Ses Dosyası',
      'icon': Icons.audiotrack,
      'color': Colors.teal,
      'uzantilar': ['mp3', 'wav', 'flac', 'aac'],
    },
    'archive': {
      'ad': 'Arşiv Dosyası',
      'icon': Icons.archive,
      'color': Colors.brown,
      'uzantilar': ['zip', 'rar', '7z', 'tar'],
    },
    'other': {
      'ad': 'Diğer',
      'icon': Icons.insert_drive_file,
      'color': Colors.grey,
      'uzantilar': ['txt', 'csv', 'json', 'xml'],
    },
  };

  bool get _duzenlemeModundaMi => widget.duzenlenecekBelge != null;

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _verileriYukle();
    _duzenlemeVerileriniYukle();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _etiketlerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _duzenlemeVerileriniYukle() {
    if (_duzenlemeModundaMi) {
      final belge = widget.duzenlenecekBelge!;
      _baslikController.text = belge.baslik ?? '';
      _aciklamaController.text = belge.aciklama ?? '';
      _etiketler = belge.etiketler ?? [];
      _etiketlerController.text = _etiketler.join(', ');

      // Dosya türünü belirle
      _secilenDosyaTuru = _dosyaTurunuBelirle(belge.dosyaTipi);
    }
  }

  String _dosyaTurunuBelirle(String uzanti) {
    for (final entry in _dosyaTurleri.entries) {
      if (entry.value['uzantilar'].contains(uzanti.toLowerCase())) {
        return entry.key;
      }
    }
    return 'other';
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      final kategoriler = await _veriTabani.kategorileriGetir();
      final kisiler = await _veriTabani.kisileriGetir();

      setState(() {
        _kategoriler = kategoriler;
        _kisiler = kisiler;
        _yukleniyor = false;
      });

      // Düzenleme modunda seçili değerleri ayarla
      if (_duzenlemeModundaMi) {
        final belge = widget.duzenlenecekBelge!;
        _secilenKategori =
            kategoriler.where((k) => k.id == belge.kategoriId).firstOrNull;
        _secilenKisi = kisiler.where((k) => k.id == belge.kisiId).firstOrNull;
      }

      _animationController.forward();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _yukleniyor ? _buildYukleniyorWidget() : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _duzenlemeModundaMi ? 'Belge Düzenle' : 'Yeni Belge Ekle',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _duzenlemeModundaMi
                      ? 'Belge bilgilerini güncelleyin'
                      : 'Yeni belgelerinizi arşivleyin',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if ((_secilenDosyalar.isNotEmpty || _duzenlemeModundaMi) &&
              !_dosyalarIsleniyor)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _belgelerEkle,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'KAYDET',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYukleniyorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Veriler yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Dosya seçme kartı (sadece yeni ekleme modunda)
              if (!_duzenlemeModundaMi) _buildDosyaSecmeKarti(),
              if (!_duzenlemeModundaMi) const SizedBox(height: 20),

              // Seçilen dosyalar
              if (_secilenDosyalar.isNotEmpty) _buildSecilenDosyalarKarti(),
              if (_secilenDosyalar.isNotEmpty) const SizedBox(height: 20),

              // Dosya türü seçimi
              if (!_duzenlemeModundaMi) _buildDosyaTuruSecimi(),
              if (!_duzenlemeModundaMi) const SizedBox(height: 20),

              // Belge bilgileri kartı
              _buildBelgeBilgileriKarti(),
              const SizedBox(height: 20),

              // Kategori ve kişi seçimi kartı
              _buildKategoriVeKisiKarti(),
              const SizedBox(height: 20),

              // Etiketler kartı
              _buildEtiketlerKarti(),
              const SizedBox(height: 100), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDosyaSecmeKarti() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.purple.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _dosyaEkle,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _secilenDosyalar.isEmpty
                      ? 'Dosya Seçin'
                      : '${_secilenDosyalar.length} Dosya Seçildi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Birden fazla dosya seçebilirsiniz',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecilenDosyalarKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Seçilen Dosyalar (${_secilenDosyalar.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _secilenDosyalar.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final dosya = _secilenDosyalar[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.insert_drive_file,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dosya.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(dosya.size / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _secilenDosyalar.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDosyaTuruSecimi() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dosya Türü',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _dosyaTurleri.length,
              itemBuilder: (context, index) {
                final entry = _dosyaTurleri.entries.elementAt(index);
                final key = entry.key;
                final value = entry.value;
                final secili = _secilenDosyaTuru == key;

                return Container(
                  decoration: BoxDecoration(
                    color:
                        secili
                            ? value['color'].withOpacity(0.1)
                            : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: secili ? value['color'] : Colors.grey.shade300,
                      width: secili ? 2 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _secilenDosyaTuru = key;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              value['icon'],
                              color: secili ? value['color'] : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value['ad'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    secili
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    secili ? value['color'] : Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBelgeBilgileriKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Belge Bilgileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _baslikController,
              label: 'Belge Başlığı',
              hint: 'Belge için açıklayıcı bir başlık girin',
              icon: Icons.title,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _aciklamaController,
              label: 'Açıklama',
              hint: 'Belge hakkında detaylar',
              icon: Icons.description,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriVeKisiKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Kategori & Kişi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernDropdown<KategoriModeli>(
              value: _secilenKategori,
              label: 'Kategori',
              hint: 'Bir kategori seçin',
              icon: Icons.folder,
              items:
                  _kategoriler.map((kategori) {
                    return DropdownMenuItem(
                      value: kategori,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  kategori.renkKodu.replaceFirst('#', '0xFF'),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(kategori.kategoriAdi),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (kategori) {
                setState(() {
                  _secilenKategori = kategori;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildModernDropdown<KisiModeli>(
              value: _secilenKisi,
              label: 'Kişi *',
              hint: 'Bir kişi seçin',
              icon: Icons.person,
              items:
                  _kisiler.map((kisi) {
                    return DropdownMenuItem(
                      value: kisi,
                      child: Text(kisi.tamAd),
                    );
                  }).toList(),
              onChanged: (kisi) {
                setState(() {
                  _secilenKisi = kisi;
                });
              },
            ),
            if (_kisiler.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Önce bir kişi eklemelisiniz. Kişiler sekmesinden yeni kişi ekleyebilirsiniz.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEtiketlerKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.label,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Etiketler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _etiketlerController,
              label: 'Etiketler',
              hint: 'Virgülle ayırarak etiket ekleyin (örn: önemli, iş, proje)',
              icon: Icons.local_offer,
              onChanged: (value) {
                _etiketler =
                    value
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
              },
            ),
            if (_etiketler.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _etiketler.map((etiket) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          etiket,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade600, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.purple.shade600, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _dosyaEkle() async {
    try {
      final dosyalar = await _dosyaServisi.dosyaSec(cokluSecim: true);

      if (dosyalar != null && dosyalar.isNotEmpty) {
        setState(() {
          _secilenDosyalar.addAll(dosyalar);
        });
      }
    } catch (e) {
      _hataGoster('Dosya seçilirken hata oluştu: $e');
    }
  }

  Future<void> _belgelerEkle() async {
    // Validasyon
    if (!_duzenlemeModundaMi && _secilenDosyalar.isEmpty) {
      _hataGoster('En az bir dosya seçmelisiniz');
      return;
    }

    if (_secilenKisi == null) {
      _hataGoster('Bir kişi seçmelisiniz');
      return;
    }

    setState(() {
      _dosyalarIsleniyor = true;
    });

    if (_duzenlemeModundaMi) {
      await _belgeGuncelle();
    } else {
      await _yeniBelgelerEkle();
    }
  }

  Future<void> _belgeGuncelle() async {
    try {
      final guncelBelge = widget.duzenlenecekBelge!.copyWith(
        baslik:
            _baslikController.text.trim().isNotEmpty
                ? _baslikController.text.trim()
                : null,
        aciklama:
            _aciklamaController.text.trim().isNotEmpty
                ? _aciklamaController.text.trim()
                : null,
        kategoriId: _secilenKategori?.id,
        kisiId: _secilenKisi!.id!,
        etiketler: _etiketler.isNotEmpty ? _etiketler : null,
        guncellemeTarihi: DateTime.now(),
      );

      await _veriTabani.belgeGuncelle(guncelBelge);

      _basariMesajiGoster('Belge başarıyla güncellendi');
      Navigator.of(context).pop(true);
    } catch (e) {
      _hataGoster('Belge güncellenirken hata oluştu: $e');
    } finally {
      setState(() {
        _dosyalarIsleniyor = false;
      });
    }
  }

  Future<void> _yeniBelgelerEkle() async {
    // Progress dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${_secilenDosyalar.length} dosya işleniyor...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lütfen bekleyin',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
    );

    int basariliSayisi = 0;
    int hataliSayisi = 0;

    try {
      for (var platformFile in _secilenDosyalar) {
        try {
          // Dosyayı işle ve hash hesapla
          BelgeModeli belge = await _dosyaServisi.dosyaKopyalaVeHashHesapla(
            platformFile,
          );

          // Aynı hash'e sahip belge var mı kontrol et
          BelgeModeli? mevcutBelge = await _veriTabani.belgeGetirByHash(
            belge.dosyaHash,
          );
          if (mevcutBelge != null) {
            hataliSayisi++;
            continue; // Aynı dosya zaten var
          }

          // Belge bilgilerini güncelle
          DateTime simdi = DateTime.now();
          belge = belge.copyWith(
            baslik:
                _baslikController.text.trim().isNotEmpty
                    ? _baslikController.text.trim()
                    : null,
            aciklama:
                _aciklamaController.text.trim().isNotEmpty
                    ? _aciklamaController.text.trim()
                    : null,
            kategoriId: _secilenKategori?.id,
            kisiId: _secilenKisi!.id!,
            etiketler: _etiketler.isNotEmpty ? _etiketler : null,
            guncellemeTarihi: simdi,
          );

          // Veritabanına kaydet
          await _veriTabani.belgeEkle(belge);
          basariliSayisi++;
        } catch (e) {
          hataliSayisi++;
          print('Dosya işlenirken hata: $e');
        }
      }

      Navigator.of(context).pop(); // Progress dialog'u kapat

      // Sonuç mesajı
      String mesaj = '';
      if (basariliSayisi > 0) {
        mesaj += '$basariliSayisi dosya başarıyla eklendi';
      }
      if (hataliSayisi > 0) {
        if (mesaj.isNotEmpty) mesaj += ', ';
        mesaj += '$hataliSayisi dosya eklenemedi (Aynı dosya zaten mevcut)';
      }

      if (basariliSayisi > 0) {
        _basariMesajiGoster(mesaj);
        Navigator.of(context).pop(true); // true = başarılı
      } else {
        _hataGoster(mesaj.isEmpty ? 'Hiçbir dosya eklenemedi' : mesaj);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Progress dialog'u kapat
      _hataGoster('Belgeler eklenirken hata oluştu: $e');
    } finally {
      setState(() {
        _dosyalarIsleniyor = false;
      });
    }
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _basariMesajiGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
