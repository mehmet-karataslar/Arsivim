import 'dart:io';
import 'package:flutter/material.dart';
import '../models/sync_overview.dart';
import '../providers/sync_controller.dart';
import '../services/sync_gateway.dart';
import '../services/sync_repository.dart';
import '../theme/app_tones.dart';
import '../widgets/common/metric_grid.dart';
import '../widgets/common/workspace_layout.dart';
import '../widgets/aktarim_kisi_secimi.dart';
import '../widgets/yonetici_dogrulama_dialog.dart';
import '../widgets/qr_scanner_widget.dart';
import '../widgets/sync/sync_section.dart';
import '../widgets/sync/sync_status.dart';
import '../widgets/sync/sync_controls.dart';
import '../widgets/sync/sync_devices.dart';
import '../widgets/sync/sync_activity.dart';
import '../widgets/sync/sync_statistics.dart';

class SenkronizasyonEkrani extends StatefulWidget {
  const SenkronizasyonEkrani({
    super.key,
    this.showHeading = true,
    this.repository,
    this.gateway,
    this.verifyPairing,
  });
  final bool showHeading;
  final SyncRepository? repository;
  final SyncGateway? gateway;
  final Future<bool> Function(BuildContext)? verifyPairing;
  @override
  State<SenkronizasyonEkrani> createState() => _SenkronizasyonEkraniState();
}

class _SenkronizasyonEkraniState extends State<SenkronizasyonEkrani>
    with WidgetsBindingObserver {
  late final SyncController _data;
  final _search = TextEditingController();
  String? _qr;
  bool _pairing = false;
  bool _qrOpen = false;
  late final Future<int?> Function(String, List<Map<String, dynamic>>)
  _choosePerson;
  @override
  void initState() {
    super.initState();
    _data = SyncController(
      widget.repository ?? SyncRepository(),
      widget.gateway ?? SyncGateway(),
    );
    _choosePerson =
        (message, people) async =>
            mounted ? aktarimKisiSecimi(context, message, people) : null;
    if (widget.gateway == null) {
      _data.gateway.manager.onKisiSecimi = _choosePerson;
    }
    WidgetsBinding.instance.addObserver(this);
    _data.refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _data.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.gateway == null &&
        _data.gateway.manager.onKisiSecimi == _choosePerson) {
      _data.gateway.manager.onKisiSecimi = null;
    }
    _data.dispose();
    _search.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showQr() async {
    if (_pairing || _qrOpen || _data.busy) return;
    setState(() => _pairing = true);
    try {
      var code = _qr;
      if (code == null || !_data.gateway.isQrValid(code)) {
        setState(() => _qr = null);
        final verify = widget.verifyPairing ?? yoneticiDogrulamaDialog;
        if (!await verify(context) || !mounted) return;
        code = await _data.gateway.createQr();
        if (!mounted) return;
        setState(() => _qr = code);
        await _data.refresh();
      }
      if (mounted) {
        final qrCode = code;
        setState(() {
          _pairing = false;
          _qrOpen = true;
        });
        await showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Cihaz bağlantı QR kodu'),
                content: SizedBox(
                  width: (MediaQuery.sizeOf(ctx).width - 112).clamp(160, 360),
                  child: SingleChildScrollView(
                    child: AnimatedBuilder(
                      animation: _data.gateway.changes,
                      builder:
                          (context, _) =>
                              _data.gateway.isQrValid(qrCode)
                                  ? SyncPairingCode(
                                    data: qrCode,
                                    size: (MediaQuery.sizeOf(ctx).width - 112)
                                        .clamp(160, 360),
                                  )
                                  : const Text(
                                    'Bu QR kod artık geçerli değil. Pencereyi kapatıp yeni kod oluşturun.',
                                  ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
        );
      }
    } catch (_) {
      _message('QR kod oluşturulamadı. Hesap ve ağ bağlantınızı kontrol edin.');
    } finally {
      if (mounted) {
        setState(() {
          _pairing = false;
          _qrOpen = false;
        });
      }
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (ctx) => QRScannerScreen(
              onQRScanned: (value) => Navigator.of(ctx).pop(value),
            ),
      ),
    );
    if (!mounted || code == null) return;
    try {
      if (!await hesapEslesmesiniOnayla(context, code) || !mounted) return;
      final success = await _data.gateway.connect(code);
      _message(
        success
            ? 'Cihaz bağlandı.'
            : 'Cihaz bağlanamadı. Aynı ağı ve güncel QR kodunu kontrol edin.',
      );
      await _data.refresh();
    } catch (_) {
      _message('Bağlantı kurulamadı. Yeniden deneyin.');
    }
  }

  Future<void> _transfer(SyncMode mode) async {
    final targets = _data.targets(mode);
    if (targets.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Belge aktarımı'),
            content: SingleChildScrollView(
              child: Text(
                '${mode == SyncMode.pending ? 'Bekleyen yerel değişiklikler' : 'Tüm aktif belgeler'} şu cihazlara gönderilecek:\n\n'
                '${targets.map((d) => d.name).join('\n')}\n\n'
                '${mode == SyncMode.pending ? 'Yeni bağlanan cihazın eksik belgeleri için tüm belgeleri gönderin.' : 'Kişi ve kategori bilgileri belgelerle birlikte aktarılır.'}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Gönder'),
              ),
            ],
          ),
    );
    if (approved == true && mounted) await _data.transfer(mode, targets);
  }

  Future<void> _disconnect(SyncDevice device) async {
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Bağlantıyı kes'),
            content: Text('${device.name} cihazının bağlantısı kesilsin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Bağlantıyı kes'),
              ),
            ],
          ),
    );
    if (approved == true && mounted) await _data.disconnect(device.id);
  }

  void _history() => showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Son 30 aktarım kaydı'),
          content: SizedBox(
            width: 600,
            height: MediaQuery.sizeOf(ctx).height * .55,
            child:
                (_data.overview?.events.isEmpty ?? true)
                    ? const Text('Henüz kayıtlı aktarım yok.')
                    : ListView.builder(
                      itemCount: _data.overview!.events.length,
                      itemBuilder:
                          (_, i) =>
                              SyncEventTile(event: _data.overview!.events[i]),
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _data,
    builder:
        (context, _) => LayoutBuilder(
          builder: (context, box) {
            final compact = WorkspaceLayout.compact(context);
            final wide =
                box.maxWidth >= 1120 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            final overview = _data.overview;
            final serverButton = FilledButton.icon(
              key: const ValueKey('sync-server-button'),
              onPressed:
                  _data.busy || _data.transferring || _data.gateway.transferring
                      ? null
                      : _pairing
                      ? null
                      : () async {
                        await _data.server();
                        if (mounted && !_data.gateway.running) {
                          setState(() => _qr = null);
                        }
                      },
              icon: Icon(
                _data.gateway.running
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                size: 19,
              ),
              label: Text(
                _data.busy
                    ? 'Bekleyin…'
                    : _data.gateway.running
                    ? 'Sunucuyu durdur'
                    : 'Sunucuyu başlat',
              ),
            );
            final search = TextField(
              controller: _search,
              onChanged: _data.search,
              decoration: const InputDecoration(
                hintText: 'Cihaz adı veya IP ara…',
                prefixIcon: Icon(Icons.search),
              ),
            );
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showHeading)
                  Text(
                    'Senkronizasyon',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (!compact)
                  Text(
                    'Cihazlarınızı bağlayın, belgelerinizi aktarın.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
              ],
            );
            final toolbar =
                wide
                    ? Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 16),
                        SizedBox(width: 280, child: search),
                        IconButton(
                          tooltip: 'Senkronizasyonu yenile',
                          onPressed: _data.loading ? null : _data.refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        const SizedBox(width: 10),
                        serverButton,
                      ],
                    )
                    : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.showHeading || !compact) ...[
                            heading,
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(child: search),
                              IconButton(
                                tooltip: 'Senkronizasyonu yenile',
                                onPressed: _data.loading ? null : _data.refresh,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          serverButton,
                        ],
                      ),
                    );
            final summary = MetricGrid(
              items: [
                MetricData(
                  'Bağlı cihaz',
                  '${_data.devices.length}',
                  'Etkin cihaz bağlantıları',
                  Icons.devices,
                  AppTone.primary,
                ),
                MetricData(
                  'Bekleyen belge',
                  overview?.pending.toString() ?? '—',
                  'Bekleyen yerel değişiklikler',
                  Icons.description_outlined,
                  AppTone.amber,
                ),
                MetricData(
                  'Bugün senkronize',
                  overview?.today.toString() ?? '—',
                  'Doğrulanan farklı dosyalar',
                  Icons.sync,
                  AppTone.blue,
                ),
                MetricData(
                  'Son yedekleme',
                  syncDate(overview?.lastBackup),
                  'Son başarılı yedek kaydı',
                  Icons.cloud_outlined,
                  AppTone.purple,
                ),
              ],
            );
            final stats = SyncStatistics(overview: overview);
            final status = SyncStatus(controller: _data);
            final controls = SyncControls(
              controller: _data,
              onTransfer: _transfer,
            );
            final devices = SyncDevices(
              controller: _data,
              qrData: _qr != null && _data.gateway.isQrValid(_qr!) ? _qr : null,
              onQr: _showQr,
              pairing: _pairing || _qrOpen,
              onDisconnect: _disconnect,
              onScan: Platform.isAndroid || Platform.isIOS ? _scan : null,
            );
            final activity = SyncActivity(
              events: overview?.events ?? [],
              onAll: _history,
            );
            return RefreshIndicator(
              onRefresh: _data.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 22,
                  vertical: compact ? 8 : 22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    toolbar,
                    const SizedBox(height: 18),
                    if (_data.loading || _pairing)
                      const LinearProgressIndicator(),
                    if (_data.error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_data.error!),
                      ),
                    if (!compact) ...[summary, const SizedBox(height: 16)],
                    SyncOptions(controller: _data, compact: compact),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 46,
                            child: Column(
                              children: [
                                status,
                                const SizedBox(height: 16),
                                controls,
                                const SizedBox(height: 16),
                                stats,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 54,
                            child: Column(
                              children: [
                                devices,
                                const SizedBox(height: 16),
                                activity,
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      status,
                      const SizedBox(height: 12),
                      controls,
                      const SizedBox(height: 12),
                      devices,
                      const SizedBox(height: 12),
                      activity,
                      const SizedBox(height: 12),
                      if (compact)
                        ExpansionTile(
                          title: const Text('İstatistikler'),
                          children: [summary],
                        )
                      else
                        stats,
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
  );
}
