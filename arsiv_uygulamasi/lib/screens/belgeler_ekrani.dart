import 'package:flutter/material.dart';
import 'dart:io';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../services/belge_islemleri_servisi.dart';
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
  int? _secilenAy;
  int? _secilenYil;

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
        );
      } else {
        yeniBelgeler = await _veriTabani.belgeleriDetayliGetir(
          limit: _sayfaBoyutu,
          offset: _mevcutSayfa * _sayfaBoyutu,
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
    print('DEBUG: _verileriYukle() çağrıldı, kategori ID: $_mevcutKategoriId');
    setState(() {
      _yukleniyor = true;
    });

    try {
      List<Map<String, dynamic>> detayliBelgeler;
      if (_mevcutKategoriId != null) {
        print(
          'DEBUG: Kategori ID: $_mevcutKategoriId ile belgeler getiriliyor',
        );
        detayliBelgeler = await _veriTabani.kategoriyeGoreBelgeleriDetayliGetir(
          _mevcutKategoriId!,
        );
        print('DEBUG: Kategoriye ait ${detayliBelgeler.length} belge bulundu');
      } else {
        print('DEBUG: Tüm belgeler getiriliyor');
        detayliBelgeler = await _veriTabani.belgeleriDetayliGetir();
        print('DEBUG: Toplam ${detayliBelgeler.length} belge bulundu');
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
    print('DEBUG: _belgeleriFiltrele() çağrıldı');
    print('DEBUG: Arama metni: "$_aramaMetni"');
    print('DEBUG: Kategori ID: $_mevcutKategoriId');
    print('DEBUG: Seçilen ay: $_secilenAy, yıl: $_secilenYil');

    // Veritabanı seviyesinde filtreleme yap
    try {
      List<BelgeModeli> filtrelenmsBelgeler;

      if (_aramaMetni.isNotEmpty || _secilenAy != null || _secilenYil != null) {
        print('DEBUG: Gelişmiş arama kullanılıyor');
        // Gelişmiş arama kullan
        filtrelenmsBelgeler = await _veriTabani.belgeAramaDetayli(
          aramaMetni: _aramaMetni.isNotEmpty ? _aramaMetni : null,
          ay: _secilenAy,
          yil: _secilenYil,
          kategoriId: _mevcutKategoriId,
        );
      } else {
        print('DEBUG: Basit filtreleme kullanılıyor');
        // Filtresiz tüm belgeler
        filtrelenmsBelgeler = List.from(_tumBelgeler);
        print('DEBUG: Toplam belge sayısı: ${filtrelenmsBelgeler.length}');

        // Eğer kategori filtresi varsa uygula
        if (_mevcutKategoriId != null) {
          print('DEBUG: Kategori filtresi uygulanıyor');
          filtrelenmsBelgeler =
              filtrelenmsBelgeler
                  .where((belge) => belge.kategoriId == _mevcutKategoriId)
                  .toList();
          print(
            'DEBUG: Kategori filtresi sonrası: ${filtrelenmsBelgeler.length}',
          );
        }
      }

      print('DEBUG: Filtreleme sonucu: ${filtrelenmsBelgeler.length} belge');
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

    // Basit arama filtresi - istenen kriterlere göre
    if (_aramaMetni.isNotEmpty) {
      filtrelenmsBelgeler =
          filtrelenmsBelgeler.where((belge) {
            final aramaKelimesi = _aramaMetni.toLowerCase();

            // 1. Dosya adında arama
            if (belge.orijinalDosyaAdi.toLowerCase().contains(aramaKelimesi) ||
                belge.dosyaAdi.toLowerCase().contains(aramaKelimesi)) {
              return true;
            }

            // 2. Başlıkta arama
            if (belge.baslik?.toLowerCase().contains(aramaKelimesi) ?? false) {
              return true;
            }

            // 3. Açıklamada arama
            if (belge.aciklama?.toLowerCase().contains(aramaKelimesi) ??
                false) {
              return true;
            }

            // 4. Etiketlerde arama
            if (belge.etiketler?.any(
                  (etiket) => etiket.toLowerCase().contains(aramaKelimesi),
                ) ??
                false) {
              return true;
            }

            // 5. Kategoride arama
            if (belge.kategoriId != null) {
              try {
                final kategori = _kategoriler.firstWhere(
                  (k) => k.id == belge.kategoriId,
                );
                if (kategori.kategoriAdi.toLowerCase().contains(
                  aramaKelimesi,
                )) {
                  return true;
                }
              } catch (e) {
                // Kategori bulunamadı, devam et
              }
            }

            // 6. Kişide arama
            if (belge.kisiId != null) {
              try {
                final kisi = _kisiler.firstWhere((k) => k.id == belge.kisiId);
                if ('${kisi.ad} ${kisi.soyad}'.toLowerCase().contains(
                  aramaKelimesi,
                )) {
                  return true;
                }
              } catch (e) {
                // Kişi bulunamadı, devam et
              }
            }

            return false;
          }).toList();
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
              // Ana arama kutusu
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildAramaKutusu(),
              ),

              // Arama sonuçları
              Expanded(
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
                    });
                    _belgeleriFiltrele();
                  },
                  onBelgeDuzenle: (belge) async {
                    final sonuc = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                YeniBelgeEkleEkrani(duzenlenecekBelge: belge),
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
        fieldController.text = _aramaController.text;
        fieldController.addListener(() {
          _aramaController.text = fieldController.text;
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

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }
}
