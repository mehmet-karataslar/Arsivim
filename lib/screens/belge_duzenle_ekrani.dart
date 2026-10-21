import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../providers/document_editor_controller.dart';
import '../widgets/document_editor/editor_navigation.dart';
import 'document_editor_screen.dart';

class BelgeDuzenleEkrani extends StatefulWidget {
  const BelgeDuzenleEkrani({super.key, required this.belge, this.navigation});
  final BelgeModeli belge;
  final EditorNavigation? navigation;
  @override
  State<BelgeDuzenleEkrani> createState() => _BelgeDuzenleEkraniState();
}

class _BelgeDuzenleEkraniState extends State<BelgeDuzenleEkrani> {
  late final controller = DocumentEditorController(original: widget.belge);
  @override
  Widget build(BuildContext context) => DocumentEditorScreen(
    controller: controller,
    navigation: widget.navigation,
  );
}
