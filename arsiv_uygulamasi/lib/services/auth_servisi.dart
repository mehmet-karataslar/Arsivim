import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/veritabani_servisi.dart';
import '../services/log_servisi.dart';
import '../services/error_handler_servisi.dart';
import '../models/kisi_modeli.dart';

/// Authentication servisi - kullanıcı giriş/kayıt işlemleri
class AuthServisi {
  static final AuthServisi _instance = AuthServisi._internal();
  static AuthServisi get instance => _instance;
  AuthServisi._internal();

  final VeriTabaniServisi _veriTabani = VeriTabaniServisi();
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;

  KisiModeli? _currentUser;
  bool _isLoggedIn = false;

  // Getters
  KisiModeli? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  /// Şifreyi hash'le
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Kullanıcı kayıt
  Future<AuthResult> register({
    required String ad,
    required String soyad,
    required String kullaniciAdi,
    required String sifre,
  }) async {
    try {
      _logServisi.info('🔐 Kullanıcı kaydı başlatılıyor: $kullaniciAdi');

      // Kullanıcı adı kontrolü
      if (kullaniciAdi.length < 3) {
        return AuthResult(
          success: false,
          message: 'Kullanıcı adı en az 3 karakter olmalıdır.',
        );
      }

      // Şifre kontrolü
      if (sifre.length < 6) {
        return AuthResult(
          success: false,
          message: 'Şifre en az 6 karakter olmalıdır.',
        );
      }

      // Mevcut kullanıcı kontrolü
      final existingUser = await _getUserByUsername(kullaniciAdi);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          message: 'Bu kullanıcı adı zaten kullanılıyor.',
        );
      }

      // Yeni kullanıcı oluştur
      final hashedPassword = _hashPassword(sifre);
      final now = DateTime.now().toIso8601String();

      final user = KisiModeli(
        ad: ad,
        soyad: soyad,
        kullaniciAdi: kullaniciAdi,
        sifre: hashedPassword,
        kullaniciTipi: 'NORMAL',
        olusturmaTarihi: DateTime.parse(now),
        guncellemeTarihi: DateTime.parse(now),
        aktif: true,
      );

      // Veritabanına kaydet
      final userId = await _veriTabani.kisiEkle(user);
      user.id = userId;

      _logServisi.info('✅ Kullanıcı kaydı başarılı: $kullaniciAdi');

      return AuthResult(
        success: true,
        message: 'Kullanıcı başarıyla kaydedildi.',
        user: user,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.register');

      // Veritabanı şema hatası kontrolü
      if (e.toString().contains('kullanici_adi') ||
          e.toString().contains('no column')) {
        return AuthResult(
          success: false,
          message:
              'Veritabanı güncellenmesi gerekiyor. Lütfen uygulamayı yeniden başlatın.',
          needsDatabaseReset: true,
        );
      }

      return AuthResult(
        success: false,
        message: 'Kayıt sırasında bir hata oluştu: $e',
      );
    }
  }

  /// Kullanıcı giriş
  Future<AuthResult> login({
    required String kullaniciAdi,
    required String sifre,
  }) async {
    try {
      _logServisi.info('🔐 Kullanıcı girişi başlatılıyor: $kullaniciAdi');

      // Kullanıcıyı bul
      final user = await _getUserByUsername(kullaniciAdi);
      if (user == null) {
        return AuthResult(success: false, message: 'Kullanıcı bulunamadı.');
      }

      // Şifre kontrolü
      final hashedPassword = _hashPassword(sifre);
      if (user.sifre != hashedPassword) {
        return AuthResult(success: false, message: 'Şifre yanlış.');
      }

      // Kullanıcı aktif mi?
      if (!user.aktif) {
        return AuthResult(
          success: false,
          message: 'Kullanıcı hesabı devre dışı.',
        );
      }

      // Oturumu başlat
      _currentUser = user;
      _isLoggedIn = true;

      // Oturum bilgilerini kaydet
      await _saveUserSession(user);

      _logServisi.info('✅ Kullanıcı girişi başarılı: $kullaniciAdi');

      return AuthResult(success: true, message: 'Giriş başarılı.', user: user);
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.login');
      return AuthResult(
        success: false,
        message: 'Giriş sırasında bir hata oluştu: $e',
      );
    }
  }

  /// QR kod ile giriş
  Future<AuthResult> qrLogin({
    required String kullaniciAdi,
    required String token,
  }) async {
    try {
      _logServisi.info('📱 QR kod ile giriş başlatılıyor: $kullaniciAdi');

      // Kullanıcıyı bul
      final user = await _getUserByUsername(kullaniciAdi);
      if (user == null) {
        return AuthResult(success: false, message: 'Kullanıcı bulunamadı.');
      }

      // Kullanıcı aktif mi?
      if (!user.aktif) {
        return AuthResult(
          success: false,
          message: 'Kullanıcı hesabı devre dışı.',
        );
      }

      // Token geçerlilik kontrolü (basit token kontrolü)
      if (token.isEmpty ||
          (!token.startsWith('qr_login_') && !token.startsWith('pc_mobile_') && !token.startsWith('pc_login_'))) {
        return AuthResult(success: false, message: 'Geçersiz QR kod.');
      }

      // Oturumu başlat
      _currentUser = user;
      _isLoggedIn = true;

      // Oturum bilgilerini kaydet
      await _saveUserSession(user);

      _logServisi.info('✅ QR kod ile giriş başarılı: $kullaniciAdi');

      return AuthResult(
        success: true,
        message: 'QR kod ile giriş başarılı.',
        user: user,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.qrLogin');
      return AuthResult(
        success: false,
        message: 'QR kod ile giriş sırasında bir hata oluştu: $e',
      );
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    try {
      _logServisi.info(
        '🔓 Kullanıcı çıkışı: ${_currentUser?.kullaniciAdi ?? "Bilinmeyen"}',
      );

      _currentUser = null;
      _isLoggedIn = false;

      // Oturum bilgilerini temizle
      await _clearUserSession();

      _logServisi.info('✅ Çıkış başarılı');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.logout');
    }
  }

  /// Otomatik giriş kontrolü
  Future<bool> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('current_user_id');

      if (userId != null) {
        final user = await _getUserById(userId);
        if (user != null && user.aktif) {
          _currentUser = user;
          _isLoggedIn = true;
          _logServisi.info('✅ Otomatik giriş başarılı: ${user.kullaniciAdi}');
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.checkAutoLogin');
      return false;
    }
  }

  /// Kullanıcı adına göre kullanıcı bul
  Future<KisiModeli?> _getUserByUsername(String kullaniciAdi) async {
    try {
      final db = await _veriTabani.database;
      final maps = await db.query(
        'kisiler',
        where: 'kullanici_adi = ? AND aktif = ?',
        whereArgs: [kullaniciAdi, 1],
      );

      if (maps.isNotEmpty) {
        return KisiModeli.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        '_getUserByUsername',
        'kisiler',
      );
      return null;
    }
  }

  /// ID'ye göre kullanıcı bul
  Future<KisiModeli?> _getUserById(int id) async {
    try {
      final db = await _veriTabani.database;
      final maps = await db.query(
        'kisiler',
        where: 'id = ? AND aktif = ?',
        whereArgs: [id, 1],
      );

      if (maps.isNotEmpty) {
        return KisiModeli.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        '_getUserById',
        'kisiler',
      );
      return null;
    }
  }

  /// Oturum bilgilerini kaydet
  Future<void> _saveUserSession(KisiModeli user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_user_id', user.id!);
      await prefs.setString('current_user_name', user.kullaniciAdi ?? '');
      await prefs.setString('login_time', DateTime.now().toIso8601String());
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi._saveUserSession');
    }
  }

  /// Oturum bilgilerini temizle
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
      await prefs.remove('current_user_name');
      await prefs.remove('login_time');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi._clearUserSession');
    }
  }

  /// Şifre değiştir
  Future<AuthResult> changePassword({
    required String eskiSifre,
    required String yeniSifre,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult(success: false, message: 'Oturum açmanız gerekli.');
      }

      // Eski şifre kontrolü
      final hashedOldPassword = _hashPassword(eskiSifre);
      if (_currentUser!.sifre != hashedOldPassword) {
        return AuthResult(success: false, message: 'Eski şifre yanlış.');
      }

      // Yeni şifre kontrolü
      if (yeniSifre.length < 6) {
        return AuthResult(
          success: false,
          message: 'Yeni şifre en az 6 karakter olmalıdır.',
        );
      }

      // Şifreyi güncelle
      final hashedNewPassword = _hashPassword(yeniSifre);
      final db = await _veriTabani.database;

      await db.update(
        'kisiler',
        {
          'sifre': hashedNewPassword,
          'guncelleme_tarihi': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      _logServisi.info('✅ Şifre değiştirildi: ${_currentUser!.kullaniciAdi}');

      return AuthResult(
        success: true,
        message: 'Şifre başarıyla değiştirildi.',
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.changePassword');
      return AuthResult(
        success: false,
        message: 'Şifre değiştirme sırasında bir hata oluştu: $e',
      );
    }
  }

  /// Kullanıcı profili güncelle
  Future<AuthResult> updateProfile({
    required String ad,
    required String soyad,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult(success: false, message: 'Oturum açmanız gerekli.');
      }

      // Profili güncelle
      final db = await _veriTabani.database;

      await db.update(
        'kisiler',
        {
          'ad': ad,
          'soyad': soyad,
          'guncelleme_tarihi': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      // Güncel kullanıcı bilgilerini yükle
      _currentUser = await _getUserById(_currentUser!.id!);

      _logServisi.info('✅ Profil güncellendi: ${_currentUser!.kullaniciAdi}');

      return AuthResult(
        success: true,
        message: 'Profil başarıyla güncellendi.',
        user: _currentUser,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'AuthServisi.updateProfile');
      return AuthResult(
        success: false,
        message: 'Profil güncelleme sırasında bir hata oluştu: $e',
      );
    }
  }

  /// Tüm kullanıcıları listele (admin için)
  Future<List<KisiModeli>> getAllUsers() async {
    try {
      return await _veriTabani.kisileriGetir();
    } catch (e, stackTrace) {
      _errorHandler.handleDatabaseError(
        e,
        stackTrace,
        'getAllUsers',
        'kisiler',
      );
      return [];
    }
  }

  /// Auth servisini kapat
  void dispose() {
    _currentUser = null;
    _isLoggedIn = false;
    _logServisi.info('🔐 Auth servisi kapatıldı');
  }
}

/// Authentication sonucu modeli
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
  String toString() {
    return 'AuthResult(success: $success, message: $message, user: ${user?.kullaniciAdi}, needsDatabaseReset: $needsDatabaseReset)';
  }
}
