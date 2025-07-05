import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/tarayici_servisi.dart';
import '../services/test_tarayici_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../utils/yardimci_fonksiyonlar.dart';

class TarayiciEkrani extends StatefulWidget {
  const TarayiciEkrani({Key? key}) : super(key: key);

  @override
  State<TarayiciEkrani> createState() => _TarayiciEkraniState();
}

class _TarayiciEkraniState extends State<TarayiciEkrani> {
  final TarayiciServisi _tarayiciServisi = TarayiciServisi();
  final TestTarayiciServisi _testTarayiciServisi = TestTarayiciServisi();
  final BelgeIslemleriServisi _belgeIslemleri = BelgeIslemleriServisi();
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();

  bool _testModu = false; // Test modu flag'i

  List<String> _bulunanTarayicilar = [];
  String? _secilenTarayici;
  bool _tarayiciAranyor = false;
  bool _taramaDurumu = false;
  String? _tarananBelgePath;

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
      _hataGoster('Kategoriler ve kişiler yüklenirken hata: $e');
    }
  }

  Future<void> _tarayicilariAra() async {
    setState(() {
      _tarayiciAranyor = true;
      _bulunanTarayicilar.clear();
      _secilenTarayici = null;
    });

    try {
      final tarayicilar =
          _testModu
              ? await _testTarayiciServisi.tarayicilariAra()
              : await _tarayiciServisi.tarayicilariAra();

      setState(() {
        _bulunanTarayicilar = tarayicilar;
        _tarayiciAranyor = false;

        if (tarayicilar.isNotEmpty) {
          _secilenTarayici = tarayicilar.first;
        }
      });
    } catch (e) {
      setState(() {
        _tarayiciAranyor = false;
      });
      _hataGoster('Tarayıcı arama hatası: $e');
    }
  }

  Future<void> _belgeTara() async {
    if (_secilenTarayici == null) {
      _hataGoster('Önce bir tarayıcı seçin');
      return;
    }

    setState(() {
      _taramaDurumu = true;
    });

    try {
      final scannedPath =
          _testModu
              ? await _testTarayiciServisi.belgeTara(_secilenTarayici!)
              : await _tarayiciServisi.belgeTara(_secilenTarayici!);

      if (scannedPath != null && scannedPath.isNotEmpty) {
        setState(() {
          _tarananBelgePath = scannedPath;
          _taramaDurumu = false;
        });

        // Taranan belge için varsayılan başlık oluştur
        final now = DateTime.now();
        _baslikController.text =
            _testModu
                ? 'Test Taranan Belge ${now.day}/${now.month}/${now.year}'
                : 'Taranan Belge ${now.day}/${now.month}/${now.year}';

        _basariGoster(
          _testModu
              ? 'Test belgesi başarıyla oluşturuldu!'
              : 'Belge başarıyla tarandı!',
        );
      } else {
        setState(() {
          _taramaDurumu = false;
        });
        _hataGoster('Belge tarama işlemi iptal edildi');
      }
    } catch (e) {
      setState(() {
        _taramaDurumu = false;
      });
      _hataGoster('Belge tarama hatası: $e');
    }
  }

  Future<void> _belgeKaydet() async {
    if (_tarananBelgePath == null) {
      _hataGoster('Önce bir belge tarayın');
      return;
    }

    if (_baslikController.text.trim().isEmpty) {
      _hataGoster('Belge başlığı boş olamaz');
      return;
    }

    try {
      final tempFile = File(_tarananBelgePath!);
      if (!await tempFile.exists()) {
        _hataGoster('Taranan belge dosyası bulunamadı');
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

      _basariGoster(
        'Belge başarıyla tarandı ve kalıcı olarak kaydedildi! Ana ekranda görüntülenecek.',
      );
      _formuTemizle();

      // Ana ekranın belgeler listesini yenilemesi için bildirim gönder
      // Kullanıcı ana ekrana gidince yeni taranan belgeyi görebilir
    } catch (e) {
      _hataGoster('Belge kaydedilirken hata: $e');
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

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _testModu ? 'Belge Tarayıcı (Test Modu)' : 'Belge Tarayıcı',
        ),
        backgroundColor: _testModu ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Test modu switch'i
          Row(
            children: [
              const Text('Test', style: TextStyle(fontSize: 12)),
              Switch(
                value: _testModu,
                onChanged: (value) {
                  setState(() {
                    _testModu = value;
                    _bulunanTarayicilar.clear();
                    _secilenTarayici = null;
                    _tarananBelgePath = null;
                  });
                  _tarayicilariAra(); // Yeni modda tarayıcıları ara
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _tarayicilariAra,
            tooltip: 'Tarayıcıları Yenile',
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scanner, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Tarayıcı Seçimi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            else if (_bulunanTarayicilar.isEmpty)
              const Text(
                'Hiç tarayıcı bulunamadı. Tarayıcınızın bağlı ve açık olduğundan emin olun.',
                style: TextStyle(color: Colors.orange),
              )
            else
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _secilenTarayici,
                    decoration: const InputDecoration(
                      labelText: 'Tarayıcı',
                      border: OutlineInputBorder(),
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
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _secilenTarayici != null ? _belgeTara : null,
                        icon: const Icon(Icons.scanner),
                        label: const Text('Belge Tara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
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
      color: _testModu ? Colors.orange.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _testModu ? Icons.bug_report : Icons.document_scanner,
                  color: _testModu ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _testModu ? 'Test Tarama Durumu' : 'Tarama Durumu',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_testModu) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ Test Modu Aktif: Gerçek PDF dosyaları oluşturulacak',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_taramaDurumu)
              Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(
                    _testModu
                        ? 'Test belgesi oluşturuluyor...'
                        : 'Belge taranıyor...',
                  ),
                ],
              )
            else if (_tarananBelgePath != null)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    'Belge başarıyla tarandı!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Belge Detayları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ),
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _aciklamaController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
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
              style: TextStyle(fontWeight: FontWeight.bold),
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
                    ),
                    onFieldSubmitted: (_) => _etiketEkle(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _etiketEkle,
                  child: const Text('Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  _etiketler.map((etiket) {
                    return Chip(
                      label: Text(etiket),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => _etiketSil(etiket),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),

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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
