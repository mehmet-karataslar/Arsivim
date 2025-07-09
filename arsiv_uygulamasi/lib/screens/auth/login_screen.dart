import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/auth_servisi.dart';
import '../../services/log_servisi.dart';
import '../../services/error_handler_servisi.dart';
import '../../services/http_sunucu_servisi.dart';
import '../../utils/screen_utils.dart';
import '../../widgets/qr_generator_widget.dart';
import '../ana_ekran.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _kullaniciAdiController = TextEditingController();
  final _sifreController = TextEditingController();

  final AuthServisi _authServisi = AuthServisi.instance;
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;
  final HttpSunucuServisi _httpSunucu = HttpSunucuServisi.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // PC için çift giriş modu
  bool _isQRMode = false;
  String? _qrLoginToken;

  // Platform kontrolü
  bool get _isPCPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (_isPCPlatform) {
      _setupQRLoginListener();
    }
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

  void _setupQRLoginListener() {
    _logServisi.info('🔧 QR Login listener ayarlanıyor...');

    // QR kod ile giriş için HTTP sunucusunu başlat
    _httpSunucu.setOnQRLoginRequest((loginData) async {
      _logServisi.info(
        '📱 QR kod ile giriş isteği alındı: ${loginData['kullanici_adi']}',
      );

      try {
        final result = await _authServisi.qrLogin(
          kullaniciAdi: loginData['kullanici_adi'],
          token: loginData['token'],
        );

        // UI thread'de çalıştır
        if (mounted) {
          if (result.success) {
            _logServisi.info(
              '✅ QR giriş başarılı: ${loginData['kullanici_adi']}',
            );

            // UI güncellemelerini main thread'de yap
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScreenUtils.showSuccessSnackBar(
                  context,
                  'QR kod ile giriş başarılı!',
                );

                // Ana ekrana yönlendir
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                            const AnaEkran(),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                );
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScreenUtils.showErrorSnackBar(context, result.message);
              }
            });
          }
        }
      } catch (e) {
        _logServisi.error('❌ QR giriş hatası: $e');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScreenUtils.showErrorSnackBar(
                context,
                'QR kod ile giriş başarısız.',
              );
            }
          });
        }
      }
    });

    _logServisi.info('✅ QR Login listener ayarlandı');
  }

  void _toggleLoginMode() {
    setState(() {
      _isQRMode = !_isQRMode;
      if (_isQRMode) {
        _generateQRLoginToken();
      }
    });
  }

  void _generateQRLoginToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _qrLoginToken = 'qr_login_${timestamp}_${_httpSunucu.cihazId}';
    _logServisi.info('🔑 QR giriş token oluşturuldu: $_qrLoginToken');
  }

  Future<String> _getLocalIP() async {
    // HTTP sunucusundan gerçek IP adresini al
    final httpSunucu = HttpSunucuServisi.instance;

    // Sunucu çalışıyorsa gerçek IP'yi döndür
    if (httpSunucu.calisiyorMu) {
      final realIP = await httpSunucu.getRealIPAddress();
      if (realIP != null) {
        _logServisi.info('🌐 QR için gerçek IP alındı: $realIP');
        return realIP;
      }
    }

    _logServisi.warning('⚠️ Gerçek IP alınamadı, varsayılan kullanılıyor');
    return '192.168.1.100'; // Varsayılan local IP
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authServisi.login(
        kullaniciAdi: _kullaniciAdiController.text.trim(),
        sifre: _sifreController.text,
      );

      if (mounted) {
        if (result.success) {
          _logServisi.info('✅ Giriş başarılı: ${_kullaniciAdiController.text}');
          ScreenUtils.showSuccessSnackBar(context, result.message);

          // Ana ekrana yönlendir
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => const AnaEkran(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          ScreenUtils.showErrorSnackBar(context, result.message);
        }
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'LoginScreen._login');
      if (mounted) {
        ScreenUtils.showErrorSnackBar(
          context,
          'Giriş sırasında bir hata oluştu.',
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

  void _navigateToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const RegisterScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _kullaniciAdiController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
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
                        const SizedBox(height: 40),

                        // Logo ve başlık
                        _buildHeader(),

                        const SizedBox(height: 40),

                        // PC için giriş modu seçici
                        if (_isPCPlatform) _buildLoginModeSelector(),

                        const SizedBox(height: 20),

                        // Giriş formu veya QR kod
                        _isQRMode ? _buildQRLoginSection() : _buildLoginForm(),

                        const SizedBox(height: 32),

                        // Giriş butonu (sadece normal mod için)
                        if (!_isQRMode) _buildLoginButton(),

                        const SizedBox(height: 24),

                        // Kayıt ol linki (sadece normal mod için)
                        if (!_isQRMode) _buildRegisterLink(),

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
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.folder_special,
            size: 40,
            color: Color(0xFF2E7D32),
          ),
        ),

        const SizedBox(height: 16),

        // Başlık
        Text(
          'Hoş Geldiniz',
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
          'Hesabınıza giriş yapın',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildLoginModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isQRMode) _toggleLoginMode();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isQRMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      !_isQRMode
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login,
                      color:
                          !_isQRMode ? const Color(0xFF2E7D32) : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Normal Giriş',
                      style: TextStyle(
                        color:
                            !_isQRMode ? const Color(0xFF2E7D32) : Colors.white,
                        fontWeight:
                            !_isQRMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isQRMode) _toggleLoginMode();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isQRMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      _isQRMode
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: _isQRMode ? const Color(0xFF2E7D32) : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QR Kod Giriş',
                      style: TextStyle(
                        color:
                            _isQRMode ? const Color(0xFF2E7D32) : Colors.white,
                        fontWeight:
                            _isQRMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRLoginSection() {
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
          const Icon(Icons.qr_code_2, size: 60, color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          const Text(
            'QR Kod ile Giriş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mobil cihazınızdan QR kodu okutarak hızlı giriş yapın',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // QR Kod gösterimi
          if (_qrLoginToken != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  FutureBuilder<String>(
                    future: _getLocalIP(),
                    builder: (context, snapshot) {
                      final serverIP = snapshot.data ?? '192.168.1.100';
                      return QRGeneratorWidget(
                        connectionData: jsonEncode({
                          'type': 'qr_login',
                          'token': _qrLoginToken,
                          'server_ip': serverIP,
                          'server_port': _httpSunucu.port,
                          'timestamp': DateTime.now().toIso8601String(),
                        }),
                        title: 'QR Kod ile Giriş',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QR kodu mobil cihazınızla okutun',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateQRLoginToken,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeni QR Kod'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          ] else ...[
            const CircularProgressIndicator(color: Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            const Text('QR kod oluşturuluyor...'),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
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
          // Kullanıcı adı
          TextFormField(
            controller: _kullaniciAdiController,
            decoration: InputDecoration(
              labelText: 'Kullanıcı Adı',
              prefixIcon: const Icon(Icons.person_outline),
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
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
          ),

          const SizedBox(height: 16),

          // Beni hatırla
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: const Color(0xFF2E7D32),
              ),
              const Text('Beni hatırla'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
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
          onTap: _isLoading ? null : _login,
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
                      'Giriş Yap',
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

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hesabınız yok mu? ',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ),
        GestureDetector(
          onTap: _navigateToRegister,
          child: Text(
            'Kayıt Ol',
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
