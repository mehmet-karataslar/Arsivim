import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_servisi.dart';
import '../services/log_servisi.dart';
import '../services/error_handler_servisi.dart';
import 'auth/login_screen.dart';
import 'ana_ekran.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _textController;
  late AnimationController _particleController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _welcomeSlideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _glowAnimation;

  final AuthServisi _authServisi = AuthServisi.instance;
  final LogServisi _logServisi = LogServisi.instance;
  final ErrorHandlerServisi _errorHandler = ErrorHandlerServisi.instance;

  final List<String> _welcomeMessages = [
    'Hoş geldiniz',
    'Belgeleriniz güvende',
    'Hızlı ve kolay erişim',
    'Organize arşiv deneyimi',
  ];

  int _currentMessageIndex = 0;
  String _statusText = '';
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _startApp();
  }

  void _initializeAnimations() {
    // Ana animasyon kontrolcüsü
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Metin animasyon kontrolcüsü
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Parçacık animasyon kontrolcüsü
    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Logo scale animasyonu
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Logo rotation animasyonu
    _logoRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Text fade animasyonu
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Welcome slide animasyonu
    _welcomeSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // Progress animasyonu
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Glow animasyonu
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeInOut),
    );
  }

  void _startAnimationSequence() async {
    _mainController.forward();

    // Hoş geldiniz mesajlarını döngüsel göster
    Future.delayed(const Duration(milliseconds: 1000), () {
      _startMessageRotation();
    });
  }

  void _startMessageRotation() {
    if (!mounted) return;

    _textController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;

        _textController.reverse().then((_) {
          setState(() {
            _currentMessageIndex =
                (_currentMessageIndex + 1) % _welcomeMessages.length;
          });
          _startMessageRotation();
        });
      });
    });
  }

  Future<void> _startApp() async {
    try {
      // İlk animasyon için bekleme
      await Future.delayed(const Duration(milliseconds: 1000));

      // Yükleme aşamaları
      final stages = [
        {'text': 'Sistem hazırlanıyor...', 'progress': 0.2},
        {'text': 'Veritabanı kontrol ediliyor...', 'progress': 0.4},
        {'text': 'Güvenlik protokolleri yükleniyor...', 'progress': 0.6},
        {'text': 'Kullanıcı bilgileri alınıyor...', 'progress': 0.8},
        {'text': 'Her şey hazır!', 'progress': 1.0},
      ];

      for (var stage in stages) {
        if (!mounted) return;

        setState(() {
          _statusText = stage['text'] as String;
          _loadingProgress = stage['progress'] as double;
        });

        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Otomatik giriş kontrolü
      final hasAutoLogin = await _authServisi.checkAutoLogin();

      // Son animasyon için bekleme
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        if (hasAutoLogin) {
          _logServisi.info('🏠 Ana ekrana yönlendiriliyor');
          _navigateToHome();
        } else {
          _logServisi.info('🔐 Giriş ekranına yönlendiriliyor');
          _navigateToLogin();
        }
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, stackTrace, 'SplashScreen._startApp');

      setState(() {
        _statusText = 'Bir hata oluştu, yeniden yönlendiriliyorsunuz...';
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const AnaEkran(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).extension<BrandColors>()!;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: brand.background, // Koyu yeşil
      body: Stack(
        children: [
          // Arkaplan gradient ve pattern
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brand.background, // Koyu yeşil
                  Color.lerp(
                    brand.background,
                    brand.accent,
                    0.25,
                  )!, // Orta yeşil
                  Color.lerp(
                    brand.background,
                    brand.accent,
                    0.45,
                  )!, // Açık yeşil
                ],
              ),
            ),
          ),

          // Animasyonlu arkaplan deseni
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticleBackgroundPainter(
                  animation: _particleController.value,
                  glowIntensity: _glowAnimation.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Ana içerik
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),

                  // Logo ve animasyonlar
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _logoRotationAnimation.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      brand.accent, // Yeşil
                                      brand.background, // Koyu yeşil
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: const [],
                                ),
                                child: Icon(
                                  Icons.archive_rounded,
                                  size: 60,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Başlık
                  SlideTransition(
                    position: _welcomeSlideAnimation,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [
                                  brand.accent, // Yeşil
                                  Color.lerp(
                                    brand.accent,
                                    Colors.white,
                                    0.55,
                                  )!, // Açık yeşil
                                  Colors.white, // Beyaz
                                ],
                              ).createShader(bounds),
                          child: const Text(
                            'Arşivim',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dijital Belge Yönetim Sistemi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Hoş geldiniz mesajları
                  SizedBox(
                    height: 40,
                    child: FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Text(
                        _welcomeMessages[_currentMessageIndex],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Yükleme göstergesi ve durum
                  Column(
                    children: [
                      // Modern progress bar
                      Container(
                        width: 250,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: AnimatedBuilder(
                          animation: _mainController,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _loadingProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      brand.accent, // Yeşil
                                      Color.lerp(
                                        brand.accent,
                                        Colors.white,
                                        0.55,
                                      )!, // Açık yeşil
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: const [],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Durum metni
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Alt bilgi
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Verileriniz güvende her zaman',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'v2.1.0 | © 2024 Arşivim Uygulaması',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Arkaplan parçacık painter
class ParticleBackgroundPainter extends CustomPainter {
  final double animation;
  final double glowIntensity;

  ParticleBackgroundPainter({
    required this.animation,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Parçacıklar
    for (int i = 0; i < 50; i++) {
      final x = (i * 73 + animation * size.width) % size.width;
      final y = (i * 37 + animation * size.height * 0.5) % size.height;
      final opacity = (0.1 + (i % 5) * 0.05) * glowIntensity;
      final radius = 1.0 + (i % 3);

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Bağlantı çizgileri
    paint.strokeWidth = 0.5;
    paint.style = PaintingStyle.stroke;

    for (int i = 0; i < 20; i++) {
      final x1 = (i * 137 + animation * size.width * 0.3) % size.width;
      final y1 = (i * 59 + animation * size.height * 0.2) % size.height;
      final x2 = ((i + 1) * 137 + animation * size.width * 0.3) % size.width;
      final y2 = ((i + 1) * 59 + animation * size.height * 0.2) % size.height;

      final distance = ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)).abs();

      if (distance < 10000) {
        paint.color = Colors.white.withOpacity(0.05 * glowIntensity);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(ParticleBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
