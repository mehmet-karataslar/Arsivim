import 'package:flutter/material.dart';

class SimgeSeciciWidget extends StatelessWidget {
  final String secilenSimge;
  final Function(String) onSimgeSecildi;

  const SimgeSeciciWidget({
    Key? key,
    required this.secilenSimge,
    required this.onSimgeSecildi,
  }) : super(key: key);

  static const List<Map<String, dynamic>> simgeler = [
    {'kod': 'folder', 'icon': Icons.folder, 'ad': 'Klasör'},
    {'kod': 'description', 'icon': Icons.description, 'ad': 'Belge'},
    {'kod': 'image', 'icon': Icons.image, 'ad': 'Resim'},
    {'kod': 'videocam', 'icon': Icons.videocam, 'ad': 'Video'},
    {'kod': 'music_note', 'icon': Icons.music_note, 'ad': 'Müzik'},
    {'kod': 'archive', 'icon': Icons.archive, 'ad': 'Arşiv'},
    {'kod': 'work', 'icon': Icons.work, 'ad': 'İş'},
    {'kod': 'school', 'icon': Icons.school, 'ad': 'Okul'},
    {'kod': 'home', 'icon': Icons.home, 'ad': 'Ev'},
    {'kod': 'favorite', 'icon': Icons.favorite, 'ad': 'Favori'},
    {'kod': 'star', 'icon': Icons.star, 'ad': 'Yıldız'},
    {'kod': 'bookmark', 'icon': Icons.bookmark, 'ad': 'Yer İmi'},
    {'kod': 'label', 'icon': Icons.label, 'ad': 'Etiket'},
    {'kod': 'category', 'icon': Icons.category, 'ad': 'Kategori'},
    {'kod': 'shopping_cart', 'icon': Icons.shopping_cart, 'ad': 'Alışveriş'},
    {'kod': 'restaurant', 'icon': Icons.restaurant, 'ad': 'Yemek'},
    {'kod': 'sports_soccer', 'icon': Icons.sports_soccer, 'ad': 'Spor'},
    {'kod': 'travel_explore', 'icon': Icons.travel_explore, 'ad': 'Seyahat'},
    {
      'kod': 'health_and_safety',
      'icon': Icons.health_and_safety,
      'ad': 'Sağlık',
    },
    {'kod': 'savings', 'icon': Icons.savings, 'ad': 'Para'},
    {'kod': 'pets', 'icon': Icons.pets, 'ad': 'Evcil Hayvan'},
    {'kod': 'directions_car', 'icon': Icons.directions_car, 'ad': 'Araba'},
    {'kod': 'build', 'icon': Icons.build, 'ad': 'Araç'},
    {'kod': 'lightbulb', 'icon': Icons.lightbulb, 'ad': 'Fikir'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Simge Seçin',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Seçilen simge önizlemesi
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIconData(secilenSimge), size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                _getSimgeAdi(secilenSimge),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Simge paleti
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: simgeler.length,
          itemBuilder: (context, index) {
            final simge = simgeler[index];
            final simgeKodu = simge['kod'] as String;
            final simgeIcon = simge['icon'] as IconData;
            final secili = secilenSimge == simgeKodu;

            return GestureDetector(
              onTap: () => onSimgeSecildi(simgeKodu),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      secili ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: secili ? Colors.blue : Colors.grey[300]!,
                    width: secili ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    simgeIcon,
                    size: 24,
                    color: secili ? Colors.blue : Colors.grey[700],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getIconData(String iconCode) {
    final simge = simgeler.firstWhere(
      (s) => s['kod'] == iconCode,
      orElse: () => {'icon': Icons.folder},
    );
    return simge['icon'] as IconData;
  }

  String _getSimgeAdi(String simgeKodu) {
    final simge = simgeler.firstWhere(
      (s) => s['kod'] == simgeKodu,
      orElse: () => {'ad': 'Bilinmeyen'},
    );
    return simge['ad'] as String;
  }
}
