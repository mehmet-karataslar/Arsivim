import 'package:flutter/material.dart';

/// Senkronizasyon ilerleme durumu enum'u
enum SenkronizasyonAsamasi {
  bagimlilikAnaliz,
  kategorilerGonderiliyor,
  kisilerGonderiliyor,
  belgelerGonderiliyor,
  tamamlandi,
  hata,
}

/// Senkronizasyon progress model'i
class SenkronizasyonIlerleme {
  final SenkronizasyonAsamasi asama;
  final String aciklama;
  final int toplamIslem;
  final int tamamlananIslem;
  final String? hataMesaji;
  final Map<String, int>? detaylar;

  SenkronizasyonIlerleme({
    required this.asama,
    required this.aciklama,
    this.toplamIslem = 0,
    this.tamamlananIslem = 0,
    this.hataMesaji,
    this.detaylar,
  });

  double get yuzde => toplamIslem > 0 ? tamamlananIslem / toplamIslem : 0.0;
}

/// Senkronizasyon Progress Dialog Widget'ı
class SenkronizasyonProgressDialog extends StatefulWidget {
  final Stream<SenkronizasyonIlerleme> ilerlemeSreami;
  final VoidCallback? onTamam;
  final VoidCallback? onIptal;

  const SenkronizasyonProgressDialog({
    Key? key,
    required this.ilerlemeSreami,
    this.onTamam,
    this.onIptal,
  }) : super(key: key);

  @override
  State<SenkronizasyonProgressDialog> createState() =>
      _SenkronizasyonProgressDialogState();
}

class _SenkronizasyonProgressDialogState
    extends State<SenkronizasyonProgressDialog> {
  SenkronizasyonIlerleme? _mevcut;
  bool _tamamlandi = false;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    _streamDinle();
  }

  void _streamDinle() {
    widget.ilerlemeSreami.listen(
      (ilerleme) {
        if (mounted) {
          setState(() {
            _mevcut = ilerleme;
            _tamamlandi = ilerleme.asama == SenkronizasyonAsamasi.tamamlandi;
            _hata = ilerleme.asama == SenkronizasyonAsamasi.hata;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _hata = true;
            _mevcut = SenkronizasyonIlerleme(
              asama: SenkronizasyonAsamasi.hata,
              aciklama: 'Senkronizasyon hatası',
              hataMesaji: error.toString(),
            );
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tamamlandi || _hata,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400, minHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBaslik(),
              const SizedBox(height: 24),
              _buildIcerik(),
              const SizedBox(height: 24),
              _buildButonlar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBaslik() {
    IconData icon;
    Color iconColor;
    String baslik;

    if (_hata) {
      icon = Icons.error;
      iconColor = Colors.red;
      baslik = 'Senkronizasyon Hatası';
    } else if (_tamamlandi) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
      baslik = 'Senkronizasyon Tamamlandı';
    } else {
      icon = Icons.sync;
      iconColor = Colors.blue;
      baslik = 'Senkronizasyon Devam Ediyor';
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            baslik,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ),
        if (!_tamamlandi && !_hata)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
      ],
    );
  }

  Widget _buildIcerik() {
    if (_mevcut == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAsamaGostergesi(),
        const SizedBox(height: 20),
        _buildIlerlemeCarubu(),
        const SizedBox(height: 16),
        _buildAciklama(),
        if (_mevcut?.detaylar != null) ...[
          const SizedBox(height: 16),
          _buildDetaylar(),
        ],
        if (_hata && _mevcut?.hataMesaji != null) ...[
          const SizedBox(height: 16),
          _buildHataMesaji(),
        ],
      ],
    );
  }

  Widget _buildAsamaGostergesi() {
    final asamalar = [
      {
        'icon': Icons.analytics,
        'text': 'Analiz',
        'asama': SenkronizasyonAsamasi.bagimlilikAnaliz,
      },
      {
        'icon': Icons.folder,
        'text': 'Kategoriler',
        'asama': SenkronizasyonAsamasi.kategorilerGonderiliyor,
      },
      {
        'icon': Icons.people,
        'text': 'Kişiler',
        'asama': SenkronizasyonAsamasi.kisilerGonderiliyor,
      },
      {
        'icon': Icons.description,
        'text': 'Belgeler',
        'asama': SenkronizasyonAsamasi.belgelerGonderiliyor,
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          asamalar.map((asama) {
            final mevcutAsama =
                _mevcut?.asama ?? SenkronizasyonAsamasi.bagimlilikAnaliz;
            final aktif =
                _getAsamaSirasi(mevcutAsama) >=
                _getAsamaSirasi(asama['asama'] as SenkronizasyonAsamasi);
            final tamamlandi =
                _getAsamaSirasi(mevcutAsama) >
                _getAsamaSirasi(asama['asama'] as SenkronizasyonAsamasi);

            return Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        tamamlandi
                            ? Colors.green
                            : aktif
                            ? Colors.blue
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    tamamlandi ? Icons.check : asama['icon'] as IconData,
                    color:
                        tamamlandi || aktif ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  asama['text'] as String,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        tamamlandi || aktif ? Colors.black87 : Colors.grey[600],
                    fontWeight:
                        tamamlandi || aktif
                            ? FontWeight.w500
                            : FontWeight.normal,
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  int _getAsamaSirasi(SenkronizasyonAsamasi asama) {
    switch (asama) {
      case SenkronizasyonAsamasi.bagimlilikAnaliz:
        return 0;
      case SenkronizasyonAsamasi.kategorilerGonderiliyor:
        return 1;
      case SenkronizasyonAsamasi.kisilerGonderiliyor:
        return 2;
      case SenkronizasyonAsamasi.belgelerGonderiliyor:
        return 3;
      case SenkronizasyonAsamasi.tamamlandi:
        return 4;
      case SenkronizasyonAsamasi.hata:
        return -1;
    }
  }

  Widget _buildIlerlemeCarubu() {
    final mevcut = _mevcut;
    if (mevcut == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (mevcut.toplamIslem == 0) {
      return LinearProgressIndicator(
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          _hata ? Colors.red : Colors.blue,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İlerleme',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '${mevcut.tamamlananIslem}/${mevcut.toplamIslem}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: mevcut.yuzde,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _hata ? Colors.red : Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(mevcut.yuzde * 100).toStringAsFixed(1)}%',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAciklama() {
    final mevcut = _mevcut;
    if (mevcut == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mevcut.aciklama,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetaylar() {
    final detaylar = _mevcut?.detaylar;
    if (detaylar == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Senkronizasyon Sonuçları',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          ...detaylar.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getDetayBaslik(entry.key),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getDetayBaslik(String key) {
    switch (key) {
      case 'kategoriler_eklendi':
        return 'Kategoriler eklendi:';
      case 'kisiler_eklendi':
        return 'Kişiler eklendi:';
      case 'belgeler_eklendi':
        return 'Belgeler eklendi:';
      case 'hatalar':
        return 'Hatalar:';
      default:
        return key;
    }
  }

  Widget _buildHataMesaji() {
    final hataMesaji = _mevcut?.hataMesaji;
    if (hataMesaji == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hata Detayı',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hataMesaji,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.red[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButonlar() {
    if (!_tamamlandi && !_hata) {
      // Senkronizasyon devam ediyor
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: widget.onIptal,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[600],
            side: BorderSide(color: Colors.grey[400]!),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('İptal'),
        ),
      );
    } else {
      // Tamamlandı veya hata
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onTamam?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _hata ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(_hata ? 'Tamam' : 'Harika!'),
        ),
      );
    }
  }
}

/// Dialog gösterme helper fonksiyonu
Future<void> showSenkronizasyonProgressDialog(
  BuildContext context,
  Stream<SenkronizasyonIlerleme> ilerlemeSreami, {
  VoidCallback? onTamam,
  VoidCallback? onIptal,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => SenkronizasyonProgressDialog(
          ilerlemeSreami: ilerlemeSreami,
          onTamam: onTamam,
          onIptal: onIptal,
        ),
  );
}

/// Senkronizasyon detay progress dialog'u
class SenkronizasyonDetayProgressDialog extends StatefulWidget {
  final String baslik;
  final String aciklama;
  final int toplam;
  final VoidCallback? onIptal;

  const SenkronizasyonDetayProgressDialog({
    Key? key,
    required this.baslik,
    required this.aciklama,
    required this.toplam,
    this.onIptal,
  }) : super(key: key);

  @override
  State<SenkronizasyonDetayProgressDialog> createState() =>
      _SenkronizasyonDetayProgressDialogState();
}

class _SenkronizasyonDetayProgressDialogState
    extends State<SenkronizasyonDetayProgressDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _basarili = false;
  String _durumMesaji = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
    _durumMesaji = widget.aciklama;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void basariliOldu(String mesaj) {
    if (mounted) {
      setState(() {
        _basarili = true;
        _durumMesaji = mesaj;
      });
      _animationController.stop();
      _animationController.value = 1.0;

      // 2 saniye sonra dialog'u kapat
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Geri tuşunu devre dışı bırak
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (_animation.value * 0.4),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _basarili ? Colors.green[100] : Colors.blue[100],
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      _basarili ? Icons.check_circle : Icons.sync,
                      size: 40,
                      color: _basarili ? Colors.green[600] : Colors.blue[600],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              widget.baslik,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _basarili ? Colors.green[700] : Colors.blue[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Açıklama
            Text(
              _durumMesaji,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Progress indicator
            if (!_basarili) ...[
              const LinearProgressIndicator(
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.toplam} öğe işleniyor...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
            ],

            // İptal butonu (sadece işlem devam ederken)
            if (!_basarili && widget.onIptal != null) ...[
              const SizedBox(height: 20),
              TextButton(onPressed: widget.onIptal, child: const Text('İptal')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Basit senkronizasyon progress göstergesi
class BasitSenkronizasyonProgress {
  static void goster({
    required BuildContext context,
    required String baslik,
    required String aciklama,
    required int toplam,
    VoidCallback? onIptal,
  }) {
    final dialogKey = GlobalKey<_SenkronizasyonDetayProgressDialogState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => SenkronizasyonDetayProgressDialog(
            key: dialogKey,
            baslik: baslik,
            aciklama: aciklama,
            toplam: toplam,
            onIptal: onIptal,
          ),
    );
  }

  static void basariliOldu(BuildContext context, String mesaj) {
    // Dialog içindeki state'i bulup güncelle
    final dialogContext =
        context
            .findAncestorStateOfType<_SenkronizasyonDetayProgressDialogState>();
    dialogContext?.basariliOldu(mesaj);
  }

  static void kapat(BuildContext context) {
    Navigator.of(context).pop();
  }
}
