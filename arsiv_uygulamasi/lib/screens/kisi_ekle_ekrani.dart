import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/kisi_modeli.dart';
import '../services/veritabani_servisi.dart';
import '../utils/screen_utils.dart';

class KisiEkleEkrani extends StatefulWidget {
  final KisiModeli? kisi; // Düzenleme için mevcut kişi

  const KisiEkleEkrani({Key? key, this.kisi}) : super(key: key);

  @override
  State<KisiEkleEkrani> createState() => _KisiEkleEkraniState();
}

class _KisiEkleEkraniState extends State<KisiEkleEkrani>
    with SingleTickerProviderStateMixin {
  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();

  final FocusNode _adFocusNode = FocusNode();
  final FocusNode _soyadFocusNode = FocusNode();

  bool _kayitEdiliyor = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  // Profil fotoğrafı için
  File? _secilenFoto;
  String? _mevcutFotoYolu;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Eğer düzenleme modundaysa mevcut verileri yükle
    if (widget.kisi != null) {
      _adController.text = widget.kisi!.ad;
      _soyadController.text = widget.kisi!.soyad;
      _mevcutFotoYolu = widget.kisi!.profilFotografi;
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _adFocusNode.dispose();
    _soyadFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fotografSec() async {
    try {
      final XFile? secilenDosya = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (secilenDosya != null) {
        setState(() {
          _secilenFoto = File(secilenDosya.path);
        });
      }
    } catch (e) {
      _hataGoster('Fotoğraf seçilirken hata oluştu: $e');
    }
  }

  Future<void> _kameraDanCek() async {
    try {
      final XFile? secilenDosya = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (secilenDosya != null) {
        setState(() {
          _secilenFoto = File(secilenDosya.path);
        });
      }
    } catch (e) {
      _hataGoster('Kameradan fotoğraf çekilirken hata oluştu: $e');
    }
  }

  void _fotografSecenekleri() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _fotografSec();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _kameraDanCek();
                },
              ),
              if (_secilenFoto != null || _mevcutFotoYolu != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Fotoğrafı Kaldır'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _secilenFoto = null;
                      _mevcutFotoYolu = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _fotografKaydet() async {
    if (_secilenFoto == null) return _mevcutFotoYolu;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final profilePhotosDir = Directory('${appDir.path}/profile_photos');

      if (!await profilePhotosDir.exists()) {
        await profilePhotosDir.create(recursive: true);
      }

      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${profilePhotosDir.path}/$fileName';

      await _secilenFoto!.copy(savedPath);
      return savedPath;
    } catch (e) {
      _hataGoster('Fotoğraf kaydedilirken hata oluştu: $e');
      return null;
    }
  }

  void _hataGoster(String mesaj) {
    ScreenUtils.showErrorSnackBar(context, mesaj);
  }

  void _basariMesajiGoster(String mesaj) {
    ScreenUtils.showSuccessSnackBar(context, mesaj);
  }

  @override
  Widget build(BuildContext context) {
    bool duzenlemeModundaMi = widget.kisi != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: ScreenUtils.buildAppBar(
        title: duzenlemeModundaMi ? 'Kişiyi Düzenle' : 'Yeni Kişi Ekle',
        actions: [
          if (!_kayitEdiliyor)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Material(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _kisiKaydet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      duzenlemeModundaMi ? 'GÜNCELLE' : 'KAYDET',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _kayitEdiliyor ? _buildYuklemeEkrani() : _buildForm(),
    );
  }

  Widget _buildYuklemeEkrani() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
              Icon(
                Icons.person_add,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.kisi != null
                ? 'Kişi güncelleniyor...'
                : 'Kişi kaydediliyor...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen bekleyiniz',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık kartı
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.1),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.kisi != null
                                  ? Icons.edit
                                  : Icons.person_add,
                              size: 32,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.kisi != null
                                ? 'Kişi Bilgilerini Düzenle'
                                : 'Yeni Kişi Ekle',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kişi bilgilerini girin. Bu kişiye ait belgeler organize edilecektir.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Profil Fotoğrafı Seçici
                    Text(
                      'Profil Fotoğrafı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProfilFotografiSecici(),

                    const SizedBox(height: 24),

                    // Ad alanı
                    Text(
                      'Ad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adController,
                      focusNode: _adFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Kişinin adını girin',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_soyadFocusNode);
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ad alanı boş olamaz';
                        }
                        if (value.trim().length < 2) {
                          return 'Ad en az 2 karakter olmalıdır';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Soyad alanı
                    Text(
                      'Soyad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _soyadController,
                      focusNode: _soyadFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Kişinin soyadını girin',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _kisiKaydet();
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Soyad alanı boş olamaz';
                        }
                        if (value.trim().length < 2) {
                          return 'Soyad en az 2 karakter olmalıdır';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 40),

                    // Kaydet butonu
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _kayitEdiliyor ? null : _kisiKaydet,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.kisi != null
                                      ? Icons.edit
                                      : Icons.person_add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.kisi != null
                                      ? 'Kişiyi Güncelle'
                                      : 'Kişiyi Kaydet',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // İptal butonu
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              _kayitEdiliyor
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close,
                                  color: Colors.grey.shade600,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'İptal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bilgi notu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tüm alanlar zorunludur ve en az 2 karakter içermelidir.',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfilFotografiSecici() {
    return GestureDetector(
      onTap: _fotografSecenekleri,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color:
                _secilenFoto != null || _mevcutFotoYolu != null
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child:
            _secilenFoto != null || _mevcutFotoYolu != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.file(
                    _secilenFoto ?? File(_mevcutFotoYolu!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
                : Icon(
                  Icons.camera_alt_outlined,
                  size: 30,
                  color: Colors.grey.shade600,
                ),
      ),
    );
  }

  Future<void> _kisiKaydet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Klavyeyi kapat
    FocusScope.of(context).unfocus();

    setState(() {
      _kayitEdiliyor = true;
    });

    try {
      DateTime simdi = DateTime.now();
      String ad = _adController.text.trim();
      String soyad = _soyadController.text.trim();
      String? profilFotografi = await _fotografKaydet();

      if (widget.kisi == null) {
        // Yeni kişi ekle
        KisiModeli yeniKisi = KisiModeli(
          ad: ad,
          soyad: soyad,
          olusturmaTarihi: simdi,
          guncellemeTarihi: simdi,
          profilFotografi: profilFotografi,
        );

        await _veriTabani.kisiEkle(yeniKisi);
        _basariMesajiGoster('Kişi başarıyla eklendi');
      } else {
        // Mevcut kişiyi güncelle
        KisiModeli guncellenmisKisi = widget.kisi!.copyWith(
          ad: ad,
          soyad: soyad,
          guncellemeTarihi: simdi,
          profilFotografi: profilFotografi,
        );

        await _veriTabani.kisiGuncelle(guncellenmisKisi);
        _basariMesajiGoster('Kişi başarıyla güncellendi');
      }

      // Başarılı kayıt sonrası geri dön
      Navigator.of(context).pop(true); // true = başarılı
    } catch (e) {
      _hataGoster('Kişi kaydedilirken hata oluştu: $e');
    } finally {
      if (mounted) {
        setState(() {
          _kayitEdiliyor = false;
        });
      }
    }
  }
}
