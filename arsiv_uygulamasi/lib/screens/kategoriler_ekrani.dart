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
      appBar: ScreenUtils.buildAppBar(
        title: 'Kategoriler',
        backgroundColor: Colors.transparent,
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
              } else if (value == 'toplu_sil') {
                _topluSilmeDialogGoster();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'toplu_sil',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Toplu Silme İşlemleri'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
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
      body: ScreenUtils.buildGradientContainer(
        colors: [Colors.purple.shade50, Colors.white],
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
                              onSilmeSecimi:
                                  (secimTipi) =>
                                      _hizliSilmeSecimi(secimTipi, kategori),
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
    return ScreenUtils.buildEmptyState(
      icon: Icons.category_outlined,
      title: 'Henüz kategori eklenmemiş',
      message: 'İlk kategorinizi eklemek için + butonuna tıklayın',
      actionText: 'Kategori Ekle',
      onAction: _yeniKategoriEkle,
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
    final secim = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text('${kategori.kategoriAdi} Kategorisi'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu kategoride ${kategori.belgeSayisi ?? 0} belge bulunuyor.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hangi verileri silmek istiyorsunuz?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Kişileri Sil: Sadece kategoriye ait kişileri siler\n'
                  '• Belgeleri Sil: Sadece kategoriye ait belgeleri siler\n'
                  '• Hepsini Sil: Hem kişileri hem belgeleri siler',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('kisiler'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Kişileri Sil'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('belgeler'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('Belgeleri Sil'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('hepsi'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hepsini Sil'),
              ),
            ],
          ),
    );

    if (secim != null) {
      // Onay dialog'u göster
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

  Future<bool?> _onayDialog(String secim, KategoriModeli kategori) async {
    String baslik = '';
    String mesaj = '';
    Color renk = Colors.red;

    switch (secim) {
      case 'kisiler':
        baslik = 'Kişileri Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki kişiler silinecek. Emin misiniz?';
        renk = Colors.orange;
        break;
      case 'belgeler':
        baslik = 'Belgeleri Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki belgeler silinecek. Emin misiniz?';
        renk = Colors.blue;
        break;
      case 'hepsi':
        baslik = 'Hepsini Sil';
        mesaj =
            '${kategori.kategoriAdi} kategorisindeki hem kişiler hem belgeler silinecek. Emin misiniz?';
        renk = Colors.red;
        break;
    }

    return await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: renk),
                const SizedBox(width: 8),
                Text(baslik),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mesaj),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: renk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: renk, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bu işlem geri alınamaz!',
                          style: TextStyle(fontWeight: FontWeight.w500),
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: renk),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  // Hızlı silme seçimi (karttan direkt silme)
  Future<void> _hizliSilmeSecimi(String secim, KategoriModeli kategori) async {
    // Onay dialog'u göster
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

  void _basariGoster(String mesaj) {
    ScreenUtils.showSuccessSnackBar(context, mesaj);
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }

  // Toplu silme dialog'u
  Future<void> _topluSilmeDialogGoster() async {
    final secim = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.delete_sweep, color: Colors.orange),
                SizedBox(width: 8),
                Text('Toplu Silme İşlemleri'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tüm kategorilerdeki verileri silmek istediğiniz alanları seçin:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  '• Tüm Kişileri Sil: Bütün kategorilerdeki kişileri siler\n'
                  '• Tüm Belgeleri Sil: Bütün kategorilerdeki belgeleri siler\n'
                  '• Tüm Verileri Sil: Hem kişileri hem belgeleri siler',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu işlemler geri alınamaz ve tüm kategorileri etkiler!',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
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
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('tum_kisiler'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Tüm Kişileri Sil'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('tum_belgeler'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('Tüm Belgeleri Sil'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('tum_veriler'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Tüm Verileri Sil'),
              ),
            ],
          ),
    );

    if (secim != null) {
      await _topluSilmeOnayDialog(secim);
    }
  }

  // Toplu silme onay dialog'u
  Future<void> _topluSilmeOnayDialog(String secim) async {
    String baslik = '';
    String mesaj = '';
    Color renk = Colors.red;
    IconData icon = Icons.warning;

    switch (secim) {
      case 'tum_kisiler':
        baslik = 'Tüm Kişileri Sil';
        mesaj =
            'Tüm kategorilerdeki kişiler silinecek. Bu işlem geri alınamaz!';
        renk = Colors.orange;
        icon = Icons.person_remove;
        break;
      case 'tum_belgeler':
        baslik = 'Tüm Belgeleri Sil';
        mesaj =
            'Tüm kategorilerdeki belgeler silinecek. Bu işlem geri alınamaz!';
        renk = Colors.blue;
        icon = Icons.delete_sweep;
        break;
      case 'tum_veriler':
        baslik = 'Tüm Verileri Sil';
        mesaj =
            'Tüm kategorilerdeki kişiler ve belgeler silinecek. Bu işlem geri alınamaz!';
        renk = Colors.red;
        icon = Icons.delete_forever;
        break;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(icon, color: renk),
                const SizedBox(width: 8),
                Text(baslik),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mesaj),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: renk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: renk.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: renk, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bu işlem TÜM kategorileri etkiler ve geri alınamaz!',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: renk,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (onay == true) {
      await _topluSilmeIslemiGerceklestir(secim);
    }
  }

  // Toplu silme işlemini gerçekleştir
  Future<void> _topluSilmeIslemiGerceklestir(String secim) async {
    try {
      setState(() => _yukleniyor = true);

      int toplamKisiSayisi = 0;
      int toplamBelgeSayisi = 0;

      switch (secim) {
        case 'tum_kisiler':
          // Tüm kategorilerdeki kişileri sil
          for (final kategori in _kategoriler) {
            final silinenKisiSayisi = await _veriTabaniServisi
                .kategoriKisileriSil(kategori.id!);
            toplamKisiSayisi += silinenKisiSayisi;
          }
          _basariGoster('Toplam $toplamKisiSayisi kişi başarıyla silindi');
          break;

        case 'tum_belgeler':
          // Tüm kategorilerdeki belgeleri sil
          for (final kategori in _kategoriler) {
            final silinenBelgeSayisi = await _veriTabaniServisi
                .kategoriBelgeleriSil(kategori.id!);
            toplamBelgeSayisi += silinenBelgeSayisi;
          }
          _basariGoster('Toplam $toplamBelgeSayisi belge başarıyla silindi');
          break;

        case 'tum_veriler':
          // Tüm kategorilerdeki hem kişileri hem belgeleri sil
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

      // Kategorileri yeniden yükle
      await _kategorileriYukle();
    } catch (e) {
      _hataGoster('Toplu silme işlemi sırasında hata oluştu: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }
}
