import 'package:flutter/material.dart';
import 'dart:async';
import '../services/usb_senkron_servisi.dart';
import '../services/tema_yoneticisi.dart';

class UsbSenkronEkrani extends StatefulWidget {
  const UsbSenkronEkrani({Key? key}) : super(key: key);

  @override
  State<UsbSenkronEkrani> createState() => _UsbSenkronEkraniState();
}

class _UsbSenkronEkraniState extends State<UsbSenkronEkrani>
    with TickerProviderStateMixin {
  final UsbSenkronServisi _senkronServisi = UsbSenkronServisi.instance;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  List<StreamSubscription> _subscriptions = [];
  List<String> _logMesajlari = [];

  CihazDurumu _cihazDurumu = CihazDurumu.BAGLI_DEGIL;
  UsbSenkronDurumu _senkronDurumu = UsbSenkronDurumu.BEKLEMEDE;
  List<SenkronCihazi> _bulunanCihazlar = [];
  SenkronCihazi? _bagliBulunanCihaz;
  SenkronIstatistik? _senkronIstatistik;
  double _discoveryProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStreams();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _initStreams() {
    _subscriptions.addAll([
      _senkronServisi.cihazDurumuStream.listen((durum) {
        setState(() {
          _cihazDurumu = durum;
        });
        if (durum == CihazDurumu.ARANYOR) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }),

      _senkronServisi.senkronDurumuStream.listen((durum) {
        setState(() {
          _senkronDurumu = durum;
        });
      }),

      _senkronServisi.cihazlarStream.listen((cihazlar) {
        setState(() {
          _bulunanCihazlar = cihazlar;
        });
      }),

      _senkronServisi.istatistikStream.listen((istatistik) {
        setState(() {
          _senkronIstatistik = istatistik;
        });
        if (istatistik != null) {
          _progressController.animateTo(istatistik.ilerlemeYuzdesi / 100);
        }
      }),

      _senkronServisi.logStream.listen((mesaj) {
        setState(() {
          _logMesajlari.insert(0, mesaj);
          if (_logMesajlari.length > 50) {
            _logMesajlari.removeLast();
          }
        });
      }),

      _senkronServisi.discoveryProgressStream.listen((progress) {
        setState(() {
          _discoveryProgress = progress;
        });
      }),
    ]);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: TemaYoneticisi.anaGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'USB Senkronizasyon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Arama durumunda iptal butonu göster
          if (_cihazDurumu == CihazDurumu.ARANYOR)
            IconButton(
              onPressed: () {
                _senkronServisi.cihazAramayiDurdur();
              },
              icon: const Icon(Icons.stop, color: Colors.red),
              tooltip: 'Aramayı Durdur',
            ),
          const SizedBox(width: 8),
          _buildStatusIcon(),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (_cihazDurumu) {
      case CihazDurumu.BAGLI_DEGIL:
        icon = Icons.usb_off;
        color = Colors.white54;
        break;
      case CihazDurumu.ARANYOR:
        icon = Icons.search;
        color = Colors.yellow;
        break;
      case CihazDurumu.BULUNDU:
        icon = Icons.devices;
        color = Colors.orange;
        break;
      case CihazDurumu.BAGLANIYOR:
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case CihazDurumu.BAGLI:
        icon = Icons.usb;
        color = Colors.green;
        break;
      case CihazDurumu.SENKRON_EDILIYOR:
        icon = Icons.sync;
        color = Colors.purple;
        break;
    }

    Widget iconWidget = Icon(icon, color: color, size: 28);

    if (_cihazDurumu == CihazDurumu.ARANYOR ||
        _cihazDurumu == CihazDurumu.SENKRON_EDILIYOR) {
      iconWidget = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: iconWidget,
          );
        },
      );
    }

    return iconWidget;
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildControlButtons(),
          const SizedBox(height: 16),
          if (_bulunanCihazlar.isNotEmpty) ...[
            _buildDevicesList(),
            const SizedBox(height: 16),
          ],
          if (_senkronIstatistik != null) ...[
            _buildSyncProgress(),
            const SizedBox(height: 16),
          ],
          _buildLogCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    String durum;
    String aciklama;
    Color renk;

    switch (_cihazDurumu) {
      case CihazDurumu.BAGLI_DEGIL:
        durum = 'Bağlı Değil';
        aciklama = 'USB cihazı bulunamadı. Cihaz aramaya başlayın.';
        renk = Colors.grey;
        break;
      case CihazDurumu.ARANYOR:
        durum = 'Aranıyor';
        aciklama = 'Ağdaki Arşivim cihazları taranıyor...';
        renk = Colors.orange;
        break;
      case CihazDurumu.BULUNDU:
        durum = 'Cihaz Bulundu';
        aciklama =
            '${_bulunanCihazlar.length} cihaz bulundu. Bağlanmak için seçin.';
        renk = Colors.blue;
        break;
      case CihazDurumu.BAGLANIYOR:
        durum = 'Bağlanıyor';
        aciklama = 'Seçilen cihaza bağlanılıyor...';
        renk = Colors.blue;
        break;
      case CihazDurumu.BAGLI:
        durum = 'Bağlı';
        aciklama = '${_bagliBulunanCihaz?.ad ?? "Cihaz"} ile bağlantı kuruldu.';
        renk = Colors.green;
        break;
      case CihazDurumu.SENKRON_EDILIYOR:
        durum = 'Senkronize Ediliyor';
        aciklama = 'Dosyalar senkronize ediliyor...';
        renk = Colors.purple;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: renk,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  durum,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              aciklama,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            // Discovery progress bar
            if (_cihazDurumu == CihazDurumu.ARANYOR) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _discoveryProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(renk),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_discoveryProgress * 100).toStringAsFixed(0)}% tamamlandı',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_bagliBulunanCihaz != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildDeviceInfo(_bagliBulunanCihaz!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfo(SenkronCihazi cihaz) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.devices, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cihaz.ad,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.computer, size: 16),
            const SizedBox(width: 8),
            Text(
              '${cihaz.platform} • ${cihaz.ip}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.folder, size: 16),
            const SizedBox(width: 8),
            Text(
              '${cihaz.belgeSayisi} belge • ${_formatFileSize(cihaz.toplamBoyut)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _cihazDurumu == CihazDurumu.ARANYOR
                    ? null
                    : () {
                      _senkronServisi.cihazAramayaBasla();
                    },
            icon: Icon(
              _cihazDurumu == CihazDurumu.ARANYOR ? Icons.stop : Icons.search,
            ),
            label: Text(
              _cihazDurumu == CihazDurumu.ARANYOR
                  ? 'Aramayı Durdur'
                  : 'Cihaz Ara',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _cihazDurumu == CihazDurumu.BAGLI &&
                        _senkronDurumu != UsbSenkronDurumu.DEVAM_EDIYOR
                    ? () {
                      _senkronServisi.senkronizasyonBaslat();
                    }
                    : null,
            icon: const Icon(Icons.sync),
            label: const Text('Senkronize Et'),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulunan Cihazlar (${_bulunanCihazlar.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._bulunanCihazlar
                .map((cihaz) => _buildDeviceItem(cihaz))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(SenkronCihazi cihaz) {
    final isConnected = _bagliBulunanCihaz?.id == cihaz.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isConnected ? TemaYoneticisi.anaRenk : Colors.grey[300]!,
          width: isConnected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          Icons.devices,
          color: isConnected ? TemaYoneticisi.anaRenk : Colors.grey[600],
        ),
        title: Text(cihaz.ad),
        subtitle: Text('${cihaz.platform} • ${cihaz.ip}'),
        trailing:
            isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () {
                    _senkronServisi.cihazaBaglan(cihaz);
                  },
                ),
        onTap:
            isConnected
                ? null
                : () {
                  _senkronServisi.cihazaBaglan(cihaz);
                },
      ),
    );
  }

  Widget _buildSyncProgress() {
    final istatistik = _senkronIstatistik!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Senkronizasyon İlerlemesi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: istatistik.ilerlemeYuzdesi / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  TemaYoneticisi.anaRenk,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${istatistik.ilerlemeYuzdesi.toStringAsFixed(1)}% tamamlandı',
              style: const TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 16),

            // İstatistikler
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Toplam',
                    '${istatistik.toplamDosya}',
                    Icons.folder,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Aktarılan',
                    '${istatistik.aktarilanDosya}',
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Hatalı',
                    '${istatistik.hataliDosya}',
                    Icons.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.timer, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Geçen süre: ${_formatDuration(istatistik.gecenSure)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),

            if (_senkronDurumu == UsbSenkronDurumu.DEVAM_EDIYOR) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _senkronServisi.senkronizasyonuIptalEt();
                  },
                  child: const Text('İptal Et'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: TemaYoneticisi.anaRenk),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sistem Logları',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child:
                  _logMesajlari.isEmpty
                      ? const Center(
                        child: Text(
                          'Henüz log mesajı yok',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _logMesajlari.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              _logMesajlari[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
