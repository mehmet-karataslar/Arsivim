import 'package:flutter/material.dart';
import '../../models/ana_sayfa_ozeti.dart';

class EditorNavigation {
  const EditorNavigation({
    required this.onSelected,
    required this.onStorage,
    required this.onLogout,
    this.summary,
  });
  final ValueChanged<int> onSelected;
  final VoidCallback onStorage, onLogout;
  final AnaSayfaOzeti? summary;
}

class EditorNavigationScope extends InheritedWidget {
  const EditorNavigationScope({
    super.key,
    required this.navigation,
    required super.child,
  });
  final EditorNavigation navigation;
  static EditorNavigation? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<EditorNavigationScope>()
          ?.navigation;
  @override
  bool updateShouldNotify(EditorNavigationScope oldWidget) =>
      navigation != oldWidget.navigation;
}
