import 'dart:async';
import 'package:flutter/material.dart';

/// A brief, one-time welcome. Session routing is handled before the app starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _completed = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 1), _complete);
  }

  void _complete() {
    if (!mounted || _completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              Icons.folder_rounded,
                              size: 48,
                              color: colors.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Arşivim',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belgeleriniz her zaman elinizin altında.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: _complete,
                            child: const Text('Devam et'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
