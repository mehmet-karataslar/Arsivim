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
  List<KategoriModeli> _kategoriler = [];
  List<KisiModeli> _kisiler = [];
  bool _yukleniyor = true;

  // Basit arama durumu
  String _aramaMetni = '';
  int? _mevcutKategoriId; // Kategoriye göre filtreleme için
  KategoriModeli? _mevcutKategori; // Kategori bilgisi için

  // Sonuç widget durumu
  AramaSiralamaTuru _siralamaTuru = AramaSiralamaTuru.tarihYeni;
  AramaGorunumTuru _gorunumTuru = AramaGorunumTuru.liste;

  // Tarih filtresi
  DateTime? _secilenBaslangicTarihi;
  DateTime? _secilenBitisTarihi;

  final TextEditingController _aramaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mevcutKategoriId = widget.kategoriId;
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
    });

    try {
      List<BelgeModeli> belgeler;
      if (_mevcutKategoriId != null) {
        belgeler = await _veriTabani.kategoriyeGoreBelgeleriGetir(
          _mevcutKategoriId!,
        );
      } else {
        belgeler = await _veriTabani.belgeleriGetir();
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
        _tumBelgeler = belgeler;
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
      await _verileriYukle();

      // Başarı mesajı göster
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
    } catch (e) {
      _hataGoster('Yenileme sırasında hata oluştu: $e');
    }
  }

  // Pull-to-refresh metodu
  Future<void> _onRefresh() async {
    await _verileriYenile();
  }

  void _belgeleriFiltrele() {
    List<BelgeModeli> filtrelenmsBelgeler = List.from(_tumBelgeler);

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
    if (_secilenBaslangicTarihi != null || _secilenBitisTarihi != null) {
      filtrelenmsBelgeler =
          filtrelenmsBelgeler.where((belge) {
            final belgeTarihi = belge.olusturmaTarihi;

            // Başlangıç tarihi kontrolü
            if (_secilenBaslangicTarihi != null) {
              if (belgeTarihi.isBefore(_secilenBaslangicTarihi!)) {
                return false;
              }
            }

            // Bitiş tarihi kontrolü
            if (_secilenBitisTarihi != null) {
              final bitisTarihi = DateTime(
                _secilenBitisTarihi!.year,
                _secilenBitisTarihi!.month,
                _secilenBitisTarihi!.day,
                23,
                59,
                59,
              ); // Gün sonuna kadar
              if (belgeTarihi.isAfter(bitisTarihi)) {
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
                  kategoriler: _kategoriler,
                  kisiler: _kisiler,
                  siralamaTuru: _siralamaTuru,
                  gorunumTuru: _gorunumTuru,
                  yukleniyor: _yukleniyor,
                  secilenBaslangicTarihi: _secilenBaslangicTarihi,
                  secilenBitisTarihi: _secilenBitisTarihi,
                  onSiralamaSecildi: (siralama) {
                    setState(() => _siralamaTuru = siralama);
                  },
                  onGorunumSecildi: (gorunum) {
                    setState(() => _gorunumTuru = gorunum);
                  },
                  onTarihSecimi: (baslangic, bitis) {
                    setState(() {
                      _secilenBaslangicTarihi = baslangic;
                      _secilenBitisTarihi = bitis;
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
    // PC için otomatik tamamlama ile arama kutusu
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
          // fieldController otomatik olarak Autocomplete tarafından yönetiliyor
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
    } else {
      // Mobil için normal arama kutusu
      return TextField(
        controller: _aramaController,
        decoration: InputDecoration(
          hintText:
              'Belgeler arasında arama yapın (dosya adı, başlık, açıklama, etiket, kategori, kişi)...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _aramaMetni.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
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
    }
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }
}
