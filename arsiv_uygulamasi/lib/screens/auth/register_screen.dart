import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_servisi.dart';
import '../../services/log_servisi.dart';
import '../../services/error_handler_servisi.dart';
import '../../services/veritabani_servisi.dart';
import '../../utils/screen_utils.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _kullaniciAdiController = TextEditingController();
  final _sifreController = TextEditingController();
  final _sifreTekrarController = TextEditingController();

  final AuthServisi _authServisi = AuthServisi.instance;
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;


    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authServisi.register(
        ad: _adController.text.trim(),
        soyad: _soyadController.text.trim(),
        kullaniciAdi: _kullaniciAdiController.text.trim(),
        sifre: _sifreController.text,
      );

      if (mounted) {
        if (result.success) {
          _logServisi.info('✅ Kayıt başarılı: ${_kullaniciAdiController.text}');
          ScreenUtils.showSuccessSnackBar(context, result.message);

          // Giriş ekranına dön
          Navigator.of(context).pop();
        } else {
          // Veritabanı sıfırlama gerekiyor mu?
          if (result.needsDatabaseReset) {
            _showDatabaseResetDialog();
          } else {
            ScreenUtils.showErrorSnackBar(context, result.message);
          }
        }
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'RegisterScreen._register');
      if (mounted) {
        ScreenUtils.showErrorSnackBar(
          context,
          'Kayıt sırasında bir hata oluştu.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pop();
  }

  /// Veritabanı sıfırlama dialog'u göster
  void _showDatabaseResetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Veritabanı Güncellemesi Gerekli'),
            content: const Text(
              'Veritabanı şeması güncellenmiş. Uygulamanın düzgün çalışması için veritabanını sıfırlamanız gerekmektedir.\n\n'
              'Bu işlem mevcut verilerinizi silecektir. Devam etmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Ana ekrana dön
                  Navigator.pop(context);
                },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _resetDatabase();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Veritabanını Sıfırla'),
              ),
            ],
          ),
    );
  }

  /// Veritabanını sıfırla
  Future<void> _resetDatabase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final veriTabani = VeriTabaniServisi();
      await veriTabani.resetDatabase();

      if (mounted) {
        ScreenUtils.showSuccessSnackBar(
          context,
          'Veritabanı başarıyla sıfırlandı. Şimdi kayıt olabilirsiniz.',
        );
        // Form alanlarını temizle
        _adController.clear();
        _soyadController.clear();
        _kullaniciAdiController.clear();
        _sifreController.clear();
        _sifreTekrarController.clear();
        setState(() {
          _acceptTerms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScreenUtils.showErrorSnackBar(
          context,
          'Veritabanı sıfırlanırken hata oluştu: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _adController.dispose();
    _soyadController.dispose();
    _kullaniciAdiController.dispose();
    _sifreController.dispose();
    _sifreTekrarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32), // Beyaz alan önleme için
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Geri butonu ve başlık
                        _buildHeader(),

                        const SizedBox(height: 40),

                        // Kayıt formu
                        _buildRegisterForm(),

                        const SizedBox(height: 24),

                        const SizedBox(height: 24),

                        // Kayıt butonu
                        _buildRegisterButton(),

                        const SizedBox(height: 24),

                        // Giriş linki
                        _buildLoginLink(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Geri butonu ve logo
        Row(
          children: [
            IconButton(
              onPressed: _navigateToLogin,
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            ),
            const Spacer(),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_add,
                size: 30,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48), // Balance for back button
          ],
        ),

        const SizedBox(height: 16),

        // Başlık
        Text(
          'Hesap Oluştur',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Yeni hesabınızı oluşturun',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ad
          TextFormField(
            controller: _adController,
            decoration: InputDecoration(
              labelText: 'Ad',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Ad gerekli';
              }
              if (value!.length < 2) {
                return 'Ad en az 2 karakter olmalı';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 16),

          // Soyad
          TextFormField(
            controller: _soyadController,
            decoration: InputDecoration(
              labelText: 'Soyad',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Soyad gerekli';
              }
              if (value!.length < 2) {
                return 'Soyad en az 2 karakter olmalı';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 16),

          // Kullanıcı adı
          TextFormField(
            controller: _kullaniciAdiController,
            decoration: InputDecoration(
              labelText: 'Kullanıcı Adı',
              prefixIcon: const Icon(Icons.alternate_email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Kullanıcı adı gerekli';
              }
              if (value!.length < 3) {
                return 'Kullanıcı adı en az 3 karakter olmalı';
              }
              if (value.contains(' ')) {
                return 'Kullanıcı adı boşluk içeremez';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          // Şifre
          TextFormField(
            controller: _sifreController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Şifre gerekli';
              }
              if (value!.length < 6) {
                return 'Şifre en az 6 karakter olmalı';
              }
              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          // Şifre tekrar
          TextFormField(
            controller: _sifreTekrarController,
            obscureText: _obscurePasswordConfirm,
            decoration: InputDecoration(
              labelText: 'Şifre Tekrar',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordConfirm
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePasswordConfirm = !_obscurePasswordConfirm;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Şifre tekrarı gerekli';
              }
              if (value != _sifreController.text) {
                return 'Şifreler eşleşmiyor';
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            activeColor: Colors.white,
            checkColor: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors:
              _isLoading
                  ? [Colors.grey, Colors.grey[400]!]
                  : [const Color(0xFF2E7D32), const Color(0xFF4CAF50)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _register,
          child: Center(
            child:
                _isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Hesap Oluştur',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Zaten hesabınız var mı? ',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ),
        GestureDetector(
          onTap: _navigateToLogin,
          child: Text(
            'Giriş Yap',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
