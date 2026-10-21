import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';
import '../home/home_storage.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.summary,
    required this.onStorage,
    required this.onLogout,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AnaSayfaOzeti? summary;
  final VoidCallback onStorage;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: Color.lerp(colors.primary, colors.surface, .97),
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder_rounded,
                            color: colors.onPrimary,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arşivim',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Belgeleriniz her zaman elinizin altında',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  for (final item in [
                    (0, 'Ana Sayfa', Icons.home_rounded),
                    (1, 'Belgeler', Icons.folder_outlined),
                    (2, 'Kategoriler', Icons.category_outlined),
                    (4, 'Kişiler', Icons.people_outline),
                    (3, 'Senkronizasyon', Icons.sync),
                    (6, 'Yedekleme', Icons.cloud_outlined),
                  ])
                    _item(context, item.$1, item.$2, item.$3),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22, horizontal: 6),
                    child: Divider(height: 1),
                  ),
                  _item(context, 5, 'Profil', Icons.person_outline_rounded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: HomeStorage(
                summary: summary,
                compact: true,
                onSettings: onStorage,
              ),
            ),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Çıkış yap'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color:
            selected
                ? colors.primaryContainer
                : colors.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          selected: selected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            icon,
            color: selected ? colors.primary : colors.onSurface,
            size: 25,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          textColor: colors.onSurface,
          selectedColor: colors.onSurface,
          minLeadingWidth: 28,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          onTap: () => onSelected(index),
        ),
      ),
    );
  }
}
