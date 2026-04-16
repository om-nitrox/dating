import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/photo_carousel.dart';
import '../../data/swipe_repository.dart';

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.read(swipeRepositoryProvider));
});

class FeedState {
  final List<UserModel> profiles;
  final bool isLoading;
  final String? error;
  final String? cursor;
  final bool canUndo;

  FeedState({
    this.profiles = const [],
    this.isLoading = false,
    this.error,
    this.cursor,
    this.canUndo = false,
  });

  FeedState copyWith({
    List<UserModel>? profiles,
    bool? isLoading,
    String? error,
    String? cursor,
    bool? canUndo,
  }) {
    return FeedState(
      profiles: profiles ?? this.profiles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cursor: cursor ?? this.cursor,
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final SwipeRepository _repo;

  FeedNotifier(this._repo) : super(FeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.getFeed(cursor: state.cursor);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          profiles: [...state.profiles, ...data.profiles],
          isLoading: false,
          cursor: data.nextCursor,
        );
      case Failure(:final exception):
        state = state.copyWith(isLoading: false, error: exception.message);
    }
  }

  /// Reset and reload feed from scratch.
  Future<void> refresh() async {
    state = FeedState(isLoading: true);
    final result = await _repo.getFeed();
    switch (result) {
      case Success(:final data):
        state = FeedState(
          profiles: data.profiles,
          cursor: data.nextCursor,
        );
      case Failure(:final exception):
        state = FeedState(error: exception.message);
    }
  }

  Future<String?> onSwipeRight(int index) async {
    if (index >= state.profiles.length) return null;
    final user = state.profiles[index];
    final result = await _repo.like(user.id);
    state = state.copyWith(canUndo: false);
    _checkLoadMore(index);
    if (result is Failure<void>) {
      return result.exception.message;
    }
    return null;
  }

  Future<void> onSwipeLeft(int index) async {
    if (index >= state.profiles.length) return;
    final user = state.profiles[index];
    _repo.skip(user.id);
    state = state.copyWith(canUndo: true);
    _checkLoadMore(index);
  }

  Future<String?> undoLastSkip() async {
    final result = await _repo.undoLastSkip();
    switch (result) {
      case Success():
        state = state.copyWith(canUndo: false);
        // Refresh the feed so the undone profile reappears
        await refresh();
        return null;
      case Failure(:final exception):
        return exception.message;
    }
  }

  void _checkLoadMore(int currentIndex) {
    if (state.profiles.length - currentIndex <= 3 && state.cursor != null) {
      loadFeed();
    }
  }
}

class GirlHomeScreen extends ConsumerWidget {
  const GirlHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedProvider);

    if (feedState.isLoading && feedState.profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.error != null && feedState.profiles.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Failed to load profiles',
        subtitle: feedState.error,
        actionLabel: 'Retry',
        onAction: () => ref.read(feedProvider.notifier).refresh(),
      );
    }

    if (feedState.profiles.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No more profiles',
        subtitle: 'Check back later for new people',
        actionLabel: 'Refresh',
        onAction: () => ref.read(feedProvider.notifier).refresh(),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: CardSwiper(
            cardsCount: feedState.profiles.length,
            numberOfCardsDisplayed: feedState.profiles.length >= 2 ? 2 : 1,
            backCardOffset: const Offset(0, -30),
            padding: EdgeInsets.zero,
            onSwipe: (prevIndex, currentIndex, direction) {
              if (direction == CardSwiperDirection.right) {
                ref.read(feedProvider.notifier).onSwipeRight(prevIndex).then((err) {
                  if (err != null && context.mounted) {
                    context.showSnackBar(err, isError: true);
                  }
                });
              } else if (direction == CardSwiperDirection.left) {
                ref.read(feedProvider.notifier).onSwipeLeft(prevIndex);
              }
              return true;
            },
            cardBuilder: (context, index, percentX, percentY) {
              final user = feedState.profiles[index];
              return _SwipeCard(user: user);
            },
          ),
        ),
        // Undo button
        if (feedState.canUndo)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.small(
                heroTag: 'undo',
                onPressed: () {
                  ref.read(feedProvider.notifier).undoLastSkip().then((err) {
                    if (err != null && context.mounted) {
                      context.showSnackBar(err, isError: true);
                    }
                  });
                },
                child: const Icon(Icons.undo),
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeCard extends StatelessWidget {
  final UserModel user;

  const _SwipeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PhotoCarousel(
            photoUrls: user.photos.map((p) => p.url).toList(),
            borderRadius: BorderRadius.circular(20),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${user.name ?? "Unknown"}, ${user.age ?? "?"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (user.interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.interests.take(4).map((i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            i,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
