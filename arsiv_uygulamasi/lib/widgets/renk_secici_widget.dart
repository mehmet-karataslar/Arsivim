import 'package:flutter/material.dart';

class RenkSeciciWidget extends StatelessWidget {
  final String secilenRenk;
  final Function(String) onRenkSecildi;

  const RenkSeciciWidget({
    Key? key,
    required this.secilenRenk,
    required this.onRenkSecildi,
  }) : super(key: key);

  static const List<Map<String, dynamic>> renkler = [
    {'kod': '#2196F3', 'ad': 'Mavi'},
    {'kod': '#4CAF50', 'ad': 'Yeşil'},
    {'kod': '#FF9800', 'ad': 'Turuncu'},
    {'kod': '#9C27B0', 'ad': 'Mor'},
    {'kod': '#F44336', 'ad': 'Kırmızı'},
    {'kod': '#607D8B', 'ad': 'Gri'},
    {'kod': '#795548', 'ad': 'Kahverengi'},
    {'kod': '#009688', 'ad': 'Turkuaz'},
    {'kod': '#E91E63', 'ad': 'Pembe'},
    {'kod': '#FFEB3B', 'ad': 'Sarı'},
    {'kod': '#3F51B5', 'ad': 'İndigo'},
    {'kod': '#00BCD4', 'ad': 'Cyan'},
    {'kod': '#8BC34A', 'ad': 'Açık Yeşil'},
    {'kod': '#FF5722', 'ad': 'Koyu Turuncu'},
    {'kod': '#673AB7', 'ad': 'Koyu Mor'},
    {'kod': '#FFC107', 'ad': 'Amber'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Renk Seçin',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Seçilen renk önizlemesi
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: _hexToColor(secilenRenk),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Center(
            child: Text(
              _getRenkAdi(secilenRenk),
              style: TextStyle(
                color:
                    _hexToColor(secilenRenk).computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Renk paleti
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: renkler.length,
          itemBuilder: (context, index) {
            final renk = renkler[index];
            final renkKodu = renk['kod'] as String;
            final renkAdi = renk['ad'] as String;
            final secili = secilenRenk == renkKodu;

            return GestureDetector(
              onTap: () => onRenkSecildi(renkKodu),
              child: Container(
                decoration: BoxDecoration(
                  color: _hexToColor(renkKodu),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: secili ? Colors.black : Colors.grey[300]!,
                    width: secili ? 3 : 1,
                  ),
                  boxShadow:
                      secili
                          ? [
                            BoxShadow(
                              color: _hexToColor(renkKodu).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child:
                    secili
                        ? Center(
                          child: Icon(
                            Icons.check,
                            color:
                                _hexToColor(renkKodu).computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                            size: 24,
                          ),
                        )
                        : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  String _getRenkAdi(String renkKodu) {
    final renk = renkler.firstWhere(
      (r) => r['kod'] == renkKodu,
      orElse: () => {'ad': 'Bilinmeyen'},
    );
    return renk['ad'] as String;
  }
}
