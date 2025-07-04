import 'package:flutter/material.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../widgets/kategori_karti_widget.dart';
import '../widgets/kategori_form_dialog.dart';
import '../screens/belgeler_ekrani.dart';

class KategorilerEkrani extends StatefulWidget {
  const KategorilerEkrani({Key? key}) : super(key: key);

  @override
  State<KategorilerEkrani> createState() => _KategorilerEkraniState();
}

class _KategorilerEkraniState extends State<KategorilerEkrani> {
  final VeriTabaniServisi _veriTabaniServisi = VeriTabaniServisi();

  List<KategoriModeli> _kategoriler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _kategorileriYukle();
  }

  Future<void> _kategorileriYukle() async {
    setState(() => _yukleniyor = true);

    try {
      final kategoriler = await _veriTabaniServisi.kategorileriGetir();
      print('Kategoriler yüklendi: ${kategoriler.length} adet');

      // Eğer kategori yoksa, default kategorileri ekle
      if (kategoriler.isEmpty) {
        print('Kategori bulunamadı, default kategoriler ekleniyor...');
        await _defaultKategorileriEkle();
        final yeniKategoriler = await _veriTabaniServisi.kategorileriGetir();
        print('Default kategoriler eklendi: ${yeniKategoriler.length} adet');

        setState(() {
          _kategoriler = yeniKategoriler;
          _yukleniyor = false;
        });
        return;
      }

      // Gerçek belge sayılarını yükle
      final kategoriBelgeSayilari =
          await _veriTabaniServisi.kategoriBelgeSayilari();

      for (var kategori in kategoriler) {
        kategori.belgeSayisi = kategoriBelgeSayilari[kategori.id] ?? 0;
      }

      setState(() {
        _kategoriler = kategoriler;
        _yukleniyor = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _yeniKategoriEkle,
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Kategori',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset_db') {
                final onay = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Veritabanını Sıfırla'),
                        content: const Text(
                          'Tüm veriler silinecek. Emin misiniz?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Sıfırla'),
                          ),
                        ],
                      ),
                );

                if (onay == true) {
                  await _veriTabaniServisi.veritabaniniSifirla();
                  _kategorileriYukle();
                  _basariGoster('Veritabanı sıfırlandı');
                }
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'reset_db',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Veritabanını Sıfırla'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade50, Colors.white],
          ),
        ),
        child:
            _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _kategoriler.isEmpty
                ? _buildBosListe()
                : RefreshIndicator(
                  onRefresh: _kategorileriYukle,
                  child: Column(
                    children: [
                      // İstatistikler
                      _buildIstatistikler(),

                      // Kategori listesi
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _kategoriler.length,
                          itemBuilder: (context, index) {
                            final kategori = _kategoriler[index];
                            return KategoriKartiWidget(
                              kategori: kategori,
                              onTap: () => _kategoriDetayGoster(kategori),
                              onLongPress: () => _kategoriDuzenle(kategori),
                              onDuzenle: () => _kategoriDuzenle(kategori),
                              onSil: () => _kategoriSil(kategori),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeniKategoriEkle,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Kategori Ekle'),
      ),
    );
  }

  Widget _buildIstatistikler() {
    final toplamKategori = _kategoriler.length;
    final toplamBelge = _kategoriler.fold(
      0,
      (sum, k) => sum + (k.belgeSayisi ?? 0),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIstatistikKarti(
            'Toplam Kategori',
            toplamKategori.toString(),
            Icons.category,
            Colors.purple,
          ),
          const SizedBox(width: 16),
          _buildIstatistikKarti(
            'Toplam Belge',
            toplamBelge.toString(),
            Icons.description,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildIstatistikKarti(
    String baslik,
    String deger,
    IconData icon,
    Color renk,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: renk, size: 24),
            const SizedBox(height: 8),
            Text(
              deger,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: renk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              baslik,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBosListe() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Henüz kategori eklenmemiş',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk kategorinizi eklemek için + butonuna tıklayın',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _yeniKategoriEkle,
            icon: const Icon(Icons.add),
            label: const Text('Kategori Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
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
        print('DEBUG: Kategori eklenecek: ${sonuc.toMap()}');
        await _veriTabaniServisi.kategoriEkle(sonuc);
        _basariGoster('Kategori başarıyla eklendi');
        _kategorileriYukle();
      } catch (e) {
        print('DEBUG: Kategori ekleme hatası: $e');
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
    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kategoriyi Sil'),
            content: Text(
              '${kategori.kategoriAdi} kategorisi ve bu kategoriye ait tüm belgeler silinecektir. Emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (onay == true) {
      try {
        await _veriTabaniServisi.kategoriSil(kategori.id!);
        // Kategoriye ait belgeleri de sil
        // TODO: Belge silme servisi üzerinden belgelerin de silinmesi sağlanmalı.
        _basariGoster('Kategori başarıyla silindi');
        _kategorileriYukle();
      } catch (e) {
        _hataGoster('Kategori silinirken hata oluştu: $e');
      }
    }
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.green),
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
  }
}
