import 'package:flutter/material.dart';
import '../common/section_surface.dart';

class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.title,
    required this.child,
    this.number,
  });
  final String title;
  final int? number;
  final Widget child;
  @override
  Widget build(BuildContext context) => SectionSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child:
                  number == null
                      ? const Icon(Icons.description_outlined, size: 17)
                      : Text('$number', style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class EditorColumns extends StatelessWidget {
  const EditorColumns({
    super.key,
    required this.children,
    this.breakpoint = 700,
  });
  final List<Widget> children;
  final double breakpoint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}
