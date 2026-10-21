import 'package:flutter/material.dart';

/// Ortak, gölgesiz kart yüzeyi. Etkileşimli kartlar klavye odağını da destekler.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null ? true : null,
    child: Card(
      color: color,
      shape:
          borderColor == null
              ? null
              : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: borderColor!),
              ),
      child:
          onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
    ),
  );
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: colors.onPrimaryContainer, size: 22),
    );
  }
}
