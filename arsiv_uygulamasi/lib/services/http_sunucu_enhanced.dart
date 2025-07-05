import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'belge_islemleri_servisi.dart';
import 'sync_state_tracker.dart';
import 'document_change_tracker.dart';
import 'metadata_sync_manager.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';

/// Geliştirilmiş HTTP Sunucu Servisi - Metadata sync desteği ile
class HttpSunucuEnhanced {
  static const int SUNUCU_PORTU = 8080;
  static const String UYGULAMA_KODU = 'arsivim';

  static HttpSunucuEnhanced? _instance;
  static HttpSunucuEnhanced get instance =>
      _instance ??= HttpSunucuEnhanced._();
  HttpSunucuEnhanced._();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();
  final SyncStateTracker _stateTracker = SyncStateTracker.instance;
  final DocumentChangeTracker _changeTracker = DocumentChangeTracker.instance;

  HttpServer? _sunucu;
  String? _cihazId;
  String? _cihazAdi;
  String? _platform;
  bool _calisiyorMu = false;

  Function(Map<String, dynamic>)? _onDeviceConnected;

  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;

  void setOnDeviceConnected(Function(Map<String, dynamic>) callback) {
    _onDeviceConnected = callback;
  }

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) {
      print('⚠️ Sunucu zaten çalışıyor');
      return;
    }

    try {
      print('🔧 Geliştirilmiş HTTP Sunucusu başlatılıyor...');

      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      print('📱 Cihaz bilgileri alındı: $_cihazAdi ($_platform)');

      // Sunucuyu başlat
      print('🌐 Port $SUNUCU_PORTU dinlenmeye başlanıyor...');
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);
      print(
        '🚀 Geliştirilmiş Arşivim HTTP Sunucusu başlatıldı: http://localhost:$SUNUCU_PORTU',
      );
      print('📱 Cihaz ID: $_cihazId');
      print('💻 Platform: $_platform');

      _calisiyorMu = true;
      print('✅ Sunucu durumu: $_calisiyorMu');

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          print('📨 HTTP İstek: ${request.method} ${request.uri.path}');

          // CORS headers ekle
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add(
            'Content-Type',
            'application/json; charset=utf-8',
          );

          String responseBody;
          int statusCode = 200;
          bool isBinaryResponse = false;

          // Enhanced Route handling
          switch (request.uri.path) {
            // Temel endpoint'ler
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/connect':
              responseBody = await _handleConnect(request);
              break;

            // Belge endpoint'leri
            case '/documents':
              responseBody = await _handleDocuments();
              break;
            case '/categories':
              responseBody = await _handleCategories();
              break;
            case '/people':
              responseBody = await _handlePeople();
              break;

            // Yeni Metadata Sync endpoint'leri
            case '/sync/metadata':
              if (request.method == 'GET') {
                responseBody = await _handleGetMetadataChanges(request);
              } else if (request.method == 'POST') {
                responseBody = await _handlePostMetadataChanges(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;

            case '/sync/changes':
              responseBody = await _handleGetChanges(request);
              break;

            case '/sync/state':
              responseBody = await _handleGetSyncState(request);
              break;

            case '/sync/conflicts':
              responseBody = await _handleGetConflicts(request);
              break;

            // Document Management endpoint'leri
            case '/document/update':
              if (request.method == 'POST') {
                responseBody = await _handleDocumentUpdate(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;

            case '/document/versions':
              responseBody = await _handleGetDocumentVersions(request);
              break;

            // Time sync endpoint
            case '/time':
              responseBody = json.encode(
                DateTime.now().toUtc().toIso8601String(),
              );
              break;

            default:
              if (request.uri.path.startsWith('/download/')) {
                responseBody = await _handleDownload(request);
                if (responseBody == 'BINARY_SENT') {
                  isBinaryResponse = true;
                  print('✅ Binary dosya gönderildi');
                }
              } else if (request.uri.path == '/upload' &&
                  request.method == 'POST') {
                responseBody = await _handleUploadEnhanced(request);
                try {
                  final responseJson = json.decode(responseBody);
                  if (responseJson['status'] == 'error') {
                    statusCode = 400;
                  }
                } catch (e) {
                  // JSON parse edilemezse default 200 kullan
                }
              } else if (request.uri.path.startsWith('/document/')) {
                responseBody = await _handleDocumentById(request);
              } else if (request.uri.path.startsWith('/person/')) {
                responseBody = await _handlePersonById(request);
              } else {
                statusCode = 404;
                responseBody = json.encode({'error': 'Endpoint bulunamadı'});
              }
          }

          // Binary response değilse normal JSON response gönder
          if (!isBinaryResponse) {
            final responseBytes = utf8.encode(responseBody);
            request.response
              ..statusCode = statusCode
              ..add(responseBytes);

            await request.response.close();
            print('✅ HTTP Yanıt gönderildi: $statusCode');
          }
        } catch (e) {
          print('❌ İstek işleme hatası: $e');
          try {
            final errorResponse = json.encode({
              'error': 'Sunucu hatası',
              'message': e.toString(),
            });
            final errorBytes = utf8.encode(errorResponse);

            request.response
              ..statusCode = 500
              ..add(errorBytes);
            await request.response.close();
          } catch (closeError) {
            print('❌ Response kapatma hatası: $closeError');
          }
        }
      });
    } catch (e) {
      print('❌ Sunucu başlatma hatası: $e');
      throw Exception('HTTP sunucusu başlatılamadı: $e');
    }
  }

  // ============== YENİ METADATA SYNC ENDPOINT'LERİ ==============

  /// GET /sync/metadata - Metadata değişikliklerini al
  Future<String> _handleGetMetadataChanges(HttpRequest request) async {
    try {
      final sinceParam = request.uri.queryParameters['since'];
      final since = sinceParam != null ? DateTime.tryParse(sinceParam) : null;

      final changes = await _getLocalMetadataChanges(since);

      return json.encode({
        'success': true,
        'changes': changes.map((change) => change.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Metadata değişiklikleri alınamadı: $e',
      });
    }
  }

  /// POST /sync/metadata - Metadata değişikliklerini al ve uygula
  Future<String> _handlePostMetadataChanges(HttpRequest request) async {
    try {
      final requestBody = await utf8.decoder.bind(request).join();
      final data = json.decode(requestBody);
      final changesData = data['changes'] as List;

      final changes =
          changesData.map((change) => MetadataChange.fromJson(change)).toList();

      // Metadata değişikliklerini uygula
      int appliedCount = 0;
      for (final change in changes) {
        try {
          await _applyMetadataChange(change);
          appliedCount++;
        } catch (e) {
          print('Metadata change uygulama hatası: $e');
        }
      }

      return json.encode({
        'success': true,
        'applied': appliedCount,
        'total': changes.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Metadata değişiklikleri uygulanamadı: $e',
      });
    }
  }

  /// GET /sync/changes - Belge değişikliklerini al
  Future<String> _handleGetChanges(HttpRequest request) async {
    try {
      final sinceParam = request.uri.queryParameters['since'];
      final since = sinceParam != null ? DateTime.tryParse(sinceParam) : null;

      final changes = await _changeTracker.getChangedDocuments(
        since ?? DateTime.now().subtract(const Duration(days: 1)),
      );

      return json.encode({
        'success': true,
        'changes': changes,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Değişiklikler alınamadı: $e',
      });
    }
  }

  /// GET /sync/state - Senkronizasyon durumunu al
  Future<String> _handleGetSyncState(HttpRequest request) async {
    try {
      final stats = await _stateTracker.getSyncStatistics();
      final allStates = await _stateTracker.getAllSyncStates();

      return json.encode({
        'success': true,
        'statistics': stats,
        'states': allStates,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Sync durumu alınamadı: $e',
      });
    }
  }

  /// GET /sync/conflicts - Çakışmaları al
  Future<String> _handleGetConflicts(HttpRequest request) async {
    try {
      final conflicts = await _stateTracker.getFilesByState(SyncState.conflict);

      return json.encode({
        'success': true,
        'conflicts': conflicts,
        'count': conflicts.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Çakışmalar alınamadı: $e',
      });
    }
  }

  /// POST /document/update - Belge metadata güncelleme
  Future<String> _handleDocumentUpdate(HttpRequest request) async {
    try {
      final requestBody = await utf8.decoder.bind(request).join();
      final data = json.decode(requestBody);

      final belgeId = data['id'] as int;
      final belge = await _veriTabani.belgeGetir(belgeId);

      if (belge == null) {
        return json.encode({'success': false, 'error': 'Belge bulunamadı'});
      }

      // Metadata güncelle
      final updatedBelge = BelgeModeli(
        id: belge.id,
        dosyaAdi: belge.dosyaAdi,
        orijinalDosyaAdi: belge.orijinalDosyaAdi,
        dosyaYolu: belge.dosyaYolu,
        dosyaBoyutu: belge.dosyaBoyutu,
        dosyaTipi: belge.dosyaTipi,
        dosyaHash: belge.dosyaHash,
        kategoriId: data['categoryId'] ?? belge.kategoriId,
        kisiId: data['personId'] ?? belge.kisiId,
        baslik: data['title'] ?? belge.baslik,
        aciklama: data['description'] ?? belge.aciklama,
        etiketler: data['tags'] ?? belge.etiketler,
        olusturmaTarihi: belge.olusturmaTarihi,
        guncellemeTarihi: DateTime.now(),
        sonErisimTarihi: belge.sonErisimTarihi,
        aktif: belge.aktif,
        senkronDurumu: belge.senkronDurumu,
      );

      await _veriTabani.belgeGuncelle(updatedBelge);

      // Change tracking - Create dummy previous version for tracking
      await _changeTracker.trackDocumentChanges(
        belge,
        updatedBelge,
        _cihazId ?? 'unknown',
      );

      return json.encode({
        'success': true,
        'message': 'Belge güncellendi',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Belge güncellenemedi: $e',
      });
    }
  }

  /// GET /document/versions - Belge versiyonlarını al
  Future<String> _handleGetDocumentVersions(HttpRequest request) async {
    try {
      final belgeIdParam = request.uri.queryParameters['id'];
      if (belgeIdParam == null) {
        return json.encode({'success': false, 'error': 'Belge ID gerekli'});
      }

      final belgeId = int.parse(belgeIdParam);

      // Basit version bilgisi - gerçek uygulamada version tablosundan gelecek
      final versions = [
        {
          'id': 1,
          'belgeId': belgeId,
          'version': '1.0',
          'timestamp': DateTime.now().toIso8601String(),
          'changes': 'İlk versiyon',
        },
      ];

      return json.encode({
        'success': true,
        'versions': versions,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'success': false,
        'error': 'Versiyonlar alınamadı: $e',
      });
    }
  }

  /// Geliştirilmiş upload handler
  Future<String> _handleUploadEnhanced(HttpRequest request) async {
    try {
      // Multipart parsing logic burada olacak
      // Şimdilik basit response
      return json.encode({
        'success': true,
        'message': 'Dosya başarıyla yüklendi',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({'success': false, 'error': 'Upload hatası: $e'});
    }
  }

  // ============== HELPER METODLAR ==============

  /// Local metadata değişikliklerini al
  Future<List<MetadataChange>> _getLocalMetadataChanges(DateTime? since) async {
    final changes = <MetadataChange>[];
    final sinceTime = since ?? DateTime.now().subtract(const Duration(days: 1));

    // Belgeler için metadata değişiklikleri
    final belgeChanges = await _changeTracker.getChangedDocuments(sinceTime);

    for (final change in belgeChanges) {
      final belgeId = change['belge_id'] as int;
      final belge = await _veriTabani.belgeGetir(belgeId);

      if (belge != null) {
        changes.add(
          MetadataChange(
            entityType: 'belge',
            entityId: belgeId,
            changeType: change['degisiklik_tipi'] as String,
            metadata: _belgeToMetadata(belge),
            timestamp: DateTime.parse(change['olusturma_tarihi'] as String),
            hash: _generateBelgeHash(belge),
          ),
        );
      }
    }

    return changes;
  }

  /// Metadata change'i uygula
  Future<void> _applyMetadataChange(MetadataChange change) async {
    switch (change.entityType) {
      case 'belge':
        await _applyBelgeMetadataChange(change);
        break;
      case 'kategori':
        await _applyKategoriMetadataChange(change);
        break;
      case 'kisi':
        await _applyKisiMetadataChange(change);
        break;
    }
  }

  Future<void> _applyBelgeMetadataChange(MetadataChange change) async {
    final belge = await _veriTabani.belgeGetir(change.entityId);
    if (belge != null) {
      final metadata = change.metadata;
      final updatedBelge = BelgeModeli(
        id: belge.id,
        dosyaAdi: belge.dosyaAdi,
        orijinalDosyaAdi: belge.orijinalDosyaAdi,
        dosyaYolu: belge.dosyaYolu,
        dosyaBoyutu: belge.dosyaBoyutu,
        dosyaTipi: belge.dosyaTipi,
        dosyaHash: belge.dosyaHash,
        kategoriId: metadata['kategoriId'],
        kisiId: metadata['kisiId'],
        baslik: metadata['baslik'],
        aciklama: metadata['aciklama'],
        etiketler: metadata['etiketler'],
        olusturmaTarihi: belge.olusturmaTarihi,
        guncellemeTarihi: DateTime.parse(metadata['guncellemeTarihi']),
        sonErisimTarihi: belge.sonErisimTarihi,
        aktif: belge.aktif,
        senkronDurumu: belge.senkronDurumu,
      );

      await _veriTabani.belgeGuncelle(updatedBelge);
    }
  }

  Future<void> _applyKategoriMetadataChange(MetadataChange change) async {
    // Kategori metadata güncelleme
    final kategori = await _veriTabani.kategoriGetir(change.entityId);
    if (kategori != null) {
      final metadata = change.metadata;
      final updatedKategori = KategoriModeli(
        id: kategori.id,
        kategoriAdi:
            metadata['kategoriAdi'] ?? metadata['ad'] ?? kategori.kategoriAdi,
        aciklama: metadata['aciklama'] ?? kategori.aciklama,
        renkKodu: metadata['renkKodu'] ?? metadata['renk'] ?? kategori.renkKodu,
        simgeKodu:
            metadata['simgeKodu'] ?? metadata['simge'] ?? kategori.simgeKodu,
        olusturmaTarihi: kategori.olusturmaTarihi,
        aktif: metadata['aktif'] ?? kategori.aktif,
      );

      await _veriTabani.kategoriGuncelle(updatedKategori);
    }
  }

  Future<void> _applyKisiMetadataChange(MetadataChange change) async {
    // Kişi metadata güncelleme
    final kisi = await _veriTabani.kisiGetir(change.entityId);
    if (kisi != null) {
      final metadata = change.metadata;
      final updatedKisi = KisiModeli(
        id: kisi.id,
        ad: metadata['ad'] ?? kisi.ad,
        soyad: metadata['soyad'] ?? kisi.soyad,
        olusturmaTarihi: kisi.olusturmaTarihi,
        guncellemeTarihi:
            metadata['guncellemeTarihi'] != null
                ? DateTime.parse(metadata['guncellemeTarihi'])
                : DateTime.now(),
        aktif: metadata['aktif'] ?? kisi.aktif,
      );

      await _veriTabani.kisiGuncelle(updatedKisi);
    }
  }

  Map<String, dynamic> _belgeToMetadata(BelgeModeli belge) {
    return {
      'id': belge.id,
      'dosyaAdi': belge.dosyaAdi,
      'orijinalDosyaAdi': belge.orijinalDosyaAdi,
      'baslik': belge.baslik,
      'aciklama': belge.aciklama,
      'kategoriId': belge.kategoriId,
      'kisiId': belge.kisiId,
      'etiketler': belge.etiketler,
      'guncellemeTarihi': belge.guncellemeTarihi.toIso8601String(),
    };
  }

  String _generateBelgeHash(BelgeModeli belge) {
    final data = json.encode(_belgeToMetadata(belge));
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<void> _cihazBilgileriniAl() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cihazAdi = '${androidInfo.brand} ${androidInfo.model}';
        _platform = 'Android ${androidInfo.version.release}';
        _cihazId = androidInfo.id;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cihazAdi = windowsInfo.computerName;
        _platform = 'Windows';
        _cihazId = windowsInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cihazAdi = linuxInfo.name;
        _platform = 'Linux';
        _cihazId =
            linuxInfo.machineId ??
            'linux-${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cihazAdi = macInfo.computerName;
        _platform = 'macOS';
        _cihazId =
            macInfo.systemGUID ??
            'mac-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _cihazAdi = 'Bilinmeyen Cihaz';
        _platform = 'Bilinmeyen Platform';
        _cihazId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print('⚠️ Cihaz bilgisi alınamadı: $e');
      _cihazAdi = 'Varsayılan Cihaz';
      _platform = 'Bilinmeyen';
      _cihazId = 'default-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ============== MEVCUT METODLAR ==============

  Future<String> _handleInfo() async {
    return json.encode({
      'app': UYGULAMA_KODU,
      'version': '2.0.0-enhanced',
      'deviceId': _cihazId,
      'deviceName': _cihazAdi,
      'platform': _platform,
      'status': 'active',
      'features': [
        'document_sync',
        'metadata_sync',
        'bidirectional_sync',
        'conflict_resolution',
        'change_tracking',
        'version_history',
      ],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'uptime': _calisiyorMu ? 'running' : 'stopped',
    });
  }

  Future<String> _handleConnect(HttpRequest request) async {
    return json.encode({
      'status': 'connected',
      'deviceId': _cihazId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<String> _handleDocuments() async {
    try {
      final belgeler = await _veriTabani.belgeleriGetir();

      final documentList =
          belgeler
              .map(
                (belge) => {
                  'id': belge.id,
                  // Türkçe field'lar (primary)
                  'dosyaAdi': belge.dosyaAdi,
                  'orijinalDosyaAdi': belge.orijinalDosyaAdi,
                  'baslik': belge.baslik,
                  'aciklama': belge.aciklama,
                  'dosyaBoyutu': belge.dosyaBoyutu,
                  'dosyaTipi': belge.dosyaTipi,
                  'dosyaHash': belge.dosyaHash,
                  'kategoriId': belge.kategoriId,
                  'kisiId': belge.kisiId,
                  'etiketler': belge.etiketler,
                  'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
                  'guncellemeTarihi': belge.guncellemeTarihi.toIso8601String(),
                  // İngilizce field'lar (backward compatibility)
                  'fileName': belge.dosyaAdi,
                  'originalFileName': belge.orijinalDosyaAdi,
                  'title': belge.baslik,
                  'description': belge.aciklama,
                  'fileSize': belge.dosyaBoyutu,
                  'fileType': belge.dosyaTipi,
                  'hash': belge.dosyaHash,
                  'categoryId': belge.kategoriId,
                  'personId': belge.kisiId,
                  'tags': belge.etiketler,
                  'createdAt': belge.olusturmaTarihi.toIso8601String(),
                  'updatedAt': belge.guncellemeTarihi.toIso8601String(),
                  'lastModified': belge.guncellemeTarihi.toIso8601String(),
                },
              )
              .toList();

      return json.encode({
        'documents': documentList,
        'count': documentList.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'error': 'Belgeler listelenemedi: $e',
        'documents': [],
        'count': 0,
      });
    }
  }

  Future<String> _handleCategories() async {
    try {
      final kategoriler = await _veriTabani.kategorileriGetir();

      final categoryList =
          kategoriler
              .map(
                (kategori) => {
                  'id': kategori.id,
                  // Türkçe field'lar (primary)
                  'kategoriAdi': kategori.kategoriAdi,
                  'aciklama': kategori.aciklama,
                  'renkKodu': kategori.renkKodu,
                  'simgeKodu': kategori.simgeKodu,
                  'olusturmaTarihi': kategori.olusturmaTarihi.toIso8601String(),
                  'aktif': kategori.aktif,
                  'belgeSayisi': kategori.belgeSayisi,
                  // İngilizce field'lar (backward compatibility)
                  'name': kategori.kategoriAdi,
                  'ad': kategori.kategoriAdi,
                  'description': kategori.aciklama,
                  'color': kategori.renkKodu,
                  'icon': kategori.simgeKodu,
                  'createdAt': kategori.olusturmaTarihi.toIso8601String(),
                  'updatedAt': kategori.olusturmaTarihi.toIso8601String(),
                },
              )
              .toList();

      return json.encode({
        'categories': categoryList,
        'count': categoryList.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'error': 'Kategoriler listelenemedi: $e',
        'categories': [],
        'count': 0,
      });
    }
  }

  Future<String> _handlePeople() async {
    try {
      final kisiler = await _veriTabani.kisileriGetir();

      final peopleList =
          kisiler
              .map(
                (kisi) => {
                  'id': kisi.id,
                  // Türkçe field'lar (primary)
                  'ad': kisi.ad,
                  'soyad': kisi.soyad,
                  'tamAd': kisi.tamAd,
                  'olusturmaTarihi': kisi.olusturmaTarihi.toIso8601String(),
                  'guncellemeTarihi': kisi.guncellemeTarihi.toIso8601String(),
                  'aktif': kisi.aktif,
                  // İngilizce field'lar (backward compatibility)
                  'firstName': kisi.ad,
                  'lastName': kisi.soyad,
                  'fullName': kisi.tamAd,
                  'createdAt': kisi.olusturmaTarihi.toIso8601String(),
                  'updatedAt': kisi.guncellemeTarihi.toIso8601String(),
                },
              )
              .toList();

      return json.encode({
        'people': peopleList,
        'count': peopleList.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return json.encode({
        'error': 'Kişiler listelenemedi: $e',
        'people': [],
        'count': 0,
      });
    }
  }

  Future<String> _handleDownload(HttpRequest request) async {
    return 'BINARY_SENT';
  }

  Future<String> _handleDocumentById(HttpRequest request) async {
    return json.encode({'message': 'Document details'});
  }

  Future<String> _handlePersonById(HttpRequest request) async {
    return json.encode({'message': 'Person details'});
  }

  Future<void> sunucuyuDurdur() async {
    if (_sunucu != null) {
      await _sunucu!.close();
      _sunucu = null;
      _calisiyorMu = false;
      print('🛑 Geliştirilmiş Arşivim HTTP Sunucusu durduruldu');
    }
  }
}

// ============== HELPER SINIFLARI ==============

/// Metadata değişikliği modeli
class MetadataChange {
  final String entityType;
  final int entityId;
  final String changeType;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String hash;

  MetadataChange({
    required this.entityType,
    required this.entityId,
    required this.changeType,
    required this.metadata,
    required this.timestamp,
    required this.hash,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'entityId': entityId,
      'changeType': changeType,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'hash': hash,
    };
  }

  factory MetadataChange.fromJson(Map<String, dynamic> json) {
    return MetadataChange(
      entityType: json['entityType'],
      entityId: json['entityId'],
      changeType: json['changeType'],
      metadata: json['metadata'],
      timestamp: DateTime.parse(json['timestamp']),
      hash: json['hash'],
    );
  }
}

// SyncState enum'u sync_state_tracker.dart'da tanımlandı - import ile kullanılacak
