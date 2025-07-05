import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../utils/screen_utils.dart';

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
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Dosya türleri
  final Map<String, Map<String, dynamic>> _dosyaTurleri = {
    'pdf': {
      'ad': 'PDF Belgesi',
      'icon': Icons.picture_as_pdf_rounded,
      'color': Colors.red.shade600,
      'uzantilar': ['pdf'],
      'gradient': [Colors.red.shade400, Colors.red.shade600],
    },
    'doc': {
      'ad': 'Word Belgesi',
      'icon': Icons.description_rounded,
      'color': Colors.blue.shade600,
      'uzantilar': ['doc', 'docx'],
      'gradient': [Colors.blue.shade400, Colors.blue.shade600],
    },
    'xls': {
      'ad': 'Excel Tablosu',
      'icon': Icons.table_chart_rounded,
      'color': Colors.green.shade600,
      'uzantilar': ['xls', 'xlsx'],
      'gradient': [Colors.green.shade400, Colors.green.shade600],
    },
    'ppt': {
      'ad': 'PowerPoint Sunumu',
      'icon': Icons.slideshow_rounded,
      'color': Colors.orange.shade600,
      'uzantilar': ['ppt', 'pptx'],
      'gradient': [Colors.orange.shade400, Colors.orange.shade600],
    },
    'jpg': {
      'ad': 'Resim Dosyası',
      'icon': Icons.image_rounded,
      'color': Colors.purple.shade600,
      'uzantilar': ['jpg', 'jpeg', 'png', 'gif', 'bmp'],
      'gradient': [Colors.purple.shade400, Colors.purple.shade600],
    },
    'video': {
      'ad': 'Video Dosyası',
      'icon': Icons.video_library_rounded,
      'color': Colors.indigo.shade600,
      'uzantilar': ['mp4', 'avi', 'mkv', 'mov'],
      'gradient': [Colors.indigo.shade400, Colors.indigo.shade600],
    },
    'audio': {
      'ad': 'Ses Dosyası',
      'icon': Icons.audiotrack_rounded,
      'color': Colors.teal.shade600,
      'uzantilar': ['mp3', 'wav', 'flac', 'aac'],
      'gradient': [Colors.teal.shade400, Colors.teal.shade600],
    },
    'archive': {
      'ad': 'Arşiv Dosyası',
      'icon': Icons.archive_rounded,
      'color': Colors.brown.shade600,
      'uzantilar': ['zip', 'rar', '7z', 'tar'],
      'gradient': [Colors.brown.shade400, Colors.brown.shade600],
    },
    'other': {
      'ad': 'Diğer',
      'icon': Icons.insert_drive_file_rounded,
      'color': Colors.grey.shade600,
      'uzantilar': ['txt', 'csv', 'json', 'xml'],
      'gradient': [Colors.grey.shade400, Colors.grey.shade600],
    },
  };

  bool get _duzenlemeModundaMi => widget.duzenlenecekBelge != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    _verileriYukle();
    _duzenlemeVerileriniYukle();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _etiketlerController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _duzenlemeVerileriniYukle() {
    if (_duzenlemeModundaMi) {
      final belge = widget.duzenlenecekBelge!;
      _baslikController.text = belge.baslik ?? '';
      _aciklamaController.text = belge.aciklama ?? '';
      _etiketler = belge.etiketler ?? [];
      _etiketlerController.text = _etiketler.join(', ');
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
              Colors.indigo.shade50,
              Colors.purple.shade50,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: _yukleniyor ? _buildYukleniyorWidget() : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade200, Colors.grey.shade100],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
              ),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _duzenlemeModundaMi
                      ? 'Belge bilgilerini güncelleyin'
                      : 'Belgelerinizi organize edin',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if ((_secilenDosyalar.isNotEmpty || _duzenlemeModundaMi) &&
              !_dosyalarIsleniyor)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _belgelerEkle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.save_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'KAYDET',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade400,
                    ),
                  ),
                ),
                Icon(
                  Icons.cloud_download_rounded,
                  size: 30,
                  color: Colors.blue.shade400,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Veriler yükleniyor...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Lütfen bekleyiniz',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
              if (!_duzenlemeModundaMi) _buildDosyaSecmeKarti(),
              if (!_duzenlemeModundaMi) const SizedBox(height: 20),

              if (_secilenDosyalar.isNotEmpty) _buildSecilenDosyalarKarti(),
              if (_secilenDosyalar.isNotEmpty) const SizedBox(height: 20),

              if (!_duzenlemeModundaMi) _buildDosyaTuruSecimi(),
              if (!_duzenlemeModundaMi) const SizedBox(height: 20),

              _buildBelgeBilgileriKarti(),
              const SizedBox(height: 20),

              _buildKategoriVeKisiKarti(),
              const SizedBox(height: 20),

              _buildEtiketlerKarti(),
              const SizedBox(height: 100),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _dosyaEkle,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _secilenDosyalar.isEmpty
                      ? Icons.cloud_upload_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _secilenDosyalar.isEmpty
                      ? 'Dosya Seçin'
                      : '${_secilenDosyalar.length} Dosya Seçildi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen Dosyalar',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${_secilenDosyalar.length} dosya hazır',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _secilenDosyalar.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final dosya = _secilenDosyalar[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dosya.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(dosya.size / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _secilenDosyalar.removeAt(index);
                              });

                              if (_secilenDosyalar.isNotEmpty) {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () => _otomatikDosyaTuruAlgila(),
                                );
                              } else {
                                setState(() {
                                  _secilenDosyaTuru = null;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                            ),
                          ),
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
    if (_secilenDosyalar.isNotEmpty && _secilenDosyaTuru == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otomatikDosyaTuruAlgila();
      });
    }

    final secilenTur =
        _secilenDosyaTuru != null ? _dosyaTurleri[_secilenDosyaTuru!] : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          secilenTur != null
                              ? secilenTur['gradient']
                              : [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    secilenTur?['icon'] ?? Icons.category_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dosya Türü',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        secilenTur != null
                            ? '${secilenTur['ad']} (Otomatik algılandı)'
                            : 'Dosya türünü seçin',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              secilenTur != null
                                  ? secilenTur['color']
                                  : Colors.grey.shade600,
                          fontWeight:
                              secilenTur != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (secilenTur != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: secilenTur['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: secilenTur['color'].withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: secilenTur['color'],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Auto',
                          style: TextStyle(
                            fontSize: 12,
                            color: secilenTur['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      secilenTur != null
                          ? secilenTur['color'].withOpacity(0.3)
                          : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  childrenPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            secilenTur != null
                                ? secilenTur['gradient']
                                : [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      secilenTur?['icon'] ?? Icons.folder_open_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    secilenTur?['ad'] ?? 'Dosya türü seçin',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          secilenTur != null
                              ? secilenTur['color']
                              : Colors.grey.shade700,
                    ),
                  ),
                  subtitle: Text(
                    secilenTur != null
                        ? 'Desteklenen: ${secilenTur['uzantilar'].join(', ').toUpperCase()}'
                        : 'Dosya türünü belirlemek için tıklayın',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color:
                        secilenTur != null
                            ? secilenTur['color']
                            : Colors.grey.shade600,
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children:
                            _dosyaTurleri.entries.map((entry) {
                              final key = entry.key;
                              final value = entry.value;
                              final secili = _secilenDosyaTuru == key;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _secilenDosyaTuru = key;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          secili
                                              ? value['color'].withOpacity(0.08)
                                              : Colors.transparent,
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: value['gradient'],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            value['icon'],
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                value['ad'],
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      secili
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                  color:
                                                      secili
                                                          ? value['color']
                                                          : Colors
                                                              .grey
                                                              .shade700,
                                                ),
                                              ),
                                              Text(
                                                value['uzantilar']
                                                    .join(', ')
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (secili)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: value['color'],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _otomatikDosyaTuruAlgila() {
    if (_secilenDosyalar.isEmpty) return;

    Map<String, int> uzantiSayilari = {};
    Map<String, String> uzantiTurleri = {};

    for (final dosya in _secilenDosyalar) {
      if (dosya.name.contains('.')) {
        String uzanti = dosya.name.split('.').last.toLowerCase();
        uzantiSayilari[uzanti] = (uzantiSayilari[uzanti] ?? 0) + 1;

        for (final entry in _dosyaTurleri.entries) {
          if (entry.value['uzantilar'].contains(uzanti)) {
            uzantiTurleri[uzanti] = entry.key;
            break;
          }
        }
      }
    }

    if (uzantiTurleri.isEmpty) return;

    Map<String, int> turSayilari = {};
    for (final uzanti in uzantiSayilari.keys) {
      String? tur = uzantiTurleri[uzanti];
      if (tur != null) {
        turSayilari[tur] = (turSayilari[tur] ?? 0) + uzantiSayilari[uzanti]!;
      }
    }

    if (turSayilari.isEmpty) return;

    String algilanaDosyaTuru =
        turSayilari.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    if (algilanaDosyaTuru != _secilenDosyaTuru) {
      setState(() {
        _secilenDosyaTuru = algilanaDosyaTuru;
      });
    }
  }

  Widget _buildBelgeBilgileriKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belge Bilgileri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Belge detaylarını girin',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModernTextField(
              controller: _baslikController,
              label: 'Belge Başlığı',
              hint: 'Belge için açıklayıcı bir başlık girin',
              icon: Icons.title_rounded,
              iconColor: Colors.blue.shade600,
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _aciklamaController,
              label: 'Açıklama',
              hint: 'Belge hakkında detaylar',
              icon: Icons.description_rounded,
              iconColor: Colors.blue.shade600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.purple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kategori & Kişi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Belgeyi organize edin',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildModernDropdown<KategoriModeli>(
              value: _secilenKategori,
              label: 'Kategori',
              hint: 'Bir kategori seçin',
              icon: Icons.folder_rounded,
              iconColor: Colors.purple.shade600,
              items:
                  _kategoriler.map((kategori) {
                    return DropdownMenuItem(
                      value: kategori,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  kategori.renkKodu.replaceFirst('#', '0xFF'),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            kategori.kategoriAdi,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
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
            const SizedBox(height: 20),
            _buildModernDropdown<KisiModeli>(
              value: _secilenKisi,
              label: 'Kişi *',
              hint: 'Bir kişi seçin',
              icon: Icons.person_rounded,
              iconColor: Colors.purple.shade600,
              items:
                  _kisiler.map((kisi) {
                    return DropdownMenuItem(
                      value: kisi,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.purple.shade100,
                            child: Text(
                              kisi.ad.isNotEmpty
                                  ? kisi.ad[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.purple.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              kisi.tamAd,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (kisi) {
                setState(() {
                  _secilenKisi = kisi;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtiketlerKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.label_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etiketler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Belgeyi etiketleyin',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _etiketlerController,
              label: 'Etiketler',
              hint: 'Virgülle ayırarak etiket ekleyin (örn: önemli, iş, proje)',
              icon: Icons.local_offer_rounded,
              iconColor: Colors.green.shade600,
              onChanged: (value) {
                setState(() {
                  _etiketler =
                      value
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                });
              },
            ),
            if (_etiketler.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    _etiketler.map((etiket) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade100,
                              Colors.blue.shade200,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tag_rounded,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              etiket,
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
    required Color iconColor,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
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

        Future.delayed(const Duration(milliseconds: 100), () {
          _otomatikDosyaTuruAlgila();
        });
      }
    } catch (e) {
      _hataGoster('Dosya seçilirken hata oluştu: $e');
    }
  }

  Future<void> _belgelerEkle() async {
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

  Future<void> _kisileriYenile() async {
    try {
      final kisiler = await _veriTabani.kisileriGetir();
      setState(() {
        _kisiler = kisiler;
      });

      if (_secilenKisi != null) {
        final mevcutKisi = _kisiler.firstWhere(
          (k) => k.id == _secilenKisi!.id,
          orElse:
              () => KisiModeli(
                ad: '',
                soyad: '',
                olusturmaTarihi: DateTime.now(),
                guncellemeTarihi: DateTime.now(),
              ),
        );

        if (mevcutKisi.ad.isEmpty) {
          _secilenKisi = null;
        }
      }

      _basariMesajiGoster('${_kisiler.length} kişi yüklendi');
    } catch (e) {
      _hataGoster('Kişiler yüklenirken hata oluştu: $e');
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade400,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.cloud_upload_rounded,
                          size: 28,
                          color: Colors.blue.shade400,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${_secilenDosyalar.length} dosya işleniyor...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dosyalar kaydediliyor, lütfen bekleyin',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
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
          BelgeModeli belge = await _dosyaServisi.dosyaKopyalaVeHashHesapla(
            platformFile,
          );

          BelgeModeli? mevcutBelge = await _veriTabani.belgeGetirByHash(
            belge.dosyaHash,
          );
          if (mevcutBelge != null) {
            hataliSayisi++;
            continue;
          }

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

          await _veriTabani.belgeEkle(belge);
          basariliSayisi++;
        } catch (e) {
          hataliSayisi++;
          print('Dosya işlenirken hata: $e');
        }
      }

      Navigator.of(context).pop();

      String mesaj = '';
      if (basariliSayisi > 0) {
        mesaj += '$basariliSayisi dosya başarıyla eklendi';
      }
      if (hataliSayisi > 0) {
        if (mesaj.isNotEmpty) mesaj += ', ';
        mesaj += '$hataliSayisi dosya eklenemedi';
      }

      if (basariliSayisi > 0) {
        _basariMesajiGoster(mesaj);
        Navigator.of(context).pop(true);
      } else {
        _hataGoster(mesaj.isEmpty ? 'Hiçbir dosya eklenemedi' : mesaj);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _hataGoster('Belgeler eklenirken hata oluştu: $e');
    } finally {
      setState(() {
        _dosyalarIsleniyor = false;
      });
    }
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }

  void _basariMesajiGoster(String mesaj) {
    ScreenUtils.showSuccessSnackBar(context, mesaj);
  }
}
