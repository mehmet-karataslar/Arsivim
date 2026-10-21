import 'arsiv_hesap_servisi.dart';
import 'auth_servisi.dart';

/// Bilet yeniden baslatmada, oturum degisiminde veya 5 dakika sonra gecersizdir.
class HesapEslesmeServisi {
  final AuthServisi auth;
  final DateTime Function() saat;
  HesapEslesmeServisi(this.auth, {DateTime Function()? saat})
    : saat = saat ?? DateTime.now;
  String? _bilet;
  DateTime? _son;
  int? _oturum;
  bool _mesgul = false;
  Future<void> Function(String ip)? ekYetkiKontrol;
  final Map<String, ({int oturum, String arsiv, String baglanti})> _cihazlar =
      {};

  String baglantiKimligi(String ip) {
    final device = _cihazlar[ip];
    if (device == null || device.oturum != auth.sessionGeneration) {
      throw HesapHatasi('Etkin cihaz oturumu yok.');
    }
    return device.baglanti;
  }

  /// Only call after a persisted device credential has been proven.
  Future<void> guvenilirBaglanti(String ip, Map<String, dynamic> remote) async {
    final session = auth.sessionGeneration;
    final local = await auth.hesapTanitim();
    ArsivHesapServisi.tanitimDogrula(remote);
    if (local['arsiv_id'] != remote['arsiv_id'] ||
        local['yonetici_id'] != remote['yonetici_id'] ||
        session != auth.sessionGeneration) {
      throw HesapHatasi('Tanimli cihaz bu arsive ait degil.');
    }
    _cihazlar[ip] = (
      oturum: session,
      arsiv: local['arsiv_id'] as String,
      baglanti: ArsivHesapServisi.kimlik(),
    );
  }

  /// Reopening a QR must reuse only the current, unused ticket for this session.
  bool biletGecerli(String ticket) =>
      _bilet != null &&
      ticket == _bilet &&
      _son != null &&
      saat().isBefore(_son!) &&
      _oturum == auth.sessionGeneration;

  Future<Map<String, dynamic>> biletOlustur() async {
    if (_mesgul) {
      throw HesapHatasi('Eslesme tamamlanirken yeni QR olusturulamaz.');
    }
    final session = auth.sessionGeneration;
    final account = await auth.hesapTanitim(yeniDogrulama: true);
    if (session != auth.sessionGeneration) throw HesapHatasi('Oturum degisti.');
    _bilet = ArsivHesapServisi.kimlik();
    _son = saat().add(const Duration(minutes: 5));
    _oturum = auth.sessionGeneration;
    return {
      'account_version': 1,
      'pair_ticket': _bilet,
      'pair_expires': _son!.millisecondsSinceEpoch,
      'account': account,
    };
  }

  Future<Map<String, dynamic>> kabulEt(
    String ip,
    Map<String, dynamic> body,
  ) async {
    if (_mesgul) throw HesapHatasi('Baska bir hesap eslesmesi suruyor.');
    final session = auth.sessionGeneration;
    final localId = auth.currentUser?.id;
    _mesgul = true;
    try {
      if (body['account_version'] != 1 ||
          _bilet == null ||
          body['pair_ticket'] != _bilet ||
          _son == null ||
          !saat().isBefore(_son!) ||
          _oturum != auth.sessionGeneration) {
        throw HesapHatasi(
          'QR kodu kullanilmis veya suresi dolmus. Yeni kod olusturun.',
        );
      }
      final local = await auth.hesapTanitim(yeniDogrulama: true);
      final remote = Map<String, dynamic>.from(body['account'] as Map);
      final service = await auth.hesapServisi;
      // Bagli bir cihazin arsivini QR gosteren bagimsiz hesaba cevirmeyiz.
      ArsivHesapServisi.tanitimDogrula(remote);
      if (remote['bagli'] == 1 &&
          (remote['arsiv_id'] != local['arsiv_id'] ||
              remote['yonetici_id'] != local['yonetici_id'])) {
        throw HesapHatasi(
          'QR kodunu zaten arsive bagli olan cihazda olusturun.',
        );
      }
      // Yerel bagli arsiv yeni, bagimsiz bir cihazi kabul edebilir.
      await service.baglantiKontrol(localId!, {
        ...remote,
        'arsiv_id': local['arsiv_id'],
        'yonetici_id': local['yonetici_id'],
      });
      if (session != auth.sessionGeneration) {
        throw HesapHatasi('Oturum degisti.');
      }
      await service.bagla(localId, local);
      _bilet = null;
      if (session != auth.sessionGeneration) {
        throw HesapHatasi('Oturum degisti. Yeniden eslestirin.');
      }
      _cihazlar[ip] = (
        oturum: auth.sessionGeneration,
        arsiv: local['arsiv_id'] as String,
        baglanti: ArsivHesapServisi.kimlik(),
      );
      return await auth.hesapTanitim();
    } finally {
      _mesgul = false;
    }
  }

  Future<void> karsiCihazaBaglanildi(
    String ip,
    Map<String, dynamic> remote,
  ) async {
    final session = auth.sessionGeneration;
    final localId = auth.currentUser?.id;
    await auth.hesapTanitim(yeniDogrulama: true);
    if (session != auth.sessionGeneration) throw HesapHatasi('Oturum degisti.');
    await (await auth.hesapServisi).bagla(localId!, remote);
    if (session != auth.sessionGeneration) {
      throw HesapHatasi('Oturum degisti. Yeniden eslestirin.');
    }
    _cihazlar[ip] = (
      oturum: auth.sessionGeneration,
      arsiv: remote['arsiv_id'] as String,
      baglanti: ArsivHesapServisi.kimlik(),
    );
  }

  Future<void> yetkiKontrol(String ip) async {
    final account = await auth.hesapTanitim();
    final device = _cihazlar[ip];
    if (device == null ||
        device.oturum != auth.sessionGeneration ||
        device.arsiv != account['arsiv_id']) {
      throw HesapHatasi(
        'Cihaz bu yonetici oturumuna bagli degil. Yeniden eslestirin.',
      );
    }
    await ekYetkiKontrol?.call(ip);
  }

  void baglantiKes(String ip) => _cihazlar.remove(ip);
  void temizle() {
    _cihazlar.clear();
    _bilet = null;
  }
}
