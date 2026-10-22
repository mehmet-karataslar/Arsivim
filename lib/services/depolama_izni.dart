import 'package:permission_handler/permission_handler.dart';

/// Açık arşiv klasörü için Android sürümünün desteklediği izni ister.
Future<void> androidDepolamaIzniIste(int sdkInt) async {
  // Android 11+ tüm dosya erişimi kullanır. Eski storage izni Android 13+
  // sürümlerinde kaldırılmıştır; manifest uyarısına ve gereksiz redde yol açar.
  final permission =
      sdkInt >= 30 ? Permission.manageExternalStorage : Permission.storage;
  if (!await permission.isGranted) {
    await permission.request();
  }
}
