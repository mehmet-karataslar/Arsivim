import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/scan_page.dart';

class ScanPageView extends StatelessWidget {
  const ScanPageView({super.key, required this.page, this.thumbnail = false});
  final ScanPage page;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) {
    final paper = Center(
      child: AspectRatio(
        aspectRatio: 210 / 297,
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 190 / 210,
              heightFactor: 277 / 297,
              child: RotatedBox(
                quarterTurns: page.quarterTurns,
                child: Image.file(
                  File(page.path),
                  fit: BoxFit.contain,
                  cacheWidth: thumbnail ? 180 : 1600,
                  errorBuilder:
                      (_, error, stack) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return thumbnail
        ? paper
        : InteractiveViewer(
          key: ValueKey('${page.path}-${page.quarterTurns}'),
          minScale: 1,
          maxScale: 5,
          child: paper,
        );
  }
}

class ScanPageStrip extends StatelessWidget {
  const ScanPageStrip({
    super.key,
    required this.pages,
    required this.selected,
    required this.onSelected,
  });
  final List<ScanPage> pages;
  final int selected;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 110,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: pages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder:
          (context, i) => Semantics(
            selected: i == selected,
            label: '${i + 1}. sayfa',
            button: true,
            child: InkWell(
              key: ValueKey('scan-page-$i'),
              onTap: onSelected == null ? null : () => onSelected!(i),
              child: Container(
                width: 70,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        i == selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                    width: i == selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ScanPageView(page: pages[i], thumbnail: true),
                    ),
                    Text('${i + 1}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
    ),
  );
}
