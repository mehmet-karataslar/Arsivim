import 'package:flutter/foundation.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';
import '../models/kategori_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/log_servisi.dart';
import '../services/error_handler_servisi.dart';
import '../services/cache_servisi.dart';

/// Ana uygulama state manager'ı
class AppStateManager extends ChangeNotifier {
  // Services
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;
  final CacheServisi _cacheServisi = CacheServisi();

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
      // Önce cache'ten dene
      final cachedBelgeler = await _cacheServisi.cachedBelgeleriGetir();

      if (cachedBelgeler != null) {
        _belgeler = cachedBelgeler;
        _logServisi.info('⚡ ${_belgeler.length} belge cache\'ten yüklendi');
      } else {
        // Cache'te yoksa veritabanından yükle
      _belgeler = await _veriTabani.belgeleriGetir();
        _logServisi.info(
          '💽 ${_belgeler.length} belge veritabanından yüklendi',
        );

        // Cache'e kaydet
        await _cacheServisi.belgeleriCacheEt(_belgeler);
      }

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
    // Minimum karakter kontrolü
    if (_searchQuery.isNotEmpty && _searchQuery.trim().length < 1) {
      _filteredBelgeler = List.from(_belgeler);
      return;
    }

    final aramaKelimesi = _searchQuery.toLowerCase().trim();
    final aramaSozcukleri =
        aramaKelimesi.split(' ').where((s) => s.isNotEmpty).toList();

    if (_searchQuery.isNotEmpty) {
      // Arama sonuçlarını puanlama sistemi ile sıralama
      final aramaSonuclari = <Map<String, dynamic>>[];

      for (final belge in _belgeler) {
        final puan = _belgeAramaPuani(belge, aramaKelimesi, aramaSozcukleri);
        if (puan > 0) {
          aramaSonuclari.add({'belge': belge, 'puan': puan});
        }
      }

      // Puana göre sıralama (yüksek puan önce)
      aramaSonuclari.sort((a, b) => b['puan'].compareTo(a['puan']));

      _filteredBelgeler =
          aramaSonuclari.map((item) => item['belge'] as BelgeModeli).toList();
    } else {
      _filteredBelgeler = List.from(_belgeler);
    }

    // Kategori filtresi
    if (_selectedKategori != null) {
      _filteredBelgeler =
          _filteredBelgeler
              .where((belge) => belge.tumKategoriIds.contains(_selectedKategori!.id))
              .toList();
    }

    // Kişi filtresi
    if (_selectedKisi != null) {
    _filteredBelgeler =
          _filteredBelgeler
              .where((belge) => belge.tumKisiIds.contains(_selectedKisi!.id))
              .toList();
    }
  }

  // Gelişmiş arama puanlama sistemi
  int _belgeAramaPuani(
    BelgeModeli belge,
    String aramaKelimesi,
    List<String> aramaSozcukleri,
  ) {
    int puan = 0;

    // Arama metinlerini hazırla
    final dosyaAdi = belge.dosyaAdi.toLowerCase();
    final baslik = (belge.baslik ?? '').toLowerCase();
    final aciklama = (belge.aciklama ?? '').toLowerCase();
    final etiketler = (belge.etiketler ?? [])
        .map((e) => e.toLowerCase())
        .join(' ');

    // 1. TAM METIN EŞLEŞMESİ (en yüksek puan)
    if (dosyaAdi == aramaKelimesi) puan += 1000;
    if (baslik == aramaKelimesi) puan += 900;
    if (aciklama == aramaKelimesi) puan += 800;

    // 2. TAM KELIME EŞLEŞMESİ (yüksek puan)
    final tamKelimePuani =
        _tamKelimeAramaPuani(aramaKelimesi, aramaSozcukleri, {
          'dosyaAdi': dosyaAdi,
          'baslik': baslik,
          'aciklama': aciklama,
          'etiketler': etiketler,
        });
    puan += tamKelimePuani;

    // 3. BAŞLANGIC EŞLEŞMESİ (orta puan)
    if (dosyaAdi.startsWith(aramaKelimesi)) puan += 300;
    if (baslik.startsWith(aramaKelimesi)) puan += 250;
    if (aciklama.startsWith(aramaKelimesi)) puan += 200;

    // 4. IÇERIK EŞLEŞMESİ (düşük puan)
    if (dosyaAdi.contains(aramaKelimesi)) puan += 50;
    if (baslik.contains(aramaKelimesi)) puan += 40;
    if (aciklama.contains(aramaKelimesi)) puan += 30;
    if (etiketler.contains(aramaKelimesi)) puan += 25;

    // 5. FUZZY SEARCH (çok düşük puan)
    puan += _fuzzySearchPuani(aramaKelimesi, dosyaAdi, 10);
    puan += _fuzzySearchPuani(aramaKelimesi, baslik, 8);
    puan += _fuzzySearchPuani(aramaKelimesi, aciklama, 6);

    return puan;
  }

  // Tam kelime arama puanlama sistemi
  int _tamKelimeAramaPuani(
    String aramaKelimesi,
    List<String> aramaSozcukleri,
    Map<String, String> alanlar,
  ) {
    int puan = 0;

    // Tek kelime tam eşleşme
    for (final alan in alanlar.entries) {
      final alanDegeri = alan.value;
      final kelimeler =
          alanDegeri
              .split(RegExp(r'[^a-zA-ZçğıöşüÇĞIİÖŞÜ0-9]+'))
              .where((s) => s.isNotEmpty)
              .toList();

      for (final kelime in kelimeler) {
        if (kelime == aramaKelimesi) {
          switch (alan.key) {
            case 'dosyaAdi':
              puan += 500;
              break;
            case 'baslik':
              puan += 450;
              break;
            case 'aciklama':
              puan += 400;
              break;
            case 'etiketler':
              puan += 350;
              break;
          }
        }
      }
    }

    // Çoklu kelime araması (cümle araması)
    if (aramaSozcukleri.length > 1) {
      for (final alan in alanlar.entries) {
        final alanDegeri = alan.value;
        int eslesen = 0;

        for (final sozcuk in aramaSozcukleri) {
          if (sozcuk.length >= 1) {
            // Minimum 1 karakter
            final alanKelimeler =
                alanDegeri
                    .split(RegExp(r'[^a-zA-ZçğıöşüÇĞIİÖŞÜ0-9]+'))
                    .where((s) => s.isNotEmpty)
                    .toList();

            // Tam kelime eşleşmesi
            if (alanKelimeler.any((k) => k == sozcuk)) {
              eslesen += 3;
            }
            // Başlangıç eşleşmesi
            else if (alanKelimeler.any((k) => k.startsWith(sozcuk))) {
              eslesen += 2;
            }
            // İçerik eşleşmesi
            else if (alanDegeri.contains(sozcuk)) {
              eslesen += 1;
            }
          }
        }

        // Eşleşen kelime sayısına göre puan ver
        if (eslesen > 0) {
          final cokluKelimeBonusu = (eslesen * 100) ~/ aramaSozcukleri.length;
          switch (alan.key) {
            case 'dosyaAdi':
              puan += cokluKelimeBonusu;
              break;
            case 'baslik':
              puan += (cokluKelimeBonusu * 0.9).round();
              break;
            case 'aciklama':
              puan += (cokluKelimeBonusu * 0.8).round();
              break;
            case 'etiketler':
              puan += (cokluKelimeBonusu * 0.7).round();
              break;
          }
        }
      }
    }

    return puan;
  }

  // Fuzzy search algoritması (Levenshtein distance)
  int _fuzzySearchPuani(String aranan, String hedef, int maxPuan) {
    if (aranan.isEmpty || hedef.isEmpty) return 0;
    if (aranan.length < 3)
      return 0; // Çok kısa kelimeler için fuzzy search yapma

    final mesafe = _levenshteinDistance(aranan, hedef);
    final maxMesafe = (aranan.length * 0.4).round(); // %40 hata toleransı

    if (mesafe <= maxMesafe) {
      final benzerlikOrani = 1.0 - (mesafe / aranan.length);
      return (maxPuan * benzerlikOrani).round();
    }

    return 0;
  }

  // Levenshtein distance hesaplama
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // silme
          matrix[i][j - 1] + 1, // ekleme
          matrix[i - 1][j - 1] + cost, // değiştirme
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
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
      'cache_stats': _cacheServisi.getCacheStats(),
    };
  }

  @override
  void dispose() {
    _logServisi.info('🔄 AppStateManager dispose edildi');

    // Cache servisi'ni dispose et
    _cacheServisi.dispose().catchError((error) {
      _logServisi.error('❌ Cache servisi dispose hatası: $error');
    });

    super.dispose();
  }
}
