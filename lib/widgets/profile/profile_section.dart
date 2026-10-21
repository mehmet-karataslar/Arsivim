import '../common/workspace_layout.dart';
import 'package:flutter/material.dart';
import '../common/section_surface.dart';

class ProfileInset extends StatelessWidget {
  const ProfileInset({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: WorkspaceLayout.compact(context) ? 12 : 0,
    ),
    child: child,
  );
}

/// Telefonda dış çerçeve yoktur. Metinlerin iç boşluğu kartları daraltmaz.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.edgeToEdge = false,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) {
    final inset = WorkspaceLayout.compact(context) ? 12.0 : 0.0;
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset, vertical: 16),
            child: const Divider(height: 1),
          ),
          if (edgeToEdge)
            child
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: child,
            ),
        ],
      ),
    );
  }
}
