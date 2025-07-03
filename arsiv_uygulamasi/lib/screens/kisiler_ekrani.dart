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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişiler'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _yeniKisiEkle,
            icon: const Icon(Icons.person_add),
            tooltip: 'Yeni Kişi Ekle',
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
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Henüz kişi eklenmemiş',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk kişiyi eklemek için üstteki + simgesine dokunun',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildKisiKarti(KisiModeli kisi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            kisi.ad.isNotEmpty ? kisi.ad[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          kisi.tamAd,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            FutureBuilder<int>(
              future: _veriTabani.kisiBelgeSayisi(kisi.id!),
              builder: (context, snapshot) {
                final belgeSayisi = snapshot.data ?? 0;
                return Text(
                  '$belgeSayisi belge',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              'Eklendi: ${kisi.formatliOlusturmaTarihi}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _kisiMenuSecimi(value, kisi),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'duzenle',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'belgeler',
                  child: Row(
                    children: [
                      Icon(Icons.folder),
                      SizedBox(width: 8),
                      Text('Belgeleri Gör'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sil',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sil', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
        onTap: () => _kisiDetayGoster(kisi),
      ),
    );
  }

  void _kisiMenuSecimi(String secim, KisiModeli kisi) {
    switch (secim) {
      case 'duzenle':
        _kisiDuzenle(kisi);
        break;
      case 'belgeler':
        _kisiBelgeleriGoster(kisi);
        break;
      case 'sil':
        _kisiSilOnay(kisi);
        break;
    }
  }

  void _kisiDetayGoster(KisiModeli kisi) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(kisi.tamAd),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ad: ${kisi.ad}'),
                Text('Soyad: ${kisi.soyad}'),
                Text('Eklendi: ${kisi.formatliOlusturmaTarihi}'),
                Text('Güncellendi: ${kisi.formatliGuncellemeTarihi}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  Future<void> _yeniKisiEkle() async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const KisiEkleEkrani()),
    );

    // Eğer başarılı bir şekilde kişi eklendiyse verileri yenile
    if (sonuc == true) {
      _kisileriYukle();
    }
  }

  Future<void> _kisiDuzenle(KisiModeli kisi) async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => KisiEkleEkrani(kisi: kisi)),
    );

    // Eğer başarılı bir şekilde kişi güncellendiyse verileri yenile
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
            title: const Text('Kişiyi Sil'),
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
