import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'arsiv_hesap_servisi.dart';
import 'guvenli_aktarim_servisi.dart';

class BaglantiTanisi {
  static String mesaj(Object error, String asama) {
    final String detail;
    if (error is HesapHatasi) {
      detail = error.mesaj;
    } else if (error is AktarimHatasi) {
      detail = '${error.mesaj} [${error.kod}]';
    } else if (error is SocketException) {
      final refused = [10061, 111, 61].contains(error.osError?.errorCode);
      detail =
          refused
              ? 'Karşı cihaz 8080 bağlantısını reddetti. Telefonda Senkronizasyon sayfasındaki “Bu telefonu bağlantılara aç” seçeneğini açın ve uygulamayı ön planda tutun. IP değiştiyse güncel adresi kullanın veya yeni QR tarayın.'
              : 'Karşı cihazın IP adresine veya 8080 portuna ulaşılamadı. Wi-Fi/hotspot değiştiyse IP değişmiş olabilir. Karşı cihazda uygulama ve sunucu açık olmalı; güncel adresi ve güvenlik duvarını kontrol edin.';
    } else if (error is TimeoutException) {
      detail =
          'Karşı cihaz zamanında yanıt vermedi. Uygulamayı ön planda tutup yeniden deneyin.';
    } else if (error is MissingPluginException) {
      detail =
          'Güvenli cihaz deposu bileşeni yüklenmemiş. Güncel sürümü iki cihazda da tamamen kapatıp yeniden açın; sıcak yenileme yeterli olmayabilir.';
    } else if (error is PlatformException) {
      detail =
          'İşletim sisteminin güvenli cihaz deposuna erişilemedi. Uygulamayı yeniden başlatın; arşiv verilerini silmeyin.';
    } else if (error is FormatException || error is TypeError) {
      detail =
          'Bağlantı yanıtının yapısı uyumsuz. İki cihazda aynı güncel sürümü kullanıp uygulamaları yeniden başlatın.';
    } else {
      detail =
          'Bağlantı işlemi tamamlanamadı (${error.runtimeType}). Arşiv verilerini silmeden uygulamaları yeniden başlatın.';
    }
    return '$asama: $detail';
  }
}
