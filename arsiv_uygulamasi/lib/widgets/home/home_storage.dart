import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../../theme/app_tones.dart';
import '../../utils/screen_utils.dart';
import '../common/app_card.dart';
import '../common/tone_widgets.dart';

class HomeStorage extends StatelessWidget {
  const HomeStorage({
    super.key,
    required this.summary,
    required this.onSettings,
    this.compact = false,
  });
  final AnaSayfaOzeti? summary;
  final VoidCallback onSettings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ToneBadge(
                icon: Icons.storage_rounded,
                tone: compact ? AppTone.primary : AppTone.blue,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  compact ? 'Kullanılan alan' : 'Depolama alanı',
                  style: TextStyle(
                    fontWeight: compact ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
              ),
              if (!compact)
                IconButton(
                  tooltip: 'Veritabanı bilgileri',
                  onPressed: onSettings,
                  icon: const Icon(Icons.info_outline, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary == null
                ? '—'
                : ScreenUtils.formatFileSize(summary!.dosyaBoyutu),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 18 : 23,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              'Belgelerinizin kullandığı toplam alan',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder:
                  (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in [
                        ('documents', 'Belgeler', AppTone.primary),
                        ('images', 'Görseller', AppTone.amber),
                        ('videos', 'Videolar', AppTone.blue),
                        ('other', 'Diğer', AppTone.neutral),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.circle,
                                  size: 10,
                                  color:
                                      ToneColors.of(
                                        context,
                                        item.$3,
                                      ).foreground,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.$2,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      summary == null
                                          ? '—'
                                          : ScreenUtils.formatFileSize(
                                            summary!.turBoyutlari[item.$1] ?? 0,
                                          ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
