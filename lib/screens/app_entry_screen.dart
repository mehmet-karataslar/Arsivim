import 'package:flutter/material.dart';
import '../services/app_launch_service.dart';
import 'ana_ekran.dart';
import 'auth/login_screen.dart';
import 'splash_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({
    super.key,
    required this.launch,
    required this.service,
    this.homeBuilder,
    this.loginBuilder,
  });
  final AppLaunchState launch;
  final AppLaunchService service;
  final WidgetBuilder? homeBuilder, loginBuilder;
  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late bool welcome = widget.launch.showWelcome;
  @override
  void initState() {
    super.initState();
    if (welcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await widget.service.markWelcomeSeen();
        } catch (_) {
          // A preference write failure must not block access to the login form.
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (welcome) {
      return SplashScreen(onComplete: () => setState(() => welcome = false));
    }
    return widget.launch.signedIn
        ? (widget.homeBuilder?.call(context) ?? const AnaEkran())
        : (widget.loginBuilder?.call(context) ?? const LoginScreen());
  }
}
