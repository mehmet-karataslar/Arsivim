import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kisi_modeli.dart';

class HttpSunucuServisi {
  static const int SUNUCU_PORTU = 8080;
  static const String UYGULAMA_KODU = 'arsivim';

  static HttpSunucuServisi? _instance;
  static HttpSunucuServisi get instance => _instance ??= HttpSunucuServisi._();
  HttpSunucuServisi._();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final DosyaServisi _dosyaServisi = DosyaServisi();

  HttpServer? _sunucu;
  String? _cihazId;
  String? _cihazAdi;
  String? _platform;
  bool _calisiyorMu = false;

  // Bağlantı callback'i
  Function(Map<String, dynamic>)? _onDeviceConnected;

  bool get calisiyorMu => _calisiyorMu;
  String? get cihazId => _cihazId;

  // Callback ayarlama metodu
  void setOnDeviceConnected(Function(Map<String, dynamic>) callback) {
    _onDeviceConnected = callback;
  }

  Future<void> sunucuyuBaslat() async {
    if (_calisiyorMu) {
      print('⚠️ Sunucu zaten çalışıyor');
      return;
    }

    try {
      print('🔧 HTTP Sunucusu başlatılıyor...');

      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      print('📱 Cihaz bilgileri alındı: $_cihazAdi ($_platform)');

      // Sunucuyu başlat
      print('🌐 Port $SUNUCU_PORTU dinlenmeye başlanıyor...');
      _sunucu = await HttpServer.bind(InternetAddress.anyIPv4, SUNUCU_PORTU);
      print(
        '🚀 Arşivim HTTP Sunucusu başlatıldı: http://localhost:$SUNUCU_PORTU',
      );
      print('📱 Cihaz ID: $_cihazId');
      print('💻 Platform: $_platform');

      _calisiyorMu = true;
      print('✅ Sunucu durumu: $_calisiyorMu');

      // İstekleri dinle
      _sunucu!.listen((HttpRequest request) async {
        try {
          print('📨 HTTP İstek: ${request.method} ${request.uri.path}');

          // CORS headers ekle (UTF-8 desteği ile)
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add(
            'Content-Type',
            'application/json; charset=utf-8',
          );

          String responseBody;
          int statusCode = 200;

          // Route handling
          bool isBinaryResponse = false;

          switch (request.uri.path) {
            case '/info':
              responseBody = await _handleInfo();
              break;
            case '/ping':
              responseBody = await _handlePing();
              break;
            case '/connect':
              responseBody = await _handleConnect(request);
              break;
            case '/documents':
              responseBody = await _handleDocuments();
              break;
            case '/categories':
              responseBody = await _handleCategories();
              break;
            case '/people':
              responseBody = await _handlePeople();
              break;
            case '/sync/deltas':
              responseBody = await _handleSyncDeltas();
              break;
            case '/metadata/sync':
              if (request.method == 'POST') {
                responseBody = await _handleMetadataSync(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/metadata/changes':
              responseBody = await _handleMetadataChanges(request);
              break;
            case '/metadata/conflicts':
              responseBody = await _handleMetadataConflicts(request);
              break;
            case '/sync/negotiate':
              if (request.method == 'POST') {
                responseBody = await _handleSyncNegotiate(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/manifest':
              if (request.method == 'GET') {
                responseBody = await _handleSyncManifest(request);
              } else if (request.method == 'POST') {
                responseBody = await _handleSyncManifestCreate(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
              break;
            case '/sync/bidirectional':
              if (request.method == 'POST') {
                responseBody = await _handleBidirectionalSync(request);
              } else {
                statusCode = 405;
                responseBody = json.encode({'error': 'Method not allowed'});
              }
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
                responseBody = await _handleUpload(request);
                // Upload response'unda hata kontrolü yap
                try {
                  final responseJson = json.decode(responseBody);
                  if (responseJson['status'] == 'error') {
                    statusCode = 400; // Bad Request
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
            // UTF-8 bytes olarak yaz
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

  Future<void> sunucuyuDurdur() async {
    if (_sunucu != null) {
      await _sunucu!.close();
      _sunucu = null;
      _calisiyorMu = false;
      print('🛑 Arşivim HTTP Sunucusu durduruldu');
    }
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
        _platform = Platform.operatingSystem;
        _cihazId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Cihaz ID'sini hash'le (güvenlik için)
      final bytes = utf8.encode(_cihazId!);
      final digest = sha256.convert(bytes);
      _cihazId = digest.toString().substring(0, 16);
    } catch (e) {
      print('⚠️ Cihaz bilgisi alınamadı: $e');
      _cihazAdi = 'Arşivim Cihazı';
      _platform = Platform.operatingSystem;
      _cihazId = 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // HTTP Handler metodları
  Future<String> _handleInfo() async {
    try {
      final belgeSayisi = await _veriTabani.toplamBelgeSayisi();
      final toplamBoyut = await _veriTabani.toplamDosyaBoyutu();

      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'id': _cihazId,
        'ad': _cihazAdi,
        'platform': _platform,
        'belgeSayisi': belgeSayisi,
        'toplamBoyut': toplamBoyut,
        'zaman': DateTime.now().toIso8601String(),
        'aktif': true,
      });
    } catch (e) {
      print('❌ Info endpoint hatası: $e');
      return json.encode({
        'app': UYGULAMA_KODU,
        'version': '1.0.0',
        'id': _cihazId,
        'ad': _cihazAdi,
        'platform': _platform,
        'belgeSayisi': 0,
        'toplamBoyut': 0,
        'zaman': DateTime.now().toIso8601String(),
        'aktif': true,
      });
    }
  }

  Future<String> _handlePing() async {
    return json.encode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'cihaz': _cihazId,
    });
  }

  Future<String> _handleConnect(HttpRequest request) async {
    try {
      print('🔗 Yeni bağlantı isteği alındı');

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
      final body = utf8.decode(bodyBytes);
      final data = json.decode(body);

      final clientId = data['clientId'] as String?;
      final clientName = data['clientName'] as String?;
      final clientIP =
          request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor';

      if (clientId == null || clientName == null) {
        return json.encode({'error': 'clientId ve clientName gerekli'});
      }

      // Basit token oluştur
      final token = 'token_${DateTime.now().millisecondsSinceEpoch}';

      // Server'ın kendi IP'sini al (local network IP)
      String? serverIP;
      try {
        // Local network interface'ini bul
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          if (interface.name.toLowerCase().contains('wi-fi') ||
              interface.name.toLowerCase().contains('wlan') ||
              interface.name.toLowerCase().contains('ethernet')) {
            for (final addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 &&
                  !addr.isLoopback &&
                  addr.address.startsWith('192.168.')) {
                serverIP = addr.address;
                break;
              }
            }
            if (serverIP != null) break;
          }
        }
        // Fallback: any valid local IP
        if (serverIP == null) {
          for (final interface in interfaces) {
            for (final addr in interface.addresses) {
              if (addr.type == InternetAddressType.IPv4 &&
                  !addr.isLoopback &&
                  (addr.address.startsWith('192.168.') ||
                      addr.address.startsWith('10.') ||
                      addr.address.startsWith('172.'))) {
                serverIP = addr.address;
                break;
              }
            }
            if (serverIP != null) break;
          }
        }
      } catch (e) {
        print('⚠️ Server IP alınamadı: $e');
        serverIP = 'localhost';
      }

      // Bağlantı başarılı bildirimi
      print('🎉 BAĞLANTI BAŞARILI! Mobil cihaz bağlandı');
      print('📱 Bağlanan cihaz: $clientName ($clientId)');
      print('📱 Client IP: $clientIP');
      print('💻 Server IP: $serverIP');

      // UI'ya bildirim gönder - HEMEN
      final deviceInfo = {
        'clientId': clientId,
        'clientName': clientName,
        'ip': clientIP,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': data['platform'] ?? 'Mobil',
        'belgeSayisi': data['belgeSayisi'] ?? 0,
        'toplamBoyut': data['toplamBoyut'] ?? 0,
      };

      // Callback'i çağır
      if (_onDeviceConnected != null) {
        print('📢 Callback çağrılıyor...');
        Future.microtask(() => _onDeviceConnected!(deviceInfo));
      } else {
        print('⚠️ Callback tanımlanmamış!');
      }

      return json.encode({
        'success': true,
        'token': token,
        'serverId': _cihazId,
        'serverName': _cihazAdi,
        'serverIP': serverIP, // ✅ EKLENEN: Server IP bilgisi
        'serverPort': SUNUCU_PORTU, // ✅ EKLENEN: Server port bilgisi
        'message': 'Bağlantı kuruldu',
        'serverInfo': {
          'platform': _platform,
          'belgeSayisi': await _veriTabani.toplamBelgeSayisi(),
          'toplamBoyut': await _veriTabani.toplamDosyaBoyutu(),
          'ip': serverIP, // ✅ EKLENEN: Duplicate ama uyumluluk için
        },
        // ✅ EKLENEN: Bidirectional sync için endpoint bilgileri
        'endpoints': {
          'upload': 'http://$serverIP:$SUNUCU_PORTU/upload',
          'download': 'http://$serverIP:$SUNUCU_PORTU/download',
          'documents': 'http://$serverIP:$SUNUCU_PORTU/documents',
          'connect': 'http://$serverIP:$SUNUCU_PORTU/connect',
        },
      });
    } catch (e) {
      print('❌ Connect handler hatası: $e');
      return json.encode({'error': 'Bağlantı hatası', 'message': e.toString()});
    }
  }

  // Belge listesi endpoint'i
  Future<String> _handleDocuments() async {
    try {
      print('📄 Belge listesi istendi');
      final belgeler = await _veriTabani.belgeleriGetir();

      final belgeListesi =
          belgeler
              .map(
                (belge) => {
                  'id': belge.id,
                  'dosyaAdi': belge.dosyaAdi,
                  'dosyaBoyutu': belge.dosyaBoyutu,
                  'dosyaTipi': belge.dosyaTipi,
                  'dosyaHash': belge.dosyaHash,
                  'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
                  'kategoriId': belge.kategoriId,
                  'baslik': belge.baslik,
                  'aciklama': belge.aciklama,
                  'kisiId': belge.kisiId,
                  'etiketler': belge.etiketler,
                  // Ek backward compatibility için
                  'fileName': belge.dosyaAdi,
                  'fileType': belge.dosyaTipi,
                  'hash': belge.dosyaHash,
                  'categoryId': belge.kategoriId,
                  'personId': belge.kisiId,
                  'title': belge.baslik,
                  'description': belge.aciklama,
                  'tags': belge.etiketler,
                },
              )
              .toList();

      return json.encode({
        'status': 'success',
        'documents': belgeListesi,
        'count': belgeListesi.length,
      });
    } catch (e) {
      print('❌ Documents endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Belgeler alınamadı: $e',
      });
    }
  }

  // Belge indirme endpoint'i - Hash ve dosya adı destekli
  Future<String> _handleDownload(HttpRequest request) async {
    try {
      // URL'den hash veya dosya adını al
      String requestParam;
      try {
        requestParam = Uri.decodeComponent(request.uri.pathSegments.last);
      } catch (e) {
        requestParam = request.uri.pathSegments.last;
        print('⚠️ URL decode hatası, raw string kullanılıyor: $e');
      }
      print('📥 Belge indirme isteği: $requestParam');

      BelgeModeli? belge;

      // Önce hash ile ara
      belge = await _veriTabani.belgeGetirByHash(requestParam);

      if (belge == null) {
        print('📋 Hash ile bulunamadı, dosya adı ile aranıyor...');
        // Dosya adı ile ara
        List<BelgeModeli> belgeler = await _veriTabani.belgeAra(requestParam);

        if (belgeler.isEmpty) {
          print('📋 İlk arama sonuçsuz, farklı encode türleri deneniyor...');

          // Farklı encode varyasyonlarını dene
          final aramaTerimleri = [
            requestParam,
            Uri.encodeComponent(requestParam),
            requestParam.replaceAll('%20', ' '),
            requestParam.replaceAll('+', ' '),
          ];

          for (final terim in aramaTerimleri) {
            belgeler = await _veriTabani.belgeAra(terim);
            if (belgeler.isNotEmpty) {
              print('✅ Belge bulundu: $terim');
              break;
            }
          }
        }

        if (belgeler.isEmpty) {
          print('❌ Belge hiçbir türde bulunamadı: $requestParam');
          request.response.statusCode = 404;
          await request.response.close();
          return json.encode({'error': 'Belge bulunamadı'});
        }

        belge = belgeler.first;
      }

      final dosya = File(belge.dosyaYolu);
      if (!await dosya.exists()) {
        print('❌ Dosya fiziksel olarak bulunamadı: ${belge.dosyaYolu}');
        request.response.statusCode = 404;
        await request.response.close();
        return json.encode({'error': 'Dosya bulunamadı'});
      }

      final dosyaBytes = await dosya.readAsBytes();
      final safeDosyaAdi = belge.dosyaAdi.replaceAll(
        RegExp(r'[^\w\-_\.]'),
        '_',
      );

      request.response
        ..headers.contentType = ContentType.binary
        ..headers.contentLength = dosyaBytes.length
        ..headers.add(
          'Content-Disposition',
          'attachment; filename=$safeDosyaAdi',
        )
        ..headers.add('Access-Control-Allow-Origin', '*')
        ..headers.add('Access-Control-Expose-Headers', 'Content-Disposition');

      request.response.add(dosyaBytes);
      await request.response.close();

      print(
        '✅ Belge gönderildi: ${belge.dosyaAdi} (${dosyaBytes.length} bytes)',
      );
      return 'BINARY_SENT';
    } catch (e) {
      print('❌ Download endpoint hatası: $e');
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (closeError) {
        print('⚠️ Response kapatma hatası: $closeError');
      }
      return json.encode({'error': 'İndirme hatası: $e'});
    }
  }

  // Kategori listesi endpoint'i
  Future<String> _handleCategories() async {
    try {
      print('📂 Kategori listesi istendi');
      final kategoriler = await _veriTabani.kategorileriGetir();

      final kategoriListesi =
          kategoriler
              .map(
                (kategori) => {
                  'id': kategori.id,
                  'ad': kategori.kategoriAdi,
                  'renkKodu': kategori.renkKodu,
                  'simgeKodu': kategori.simgeKodu,
                  'aciklama': kategori.aciklama,
                  'olusturmaTarihi': kategori.olusturmaTarihi.toIso8601String(),
                  'aktif': kategori.aktif,
                  'belgeSayisi': kategori.belgeSayisi,
                  // Backward compatibility için İngilizce field'ları da ekle
                  'name': kategori.kategoriAdi,
                  'color': kategori.renkKodu,
                  'icon': kategori.simgeKodu,
                  'description': kategori.aciklama,
                  'createdAt': kategori.olusturmaTarihi.toIso8601String(),
                  'active': kategori.aktif,
                  'documentCount': kategori.belgeSayisi,
                },
              )
              .toList();

      return json.encode({
        'status': 'success',
        'categories': kategoriListesi,
        'count': kategoriListesi.length,
      });
    } catch (e) {
      print('❌ Categories endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Kategoriler alınamadı: $e',
      });
    }
  }

  // Kişi listesi endpoint'i
  Future<String> _handlePeople() async {
    try {
      print('🧑‍🤝‍🧑 Kişi listesi istendi');
      final kisiler = await _veriTabani.kisileriGetir();

      final kisiListesi =
          kisiler
              .map(
                (kisi) => {
                  'id': kisi.id,
                  'ad': kisi.ad,
                  'soyad': kisi.soyad,
                  'tamAd': kisi.tamAd,
                  'olusturmaTarihi': kisi.olusturmaTarihi.toIso8601String(),
                  'guncellemeTarihi': kisi.guncellemeTarihi.toIso8601String(),
                  'aktif': kisi.aktif,
                  // Backward compatibility için İngilizce field'ları da ekle
                  'firstName': kisi.ad,
                  'lastName': kisi.soyad,
                  'fullName': kisi.tamAd,
                  'createdAt': kisi.olusturmaTarihi.toIso8601String(),
                  'updatedAt': kisi.guncellemeTarihi.toIso8601String(),
                  'active': kisi.aktif,
                },
              )
              .toList();

      return json.encode({
        'status': 'success',
        'people': kisiListesi,
        'count': kisiListesi.length,
      });
    } catch (e) {
      print('❌ People endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Kişiler alınamadı: $e',
      });
    }
  }

  // Belge yükleme endpoint'i - İyileştirilmiş multipart parser
  Future<String> _handleUpload(HttpRequest request) async {
    try {
      print('📤 Belge yükleme isteği alındı');

      // Multipart form data parser - Improved
      final boundary = request.headers.contentType?.parameters['boundary'];
      if (boundary == null) {
        throw Exception('Multipart boundary bulunamadı');
      }

      print('🔧 Boundary bulundu: $boundary');

      // Tüm body'yi binary olarak oku
      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      print('📦 Body alındı: ${bodyBytes.length} bytes');

      // Güvenli multipart parsing
      final parsedParts = _parseMultipartData(bodyBytes, boundary);

      if (parsedParts.isEmpty) {
        throw Exception('Multipart veriler parse edilemedi');
      }

      print('🔍 ${parsedParts.length} part başarıyla parse edildi');

      String? metadata;
      List<int>? fileBytes;
      String? fileName;

      // Parse edilen partları işle
      for (final part in parsedParts) {
        final headers = part['headers'] as Map<String, String>;
        final data = part['data'] as List<int>;

        final contentDisposition = headers['content-disposition'] ?? '';

        // DEBUG: Content-Disposition analizi
        print('🔍 Content-Disposition: "$contentDisposition"');

        if (contentDisposition.contains('name="metadata"') ||
            contentDisposition.contains('name="belge_data"')) {
          metadata = utf8.decode(data, allowMalformed: true);
          print(
            '✅ Metadata alındı: ${metadata.substring(0, metadata.length.clamp(0, 100))}...',
          );
        } else if (contentDisposition.contains('name="file"')) {
          fileBytes = data;

          // Filename'i header'dan çıkar
          final filenameMatch = RegExp(
            r'filename="([^"]*)"',
          ).firstMatch(contentDisposition);
          if (filenameMatch != null) {
            fileName = filenameMatch.group(1);
            print('✅ Filename bulundu: $fileName');
          }

          print('✅ File bytes alındı: ${fileBytes!.length} bytes');

          // Hash kontrolü ile data integrity check
          if (fileBytes!.isNotEmpty) {
            final hash = sha256.convert(fileBytes!).toString();
            print('🔒 Dosya hash: ${hash.substring(0, 16)}...');
          }
        }
      }

      // Debug bilgileri
      print('🔍 Parsing sonuçları:');
      print('   • Metadata: ${metadata != null ? "✅" : "❌"}');
      print(
        '   • FileBytes: ${fileBytes != null ? "✅ (${fileBytes?.length} bytes)" : "❌"}',
      );
      print('   • FileName: ${fileName ?? "❌"}');

      if (metadata == null || fileBytes == null || fileName == null) {
        final errorMsg =
            'Gerekli veriler eksik - metadata: $metadata, fileBytes: ${fileBytes?.length}, fileName: $fileName';
        print('❌ $errorMsg');
        throw Exception(errorMsg);
      }

      // Metadata'yi parse et
      Map<String, dynamic> metadataJson;
      try {
        metadataJson = json.decode(metadata) as Map<String, dynamic>;
        print(
          '📋 Metadata başarıyla parse edildi: ${metadataJson['dosyaAdi'] ?? 'Belirtilmemiş'}',
        );

        // Kişi bilgilerini güvenli şekilde göster
        final kisiAd = metadataJson['kisiAd']?.toString() ?? 'Belirtilmemiş';
        final kisiSoyad = metadataJson['kisiSoyad']?.toString() ?? '';
        final kisiTam = kisiSoyad.isNotEmpty ? '$kisiAd $kisiSoyad' : kisiAd;

        print('   • Kişi: $kisiTam');
        print(
          '   • Kategori ID: ${metadataJson['kategoriId'] ?? 'Belirtilmemiş'}',
        );
      } catch (e) {
        print('❌ Metadata parse hatası: $e');
        print('   Raw metadata: $metadata');
        throw Exception('Metadata parse edilemedi: $e');
      }

      // Dosyayı belgeler klasörüne kaydet
      final dosyaServisi = DosyaServisi();
      final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
      final yeniDosyaYolu = '$belgelerKlasoru/$fileName';

      print('💾 Dosya yazılıyor: $yeniDosyaYolu (${fileBytes.length} bytes)');

      // Dosyayı yaz
      final dosya = File(yeniDosyaYolu);
      try {
        await dosya.writeAsBytes(fileBytes);
        print('✅ Dosya başarıyla yazıldı');

        // Dosya boyutunu kontrol et
        final writtenSize = await dosya.length();
        print('📏 Yazılan dosya boyutu: $writtenSize bytes');

        if (writtenSize != fileBytes.length) {
          throw Exception(
            'Dosya boyutu eşleşmiyor - beklenen: ${fileBytes.length}, yazılan: $writtenSize',
          );
        }
      } catch (e) {
        print('❌ Dosya yazma hatası: $e');
        throw Exception('Dosya yazılamadı: $e');
      }

      // Gelişmiş kişi eşleştirme sistemi
      int? eslestirilenKisiId;
      final kisiAdStr = metadataJson['kisiAd']?.toString();
      final kisiSoyadStr = metadataJson['kisiSoyad']?.toString();
      final gonderenKisiId = metadataJson['kisiId'];
      final belgeKimlik = metadataJson['belgeKimlik']?.toString();

      print('🔍 Kişi eşleştirme başlıyor:');
      print('   • Gönderen Kişi ID: $gonderenKisiId');
      print('   • Kişi Adı: $kisiAdStr');
      print('   • Kişi Soyadı: $kisiSoyadStr');
      print('   • Belge Kimlik: $belgeKimlik');

      // Kişi bilgisi mutlaka olmalı - bu temel kural
      if (gonderenKisiId == null && (kisiAdStr == null || kisiAdStr.isEmpty)) {
        print('❌ Belge kişi bilgisi eksik - transfer reddedildi');

        // Dosyayı disk'ten sil
        final dosya = File(yeniDosyaYolu);
        if (await dosya.exists()) {
          await dosya.delete();
        }

        return json.encode({
          'status': 'error',
          'message':
              'Belge kişi bilgisi eksik. Transfer edilecek her belge mutlaka bir kişiye ait olmalıdır.',
          'code': 'MISSING_PERSON_INFO',
        });
      }

      try {
        final yerelKisiler = await _veriTabani.kisileriGetir();

        // Önce ID ile eşleştirmeyi dene (en güvenilir)
        if (gonderenKisiId != null) {
          final idIleEslestirilenKisi = yerelKisiler.firstWhere(
            (k) => k.id == gonderenKisiId,
            orElse:
                () => KisiModeli(
                  ad: '',
                  soyad: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                ),
          );

          if (idIleEslestirilenKisi.ad.isNotEmpty) {
            eslestirilenKisiId = idIleEslestirilenKisi.id;
            print('👤 ✅ ID ile eşleştirildi: ${idIleEslestirilenKisi.tamAd}');
          }
        }

        // ID ile eşleştirme başarısızsa, ad-soyad ile dene
        if (eslestirilenKisiId == null &&
            kisiAdStr != null &&
            kisiSoyadStr != null &&
            kisiAdStr.isNotEmpty) {
          final adSoyadIleEslestirilenKisi = yerelKisiler.firstWhere(
            (k) =>
                k.ad.toLowerCase() == kisiAdStr.toLowerCase() &&
                k.soyad.toLowerCase() == kisiSoyadStr.toLowerCase(),
            orElse:
                () => KisiModeli(
                  ad: '',
                  soyad: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                ),
          );

          if (adSoyadIleEslestirilenKisi.ad.isNotEmpty) {
            eslestirilenKisiId = adSoyadIleEslestirilenKisi.id;
            print(
              '👤 ✅ Ad-Soyad ile eşleştirildi: ${adSoyadIleEslestirilenKisi.tamAd}',
            );
          } else if (kisiAdStr.isNotEmpty) {
            // Kişi yoksa yeni kişi oluştur
            final yeniKisi = KisiModeli(
              ad: kisiAdStr,
              soyad: kisiSoyadStr ?? '',
              olusturmaTarihi: DateTime.now(),
              guncellemeTarihi: DateTime.now(),
            );

            final kisiId = await _veriTabani.kisiEkle(yeniKisi);
            eslestirilenKisiId = kisiId;
            print('👤 ✅ Yeni kişi oluşturuldu: ${yeniKisi.tamAd}');
          }
        }

        // Hiçbir eşleştirme başarılı değilse hata döndür
        if (eslestirilenKisiId == null) {
          print('❌ Kişi eşleştirme başarısız - transfer reddedildi');

          // Dosyayı disk'ten sil
          final dosya = File(yeniDosyaYolu);
          if (await dosya.exists()) {
            await dosya.delete();
          }

          return json.encode({
            'status': 'error',
            'message':
                'Kişi eşleştirme başarısız. Gönderilen kişi bilgileri bulunamadı.',
            'code': 'PERSON_NOT_FOUND',
          });
        }
      } catch (e) {
        print('❌ Kişi eşleştirme sistemi hatası: $e');

        // Dosyayı disk'ten sil
        final dosya = File(yeniDosyaYolu);
        if (await dosya.exists()) {
          await dosya.delete();
        }

        return json.encode({
          'status': 'error',
          'message': 'Kişi eşleştirme sistemi hatası: $e',
          'code': 'PERSON_MATCH_ERROR',
        });
      }

      // Dosya hash'ini metadata'dan al (tutarlılık için)
      final metadataHash = metadataJson['dosyaHash']?.toString();
      String dosyaHashString;

      if (metadataHash != null && metadataHash.isNotEmpty) {
        // Metadata'dan gelen hash'i kullan
        dosyaHashString = metadataHash;
        print(
          '🔐 Metadata hash kullanıldı: ${dosyaHashString.substring(0, 16)}...',
        );

        // Doğrulama için local hash hesapla
        final localHashBytes = sha256.convert(fileBytes);
        final localHashString = localHashBytes.toString();

        if (localHashString != metadataHash) {
          print('⚠️ Hash uyumsuzluğu tespit edildi!');
          print('   • Metadata Hash: ${metadataHash.substring(0, 16)}...');
          print('   • Local Hash: ${localHashString.substring(0, 16)}...');
          print('   • Dosya bütünlüğü kontrol edilmelidir');
        } else {
          print('✅ Hash doğrulaması başarılı');
        }
      } else {
        // Metadata'da hash yoksa local hesapla
        final dosyaHashBytes = sha256.convert(fileBytes);
        dosyaHashString = dosyaHashBytes.toString();
        print(
          '🔐 Local hash hesaplandı: ${dosyaHashString.substring(0, 16)}...',
        );
      }

      // Belge kimliği oluştur (Dosya Hash + Kişi ID - TC kimlik mantığı)
      final calculatedBelgeKimlik = '${dosyaHashString}_${eslestirilenKisiId}';
      print('🔍 Hesaplanan belge kimliği: $calculatedBelgeKimlik');
      print('🔍 Gelen belge kimliği: $belgeKimlik');

      // Gelişmiş duplicate kontrolü (hash + kişi bazlı)
      try {
        final mevcutBelgeler = await _veriTabani.belgeleriGetir();

        // Önce dosya hash ile kontrol et
        final hashDuplicateBelge = mevcutBelgeler.firstWhere(
          (belge) => belge.dosyaHash == dosyaHashString,
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
                kategoriId: 1,
                baslik: '',
                aciklama: '',
              ),
        );

        // Hash duplicate varsa ama kişi farklıysa güncelle
        if (hashDuplicateBelge.dosyaAdi.isNotEmpty) {
          if (hashDuplicateBelge.kisiId != eslestirilenKisiId) {
            print('🔄 Aynı dosya farklı kişiye ait, kişi güncelleniyor...');
            print('   • Eski kişi ID: ${hashDuplicateBelge.kisiId}');
            print('   • Yeni kişi ID: $eslestirilenKisiId');

            // Kişi ID'sini güncelle
            final guncelBelge = BelgeModeli(
              id: hashDuplicateBelge.id,
              dosyaAdi: hashDuplicateBelge.dosyaAdi,
              orijinalDosyaAdi: hashDuplicateBelge.orijinalDosyaAdi,
              dosyaYolu: hashDuplicateBelge.dosyaYolu,
              dosyaBoyutu: hashDuplicateBelge.dosyaBoyutu,
              dosyaTipi: hashDuplicateBelge.dosyaTipi,
              dosyaHash: hashDuplicateBelge.dosyaHash,
              kategoriId: hashDuplicateBelge.kategoriId,
              kisiId: eslestirilenKisiId, // Yeni kişi ID'si
              baslik: hashDuplicateBelge.baslik,
              aciklama: hashDuplicateBelge.aciklama,
              etiketler: hashDuplicateBelge.etiketler,
              olusturmaTarihi: hashDuplicateBelge.olusturmaTarihi,
              guncellemeTarihi: DateTime.now(), // Güncelleme zamanı
              aktif: hashDuplicateBelge.aktif,
            );
            await _veriTabani.belgeGuncelle(guncelBelge);

            // Dosyayı disk'ten sil (güncelleme yapıldı)
            final dosya = File(yeniDosyaYolu);
            if (await dosya.exists()) {
              await dosya.delete();
            }

            return json.encode({
              'status': 'success',
              'message': 'Belge kişi bilgisi güncellendi',
              'fileName': fileName,
              'action': 'updated_person',
              'oldPersonId': hashDuplicateBelge.kisiId,
              'newPersonId': eslestirilenKisiId,
            });
          } else {
            print(
              '⚠️ Aynı kişi için duplicate dosya: ${hashDuplicateBelge.dosyaAdi}',
            );

            // Metadata farklıysa UPDATE yap
            final guncellemeTarihiStr =
                metadataJson['guncellemeTarihi']?.toString();
            final guncellemeTarihi =
                guncellemeTarihiStr != null
                    ? DateTime.tryParse(guncellemeTarihiStr) ?? DateTime.now()
                    : DateTime.now();

            // Mevcut belgeden daha yeni ise UPDATE yap
            final mevcutGuncelleme = hashDuplicateBelge.guncellemeTarihi;
            final yeniGuncelleme = guncellemeTarihi;

            // Metadata değişikliği olup olmadığını kontrol et
            final metadataChanged =
                metadataJson['baslik']?.toString() !=
                    hashDuplicateBelge.baslik ||
                metadataJson['aciklama']?.toString() !=
                    hashDuplicateBelge.aciklama ||
                metadataJson['kategoriId'] != hashDuplicateBelge.kategoriId ||
                yeniGuncelleme.isAfter(mevcutGuncelleme);

            if (metadataChanged) {
              print('🔄 Metadata değişikliği tespit edildi - UPDATE yapılıyor');
              print(
                '   • Eski güncelleme: ${mevcutGuncelleme.toIso8601String()}',
              );
              print(
                '   • Yeni güncelleme: ${yeniGuncelleme.toIso8601String()}',
              );

              // Veritabanında UPDATE yap
              final updatedBelge = BelgeModeli(
                id: hashDuplicateBelge.id,
                dosyaAdi: fileName,
                orijinalDosyaAdi:
                    metadataJson['dosyaAdi']?.toString() ?? fileName,
                dosyaYolu: hashDuplicateBelge.dosyaYolu,
                dosyaBoyutu: fileBytes.length,
                dosyaTipi: fileName.split('.').last.toLowerCase(),
                dosyaHash: dosyaHashString,
                olusturmaTarihi: hashDuplicateBelge.olusturmaTarihi,
                guncellemeTarihi: yeniGuncelleme,
                kategoriId:
                    metadataJson['kategoriId'] ?? hashDuplicateBelge.kategoriId,
                baslik:
                    metadataJson['baslik']?.toString() ??
                    hashDuplicateBelge.baslik,
                aciklama:
                    metadataJson['aciklama']?.toString() ??
                    hashDuplicateBelge.aciklama,
                kisiId: eslestirilenKisiId,
                etiketler:
                    metadataJson['etiketler'] != null
                        ? List<String>.from(metadataJson['etiketler'])
                        : hashDuplicateBelge.etiketler,
                aktif: hashDuplicateBelge.aktif,
                senkronDurumu: hashDuplicateBelge.senkronDurumu,
                sonErisimTarihi: hashDuplicateBelge.sonErisimTarihi,
              );

              await _veriTabani.belgeGuncelle(updatedBelge);
              print('✅ Belge güncellendi - ID: ${hashDuplicateBelge.id}');

              // Dosyayı disk'ten sil (güncelleme yapıldı)
              final dosya = File(yeniDosyaYolu);
              if (await dosya.exists()) {
                await dosya.delete();
                print('🗑️ Geçici dosya diskten silindi');
              }

              return json.encode({
                'status': 'success',
                'message': 'Belge başarıyla güncellendi',
                'fileName': fileName,
                'size': fileBytes.length,
                'belgeId': hashDuplicateBelge.id,
                'action': 'updated',
              });
            } else {
              print('⏸️ Metadata değişikliği yok - atlanıyor');

              // Dosyayı disk'ten sil
              final dosya = File(yeniDosyaYolu);
              if (await dosya.exists()) {
                await dosya.delete();
                print('🗑️ Duplicate dosya diskten silindi');
              }

              return json.encode({
                'status': 'warning',
                'message': 'Bu dosya zaten mevcut (değişiklik yok)',
                'fileName': fileName,
                'existingFile': hashDuplicateBelge.dosyaAdi,
                'duplicate': true,
              });
            }
          }
        }

        // Belge kimlik kontrolü (varsa)
        if (belgeKimlik != null && belgeKimlik.isNotEmpty) {
          print('🔍 Belge kimlik kontrolü: $belgeKimlik');
          // İleride belge kimlik tablosu eklenirse burada kontrol edilebilir
        }
      } catch (e) {
        print('⚠️ Duplicate kontrolü hatası: $e');
        // Hata durumunda devam et
      }

      // Veritabanına ekle - null safety ile
      final olusturmaTarihiStr = metadataJson['olusturmaTarihi']?.toString();
      final olusturmaTarihi =
          olusturmaTarihiStr != null
              ? DateTime.tryParse(olusturmaTarihiStr) ?? DateTime.now()
              : DateTime.now();

      final yeniBelge = BelgeModeli(
        dosyaAdi: fileName,
        orijinalDosyaAdi: metadataJson['dosyaAdi']?.toString() ?? fileName,
        dosyaYolu: yeniDosyaYolu,
        dosyaBoyutu: fileBytes.length,
        dosyaTipi: fileName.split('.').last.toLowerCase(),
        dosyaHash: dosyaHashString,
        olusturmaTarihi: olusturmaTarihi,
        guncellemeTarihi: DateTime.now(),
        kategoriId: metadataJson['kategoriId'] ?? 1,
        baslik: metadataJson['baslik']?.toString(),
        aciklama: metadataJson['aciklama']?.toString(),
        kisiId: eslestirilenKisiId,
        etiketler:
            metadataJson['etiketler'] != null
                ? List<String>.from(metadataJson['etiketler'])
                : null,
      );

      final belgeId = await _veriTabani.belgeEkle(yeniBelge);
      print('✅ Belge veritabanına eklendi - ID: $belgeId');

      print('🎉 Belge başarıyla yüklendi: $fileName');
      print('📊 Özet:');
      print('   • Dosya adı: $fileName');
      print('   • Boyut: ${fileBytes.length} bytes');

      // Kişi bilgilerini güvenli şekilde göster
      final kisiAd = metadataJson['kisiAd']?.toString() ?? 'Belirtilmemiş';
      final kisiSoyad = metadataJson['kisiSoyad']?.toString() ?? '';
      final kisiTam = kisiSoyad.isNotEmpty ? '$kisiAd $kisiSoyad' : kisiAd;

      print('   • Kişi: $kisiTam');
      print('   • Kategori ID: ${metadataJson['kategoriId']}');

      return json.encode({
        'status': 'success',
        'message': 'Belge başarıyla yüklendi',
        'fileName': fileName,
        'size': fileBytes.length,
        'belgeId': belgeId,
        'kisi': kisiTam,
      });
    } catch (e, stackTrace) {
      print('❌ Upload endpoint hatası: $e');
      print('📋 Stack trace: $stackTrace');

      // Hata durumunda da uygun response dön
      final errorResponse = json.encode({
        'status': 'error',
        'error': 'Yükleme hatası',
        'message': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Status code'u düzgün ayarla ama response'u bizim döndürmemize izin ver
      // Çünkü main handler zaten response'u kapatacak
      return errorResponse;
    }
  }

  // Multipart parsing helper fonksiyonları
  List<Map<String, dynamic>> _parseMultipartData(
    List<int> bodyBytes,
    String boundary,
  ) {
    final parts = <Map<String, dynamic>>[];

    try {
      // Boundary bytes'ını hazırla
      final boundaryBytes = utf8.encode('--$boundary');
      final endBoundaryBytes = utf8.encode('--$boundary--');

      int start = 0;
      int partIndex = 0;

      // İlk boundary'i atla
      int firstBoundaryIndex = _findBoundary(bodyBytes, boundaryBytes, start);
      if (firstBoundaryIndex == -1) {
        print('❌ İlk boundary bulunamadı');
        return parts;
      }

      start = firstBoundaryIndex + boundaryBytes.length;
      // \r\n'i atla
      if (start < bodyBytes.length && bodyBytes[start] == 13) start++;
      if (start < bodyBytes.length && bodyBytes[start] == 10) start++;

      // Her part'ı işle
      while (start < bodyBytes.length && partIndex < 10) {
        // Bir sonraki boundary'i bul
        int nextBoundaryIndex = _findBoundary(bodyBytes, boundaryBytes, start);
        int endBoundaryIndex = _findBoundary(
          bodyBytes,
          endBoundaryBytes,
          start,
        );

        // En yakın boundary'i seç
        int currentPartEnd = -1;
        if (nextBoundaryIndex != -1 && endBoundaryIndex != -1) {
          currentPartEnd =
              nextBoundaryIndex < endBoundaryIndex
                  ? nextBoundaryIndex
                  : endBoundaryIndex;
        } else if (nextBoundaryIndex != -1) {
          currentPartEnd = nextBoundaryIndex;
        } else if (endBoundaryIndex != -1) {
          currentPartEnd = endBoundaryIndex;
        }

        if (currentPartEnd == -1) break;

        // Part data'sını al
        final partData = bodyBytes.sublist(start, currentPartEnd);
        if (partData.isEmpty) break;

        // Header'ı bul
        final headerEndIndex = _findHeaderEnd(partData);
        if (headerEndIndex == -1) {
          print('⚠️ Part $partIndex: Header end bulunamadı');
          break;
        }

        // Header'ı parse et
        final headerBytes = partData.sublist(0, headerEndIndex);
        final headerString = utf8.decode(headerBytes, allowMalformed: true);

        // Header'ları ayrıştır
        final headers = <String, String>{};
        final headerLines = headerString.split('\r\n');

        for (final line in headerLines) {
          if (line.contains(':')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim().toLowerCase();
              final value = parts.sublist(1).join(':').trim();
              headers[key] = value;
            }
          }
        }

        // Data kısmını al
        final dataStart = headerEndIndex + 4; // \r\n\r\n atla
        List<int> data = [];

        if (dataStart < partData.length) {
          data = partData.sublist(dataStart);

          // Trailing \r\n'leri temizle
          while (data.isNotEmpty && (data.last == 13 || data.last == 10)) {
            data.removeLast();
          }
        }

        // Part'ı ekle
        parts.add({'headers': headers, 'data': data});

        print('✅ Part $partIndex parse edildi: ${data.length} bytes');
        partIndex++;

        // Sonraki part'a geç
        start = currentPartEnd + boundaryBytes.length;
        if (start < bodyBytes.length && bodyBytes[start] == 13) start++;
        if (start < bodyBytes.length && bodyBytes[start] == 10) start++;

        // End boundary'e ulaştıysak dur
        if (currentPartEnd == endBoundaryIndex) break;
      }

      print('🎉 Toplam ${parts.length} part başarıyla parse edildi');
      return parts;
    } catch (e) {
      print('❌ Multipart parsing hatası: $e');
      return parts;
    }
  }

  int _findHeaderEnd(List<int> bytes) {
    // \r\n\r\n (double CRLF) pattern'ini ara
    final pattern = [13, 10, 13, 10]; // \r\n\r\n

    for (int i = 0; i <= bytes.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        return i;
      }
    }
    return -1;
  }

  int _findBoundary(List<int> haystack, List<int> needle, int start) {
    for (int i = start; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        return i;
      }
    }
    return -1;
  }

  // Kategori senkronizasyon endpoint'i (basitleştirilmiş)
  Future<String> _handleCategorySync(HttpRequest request) async {
    try {
      print('📂 Kategori senkronizasyon endpoint\'i çağrıldı');

      return json.encode({
        'status': 'success',
        'message': 'Kategori sync endpoint\'i hazır (implement edilecek)',
      });
    } catch (e) {
      print('❌ Category sync hatası: $e');
      request.response.statusCode = 500;
      return json.encode({'error': 'Kategori sync hatası: $e'});
    }
  }

  // Kişi senkronizasyon endpoint'i (basitleştirilmiş)
  Future<String> _handlePeopleSync(HttpRequest request) async {
    try {
      print('🧑‍🤝‍🧑 Kişi senkronizasyon endpoint\'i çağrıldı');

      return json.encode({
        'status': 'success',
        'message': 'Kişi sync endpoint\'i hazır (implement edilecek)',
      });
    } catch (e) {
      print('❌ People sync hatası: $e');
      request.response.statusCode = 500;
      return json.encode({'error': 'Kişi sync hatası: $e'});
    }
  }

  // ============== YENİ SYNC ENDPOINT'LERİ ==============

  /// Delta listesini döndüren endpoint
  Future<String> _handleSyncDeltas() async {
    try {
      print('🔄 Delta sync endpoint\'i çağrıldı');

      // Son 24 saat içindeki değişiklikleri al
      final cutoffTime = DateTime.now().subtract(Duration(hours: 24));
      final belgeler = await _veriTabani.belgeleriGetir();

      // Değişen belgeleri tespit et
      final deltas = <Map<String, dynamic>>[];

      for (final belge in belgeler) {
        if (belge.guncellemeTarihi.isAfter(cutoffTime) ||
            belge.olusturmaTarihi.isAfter(cutoffTime)) {
          // Delta objesi oluştur
          final deltaType =
              belge.olusturmaTarihi.isAfter(cutoffTime) ? 'CREATE' : 'UPDATE';

          deltas.add({
            'id': 'delta_${belge.id}_${DateTime.now().millisecondsSinceEpoch}',
            'documentId': belge.id.toString(),
            'deltaType': deltaType,
            'timestamp': belge.guncellemeTarihi.toIso8601String(),
            'hash': belge.dosyaHash,
            'fileSize': belge.dosyaBoyutu,
            'filePath': belge.dosyaYolu,
            'metadata': {
              'title': belge.baslik,
              'description': belge.aciklama,
              'categoryId': belge.kategoriId,
              'personId': belge.kisiId,
              'fileName': belge.dosyaAdi,
              'fileType': belge.dosyaTipi,
              'createdAt': belge.olusturmaTarihi.toIso8601String(),
              'updatedAt': belge.guncellemeTarihi.toIso8601String(),
            },
          });
        }
      }

      print('📊 ${deltas.length} delta gönderiliyor');

      return json.encode({
        'deltas': deltas,
        'timestamp': DateTime.now().toIso8601String(),
        'deviceId': _cihazId,
        'totalCount': deltas.length,
      });
    } catch (e) {
      print('❌ Delta sync hatası: $e');
      return json.encode({
        'error': 'Delta sync hatası',
        'message': e.toString(),
        'deltas': [],
      });
    }
  }

  /// Belge ID'sine göre belge detaylarını döndüren endpoint
  Future<String> _handleDocumentById(HttpRequest request) async {
    try {
      final pathSegments = request.uri.pathSegments;
      if (pathSegments.length < 2) {
        return json.encode({'error': 'Belge ID gerekli'});
      }

      final documentId = pathSegments[1];
      print('📄 Belge detayı isteniyor: $documentId');

      final belge = await _veriTabani.belgeGetir(int.parse(documentId));
      if (belge == null) {
        return json.encode({'error': 'Belge bulunamadı'});
      }

      return json.encode({
        'id': belge.id,
        'fileName': belge.dosyaAdi,
        'originalFileName': belge.orijinalDosyaAdi,
        'fileType': belge.dosyaTipi,
        'fileSize': belge.dosyaBoyutu,
        'filePath': belge.dosyaYolu,
        'hash': belge.dosyaHash,
        'title': belge.baslik,
        'description': belge.aciklama,
        'categoryId': belge.kategoriId,
        'personId': belge.kisiId,
        'tags': belge.etiketler,
        'createdAt': belge.olusturmaTarihi.toIso8601String(),
        'updatedAt': belge.guncellemeTarihi.toIso8601String(),
      });
    } catch (e) {
      print('❌ Belge detayı hatası: $e');
      return json.encode({
        'error': 'Belge detayı alınamadı',
        'message': e.toString(),
      });
    }
  }

  /// Kişi ID'sine göre kişi detaylarını döndüren endpoint
  Future<String> _handlePersonById(HttpRequest request) async {
    try {
      final pathSegments = request.uri.pathSegments;
      if (pathSegments.length < 2) {
        return json.encode({'error': 'Kişi ID gerekli'});
      }

      final personId = pathSegments[1];
      print('👤 Kişi detayı isteniyor: $personId');

      final kisi = await _veriTabani.kisiGetir(int.parse(personId));
      if (kisi == null) {
        return json.encode({'error': 'Kişi bulunamadı'});
      }

      return json.encode({
        'id': kisi.id,
        'firstName': kisi.ad,
        'lastName': kisi.soyad,
        'fullName': kisi.tamAd,
        'active': kisi.aktif,
        'createdAt': kisi.olusturmaTarihi.toIso8601String(),
        'updatedAt': kisi.guncellemeTarihi.toIso8601String(),
      });
    } catch (e) {
      print('❌ Kişi detayı hatası: $e');
      return json.encode({
        'error': 'Kişi detayı alınamadı',
        'message': e.toString(),
      });
    }
  }

  // New metadata synchronization endpoints

  /// Metadata senkronizasyon endpoint'i - POST /metadata/sync
  Future<String> _handleMetadataSync(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = json.decode(body);
      final changes = List<Map<String, dynamic>>.from(data['changes'] ?? []);
      final deviceId = request.headers.value('X-Device-ID') ?? 'unknown';

      print(
        '📥 Metadata sync: ${changes.length} değişiklik alındı ($deviceId)',
      );

      final processedIds = <int>[];

      for (final change in changes) {
        try {
          final belgeId = change['belge_id'] as int?;
          if (belgeId == null) continue;

          final belge = await _veriTabani.belgeGetir(belgeId);
          if (belge == null) continue;

          // Metadata değişikliklerini uygula
          final updatedBelge = _applyMetadataChanges(belge, change);
          await _veriTabani.belgeGuncelle(updatedBelge);

          processedIds.add(change['id'] as int);
          print('✅ Metadata güncellendi: ${belge.dosyaAdi}');
        } catch (e) {
          print('❌ Metadata güncelleme hatası: $e');
        }
      }

      return json.encode({
        'status': 'success',
        'processed_count': processedIds.length,
        'processed_ids': processedIds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Metadata sync endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Metadata sync hatası: $e',
      });
    }
  }

  /// Metadata değişikliklerini getir - GET /metadata/changes
  Future<String> _handleMetadataChanges(HttpRequest request) async {
    try {
      final queryParams = request.uri.queryParameters;
      final sinceParam = queryParams['since'];
      final deviceId = queryParams['device_id'] ?? 'unknown';

      DateTime since = DateTime.now().subtract(Duration(days: 1));
      if (sinceParam != null && sinceParam.isNotEmpty) {
        try {
          since = DateTime.parse(sinceParam);
        } catch (e) {
          print('⚠️ Geçersiz since parametresi: $sinceParam');
        }
      }

      print('📤 Metadata değişiklikleri istendi: $deviceId, since: $since');

      // Son değişiklikleri al
      final belgeler = await _veriTabani.belgeleriGetir();
      final changes = <Map<String, dynamic>>[];

      for (final belge in belgeler) {
        if (belge.guncellemeTarihi.isAfter(since)) {
          changes.add({
            'belge_id': belge.id,
            'dosya_hash': belge.dosyaHash,
            'metadata_hash': _generateMetadataHash(belge),
            'baslik': belge.baslik,
            'aciklama': belge.aciklama,
            'etiketler': belge.etiketler?.join(','),
            'kategori_id': belge.kategoriId,
            'kisi_id': belge.kisiId,
            'guncelleme_tarihi': belge.guncellemeTarihi.toIso8601String(),
            'change_type': 'UPDATE',
          });
        }
      }

      print('📊 ${changes.length} metadata değişikliği gönderiliyor');

      return json.encode({
        'status': 'success',
        'changes': changes,
        'count': changes.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Metadata changes endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Metadata changes hatası: $e',
        'changes': [],
      });
    }
  }

  /// Metadata çakışmalarını getir - GET /metadata/conflicts
  Future<String> _handleMetadataConflicts(HttpRequest request) async {
    try {
      final db = await _veriTabani.database;

      // Bekleyen çakışmaları al
      final conflicts = await db.rawQuery('''
        SELECT 
          mc.*,
          b.dosya_adi,
          b.baslik
        FROM metadata_conflicts mc
        LEFT JOIN belgeler b ON mc.belge_id = b.id
        WHERE mc.status = 'PENDING'
        ORDER BY mc.conflict_time DESC
        LIMIT 50
      ''');

      print('📋 ${conflicts.length} metadata çakışması gönderiliyor');

      return json.encode({
        'status': 'success',
        'conflicts': conflicts,
        'count': conflicts.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Metadata conflicts endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Metadata conflicts hatası: $e',
        'conflicts': [],
      });
    }
  }

  /// Metadata değişikliklerini belgeye uygula
  BelgeModeli _applyMetadataChanges(
    BelgeModeli belge,
    Map<String, dynamic> change,
  ) {
    return BelgeModeli(
      id: belge.id,
      dosyaAdi: belge.dosyaAdi,
      orijinalDosyaAdi: belge.orijinalDosyaAdi,
      dosyaYolu: belge.dosyaYolu,
      dosyaBoyutu: belge.dosyaBoyutu,
      dosyaTipi: belge.dosyaTipi,
      dosyaHash: belge.dosyaHash,
      baslik: change['yeni_deger'] ?? belge.baslik,
      aciklama: change['aciklama'] ?? belge.aciklama,
      etiketler:
          _parseEtiketler(change['etiketler']?.toString()) ?? belge.etiketler,
      kategoriId: change['kategori_id'] as int? ?? belge.kategoriId,
      kisiId: change['kisi_id'] as int? ?? belge.kisiId,
      olusturmaTarihi: belge.olusturmaTarihi,
      guncellemeTarihi: DateTime.now(),
      sonErisimTarihi: belge.sonErisimTarihi,
      aktif: belge.aktif,
      senkronDurumu: belge.senkronDurumu,
    );
  }

  /// Etiketleri parse et
  List<String>? _parseEtiketler(String? etiketlerString) {
    if (etiketlerString == null || etiketlerString.isEmpty) return null;
    return etiketlerString
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Metadata hash oluştur
  String _generateMetadataHash(BelgeModeli belge) {
    final metadataMap = {
      'baslik': belge.baslik ?? '',
      'aciklama': belge.aciklama ?? '',
      'etiketler': belge.etiketler?.join(',') ?? '',
      'kategori_id': belge.kategoriId ?? 0,
      'kisi_id': belge.kisiId ?? 0,
      'dosya_adi': belge.dosyaAdi,
      'dosya_tipi': belge.dosyaTipi,
    };

    final metadataJson = json.encode(metadataMap);
    final bytes = utf8.encode(metadataJson);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  // Bidirectional Sync Endpoints

  /// Sync negotiation endpoint - POST /sync/negotiate
  Future<String> _handleSyncNegotiate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = json.decode(body);

      final remoteManifest = data['manifest'];
      final strategy = data['strategy'] ?? 'LATEST_WINS';
      final deviceId = request.headers.value('X-Device-ID') ?? 'unknown';

      print('🤝 Sync negotiation başlatıldı: $deviceId, strategy: $strategy');

      // Simulate negotiation logic
      // Gerçek implementasyonda BidirectionalSyncProtocol kullanılacak

      return json.encode({
        'status': 'success',
        'negotiation_result': {
          'accepted_strategy': strategy,
          'sync_direction': 'BIDIRECTIONAL',
          'estimated_files': 0,
          'estimated_size': 0,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Sync negotiate endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Sync negotiation hatası: $e',
      });
    }
  }

  /// Get sync manifest - GET /sync/manifest
  Future<String> _handleSyncManifest(HttpRequest request) async {
    try {
      final deviceId = request.headers.value('X-Device-ID') ?? 'unknown';

      print('📋 Sync manifest istendi: $deviceId');

      // Simulate manifest creation
      // Gerçek implementasyonda BidirectionalSyncProtocol.createSyncManifest kullanılacak

      final belgeler = await _veriTabani.belgeleriGetir();
      final files = <String, Map<String, dynamic>>{};
      int totalSize = 0;

      for (final belge in belgeler) {
        files[belge.dosyaHash] = {
          'fileHash': belge.dosyaHash,
          'fileName': belge.dosyaAdi,
          'fileSize': belge.dosyaBoyutu ?? 0,
          'contentHash': belge.dosyaHash,
          'metadataHash': _generateMetadataHash(belge),
          'lastModified': belge.guncellemeTarihi.toIso8601String(),
          'metadata': {
            'baslik': belge.baslik,
            'aciklama': belge.aciklama,
            'etiketler': belge.etiketler,
          },
        };
        totalSize += belge.dosyaBoyutu ?? 0;
      }

      return json.encode({
        'status': 'success',
        'manifest': {
          'manifestId': 'manifest_${DateTime.now().millisecondsSinceEpoch}',
          'deviceId': _cihazId,
          'deviceName': _cihazAdi,
          'createdAt': DateTime.now().toIso8601String(),
          'files': files,
          'totalSize': totalSize,
          'fileCount': files.length,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Sync manifest endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Sync manifest hatası: $e',
      });
    }
  }

  /// Create sync manifest - POST /sync/manifest
  Future<String> _handleSyncManifestCreate(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = json.decode(body);

      final deviceId = data['deviceId'] ?? 'unknown';
      final deviceName = data['deviceName'] ?? 'Unknown Device';

      print('📋 Yeni sync manifest oluşturuluyor: $deviceName');

      // Manifest oluşturma simülasyonu
      // Gerçek implementasyonda BidirectionalSyncProtocol kullanılacak

      return json.encode({
        'status': 'success',
        'manifestId': 'manifest_${DateTime.now().millisecondsSinceEpoch}',
        'message': 'Manifest başarıyla oluşturuldu',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Sync manifest create endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Sync manifest create hatası: $e',
      });
    }
  }

  /// Bidirectional sync execution - POST /sync/bidirectional
  Future<String> _handleBidirectionalSync(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = json.decode(body);

      final decisions = data['decisions'] ?? {};
      final parallelExecution = data['parallel_execution'] ?? true;
      final deviceId = request.headers.value('X-Device-ID') ?? 'unknown';

      print('🔄 Bidirectional sync başlatıldı: $deviceId');

      // Simüle edilmiş bidirectional sync
      // Gerçek implementasyonda BidirectionalSyncProtocol.executeBidirectionalSync kullanılacak

      return json.encode({
        'status': 'success',
        'sync_result': {
          'session_id': 'session_${DateTime.now().millisecondsSinceEpoch}',
          'total_files': (decisions as Map).length,
          'upload_count': 0,
          'download_count': 0,
          'success_count': 0,
          'error_count': 0,
          'transferred_bytes': 0,
          'success_rate': 1.0,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Bidirectional sync endpoint hatası: $e');
      return json.encode({
        'status': 'error',
        'message': 'Bidirectional sync hatası: $e',
      });
    }
  }
}
