import 'package:flutter/material.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/yedekleme_servisi.dart';
import 'package:file_picker/file_picker.dart';

class YedeklemeEkrani extends StatefulWidget {
  const YedeklemeEkrani({Key? key}) : super(key: key);

  @override
  State<YedeklemeEkrani> createState() => _YedeklemeEkraniState();
}

class _YedeklemeEkraniState extends State<YedeklemeEkrani> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  late final YedeklemeServisi _yedeklemeServisi;

  List<KisiModeli> _tumKisiler = [];
  List<KategoriModeli> _tumKategoriler = [];
  List<int> _secilenKisilerIds = [];
  bool _tumKisileriSec = false;
  String? _hedefKlasorYolu;
  bool _yukleniyor = true;
  bool _yedeklemeDevamEdiyor = false;
  double _yedeklemeIlerlemesi = 0.0;
  String _yedeklemeIslemi = '';

  // Kategori seçimi için
  Map<int, List<KategoriModeli>> _kisiKategorileri = {};
  Map<int, List<int>> _secilenKategoriler = {}; // kisiId -> kategoriIds
  Map<int, bool> _tumKategorileriSec = {}; // kisiId -> bool

  @override
  void initState() {
    super.initState();
    _yedeklemeServisi = YedeklemeServisi();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      final kisiler = await _veriTabani.kisileriGetir();
      final kategoriler = await _veriTabani.kategorileriGetir();

      setState(() {
        _tumKisiler = kisiler;
        _tumKategoriler = kategoriler;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Veriler yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _hedefKlasorSec() async {
    try {
      String? seciliKlasor = await FilePicker.platform.getDirectoryPath();
      if (seciliKlasor != null) {
        setState(() {
          _hedefKlasorYolu = seciliKlasor;
        });
      }
    } catch (e) {
      _hataGoster('Klasör seçerken hata oluştu: $e');
    }
  }

  void _tumKisileriSecToggle(bool? value) {
    setState(() {
      _tumKisileriSec = value ?? false;
      if (_tumKisileriSec) {
        _secilenKisilerIds = _tumKisiler.map((k) => k.id!).toList();
        // Tüm kişiler için kategorileri yükle
        for (final kisi in _tumKisiler) {
          _kisiKategorileriniYukle(kisi.id!);
        }
      } else {
        _secilenKisilerIds.clear();
        _kisiKategorileri.clear();
        _secilenKategoriler.clear();
        _tumKategorileriSec.clear();
      }
    });
  }

  void _kisiSecToggle(int kisiId, bool? value) {
    setState(() {
      if (value == true) {
        _secilenKisilerIds.add(kisiId);
        _kisiKategorileriniYukle(kisiId);
      } else {
        _secilenKisilerIds.remove(kisiId);
        _kisiKategorileri.remove(kisiId);
        _secilenKategoriler.remove(kisiId);
        _tumKategorileriSec.remove(kisiId);
      }

      // Tüm kişiler seçili mi kontrol et
      _tumKisileriSec = _secilenKisilerIds.length == _tumKisiler.length;
    });
  }

  Future<void> _kisiKategorileriniYukle(int kisiId) async {
    try {
      final belgeler = await _veriTabani.kisiBelgeleriniGetir(kisiId);
      final kategoriIds =
          belgeler
              .map((b) => b.kategoriId)
              .where((id) => id != null)
              .cast<int>()
              .toSet()
              .toList();

      final kisiKategorileri =
          _tumKategoriler.where((k) => kategoriIds.contains(k.id)).toList();

      setState(() {
        _kisiKategorileri[kisiId] = kisiKategorileri;
        _secilenKategoriler[kisiId] =
            kisiKategorileri.map((k) => k.id!).toList();
        _tumKategorileriSec[kisiId] =
            true; // Varsayılan olarak tüm kategoriler seçili
      });
    } catch (e) {
      print('Kişi kategorileri yüklenirken hata: $e');
    }
  }

  void _kategoriSecToggle(int kisiId, int kategoriId, bool? value) {
    setState(() {
      if (value == true) {
        _secilenKategoriler[kisiId]?.add(kategoriId);
      } else {
        _secilenKategoriler[kisiId]?.remove(kategoriId);
      }

      // Tüm kategoriler seçili mi kontrol et
      final tumKategoriler = _kisiKategorileri[kisiId] ?? [];
      final secilenKategoriler = _secilenKategoriler[kisiId] ?? [];
      _tumKategorileriSec[kisiId] =
          secilenKategoriler.length == tumKategoriler.length;
    });
  }

  void _tumKategorileriSecToggle(int kisiId, bool? value) {
    setState(() {
      final tumKategoriler = _kisiKategorileri[kisiId] ?? [];
      _tumKategorileriSec[kisiId] = value ?? false;

      if (_tumKategorileriSec[kisiId]!) {
        _secilenKategoriler[kisiId] = tumKategoriler.map((k) => k.id!).toList();
      } else {
        _secilenKategoriler[kisiId] = [];
      }
    });
  }

  Future<void> _yedeklemeBaslat() async {
    if (_secilenKisilerIds.isEmpty) {
      _hataGoster('Lütfen yedeklenecek kişileri seçin');
      return;
    }

    if (_hedefKlasorYolu == null) {
      _hataGoster('Lütfen hedef klasörü seçin');
      return;
    }

    // Seçilen kategori kontrolü
    bool kategoriSecildi = false;
    for (final kisiId in _secilenKisilerIds) {
      final kategoriler = _secilenKategoriler[kisiId] ?? [];
      if (kategoriler.isNotEmpty) {
        kategoriSecildi = true;
        break;
      }
    }

    if (!kategoriSecildi) {
      _hataGoster('Lütfen yedeklenecek kategorileri seçin');
      return;
    }

    setState(() {
      _yedeklemeDevamEdiyor = true;
      _yedeklemeIlerlemesi = 0.0;
      _yedeklemeIslemi = 'Yedekleme başlatılıyor...';
    });

    try {
      await _yedeklemeServisi.kisiVeKategoriYedeklemeYap(
        _secilenKisilerIds,
        _hedefKlasorYolu!,
        kategoriSecimi: _secilenKategoriler,
        onProgress: (progress, operation) {
          setState(() {
            _yedeklemeIlerlemesi = progress;
            _yedeklemeIslemi = operation;
          });
        },
      );

      setState(() {
        _yedeklemeDevamEdiyor = false;
        _yedeklemeIlerlemesi = 1.0;
        _yedeklemeIslemi = 'Yedekleme tamamlandı!';
      });

      _basariGoster('Yedekleme başarıyla tamamlandı!');
    } catch (e) {
      setState(() {
        _yedeklemeDevamEdiyor = false;
        _yedeklemeIlerlemesi = 0.0;
        _yedeklemeIslemi = '';
      });
      _hataGoster('Yedekleme sırasında hata oluştu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedekleme'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _yukleniyor ? _buildYukleniyorEkrani() : _buildAnaIcerik(),
    );
  }

  Widget _buildYukleniyorEkrani() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Veriler yükleniyor...'),
        ],
      ),
    );
  }

  Widget _buildAnaIcerik() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBaslikKarti(),
            const SizedBox(height: 16),
            _buildHedefKlasorKarti(),
            const SizedBox(height: 16),
            Expanded(child: _buildKisiSecimListesi()),
            const SizedBox(height: 16),
            _buildYedeklemeButonu(),
            if (_yedeklemeDevamEdiyor) ...[
              const SizedBox(height: 16),
              _buildYedeklemeIlerlemesi(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBaslikKarti() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.backup, color: Colors.green[600], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kişiye ve Kategoriye Göre Yedekleme',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kişi seçtikten sonra o kişinin kategorilerini seçerek yedekleme yapın',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHedefKlasorKarti() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hedef Klasör',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _hedefKlasorSec,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color:
                      _hedefKlasorYolu != null
                          ? Colors.green[50]
                          : Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open,
                      color:
                          _hedefKlasorYolu != null
                              ? Colors.green[600]
                              : Colors.grey[600],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hedefKlasorYolu ?? 'Klasör seçin...',
                        style: TextStyle(
                          color:
                              _hedefKlasorYolu != null
                                  ? Colors.green[800]
                                  : Colors.grey[600],
                          fontWeight:
                              _hedefKlasorYolu != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
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

  Widget _buildKisiSecimListesi() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yedeklenecek Kişiler',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                // Tümünü seç checkbox'ı
                CheckboxListTile(
                  title: const Text(
                    'Tüm Kişileri Seç',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${_tumKisiler.length} kişi'),
                  value: _tumKisileriSec,
                  onChanged: _tumKisileriSecToggle,
                  activeColor: Colors.blue[600],
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tumKisiler.length,
              itemBuilder: (context, index) {
                final kisi = _tumKisiler[index];
                final secili = _secilenKisilerIds.contains(kisi.id);

                return Column(
                  children: [
                    CheckboxListTile(
                      title: Text(
                        kisi.tamAd,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: FutureBuilder<int>(
                        future: _veriTabani.kisiBelgeSayisi(kisi.id!),
                        builder: (context, snapshot) {
                          final belgeSayisi = snapshot.data ?? 0;
                          return Text('$belgeSayisi belge');
                        },
                      ),
                      value: secili,
                      onChanged: (value) => _kisiSecToggle(kisi.id!, value),
                      activeColor: Colors.blue[600],
                      secondary: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          kisi.ad.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (secili && _kisiKategorileri.containsKey(kisi.id))
                      _buildKisiKategorileri(kisi.id!),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKisiKategorileri(int kisiId) {
    final kategoriler = _kisiKategorileri[kisiId] ?? [];
    final secilenKategoriler = _secilenKategoriler[kisiId] ?? [];
    final tumKategorilerSecili = _tumKategorileriSec[kisiId] ?? false;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, size: 16, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text(
                'Kategoriler',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (kategoriler.isNotEmpty)
            CheckboxListTile(
              title: Text(
                'Tüm Kategorileri Seç',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange[700],
                ),
              ),
              subtitle: Text(
                '${kategoriler.length} kategori',
                style: TextStyle(fontSize: 12, color: Colors.orange[600]),
              ),
              value: tumKategorilerSecili,
              onChanged: (value) => _tumKategorileriSecToggle(kisiId, value),
              activeColor: Colors.orange[600],
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          const SizedBox(height: 4),
          ...kategoriler.map((kategori) {
            final secili = secilenKategoriler.contains(kategori.id);
            return CheckboxListTile(
              title: Text(
                kategori.kategoriAdi,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                ),
              ),
              value: secili,
              onChanged:
                  (value) => _kategoriSecToggle(kisiId, kategori.id!, value),
              activeColor: Colors.orange[600],
              contentPadding: const EdgeInsets.only(left: 16),
              dense: true,
              secondary: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(
                    int.parse(kategori.renkKodu.replaceAll('#', '0xFF')),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildYedeklemeButonu() {
    final hazir = _secilenKisilerIds.isNotEmpty && _hedefKlasorYolu != null;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: hazir && !_yedeklemeDevamEdiyor ? _yedeklemeBaslat : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: hazir ? 2 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_yedeklemeDevamEdiyor) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const Icon(Icons.backup, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              _yedeklemeDevamEdiyor ? 'Yedekleniyor...' : 'Yedeklemeyi Başlat',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYedeklemeIlerlemesi() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Yedekleme İlerlemesi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _yedeklemeIlerlemesi,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
            const SizedBox(height: 8),
            Text(
              _yedeklemeIslemi,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_yedeklemeIlerlemesi * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
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
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
