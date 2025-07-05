import 'package:flutter/foundation.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/log_servisi.dart';
import '../services/error_handler_servisi.dart';

/// Ana uygulama state manager'ı
class AppStateManager extends ChangeNotifier {
  // Services
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;

  // Application state
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  // Data collections
  List<BelgeModeli> _belgeler = [];
  List<KisiModeli> _kisiler = [];
  List<KategoriModeli> _kategoriler = [];

  // Statistics
  int _toplamBelgeSayisi = 0;
  int _toplamDosyaBoyutu = 0;
  int _senkronizeBelgeSayisi = 0;
  int _bekleyenBelgeSayisi = 0;

  // Search and filter state
  String _searchQuery = '';
  KategoriModeli? _selectedKategori;
  KisiModeli? _selectedKisi;
  List<BelgeModeli> _filteredBelgeler = [];

  // Network and sync state
  bool _isOnline = true;
  bool _syncInProgress = false;
  String _syncStatus = 'Hazır';

  // Getters
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;

  List<BelgeModeli> get belgeler => List.unmodifiable(_belgeler);
  List<KisiModeli> get kisiler => List.unmodifiable(_kisiler);
  List<KategoriModeli> get kategoriler => List.unmodifiable(_kategoriler);

  int get toplamBelgeSayisi => _toplamBelgeSayisi;
  int get toplamDosyaBoyutu => _toplamDosyaBoyutu;
  int get senkronizeBelgeSayisi => _senkronizeBelgeSayisi;
  int get bekleyenBelgeSayisi => _bekleyenBelgeSayisi;

  String get searchQuery => _searchQuery;
  KategoriModeli? get selectedKategori => _selectedKategori;
  KisiModeli? get selectedKisi => _selectedKisi;
  List<BelgeModeli> get filteredBelgeler =>
      List.unmodifiable(_filteredBelgeler);

  bool get isOnline => _isOnline;
  bool get syncInProgress => _syncInProgress;
  String get syncStatus => _syncStatus;

  /// App state manager'ı başlat
  Future<void> init() async {
    if (_initialized) return;

    try {
      _setLoading(true);
      _logServisi.info('🔄 AppStateManager başlatılıyor...');

      // Load initial data
      await _loadAllData();

      _initialized = true;
      _setError(null);
      _logServisi.info('✅ AppStateManager başarıyla başlatıldı');
    } catch (e, stackTrace) {
      _setError('Uygulama başlatılırken hata oluştu: $e');
      _errorHandler.handleError(e, stackTrace, 'AppStateManager.init()');
    } finally {
      _setLoading(false);
    }
  }

  /// Tüm verileri yükle
  Future<void> _loadAllData() async {
    await Future.wait([loadBelgeler(), loadKisiler(), loadKategoriler()]);

    _calculateStatistics();
    _applyFilters();
  }

  /// Belgeleri yükle
  Future<void> loadBelgeler() async {
    try {
      _belgeler = await _veriTabani.belgeleriGetir();
      _logServisi.info('📄 ${_belgeler.length} belge yüklendi');
      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'loadBelgeler',
        'belgeler',
      );
      rethrow;
    }
  }

  /// Kişileri yükle
  Future<void> loadKisiler() async {
    try {
      _kisiler = await _veriTabani.kisileriGetir();
      _logServisi.info('👤 ${_kisiler.length} kişi yüklendi');
      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'loadKisiler',
        'kisiler',
      );
      rethrow;
    }
  }

  /// Kategorileri yükle
  Future<void> loadKategoriler() async {
    try {
      _kategoriler = await _veriTabani.kategorileriGetir();

      // Eğer hiç kategori yoksa varsayılanları ekle
      if (_kategoriler.isEmpty) {
        await _addDefaultKategoriler();
      }

      _logServisi.info('📁 ${_kategoriler.length} kategori yüklendi');
      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'loadKategoriler',
        'kategoriler',
      );
      rethrow;
    }
  }

  /// Varsayılan kategorileri ekle
  Future<void> _addDefaultKategoriler() async {
    try {
      final defaultKategoriler = KategoriModeli.ontanimliKategoriler();

      for (final kategori in defaultKategoriler) {
        await _veriTabani.kategoriEkle(kategori);
      }

      _kategoriler = await _veriTabani.kategorileriGetir();
      _logServisi.info(
        '📁 ${defaultKategoriler.length} varsayılan kategori eklendi',
      );
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        '_addDefaultKategoriler',
        'kategoriler',
      );
    }
  }

  /// İstatistikleri hesapla
  void _calculateStatistics() {
    _toplamBelgeSayisi = _belgeler.length;
    _toplamDosyaBoyutu = _belgeler.fold(
      0,
      (sum, belge) => sum + belge.dosyaBoyutu,
    );

    _senkronizeBelgeSayisi =
        _belgeler
            .where((belge) => belge.senkronDurumu == SenkronDurumu.SENKRONIZE)
            .length;

    _bekleyenBelgeSayisi =
        _belgeler
            .where(
              (belge) =>
                  belge.senkronDurumu == SenkronDurumu.BEKLEMEDE ||
                  belge.senkronDurumu == SenkronDurumu.YEREL_DEGISIM,
            )
            .length;
  }

  /// Belge ekle
  Future<bool> addBelge(BelgeModeli belge) async {
    try {
      _setLoading(true);

      await _veriTabani.belgeEkle(belge);
      _belgeler.add(belge);

      _calculateStatistics();
      _applyFilters();

      _logServisi.info('📄 Yeni belge eklendi: ${belge.dosyaAdi}');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(e, stackTrace, 'addBelge', 'belgeler');
      _setError('Belge eklenirken hata oluştu: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Belge güncelle
  Future<bool> updateBelge(BelgeModeli belge) async {
    try {
      _setLoading(true);

      await _veriTabani.belgeGuncelle(belge);

      final index = _belgeler.indexWhere((b) => b.id == belge.id);
      if (index != -1) {
        _belgeler[index] = belge;
      }

      _calculateStatistics();
      _applyFilters();

      _logServisi.info('📄 Belge güncellendi: ${belge.dosyaAdi}');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'updateBelge',
        'belgeler',
      );
      _setError('Belge güncellenirken hata oluştu: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Belge sil
  Future<bool> deleteBelge(int belgeId) async {
    try {
      _setLoading(true);

      await _veriTabani.belgeSil(belgeId);
      _belgeler.removeWhere((belge) => belge.id == belgeId);

      _calculateStatistics();
      _applyFilters();

      _logServisi.info('📄 Belge silindi: ID $belgeId');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'deleteBelge',
        'belgeler',
      );
      _setError('Belge silinirken hata oluştu: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Kişi ekle
  Future<bool> addKisi(KisiModeli kisi) async {
    try {
      _setLoading(true);

      await _veriTabani.kisiEkle(kisi);
      _kisiler.add(kisi);

      _logServisi.info('👤 Yeni kişi eklendi: ${kisi.tamAd}');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(e, stackTrace, 'addKisi', 'kisiler');
      _setError('Kişi eklenirken hata oluştu: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Kategori ekle
  Future<bool> addKategori(KategoriModeli kategori) async {
    try {
      _setLoading(true);

      await _veriTabani.kategoriEkle(kategori);
      _kategoriler.add(kategori);

      _logServisi.info('📁 Yeni kategori eklendi: ${kategori.kategoriAdi}');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'addKategori',
        'kategoriler',
      );
      _setError('Kategori eklenirken hata oluştu: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Search query ayarla
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Kategori filtresi ayarla
  void setKategoriFilter(KategoriModeli? kategori) {
    _selectedKategori = kategori;
    _applyFilters();
    notifyListeners();
  }

  /// Kişi filtresi ayarla
  void setKisiFilter(KisiModeli? kisi) {
    _selectedKisi = kisi;
    _applyFilters();
    notifyListeners();
  }

  /// Filtreleri temizle
  void clearFilters() {
    _searchQuery = '';
    _selectedKategori = null;
    _selectedKisi = null;
    _applyFilters();
    notifyListeners();
  }

  /// Filtreleri uygula
  void _applyFilters() {
    _filteredBelgeler =
        _belgeler.where((belge) {
          // Search query filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            if (!belge.dosyaAdi.toLowerCase().contains(query) &&
                !(belge.baslik?.toLowerCase().contains(query) ?? false) &&
                !(belge.aciklama?.toLowerCase().contains(query) ?? false)) {
              return false;
            }
          }

          // Kategori filter
          if (_selectedKategori != null &&
              belge.kategoriId != _selectedKategori!.id) {
            return false;
          }

          // Kişi filter
          if (_selectedKisi != null && belge.kisiId != _selectedKisi!.id) {
            return false;
          }

          return true;
        }).toList();
  }

  /// Network durumu güncelle
  void updateNetworkStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _logServisi.info(
        '🌐 Network durumu: ${isOnline ? "Çevrimiçi" : "Çevrimdışı"}',
      );
      notifyListeners();
    }
  }

  /// Sync durumu güncelle
  void updateSyncStatus(bool inProgress, String status) {
    if (_syncInProgress != inProgress || _syncStatus != status) {
      _syncInProgress = inProgress;
      _syncStatus = status;
      _logServisi.info('🔄 Sync durumu: $status');
      notifyListeners();
    }
  }

  /// Tüm verileri yenile
  Future<void> refreshAllData() async {
    try {
      _setLoading(true);
      await _loadAllData();
      _setError(null);
      _logServisi.info('🔄 Tüm veriler yenilendi');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'refreshAllData');
      _setError('Veriler yenilenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Loading durumu ayarla
  void _setLoading(bool loading) {
    if (_loading != loading) {
      _loading = loading;
      notifyListeners();
    }
  }

  /// Error durumu ayarla
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Error'u temizle
  void clearError() {
    _setError(null);
  }

  /// Uygulama durumu istatistikleri
  Map<String, dynamic> getAppStats() {
    return {
      'initialized': _initialized,
      'loading': _loading,
      'total_documents': _toplamBelgeSayisi,
      'total_file_size': _toplamDosyaBoyutu,
      'synced_documents': _senkronizeBelgeSayisi,
      'pending_documents': _bekleyenBelgeSayisi,
      'total_people': _kisiler.length,
      'total_categories': _kategoriler.length,
      'filtered_documents': _filteredBelgeler.length,
      'has_active_filters':
          _searchQuery.isNotEmpty ||
          _selectedKategori != null ||
          _selectedKisi != null,
      'is_online': _isOnline,
      'sync_in_progress': _syncInProgress,
      'sync_status': _syncStatus,
    };
  }

  @override
  void dispose() {
    _logServisi.info('🔄 AppStateManager dispose edildi');
    super.dispose();
  }
}
