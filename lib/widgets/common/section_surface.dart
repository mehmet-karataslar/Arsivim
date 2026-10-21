import 'workspace_layout.dart';
import 'package:flutter/material.dart';
import 'app_card.dart';

/// Mobilde kart listelerinin etrafına ikinci bir çerçeve eklenmez.
class SectionSurface extends StatelessWidget {
  const SectionSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      WorkspaceLayout.compact(context)
          ? child
          : AppCard(padding: padding, child: child);
}
