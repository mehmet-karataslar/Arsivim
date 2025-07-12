import 'package:flutter/material.dart';
import 'dart:io';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
import '../services/log_servisi.dart';
import '../widgets/arama_sonuclari_widget.dart';
import '../utils/screen_utils.dart';
import 'yeni_belge_ekle_ekrani.dart';

class BelgelerEkrani extends StatefulWidget {
  final int? kategoriId;
  const BelgelerEkrani({Key? key, this.kategoriId}) : super(key: key);

  @override
  State<BelgelerEkrani> createState() => _BelgelerEkraniState();
}

class _BelgelerEkraniState extends State<BelgelerEkrani> {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final BelgeIslemleriServisi _belgeIslemleri = BelgeIslemleriServisi();
  final LogServisi _logServisi = LogServisi.instance;

  List<BelgeModeli> _tumBelgeler = [];
  List<BelgeModeli> _filtrelenmsBelgeler = [];
  List<Map<String, dynamic>> _detayliBelgeler = []; // Detaylı belge verisi için
  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  bool _yukleniyor = true;
  bool _dahaFazlaYukleniyor = false;
  bool _dahaFazlaVarMi = true;

  // Pagination
  static const int _sayfaBoyutu = 20;
  int _mevcutSayfa = 0;

  // Basit arama durumu
  String _aramaMetni = '';
  int? _mevcutKategoriId; // Kategoriye göre filtreleme için
  KategoriModeli? _mevcutKategori; // Kategori bilgisi için

  // Tarih filtresi
  DateTime? _baslangicTarihi;
  DateTime? _bitisTarihi;
  int? _secilenAy;
  int? _secilenYil;
  bool _tarihFiltresiAcik = false; // Tarih filtresinin açık/kapalı durumu

  // Sonuç widget durumu
  AramaSiralamaTuru _siralamaTuru = AramaSiralamaTuru.tarihYeni;
  AramaGorunumTuru _gorunumTuru = AramaGorunumTuru.liste;

  final TextEditingController _aramaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _aramaController.addListener(() {
      setState(() {
        _aramaMetni = _aramaController.text;
      });
      _belgeleriFiltrele();
    });

    // Constructor parametresini al
    _mevcutKategoriId = widget.kategoriId;

    // Argumentleri al (eğer route arguments varsa) ve verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['kategori_id'] != null) {
        _mevcutKategoriId = args['kategori_id'];
      }
      _verileriYukle();
    });
  }

  @override
  void dispose() {
    _aramaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _dahaFazlaBelgeYukle();
    }
  }

  Future<void> _dahaFazlaBelgeYukle() async {
    if (_dahaFazlaYukleniyor || !_dahaFazlaVarMi) return;

    setState(() {
      _dahaFazlaYukleniyor = true;
    });

    try {
      _mevcutSayfa++;
      List<Map<String, dynamic>> yeniBelgeler;

      if (_mevcutKategoriId != null) {
        yeniBelgeler = await _veriTabani.kategoriyeGoreBelgeleriDetayliGetir(
          _mevcutKategoriId!,
          limit: _sayfaBoyutu,
          offset: _mevcutSayfa * _sayfaBoyutu,
          baslangicTarihi: _baslangicTarihi,
          bitisTarihi: _bitisTarihi,
        );
      } else {
        yeniBelgeler = await _veriTabani.belgeleriDetayliGetir(
          limit: _sayfaBoyutu,
          offset: _mevcutSayfa * _sayfaBoyutu,
          baslangicTarihi: _baslangicTarihi,
          bitisTarihi: _bitisTarihi,
        );
      }

      if (mounted) {
        setState(() {
          _detayliBelgeler.addAll(yeniBelgeler);
          // Eski belge listesini de güncelle
          _tumBelgeler.addAll(
            yeniBelgeler.map((data) => BelgeModeli.fromMap(data)).toList(),
          );
          _dahaFazlaVarMi = yeniBelgeler.length == _sayfaBoyutu;
          _dahaFazlaYukleniyor = false;
        });
        _belgeleriFiltrele();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dahaFazlaYukleniyor = false;
        });
      }
    }
  }

  Future<void> _verileriYukle() async {
    _logServisi.debug(
      'Belgeler ekranı verileri yükleniyor, kategori ID: $_mevcutKategoriId',
    );
    setState(() {
      _yukleniyor = true;
    });

    try {
      List<Map<String, dynamic>> detayliBelgeler;
      if (_mevcutKategoriId != null) {
        _logServisi.debug(
          'Kategori ID: $_mevcutKategoriId ile belgeler getiriliyor',
        );
        detayliBelgeler = await _veriTabani.kategoriyeGoreBelgeleriDetayliGetir(
          _mevcutKategoriId!,
          baslangicTarihi: _baslangicTarihi,
          bitisTarihi: _bitisTarihi,
        );
        _logServisi.debug(
          'Kategoriye ait ${detayliBelgeler.length} belge bulundu',
        );
      } else {
        _logServisi.debug('Tüm belgeler getiriliyor');
        detayliBelgeler = await _veriTabani.belgeleriDetayliGetir(
          baslangicTarihi: _baslangicTarihi,
          bitisTarihi: _bitisTarihi,
        );
        _logServisi.debug('Toplam ${detayliBelgeler.length} belge bulundu');
      }

      final kategoriler = await _veriTabani.kategorileriGetir();
      final kisiler = await _veriTabani.kisileriGetir();

      // Mevcut kategoriyi bul
      KategoriModeli? mevcutKategori;
      if (_mevcutKategoriId != null) {
        try {
          mevcutKategori = kategoriler.firstWhere(
            (k) => k.id == _mevcutKategoriId,
          );
        } catch (e) {
          // Kategori bulunamazsa null kalır
        }
      }

      setState(() {
        _detayliBelgeler = detayliBelgeler;
        _tumBelgeler =
            detayliBelgeler.map((data) => BelgeModeli.fromMap(data)).toList();
        _kategoriler = kategoriler;
        _kisiler = kisiler;
        _mevcutKategori = mevcutKategori;
        _yukleniyor = false;
      });

      _belgeleriFiltrele();
    } catch (e) {
      setState(() {
        _yukleniyor = false;
      });
      _hataGoster('Veriler yüklenirken hata oluştu: $e');
    }
  }

  // Verileri yenileme metodu
  Future<void> _verileriYenile() async {
    try {
      // Önce cache'i temizle ve gerçek verilerle yenile
      _mevcutSayfa = 0;
      _dahaFazlaVarMi = true;

      await _verileriYukle();

      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('${_filtrelenmsBelgeler.length} belge yenilendi!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _hataGoster('Yenileme sırasında hata oluştu: $e');
    }
  }

  // Pull-to-refresh metodu
  Future<void> _onRefresh() async {
    await _verileriYenile();
  }

  void _belgeleriFiltrele() async {
    _logServisi.debug('Belgeler filtreleniyor');
    _logServisi.debug('Arama metni: "$_aramaMetni"');
    _logServisi.debug('Kategori ID: $_mevcutKategoriId');
    _logServisi.debug('Başlangıç: $_baslangicTarihi, Bitiş: $_bitisTarihi');

    // Veritabanı seviyesinde filtreleme yap
    try {
      List<BelgeModeli> filtrelenmsBelgeler;

      if (_aramaMetni.isNotEmpty || _secilenAy != null || _secilenYil != null) {
        _logServisi.debug('Gelişmiş arama kullanılıyor');
        // Gelişmiş arama kullan
        filtrelenmsBelgeler = await _veriTabani.belgeAramaDetayli(
          aramaMetni: _aramaMetni.isNotEmpty ? _aramaMetni : null,
          ay: _secilenAy,
          yil: _secilenYil,
          kategoriId: _mevcutKategoriId,
        );
      } else {
        _logServisi.debug('Basit filtreleme kullanılıyor');
        // Filtresiz tüm belgeler
        filtrelenmsBelgeler = List.from(_tumBelgeler);
        _logServisi.debug('Toplam belge sayısı: ${filtrelenmsBelgeler.length}');

        // Eğer kategori filtresi varsa uygula
        if (_mevcutKategoriId != null) {
          _logServisi.debug('Kategori filtresi uygulanıyor');
          filtrelenmsBelgeler =
              filtrelenmsBelgeler
                  .where((belge) => belge.kategoriId == _mevcutKategoriId)
                  .toList();
          _logServisi.debug(
            'Kategori filtresi sonrası: ${filtrelenmsBelgeler.length}',
          );
        }
      }

      _logServisi.debug(
        'Filtreleme sonucu: ${filtrelenmsBelgeler.length} belge',
      );
      setState(() {
        _filtrelenmsBelgeler = filtrelenmsBelgeler;
      });
    } catch (e) {
      // Hata durumunda client-side filtreleme kullan
      _clientSideFiltrele();
    }
  }

  // Yedek client-side filtreleme
  void _clientSideFiltrele() {
    List<BelgeModeli> filtrelenmsBelgeler = List.from(_tumBelgeler);

    // Önce kategori filtresi uygula
    if (_mevcutKategoriId != null) {
      filtrelenmsBelgeler =
          filtrelenmsBelgeler
              .where((belge) => belge.kategoriId == _mevcutKategoriId)
              .toList();
    }

    // Gelişmiş arama filtresi
    if (_aramaMetni.isNotEmpty) {
      // Minimum karakter kontrolü
      if (_aramaMetni.length < 1) {
        setState(() {
          _filtrelenmsBelgeler = filtrelenmsBelgeler;
        });
        return;
      }

      final aramaKelimesi = _aramaMetni.toLowerCase().trim();
      final aramaSozcukleri =
          aramaKelimesi.split(' ').where((s) => s.isNotEmpty).toList();

      // Arama sonuçlarını puanlama sistemi ile sıralama
      final aramaSonuclari = <Map<String, dynamic>>[];

      for (final belge in filtrelenmsBelgeler) {
        final puan = _belgeAramaPuani(belge, aramaKelimesi, aramaSozcukleri);
        if (puan > 0) {
          aramaSonuclari.add({'belge': belge, 'puan': puan});
        }
      }

      // Puana göre sıralama (yüksek puan önce)
      aramaSonuclari.sort((a, b) => b['puan'].compareTo(a['puan']));

      filtrelenmsBelgeler =
          aramaSonuclari.map((item) => item['belge'] as BelgeModeli).toList();
    }

    // Tarih filtresi uygula
    if (_secilenAy != null || _secilenYil != null) {
      filtrelenmsBelgeler =
          filtrelenmsBelgeler.where((belge) {
            final belgeTarihi = belge.olusturmaTarihi;

            // Ay kontrolü
            if (_secilenAy != null) {
              if (belgeTarihi.month != _secilenAy) {
                return false;
              }
            }

            // Yıl kontrolü
            if (_secilenYil != null) {
              if (belgeTarihi.year != _secilenYil) {
                return false;
              }
            }

              return true;
          }).toList();
    }

    setState(() {
      _filtrelenmsBelgeler = filtrelenmsBelgeler;
    });
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
    final orijinalDosyaAdi = belge.orijinalDosyaAdi.toLowerCase();
    final baslik = (belge.baslik ?? '').toLowerCase();
    final aciklama = (belge.aciklama ?? '').toLowerCase();
    final etiketler = (belge.etiketler ?? [])
        .map((e) => e.toLowerCase())
        .join(' ');

    // Kategori adı
    String kategoriAdi = '';
            if (belge.kategoriId != null) {
              try {
                final kategori = _kategoriler.firstWhere(
                  (k) => k.id == belge.kategoriId,
                );
        kategoriAdi = kategori.kategoriAdi.toLowerCase();
              } catch (e) {
        // Kategori bulunamadı
              }
            }

    // Kişi adı
    String kisiAdi = '';
            if (belge.kisiId != null) {
              try {
                final kisi = _kisiler.firstWhere((k) => k.id == belge.kisiId);
        kisiAdi = '${kisi.ad} ${kisi.soyad}'.toLowerCase();
              } catch (e) {
        // Kişi bulunamadı
      }
    }

    // 1. TAM METIN EŞLEŞMESİ (en yüksek puan)
    if (dosyaAdi == aramaKelimesi) puan += 1000;
    if (orijinalDosyaAdi == aramaKelimesi) puan += 1000;
    if (baslik == aramaKelimesi) puan += 900;
    if (aciklama == aramaKelimesi) puan += 800;
    if (kategoriAdi == aramaKelimesi) puan += 700;
    if (kisiAdi == aramaKelimesi) puan += 600;

    // 2. TAM KELIME EŞLEŞMESİ (yüksek puan)
    final tamKelimePuani =
        _tamKelimeAramaPuani(aramaKelimesi, aramaSozcukleri, {
          'dosyaAdi': dosyaAdi,
          'orijinalDosyaAdi': orijinalDosyaAdi,
          'baslik': baslik,
          'aciklama': aciklama,
          'etiketler': etiketler,
          'kategoriAdi': kategoriAdi,
          'kisiAdi': kisiAdi,
        });
    puan += tamKelimePuani;

    // 3. BAŞLANGIC EŞLEŞMESİ (orta puan)
    if (dosyaAdi.startsWith(aramaKelimesi)) puan += 300;
    if (orijinalDosyaAdi.startsWith(aramaKelimesi)) puan += 300;
    if (baslik.startsWith(aramaKelimesi)) puan += 250;
    if (aciklama.startsWith(aramaKelimesi)) puan += 200;
    if (kategoriAdi.startsWith(aramaKelimesi)) puan += 150;
    if (kisiAdi.startsWith(aramaKelimesi)) puan += 100;

    // 4. IÇERIK EŞLEŞMESİ (düşük puan)
    if (dosyaAdi.contains(aramaKelimesi)) puan += 50;
    if (orijinalDosyaAdi.contains(aramaKelimesi)) puan += 50;
    if (baslik.contains(aramaKelimesi)) puan += 40;
    if (aciklama.contains(aramaKelimesi)) puan += 30;
    if (etiketler.contains(aramaKelimesi)) puan += 25;
    if (kategoriAdi.contains(aramaKelimesi)) puan += 20;
    if (kisiAdi.contains(aramaKelimesi)) puan += 15;

    // 5. FUZZY SEARCH (çok düşük puan)
    puan += _fuzzySearchPuani(aramaKelimesi, dosyaAdi, 10);
    puan += _fuzzySearchPuani(aramaKelimesi, orijinalDosyaAdi, 10);
    puan += _fuzzySearchPuani(aramaKelimesi, baslik, 8);
    puan += _fuzzySearchPuani(aramaKelimesi, aciklama, 6);
    puan += _fuzzySearchPuani(aramaKelimesi, kategoriAdi, 4);
    puan += _fuzzySearchPuani(aramaKelimesi, kisiAdi, 2);

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
            case 'orijinalDosyaAdi':
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
            case 'kategoriAdi':
              puan += 300;
              break;
            case 'kisiAdi':
              puan += 250;
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
            case 'orijinalDosyaAdi':
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
            case 'kategoriAdi':
              puan += (cokluKelimeBonusu * 0.6).round();
              break;
            case 'kisiAdi':
              puan += (cokluKelimeBonusu * 0.5).round();
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
    if (aranan.length < 2)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ScreenUtils.buildAppBar(
        title:
            _mevcutKategori != null
                ? '${_mevcutKategori!.kategoriAdi} Belgeleri'
                : 'Tüm Belgeler',
        backgroundColor: Colors.transparent,
        actions: [
          // Yenileme butonu - sadece desktop platformlarda göster
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: IconButton(
                icon:
                    _yukleniyor
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                        : const Icon(Icons.refresh),
                onPressed: _yukleniyor ? null : _verileriYenile,
                tooltip: 'Belgeleri Yenile',
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ScreenUtils.buildGradientContainer(
          colors: [Colors.blue.shade50, Colors.white],
          child: Column(
            children: [
              // Görünüm kontrolleri en üstte
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildGorunumKontrolleri(),
              ),

              // Ana arama kutusu
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildAramaKutusu(),
              ),

              // Tarih filtresi (açılır/kapanır)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildTarihFiltresi(),
              ),

              // Arama sonuçları
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRect(
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: AramaSonuclariWidget(
                    belgeler: _filtrelenmsBelgeler,
                    detayliBelgeler: _detayliBelgeler,
                    kategoriler: _kategoriler,
                    kisiler: _kisiler,
                    siralamaTuru: _siralamaTuru,
                    gorunumTuru: _gorunumTuru,
                    yukleniyor: _yukleniyor,
                    secilenAy: _secilenAy,
                    secilenYil: _secilenYil,
                    onSiralamaSecildi: (siralama) {
                      setState(() => _siralamaTuru = siralama);
                    },
                    onGorunumSecildi: (gorunum) {
                      setState(() => _gorunumTuru = gorunum);
                    },
                    onAyYilSecimi: (ay, yil) {
                      setState(() {
                        _secilenAy = ay;
                        _secilenYil = yil;

                        // Yeni tarih filtreleme sistemini de güncelle
                        if (ay != null && yil != null) {
                          _baslangicTarihi = DateTime(yil, ay, 1);
                          _bitisTarihi = DateTime(
                            yil,
                            ay + 1,
                            0,
                          ); // Ayın son günü
                        } else if (yil != null) {
                          _baslangicTarihi = DateTime(yil, 1, 1);
                          _bitisTarihi = DateTime(yil, 12, 31);
                        } else {
                          _baslangicTarihi = null;
                          _bitisTarihi = null;
                        }
                      });
                      _belgeleriFiltrele();
                    },
                    onBelgeDuzenle: (belge) async {
                      final sonuc = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                                      (context) => YeniBelgeEkleEkrani(
                                        duzenlenecekBelge: belge,
                                      ),
                        ),
                      );
                      if (sonuc == true) {
                        _verileriYukle();
                      }
                    },
                    onBelgelerGuncellendi: () {
                      _verileriYukle();
                    },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Sağ alta belge ekleme butonu
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final sonuc = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const YeniBelgeEkleEkrani(),
            ),
          );
          if (sonuc == true) {
            _verileriYukle();
          }
        },
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildGorunumKontrolleri() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              'Görünüm:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    '${_filtrelenmsBelgeler.length} belge',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // Görünüm toggle butonları
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGorunumButonu(
                    AramaGorunumTuru.liste,
                    Icons.view_list,
                    'Liste',
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[300]),
                  _buildGorunumButonu(
                    AramaGorunumTuru.kompakt,
                    Icons.view_compact,
                    'Kompakt',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGorunumButonu(
    AramaGorunumTuru tur,
    IconData icon,
    String tooltip,
  ) {
    final secili = _gorunumTuru == tur;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _gorunumTuru = tur),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: secili ? Colors.blue[600] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildAramaKutusu() {
    // Kişi isimlerini autocomplete için hazırla
    final kisiIsimleri = _kisiler.map((kisi) => kisi.tamAd).toList();
    final kategoriIsimleri =
        _kategoriler.map((kategori) => kategori.kategoriAdi).toList();
    final tumOneriler = [...kisiIsimleri, ...kategoriIsimleri];

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return tumOneriler.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        _aramaController.text = selection;
        setState(() => _aramaMetni = selection);
        _belgeleriFiltrele();
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // fieldController'ı _aramaController ile senkronize et
        if (fieldController.text != _aramaController.text) {
        fieldController.text = _aramaController.text;
        }

        // Listener'ı tek seferlik ekle
        fieldController.removeListener(() {});
        fieldController.addListener(() {
          if (_aramaController.text != fieldController.text) {
          _aramaController.text = fieldController.text;
            setState(() => _aramaMetni = fieldController.text);
            _belgeleriFiltrele();
          }
        });

        return TextField(
          controller: fieldController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            hintText:
                'Belgeler arasında arama yapın (kişi, kategori, dosya adı...)...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon:
                _aramaMetni.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        fieldController.clear();
                        _aramaController.clear();
                        setState(() => _aramaMetni = '');
                        _belgeleriFiltrele();
                      },
                    )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            setState(() => _aramaMetni = value);
            _belgeleriFiltrele();
          },
          onSubmitted: (value) {
            setState(() => _aramaMetni = value);
            _belgeleriFiltrele();
          },
        );
      },
    );
  }

  Widget _buildTarihFiltresi() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(Icons.date_range, color: Colors.blue[600], size: 18),
              const SizedBox(width: 8),
              Text(
                'Tarih Filtresi',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              if (_baslangicTarihi != null || _bitisTarihi != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_baslangicTarihi != null || _bitisTarihi != null)
                IconButton(
                  onPressed: _tarihFiltresiTemizle,
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: 'Temizle',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              Icon(
                _tarihFiltresiAcik ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
          initiallyExpanded: _tarihFiltresiAcik,
          onExpansionChanged: (expanded) {
            setState(() {
              _tarihFiltresiAcik = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTarihSecici(
                          'Başlangıç Tarihi',
                          _baslangicTarihi,
                          (tarih) => setState(() => _baslangicTarihi = tarih),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTarihSecici(
                          'Bitiş Tarihi',
                          _bitisTarihi,
                          (tarih) => setState(() => _bitisTarihi = tarih),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHizliTarihSecenekleri(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarihSecici(
    String label,
    DateTime? tarih,
    Function(DateTime?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _tarihSec(onChanged),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tarih != null
                        ? '${tarih.day}/${tarih.month}/${tarih.year}'
                        : 'Tarih seçin',
                    style: TextStyle(
                      color: tarih != null ? Colors.black87 : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
                if (tarih != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHizliTarihSecenekleri() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı Seçenekler:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildHizliTarihChip('Son 7 gün', () => _setHizliTarih(7)),
            _buildHizliTarihChip('Son 30 gün', () => _setHizliTarih(30)),
            _buildHizliTarihChip('Bu ay', () => _setBuAy()),
            _buildHizliTarihChip('Geçen ay', () => _setGecenAy()),
            _buildHizliTarihChip('Bu yıl', () => _setBuYil()),
          ],
        ),
      ],
    );
  }

  Widget _buildHizliTarihChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(
        color: Colors.blue[700],
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(color: Colors.blue[200]!),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Future<void> _tarihSec(Function(DateTime?) onChanged) async {
    final tarih = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (tarih != null) {
      onChanged(tarih);
      _belgeleriFiltrele();
    }
  }

  void _tarihFiltresiTemizle() {
    setState(() {
      _baslangicTarihi = null;
      _bitisTarihi = null;
      _secilenAy = null;
      _secilenYil = null;
    });
    _belgeleriFiltrele();
  }

  void _setHizliTarih(int gunSayisi) {
    final now = DateTime.now();
    setState(() {
      _bitisTarihi = now;
      _baslangicTarihi = now.subtract(Duration(days: gunSayisi));
    });
    _belgeleriFiltrele();
  }

  void _setBuAy() {
    final now = DateTime.now();
    setState(() {
      _baslangicTarihi = DateTime(now.year, now.month, 1);
      _bitisTarihi = DateTime(now.year, now.month + 1, 0);
    });
    _belgeleriFiltrele();
  }

  void _setGecenAy() {
    final now = DateTime.now();
    final gecenAy = DateTime(now.year, now.month - 1, 1);
    setState(() {
      _baslangicTarihi = gecenAy;
      _bitisTarihi = DateTime(gecenAy.year, gecenAy.month + 1, 0);
    });
    _belgeleriFiltrele();
  }

  void _setBuYil() {
    final now = DateTime.now();
    setState(() {
      _baslangicTarihi = DateTime(now.year, 1, 1);
      _bitisTarihi = DateTime(now.year, 12, 31);
    });
    _belgeleriFiltrele();
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }
}
