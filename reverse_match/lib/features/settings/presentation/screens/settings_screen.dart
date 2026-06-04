import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../account/data/account_repository.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../config/data/config_repository.dart';
import '../../../profile/data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 24),
            _Section(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  title: 'Edit profile',
                  subtitle: 'Photos, bio, interests',
                  onTap: () => context.push('/edit-profile'),
                ),
                _SettingsTile(
                  icon: Icons.flash_on_rounded,
                  color: AppColors.warning,
                  title: 'Boost',
                  subtitle: 'Get more profile views',
                  trailing: _BoostBadge(),
                  onTap: () => context.push('/boost'),
                ),
                _SettingsTile(
                  icon: Icons.location_on_rounded,
                  color: AppColors.secondary,
                  title: 'Update location',
                  subtitle: 'Refresh your city',
                  onTap: () => _updateLocation(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Legal',
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  color: AppColors.textSecondary,
                  title: 'Privacy Policy',
                  onTap: () =>
                      _openLegalUrl(context, ref, 'privacyPolicyUrl'),
                ),
                _SettingsTile(
                  icon: Icons.description_rounded,
                  color: AppColors.textSecondary,
                  title: 'Terms of Service',
                  onTap: () =>
                      _openLegalUrl(context, ref, 'termsOfServiceUrl'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Danger Zone',
              accent: AppColors.error,
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  color: AppColors.warning,
                  title: 'Logout',
                  textColor: AppColors.textPrimary,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  color: AppColors.error,
                  title: 'Delete account',
                  textColor: AppColors.error,
                  onTap: () => _showDeleteAccountDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _AppFooter(),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?'),
        content: const Text('You\'ll need to sign in again next time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/welcome');
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegalUrl(
      BuildContext context, WidgetRef ref, String key) async {
    final repo = ref.read(configRepositoryProvider);
    final result = await repo.getConfig();

    switch (result) {
      case Success(:final data):
        final url = switch (key) {
          'privacyPolicyUrl' => data.privacyPolicyUrl,
          'termsOfServiceUrl' => data.termsOfServiceUrl,
          _ => '',
        };

        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else {
          if (context.mounted) {
            context.showSnackBar('Not available yet', isError: true);
          }
        }
      case Failure():
        if (context.mounted) {
          context.showSnackBar('Failed to load', isError: true);
        }
    }
  }

  Future<void> _updateLocation(
      BuildContext context, WidgetRef ref) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            context.showSnackBar('Location permission denied',
                isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          context.showSnackBar(
            'Location permission permanently denied. Enable in settings.',
            isError: true,
          );
        }
        return;
      }

      if (context.mounted) {
        context.showSnackBar('Getting your location...');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      String? city;
      String? state;
      try {
        final placemarks = await geo.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          city = placemarks.first.locality;
          state = placemarks.first.administrativeArea;
        }
      } catch (_) {}

      final repo = ref.read(profileRepositoryProvider);
      final result = await repo.updateProfile({
        'location': {
          'coordinates': [position.longitude, position.latitude],
          'city': city ?? '',
          'state': state ?? '',
        },
      });

      if (context.mounted) {
        switch (result) {
          case Success():
            final display = [city, state]
                .where((s) => s != null && s.isNotEmpty)
                .join(', ');
            context.showSnackBar(
                'Location updated${display.isNotEmpty ? ': $display' : ''}');
          case Failure(:final exception):
            context.showSnackBar(exception.message, isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Failed to update location', isError: true);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        onConfirm: () async {
          Navigator.pop(ctx);
          await _deleteAccount(context, ref);
        },
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    // Capture the ROOT navigator up front. The loading dialog is pushed on the
    // root navigator, so it must also be dismissed there. Using the local
    // (shell-branch) navigator popped the Settings route itself and left a
    // black screen behind.
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final repo = ref.read(accountRepositoryProvider);
    final result = await repo.deleteAccount('DELETE_MY_ACCOUNT');

    // Always dismiss the loading dialog from the root navigator.
    if (rootNavigator.canPop()) rootNavigator.pop();

    switch (result) {
      case Success():
        if (context.mounted) {
          context.showSnackBar('Account deleted');
        }
        // Clears tokens + sets auth state to unauthenticated; the router's
        // redirect (driven by refreshListenable) then routes to /welcome.
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          context.go('/welcome');
        }
      case Failure(:final exception):
        if (context.mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }
}

/// Hinge "My Profile" style header: avatar wrapped in a completion ring,
/// name + verified badge, and a completion-percentage pill.
class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  const _ProfileHeader({required this.user});

  /// Rough profile-completion score across the key fields.
  double _completion(UserModel u) {
    final checks = <bool>[
      (u.name ?? '').isNotEmpty,
      u.age != null,
      u.gender != null,
      u.photos.length >= 2,
      (u.bio ?? '').isNotEmpty,
      u.prompts.isNotEmpty,
      u.interests.isNotEmpty,
      (u.education ?? '').isNotEmpty,
      (u.hometown ?? '').isNotEmpty || (u.location?.city ?? '').isNotEmpty,
      u.datingIntentions != null,
      u.height != null,
    ];
    final done = checks.where((c) => c).length;
    return done / checks.length;
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final pct = u == null ? 0.0 : _completion(u);
    final percentLabel = '${(pct * 100).round()}%';
    final photo = u?.firstPhoto ?? '';

    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: CircularProgressIndicator(
                  value: pct == 0 ? null : pct,
                  strokeWidth: 4,
                  backgroundColor: AppColors.divider,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.grape),
                ),
              ),
              ClipOval(
                child: photo.isNotEmpty
                    ? AppCachedImage(
                        imageUrl: photo, width: 88, height: 88, fit: BoxFit.cover)
                    : Container(
                        width: 88,
                        height: 88,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.person_rounded,
                            size: 40, color: AppColors.textHint),
                      ),
              ),
              if (pct < 1)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.grape,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      percentLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              u?.name ?? 'You',
              style: AppTheme.serifHeading(fontSize: 26),
            ),
            if (u?.isVerified ?? false) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded,
                  color: AppColors.grape, size: 22),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          pct >= 1 ? 'Profile complete' : 'Complete your profile',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;

  const _Section({
    required this.title,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent ?? AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClayContainer(
          borderRadius: 26,
          depth: 0.85,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: List.generate(children.length * 2 - 1, (i) {
              if (i.isEven) return children[i ~/ 2];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerTheme.color),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? textColor;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor ?? AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostBadge extends StatelessWidget {
  const _BoostBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        const Text(
          'Reverse Match',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'v1.0.0',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onConfirm;
  const _DeleteAccountDialog({required this.onConfirm});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Delete account'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This is permanent. All your data, matches, and messages will be erased.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Type DELETE to confirm:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            onChanged: (v) =>
                setState(() => _canDelete = v.trim() == 'DELETE'),
            decoration: InputDecoration(
              hintText: 'DELETE',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canDelete ? widget.onConfirm : null,
          child: Text(
            'Delete forever',
            style: TextStyle(
              color: _canDelete ? AppColors.error : AppColors.textHint,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
