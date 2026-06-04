import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_state.dart';
import '../providers/auth_provider.dart';

/// Hinge-style 6-digit OTP screen. Email-only — submits the verify call
/// against the address the OTP was sent to.
class OtpScreen extends ConsumerStatefulWidget {
  /// Email address the OTP was sent to.
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with TickerProviderStateMixin {
  static const _length = AppConstants.otpLength;

  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_length, (_) => FocusNode());

  int _resendTimer = AppConstants.otpResendSeconds;
  Timer? _timer;
  bool _hasError = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _resendTimer = AppConstants.otpResendSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (_hasError) {
      setState(() => _hasError = false);
    }
    // Multi-digit paste path: spread digits across boxes.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final fillTo = digits.length >= _length ? _length - 1 : digits.length;
      _focusNodes[fillTo].requestFocus();
      setState(() {});
      if (_otp.length == _length) _submit();
      return;
    }

    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == _length) _submit();
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  void _submit() {
    if (_otp.length != _length) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).verifyOtp(widget.email, _otp);
  }

  void _triggerError() {
    setState(() => _hasError = true);
    _shake.forward(from: 0);
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state is AuthError) {
        _triggerError();
        context.showSnackBar(state.message, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).clearError();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Enter your\nverification code',
                      textAlign: TextAlign.center,
                      style: AppTheme.serifHeading(fontSize: 30),
                    ),
                    const SizedBox(height: 40),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) {
                        final v = _shake.value;
                        final offset = v == 0
                            ? 0.0
                            : 10 * (1 - v) * math.sin(v * math.pi * 8);
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          _length,
                          (i) => _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            hasError: _hasError,
                            onKey: (e) => _onKeyDown(i, e),
                            onChanged: (v) => _onChanged(i, v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: InkWell(
                        onTap: () {
                          ref.read(authProvider.notifier).clearError();
                          Navigator.of(context).maybePop();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sent to: ${widget.email}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _ResendRow(
                      secondsLeft: _resendTimer,
                      onResend: isLoading
                          ? null
                          : () {
                              ref
                                  .read(authProvider.notifier)
                                  .sendOtp(widget.email);
                              _startTimer();
                              for (final c in _controllers) {
                                c.clear();
                              }
                              _focusNodes[0].requestFocus();
                            },
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : (_otp.length == _length ? _submit : null),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 28),
                                  child: Text('Verify'),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<KeyEvent> onKey;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onKey,
    required this.onChanged,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _focused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? AppColors.error
        : _focused
            ? AppColors.pill
            : AppColors.inputBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: _focused || widget.hasError ? 1.8 : 1.2,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: widget.onKey,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6, // allow full-code paste into the first box.
          showCursor: true,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback? onResend;

  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: secondsLeft > 0
          ? RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                children: [
                  const TextSpan(text: "Didn't get it? Resend in "),
                  TextSpan(
                    text: '${secondsLeft}s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          : TextButton.icon(
              onPressed: onResend,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Resend code'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
    );
  }
}
