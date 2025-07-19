import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../utils/screen_utils.dart';
import '../utils/yardimci_fonksiyonlar.dart';

class BelgeDuzenleEkrani extends StatefulWidget {
  final BelgeModeli belge;

  const BelgeDuzenleEkrani({
    Key? key,
    required this.belge,
  }) : super(key: key);

  @override
  State<BelgeDuzenleEkrani> createState() => _BelgeDuzenleEkraniState();
}

class _BelgeDuzenleEkraniState extends State<BelgeDuzenleEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _baslikController = TextEditingController();
  final _aciklamaController = TextEditingController();
  final _etiketController = TextEditingController();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();

  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  KategoriModeli? _secilenKategori;
  KisiModeli? _secilenKisi;
  List<String> _etiketler = [];
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _formBilgileriniDoldur();
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _etiketController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    try {
      final kategoriler = await _veriTabani.kategorileriGetir();
      final kisiler = await _veriTabani.kisileriGetir();

      setState(() {
        _kategoriler = kategoriler;
        _kisiler = kisiler;
        
        // Belgenin mevcut kategori ve kişisini bul
        if (widget.belge.kategoriId != null && kategoriler.isNotEmpty) {
          try {
            _secilenKategori = kategoriler.firstWhere(
              (k) => k.id == widget.belge.kategoriId,
            );
          } catch (e) {
            _secilenKategori = kategoriler.isNotEmpty ? kategoriler.first : null;
          }
        }
        
        if (widget.belge.kisiId != null && kisiler.isNotEmpty) {
          try {
            _secilenKisi = kisiler.firstWhere(
              (k) => k.id == widget.belge.kisiId,
            );
          } catch (e) {
            _secilenKisi = kisiler.isNotEmpty ? kisiler.first : null;
          }
        }
      });
    } catch (e) {
      ScreenUtils.showErrorSnackBar(context, 'Veriler yüklenirken hata oluştu: $e');
    }
  }

  void _formBilgileriniDoldur() {
    _baslikController.text = widget.belge.baslik ?? widget.belge.orijinalDosyaAdi;
    _aciklamaController.text = widget.belge.aciklama ?? '';
    _etiketler = widget.belge.etiketler ?? [];
  }

  Future<void> _belgeKaydet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      // Güncellenmiş belge modelini oluştur
      final guncellenmiBelge = BelgeModeli(
        id: widget.belge.id,
        dosyaAdi: widget.belge.dosyaAdi,
        orijinalDosyaAdi: widget.belge.orijinalDosyaAdi,
        dosyaYolu: widget.belge.dosyaYolu,
        dosyaBoyutu: widget.belge.dosyaBoyutu,
        dosyaTipi: widget.belge.dosyaTipi,
        dosyaHash: widget.belge.dosyaHash,
        kategoriId: _secilenKategori?.id,
        kisiId: _secilenKisi?.id,
        baslik: _baslikController.text.trim().isEmpty 
            ? null 
            : _baslikController.text.trim(),
        aciklama: _aciklamaController.text.trim().isEmpty 
            ? null 
            : _aciklamaController.text.trim(),
        etiketler: _etiketler.isEmpty ? null : _etiketler,
        olusturmaTarihi: widget.belge.olusturmaTarihi,
        guncellemeTarihi: DateTime.now(),
        sonErisimTarihi: widget.belge.sonErisimTarihi,
        aktif: widget.belge.aktif,
        senkronDurumu: SenkronDurumu.YEREL_DEGISIM,
      );

      await _veriTabani.belgeGuncelle(guncellenmiBelge);

      if (mounted) {
        ScreenUtils.showSuccessSnackBar(context, 'Belge başarıyla güncellendi');
        Navigator.of(context).pop(true); // Geri dön ve değişiklikleri kaydet
      }
    } catch (e) {
      ScreenUtils.showErrorSnackBar(context, 'Belge güncellenirken hata oluştu: $e');
    } finally {
      setState(() {
        _yukleniyor = false;
      });
    }
  }

  void _etiketEkle() {
    final etiket = _etiketController.text.trim();
    if (etiket.isNotEmpty && !_etiketler.contains(etiket)) {
      setState(() {
        _etiketler.add(etiket);
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
      appBar: AppBar(
        title: const Text('Belge Düzenle'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_yukleniyor)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _belgeKaydet,
              icon: const Icon(Icons.save),
              tooltip: 'Kaydet',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dosya bilgileri (salt okunur)
              _buildDosyaBilgileri(),
              const SizedBox(height: 24),

              // Düzenlenebilir alanlar
              _buildDuzenlenebilirAlanlar(),
              const SizedBox(height: 24),

              // Kaydet butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _yukleniyor ? null : _belgeKaydet,
                  icon: _yukleniyor 
                      ? const SizedBox(
                          width: 16, 
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_yukleniyor ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDosyaBilgileri() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dosya Bilgileri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBilgiSatiri('Dosya Adı', widget.belge.dosyaAdi),
            _buildBilgiSatiri('Orijinal Ad', widget.belge.orijinalDosyaAdi),
            _buildBilgiSatiri('Dosya Tipi', widget.belge.dosyaTipi.toUpperCase()),
            _buildBilgiSatiri('Boyut', widget.belge.formatliDosyaBoyutu),
            _buildBilgiSatiri('Oluşturulma', widget.belge.formatliOlusturmaTarihi),
            _buildBilgiSatiri('Son Güncelleme', widget.belge.formatliGuncellemeTarihi),
            _buildBilgiSatiri('Dosya Yolu', widget.belge.dosyaYolu),
          ],
        ),
      ),
    );
  }

  Widget _buildBilgiSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$baslik:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              deger,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuzenlenebilirAlanlar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        TextFormField(
          controller: _baslikController,
          decoration: InputDecoration(
            labelText: 'Belge Başlığı',
            hintText: 'Belge için bir başlık girin',
            prefixIcon: const Icon(Icons.title),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Başlık boş olamaz';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Açıklama
        TextFormField(
          controller: _aciklamaController,
          decoration: InputDecoration(
            labelText: 'Açıklama',
            hintText: 'Belge hakkında açıklama girin',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

                 // Kategori seçimi
         if (_kategoriler.isNotEmpty)
           DropdownButtonFormField<KategoriModeli>(
             value: _secilenKategori,
             decoration: InputDecoration(
               labelText: 'Kategori',
               prefixIcon: const Icon(Icons.category),
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
               filled: true,
               fillColor: Colors.grey[50],
             ),
             items: _kategoriler.map((kategori) {
               return DropdownMenuItem(
                 value: kategori,
                 child: Text(kategori.kategoriAdi),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _secilenKategori = value;
               });
             },
           )
         else
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.grey[100],
               borderRadius: BorderRadius.circular(12),
             ),
             child: const Text('Kategori bulunamadı'),
           ),
        const SizedBox(height: 16),

                 // Kişi seçimi
         if (_kisiler.isNotEmpty)
           DropdownButtonFormField<KisiModeli>(
             value: _secilenKisi,
             decoration: InputDecoration(
               labelText: 'İlgili Kişi',
               prefixIcon: const Icon(Icons.person),
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
               filled: true,
               fillColor: Colors.grey[50],
             ),
             items: _kisiler.map((kisi) {
               return DropdownMenuItem(
                 value: kisi,
                 child: Text(kisi.tamAd),
               );
             }).toList(),
             onChanged: (value) {
               setState(() {
                 _secilenKisi = value;
               });
             },
           )
         else
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.grey[100],
               borderRadius: BorderRadius.circular(12),
             ),
             child: const Text('Kişi bulunamadı'),
           ),
        const SizedBox(height: 16),

        // Etiket ekleme
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _etiketController,
                decoration: InputDecoration(
                  labelText: 'Etiket Ekle',
                  hintText: 'Yeni etiket girin',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onFieldSubmitted: (_) => _etiketEkle(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _etiketEkle,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Mevcut etiketler
        if (_etiketler.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _etiketler.map((etiket) {
              return Chip(
                label: Text(etiket),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => _etiketSil(etiket),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                deleteIconColor: Theme.of(context).primaryColor,
              );
            }).toList(),
          ),
      ],
    );
  }
} 