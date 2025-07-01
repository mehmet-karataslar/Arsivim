import 'package:flutter/material.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';

class KisiEkleEkrani extends StatefulWidget {
  final KisiModeli? kisi; // Düzenleme için mevcut kişi

  const KisiEkleEkrani({Key? key, this.kisi}) : super(key: key);

  @override
  State<KisiEkleEkrani> createState() => _KisiEkleEkraniState();
}

class _KisiEkleEkraniState extends State<KisiEkleEkrani> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();

  bool _kayitEdiliyor = false;

  @override
  void initState() {
    super.initState();

    // Eğer düzenleme modundaysa mevcut verileri yükle
    if (widget.kisi != null) {
      _adController.text = widget.kisi!.ad;
      _soyadController.text = widget.kisi!.soyad;
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    super.dispose();
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
  }

  void _basariMesajiGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool duzenlemeModundaMi = widget.kisi != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(duzenlemeModundaMi ? 'Kişiyi Düzenle' : 'Yeni Kişi Ekle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_kayitEdiliyor)
            TextButton(
              onPressed: _kisiKaydet,
              child: Text(
                duzenlemeModundaMi ? 'GÜNCELLE' : 'KAYDET',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body:
          _kayitEdiliyor
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Kişi kaydediliyor...'),
                  ],
                ),
              )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bilgi kartı
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kişi bilgilerini girin. Bu kişiye ait belgeler organize edilecektir.',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Ad alanı
            TextFormField(
              controller: _adController,
              decoration: const InputDecoration(
                labelText: 'Ad *',
                hintText: 'Kişinin adını girin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad alanı boş olamaz';
                }
                if (value.trim().length < 2) {
                  return 'Ad en az 2 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Soyad alanı
            TextFormField(
              controller: _soyadController,
              decoration: const InputDecoration(
                labelText: 'Soyad *',
                hintText: 'Kişinin soyadını girin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Soyad alanı boş olamaz';
                }
                if (value.trim().length < 2) {
                  return 'Soyad en az 2 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Kaydet butonu (alternatif)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _kayitEdiliyor ? null : _kisiKaydet,
                icon: Icon(widget.kisi != null ? Icons.edit : Icons.person_add),
                label: Text(
                  widget.kisi != null ? 'Kişiyi Güncelle' : 'Kişiyi Kaydet',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // İptal butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _kayitEdiliyor ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.cancel),
                label: const Text('İptal', style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Zorunlu alan uyarısı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '* işaretli alanlar zorunludur',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kisiKaydet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _kayitEdiliyor = true;
    });

    try {
      DateTime simdi = DateTime.now();
      String ad = _adController.text.trim();
      String soyad = _soyadController.text.trim();

      if (widget.kisi == null) {
        // Yeni kişi ekle
        KisiModeli yeniKisi = KisiModeli(
          ad: ad,
          soyad: soyad,
          olusturmaTarihi: simdi,
          guncellemeTarihi: simdi,
        );

        await _veriTabani.kisiEkle(yeniKisi);
        _basariMesajiGoster('Kişi başarıyla eklendi');
      } else {
        // Mevcut kişiyi güncelle
        KisiModeli guncellenmisKisi = widget.kisi!.copyWith(
          ad: ad,
          soyad: soyad,
          guncellemeTarihi: simdi,
        );

        await _veriTabani.kisiGuncelle(guncellenmisKisi);
        _basariMesajiGoster('Kişi başarıyla güncellendi');
      }

      // Başarılı kayıt sonrası geri dön
      Navigator.of(context).pop(true); // true = başarılı
    } catch (e) {
      _hataGoster('Kişi kaydedilirken hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _kayitEdiliyor = false;
        });
      }
    }
  }
}
