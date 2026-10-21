import 'package:flutter/widgets.dart';

/// Dar ekranlar ve telefonun yatay konumu aynı sade yerleşimi kullanır.
abstract final class WorkspaceLayout {
  static bool compact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < 600 || (size.width < 1100 && size.height < 500);
  }
}
