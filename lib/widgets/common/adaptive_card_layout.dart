import 'package:flutter/material.dart';

/// Sabit yükseklik/oran kullanmaz; büyük yazıda kartlar büyüyüp satır değiştirir.
class AdaptiveCardLayout extends StatelessWidget {
  const AdaptiveCardLayout({
    super.key,
    required this.children,
    this.minCardWidth = 240,
    this.maxColumns = 3,
    this.spacing = 16,
    this.allowedColumns,
    this.equalHeightRows = false,
  });
  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;
  final double spacing;
  final List<int>? allowedColumns;
  final bool equalHeightRows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimum = minCardWidth * scale.clamp(1.0, 1.6);
      var columns = ((constraints.maxWidth + spacing) / (minimum + spacing))
          .floor()
          .clamp(1, maxColumns);
      if (allowedColumns != null && allowedColumns!.isNotEmpty) {
        final allowed = [...allowedColumns!]..sort();
        columns =
            allowed.where((count) => count <= columns).lastOrNull ??
            allowed.first;
      }
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      if (equalHeightRows) {
        // Yalnızca az sayıdaki özet kartları için satır yüksekliğini eşitle.
        return Column(
          children: [
            for (var start = 0; start < children.length; start += columns) ...[
              if (start > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) SizedBox(width: spacing),
                      Expanded(
                        child:
                            start + col < children.length
                                ? children[start + col]
                                : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      }
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
