import 'package:flutter/material.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import 'kisi_ekle_ekrani.dart';
import 'kisi_belgeleri_ekrani.dart';

class KisilerEkrani extends StatefulWidget {
  const KisilerEkrani({Key? key}) : super(key: key);

  @override
  State<KisilerEkrani> createState() => _KisilerEkraniState();
}

class _KisilerEkraniState extends State<KisilerEkrani> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  List<KisiModeli> _kisiler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _kisileriYukle();
  }

  Future<void> _kisileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      final kisiler = await _veriTabani.kisileriGetir();
      setState(() {
        _kisiler = kisiler;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Kişiler yüklenirken hata oluştu: $e');
    }
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _basariMesajiGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Kişiler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        shadowColor: Colors.black12,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Material(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _yeniKisiEkle,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _buildKisiListesi(),
    );
  }

  Widget _buildKisiListesi() {
    if (_kisiler.isEmpty) {
      return _buildBosList();
    }

    return RefreshIndicator(
      onRefresh: _kisileriYukle,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _kisiler.length,
        itemBuilder: (context, index) {
          return _buildKisiKarti(_kisiler[index]);
        },
      ),
    );
  }

  Widget _buildBosList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz kişi eklenmemiş',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk kişiyi eklemek için üstteki + simgesine dokunun',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildKisiKarti(KisiModeli kisi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Üst kısım - Kişi bilgileri
          InkWell(
            onTap: () => _kisiDetayGoster(kisi),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.8),
                          Theme.of(context).primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        kisi.ad.isNotEmpty ? kisi.ad[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Kişi bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kisi.tamAd,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: _veriTabani.kisiBelgeSayisi(kisi.id!),
                          builder: (context, snapshot) {
                            final belgeSayisi = snapshot.data ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$belgeSayisi belge',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Eklendi: ${kisi.formatliOlusturmaTarihi}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Alt kısım - Butonlar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Düzenle butonu
                Expanded(
                  child: InkWell(
                    onTap: () => _kisiDuzenle(kisi),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Düzenle',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Ayırıcı çizgi
                Container(width: 1, height: 50, color: Colors.grey.shade300),
                // Belgeler butonu
                Expanded(
                  child: InkWell(
                    onTap: () => _kisiBelgeleriGoster(kisi),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Belgeler',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Ayırıcı çizgi
                Container(width: 1, height: 50, color: Colors.grey.shade300),
                // Sil butonu
                Expanded(
                  child: InkWell(
                    onTap: () => _kisiSilOnay(kisi),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sil',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _kisiDetayGoster(KisiModeli kisi) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.8),
                        Theme.of(context).primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      kisi.ad.isNotEmpty ? kisi.ad[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    kisi.tamAd,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetayBilgi('Ad', kisi.ad),
                _buildDetayBilgi('Soyad', kisi.soyad),
                _buildDetayBilgi('Eklendi', kisi.formatliOlusturmaTarihi),
                _buildDetayBilgi('Güncellendi', kisi.formatliGuncellemeTarihi),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetayBilgi(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$baslik:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(deger, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Future<void> _yeniKisiEkle() async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const KisiEkleEkrani()),
    );

    if (sonuc == true) {
      _kisileriYukle();
    }
  }

  Future<void> _kisiDuzenle(KisiModeli kisi) async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => KisiEkleEkrani(kisi: kisi)),
    );

    if (sonuc == true) {
      _kisileriYukle();
    }
  }

  void _kisiBelgeleriGoster(KisiModeli kisi) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => KisiBelgeleriEkrani(kisi: kisi)),
    );
  }

  void _kisiSilOnay(KisiModeli kisi) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                const Text('Kişiyi Sil'),
              ],
            ),
            content: Text(
              '${kisi.tamAd} kişisini silmek istediğinizden emin misiniz?\n\nBu kişiye ait belgeler etkilenmeyecektir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _kisiSil(kisi);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  Future<void> _kisiSil(KisiModeli kisi) async {
    try {
      await _veriTabani.kisiSil(kisi.id!);
      _basariMesajiGoster('Kişi başarıyla silindi');
      _kisileriYukle();
    } catch (e) {
      _hataGoster('Kişi silinirken hata oluştu: $e');
    }
  }
}
