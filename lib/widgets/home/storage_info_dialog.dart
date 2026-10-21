import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StorageInfoDialog extends StatelessWidget {
  const StorageInfoDialog({
    super.key,
    required this.path,
    required this.size,
    required this.version,
    required this.exists,
  });
  final String path;
  final String size;
  final int version;
  final bool exists;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Veritabanı bilgileri'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(
              context,
              'Durum',
              exists ? 'Dosya mevcut' : 'Dosya bulunamadı',
            ),
            _field(context, 'Veritabanı boyutu', size),
            _field(context, 'Şema sürümü', version.toString()),
            _field(context, 'Dosya konumu', path),
            const Text(
              'Bu bilgi veritabanı dosyasına aittir. Belgelerin toplam boyutu ana sayfada ayrıca gösterilir.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: path));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Konum kopyalandı.')));
          }
        },
        icon: const Icon(Icons.copy, size: 18),
        label: const Text('Konumu kopyala'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Kapat'),
      ),
    ],
  );

  Widget _field(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );
}
