import 'package:flutter/material.dart';
import '../models/scan_page.dart';
import '../widgets/document_editor/scan_page_view.dart';

class ScanPreviewScreen extends StatefulWidget {
  const ScanPreviewScreen({super.key, required this.pages, required this.name});
  final List<ScanPage> pages;
  final String name;
  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Tarama önizlemesi · ${selected + 1} / ${widget.pages.length}',
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ScanPageView(page: widget.pages[selected]),
            ),
          ),
          ScanPageStrip(
            pages: widget.pages,
            selected: selected,
            onSelected: (i) => setState(() => selected = i),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Yakınlaştırarak sayfaları kontrol edebilirsiniz.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}
