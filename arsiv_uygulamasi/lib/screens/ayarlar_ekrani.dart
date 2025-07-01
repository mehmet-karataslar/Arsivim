import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ayarlar_servisi.dart';
import '../services/tema_yoneticisi.dart';
import '../main.dart';
import 'usb_senkron_ekrani.dart';

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({Key? key}) : super(key: key);

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  final AyarlarServisi _ayarlarServisi = AyarlarServisi.instance;

  TemaSecenek _secilenTema = TemaSecenek.sistem;
  bool _otomatikYedekleme = false;
  int _yedeklemeAraligi = 7;
  bool _bildirimlereIzin = true;
  List<String> _yedekDosyalari = [];
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    setState(() => _yukleniyor = true);

    try {
      final tema = await _ayarlarServisi.getTemaSecenegi();
      final otomatikYedekleme = await _ayarlarServisi.getOtomatikYedekleme();
      final yedeklemeAraligi = await _ayarlarServisi.getYedeklemeAraligi();
      final bildirimlereIzin = await _ayarlarServisi.getBildirimlereIzin();
      final yedekDosyalari = await _ayarlarServisi.yedekDosyalariniListele();

      setState(() {
        _secilenTema = tema;
        _otomatikYedekleme = otomatikYedekleme;
        _yedeklemeAraligi = yedeklemeAraligi;
        _bildirimlereIzin = bildirimlereIzin;
        _yedekDosyalari = yedekDosyalari;
      });
    } catch (e) {
      _hataGoster('Ayarlar yüklenirken hata: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _temaDegisTir(TemaSecenek yeniTema) async {
    try {
      await _ayarlarServisi.setTemaSecenegi(yeniTema);
      setState(() => _secilenTema = yeniTema);

      // Ana uygulamaya tema değişikliğini bildir
      if (mounted) {
        MyApp.of(context)?.changeTema(yeniTema);
      }

      _basariGoster('Tema değiştirildi');
    } catch (e) {
      _hataGoster('Tema değiştirirken hata: $e');
    }
  }

  Future<void> _veritabaniYedekle() async {
    setState(() => _yukleniyor = true);

    try {
      final yedekDosyaYolu = await _ayarlarServisi.veritabaniYedekle();
      await _ayarlariYukle(); // Yedek listesini güncelle
      _basariGoster('Veritabanı başarıyla yedeklendi');
    } catch (e) {
      _hataGoster('Yedekleme hatası: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _veritabaniGeriYukle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Yedek dosyası seçin',
      );

      if (result != null && result.files.single.path != null) {
        final onay = await _onayIste(
          'Veritabanını Geri Yükle',
          'Mevcut veriler silinecek ve yedek dosyasındaki veriler geri yüklenecek. Devam etmek istiyor musunuz?',
        );

        if (onay) {
          setState(() => _yukleniyor = true);

          await _ayarlarServisi.veritabaniGeriYukle(result.files.single.path!);
          _basariGoster(
            'Veritabanı başarıyla geri yüklendi. Uygulamayı yeniden başlatın.',
          );
        }
      }
    } catch (e) {
      _hataGoster('Geri yükleme hatası: $e');
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _yedekDosyasiniSil(String dosyaYolu) async {
    final onay = await _onayIste(
      'Yedek Dosyasını Sil',
      'Bu yedek dosyasını silmek istediğinizden emin misiniz?',
    );

    if (onay) {
      try {
        await _ayarlarServisi.yedekDosyasiniSil(dosyaYolu);
        await _ayarlariYukle(); // Listeyi güncelle
        _basariGoster('Yedek dosyası silindi');
      } catch (e) {
        _hataGoster('Silme hatası: $e');
      }
    }
  }

  Future<void> _ayarlariSifirla() async {
    final onay = await _onayIste(
      'Ayarları Sıfırla',
      'Tüm ayarlar varsayılan değerlere döndürülecek. Devam etmek istiyor musunuz?',
    );

    if (onay) {
      try {
        await _ayarlarServisi.ayarlariSifirla();
        await _ayarlariYukle();
        _basariGoster('Ayarlar sıfırlandı');
      } catch (e) {
        _hataGoster('Sıfırlama hatası: $e');
      }
    }
  }

  String _dosyaAdiniBul(String dosyaYolu) {
    return dosyaYolu.split('/').last.split('\\').last;
  }

  String _tarihFormatla(String dosyaAdi) {
    try {
      final parts = dosyaAdi.split('_');
      if (parts.length >= 3) {
        final tarihPart = parts[2];
        final saatPart = parts[3].replaceAll('.db', '');

        final yil = tarihPart.substring(0, 4);
        final ay = tarihPart.substring(4, 6);
        final gun = tarihPart.substring(6, 8);

        final saat = saatPart.substring(0, 2);
        final dakika = saatPart.substring(2, 4);

        return '$gun/$ay/$yil $saat:$dakika';
      }
    } catch (e) {
      // Ignore
    }
    return dosyaAdi;
  }

  Future<bool> _onayIste(String baslik, String mesaj) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(baslik),
            content: Text(mesaj),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Devam Et'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: TemaYoneticisi.vurguRengi,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: TemaYoneticisi.hataRengi,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: TemaYoneticisi.anaGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ayarlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // İçerik
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child:
                      _yukleniyor
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Tema Ayarları
                              _buildSectionTitle('Görünüm'),
                              _buildTemaCard(),
                              const SizedBox(height: 16),

                              // Yedekleme Ayarları
                              _buildSectionTitle('Yedekleme'),
                              _buildYedeklemeCard(),
                              const SizedBox(height: 16),

                              // Yedek Dosyaları
                              if (_yedekDosyalari.isNotEmpty) ...[
                                _buildSectionTitle('Yedek Dosyaları'),
                                _buildYedekDosyalariCard(),
                                const SizedBox(height: 16),
                              ],

                              // Senkronizasyon Ayarları
                              _buildSectionTitle('Senkronizasyon'),
                              _buildSenkronizasyonCard(),
                              const SizedBox(height: 16),

                              // Bildirim Ayarları
                              _buildSectionTitle('Bildirimler'),
                              _buildBildirimCard(),
                              const SizedBox(height: 16),

                              // Uygulama Bilgileri
                              _buildSectionTitle('Uygulama'),
                              _buildUygulamaBilgileriCard(),
                              const SizedBox(height: 16),

                              // Ayarları Sıfırla
                              _buildSifirlaButonu(),
                              const SizedBox(height: 32),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTemaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tema Seçimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ...TemaSecenek.values.map((tema) {
              String baslik;
              IconData icon;

              switch (tema) {
                case TemaSecenek.sistem:
                  baslik = 'Sistem Ayarı';
                  icon = Icons.settings;
                  break;
                case TemaSecenek.acik:
                  baslik = 'Açık Tema';
                  icon = Icons.light_mode;
                  break;
                case TemaSecenek.koyu:
                  baslik = 'Koyu Tema';
                  icon = Icons.dark_mode;
                  break;
              }

              return RadioListTile<TemaSecenek>(
                title: Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(baslik),
                  ],
                ),
                value: tema,
                groupValue: _secilenTema,
                onChanged: (value) {
                  if (value != null) {
                    _temaDegisTir(value);
                  }
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDilCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dil Seçimi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildYedeklemeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veritabanı Yedekleme',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Manuel yedekleme butonları
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _veritabaniYedekle,
                    icon: const Icon(Icons.backup),
                    label: const Text('Yedekle'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _veritabaniGeriYukle,
                    icon: const Icon(Icons.restore),
                    label: const Text('Geri Yükle'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Otomatik yedekleme ayarları
            SwitchListTile(
              title: Text(
                'Otomatik Yedekleme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                'Belirli aralıklarla otomatik yedek al',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _otomatikYedekleme,
              onChanged: (value) async {
                await _ayarlarServisi.setOtomatikYedekleme(value);
                setState(() => _otomatikYedekleme = value);
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_otomatikYedekleme) ...[
              const SizedBox(height: 8),
              Text(
                'Yedekleme Aralığı: $_yedeklemeAraligi gün',
                style: const TextStyle(fontSize: 14),
              ),
              Slider(
                value: _yedeklemeAraligi.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$_yedeklemeAraligi gün',
                onChanged: (value) {
                  setState(() => _yedeklemeAraligi = value.round());
                },
                onChangeEnd: (value) async {
                  await _ayarlarServisi.setYedeklemeAraligi(value.round());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYedekDosyalariCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yedek Dosyaları (${_yedekDosyalari.length} adet)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ..._yedekDosyalari.take(5).map((dosyaYolu) {
              final dosyaAdi = _dosyaAdiniBul(dosyaYolu);
              final tarih = _tarihFormatla(dosyaAdi);

              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(
                  tarih,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  dosyaAdi,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _yedekDosyasiniSil(dosyaYolu),
                ),
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),

            if (_yedekDosyalari.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... ve ${_yedekDosyalari.length - 5} dosya daha',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenkronizasyonCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'USB Senkronizasyon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Cihazlar arası belge senkronizasyonu',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UsbSenkronEkrani(),
                    ),
                  );
                },
                icon: const Icon(Icons.sync),
                label: const Text('Senkronizasyon Ekranı'),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wi-Fi ağında bulunan diğer Arşivim cihazları ile belgelerinizi senkronize edin.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBildirimCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SwitchListTile(
          title: Text(
            'Bildirimlere İzin Ver',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            'Uygulama bildirimleri göster',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _bildirimlereIzin,
          onChanged: (value) async {
            await _ayarlarServisi.setBildirimlereIzin(value);
            setState(() => _bildirimlereIzin = value);
          },
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildUygulamaBilgileriCard() {
    final bilgiler = _ayarlarServisi.getUygulamaBilgileri();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulama Bilgileri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(
                'Versiyon',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                bilgiler['versiyon'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Yapım Tarihi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                bilgiler['yapim_tarihi'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: Text(
                'Geliştirici',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                bilgiler['gelistirici'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSifirlaButonu() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _ayarlariSifirla,
        icon: const Icon(Icons.restore, color: Colors.red),
        label: const Text(
          'Ayarları Sıfırla',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
