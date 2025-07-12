import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../services/senkronizasyon_yonetici_servisi.dart';
import '../widgets/senkronizasyon_kartlari.dart';
import '../widgets/cihaz_baglanti_paneli.dart';
import '../widgets/senkronizasyon_kontrolleri.dart';
import '../widgets/qr_generator_widget.dart';
import '../widgets/qr_scanner_widget.dart';
import '../models/belge_modeli.dart';
import '../screens/senkron_belgeler_ekrani.dart';
import '../utils/screen_utils.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';

class SenkronizasyonEkrani extends StatefulWidget {
  const SenkronizasyonEkrani({Key? key}) : super(key: key);

  @override
  State<SenkronizasyonEkrani> createState() => _SenkronizasyonEkraniState();
}

class _SenkronizasyonEkraniState extends State<SenkronizasyonEkrani>
    with TickerProviderStateMixin {
  late final SenkronizasyonYoneticiServisi _yonetici;

  // Animasyon controller'ları
  late AnimationController _fadeAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _yukleniyor = false;
  List<BelgeModeli> _bekleyenBelgeler = [];
  List<KisiModeli> _bekleyenKisiler = [];
  List<KategoriModeli> _bekleyenKategoriler = [];

  // Anlık güncelleme için Timer
  Timer? _refreshTimer;

  // Platform kontrolü
  bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _yonetici = SenkronizasyonYoneticiServisi.instance;
    _initAnimations();
    _initServiceCallbacks();
    _verileriYukle();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _pulseAnimationController.dispose();
    _refreshTimer?.cancel();
    _yonetici.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimationController.forward();
    _pulseAnimationController.repeat(reverse: true);
  }

  void _initServiceCallbacks() {
    _yonetici.onStatusChanged = (status) {
      if (mounted) setState(() {});
    };

    _yonetici.onDeviceListChanged = () {
      if (mounted) setState(() {});
    };

    _yonetici.onSuccess = (message) {
      if (mounted) _basariMesaji(message);
    };

    _yonetici.onError = (error) {
      if (mounted) _hataGoster(error);
    };
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;
    setState(() => _yukleniyor = true);

    try {
      await _yonetici.verileriYukle();

      // Bekleyen senkronizasyonları yükle
      final bekleyenler = await _yonetici.bekleyenSenkronlariGetir();

      if (mounted) {
        setState(() {
          _bekleyenBelgeler =
              (bekleyenler['bekleyen_belgeler'] as List<dynamic>?)
                  ?.cast<BelgeModeli>() ??
              [];
          _bekleyenKisiler =
              (bekleyenler['bekleyen_kisiler'] as List<dynamic>?)
                  ?.cast<KisiModeli>() ??
              [];
          _bekleyenKategoriler =
              (bekleyenler['bekleyen_kategoriler'] as List<dynamic>?)
                  ?.cast<KategoriModeli>() ??
              [];
        });
      }
    } catch (e) {
      print('❌ Veriler yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  /// Anlık güncelleme timer'ını başlat
  void _startRefreshTimer() {
    // Mobilde daha az sıklıkla yenile (performans için)
    final refreshInterval =
        Platform.isAndroid || Platform.isIOS
            ? const Duration(seconds: 15)
            : const Duration(seconds: 10);

    _refreshTimer = Timer.periodic(refreshInterval, (timer) {
      if (mounted) {
        _verileriYukle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _verileriYukle,
            child:
                _yukleniyor
                    ? const Center(child: CircularProgressIndicator())
                    : (_pcPlatform ? _buildPCLayout() : _buildMobileLayout()),
          ),
        ),
      ),
    );
  }

  // PC Layout - Geniş ekran için optimize edilmiş
  Widget _buildPCLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol panel - Durum ve kontroller
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      SenkronizasyonKartlari.buildSunucuDurumKarti(
                        context,
                        _yonetici,
                        _pulseAnimation,
                      ),
                      const SizedBox(height: 16),

                      SenkronizasyonKartlari.buildHizliIstatistikler(
                        context,
                        _yonetici,
                        _bekleyenBelgeleriGoster,
                        bekleyenBelgeler: _bekleyenBelgeler,
                        bekleyenKisiler: _bekleyenKisiler,
                        bekleyenKategoriler: _bekleyenKategoriler,
                        bekleyenKisileriGoster: _bekleyenKisileriGoster,
                        bekleyenKategorileriGoster: _bekleyenKategorileriGoster,
                      ),
                      const SizedBox(height: 16),
                      // PC için senkronizasyon kontrolleri
                      SenkronizasyonKontrolleri(
                        yonetici: _yonetici,
                        onTumSistemSenkron: _tumSistemSenkronEt,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Sağ panel - Bağlı cihazlar ve detaylar
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      CihazBaglantiPaneli(
                        yonetici: _yonetici,
                        onQRKodGoster: _qrKodGoster,
                        onQRKodTara: _qrKodTara,
                        onTamEkranQR: _tamEkranQRGoster,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Mobile Layout - Mobil cihazlar için optimize edilmiş
  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            SenkronizasyonKartlari.buildSunucuDurumKarti(
              context,
              _yonetici,
              _pulseAnimation,
            ),
            const SizedBox(height: 16),

            SenkronizasyonKartlari.buildHizliIstatistikler(
              context,
              _yonetici,
              _bekleyenBelgeleriGoster,
              bekleyenBelgeler: _bekleyenBelgeler,
              bekleyenKisiler: _bekleyenKisiler,
              bekleyenKategoriler: _bekleyenKategoriler,
              bekleyenKisileriGoster: _bekleyenKisileriGoster,
              bekleyenKategorileriGoster: _bekleyenKategorileriGoster,
            ),
            const SizedBox(height: 16),
            CihazBaglantiPaneli(
              yonetici: _yonetici,
              onQRKodGoster: _qrKodGoster,
              onQRKodTara: _qrKodTara,
              onTamEkranQR: _tamEkranQRGoster,
            ),
            const SizedBox(height: 16),
            SenkronizasyonKontrolleri(
              yonetici: _yonetici,
              onTumSistemSenkron: _tumSistemSenkronEt,
            ),
            const SizedBox(height: 80), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync_rounded,
              size: _pcPlatform ? 32 : 28,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Senkronizasyon',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    _pcPlatform
                        ? 'Masaüstü Senkronizasyon Merkezi'
                        : 'Mobil Senkronizasyon',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // Durum indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _yonetici.sunucuCalisiyorMu ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _yonetici.durum,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Otomatik bağlantı kesme ayarı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_power_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Otomatik Bağlantı Kesme',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Senkronizasyon bitince bağlantı otomatik kesilsin',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _yonetici.otomatikBaglantiKes,
                onChanged: (value) {
                  setState(() {
                    _yonetici.otomatikBaglantiKes = value;
                  });
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // QR kod işlemleri
  void _qrKodGoster() async {
    final connectionData = await _yonetici.connectionDataOlustur();

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: _pcPlatform ? 450 : 350,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: QRGeneratorWidget(
                  connectionData: connectionData,
                  title: 'PC Bağlantı QR Kodu',
                  onRefresh: () {
                    Navigator.of(context).pop();
                    _qrKodGoster(); // Dialog'u yeniden aç
                  },
                ),
              ),
            ),
          ),
    );
  }

  void _qrKodTara() {
    print('📱 QR kod tarayıcısı açılıyor...');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              onQRScanned: (qrData) {
                print('📷 QR kod tarandı: $qrData');

                // QR kod tarandığında hemen kapansın
                Navigator.of(context).pop();
                print('🔄 QR scanner hemen kapatıldı');

                // Arka planda bağlantı işlemlerini yap
                _processQRCode(qrData);
              },
            ),
      ),
    );
  }

  void _processQRCode(String qrData) async {
    try {
      print('🔄 QR kod işleniyor: $qrData');

      // QR kod işlemini başlat
      final baglantiBasarili = await _yonetici.qrKoduTarandi(qrData);
      print('🔄 Bağlantı sonucu: $baglantiBasarili');

      // Başarılı bağlantı durumunda bildirim göster
      if (baglantiBasarili && _yonetici.bagliCihazlar.isNotEmpty) {
        final sonBagliCihaz = _yonetici.bagliCihazlar.last;
        print('🎉 Başarı dialogu gösteriliyor: ${sonBagliCihaz['name']}');
        _cihazBaglantiBasarili(sonBagliCihaz['name'] ?? 'Bilinmeyen Cihaz');
      }
    } catch (e) {
      print('❌ QR kod işleme hatası: $e');
      _hataGoster('QR kod işleme hatası: $e');
    }
  }

  void _tamEkranQRGoster() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const QRConnectionScreen()));
  }

  void _cihazBaglantiBasarili(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bağlantı Başarılı!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deviceName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pcPlatform
                        ? 'cihazı PC\'ye bağlandı'
                        : 'PC\'ye başarıyla bağlandı',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tamam'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Mobil cihaz bağlı cihazlar listesini göster
                            if (!_pcPlatform) {
                              // Mobil için bağlı cihazlar gösterme fonksiyonu çağrılacak
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cihazları Gör'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Navigasyon fonksiyonları
  void _bekleyenBelgeleriGoster() async {
    try {
      final bekleyenler = await _yonetici.bekleyenSenkronlariGetir();
      final bekleyenBelgeler =
          bekleyenler['bekleyen_belgeler'] as List<dynamic>?;

      if (bekleyenBelgeler != null) {
        setState(() {
          _bekleyenBelgeler = bekleyenBelgeler.cast<BelgeModeli>();
        });
      }

      _showBekleyenBelgelerDialog();
    } catch (e) {
      _hataGoster('Bekleyen belgeler yüklenemedi: $e');
    }
  }

  void _bekleyenKisileriGoster() async {
    try {
      final bekleyenler = await _yonetici.bekleyenSenkronlariGetir();
      final bekleyenKisiler = bekleyenler['bekleyen_kisiler'] as List<dynamic>?;

      if (bekleyenKisiler != null && mounted) {
        setState(() {
          _bekleyenKisiler = bekleyenKisiler.cast<KisiModeli>();
        });
      }

      if (mounted) {
        _showBekleyenKisilerDialog();
      }
    } catch (e) {
      if (mounted) {
        _hataGoster('Bekleyen kişiler yüklenemedi: $e');
      }
    }
  }

  void _bekleyenKategorileriGoster() async {
    try {
      final bekleyenler = await _yonetici.bekleyenSenkronlariGetir();
      final bekleyenKategoriler =
          bekleyenler['bekleyen_kategoriler'] as List<dynamic>?;

      if (bekleyenKategoriler != null && mounted) {
        setState(() {
          _bekleyenKategoriler = bekleyenKategoriler.cast<KategoriModeli>();
        });
      }

      if (mounted) {
        _showBekleyenKategorilerDialog();
      }
    } catch (e) {
      if (mounted) {
        _hataGoster('Bekleyen kategoriler yüklenemedi: $e');
      }
    }
  }

  void _showBekleyenBelgelerDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: _pcPlatform ? 600 : 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sync_problem, color: Colors.orange[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Senkronizasyon Bekleyen Belgeler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SenkronizasyonKartlari.buildBekleyenBelgeler(
                          context,
                          _bekleyenBelgeler,
                          _belgeleriCihazaGonder,
                          _yonetici,
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

  void _showBekleyenKisilerDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: _pcPlatform ? 600 : 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Senkronizasyon Bekleyen Kişiler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SenkronizasyonKartlari.buildBekleyenKisiler(
                          context,
                          _bekleyenKisiler,
                          _kisileriCihazaGonder,
                          _yonetici,
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

  void _showBekleyenKategorilerDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: _pcPlatform ? 600 : 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category, color: Colors.purple[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Senkronizasyon Bekleyen Kategoriler',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SenkronizasyonKartlari.buildBekleyenKategoriler(
                          context,
                          _bekleyenKategoriler,
                          _kategorileriCihazaGonder,
                          _yonetici,
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

  void _belgeleriCihazaGonder(List<BelgeModeli> belgeler) async {
    if (_yonetici.bagliCihazlar.isEmpty) {
      _hataGoster('Önce bir cihaz bağlanmalı');
      return;
    }

    final hedefCihaz = _yonetici.bagliCihazlar.first;
    final hedefIP = hedefCihaz['ip'] as String;

    if (hedefIP == 'incoming') {
      _hataGoster('Gelen bağlantı cihazlarına dosya gönderilemez');
      return;
    }

    // Dialog kapatma ve progress gösterme
    bool dialogAcik = false;

    try {
      // Ana dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Progress dialog göster
      if (mounted) {
        dialogAcik = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext dialogContext) => PopScope(
                canPop: false,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        '${belgeler.length} belge senkronize ediliyor...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belgeler tüm metadata ile transfer ediliyor...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }

      // Async olarak senkronize et
      final basarili = await _yonetici.belgeleriSenkronEt(
        hedefIP,
        belgeler: belgeler,
      );

      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogAcik = false;
      }

      if (basarili) {
        _basariMesaji('${belgeler.length} belge başarıyla senkronize edildi');
        // Verileri yenile
        await _verileriYukle();
      } else {
        _hataGoster('Belge senkronizasyonu başarısız oldu');
      }
    } catch (e) {
      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Navigation error: $navError');
        }
        dialogAcik = false;
      }
      _hataGoster('Belge senkronizasyon hatası: $e');
    } finally {
      // Son güvenlik kontrolü
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Final navigation error: $navError');
        }
      }

      // Loading durumunu kapat
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  void _kisileriCihazaGonder(List<KisiModeli> kisiler) async {
    if (_yonetici.bagliCihazlar.isEmpty) {
      _hataGoster('Önce bir cihaz bağlanmalı');
      return;
    }

    final hedefCihaz = _yonetici.bagliCihazlar.first;
    final hedefIP = hedefCihaz['ip'] as String;

    if (hedefIP == 'incoming') {
      _hataGoster('Gelen bağlantı cihazlarına dosya gönderilemez');
      return;
    }

    // Dialog kapatma ve progress gösterme
    bool dialogAcik = false;

    try {
      // Ana dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Progress dialog göster
      if (mounted) {
        dialogAcik = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext dialogContext) => PopScope(
                canPop: false,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        '${kisiler.length} kişi senkronize ediliyor...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Profil fotoğrafları ve tüm bilgiler dahil ediliyor...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }

      // Async olarak senkronize et
      final basarili = await _yonetici.kisileriSenkronEt(
        hedefIP,
        kisiler: kisiler,
      );

      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogAcik = false;
      }

      if (basarili) {
        _basariMesaji('${kisiler.length} kişi başarıyla senkronize edildi');
        // Verileri yenile
        await _verileriYukle();
      } else {
        _hataGoster('Kişi senkronizasyonu başarısız oldu');
      }
    } catch (e) {
      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Navigation error: $navError');
        }
        dialogAcik = false;
      }
      _hataGoster('Kişi senkronizasyon hatası: $e');
    } finally {
      // Son güvenlik kontrolü
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Final navigation error: $navError');
        }
      }

      // Loading durumunu kapat
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  void _kategorileriCihazaGonder(List<KategoriModeli> kategoriler) async {
    if (_yonetici.bagliCihazlar.isEmpty) {
      _hataGoster('Önce bir cihaz bağlanmalı');
      return;
    }

    final hedefCihaz = _yonetici.bagliCihazlar.first;
    final hedefIP = hedefCihaz['ip'] as String;

    if (hedefIP == 'incoming') {
      _hataGoster('Gelen bağlantı cihazlarına dosya gönderilemez');
      return;
    }

    // Dialog kapatma ve progress gösterme
    bool dialogAcik = false;

    try {
      // Ana dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Progress dialog göster
      if (mounted) {
        dialogAcik = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (BuildContext dialogContext) => PopScope(
                canPop: false,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        '${kategoriler.length} kategori senkronize ediliyor...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tüm kategori bilgileri dahil ediliyor...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }

      // Async olarak senkronize et
      final basarili = await _yonetici.kategorileriSenkronEt(
        hedefIP,
        kategoriler: kategoriler,
      );

      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogAcik = false;
      }

      if (basarili) {
        _basariMesaji(
          '${kategoriler.length} kategori başarıyla senkronize edildi',
        );
        // Verileri yenile
        await _verileriYukle();
      } else {
        _hataGoster('Kategori senkronizasyonu başarısız oldu');
      }
    } catch (e) {
      // Progress dialog'u güvenli şekilde kapat
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Navigation error: $navError');
        }
        dialogAcik = false;
      }
      _hataGoster('Kategori senkronizasyon hatası: $e');
    } finally {
      // Son güvenlik kontrolü
      if (mounted && dialogAcik) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          print('Final navigation error: $navError');
        }
      }

      // Loading durumunu kapat
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  // Mesaj gösterme fonksiyonları
  void _hataGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _basariMesaji(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Tüm sistemi senkronize et
  Future<void> _tumSistemSenkronEt() async {
    if (_yonetici.bagliCihazlar.isEmpty) {
      _hataGoster('Hiçbir cihaz bağlı değil! Önce bir cihaza bağlanın.');
      return;
    }

    try {
      // İlk bağlı cihazı al
      final hedefCihaz = _yonetici.bagliCihazlar.first;
      final hedefIP = hedefCihaz['ip'] as String;

      if (hedefIP == 'incoming') {
        _hataGoster('Gelen bağlantı cihazlarına dosya gönderilemez');
        return;
      }

      // Onay dialog'u göster
      final onay = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Tüm Sistem Senkronizasyonu'),
              content: Text(
                'Tüm belgeler, kişiler ve kategoriler "${hedefCihaz['device_name']}" cihazına gönderilecek.\n\n'
                'Bu işlem uzun sürebilir. Devam etmek istiyor musunuz?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Devam Et'),
                ),
              ],
            ),
      );

      if (onay == true) {
        setState(() => _yukleniyor = true);
        final sonuc = await _yonetici.tumSistemiSenkronEt(hedefIP);

        if (sonuc) {
          _basariMesaji('Tüm sistem başarıyla senkronize edildi!');
          _verileriYukle(); // Verileri yenile
        } else {
          _hataGoster('Tüm sistem senkronizasyonu başarısız oldu.');
        }
      }
    } catch (e) {
      _hataGoster('Tüm sistem senkronizasyon hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }
}
