import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile_setup/data/profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () => context.push('/edit-profile'),
          ),
          _SettingsTile(
            icon: Icons.rocket_launch_outlined,
            title: 'Boost',
            onTap: () => context.push('/boost'),
          ),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Update Location',
            onTap: () => _updateLocation(context, ref),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _openLegalUrl(context, ref, 'privacyPolicyUrl'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _openLegalUrl(context, ref, 'termsOfServiceUrl'),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            textColor: AppColors.error,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content:
                      const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).logout();
                      },
                      child: const Text('Logout',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            textColor: AppColors.error,
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _openLegalUrl(BuildContext context, WidgetRef ref, String key) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(ApiEndpoints.appConfig);
      final url = response.data[key] as String?;

      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (context.mounted) {
          context.showSnackBar('Not available yet', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Failed to load', isError: true);
      }
    }
  }

  Future<void> _updateLocation(BuildContext context, WidgetRef ref) async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            context.showSnackBar('Location permission denied', isError: true);
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      // Reverse geocode
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
            final display = [city, state].where((s) => s != null && s.isNotEmpty).join(', ');
            context.showSnackBar('Location updated${display.isNotEmpty ? ': $display' : ''}');
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
    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final dio = ref.read(dioProvider);
      await dio.delete(
        ApiEndpoints.deleteAccount,
        data: {'confirmation': 'DELETE_MY_ACCOUNT'},
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        context.showSnackBar('Account deleted');
      }
      await ref.read(authProvider.notifier).logout();
    } on DioException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final msg = e.response?.data?['error']?['message'] ?? 'Failed to delete account';
        context.showSnackBar(msg, isError: true);
      }
    }
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
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action is permanent and cannot be undone. All your data, matches, and messages will be deleted.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Type DELETE to confirm:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            onChanged: (v) => setState(() => _canDelete = v.trim() == 'DELETE'),
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
              isDense: true,
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
            'Delete Forever',
            style: TextStyle(
              color: _canDelete ? AppColors.error : AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing:
          Icon(Icons.chevron_right, color: textColor ?? AppColors.textHint),
      onTap: onTap,
    );
  }
}
