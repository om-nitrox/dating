import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

/// Hinge-style birthday entry — three side-by-side boxes (Month / Day / Year).
/// On full + valid entry, a bottom sheet confirms the user's age.
class DobScreen extends ConsumerStatefulWidget {
  const DobScreen({super.key});

  @override
  ConsumerState<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends ConsumerState<DobScreen> {
  final _monthCtl = TextEditingController();
  final _dayCtl = TextEditingController();
  final _yearCtl = TextEditingController();
  final _monthFocus = FocusNode();
  final _dayFocus = FocusNode();
  final _yearFocus = FocusNode();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    final dob = ref.read(onboardingProvider).dob;
    if (dob != null) {
      _monthCtl.text = dob.month.toString().padLeft(2, '0');
      _dayCtl.text = dob.day.toString().padLeft(2, '0');
      _yearCtl.text = dob.year.toString();
      _confirmed = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _monthFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in [_monthCtl, _dayCtl, _yearCtl]) {
      c.dispose();
    }
    for (final f in [_monthFocus, _dayFocus, _yearFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  DateTime? get _dob {
    final m = int.tryParse(_monthCtl.text);
    final d = int.tryParse(_dayCtl.text);
    final y = int.tryParse(_yearCtl.text);
    if (m == null || d == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > DateTime.now().year) {
      return null;
    }
    try {
      final dt = DateTime(y, m, d);
      // Reject out-of-range days (e.g. Feb 30 normalizes forward in Dart).
      if (dt.month != m || dt.day != d) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  int? get _age {
    final dob = _dob;
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      a--;
    }
    return a;
  }

  Future<void> _openAgeSheet() async {
    final age = _age;
    if (age == null) return;
    FocusScope.of(context).unfocus();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AgeConfirmSheet(age: age, eligible: age >= 18),
    );

    if (!mounted) return;
    if (confirmed == true && age >= 18) {
      setState(() => _confirmed = true);
    } else {
      // User tapped "Edit" — re-focus the day box for quick correction.
      _dayFocus.requestFocus();
    }
  }

  void _onDigitChanged(int field, String value) {
    setState(() {});
    if (field == 0 && value.length == 2) _dayFocus.requestFocus();
    if (field == 1 && value.length == 2) _yearFocus.requestFocus();
    if (field == 2 && value.length == 4) {
      // Full → show confirm sheet.
      if (_dob != null) _openAgeSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;
    final canProceed = _confirmed && age != null && age >= 18;

    return OnboardingScaffold(
      title: "When's your\nbirthday?",
      subtitle: "We'll only show your age on your profile.",
      progress: OnboardingSteps.progress('/onboarding/dob'),
      onNext: canProceed
          ? () {
              ref.read(onboardingProvider.notifier).setDob(_dob!);
              context.push(OnboardingSteps.next('/onboarding/dob')!);
            }
          : null,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  controller: _monthCtl,
                  focusNode: _monthFocus,
                  hint: 'Month',
                  maxLength: 2,
                  onChanged: (v) => _onDigitChanged(0, v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBox(
                  controller: _dayCtl,
                  focusNode: _dayFocus,
                  hint: 'Day',
                  maxLength: 2,
                  onChanged: (v) => _onDigitChanged(1, v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _DateBox(
                  controller: _yearCtl,
                  focusNode: _yearFocus,
                  hint: 'Year',
                  maxLength: 4,
                  onChanged: (v) => _onDigitChanged(2, v),
                ),
              ),
            ],
          ),
          if (age != null && !_confirmed && _dob != null) ...[
            const SizedBox(height: 22),
            TextButton(
              onPressed: _openAgeSheet,
              child: const Text('Confirm your age'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final int maxLength;
  final ValueChanged<String> onChanged;

  const _DateBox({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.maxLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      ),
      onChanged: onChanged,
    );
  }
}

class _AgeConfirmSheet extends StatelessWidget {
  final int age;
  final bool eligible;

  const _AgeConfirmSheet({required this.age, required this.eligible});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            eligible ? "You're $age" : 'Must be 18+',
            style: AppTheme.serifHeading(fontSize: 24),
          ),
          const SizedBox(height: 10),
          Text(
            eligible
                ? 'Make sure your age is correct before moving on. It keeps Reverse Match real for everyone.'
                : 'You must be at least 18 to use Reverse Match. Please edit your date of birth.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      eligible ? () => Navigator.pop(context, true) : null,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
