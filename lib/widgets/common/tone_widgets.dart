import 'package:flutter/material.dart';
import '../../theme/app_tones.dart';

class ToneBadge extends StatelessWidget {
  const ToneBadge({
    super.key,
    required this.icon,
    this.tone = AppTone.primary,
    this.size = 44,
  });
  final IconData icon;
  final AppTone tone;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, size: size * .54, color: colors.foreground),
    );
  }
}

class ToneButton extends StatelessWidget {
  const ToneButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = AppTone.primary,
    this.dense = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final AppTone tone;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final colors = ToneColors.of(context, tone);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: dense ? const TextStyle(fontSize: 12) : null),
      style: TextButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        minimumSize: const Size(64, 44),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 14,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
  }
}
