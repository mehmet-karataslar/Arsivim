import 'dart:math' as math;
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
    final items = destinations.where((item) => item.$1 != 6).toList();
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labels = [
                for (final item in items)
                  switch (item.$1) {
                    0 => 'Ana Sayfa',
                    2 =>
                      constraints.maxWidth < 360 ? 'Kategori' : 'Kategoriler',
                    3 => 'Senkron',
                    _ => item.$2,
                  },
              ];
              final style = DefaultTextStyle.of(context).style.merge(
                const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              );
              final scaler = MediaQuery.textScalerOf(context);
              final minimum = math.max(48.0, 48 * scaler.scale(11) / 11);
              var labelHeight = 0.0;
              for (final label in labels) {
                final painter = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textScaler: scaler,
                  textDirection: Directionality.of(context),
                )..layout();
                labelHeight = math.max(labelHeight, painter.height);
                painter.dispose();
              }
              final width = math.max(
                constraints.maxWidth / items.length,
                minimum,
              );
              // Large accessibility text scrolls instead of shrinking below readable size.
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Semantics(
                        selected: selectedIndex == items[i].$1,
                        button: true,
                        label: items[i].$2,
                        child: Tooltip(
                          message: items[i].$2,
                          excludeFromSemantics: true,
                          child: InkWell(
                            key: ValueKey('navigation-${items[i].$1}'),
                            onTap: () => onSelected(items[i].$1),
                            child: Container(
                              width: width,
                              height: labelHeight + 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 6,
                              ),
                              child: ExcludeSemantics(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color:
                                            selectedIndex == items[i].$1
                                                ? colors.primaryContainer
                                                : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        items[i].$3,
                                        size: 22,
                                        color:
                                            selectedIndex == items[i].$1
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      labels[i],
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: style.copyWith(
                                        color:
                                            selectedIndex == items[i].$1
                                                ? colors.primary
                                                : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
