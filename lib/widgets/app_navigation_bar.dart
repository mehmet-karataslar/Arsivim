import 'package:flutter/material.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const destinations = [
    (0, 'Ana Sayfa', Icons.home_outlined),
    (1, 'Belgeler', Icons.folder_outlined),
    (2, 'Kategoriler', Icons.category_outlined),
    (4, 'Kişiler', Icons.people_outline),
    (3, 'Senkronizasyon', Icons.sync_rounded),
    (6, 'Yedekleme', Icons.cloud_outlined),
    (5, 'Profil', Icons.person_outline),
  ];

  static String labelFor(int index) =>
      destinations.firstWhere((item) => item.$1 == index).$2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (final destination in destinations)
                    Expanded(
                      child: Semantics(
                        selected: selectedIndex == destination.$1,
                        button: true,
                        label: destination.$2,
                        child: Tooltip(
                          message: destination.$2,
                          excludeFromSemantics: true,
                          child: InkWell(
                            key: ValueKey('navigation-${destination.$1}'),
                            onTap: () => onSelected(destination.$1),
                            child: Container(
                              height: 52,
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    selectedIndex == destination.$1
                                        ? colors.primaryContainer
                                        : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                destination.$3,
                                color:
                                    selectedIndex == destination.$1
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
