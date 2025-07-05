import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../services/senkronizasyon_yonetici_servisi.dart';
import '../widgets/senkronizasyon_kartlari.dart';
import '../widgets/cihaz_baglanti_paneli.dart';

import '../widgets/qr_generator_widget.dart';
import '../widgets/qr_scanner_widget.dart';
import '../models/belge_modeli.dart';
import '../screens/senkron_belgeler_ekrani.dart';
import '../utils/screen_utils.dart';

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
    await _yonetici.verileriYukle();
    if (!mounted) return;
    setState(() => _yukleniyor = false);
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
                      const SizedBox(height: 16),
                      SenkronizasyonKartlari.buildSenkronizasyonGecmisi(
                        context,
                        _yonetici,
                      ),
                      const SizedBox(height: 16),
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
            ),
            const SizedBox(height: 16),
            CihazBaglantiPaneli(
              yonetici: _yonetici,
              onQRKodGoster: _qrKodGoster,
              onQRKodTara: _qrKodTara,
              onTamEkranQR: _tamEkranQRGoster,
            ),
            const SizedBox(height: 16),
            SenkronizasyonKartlari.buildSenkronizasyonGecmisi(
              context,
              _yonetici,
            ),
            const SizedBox(height: 16),

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              onQRScanned: (qrData) {
                Navigator.of(context).pop(); // QR scanner'ı kapat
                _yonetici.qrKoduTarandi(qrData);

                // Başarılı bağlantı durumunda bildirim göster
                if (_yonetici.bagliCihazlar.isNotEmpty) {
                  _cihazBaglantiBasarili(_yonetici.bagliCihazlar.last['name']);
                }
              },
            ),
      ),
    );
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

  void _belgeleriCihazaGonder(List<BelgeModeli> belgeler) async {
    // Eğer bağlı cihaz varsa
    if (_yonetici.bagliCihazlar.isNotEmpty) {
      // İlk bağlı cihaza gönder (veya kullanıcı seçsin)
      final hedefCihaz = _yonetici.bagliCihazlar.first;
      final hedefIP = hedefCihaz['ip'] as String;

      if (hedefIP != 'incoming') {
        Navigator.pop(context); // Dialog'u kapat
        final basarili = await _yonetici.belgeleriSenkronEt(
          hedefIP,
          belgeler: belgeler,
        );

        if (basarili) {
          // Bekleyen belgeleri yeniden yükle
          _bekleyenBelgeleriGoster();
        }
      } else {
        _hataGoster('Gelen bağlantı cihazlarına dosya gönderilemez');
      }
    } else {
      _hataGoster('Önce bir cihaz bağlanmalı');
    }
  }

  // Mesaj gösterme fonksiyonları
  void _hataGoster(String mesaj) {
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
}
