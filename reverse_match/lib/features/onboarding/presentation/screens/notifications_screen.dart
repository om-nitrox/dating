import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../onboarding_steps.dart';

/// Hinge-style "Don't miss when someone wants to connect" notification
/// permission step. Tapping the toggle prompts the OS permission dialog.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _granted = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() => _granted = status.isGranted);
  }

  Future<void> _toggle(bool requested) async {
    if (!requested || _requesting) return;
    setState(() => _requesting = true);
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() {
      _granted = status.isGranted;
      _requesting = false;
    });
  }

  void _next() =>
      context.push(OnboardingSteps.next('/onboarding/notifications')!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background image placeholder — solid sky-ish gradient since the
          // hands-shake hero image isn't shipped in assets.
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceVariant,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Text(
                    "Don't miss\nwhen someone\nwants to connect",
                    textAlign: TextAlign.center,
                    style: AppTheme.serifHeading(fontSize: 26),
                  ),
                  const Spacer(),
                  _ToggleRow(
                    granted: _granted,
                    requesting: _requesting,
                    onChanged: _toggle,
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text('Continue'),
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
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final bool granted;
  final bool requesting;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.granted,
    required this.requesting,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Turn on notifications',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            requesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Switch(
                    value: granted,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.pill,
                    inactiveTrackColor: AppColors.divider,
                  ),
          ],
        ),
      ),
    );
  }
}
