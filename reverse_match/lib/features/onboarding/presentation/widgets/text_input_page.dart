import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_scaffold.dart';

/// Shared single-line text input page for fields like hometown, job, school.
class TextInputPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? whyText;
  final String hint;
  final String initialValue;
  final double progress;
  final int minChars;
  final bool optional;
  final TextCapitalization capitalization;
  final ValueChanged<String> onSubmit;
  final VoidCallback onNext;

  const TextInputPage({
    super.key,
    required this.title,
    this.subtitle,
    this.whyText,
    required this.hint,
    this.initialValue = '',
    required this.progress,
    this.minChars = 1,
    this.optional = false,
    this.capitalization = TextCapitalization.words,
    required this.onSubmit,
    required this.onNext,
  });

  @override
  State<TextInputPage> createState() => _TextInputPageState();
}

class _TextInputPageState extends State<TextInputPage> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canProceed =
        widget.optional || _c.text.trim().length >= widget.minChars;

    return OnboardingScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      whyText: widget.whyText,
      progress: widget.progress,
      onSkip: widget.optional ? widget.onNext : null,
      onNext: canProceed
          ? () {
              widget.onSubmit(_c.text.trim());
              widget.onNext();
            }
          : null,
      child: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: widget.capitalization,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: AppColors.textHint),
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
