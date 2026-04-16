import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/like_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../data/queue_repository.dart';

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  return QueueNotifier(ref.read(queueRepositoryProvider));
});

class QueueState {
  final List<LikeModel> likes;
  final bool isLoading;
  final String? error;

  QueueState({this.likes = const [], this.isLoading = false, this.error});

  QueueState copyWith({
    List<LikeModel>? likes,
    bool? isLoading,
    String? error,
  }) {
    return QueueState(
      likes: likes ?? this.likes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QueueNotifier extends StateNotifier<QueueState> {
  final QueueRepository _repo;

  QueueNotifier(this._repo) : super(QueueState()) {
    loadQueue();
  }

  Future<void> loadQueue() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.getQueue();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(likes: data, isLoading: false);
      case Failure(:final exception):
        state = state.copyWith(isLoading: false, error: exception.message);
    }
  }

  Future<void> accept(String likeId, BuildContext context) async {
    final result = await _repo.accept(likeId);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          likes: state.likes.where((l) => l.id != likeId).toList(),
        );
        if (context.mounted) {
          _showMatchDialog(context, data);
        }
      case Failure(:final exception):
        if (context.mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  Future<void> reject(String likeId) async {
    state = state.copyWith(
      likes: state.likes.where((l) => l.id != likeId).toList(),
    );
    _repo.reject(likeId); // Fire and forget
  }

  void _showMatchDialog(BuildContext context, dynamic match) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: AppColors.primary, size: 64),
            const SizedBox(height: 16),
            const Text(
              "It's a Match!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/chat/${match.id}');
              },
              child: const Text('Send a Message'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Browsing'),
            ),
          ],
        ),
      ),
    );
  }
}

class BoyHomeScreen extends ConsumerWidget {
  const BoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);

    if (queueState.isLoading && queueState.likes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (queueState.likes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.hourglass_empty,
        title: 'Waiting for likes',
        subtitle: 'When someone likes your profile, they\'ll appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(queueProvider.notifier).loadQueue(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: queueState.likes.length,
        itemBuilder: (context, index) {
          final like = queueState.likes[index];
          return _QueueCard(
            like: like,
            onAccept: () =>
                ref.read(queueProvider.notifier).accept(like.id, context),
            onReject: () =>
                ref.read(queueProvider.notifier).reject(like.id),
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final LikeModel like;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _QueueCard({
    required this.like,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = like.fromUser;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: user.firstPhoto.isNotEmpty
                  ? AppCachedImage(
                      imageUrl: user.firstPhoto,
                      width: 80,
                      height: 80,
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 40),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user.name ?? "Unknown"}, ${user.age ?? "?"}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close, color: AppColors.nopeRed),
              iconSize: 28,
            ),
            IconButton(
              onPressed: onAccept,
              icon: const Icon(Icons.check, color: AppColors.likeGreen),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}
