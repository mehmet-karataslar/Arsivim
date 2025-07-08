import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'qr_scanner_widget.dart';

class QRGeneratorWidget extends StatefulWidget {
  final String connectionData;
  final String title;
  final VoidCallback? onRefresh;

  const QRGeneratorWidget({
    Key? key,
    required this.connectionData,
    this.title = 'Bağlantı QR Kodu',
    this.onRefresh,
  }) : super(key: key);

  @override
  State<QRGeneratorWidget> createState() => _QRGeneratorWidgetState();
}

class _QRGeneratorWidgetState extends State<QRGeneratorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showInfo = false;

  // Platform kontrolü
  bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildQRCode(),
            const SizedBox(height: 20),
            _buildConnectionInfo(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.qr_code, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _pcPlatform
                    ? 'Mobil cihazdan bu QR kodu tarayın'
                    : 'Bu cihazın QR kodu',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
          onPressed: () => setState(() => _showInfo = !_showInfo),
          tooltip: 'Bilgi',
        ),
      ],
    );
  }

  Widget _buildQRCode() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            QrImageView(
              data: widget.connectionData,
              version: QrVersions.auto,
              size: _pcPlatform ? 220.0 : 180.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorStateBuilder: (context, error) {
                return Container(
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 60),
                        const SizedBox(height: 8),
                        Text(
                          'QR kod oluşturulamadı',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green[200] ?? Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Bağlantı Hazır',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo() {
    if (!_showInfo) return Container();

    Map<String, dynamic> connectionInfo;
    try {
      connectionInfo = json.decode(widget.connectionData);
    } catch (e) {
      connectionInfo = {'error': 'Geçersiz veri'};
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, size: 18, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                'Bağlantı Bilgileri',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...connectionInfo.entries
              .map((entry) => _buildInfoRow(entry.key, entry.value.toString()))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Kopyala',
            Icons.copy,
            Colors.blue,
            _kopyala,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Paylaş',
            Icons.share,
            Colors.green,
            _paylas,
          ),
        ),
        if (widget.onRefresh != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Yenile',
              Icons.refresh,
              Colors.orange,
              widget.onRefresh!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _kopyala() {
    Clipboard.setData(ClipboardData(text: widget.connectionData));
    _basariMesaji('Bağlantı bilgisi kopyalandı');
  }

  void _paylas() {
    // Share.share(widget.connectionData, subject: 'Arşivim Bağlantı Bilgisi');
    _basariMesaji('Paylaşım özelliği yakında...');
  }

  void _basariMesaji(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(mesaj),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// QR Kod Bağlantı Ekranı
class QRConnectionScreen extends StatefulWidget {
  const QRConnectionScreen({Key? key}) : super(key: key);

  @override
  State<QRConnectionScreen> createState() => _QRConnectionScreenState();
}

class _QRConnectionScreenState extends State<QRConnectionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _connectionData = '';
  List<Map<String, dynamic>> _bagliCihazlar = [];

  // Platform kontrolü
  bool get _pcPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connectionDataOlustur();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _connectionDataOlustur() {
    final connectionInfo = {
      'type': 'arsivim_connection',
      'version': '1.0',
      'device_id': 'device_123456789',
      'device_name':
          _pcPlatform ? 'PC-${Platform.operatingSystem}' : 'Mobile-Android',
      'ip': '192.168.1.100',
      'port': 8080,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'platform': Platform.operatingSystem,
    };

    setState(() {
      _connectionData = json.encode(connectionInfo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Bağlantı'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: Icon(_pcPlatform ? Icons.qr_code : Icons.qr_code_scanner),
              text: _pcPlatform ? 'QR Kod Göster' : 'QR Kod Tara',
            ),
            const Tab(icon: Icon(Icons.devices), text: 'Bağlı Cihazlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildQRTab(), _buildDevicesTab()],
      ),
    );
  }

  Widget _buildQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_pcPlatform) _buildPCQRView() else _buildMobileQRView(),
          const SizedBox(height: 24),
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildPCQRView() {
    return QRGeneratorWidget(
      connectionData: _connectionData,
      title: 'PC Bağlantı QR Kodu',
      onRefresh: _connectionDataOlustur,
    );
  }

  Widget _buildMobileQRView() {
    return Column(
      children: [
        QRGeneratorWidget(
          connectionData: _connectionData,
          title: 'Mobil Bağlantı QR Kodu',
          onRefresh: _connectionDataOlustur,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _qrKoduTara,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QR Kod Tara'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Nasıl Kullanılır?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_pcPlatform) ...[
              _buildInstructionStep(
                '1',
                'Mobil cihazınızda Arşivim uygulamasını açın',
              ),
              _buildInstructionStep('2', 'Senkronizasyon sayfasına gidin'),
              _buildInstructionStep('3', 'QR kod tara butonuna basın'),
              _buildInstructionStep('4', 'Bu QR kodu tarayın'),
            ] else ...[
              _buildInstructionStep('1', 'PC\'de Arşivim uygulamasını açın'),
              _buildInstructionStep('2', 'QR kod göster butonuna basın'),
              _buildInstructionStep('3', 'QR Kod Tara butonuna basın'),
              _buildInstructionStep('4', 'PC\'deki QR kodu tarayın'),
            ],
            _buildInstructionStep(
              '5',
              'Bağlantı kurulacak ve senkronizasyon başlayacak',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDeviceHeader(),
          const SizedBox(height: 16),
          Expanded(
            child:
                _bagliCihazlar.isEmpty
                    ? _buildNoDevices()
                    : _buildDevicesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.devices, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bağlı Cihazlar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_bagliCihazlar.length} cihaz bağlı',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _cihazlariYenile,
              icon: const Icon(Icons.refresh),
              tooltip: 'Yenile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevices() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Henüz bağlı cihaz yok',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'QR kod ile cihaz bağlayın',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      itemCount: _bagliCihazlar.length,
      itemBuilder: (context, index) {
        final cihaz = _bagliCihazlar[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.smartphone, color: Colors.green[600]),
            ),
            title: Text(cihaz['name'] ?? 'Bilinmeyen Cihaz'),
            subtitle: Text(cihaz['ip'] ?? 'IP Bilinmiyor'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Bağlı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _cihazBagla(Map<String, dynamic> connectionInfo) {
    setState(() {
      _bagliCihazlar.add({
        'name': connectionInfo['device_name'],
        'ip': connectionInfo['ip'],
        'platform': connectionInfo['platform'],
        'connected_at': DateTime.now(),
      });
    });

    _basariMesaji('Cihaz başarıyla bağlandı: ${connectionInfo['device_name']}');
    _tabController.animateTo(1); // Cihazlar sekmesine geç
  }

  void _cihazlariYenile() {
    _basariMesaji('Cihazlar yenilendi');
  }

  void _basariMesaji(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(mesaj),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Text(mesaj),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _qrKoduTara() {
    print('📱 QR kod tarayıcısı açılıyor (QR Connection)...');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              onQRScanned: (qrData) {
                print('📷 QR kod tarandı (QR Connection): $qrData');

                // QR kod tarandığında hemen kapansın
                Navigator.of(context).pop();
                print('🔄 QR scanner hemen kapatıldı (QR Connection)');

                // Arka planda bağlantı işlemlerini yap
                _processQRCodeConnection(qrData);
              },
            ),
      ),
    );
  }

  void _processQRCodeConnection(String qrData) async {
    try {
      print('🔄 QR kod işleniyor (QR Connection): $qrData');
      final connectionInfo = json.decode(qrData);

      if (connectionInfo['type'] == 'arsivim_connection') {
        print('✅ Geçerli Arşivim QR kodu, bağlantı simüle ediliyor...');

        // Gerçek bağlantı işlemini burada yapın
        // Şimdilik simüle ediyoruz
        await Future.delayed(const Duration(seconds: 1));

        // Cihazı bağla
        _cihazBagla(connectionInfo);
      } else {
        print('❌ Geçersiz QR kod formatı');
        _hataGoster('Geçersiz QR kod');
      }
    } catch (e) {
      print('❌ QR kod işleme hatası: $e');
      _hataGoster('QR kod okunamadı: $e');
    }
  }
}
