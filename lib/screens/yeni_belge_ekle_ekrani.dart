import 'package:flutter/material.dart';
import '../models/belge_modeli.dart';
import '../providers/document_editor_controller.dart';
import '../widgets/document_editor/editor_navigation.dart';
import 'document_editor_screen.dart';

class YeniBelgeEkleEkrani extends StatefulWidget {
  const YeniBelgeEkleEkrani({
    super.key,
    this.duzenlenecekBelge,
    this.navigation,
  });
  final BelgeModeli? duzenlenecekBelge;
  final EditorNavigation? navigation;
  @override
  State<YeniBelgeEkleEkrani> createState() => _YeniBelgeEkleEkraniState();
}

class _YeniBelgeEkleEkraniState extends State<YeniBelgeEkleEkrani> {
  late final controller = DocumentEditorController(
    original: widget.duzenlenecekBelge,
  );
  @override
  Widget build(BuildContext context) => DocumentEditorScreen(
    controller: controller,
    navigation: widget.navigation,
  );
}
