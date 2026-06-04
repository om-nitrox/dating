import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/models/match_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../data/match_repository.dart';

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, MatchesState>((ref) {
  return MatchesNotifier(
    ref.read(matchRepositoryProvider),
    ref.read(socketServiceProvider),
  );
});

class MatchesState {
  final List<MatchModel> matches;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const MatchesState({
    this.matches = const [],
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
  });

  MatchesState copyWith({
    List<MatchModel>? matches,
    bool? isLoading,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) {
    return MatchesState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class MatchesNotifier extends StateNotifier<MatchesState> {
  final MatchRepository _repo;
  final SocketService _socket;

  MatchesNotifier(this._repo, this._socket) : super(const MatchesState()) {
    loadMatches();
    _listenForSocketEvents();
  }

  void _listenForSocketEvents() {
    _socket.on('new-match', (_) {
      refresh();
    });

    _socket.on('new-message', (data) {
      final matchId = data['matchId'] as String?;
      if (matchId == null) return;

      final updated = state.matches.map((m) {
        if (m.id == matchId) {
          return MatchModel(
            id: m.id,
            users: m.users,
            lastMessage: MessagePreview.fromJson(data),
            unreadCount: m.unreadCount + 1,
            createdAt: m.createdAt,
          );
        }
        return m;
      }).toList();

      updated.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      state = state.copyWith(matches: updated);
    });
  }

  Future<void> loadMatches({bool loadMore = false}) async {
    if (state.isLoading) return;
    final page = loadMore ? state.currentPage + 1 : 1;
    state = state.copyWith(isLoading: true);

    final result = await _repo.listMatches(page: page, limit: 30);
    switch (result) {
      case Success(:final data):
        if (loadMore) {
          state = state.copyWith(
            matches: [...state.matches, ...data.matches],
            isLoading: false,
            currentPage: page,
            hasMore: data.hasMore,
          );
        } else {
          state = state.copyWith(
            matches: data.matches,
            isLoading: false,
            currentPage: 1,
            hasMore: data.hasMore,
          );
        }
      case Failure(:final exception):
        state = state.copyWith(
          isLoading: false,
          error: exception.message,
        );
    }
  }

  Future<void> refresh() async {
    state = const MatchesState();
    await loadMatches();
  }

  Future<String?> deleteMatch(String matchId) async {
    final result = await _repo.unmatch(matchId);
    switch (result) {
      case Success():
        state = state.copyWith(
          matches: state.matches.where((m) => m.id != matchId).toList(),
        );
        return null;
      case Failure(:final exception):
        return exception.message;
    }
  }

  @override
  void dispose() {
    _socket.off('new-match');
    _socket.off('new-message');
    super.dispose();
  }
}

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(count: state.matches.length),
            Expanded(child: _body(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, MatchesState state) {
    if (state.isLoading && state.matches.isEmpty) {
      return const _LoadingSkeleton();
    }
    if (state.error != null && state.matches.isEmpty) {
      return _ErrorState(
        message: state.error!,
        onRetry: () => ref.read(matchesProvider.notifier).refresh(),
      );
    }
    if (state.matches.isEmpty) {
      return _EmptyState(
        onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
      );
    }

    return FutureBuilder<String?>(
      future: ref.read(secureStorageProvider).getUserId(),
      builder: (context, snapshot) {
        final myId = snapshot.data ?? '';
        final newMatches =
            state.matches.where((m) => m.lastMessage == null).toList();
        final conversations =
            state.matches.where((m) => m.lastMessage != null).toList();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200 &&
                  state.hasMore &&
                  !state.isLoading) {
                ref
                    .read(matchesProvider.notifier)
                    .loadMatches(loadMore: true);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                if (newMatches.isNotEmpty) ...[
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'New Matches',
                        emoji: '✨',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: newMatches.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final match = newMatches[index];
                          final other = match.otherUser(myId);
                          return _NewMatchTile(
                            name: other.name ?? 'Unknown',
                            photoUrl: other.firstPhoto,
                            onTap: () => context.push('/chat/${match.id}',
                                extra: other),
                            onLongPress: () =>
                                _showUnmatchDialog(context, ref, match),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (conversations.isNotEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Messages',
                        emoji: '💬',
                      ),
                    ),
                  ),
                SliverList.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final match = conversations[index];
                    final other = match.otherUser(myId);
                    return Dismissible(
                      key: ValueKey(match.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: AppColors.error,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Unmatch',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) async =>
                          await _confirmUnmatch(context),
                      onDismissed: (_) {
                        ref
                            .read(matchesProvider.notifier)
                            .deleteMatch(match.id)
                            .then((err) {
                          if (err != null && context.mounted) {
                            context.showSnackBar(err, isError: true);
                            ref.read(matchesProvider.notifier).refresh();
                          }
                        });
                      },
                      child: _ConversationTile(
                        match: match,
                        otherName: other.name ?? 'Unknown',
                        photoUrl: other.firstPhoto,
                        onTap: () => context.push('/chat/${match.id}'),
                        onLongPress: () =>
                            _showUnmatchDialog(context, ref, match),
                      ),
                    );
                  },
                ),
                if (state.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmUnmatch(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Unmatch'),
        content: const Text(
          'This deletes the conversation and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unmatch',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showUnmatchDialog(
      BuildContext context, WidgetRef ref, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Unmatch'),
        content: const Text(
          'This deletes the conversation and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(matchesProvider.notifier)
                  .deleteMatch(match.id)
                  .then((err) {
                if (err != null && context.mounted) {
                  context.showSnackBar(err, isError: true);
                } else if (context.mounted) {
                  context.showSnackBar('Unmatched');
                }
              });
            },
            child: const Text('Unmatch',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int count;

  const _TopBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          const Text(
            'Matches',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 10),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;

  const _SectionHeader({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$title $emoji',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _NewMatchTile extends StatelessWidget {
  final String name;
  final String photoUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NewMatchTile({
    required this.name,
    required this.photoUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            ClayContainer(
              borderRadius: 36,
              depth: 0.7,
              padding: const EdgeInsets.all(4),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.grape],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? AppCachedImage(
                        imageUrl: photoUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.person,
                            color: AppColors.textHint),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final MatchModel match;
  final String otherName;
  final String photoUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.match,
    required this.otherName,
    required this.photoUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final unread = match.unreadCount > 0;
    final last = match.lastMessage;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: photoUrl.isNotEmpty
                  ? AppCachedImage(
                      imageUrl: photoUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.person,
                          color: AppColors.textHint),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        last != null
                            ? AppDateUtils.formatTimestamp(last.createdAt)
                            : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: unread
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last?.text ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: unread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          constraints:
                              const BoxConstraints(minWidth: 22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.grape],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${match.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
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
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.divider.withValues(alpha: 0.4),
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, __) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 14,
                          width: 140,
                          color: AppColors.surfaceVariant),
                      const SizedBox(height: 8),
                      Container(
                          height: 12,
                          width: 220,
                          color: AppColors.surfaceVariant),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 54,
                        color: AppColors.grape,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Complete your profile\nto start getting matches',
                      textAlign: TextAlign.center,
                      style: AppTheme.serifHeading(fontSize: 24),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton(
                        onPressed: () => context.push('/edit-profile'),
                        child: const Text('Edit profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load matches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
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
