import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/models/match_model.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, MatchesState>((ref) {
  return MatchesNotifier(ref.read(dioProvider), ref.read(socketServiceProvider));
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
  final Dio _dio;
  final SocketService _socket;

  MatchesNotifier(this._dio, this._socket) : super(const MatchesState()) {
    loadMatches();
    _listenForSocketEvents();
  }

  void _listenForSocketEvents() {
    _socket.on('new-match', (_) {
      // Reload matches when a new match occurs
      refresh();
    });

    _socket.on('new-message', (data) {
      // Update match preview with new message
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

      // Move the updated match to the top of conversations
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

    try {
      final response = await _dio.get(
        ApiEndpoints.matches,
        queryParameters: {'page': page, 'limit': 30},
      );
      final data = response.data;
      final matchesList = (data['matches'] as List? ?? [])
          .map((m) => MatchModel.fromJson(m))
          .toList();
      final hasMore = data['hasMore'] ?? false;

      if (loadMore) {
        state = state.copyWith(
          matches: [...state.matches, ...matchesList],
          isLoading: false,
          currentPage: page,
          hasMore: hasMore,
        );
      } else {
        state = state.copyWith(
          matches: matchesList,
          isLoading: false,
          currentPage: 1,
          hasMore: hasMore,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load matches',
      );
    }
  }

  Future<void> refresh() async {
    state = const MatchesState();
    await loadMatches();
  }

  Future<String?> deleteMatch(String matchId) async {
    try {
      await _dio.delete(ApiEndpoints.deleteMatch(matchId));
      state = state.copyWith(
        matches: state.matches.where((m) => m.id != matchId).toList(),
      );
      return null;
    } on DioException catch (e) {
      return e.response?.data?['error']?['message'] ?? 'Failed to unmatch';
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
    final matchesState = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: _buildBody(context, ref, matchesState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, MatchesState matchesState) {
    if (matchesState.isLoading && matchesState.matches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (matchesState.error != null && matchesState.matches.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Failed to load matches',
        actionLabel: 'Retry',
        onAction: () => ref.read(matchesProvider.notifier).refresh(),
      );
    }

    if (matchesState.matches.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No matches yet',
        subtitle: 'Your matches will appear here',
      );
    }

    return FutureBuilder<String?>(
      future: ref.read(secureStorageProvider).getUserId(),
      builder: (context, snapshot) {
        final myId = snapshot.data ?? '';

        final newMatches =
            matchesState.matches.where((m) => m.lastMessage == null).toList();
        final conversations =
            matchesState.matches.where((m) => m.lastMessage != null).toList();

        return RefreshIndicator(
          onRefresh: () => ref.read(matchesProvider.notifier).refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200 &&
                  matchesState.hasMore &&
                  !matchesState.isLoading) {
                ref.read(matchesProvider.notifier).loadMatches(loadMore: true);
              }
              return false;
            },
            child: ListView(
              children: [
                if (newMatches.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('New Matches',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: newMatches.length,
                      itemBuilder: (context, index) {
                        final match = newMatches[index];
                        final other = match.otherUser(myId);
                        return GestureDetector(
                          onTap: () => context.push('/chat/${match.id}'),
                          onLongPress: () =>
                              _showUnmatchDialog(context, ref, match),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundImage: other.firstPhoto.isNotEmpty
                                      ? NetworkImage(other.firstPhoto)
                                      : null,
                                  child: other.firstPhoto.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  other.name ?? 'Unknown',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (conversations.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Messages',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ...conversations.map((match) {
                  final other = match.otherUser(myId);
                  return Dismissible(
                    key: ValueKey(match.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.error,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await _confirmUnmatch(context);
                    },
                    onDismissed: (_) {
                      ref.read(matchesProvider.notifier).deleteMatch(match.id).then((err) {
                        if (err != null && context.mounted) {
                          context.showSnackBar(err, isError: true);
                          // Reload since dismissible already removed it
                          ref.read(matchesProvider.notifier).refresh();
                        }
                      });
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: other.firstPhoto.isNotEmpty
                            ? NetworkImage(other.firstPhoto)
                            : null,
                        child: other.firstPhoto.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(other.name ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        match.lastMessage?.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: match.unreadCount > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: match.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            match.lastMessage != null
                                ? AppDateUtils.formatTimestamp(
                                    match.lastMessage!.createdAt)
                                : '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (match.unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                '${match.unreadCount}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => context.push('/chat/${match.id}'),
                      onLongPress: () =>
                          _showUnmatchDialog(context, ref, match),
                    ),
                  );
                }),
                if (matchesState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
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
        title: const Text('Unmatch'),
        content: const Text(
          'Are you sure? This will delete the conversation and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unmatch', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showUnmatchDialog(BuildContext context, WidgetRef ref, MatchModel match) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unmatch'),
        content: const Text(
          'Are you sure? This will delete the conversation and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(matchesProvider.notifier).deleteMatch(match.id).then((err) {
                if (err != null && context.mounted) {
                  context.showSnackBar(err, isError: true);
                } else if (context.mounted) {
                  context.showSnackBar('Unmatched');
                }
              });
            },
            child: const Text('Unmatch', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
