import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../services/usb_senkron_servisi.dart';
import '../services/http_sunucu_servisi.dart';
import '../services/senkron_manager_coordinator.dart';
import '../models/senkron_cihazi.dart' as models;
import '../widgets/qr_scanner_widget.dart';
import '../widgets/senkron_dialogs.dart';

class UsbSenkronEkrani extends StatefulWidget {
  const UsbSenkronEkrani({Key? key}) : super(key: key);

  @override
  State<UsbSenkronEkrani> createState() => _UsbSenkronEkraniState();
}

class _UsbSenkronEkraniState extends State<UsbSenkronEkrani>
    with TickerProviderStateMixin {
  final UsbSenkronServisi _senkronServisi = UsbSenkronServisi.instance;
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final SenkronManagerCoordinator _senkronCoordinator =
      SenkronManagerCoordinator.instance;
  final TextEditingController _ipController = TextEditingController();
  final NetworkInfo _networkInfo = NetworkInfo();

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

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

  // YENİ: Sync Manager seçimi için
  SyncManagerType _selectedSyncManager = SyncManagerType.enhanced;
  bool _autoFallbackEnabled = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStreams();
    _getLocalIP();
    _checkServerStatus();
    _setupDeviceConnectionCallback();
    _setupSenkronCoordinatorCallbacks();
  }

  // YENİ: Coordinator callback'lerini ayarla
  void _setupSenkronCoordinatorCallbacks() {
    print('🔧 USB Senkron Ekranı: Coordinator callback kuruluyor...');

    _senkronCoordinator.onProgressUpdate = (progress) {
      _progressNotifier.value = progress;
    };

    _senkronCoordinator.onOperationUpdate = (operation) {
      _currentOperationNotifier.value = operation;
    };

    _senkronCoordinator.onLogMessage = (message) {
      _addLog(message);
    };

    // İlk ayarları yap
    _senkronCoordinator.setSyncManagerType(_selectedSyncManager);
    _senkronCoordinator.setAutoFallback(_autoFallbackEnabled);
  }

  void _setupDeviceConnectionCallback() {
    print('🔧 USB Senkron Ekranı: Callback kuruluyor...');
    _httpSunucu.setOnDeviceConnected((deviceInfo) {
      print('🎉 USB SENKRON CALLBACK ÇALIŞTI!');
      _addLog('🎉 YENİ CİHAZ BAĞLANDI!');
      _addLog('📱 Cihaz: ${deviceInfo['clientName']}');
      _addLog('🌐 IP: ${deviceInfo['ip']}');
      _addLog(
        '⏰ Bağlantı Zamanı: ${DateTime.now().toString().substring(11, 19)}',
      );

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
        _showEnhancedConnectionDialog(deviceInfo);
      } else {
        SenkronDialogs.showSuccessDialog(
          context,
          _bagliBulunanCihaz,
          _startEnhancedSynchronization,
        );
      }

      _showConnectionSnackbar(deviceInfo);
    });
  }

  // YENİ: Gelişmiş bağlantı dialog'u
  void _showEnhancedConnectionDialog(Map<String, dynamic> deviceInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cihaz bağlantı ikonu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    size: 48,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık
                Text(
                  '📱 Cihaz Bağlandı!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),

                // Cihaz bilgileri
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('📱 Cihaz', deviceInfo['clientName']),
                      _buildInfoRow('🌐 IP Adresi', deviceInfo['ip']),
                      _buildInfoRow(
                        '📄 Belgeler',
                        '${deviceInfo['belgeSayisi'] ?? 0} adet',
                      ),
                      _buildInfoRow(
                        '💾 Boyut',
                        '${(deviceInfo['toplamBoyut'] ?? 0) / 1024} KB',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Sync Manager seçimi
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚙️ Sync Manager Seçimi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SyncManagerType>(
                        value: _selectedSyncManager,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items:
                            SyncManagerType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  '${type.displayName} ${type.isRecommended ? "⭐" : ""}',
                                ),
                              );
                            }).toList(),
                        onChanged: (SyncManagerType? newType) {
                          if (newType != null) {
                            setState(() {
                              _selectedSyncManager = newType;
                            });
                            _senkronCoordinator.setSyncManagerType(newType);
                          }
                        },
                      ),
                      const SizedBox(height: 8),

                      // Auto fallback switch
                      Row(
                        children: [
                          Switch(
                            value: _autoFallbackEnabled,
                            onChanged: (bool value) {
                              setState(() {
                                _autoFallbackEnabled = value;
                              });
                              _senkronCoordinator.setAutoFallback(value);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Auto Fallback (hata durumunda güvenli manager\'a geç)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _performEnhancedSynchronization();
                        },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Senkronizasyonu Başlat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showConnectionSnackbar(Map<String, dynamic> deviceInfo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${deviceInfo['ip']} • Belgeler: ${deviceInfo['belgeSayisi'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        elevation: 8,
      ),
    );
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Animasyonları başlat
    _slideController.forward();
    _fadeController.forward();
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
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.wifi, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adres: $_localIP:8080 • Mobil cihazlar bağlanabilir',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.blue.shade600,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(20),
          elevation: 8,
        ),
      );
    }
  }

  void _showServerErrorSnackbar(String error) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.error, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Sunucu başlatılamadı: $error',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.all(20),
          elevation: 8,
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

      final success = await _senkronServisi.manuelBaglantiDene(ip);

      if (success) {
        _addLog('🎉 BAĞLANTI BAŞARILI!');

        SenkronDialogs.showSuccessDialog(
          context,
          _bagliBulunanCihaz,
          _startEnhancedSynchronization,
        );

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

  void _startEnhancedSynchronization() {
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

    _performEnhancedSynchronization();
  }

  Future<void> _performEnhancedSynchronization() async {
    try {
      _progressNotifier.value = 0.0;
      _currentOperationNotifier.value = 'Senkronizasyon başlatılıyor...';
      SenkronDialogs.showProgressDialog(
        context,
        _progressNotifier,
        _currentOperationNotifier,
      );

      final results = await _senkronCoordinator.performSynchronization(
        _bagliBulunanCihaz!,
      );

      Navigator.pop(context);

      // Enhanced results'ı eski format'a uyumlu hale getir
      final stats = results['statistics'] as Map<String, dynamic>? ?? {};
      final compatibleResults = {
        'yeni': (stats['downloadedDocuments'] ?? 0) as int,
        'gonderilen': (stats['uploadedDocuments'] ?? 0) as int,
        'guncellenen': (stats['updatedDocuments'] ?? 0) as int,
        'cakisma': (stats['conflictedDocuments'] ?? 0) as int,
        'hata': (stats['erroredDocuments'] ?? 0) as int,
      };

      _showSyncResultsSnackbar(compatibleResults);
    } catch (e) {
      Navigator.pop(context);
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

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

      final pingResponse = await http
          .get(Uri.parse('http://$ip:$port/ping'))
          .timeout(const Duration(seconds: 10));

      if (pingResponse.statusCode != 200) {
        throw Exception('Ping başarısız');
      }

      _addLog('✅ Ping başarılı, gerçek bağlantı kuruluyor...');

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

          await Future.delayed(const Duration(seconds: 1));
          _performEnhancedSynchronization();
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
    _slideController.dispose();
    _fadeController.dispose();
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade400.withOpacity(0.9),
              Colors.purple.shade400.withOpacity(0.9),
              Colors.pink.shade300.withOpacity(0.8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: _buildContent(),
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

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Geri gelme butonu (PC için)
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                ),
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false),
                tooltip: 'Ana Sayfaya Dön',
              ),
            ),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cihaz Senkronizasyonu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize:
                        Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS
                            ? 24
                            : 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cihazlar arası güvenli dosya paylaşımı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildEnhancedStatusIcon(),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatusIcon() {
    IconData icon;
    Color color;
    String status;

    if (_baglantiDeneniyor) {
      icon = Icons.sync;
      color = Colors.yellow.shade300;
      status = 'Bağlanıyor';
    } else if (_bagliBulunanCihaz != null) {
      icon = Icons.devices;
      color = Colors.green.shade300;
      status = 'Bağlı';
    } else if (_sunucuCalisiyorMu) {
      icon = Icons.wifi;
      color = Colors.blue.shade300;
      status = 'Hazır';
    } else {
      icon = Icons.wifi_off;
      color = Colors.white54;
      status = 'Kapalı';
    }

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            _buildEnhancedServerCard(),
            const SizedBox(height: 24),
          ],
          _buildEnhancedConnectionCard(),
          const SizedBox(height: 24),
          if (Platform.isAndroid || Platform.isIOS) ...[
            _buildEnhancedQRScanCard(),
            const SizedBox(height: 24),
          ],
          if (_bagliBulunanCihaz != null) ...[
            _buildEnhancedConnectedDeviceCard(),
            const SizedBox(height: 24),
          ],
          _buildEnhancedLogCard(),
        ],
      ),
    );
  }

  Widget _buildEnhancedServerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              _sunucuCalisiyorMu
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              _sunucuCalisiyorMu
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_sunucuCalisiyorMu ? Colors.green : Colors.grey)
                .withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          _sunucuCalisiyorMu
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_sunucuCalisiyorMu ? Colors.green : Colors.grey)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _sunucuCalisiyorMu ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sunucuCalisiyorMu
                            ? '🌐 Sunucu Aktif'
                            : '⚠️ Sunucu Kapalı',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sunucuCalisiyorMu && _localIP != null
                            ? 'Dinleniyor: $_localIP:8080'
                            : 'Sunucu başlatılmadı',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (_sunucuCalisiyorMu)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_sunucuCalisiyorMu && _localIP != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smartphone,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bu IP adresini telefonda girin:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        '$_localIP:8080',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: '$_localIP:8080'),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Kopyala'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.grey[700],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showQRCode,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('QR Kod'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Diğer cihazların bağlanabilmesi için sunucuyu başlatın.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startServer,
                        icon: const Icon(Icons.power_settings_new_rounded),
                        label: const Text('Sunucuyu Başlat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedConnectionCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.purple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Manuel Bağlantı',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bağlanmak istediğiniz cihazın IP adresini girin:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Adresi',
                  hintText: '192.168.1.100:8080',
                  helperText: 'Örnek: 192.168.1.100:8080 (port isteğe bağlı)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.computer_rounded),
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _baglantiDeneniyor ? null : _connectToDevice,
                icon:
                    _baglantiDeneniyor
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.link_rounded),
                label: Text(_baglantiDeneniyor ? 'Bağlanıyor...' : 'Bağlan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedQRScanCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'QR Kod ile Bağlan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  Icons.flash_on_rounded,
                  color: Colors.green[400],
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bilgisayardaki QR kodu tarayarak hızlı bağlantı kurun.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startQRScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('QR Kod Tara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedConnectedDeviceCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Bağlı Cihaz',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'BAĞLI',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildDeviceInfoRow(
                    Icons.computer_rounded,
                    'Cihaz',
                    _bagliBulunanCihaz!.ad,
                  ),
                  _buildDeviceInfoRow(
                    Icons.phone_android_rounded,
                    'Platform',
                    _bagliBulunanCihaz!.platform,
                  ),
                  _buildDeviceInfoRow(
                    Icons.wifi_rounded,
                    'IP Adresi',
                    _bagliBulunanCihaz!.ip,
                  ),
                  _buildDeviceInfoRow(
                    Icons.folder_rounded,
                    'Belgeler',
                    '${_bagliBulunanCihaz!.belgeSayisi} adet',
                  ),
                  _buildDeviceInfoRow(
                    Icons.storage_rounded,
                    'Boyut',
                    _formatFileSize(_bagliBulunanCihaz!.toplamBoyut),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startEnhancedSynchronization,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Senkronizasyon Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _disconnectDevice,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text('Bağlantıyı Kes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedLogCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Flexible(
                        child: Text(
                          'Aktivite Günlüğü',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _logMesajlari.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Temizle'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child:
                  _logMesajlari.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terminal_rounded,
                              color: Colors.grey[600],
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz aktivite yok',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logMesajlari.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _logMesajlari[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.green,
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

  Widget _buildDeviceInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.blue[600]),
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode() {
    if (_localIP != null && _sunucuCalisiyorMu) {
      SenkronDialogs.showQRCode(context, _localIP!);
    }
  }
}
