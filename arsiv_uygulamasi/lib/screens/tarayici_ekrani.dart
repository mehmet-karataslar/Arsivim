import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/tarayici_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../utils/yardimci_fonksiyonlar.dart';
import '../utils/screen_utils.dart';

class TarayiciEkrani extends StatefulWidget {
  const TarayiciEkrani({Key? key}) : super(key: key);

  @override
  State<TarayiciEkrani> createState() => _TarayiciEkraniState();
}

class _TarayiciEkraniState extends State<TarayiciEkrani> {
  final TarayiciServisi _tarayiciServisi = TarayiciServisi();
  final BelgeIslemleriServisi _belgeIslemleri = BelgeIslemleriServisi();
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();

  List<String> _bulunanTarayicilar = [];
  String? _secilenTarayici;
  bool _tarayiciAranyor = false;
  bool _taramaDurumu = false;
  String? _tarananBelgePath;
  String? _tarayiciAranamaHatasi;

  // Belge kaydetme için form alanları
  final _baslikController = TextEditingController();
  final _aciklamaController = TextEditingController();
  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  KategoriModeli? _secilenKategori;
  KisiModeli? _secilenKisi;
  List<String> _etiketler = [];
  final _etiketController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kategoriVeKisileriYukle();
    _tarayicilariAra();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _etiketController.dispose();
    super.dispose();
  }

  Future<void> _kategoriVeKisileriYukle() async {
    try {
      final kategoriler = await _veriTabani.kategorileriGetir();
      final kisiler = await _veriTabani.kisileriGetir();

      setState(() {
        _kategoriler = kategoriler;
        _kisiler = kisiler;
      });
    } catch (e) {
      if (mounted) {
        ScreenUtils.showErrorSnackBar(
          context,
          'Kategoriler ve kişiler yüklenirken hata: $e',
        );
      }
    }
  }

  Future<void> _tarayicilariAra() async {
    setState(() {
      _tarayiciAranyor = true;
      _bulunanTarayicilar.clear();
      _secilenTarayici = null;
      _tarayiciAranamaHatasi = null;
    });

    try {
      final tarayicilar = await _tarayiciServisi.tarayicilariAra();

      setState(() {
        _bulunanTarayicilar = tarayicilar;
        _tarayiciAranyor = false;

        if (tarayicilar.isNotEmpty) {
          _secilenTarayici = tarayicilar.first;
        }
      });
      
      // Ağ tarayıcısı bağlantı durumunu kontrol et
      if (tarayicilar.isNotEmpty) {
        _agTarayiciDurumKontrol();
      }
    } on PlatformException catch (e) {
      setState(() {
        _tarayiciAranyor = false;
        _tarayiciAranamaHatasi = _tarayiciServisi.getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _tarayiciAranyor = false;
        _tarayiciAranamaHatasi =
            'Tarayıcı arama sırasında beklenmeyen bir hata oluştu';
      });
    }
  }

  /// Ağ tarayıcısı durumunu kontrol et
  Future<void> _agTarayiciDurumKontrol() async {
    for (String tarayici in _bulunanTarayicilar) {
      try {
        final bool durum = await _tarayiciServisi.tarayiciBaglantiTest(tarayici);
        if (!durum) {
          // Ağ tarayıcısı çevrim dışı uyarısı
          _showNetworkScannerWarning(tarayici);
        }
      } catch (e) {
        // Sessizce devam et
      }
    }
  }

  /// Ağ tarayıcısı uyarısını göster
  void _showNetworkScannerWarning(String tarayiciAdi) {
    if (!mounted) return;
    
    ScreenUtils.showWarningSnackBar(
      context,
      'Ağ tarayıcısı "$tarayiciAdi" çevrim dışı. Wi-Fi bağlantınızı kontrol edin.',
    );
  }

  Future<void> _belgeTara() async {
    if (_secilenTarayici == null) {
      ScreenUtils.showErrorSnackBar(context, 'Önce bir tarayıcı seçin');
      return;
    }

    setState(() {
      _taramaDurumu = true;
    });

    try {
      final scannedPath = await _tarayiciServisi.belgeTara(_secilenTarayici!);

      if (scannedPath != null && scannedPath.isNotEmpty) {
        setState(() {
          _tarananBelgePath = scannedPath;
          _taramaDurumu = false;
        });

        // Taranan belge için varsayılan başlık oluştur
        final now = DateTime.now();
        _baslikController.text =
            'Taranan Belge ${now.day}/${now.month}/${now.year}';

        ScreenUtils.showSuccessSnackBar(context, 'Belge başarıyla tarandı!');
      } else {
        setState(() {
          _taramaDurumu = false;
        });
        ScreenUtils.showWarningSnackBar(
          context,
          'Belge tarama işlemi iptal edildi',
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _taramaDurumu = false;
      });
      ScreenUtils.showErrorSnackBar(
        context,
        _tarayiciServisi.getErrorMessage(e.code),
      );
    } catch (e) {
      setState(() {
        _taramaDurumu = false;
      });
      ScreenUtils.showErrorSnackBar(
        context,
        'Tarama sırasında beklenmeyen bir hata oluştu',
      );
    }
  }

  Future<void> _belgeKaydet() async {
    if (_tarananBelgePath == null) {
      ScreenUtils.showErrorSnackBar(context, 'Önce bir belge tarayın');
      return;
    }

    if (_baslikController.text.trim().isEmpty) {
      ScreenUtils.showErrorSnackBar(context, 'Belge başlığı boş olamaz');
      return;
    }

    ScreenUtils.showLoadingDialog(context, message: 'Belge kaydediliyor...');

    try {
      final tempFile = File(_tarananBelgePath!);
      if (!await tempFile.exists()) {
        Navigator.of(context).pop(); // Close loading dialog
        ScreenUtils.showErrorSnackBar(
          context,
          'Taranan belge dosyası bulunamadı',
        );
        return;
      }

      // Kalıcı belgeler klasörüne taşı
      final belgelerKlasoruYolu = await _dosyaServisi.belgelerKlasoruYolu();
      final dosyaAdi =
          'scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final kaliciDosyaYolu = path.join(belgelerKlasoruYolu, dosyaAdi);

      // Dosyayı temp'den kalıcı klasöre kopyala
      final kaliciDosya = await tempFile.copy(kaliciDosyaYolu);

      // Temp dosyasını sil (kopyalama başarılı olursa)
      try {
        await tempFile.delete();
      } catch (e) {
        // Temp dosya silinemezse loglayalım ama devam edelim
        print('Temp dosya silinemedi: $e');
      }

      // Dosya bilgilerini al
      final dosyaBoyutu = await kaliciDosya.length();
      final dosyaTipi = YardimciFonksiyonlar.dosyaUzantisiAl(kaliciDosyaYolu);
      final dosyaHash = await YardimciFonksiyonlar.dosyaHashHesapla(
        kaliciDosyaYolu,
      );

      // Belge modelini oluştur
      final belge = BelgeModeli(
        dosyaAdi: dosyaAdi,
        orijinalDosyaAdi: 'scanned_document.pdf',
        dosyaYolu: kaliciDosyaYolu,
        dosyaBoyutu: dosyaBoyutu,
        dosyaTipi: dosyaTipi,
        dosyaHash: dosyaHash,
        baslik: _baslikController.text.trim(),
        aciklama: _aciklamaController.text.trim(),
        kategoriId: _secilenKategori?.id,
        kisiId: _secilenKisi?.id,
        etiketler: _etiketler,
        olusturmaTarihi: DateTime.now(),
        guncellemeTarihi: DateTime.now(),
      );

      // Belgeyi kaydet
      await _veriTabani.belgeEkle(belge);

      Navigator.of(context).pop(); // Close loading dialog
      ScreenUtils.showSuccessSnackBar(
        context,
        'Belge başarıyla kaydedildi! Ana ekranda görüntülenecek.',
      );
      _formuTemizle();
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScreenUtils.showErrorSnackBar(context, 'Belge kaydedilirken hata: $e');
    }
  }

  void _formuTemizle() {
    setState(() {
      _tarananBelgePath = null;
      _baslikController.clear();
      _aciklamaController.clear();
      _secilenKategori = null;
      _secilenKisi = null;
      _etiketler.clear();
    });
  }

  void _etiketEkle() {
    if (_etiketController.text.trim().isNotEmpty) {
      setState(() {
        _etiketler.add(_etiketController.text.trim());
        _etiketController.clear();
      });
    }
  }

  void _etiketSil(String etiket) {
    setState(() {
      _etiketler.remove(etiket);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScreenUtils.buildAppBar(
        title: 'Belge Tarayıcı',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _tarayicilariAra,
            tooltip: 'Tarayıcıları Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _gosterTarayiciYardimi(),
            tooltip: 'Yardım',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTarayiciSecimi(),
            const SizedBox(height: 20),
            _buildTaramaAktivitesi(),
            const SizedBox(height: 20),
            if (_tarananBelgePath != null) _buildBelgeDetaylari(),
          ],
        ),
      ),
    );
  }

  Widget _buildTarayiciSecimi() {
    return Card(
      elevation: 4,
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.scanner, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tarayıcı Seçimi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tarayiciAranyor)
              const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Tarayıcılar aranıyor...'),
                ],
              )
            else if (_tarayiciAranamaHatasi != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'Tarayıcı Bulunamadı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_tarayiciAranamaHatasi!),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _tarayicilariAra,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (_bulunanTarayicilar.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_outlined,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tarayıcı Bulunamadı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarayıcınızın bağlı ve açık olduğundan emin olun.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _tarayicilariAra,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Ara'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _secilenTarayici,
                    decoration: const InputDecoration(
                      labelText: 'Tarayıcı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scanner),
                    ),
                    items:
                        _bulunanTarayicilar.map((tarayici) {
                          return DropdownMenuItem(
                            value: tarayici,
                            child: Text(tarayici),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _secilenTarayici = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _tarayicilariAra,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yenile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _secilenTarayici != null ? _belgeTara : null,
                          icon: const Icon(Icons.document_scanner),
                          label: const Text('Belge Tara'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaramaAktivitesi() {
    return Card(
      elevation: 4,
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.document_scanner,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tarama Durumu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_taramaDurumu)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      const Text('Belge taranıyor...'),
                    ],
                  ),
                ],
              )
            else if (_tarananBelgePath != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Belge başarıyla tarandı!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Henüz belge taranmadı. Yukarıdan tarayıcı seçip "Belge Tara" butonuna basın.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBelgeDetaylari() {
    return Card(
      elevation: 4,
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belge Detayları',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Başlık
            TextFormField(
              controller: _baslikController,
              decoration: const InputDecoration(
                labelText: 'Belge Başlığı *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Belge başlığı boş olamaz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _aciklamaController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Kategori seçimi
            DropdownButtonFormField<KategoriModeli>(
              value: _secilenKategori,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items:
                  _kategoriler.map((kategori) {
                    return DropdownMenuItem(
                      value: kategori,
                      child: Text(kategori.ad),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _secilenKategori = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Kişi seçimi
            DropdownButtonFormField<KisiModeli>(
              value: _secilenKisi,
              decoration: const InputDecoration(
                labelText: 'Kişi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items:
                  _kisiler.map((kisi) {
                    return DropdownMenuItem(
                      value: kisi,
                      child: Text('${kisi.ad} ${kisi.soyad}'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _secilenKisi = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Etiketler
            const Text(
              'Etiketler:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _etiketController,
                    decoration: const InputDecoration(
                      labelText: 'Etiket ekle',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    onFieldSubmitted: (_) => _etiketEkle(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _etiketEkle,
                  icon: const Icon(Icons.add),
                  label: const Text('Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_etiketler.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _etiketler.map((etiket) {
                      return Chip(
                        label: Text(etiket),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () => _etiketSil(etiket),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      );
                    }).toList(),
              ),
            const SizedBox(height: 24),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _belgeKaydet,
                icon: const Icon(Icons.save),
                label: const Text('Belgeyi Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _gosterTarayiciYardimi() {
    ScreenUtils.showConfirmationDialog(
      context,
      title: 'Tarayıcı Yardımı',
      message: '''
Tarayıcınızı kullanmak için:

1. Tarayıcınızın bilgisayara bağlı olduğundan emin olun
2. Tarayıcı sürücülerinin yüklü olduğundan emin olun
3. Tarayıcınızı açın ve hazır duruma getirin
4. "Tarayıcıları Yenile" butonuna basın
5. Listeden tarayıcınızı seçin
6. Belgeyi tarayıcıya yerleştirin
7. "Belge Tara" butonuna basın

Sorun yaşıyorsanız tarayıcınızı yeniden başlatın.
      ''',
      confirmText: 'Tamam',
      cancelText: '',
      icon: Icons.help_outline,
    );
  }
}
