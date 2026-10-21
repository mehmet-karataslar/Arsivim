import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../theme/app_tones.dart';
import '../../utils/screen_utils.dart';
import '../common/metric_grid.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.summary,
    required this.onStorage,
    this.todayCount,
  });
  final AnaSayfaOzeti? summary;
  final VoidCallback onStorage;
  final int? todayCount;
  @override
  Widget build(BuildContext context) => MetricGrid(
    items: [
      MetricData(
        'Toplam belge',
        summary?.belgeSayisi.toString() ?? '—',
        'Arşivinizdeki aktif belgeler',
        Icons.description_rounded,
        AppTone.primary,
      ),
      MetricData(
        todayCount == null ? 'Dosya boyutu' : 'Toplam boyut',
        summary == null
            ? '—'
            : ScreenUtils.formatFileSize(summary!.dosyaBoyutu),
        'Arşivdeki belgelerin toplamı',
        Icons.storage_rounded,
        AppTone.blue,
      ),
      if (todayCount != null)
        MetricData(
          'Bugün eklenen',
          todayCount.toString(),
          'Bugün eklenen yeni belgeler',
          Icons.calendar_today_outlined,
          AppTone.amber,
        )
      else
        MetricData(
          'Son yedekleme',
          summary == null
              ? '—'
              : summary!.sonYedekleme == null
              ? 'Kayıt yok'
              : formatBackupDate(summary!.sonYedekleme!),
          summary?.sonYedekleme == null
              ? 'Henüz kayıtlı yedek yok'
              : 'Başarıyla tamamlandı',
          Icons.cloud_outlined,
          AppTone.amber,
        ),
      MetricData(
        'Kullanılan kategoriler',
        summary?.kategoriSayisi.toString() ?? '—',
        'Arşivinizdeki kategori sayısı',
        Icons.sell_outlined,
        AppTone.purple,
      ),
    ],
  );
  static String formatBackupDate(DateTime date) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
