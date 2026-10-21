import 'package:flutter/material.dart';
import 'section_surface.dart';

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });
  final int number;
  final String title, subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SectionSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

class LabeledFormField extends StatelessWidget {
  const LabeledFormField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.requiredField = false,
    this.validator,
    this.keyboardType,
    this.lines = 1,
    this.autofillHints,
  });
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool requiredField;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int lines;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          text: label,
          children: [
            if (requiredField)
              TextSpan(
                text: ' *',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 8),
      TextFormField(
        key: ValueKey('person-$label'),
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        textCapitalization:
            keyboardType == null
                ? TextCapitalization.words
                : TextCapitalization.none,
        textInputAction:
            lines == 1 ? TextInputAction.next : TextInputAction.newline,
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
      ),
    ],
  );
}
