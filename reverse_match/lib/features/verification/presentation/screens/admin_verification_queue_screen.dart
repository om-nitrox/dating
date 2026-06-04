import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/verification_repository.dart';

/// The ONLY screen an admin sees. Lists girls awaiting approval with their
/// photos + selfie, and lets the admin approve or reject each one. Approving
/// instantly lifts the account gate for that girl (her pending screen polls
/// and moves her into the app).
class AdminVerificationQueueScreen extends ConsumerStatefulWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  ConsumerState<AdminVerificationQueueScreen> createState() =>
      _AdminVerificationQueueScreenState();
}

class _AdminVerificationQueueScreenState
    extends ConsumerState<AdminVerificationQueueScreen> {
  bool _loading = true;
  String? _error;
  List<PendingProfile> _queue = const [];
  final _busy = <String>{}; // userIds currently being approved/rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ref.read(verificationRepositoryProvider).listPending();
    if (!mounted) return;
    switch (res) {
      case Success(:final data):
        setState(() {
          _queue = data;
          _loading = false;
        });
      case Failure(:final exception):
        setState(() {
          _error = exception.message;
          _loading = false;
        });
    }
  }

  Future<void> _approve(PendingProfile p) async {
    setState(() => _busy.add(p.id));
    final res = await ref.read(verificationRepositoryProvider).approve(p.id);
    if (!mounted) return;
    setState(() => _busy.remove(p.id));
    if (res is Failure) {
      context.showSnackBar(res.exception.message, isError: true);
      return;
    }
    setState(() => _queue = _queue.where((x) => x.id != p.id).toList());
    context.showSnackBar('${p.name} approved ✓');
  }

  Future<void> _reject(PendingProfile p) async {
    final reason = await _askReason(p.name);
    if (reason == null) return; // cancelled
    setState(() => _busy.add(p.id));
    final res = await ref
        .read(verificationRepositoryProvider)
        .reject(p.id, reason: reason);
    if (!mounted) return;
    setState(() => _busy.remove(p.id));
    if (res is Failure) {
      context.showSnackBar(res.exception.message, isError: true);
      return;
    }
    setState(() => _queue = _queue.where((x) => x.id != p.id).toList());
    context.showSnackBar('${p.name} rejected');
  }

  Future<String?> _askReason(String name) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Clay.surface(ctx),
        title: Text('Reject $name?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (shown to the user, optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clay.base(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Verification Queue',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return _Centered(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\'t load the queue',
        subtitle: _error!,
        action: ('Retry', _load),
      );
    }
    if (_queue.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            _Centered(
              icon: Icons.inbox_rounded,
              title: 'All caught up',
              subtitle: 'No profiles waiting for verification right now.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _queue.length,
        itemBuilder: (_, i) => _QueueCard(
          profile: _queue[i],
          busy: _busy.contains(_queue[i].id),
          onApprove: () => _approve(_queue[i]),
          onReject: () => _reject(_queue[i]),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final PendingProfile profile;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _QueueCard({
    required this.profile,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final title = profile.age != null
        ? '${profile.name}, ${profile.age}'
        : profile.name;
    return ClayContainer(
      borderRadius: 24,
      depth: 0.9,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              profile.bio!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _PhotoStrip(profile: profile),
          const SizedBox(height: 16),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    filled: false,
                    onTap: onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    filled: true,
                    onTap: onApprove,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final PendingProfile profile;
  const _PhotoStrip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (profile.selfieUrl != null)
        _PhotoTile(url: profile.selfieUrl!, badge: 'Selfie'),
      ...profile.photoUrls.map((u) => _PhotoTile(url: u)),
    ];
    if (tiles.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No photos', style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        itemBuilder: (_, i) => tiles[i],
        separatorBuilder: (_, __) => const SizedBox(width: 10),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final String? badge;
  const _PhotoTile({required this.url, this.badge});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.network(
            url,
            width: 110,
            height: 140,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : Container(
                    width: 110,
                    height: 140,
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            errorBuilder: (ctx, _, __) => Container(
              width: 110,
              height: 140,
              color: AppColors.surfaceVariant,
              child: const Icon(Icons.broken_image_rounded,
                  color: AppColors.textHint),
            ),
          ),
          if (badge != null)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.grape,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final (String, VoidCallback)? action;

  const _Centered({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              ClayButton(
                onTap: action!.$2,
                child: Text(
                  action!.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
