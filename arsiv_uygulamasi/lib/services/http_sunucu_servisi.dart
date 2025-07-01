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
      final dosyaAdi = Uri.decodeComponent(request.uri.pathSegments.last);
      print('📥 Belge indirme isteği: $dosyaAdi');

      final belgeler = await _veriTabani.belgeAra(dosyaAdi);
      if (belgeler.isEmpty) {
        request.response.statusCode = 404;
        await request.response.close();
        return json.encode({'error': 'Belge bulunamadı'});
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
      return 'BINARY_SENT'; // Binary response gönderildi işareti
    } catch (e) {
      print('❌ Download endpoint hatası: $e');
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (closeError) {
        print('❌ Response kapatma hatası: $closeError');
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

  // Belge yükleme endpoint'i
  Future<String> _handleUpload(HttpRequest request) async {
    try {
      print('📤 Belge yükleme isteği alındı');

      // Multipart form data parser
      final boundary = request.headers.contentType?.parameters['boundary'];
      if (boundary == null) {
        throw Exception('Multipart boundary bulunamadı');
      }

      final bodyBytes = await request.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      // Simple multipart parsing
      final bodyString = utf8.decode(bodyBytes);
      final parts = bodyString.split('--$boundary');

      String? metadata;
      List<int>? fileBytes;
      String? fileName;

      for (final part in parts) {
        if (part.contains('Content-Disposition: form-data; name="metadata"')) {
          final lines = part.split('\r\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].trim().isEmpty && i + 1 < lines.length) {
              metadata = lines[i + 1].trim();
              break;
            }
          }
        } else if (part.contains(
          'Content-Disposition: form-data; name="file"',
        )) {
          final lines = part.split('\r\n');

          // Filename'i bul
          for (final line in lines) {
            if (line.contains('filename=')) {
              final filenameMatch = RegExp(
                r'filename="([^"]*)"',
              ).firstMatch(line);
              if (filenameMatch != null) {
                fileName = filenameMatch.group(1);
              }
              break;
            }
          }

          // Dosya verisinin başlangıcını bul
          final headerEndIndex = part.indexOf('\r\n\r\n');
          if (headerEndIndex != -1) {
            final fileContent = part.substring(headerEndIndex + 4);
            if (fileContent.isNotEmpty) {
              fileBytes = utf8.encode(fileContent);
            }
          }
        }
      }

      if (metadata == null || fileBytes == null || fileName == null) {
        throw Exception('Gerekli veriler eksik: metadata, file, filename');
      }

      // Metadata'yi parse et
      final metadataJson = json.decode(metadata) as Map<String, dynamic>;
      print('📋 Metadata alındı: ${metadataJson['dosyaAdi']}');

      // Dosyayı belgeler klasörüne kaydet
      final dosyaServisi = DosyaServisi();
      final belgelerKlasoru = await dosyaServisi.belgelerKlasoruYolu();
      final yeniDosyaYolu = '$belgelerKlasoru/$fileName';

      // Dosyayı yaz
      final dosya = File(yeniDosyaYolu);
      await dosya.writeAsBytes(fileBytes);

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

      // Veritabanına ekle
      final yeniBelge = BelgeModeli(
        dosyaAdi: fileName,
        orijinalDosyaAdi: metadataJson['dosyaAdi'] ?? fileName,
        dosyaYolu: yeniDosyaYolu,
        dosyaBoyutu: fileBytes.length,
        dosyaTipi: fileName.split('.').last.toLowerCase(),
        dosyaHash: '', // Hash hesaplanacak
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

      await _veriTabani.belgeEkle(yeniBelge);

      print('✅ Belge başarıyla yüklendi: $fileName');

      return json.encode({
        'status': 'success',
        'message': 'Belge başarıyla yüklendi',
        'fileName': fileName,
        'size': fileBytes.length,
      });
    } catch (e) {
      print('❌ Upload endpoint hatası: $e');
      request.response.statusCode = 500;
      return json.encode({'error': 'Yükleme hatası: $e'});
    }
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
