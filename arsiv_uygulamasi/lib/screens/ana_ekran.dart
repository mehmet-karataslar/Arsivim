import 'dart:io';
import 'package:flutter/material.dart';
import '../models/ana_sayfa_ozeti.dart';
import '../models/belge_modeli.dart';
import '../services/auth_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/log_servisi.dart';
import '../services/veritabani_servisi.dart';
import '../utils/sabitler.dart';
import '../utils/screen_utils.dart';
import '../widgets/common/app_sidebar.dart';
import '../services/home_summary_service.dart';
import 'kisi_ekle_ekrani.dart';
import '../widgets/common/app_header.dart';
import '../widgets/home/home_content.dart';
import '../widgets/home/recent_documents.dart';
import '../widgets/home/storage_info_dialog.dart';
import 'auth/login_screen.dart';
import 'belge_duzenle_ekrani.dart';
import 'belgeler_ekrani.dart';
import 'kategoriler_ekrani.dart';
import 'kisiler_ekrani.dart';
import 'profil_ekrani.dart';
import 'senkronizasyon_ekrani.dart';
import 'yedekleme_ekrani.dart';
import 'yeni_belge_ekle_ekrani.dart';

/// Uygulama kabuğu: veri yaşam döngüsü ve yönlendirme.
/// Ana sayfanın sunumu widgets/home, ortak bileşenler widgets/common içindedir.
class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key, this.loadSummary});
  final Future<AnaSayfaOzeti> Function()? loadSummary;

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _selectedTab = 0;
  AnaSayfaOzeti? _summary;
  bool _loading = false;
  String? _error;
  Future<void>? _loadFuture;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _documentSearch = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Aynı anda tek sorgu grubu; yenileme sırasında mevcut içerik korunur.
  Future<void> _refresh() =>
      _loadFuture ??= _load().whenComplete(() => _loadFuture = null);

  Future<AnaSayfaOzeti> _readSummary() => HomeSummaryService().read();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await (widget.loadSummary ?? _readSummary)();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error, stack) {
      LogServisi.instance.error('Ana sayfa yüklenemedi', error, stack);
      if (mounted) {
        setState(
          () =>
              _error =
                  _summary == null
                      ? 'Arşiv bilgileri yüklenemedi. Yeniden deneyebilirsiniz.'
                      : 'Bilgiler yenilenemedi. Son yüklenen bilgiler gösteriliyor.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
    if (index == 0) _refresh();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop =
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      Widget sidebar() => AppSidebar(
        selectedIndex: _selectedTab,
        summary: _summary,
        onSelected: (index) {
          _scaffoldKey.currentState?.closeDrawer();
          _navigate(index);
        },
        onStorage: _showStorage,
        onLogout: _logout,
      );
      return Scaffold(
        key: _scaffoldKey,
        drawer: desktop ? null : Drawer(width: 268, child: sidebar()),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop) sidebar(),
              Expanded(
                key: const ValueKey('workspace'),
                child: Column(
                  children: [
                    if (!desktop || (_selectedTab != 0 && _selectedTab != 1))
                      AppHeader(
                        onSearch: () => _navigate(1),
                        onRefresh: _refresh,
                        onLogout: _logout,
                        refreshing: _loading,
                        onMenu:
                            desktop
                                ? null
                                : () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                    Expanded(child: _tabContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _tabContent() {
    switch (_selectedTab) {
      case 1:
        return BelgelerEkrani(
          initialSearch: _documentSearch,
          onDataChanged: _refresh,
          onStorage: _showStorage,
        );
      case 2:
        return const KategorilerEkrani();
      case 3:
        return const SenkronizasyonEkrani();
      case 4:
        return const KisilerEkrani();
      case 6:
        return const YedeklemeEkrani();
      case 5:
        return ProfilEkrani(kullanici: AuthServisi.instance.currentUser);
      default:
        return HomeContent(
          summary: _summary,
          loading: _loading,
          error: _error,
          onRefresh: _refresh,
          onAdd: _addDocument,
          onNavigate: _navigate,
          onBackup: () => _navigate(6),
          onSearch: (query) {
            _documentSearch = query;
            _navigate(1);
          },
          onAddPerson:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const KisiEkleEkrani())),
          onStorage: _showStorage,
          onDocumentAction: _documentAction,
        );
    }
  }

  Future<void> _addDocument() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const YeniBelgeEkleEkrani()),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _documentAction(
    BelgeModeli document,
    HomeDocumentAction action,
  ) async {
    final service = BelgeIslemleriServisi();
    switch (action) {
      case HomeDocumentAction.open:
        await service.belgeAc(document, context);
      case HomeDocumentAction.share:
        await service.belgePaylas(document, context);
      case HomeDocumentAction.edit:
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BelgeDuzenleEkrani(belge: document),
          ),
        );
        if (changed == true && mounted) await _refresh();
      case HomeDocumentAction.delete:
        await service.belgeSil(document, context);
        if (mounted) await _refresh();
    }
  }

  Future<void> _showStorage() async {
    try {
      final path = await VeriTabaniServisi.veritabaniYolu();
      final file = File(path);
      final exists = await file.exists();
      final bytes = exists ? await file.length() : 0;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (_) => StorageInfoDialog(
              path: path,
              exists: exists,
              size: ScreenUtils.formatFileSize(bytes),
              version: Sabitler.VERITABANI_VERSIYONU,
            ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veritabanı bilgileri alınamadı.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Çıkış yap'),
            content: const Text('Oturumunuzu kapatmak istiyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
    );
    if (approved != true) return;
    await AuthServisi.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
