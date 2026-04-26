import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final _cityController = TextEditingController();
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    _cityController.text = ref.read(onboardingProvider).city ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (mounted) {
          context.showSnackBar('Location permission denied', isError: true);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      ref.read(onboardingProvider.notifier).setLocation(
            lat: pos.latitude,
            lng: pos.longitude,
            city: 'Current location',
          );
      setState(() => _cityController.text = 'Current location');
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Could not detect location', isError: true);
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(onboardingProvider);
    final canProceed = data.city != null && data.city!.trim().isNotEmpty;

    return OnboardingScaffold(
      title: 'Where do you live?',
      subtitle:
          "We'll show you profiles nearby. Your exact location is never shared.",
      progress: OnboardingSteps.progress('/onboarding/location'),
      onNext: canProceed
          ? () =>
              context.push(OnboardingSteps.next('/onboarding/location')!)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _detecting ? null : _detect,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Text(
                    _detecting
                        ? 'Detecting…'
                        : 'Use my current location',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Or enter manually',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'City',
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (v) {
              ref.read(onboardingProvider.notifier).setLocation(city: v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
