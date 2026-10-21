import 'package:flutter/material.dart';

/// Sabit yükseklik/oran kullanmaz; büyük yazıda kartlar büyüyüp satır değiştirir.
class AdaptiveCardLayout extends StatelessWidget {
  const AdaptiveCardLayout({
    super.key,
    required this.children,
    this.minCardWidth = 240,
    this.maxColumns = 3,
    this.spacing = 16,
  });
  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimum = minCardWidth * scale.clamp(1.0, 1.6);
      final columns = ((constraints.maxWidth + spacing) / (minimum + spacing))
          .floor()
          .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
