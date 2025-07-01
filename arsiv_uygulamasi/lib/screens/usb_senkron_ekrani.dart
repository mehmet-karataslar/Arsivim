import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../services/usb_senkron_servisi.dart';
import '../services/http_sunucu_servisi.dart';
import '../services/veritabani_servisi.dart';
import '../services/dosya_servisi.dart';
import '../services/tema_yoneticisi.dart';
import '../models/belge_modeli.dart';

class UsbSenkronEkrani extends StatefulWidget {
  const UsbSenkronEkrani({Key? key}) : super(key: key);

  @override
  State<UsbSenkronEkrani> createState() => _UsbSenkronEkraniState();
}

class _UsbSenkronEkraniState extends State<UsbSenkronEkrani>
    with TickerProviderStateMixin {
  final UsbSenkronServisi _senkronServisi = UsbSenkronServisi.instance;
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;
  final TextEditingController _ipController = TextEditingController();
  final NetworkInfo _networkInfo = NetworkInfo();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<StreamSubscription> _subscriptions = [];
  List<String> _logMesajlari = [];
  String? _localIP;
  bool _sunucuCalisiyorMu = false;
  bool _baglantiDeneniyor = false;
  SenkronCihazi? _bagliBulunanCihaz;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initStreams();
    _getLocalIP();
    _checkServerStatus();
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
    } catch (e) {
      _addLog('❌ Sunucu başlatma hatası: $e');
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
        _showSuccessDialog();

        // Bağlı cihaz bilgisini güncelle
        setState(() {
          _bagliBulunanCihaz = _senkronServisi.bagliBulunanCihaz;
        });
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

  // Başarı bildirimi dialog'u
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bağlantı Başarılı!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cihaz bağlantısı başarıyla kuruldu!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.devices,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _bagliBulunanCihaz?.ad ?? 'Bilinmeyen Cihaz',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.computer,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_bagliBulunanCihaz?.platform ?? "Bilinmeyen"}',
                          ),
                          const Spacer(),
                          Icon(Icons.folder, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 4),
                          Text('${_bagliBulunanCihaz?.belgeSayisi ?? 0} belge'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🎉 Artık dosyalarınızı senkronize edebilirsiniz!',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startSynchronization();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Şimdi Senkronize Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
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

    // Gerçek senkronizasyon başlat (basit versiyon)
    _performSimpleSyncWithRealData();
  }

  // Cihaz bağlantısını kesme
  void _disconnectDevice() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bağlantıyı Kes'),
            content: Text(
              '${_bagliBulunanCihaz?.ad ?? "Cihaz"} ile bağlantıyı kesmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _bagliBulunanCihaz = null;
                  });
                  _addLog('🔌 Cihaz bağlantısı kesildi');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bağlantı kesildi')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Kes', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
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

  // Gerçek senkronizasyon işlemi
  Future<void> _performRealSynchronization() async {
    try {
      _addLog('🔄 Senkronizasyon başlatıldı');

      // 1. Yerel belgeleri al
      _addLog('📊 Yerel belgeler kontrol ediliyor...');
      final veriTabani = VeriTabaniServisi();
      final yerelBelgeler = await veriTabani.belgeleriGetir();
      _addLog('📁 Yerel belge sayısı: ${yerelBelgeler.length}');

      // 2. Uzak cihazdan belgeleri al
      _addLog('📥 Uzak cihazdan belgeler alınıyor...');
      final uzakBelgeler = await _getRemoteDocuments();
      _addLog('📁 Uzak belge sayısı: ${uzakBelgeler.length}');

      // 3. Karşılaştırma ve senkronizasyon
      _addLog('🔍 Belgeler karşılaştırılıyor...');
      int yeniBelgeSayisi = 0;
      int guncellenmisBelgeSayisi = 0;

      for (final uzakBelge in uzakBelgeler) {
        final yerelBelge = yerelBelgeler.firstWhere(
          (belge) => belge.dosyaAdi == uzakBelge['dosyaAdi'],
          orElse:
              () => BelgeModeli(
                dosyaAdi: '',
                orijinalDosyaAdi: '',
                dosyaYolu: '',
                dosyaBoyutu: 0,
                dosyaTipi: '',
                dosyaHash: '',
                olusturmaTarihi: DateTime.now(),
                guncellemeTarihi: DateTime.now(),
              ),
        );

        if (yerelBelge.dosyaAdi.isEmpty) {
          // Yeni belge - indir
          await _downloadDocument(uzakBelge);
          yeniBelgeSayisi++;
          _addLog('📥 Yeni belge eklendi: ${uzakBelge['dosyaAdi']}');
        } else {
          // Mevcut belge - tarih kontrolü
          final uzakTarih = DateTime.parse(uzakBelge['olusturmaTarihi']);
          if (uzakTarih.isAfter(yerelBelge.olusturmaTarihi)) {
            await _downloadDocument(uzakBelge);
            guncellenmisBelgeSayisi++;
            _addLog('🔄 Belge güncellendi: ${uzakBelge['dosyaAdi']}');
          }
        }
      }

      // 4. Yerel belgeleri uzak cihaza gönder
      _addLog('📤 Yerel belgeler gönderiliyor...');
      int gonderilmiBelgeSayisi = 0;

      for (final yerelBelge in yerelBelgeler) {
        final uzakBelgeVar = uzakBelgeler.any(
          (uzakBelge) => uzakBelge['dosyaAdi'] == yerelBelge.dosyaAdi,
        );

        if (!uzakBelgeVar) {
          await _uploadDocument(yerelBelge);
          gonderilmiBelgeSayisi++;
          _addLog('📤 Belge gönderildi: ${yerelBelge.dosyaAdi}');
        }
      }

      // 5. Senkronizasyon tamamlandı
      Navigator.pop(context); // Progress dialog'u kapat

      _addLog('✅ Senkronizasyon tamamlandı!');
      _addLog('📊 Sonuçlar:');
      _addLog('   • Yeni belgeler: $yeniBelgeSayisi');
      _addLog('   • Güncellenen belgeler: $guncellenmisBelgeSayisi');
      _addLog('   • Gönderilen belgeler: $gonderilmiBelgeSayisi');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Senkronizasyon tamamlandı!\n'
            'Yeni: $yeniBelgeSayisi, Güncellenen: $guncellenmisBelgeSayisi, '
            'Gönderilen: $gonderilmiBelgeSayisi',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
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

  // Gerçek senkronizasyon işlemi
  Future<void> _performRealSynchronization() async {
    try {
      _addLog('🔄 Senkronizasyon başlatıldı');

      // 1. Yerel belgeleri al
      _addLog('📊 Yerel belgeler kontrol ediliyor...');
      final veriTabani = VeriTabaniServisi();
      final yerelBelgeler = await veriTabani.belgeleriGetir();
      _addLog('📁 Yerel belge sayısı: ${yerelBelgeler.length}');

      // 2. Uzak cihazdan belgeleri al
      _addLog('📥 Uzak cihazdan belgeler alınıyor...');
      final uzakBelgeler = await _getRemoteDocuments();
      _addLog('📁 Uzak belge sayısı: ${uzakBelgeler.length}');

      // 3. Karşılaştırma ve senkronizasyon
      _addLog('🔍 Belgeler karşılaştırılıyor...');
      int yeniBelgeSayisi = 0;
      int guncellenmisBelgeSayisi = 0;

      for (final uzakBelge in uzakBelgeler) {
        final yerelBelge = yerelBelgeler.firstWhere(
          (belge) => belge.dosyaAdi == uzakBelge['dosyaAdi'],
          orElse:
              () => BelgeModeli(
                dosyaAdi: '',
                dosyaYolu: '',
                dosyaBoyutu: 0,
                olusturmaTarihi: DateTime.now(),
                kategoriId: 1,
              ),
        );

        if (yerelBelge.dosyaAdi.isEmpty) {
          // Yeni belge - indir
          await _downloadDocument(uzakBelge);
          yeniBelgeSayisi++;
          _addLog('📥 Yeni belge eklendi: ${uzakBelge['dosyaAdi']}');
        } else {
          // Mevcut belge - tarih kontrolü
          final uzakTarih = DateTime.parse(uzakBelge['olusturmaTarihi']);
          if (uzakTarih.isAfter(yerelBelge.olusturmaTarihi)) {
            await _downloadDocument(uzakBelge);
            guncellenmisBelgeSayisi++;
            _addLog('🔄 Belge güncellendi: ${uzakBelge['dosyaAdi']}');
          }
        }
      }

      // 4. Yerel belgeleri uzak cihaza gönder
      _addLog('📤 Yerel belgeler gönderiliyor...');
      int gonderilmiBelgeSayisi = 0;

      for (final yerelBelge in yerelBelgeler) {
        final uzakBelgeVar = uzakBelgeler.any(
          (uzakBelge) => uzakBelge['dosyaAdi'] == yerelBelge.dosyaAdi,
        );

        if (!uzakBelgeVar) {
          await _uploadDocument(yerelBelge);
          gonderilmiBelgeSayisi++;
          _addLog('📤 Belge gönderildi: ${yerelBelge.dosyaAdi}');
        }
      }

      // 5. Senkronizasyon tamamlandı
      Navigator.pop(context); // Progress dialog'u kapat

      _addLog('✅ Senkronizasyon tamamlandı!');
      _addLog('📊 Sonuçlar:');
      _addLog('   • Yeni belgeler: $yeniBelgeSayisi');
      _addLog('   • Güncellenen belgeler: $guncellenmisBelgeSayisi');
      _addLog('   • Gönderilen belgeler: $gonderilmiBelgeSayisi');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Senkronizasyon tamamlandı!\n'
            'Yeni: $yeniBelgeSayisi, Güncellenen: $guncellenmisBelgeSayisi, '
            'Gönderilen: $gonderilmiBelgeSayisi',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
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

  // Uzak cihazdan belge listesi al
  Future<List<Map<String, dynamic>>> _getRemoteDocuments() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://${_bagliBulunanCihaz!.ip}:8080/documents'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['documents'] ?? []);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Uzak belgeler alınamadı: $e');
      return [];
    }
  }

  // Uzak cihazdan belge indir
  Future<void> _downloadDocument(Map<String, dynamic> belgeData) async {
    try {
      final dosyaAdi = belgeData['dosyaAdi'];
      _addLog('📥 İndiriliyor: $dosyaAdi');

      // Belge içeriğini al
      final response = await http
          .get(
            Uri.parse(
              'http://${_bagliBulunanCihaz!.ip}:8080/download/$dosyaAdi',
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Dosyayı belgeler klasörüne kaydet
        final dosyaServisi = DosyaServisi();
        final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
        final yeniDosyaYolu = '$belgelerKlasoru/$dosyaAdi';

        // Dosyayı yaz
        final dosya = File(yeniDosyaYolu);
        await dosya.writeAsBytes(response.bodyBytes);

        // Veritabanına ekle
        final veriTabani = VeriTabaniServisi();
        final yeniBelge = BelgeModeli(
          dosyaAdi: dosyaAdi,
          orijinalDosyaAdi: belgeData['dosyaAdi'] ?? dosyaAdi,
          dosyaYolu: yeniDosyaYolu,
          dosyaBoyutu: response.bodyBytes.length,
          dosyaTipi: belgeData['dosyaTipi'] ?? 'unknown',
          dosyaHash: belgeData['dosyaHash'] ?? '',
          olusturmaTarihi: DateTime.parse(belgeData['olusturmaTarihi']),
          guncellemeTarihi: DateTime.now(),
          kategoriId: belgeData['kategoriId'] ?? 1,
          baslik: belgeData['baslik'],
          aciklama: belgeData['aciklama'],
          kisiId: belgeData['kisiId'],
          etiketler:
              belgeData['etiketler'] != null
                  ? List<String>.from(belgeData['etiketler'])
                  : null,
        );

        await veriTabani.belgeEkle(yeniBelge);
        _addLog('✅ İndirildi: $dosyaAdi');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ İndirme hatası (${belgeData['dosyaAdi']}): $e');
    }
  }

  // Yerel belgeyi uzak cihaza yükle
  Future<void> _uploadDocument(BelgeModeli belge) async {
    try {
      _addLog('📤 Yükleniyor: ${belge.dosyaAdi}');

      // Dosya içeriğini oku
      final dosya = File(belge.dosyaYolu);
      if (!await dosya.exists()) {
        throw Exception('Dosya bulunamadı: ${belge.dosyaYolu}');
      }

      final dosyaBytes = await dosya.readAsBytes();

      // Multipart request oluştur
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://${_bagliBulunanCihaz!.ip}:8080/upload'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          dosyaBytes,
          filename: belge.dosyaAdi,
        ),
      );

      // Belge metadata'sını ekle
      request.fields['metadata'] = json.encode({
        'dosyaAdi': belge.dosyaAdi,
        'kategoriId': belge.kategoriId,
        'baslik': belge.baslik,
        'aciklama': belge.aciklama,
        'kisiId': belge.kisiId,
        'etiketler': belge.etiketler,
        'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
      });

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        _addLog('✅ Yüklendi: ${belge.dosyaAdi}');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Yükleme hatası (${belge.dosyaAdi}): $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ipController.dispose();
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
          const Expanded(
            child: Text(
              'Cihaz Senkronizasyonu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
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
          _buildLogCard(),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _sunucuCalisiyorMu ? Icons.wifi : Icons.wifi_off,
                  color: _sunucuCalisiyorMu ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _sunucuCalisiyorMu ? 'Sunucu Aktif' : 'Sunucu Kapalı',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_sunucuCalisiyorMu && _localIP != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Bu IP adresini telefonda girin:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '$_localIP:8080',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: '$_localIP:8080'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('IP adresi kopyalandı'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Kopyala'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showQRCode(context),
                          icon: const Icon(Icons.qr_code),
                          label: const Text('QR Kod'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Diğer cihazların bağlanabilmesi için sunucuyu başlatın.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _startServer,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Sunucuyu Başlat'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cihaza Bağlan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bağlanmak istediğiniz cihazın IP adresini girin:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Adresi',
                hintText: '192.168.1.100:8080',
                helperText: 'Örnek: 192.168.1.100:8080 (port isteğe bağlı)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                // Gerçek zamanlı format kontrolü
                if (value.isNotEmpty && !value.contains('.')) {
                  // Geçersiz format uyarısı verebiliriz
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _baglantiDeneniyor ? null : _connectToDevice,
                icon:
                    _baglantiDeneniyor
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.link),
                label: Text(_baglantiDeneniyor ? 'Bağlanıyor...' : 'Bağlan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Bağlı Cihaz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'BAĞLI',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bağlı cihaz bilgileri
            _buildDeviceInfoRow(
              Icons.computer,
              'Cihaz',
              _bagliBulunanCihaz?.ad ?? "Bilinmeyen",
            ),
            _buildDeviceInfoRow(
              Icons.phone_android,
              'Platform',
              _bagliBulunanCihaz?.platform ?? "Bilinmeyen",
            ),
            _buildDeviceInfoRow(
              Icons.wifi,
              'IP Adresi',
              _bagliBulunanCihaz?.ip ?? "Bilinmeyen",
            ),
            _buildDeviceInfoRow(
              Icons.folder,
              'Belgeler',
              '${_bagliBulunanCihaz?.belgeSayisi ?? 0} adet',
            ),
            _buildDeviceInfoRow(
              Icons.storage,
              'Boyut',
              _formatFileSize(_bagliBulunanCihaz?.toplamBoyut ?? 0),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Senkronizasyon butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startSynchronization(),
                icon: const Icon(Icons.sync),
                label: const Text('Senkronizasyon Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _disconnectDevice(),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Bağlantıyı Kes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
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

  Widget _buildLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Aktivite Günlüğü',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _logMesajlari.clear();
                    });
                  },
                  child: const Text('Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child:
                  _logMesajlari.isEmpty
                      ? const Center(
                        child: Text(
                          'Henüz aktivite yok',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logMesajlari.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
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

  // QR Kod gösterme
  void _showQRCode(BuildContext context) {
    if (_localIP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IP adresi henüz alınamadı')),
      );
      return;
    }

    final qrData = json.encode({
      'type': 'arsivim_connection',
      'ip': _localIP,
      'port': 8080,
      'url': '$_localIP:8080',
      'name': 'Arşivim Cihazı',
      'timestamp': DateTime.now().toIso8601String(),
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Kod ile Bağlantı'),
            content: SizedBox(
              width: 300,
              height: 350,
              child: Column(
                children: [
                  const Text(
                    'Bu QR kodu telefon ile tarayın:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_localIP:8080',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  // QR Kod tarama kartı (mobil cihazlar için)
  Widget _buildQRScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'QR Kod ile Bağlan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bilgisayardaki QR kodu tarayarak hızlı bağlantı kurun.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startQRScan(),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QR Kod Tara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        final url = '$ip:$port';

        // IP adresini otomatik doldur
        _ipController.text = url;

        // Otomatik bağlantı dene
        _connectToDevice();

        _addLog('📱 QR kod tarandı: $url');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('QR kod tarandı: $url')));
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
}

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final Function(String) onQRScanned;

  const QRScannerScreen({Key? key, required this.onQRScanned})
    : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Tara'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: const Icon(Icons.flip_camera_android),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (isScanning && capture.barcodes.isNotEmpty) {
                      final String? code = capture.barcodes.first.rawValue;
                      if (code != null) {
                        isScanning = false;
                        widget.onQRScanned(code);
                      }
                    }
                  },
                ),
                // Custom overlay
                Container(
                  decoration: ShapeDecoration(
                    shape: QRScannerOverlayShape(
                      borderColor: Colors.green,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'QR kodu kamera ile tarayın',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Arşivim bağlantı QR kodunu tarayın',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom QR Scanner Overlay
class QRScannerOverlayShape extends ShapeBorder {
  const QRScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    Path holePath =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center,
              width: cutOutSize,
              height: cutOutSize,
            ),
            Radius.circular(borderRadius),
          ),
        );
    return Path.combine(PathOperation.difference, path, holePath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint =
        Paint()
          ..color = overlayColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(getOuterPath(rect), paint);

    // Draw border
    final Paint borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final double centerX = rect.center.dx;
    final double centerY = rect.center.dy;
    final double halfSize = cutOutSize / 2;

    // Top-left corner
    canvas.drawLine(
      Offset(centerX - halfSize, centerY - halfSize),
      Offset(centerX - halfSize + borderLength, centerY - halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX - halfSize, centerY - halfSize),
      Offset(centerX - halfSize, centerY - halfSize + borderLength),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(centerX + halfSize, centerY - halfSize),
      Offset(centerX + halfSize - borderLength, centerY - halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX + halfSize, centerY - halfSize),
      Offset(centerX + halfSize, centerY - halfSize + borderLength),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(centerX - halfSize, centerY + halfSize),
      Offset(centerX - halfSize + borderLength, centerY + halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX - halfSize, centerY + halfSize),
      Offset(centerX - halfSize, centerY + halfSize - borderLength),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(centerX + halfSize, centerY + halfSize),
      Offset(centerX + halfSize - borderLength, centerY + halfSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(centerX + halfSize, centerY + halfSize),
      Offset(centerX + halfSize, centerY + halfSize - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
