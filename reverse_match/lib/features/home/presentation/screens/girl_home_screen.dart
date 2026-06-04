import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/taxonomies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/swipe_repository.dart';
import '../../domain/discovery_filters.dart';
import '../providers/discovery_filters_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/hinge_profile_view.dart';

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

class GirlHomeScreen extends ConsumerStatefulWidget {
  const GirlHomeScreen({super.key});

  @override
  ConsumerState<GirlHomeScreen> createState() => _GirlHomeScreenState();
}

class _GirlHomeScreenState extends ConsumerState<GirlHomeScreen> {
  int _index = 0;

  void _like() {
    final i = _index;
    ref.read(feedProvider.notifier).onSwipeRight(i).then((err) {
      if (err != null && mounted) context.showSnackBar(err, isError: true);
    });
    _advance();
  }

  void _pass() {
    ref.read(feedProvider.notifier).onSwipeLeft(_index);
    _advance();
  }

  void _advance() => setState(() => _index++);

  void _undo() {
    ref.read(feedProvider.notifier).undoLastSkip().then((err) {
      if (!mounted) return;
      if (err != null) {
        context.showSnackBar(err, isError: true);
      } else {
        setState(() => _index = 0);
      }
    });
  }

  void _refresh() {
    ref.read(feedProvider.notifier).refresh();
    setState(() => _index = 0);
  }

  Future<void> _openFilters() async {
    final current = ref.read(discoveryFiltersProvider);
    final result = await showModalBottomSheet<DiscoveryFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(initial: current),
    );
    if (result == null || !mounted) return;
    final err = await ref.read(discoveryFiltersProvider.notifier).apply(result);
    if (!mounted) return;
    if (err != null) {
      context.showSnackBar(err, isError: true);
      return;
    }
    // Filters are saved into preferences; the backend feed + ideal-match read
    // them, so a refresh re-fetches the now-filtered feed.
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              filters: ref.watch(discoveryFiltersProvider),
              onFilter: _openFilters,
              onIdeal: () => context.push('/ideal-match'),
            ),
            Expanded(child: _body(feedState)),
          ],
        ),
      ),
    );
  }

  Widget _body(FeedState state) {
    if (state.isLoading && state.profiles.isEmpty) {
      return const _LoadingSkeleton();
    }
    if (state.error != null && state.profiles.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: _refresh);
    }
    if (state.profiles.isEmpty) {
      return _EmptyDeck(onRefresh: _refresh);
    }
    if (_index >= state.profiles.length) {
      // Waiting on the next page, or genuinely caught up.
      if (state.isLoading || state.cursor != null) {
        return const _LoadingSkeleton();
      }
      return _EmptyDeck(onRefresh: _refresh);
    }

    final user = state.profiles[_index];
    return HingeProfileView(
      key: ValueKey(user.id),
      user: user,
      canUndo: state.canUndo,
      onUndo: _undo,
      onLike: _like,
      onPass: _pass,
    );
  }
}

/// Hinge-style horizontally-scrolling filter chips with a leading tune icon.
/// Every chip opens the same filter sheet; chips reflect the active filter and
/// highlight when narrowing the feed.
class _FilterBar extends StatelessWidget {
  final DiscoveryFilters filters;
  final VoidCallback onFilter;
  final VoidCallback onIdeal;
  const _FilterBar({
    required this.filters,
    required this.onFilter,
    required this.onIdeal,
  });

  @override
  Widget build(BuildContext context) {
    final heightLabel = filters.hasHeight
        ? 'Height ${filters.heightMin ?? DiscoveryFilters.heightFloor}–${filters.heightMax ?? DiscoveryFilters.heightCeil}cm'
        : 'Height';
    final intentLabel = filters.hasIntent
        ? (DatingIntentions.labels[filters.intent] ?? 'Dating Intentions')
        : 'Dating Intentions';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onFilter,
            icon: Icon(
              Icons.tune_rounded,
              color: filters.isActive
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
            tooltip: 'Filters',
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterChip(
                    label: filters.hasAge
                        ? 'Age ${filters.ageMin}–${filters.ageMax}'
                        : 'Age',
                    active: filters.hasAge,
                    onTap: onFilter,
                  ),
                  _FilterChip(
                    label: heightLabel,
                    active: filters.hasHeight,
                    onTap: onFilter,
                  ),
                  _FilterChip(
                    label: intentLabel,
                    active: filters.hasIntent,
                    onTap: onFilter,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Ideal Match — girls-only ML pick.
          ClayButton(
            onTap: onIdeal,
            borderRadius: 22,
            depth: 0.7,
            padding: const EdgeInsets.all(10),
            gradient: const LinearGradient(
              colors: [AppColors.grape, AppColors.hot],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClayButton(
        onTap: onTap,
        borderRadius: 20,
        depth: 0.55,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: active ? AppColors.primary : Clay.surface(context),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.divider.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 160,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyDeck({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClayContainer(
              width: 120,
              height: 120,
              borderRadius: 44,
              alignment: Alignment.center,
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 54,
                color: AppColors.grape,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "You're all caught up",
              textAlign: TextAlign.center,
              style: AppTheme.serifHeading(fontSize: 26),
            ),
            const SizedBox(height: 8),
            const Text(
              'New people join every day.\nCheck back soon for fresh profiles.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              "Couldn't load profiles",
              style: AppTheme.serifHeading(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
