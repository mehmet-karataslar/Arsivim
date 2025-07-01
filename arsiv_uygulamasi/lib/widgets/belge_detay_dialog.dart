import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/belge_modeli.dart';
import '../models/kategori_modeli.dart';
import '../models/kisi_modeli.dart';
import '../utils/yardimci_fonksiyonlar.dart';

class BelgeDetayDialog extends StatelessWidget {
  final BelgeModeli belge;
  final KategoriModeli? kategori;
  final KisiModeli? kisi;
  final VoidCallback? onDuzenle;

  const BelgeDetayDialog({
    Key? key,
    required this.belge,
    this.kategori,
    this.kisi,
    this.onDuzenle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(belge.dosyaTipiSimgesi, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              belge.baslik ?? belge.orijinalDosyaAdi,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetayCard(context),
            const SizedBox(height: 16),
            _buildAksiyonlar(context),
          ],
        ),
      ),
      actions: [
        if (onDuzenle != null)
          TextButton(onPressed: onDuzenle, child: const Text('Düzenle')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  Widget _buildDetayCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetayRow('Dosya Adı', belge.dosyaAdi),
            _buildDetayRow('Orijinal Ad', belge.orijinalDosyaAdi),
            _buildDetayRow('Boyut', belge.formatliDosyaBoyutu),
            _buildDetayRow('Tip', belge.dosyaTipi.toUpperCase()),
            _buildDetayRow('Oluşturulma', belge.formatliOlusturmaTarihi),
            _buildDetayRow('Güncelleme', belge.formatliGuncellemeTarihi),
            if (belge.sonErisimTarihi != null)
              _buildDetayRow(
                'Son Erişim',
                YardimciFonksiyonlar.tarihFormatla(belge.sonErisimTarihi!),
              ),
            _buildDetayRow(
              'Senkron Durumu',
              _senkronDurumuText(belge.senkronDurumu),
            ),
            if (kisi != null) _buildDetayRow('Kişi', kisi!.tamAd),
            if (kategori != null)
              _buildDetayRow('Kategori', kategori!.kategoriAdi),
            if (belge.aciklama != null && belge.aciklama!.isNotEmpty)
              _buildDetayRow('Açıklama', belge.aciklama!),
            if (belge.etiketler != null && belge.etiketler!.isNotEmpty)
              _buildDetayRow('Etiketler', belge.etiketler!.join(', ')),
            _buildDetayRow('Dosya Yolu', belge.dosyaYolu, kopyalanabilir: true),
            if (belge.dosyaHash != null)
              _buildDetayRow('Hash', belge.dosyaHash!, kopyalanabilir: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetayRow(
    String baslik,
    String deger, {
    bool kopyalanabilir = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$baslik:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child:
                kopyalanabilir
                    ? GestureDetector(
                      onTap: () => _metniKopyala(deger),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                deger,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            const Icon(Icons.copy, size: 16),
                          ],
                        ),
                      ),
                    )
                    : Text(deger),
          ),
        ],
      ),
    );
  }

  Widget _buildAksiyonlar(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hızlı Aksiyonlar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _dosyaYoluKopyala(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Yolu Kopyala'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _dosyaBilgileriniKopyala(context),
                    icon: const Icon(Icons.info),
                    label: const Text('Bilgileri Kopyala'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _senkronDurumuText(SenkronDurumu durum) {
    switch (durum) {
      case SenkronDurumu.SENKRONIZE:
        return 'Senkronize ✓';
      case SenkronDurumu.BEKLEMEDE:
        return 'Beklemede ⏳';
      case SenkronDurumu.CAKISMA:
        return 'Çakışma ⚠️';
      case SenkronDurumu.HATA:
        return 'Hata ❌';
      case SenkronDurumu.YEREL_DEGISIM:
        return 'Yerel Değişim ↑';
      case SenkronDurumu.UZAK_DEGISIM:
        return 'Uzak Değişim ↓';
    }
  }

  void _metniKopyala(String metin) {
    Clipboard.setData(ClipboardData(text: metin));
  }

  void _dosyaYoluKopyala(BuildContext context) {
    Clipboard.setData(ClipboardData(text: belge.dosyaYolu));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dosya yolu kopyalandı'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _dosyaBilgileriniKopyala(BuildContext context) {
    final bilgiler = '''
Dosya Adı: ${belge.dosyaAdi}
Orijinal Ad: ${belge.orijinalDosyaAdi}
Boyut: ${belge.formatliDosyaBoyutu}
Tip: ${belge.dosyaTipi.toUpperCase()}
Oluşturulma: ${belge.formatliOlusturmaTarihi}
Güncelleme: ${belge.formatliGuncellemeTarihi}
Dosya Yolu: ${belge.dosyaYolu}
${belge.aciklama != null ? 'Açıklama: ${belge.aciklama}' : ''}
${belge.etiketler != null && belge.etiketler!.isNotEmpty ? 'Etiketler: ${belge.etiketler!.join(', ')}' : ''}
''';

    Clipboard.setData(ClipboardData(text: bilgiler));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dosya bilgileri kopyalandı'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  static Future<void> goster(
    BuildContext context,
    BelgeModeli belge, {
    KategoriModeli? kategori,
    KisiModeli? kisi,
  }) async {
    return showDialog<void>(
      context: context,
      builder:
          (context) =>
              BelgeDetayDialog(belge: belge, kategori: kategori, kisi: kisi),
    );
  }
}
