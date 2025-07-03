import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'veritabani_servisi.dart';
import 'dosya_servisi.dart';
import 'belge_islemleri_servisi.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
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

      if (clientId == null || clientName == null) {
        return json.encode({'error': 'clientId ve clientName gerekli'});
      }

      // Basit token oluştur
      final token = 'token_${DateTime.now().millisecondsSinceEpoch}';

      // Bağlantı başarılı bildirimi
      print('🎉 BAĞLANTI BAŞARILI! Mobil cihaz bağlandı');
      print('📱 Bağlanan cihaz: $clientName ($clientId)');
      print('📱 IP: ${request.connectionInfo?.remoteAddress?.address}');

      // UI'ya bildirim gönder - HEMEN
      final deviceInfo = {
        'clientId': clientId,
        'clientName': clientName,
        'ip': request.connectionInfo?.remoteAddress?.address ?? 'bilinmiyor',
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
        'message': 'Bağlantı kuruldu',
        'serverInfo': {
          'platform': _platform,
          'belgeSayisi': await _veriTabani.toplamBelgeSayisi(),
          'toplamBoyut': await _veriTabani.toplamDosyaBoyutu(),
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
                  'olusturmaTarihi': belge.olusturmaTarihi.toIso8601String(),
                  'kategoriId': belge.kategoriId,
                  'baslik': belge.baslik,
                  'aciklama': belge.aciklama,
                  'kisiId': belge.kisiId,
                  'etiketler': belge.etiketler,
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

  // Belge indirme endpoint'i
  Future<String> _handleDownload(HttpRequest request) async {
    try {
      // URL decode'u güvenli şekilde yap
      String dosyaAdi;
      try {
        dosyaAdi = Uri.decodeComponent(request.uri.pathSegments.last);
      } catch (e) {
        // Decode edilemiyorsa raw string kullan
        dosyaAdi = request.uri.pathSegments.last;
        print('⚠️ URL decode hatası, raw string kullanılıyor: $e');
      }
      print('📥 Belge indirme isteği: $dosyaAdi');

      // Dosya adı ile belge ara (esnek arama)
      List<BelgeModeli> belgeler = await _veriTabani.belgeAra(dosyaAdi);

      // Eğer bulunamazsa, URL decode edilmiş hali ile de dene
      if (belgeler.isEmpty) {
        print('📋 İlk arama sonuçsuz, farklı encode türleri deneniyor...');

        // Farklı encode varyasyonlarını dene
        final aramaTerimleri = [
          dosyaAdi,
          Uri.encodeComponent(dosyaAdi),
          dosyaAdi.replaceAll('%20', ' '),
          dosyaAdi.replaceAll('+', ' '),
        ];

        for (final terim in aramaTerimleri) {
          belgeler = await _veriTabani.belgeAra(terim);
          if (belgeler.isNotEmpty) {
            print('✅ Belge bulundu: $terim');
            break;
          }
        }

        if (belgeler.isEmpty) {
          print('❌ Belge hiçbir encode türünde bulunamadı: $dosyaAdi');
          request.response.statusCode = 404;
          await request.response.close();
          return json.encode({'error': 'Belge bulunamadı'});
        }
      }

      final dosya = File(belgeler.first.dosyaYolu);
      if (!await dosya.exists()) {
        request.response.statusCode = 404;
        await request.response.close();
        return json.encode({'error': 'Dosya bulunamadı'});
      }

      final dosyaBytes = await dosya.readAsBytes();

      // Türkçe karakterler için güvenli filename oluştur
      final safeDosyaAdi = dosyaAdi.replaceAll(RegExp(r'[^\w\-_\.]'), '_');

      request.response
        ..headers.contentType = ContentType.binary
        ..headers.contentLength = dosyaBytes.length
        ..headers.add(
          'Content-Disposition',
          'attachment; filename=$safeDosyaAdi',
        )
        ..headers.add('Access-Control-Allow-Origin', '*')
        ..headers.add('Access-Control-Expose-Headers', 'Content-Disposition');

      // Dosya verilerini yaz ve response'u kapat
      request.response.add(dosyaBytes);
      await request.response.close();

      print('✅ Belge gönderildi: $dosyaAdi (${dosyaBytes.length} bytes)');
      print('✅ Binary dosya gönderildi');
      return 'BINARY_SENT'; // Binary response gönderildi işareti
    } catch (e) {
      print('❌ Download endpoint hatası: $e');

      // Response kapatmayı dene, eğer zaten kapalıysa ignore et
      try {
        request.response.statusCode = 500;
        await request.response.close();
        print('⚠️ Error response gönderildi');
      } catch (closeError) {
        print('⚠️ Response zaten kapatılmış veya kapatma hatası: $closeError');
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

        if (contentDisposition.contains('name="metadata"')) {
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
          '📋 Metadata başarıyla parse edildi: ${metadataJson['dosyaAdi']}',
        );
        print(
          '   • Kişi: ${metadataJson['kisiAd']} ${metadataJson['kisiSoyad']}',
        );
        print('   • Kategori ID: ${metadataJson['kategoriId']}');
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

      // Kişi ID'sini eşleştir (ad-soyad kombinasyonuna göre)
      int? eslestirilenKisiId;
      if (metadataJson['kisiAd'] != null && metadataJson['kisiSoyad'] != null) {
        try {
          // Yerel kişi listesinde ad-soyad kombinasyonunu ara
          final yerelKisiler = await _veriTabani.kisileriGetir();
          final eslestirilenKisi = yerelKisiler.firstWhere(
            (k) =>
                k.ad == metadataJson['kisiAd'] &&
                k.soyad == metadataJson['kisiSoyad'],
            orElse:
                () => KisiModeli(
                  ad: '',
                  soyad: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                ),
          );

          if (eslestirilenKisi.ad.isNotEmpty) {
            eslestirilenKisiId = eslestirilenKisi.id;
            print('👤 Kişi eşleştirildi: ${eslestirilenKisi.tamAd}');
          } else {
            // Kişi yoksa yeni kişi ekle
            final yeniKisi = KisiModeli(
              ad: metadataJson['kisiAd'],
              soyad: metadataJson['kisiSoyad'],
              olusturmaTarihi: DateTime.now(),
              guncellemeTarihi: DateTime.now(),
            );

            final kisiId = await _veriTabani.kisiEkle(yeniKisi);
            eslestirilenKisiId = kisiId;
            print('👤 Yeni kişi eklendi: ${yeniKisi.tamAd}');
          }
        } catch (e) {
          print('⚠️ Kişi eşleştirme hatası: $e');
          // Varsayılan olarak ilk kişiyi seç
          final yerelKisiler = await _veriTabani.kisileriGetir();
          if (yerelKisiler.isNotEmpty) {
            eslestirilenKisiId = yerelKisiler.first.id;
            print('⚠️ Varsayılan kişi seçildi: ${yerelKisiler.first.tamAd}');
          }
        }
      } else if (metadataJson['kisiId'] != null) {
        // Fallback: eski yöntem (ID ile)
        try {
          final yerelKisiler = await _veriTabani.kisileriGetir();
          final eslestirilenKisi = yerelKisiler.firstWhere(
            (k) => k.id == metadataJson['kisiId'],
            orElse:
                () => KisiModeli(
                  ad: '',
                  soyad: '',
                  olusturmaTarihi: DateTime.now(),
                  guncellemeTarihi: DateTime.now(),
                ),
          );

          if (eslestirilenKisi.ad.isNotEmpty) {
            eslestirilenKisiId = eslestirilenKisi.id;
          } else if (yerelKisiler.isNotEmpty) {
            eslestirilenKisiId = yerelKisiler.first.id;
            print(
              '⚠️ ID ile eşleştirilemedi, varsayılan seçildi: ${yerelKisiler.first.tamAd}',
            );
          }
        } catch (e) {
          print('⚠️ Kişi ID eşleştirme hatası: $e');
        }
      }

      // Dosya hash'ini hesapla
      final dosyaHashBytes = sha256.convert(fileBytes);
      final dosyaHashString = dosyaHashBytes.toString();
      print('🔐 Dosya hash hesaplandı: ${dosyaHashString.substring(0, 16)}...');

      // Duplicate kontrolü yap
      try {
        final mevcutBelgeler = await _veriTabani.belgeleriGetir();
        final duplicateBelge = mevcutBelgeler.firstWhere(
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

        if (duplicateBelge.dosyaAdi.isNotEmpty) {
          print('⚠️ Duplicate dosya bulundu: ${duplicateBelge.dosyaAdi}');

          // Dosyayı disk'ten sil
          final dosya = File(yeniDosyaYolu);
          if (await dosya.exists()) {
            await dosya.delete();
            print('🗑️ Duplicate dosya diskten silindi');
          }

          return json.encode({
            'status': 'warning',
            'message': 'Bu dosya zaten mevcut',
            'fileName': fileName,
            'existingFile': duplicateBelge.dosyaAdi,
            'duplicate': true,
          });
        }
      } catch (e) {
        print('⚠️ Duplicate kontrolü hatası: $e');
        // Hata durumunda devam et
      }

      // Veritabanına ekle
      final yeniBelge = BelgeModeli(
        dosyaAdi: fileName,
        orijinalDosyaAdi: metadataJson['dosyaAdi'] ?? fileName,
        dosyaYolu: yeniDosyaYolu,
        dosyaBoyutu: fileBytes.length,
        dosyaTipi: fileName.split('.').last.toLowerCase(),
        dosyaHash: dosyaHashString,
        olusturmaTarihi: DateTime.parse(metadataJson['olusturmaTarihi']),
        guncellemeTarihi: DateTime.now(),
        kategoriId: metadataJson['kategoriId'] ?? 1,
        baslik: metadataJson['baslik'],
        aciklama: metadataJson['aciklama'],
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
      print(
        '   • Kişi: ${metadataJson['kisiAd']} ${metadataJson['kisiSoyad']}',
      );
      print('   • Kategori ID: ${metadataJson['kategoriId']}');

      return json.encode({
        'status': 'success',
        'message': 'Belge başarıyla yüklendi',
        'fileName': fileName,
        'size': fileBytes.length,
        'belgeId': belgeId,
        'kisi': '${metadataJson['kisiAd']} ${metadataJson['kisiSoyad']}',
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
}
