import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';

/// Hinge-style email-first login. Email entry → OTP. Google as a secondary
/// option below.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _valid = false;
  bool _marketingOptOut = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_revalidate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _revalidate() {
    final ok = Validators.email(_emailController.text.trim()) == null;
    if (ok != _valid) setState(() => _valid = ok);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).sendOtp(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state is AuthError) {
        context.showSnackBar(state.message, isError: true);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  "What's your\nemail?",
                  textAlign: TextAlign.center,
                  style: AppTheme.serifHeading(fontSize: 30),
                ),
                const SizedBox(height: 14),
                const Text(
                  "We'll use your email to send you a verification code. It won't be shared with other daters.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) {
                    if (_valid && !isLoading) _submit();
                  },
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    labelText: 'Your email',
                    hintText: 'you@example.com',
                  ),
                ),
                const SizedBox(height: 14),
                _OptOutBox(
                  checked: _marketingOptOut,
                  onChanged: (v) => setState(() => _marketingOptOut = v),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),
                const SizedBox(height: 18),
                _GoogleButton(
                  onPressed: isLoading
                      ? null
                      : () =>
                          ref.read(authProvider.notifier).signInWithGoogle(),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: _valid && !isLoading ? _submit : null,
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'By continuing, you agree to our Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptOutBox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _OptOutBox({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: checked ? AppColors.pill : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: checked ? AppColors.pill : AppColors.inputBorder,
                    width: 1.4,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "If you don't wish to receive marketing communications about our products and services, check this box.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _GoogleGlyph(size: 20),
            SizedBox(width: 12),
            Text('Continue with Google'),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final arcs = [
      (-90.0, _red),
      (0.0, _yellow),
      (90.0, _green),
      (180.0, _blue),
    ];
    for (final (start, color) in arcs) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start * 3.1415926535 / 180,
        90 * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx,
      center.dy - stroke * 0.45,
      radius * 0.7,
      stroke * 0.9,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
