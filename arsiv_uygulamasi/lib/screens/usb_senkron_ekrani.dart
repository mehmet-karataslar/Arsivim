import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../services/usb_senkron_servisi.dart';
import '../services/http_sunucu_servisi.dart';
import '../services/tema_yoneticisi.dart';
import '../services/senkron_manager.dart';
import '../models/senkron_cihazi.dart' as models;
import '../widgets/qr_scanner_widget.dart';
import '../widgets/senkron_dialogs.dart';
import '../widgets/senkron_cards.dart';

class UsbSenkronEkrani extends StatefulWidget {
  const UsbSenkronEkrani({Key? key}) : super(key: key);

  @override
  State<UsbSenkronEkrani> createState() => _UsbSenkronEkraniState();
}

class _UsbSenkronEkraniState extends State<UsbSenkronEkrani>
    with TickerProviderStateMixin {
  final UsbSenkronServisi _senkronServisi = UsbSenkronServisi.instance;
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final SenkronManager _senkronManager = SenkronManager.instance;
  final TextEditingController _ipController = TextEditingController();
  final NetworkInfo _networkInfo = NetworkInfo();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<StreamSubscription> _subscriptions = [];
  List<String> _logMesajlari = [];
  String? _localIP;
  bool _sunucuCalisiyorMu = false;
  bool _baglantiDeneniyor = false;
  models.SenkronCihazi? _bagliBulunanCihaz;

  // Progress tracking için ValueNotifier'lar
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _currentOperationNotifier = ValueNotifier<String>(
    '',
  );

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStreams();
    _getLocalIP();
    _checkServerStatus();
    _setupDeviceConnectionCallback();
    _setupSenkronManagerCallbacks();
  }

  void _setupDeviceConnectionCallback() {
    print('🔧 USB Senkron Ekranı: Callback kuruluyor...');
    // HTTP sunucusuna cihaz bağlantı callback'i ekle
    _httpSunucu.setOnDeviceConnected((deviceInfo) {
      print('🎉 USB SENKRON CALLBACK ÇALIŞTI!');
      _addLog('🎉 YENİ CİHAZ BAĞLANDI!');
      _addLog('📱 Cihaz: ${deviceInfo['clientName']}');
      _addLog('🌐 IP: ${deviceInfo['ip']}');
      _addLog(
        '⏰ Bağlantı Zamanı: ${DateTime.now().toString().substring(11, 19)}',
      );

      // Bağlı cihaz bilgisini güncelle
      setState(() {
        _bagliBulunanCihaz = models.SenkronCihazi(
          id: deviceInfo['clientId'],
          ad: deviceInfo['clientName'],
          ip: deviceInfo['ip'],
          mac: 'unknown',
          platform: 'Mobil',
          sonGorulen: DateTime.now(),
          aktif: true,
          belgeSayisi: deviceInfo['belgeSayisi'] ?? 0,
          toplamBoyut: deviceInfo['toplamBoyut'] ?? 0,
        );
      });

      // PC için sistem bildirimi ve ses ile uyarı
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        SystemSound.play(SystemSoundType.alert);
        SenkronDialogs.showPCConnectionDialog(
          context,
          deviceInfo,
          _performRealSynchronization,
        );
      } else {
        SenkronDialogs.showSuccessDialog(
          context,
          _bagliBulunanCihaz,
          _startSynchronization,
        );
      }

      // Enhanced Snackbar
      _showConnectionSnackbar(deviceInfo);
    });
  }

  void _setupSenkronManagerCallbacks() {
    _senkronManager.setCallbacks(
      onProgress: (progress) {
        _progressNotifier.value = progress;
      },
      onOperation: (operation) {
        _currentOperationNotifier.value = operation;
      },
      onLog: (message) {
        _addLog(message);
      },
    );
  }

  void _showConnectionSnackbar(Map<String, dynamic> deviceInfo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.devices_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📱 ${deviceInfo['clientName']} bağlandı!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'IP: ${deviceInfo['ip']} • Belgeler: ${deviceInfo['belgeSayisi'] ?? 0}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.white, size: 28),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initStreams() {
    _subscriptions.addAll([
      _senkronServisi.logStream.listen((mesaj) {
        setState(() {
          _logMesajlari.insert(0, mesaj);
          if (_logMesajlari.length > 20) {
            _logMesajlari.removeLast();
          }
        });
      }),
    ]);
  }

  Future<void> _getLocalIP() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      setState(() {
        _localIP = ip;
      });
    } catch (e) {
      print('IP alınamadı: $e');
    }
  }

  void _checkServerStatus() {
    setState(() {
      _sunucuCalisiyorMu = _httpSunucu.calisiyorMu;
    });
  }

  Future<void> _startServer() async {
    try {
      if (!_httpSunucu.calisiyorMu) {
        await _httpSunucu.sunucuyuBaslat();
      }
      setState(() {
        _sunucuCalisiyorMu = true;
      });
      _addLog('✅ HTTP sunucusu başlatıldı');
      _addLog('🌐 Sunucu dinleniyor: $_localIP:8080');
      _showServerStartedSnackbar();
    } catch (e) {
      _addLog('❌ Sunucu başlatma hatası: $e');
      _showServerErrorSnackbar(e.toString());
    }
  }

  void _showServerStartedSnackbar() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🌐 Sunucu Başlatıldı!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Adres: $_localIP:8080 • Mobil cihazlar bağlanabilir',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.white, size: 28),
            ],
          ),
          backgroundColor: Colors.blue[600],
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showServerErrorSnackbar(String error) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sunucu başlatılamadı: $error',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _connectToDevice() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen IP adresi girin')));
      return;
    }

    setState(() {
      _baglantiDeneniyor = true;
    });
    _pulseController.repeat(reverse: true);

    try {
      _addLog('🔍 Bağlantı deneniyor: $ip');

      // Manuel bağlantı test et
      final success = await _senkronServisi.manuelBaglantiDene(ip);

      if (success) {
        _addLog('🎉 BAĞLANTI BAŞARILI!');

        // Başarı bildirimi göster
        SenkronDialogs.showSuccessDialog(
          context,
          _bagliBulunanCihaz,
          _startSynchronization,
        );

        // Bağlı cihaz bilgisini güncelle
        final usbCihaz = _senkronServisi.bagliBulunanCihaz;
        if (usbCihaz != null) {
          setState(() {
            _bagliBulunanCihaz = models.SenkronCihazi(
              id: usbCihaz.id,
              ad: usbCihaz.ad,
              ip: usbCihaz.ip,
              mac: usbCihaz.mac,
              platform: usbCihaz.platform,
              sonGorulen: usbCihaz.sonGorulen,
              aktif: usbCihaz.aktif,
              belgeSayisi: usbCihaz.belgeSayisi,
              toplamBoyut: usbCihaz.toplamBoyut,
            );
          });
        }
      } else {
        _addLog('❌ Bağlantı başarısız');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cihaza bağlanılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _addLog('❌ Bağlantı hatası: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() {
        _baglantiDeneniyor = false;
      });
      _pulseController.stop();
    }
  }

  void _addLog(String mesaj) {
    final timestamp = DateTime.now();
    final formattedTime =
        '[${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}]';
    setState(() {
      _logMesajlari.insert(0, '$formattedTime $mesaj');
      if (_logMesajlari.length > 20) {
        _logMesajlari.removeLast();
      }
    });
  }

  // Senkronizasyon başlatma
  void _startSynchronization() {
    if (_bagliBulunanCihaz == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce bir cihaza bağlanın')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Senkronizasyon'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  '${_bagliBulunanCihaz!.ad} ile senkronizasyon başlatılıyor...',
                ),
              ],
            ),
          ),
    );

    // Gerçek senkronizasyon başlat
    _performRealSynchronization();
  }

  // Gerçek senkronizasyon işlemi
  Future<void> _performRealSynchronization() async {
    try {
      // Progress dialog'u göster
      _progressNotifier.value = 0.0;
      _currentOperationNotifier.value = 'Senkronizasyon başlatılıyor...';
      SenkronDialogs.showProgressDialog(
        context,
        _progressNotifier,
        _currentOperationNotifier,
      );

      // Senkronizasyon manager ile işlemi başlat
      final results = await _senkronManager.performSynchronization(
        _bagliBulunanCihaz!,
      );

      Navigator.pop(context); // Progress dialog'u kapat

      // Sonuçları göster
      _showSyncResultsSnackbar(results);
    } catch (e) {
      Navigator.pop(context); // Progress dialog'u kapat
      _addLog('❌ Senkronizasyon hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Senkronizasyon hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSyncResultsSnackbar(Map<String, int> results) {
    final yeni = results['yeni'] ?? 0;
    final guncellenen = results['guncellenen'] ?? 0;
    final gonderilen = results['gonderilen'] ?? 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Senkronizasyon tamamlandı!\n'
          'Belgeler: Yeni $yeni, Güncellenen $guncellenen, '
          'Gönderilen $gonderilen\n'
          'Kategoriler ve kişiler de senkronize edildi',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // Cihaz bağlantısını kesme
  void _disconnectDevice() {
    SenkronDialogs.showDisconnectDialog(context, _bagliBulunanCihaz, () {
      setState(() {
        _bagliBulunanCihaz = null;
      });
      _addLog('🔌 Cihaz bağlantısı kesildi');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı kesildi'),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    });
  }

  // Dosya boyutu formatlama
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // QR kod tarama başlatma
  void _startQRScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              onQRScanned: (String qrData) {
                Navigator.pop(context);
                _handleQRData(qrData);
              },
            ),
      ),
    );
  }

  // QR kod verisi işleme
  void _handleQRData(String qrData) {
    try {
      final data = json.decode(qrData);

      if (data['type'] == 'arsivim_connection') {
        final ip = data['ip'];
        final port = data['port'] ?? 8080;
        final deviceName = data['deviceName'] ?? 'PC';

        _addLog('📱 QR kod tarandı!');
        _addLog('🖥️ PC: $deviceName');
        _addLog('🌐 IP: $ip:$port');

        // Onay dialogu göster ve gerçek bağlantı yap
        _showQRConnectionDialog(data);
      } else {
        throw Exception('Geçersiz QR kod formatı');
      }
    } catch (e) {
      _addLog('❌ QR kod hatası: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geçersiz QR kod')));
    }
  }

  // QR kod bağlantı onay dialogu
  void _showQRConnectionDialog(Map<String, dynamic> data) {
    final deviceName = data['deviceName'] ?? 'Bilinmeyen PC';
    final ip = data['ip'];
    final port = data['port'] ?? 8080;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text('QR Kod Tarandı'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$deviceName cihazına bağlanmak istiyor musunuz?'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IP: $ip:$port',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _connectToQRDevice(data);
                },
                icon: const Icon(Icons.link),
                label: const Text('Bağlan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  // QR kod ile gerçek bağlantı
  Future<void> _connectToQRDevice(Map<String, dynamic> data) async {
    setState(() {
      _baglantiDeneniyor = true;
    });
    _pulseController.repeat();

    try {
      final ip = data['ip'];
      final port = data['port'] ?? 8080;
      final deviceName = data['deviceName'] ?? 'PC';

      _addLog('🔗 $deviceName cihazına bağlanılıyor...');

      // Önce ping test et
      final pingResponse = await http
          .get(Uri.parse('http://$ip:$port/ping'))
          .timeout(const Duration(seconds: 10));

      if (pingResponse.statusCode != 200) {
        throw Exception('Ping başarısız');
      }

      _addLog('✅ Ping başarılı, gerçek bağlantı kuruluyor...');

      // Şimdi gerçek connect endpoint'ine POST isteği at
      final connectData = {
        'clientId': 'mobile-${DateTime.now().millisecondsSinceEpoch}',
        'clientName': 'Arşivim Mobil',
        'platform': Platform.operatingSystem,
        'belgeSayisi': 0,
        'toplamBoyut': 0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final connectResponse = await http
          .post(
            Uri.parse('http://$ip:$port/connect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(connectData),
          )
          .timeout(const Duration(seconds: 15));

      if (connectResponse.statusCode == 200) {
        final responseData = json.decode(connectResponse.body);

        if (responseData['success'] == true) {
          _addLog('🎉 GERÇEK BAĞLANTI BAŞARILI!');
          _addLog('🔗 PC\'ye connect edildi, callback çalıştı!');

          // Bağlı cihaz bilgisini oluştur
          setState(() {
            _bagliBulunanCihaz = models.SenkronCihazi(
              id: data['deviceId'] ?? 'unknown',
              ad: deviceName,
              ip: ip,
              mac: 'unknown',
              platform: data['platform'] ?? 'PC',
              sonGorulen: DateTime.now(),
              aktif: true,
              belgeSayisi: data['belgeSayisi'] ?? 0,
              toplamBoyut: data['toplamBoyut'] ?? 0,
            );
          });

          // 🎉 BAĞLANTI BAŞARILI BİLDİRİMİ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.devices_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎉 $deviceName\'a bağlandı!\nSenkronizasyon başlatılıyor...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 3),
            ),
          );

          // Senkronizasyonu başlat
          await Future.delayed(const Duration(seconds: 1));
          _performRealSynchronization();
        } else {
          throw Exception('Bağlantı yanıtı başarısız');
        }
      } else {
        throw Exception('HTTP ${connectResponse.statusCode}');
      }
    } catch (e) {
      _addLog('❌ QR bağlantı hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _baglantiDeneniyor = false;
      });
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ipController.dispose();
    _progressNotifier.dispose();
    _currentOperationNotifier.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
        automaticallyImplyLeading: false,
      ),
      extendBodyBehindAppBar: true,
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
          // Geri gelme butonu (PC için)
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false),
                tooltip: 'Ana Sayfaya Dön',
              ),
            ),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cihaz Senkronizasyonu',
              style: TextStyle(
                color: Colors.white,
                fontSize:
                    Platform.isWindows || Platform.isLinux || Platform.isMacOS
                        ? 22
                        : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildStatusIcon(),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    if (_baglantiDeneniyor) {
      icon = Icons.sync;
      color = Colors.yellow;
    } else if (_bagliBulunanCihaz != null) {
      icon = Icons.devices;
      color = Colors.green;
    } else if (_sunucuCalisiyorMu) {
      icon = Icons.wifi;
      color = Colors.blue;
    } else {
      icon = Icons.wifi_off;
      color = Colors.white54;
    }

    Widget iconWidget = Icon(icon, color: color, size: 28);

    if (_baglantiDeneniyor) {
      iconWidget = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: iconWidget,
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
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            _buildServerCard(),
            const SizedBox(height: 16),
          ],
          _buildConnectionCard(),
          const SizedBox(height: 16),
          if (Platform.isAndroid || Platform.isIOS) ...[
            _buildQRScanCard(),
            const SizedBox(height: 16),
          ],
          if (_bagliBulunanCihaz != null) ...[
            _buildConnectedDeviceCard(),
            const SizedBox(height: 16),
          ],
          SenkronCards.buildLogCard(
            logMesajlari: _logMesajlari,
            onClearLog: () {
              setState(() {
                _logMesajlari.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  // Sunucu kartı (PC için)
  Widget _buildServerCard() {
    return SenkronCards.buildServerCard(
      sunucuCalisiyorMu: _sunucuCalisiyorMu,
      localIP: _localIP,
      onStartServer: _startServer,
      onShowQRCode: _showQRCode,
    );
  }

  // Bağlantı kartı
  Widget _buildConnectionCard() {
    return SenkronCards.buildConnectionCard(
      ipController: _ipController,
      baglantiDeneniyor: _baglantiDeneniyor,
      onConnect: _connectToDevice,
    );
  }

  // QR kod tarama kartı (mobil için)
  Widget _buildQRScanCard() {
    return SenkronCards.buildQRScanCard(onStartQRScan: _startQRScan);
  }

  // Bağlı cihaz kartı
  Widget _buildConnectedDeviceCard() {
    return SenkronCards.buildConnectedDeviceCard(
      bagliBulunanCihaz: _bagliBulunanCihaz!,
      onSync: _startSynchronization,
      onDisconnect: _disconnectDevice,
      formatFileSize: _formatFileSize,
    );
  }

  void _showQRCode() {
    if (_localIP != null && _sunucuCalisiyorMu) {
      SenkronDialogs.showQRCode(context, _localIP!);
    }
  }

  void _showServerSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '🌐 Sunucu başlatıldı: $_localIP:8080',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
