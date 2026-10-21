import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/kisi_modeli.dart';
import 'veritabani_servisi.dart';
import 'arsiv_hesap_servisi.dart';
import 'parola_servisi.dart';

class AuthServisi {
  static final AuthServisi instance = AuthServisi._internal();
  AuthServisi._internal();
  AuthServisi.test(Database db) : _testDb = db;
  Database? _testDb;
  Future<Database> get _db async =>
      _testDb ?? await VeriTabaniServisi().database;
  Future<ArsivHesapServisi> get hesapServisi async =>
      ArsivHesapServisi(await _db);
  KisiModeli? _currentUser;
  DateTime? _sonDogrulama;
  int _sessionGeneration = 0;
  int _basarisiz = 0;
  DateTime? _bekle;
  KisiModeli? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  int get sessionGeneration => _sessionGeneration;

  Future<AuthResult> register({
    required String ad,
    required String soyad,
    required String kullaniciAdi,
    required String sifre,
  }) async {
    try {
      if (ad.trim().isEmpty ||
          soyad.trim().isEmpty ||
          kullaniciAdi.trim().length < 3) {
        throw HesapHatasi(
          'Ad, soyad ve en az 3 karakterli kullanici adi gerekli.',
        );
      }
      final now = DateTime.now().toIso8601String();
      final id = await (await hesapServisi).kaydet({
        'ad': ad.trim(),
        'soyad': soyad.trim(),
        'kullanici_adi': kullaniciAdi.trim(),
        'aktif': 1,
        'olusturma_tarihi': now,
        'guncelleme_tarihi': now,
      }, sifre);
      return AuthResult(
        success: true,
        message: 'Tek yonetici hesabi olusturuldu. Giris yapabilirsiniz.',
        user: await _getUserById(id),
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> girisAdaylari(String username) async =>
      (await hesapServisi).girisAdaylari(username);

  Future<AuthResult> login({
    required String kullaniciAdi,
    required String sifre,
    int? kisiId,
  }) async {
    try {
      if (_bekle != null && DateTime.now().isBefore(_bekle!)) {
        throw HesapHatasi(
          'Cok sayida hatali deneme. 30 saniye sonra yeniden deneyin.',
        );
      }
      final row = await (await hesapServisi).giris(
        kullaniciAdi,
        sifre,
        secilenKisiId: kisiId,
      );
      final user = KisiModeli.fromMap(row);
      await _saveUserSession(user);
      if (_currentUser?.id != user.id || _currentUser?.sifre != user.sifre)
        _sessionGeneration++;
      _currentUser = user;
      _sonDogrulama = DateTime.now();
      _basarisiz = 0;
      _bekle = null;
      return AuthResult(
        success: true,
        message: 'Yonetici girisi basarili.',
        user: user,
      );
    } catch (e) {
      if (++_basarisiz >= 5)
        _bekle = DateTime.now().add(const Duration(seconds: 30));
      return AuthResult(success: false, message: e.toString());
    }
  }

  Future<AuthResult> yoneticiDogrula(String password) async {
    final user = _currentUser;
    if (user == null)
      return AuthResult(
        success: false,
        message: 'Once yonetici hesabiniza giris yapin.',
      );
    return login(
      kullaniciAdi: user.kullaniciAdi!,
      sifre: password,
      kisiId: user.id,
    );
  }

  Future<Map<String, dynamic>> hesapTanitim({
    bool yeniDogrulama = false,
  }) async {
    final user = _currentUser;
    if (user?.id == null) throw HesapHatasi('Yonetici girisi gerekli.');
    if (yeniDogrulama &&
        (_sonDogrulama == null ||
            DateTime.now().difference(_sonDogrulama!) >
                const Duration(minutes: 5))) {
      throw HesapHatasi(
        'Cihaz eslestirmek icin yonetici sifrenizi yeniden dogrulayin.',
      );
    }
    final service = await hesapServisi;
    final current = await service.yonetici(user!.id!);
    if (current['sifre'] != user.sifre)
      throw HesapHatasi('Sifre degisti. Yeniden giris yapin.');
    return service.tanitim(user.id!);
  }

  /// Eski, sadece token onekini kontrol eden QR girisi devre disidir.
  Future<AuthResult> qrLogin({
    required String kullaniciAdi,
    required String token,
  }) async => AuthResult(
    success: false,
    message:
        'Eski QR girisi kapatildi. Sifrenizle giris yapip cihaz eslestirin.',
  );

  Future<void> logout() async {
    _currentUser = null;
    _sonDogrulama = null;
    _sessionGeneration++;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'current_user_id',
      'current_user_name',
      'login_time',
      'account_session_version',
      'account_session_proof',
    ]) {
      await prefs.remove(key);
    }
  }

  Future<bool> checkAutoLogin() async {
    _currentUser = null;
    _sonDogrulama = null;
    _sessionGeneration++;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('account_session_version') != 2) return false;
      final userId = prefs.getInt('current_user_id');
      final owner = await (await hesapServisi).hesap();
      if (userId == null || owner?['yerel_kisi_id'] != userId) return false;
      final user = await _getUserById(userId);
      if (user == null ||
          _proof(user) != prefs.getString('account_session_proof'))
        return false;
      _currentUser = user.copyWith(kullaniciTipi: 'ADMIN');
      return true;
    } catch (_) {
      return false;
    }
  }

  String _proof(KisiModeli user) =>
      sha256.convert(utf8.encode('${user.id}:${user.sifre}')).toString();

  Future<void> _saveUserSession(KisiModeli user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', user.id!);
    await prefs.setString('current_user_name', user.kullaniciAdi ?? '');
    await prefs.setString('login_time', DateTime.now().toIso8601String());
    await prefs.setString('account_session_proof', _proof(user));
    await prefs.setInt('account_session_version', 2);
  }

  Future<KisiModeli?> _getUserById(int id) async {
    final rows = await (await _db).query(
      'kisiler',
      where: 'id = ? AND aktif = 1',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : KisiModeli.fromMap(rows.single);
  }

  Future<AuthResult> changePassword({
    required String eskiSifre,
    required String yeniSifre,
  }) async {
    try {
      if (yeniSifre.length < 6 || yeniSifre.length > 1024)
        throw HesapHatasi('Sifre 6-1024 karakter olmali.');
      await hesapTanitim();
      final user = _currentUser!;
      final row = await (await hesapServisi).yonetici(user.id!);
      if (!await ParolaServisi.dogrula(eskiSifre, row['sifre'] as String))
        throw HesapHatasi('Eski sifre yanlis.');
      final value = await ParolaServisi.olustur(yeniSifre);
      final count = await (await _db).update(
        'kisiler',
        {'sifre': value, 'guncelleme_tarihi': DateTime.now().toIso8601String()},
        where: 'id = ? AND sifre = ? AND aktif = 1',
        whereArgs: [user.id, row['sifre']],
      );
      if (count != 1) throw HesapHatasi('Hesap degisti; yeniden giris yapin.');
      _currentUser = (await _getUserById(
        user.id!,
      ))!.copyWith(kullaniciTipi: 'ADMIN');
      _sessionGeneration++;
      _sonDogrulama = DateTime.now();
      await _saveUserSession(_currentUser!);
      return AuthResult(
        success: true,
        message:
            'Bu cihazin sifresi degisti. Diger cihazdaki yerel sifre korunur.',
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  Future<AuthResult> updateProfile({
    required String ad,
    required String soyad,
  }) async {
    try {
      await hesapTanitim();
      if (ad.trim().isEmpty || soyad.trim().isEmpty)
        throw HesapHatasi('Ad ve soyad gerekli.');
      await (await _db).update(
        'kisiler',
        {
          'ad': ad.trim(),
          'soyad': soyad.trim(),
          'guncelleme_tarihi': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );
      _currentUser = (await _getUserById(
        _currentUser!.id!,
      ))!.copyWith(kullaniciTipi: 'ADMIN');
      return AuthResult(
        success: true,
        message: 'Profil guncellendi.',
        user: _currentUser,
      );
    } catch (e) {
      return AuthResult(success: false, message: e.toString());
    }
  }

  Future<List<KisiModeli>> getAllUsers() async {
    await hesapTanitim();
    return (await (await _db).query(
      'kisiler',
      where: 'aktif = 1',
    )).map(KisiModeli.fromMap).toList();
  }

  void dispose() {
    _currentUser = null;
    _sonDogrulama = null;
    _sessionGeneration++;
  }
}

class AuthResult {
  final bool success;
  final String message;
  final KisiModeli? user;
  final bool needsDatabaseReset;
  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.needsDatabaseReset = false,
  });
  @override
  String toString() => 'AuthResult(success: $success, message: $message)';
}
