import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/models/message_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../data/chat_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;
  final UserModel? other;

  const ChatScreen({super.key, required this.matchId, this.other});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _isOtherTyping = false;
  String? _myId;
  Timer? _typingTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
    _loadMessages();
    _setupSocket();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    _myId = await ref.read(secureStorageProvider).getUserId();
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadMessages() async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.getMessages(
      widget.matchId,
      page: 1,
      limit: AppConstants.messagePageSize,
    );
    switch (result) {
      case Success(:final data):
        _hasMore = data.hasMore;
        _currentPage = 1;
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _messages.addAll(data.messages);
          _isLoading = false;
        });
        _scrollToBottom();
        _markSeenViaHttp();
      case Failure():
        if (!mounted) return;
        setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.getMessages(
      widget.matchId,
      page: _currentPage + 1,
      limit: AppConstants.messagePageSize,
    );
    switch (result) {
      case Success(:final data):
        _hasMore = data.hasMore;
        _currentPage++;
        final oldOffset = _scrollController.offset;
        if (!mounted) return;
        setState(() {
          _messages.insertAll(0, data.messages);
          _isLoadingMore = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              oldOffset + data.messages.length * 60.0,
            );
          }
        });
      case Failure():
        if (!mounted) return;
        setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markSeenViaHttp() async {
    await ref.read(chatRepositoryProvider).markSeen(widget.matchId);
  }

  void _setupSocket() {
    final socket = ref.read(socketServiceProvider);
    socket.joinRoom(widget.matchId);

    socket.on('new-message', (data) {
      final message = MessageModel.fromJson(data);
      if (message.matchId == widget.matchId) {
        setState(() => _messages.add(message));
        _scrollToBottom();
        socket.markSeen(widget.matchId);
      }
    });

    socket.on('user-typing', (data) {
      if (data['matchId'] == widget.matchId) {
        setState(() => _isOtherTyping = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isOtherTyping = false);
        });
      }
    });

    socket.on('user-stopped-typing', (data) {
      if (data['matchId'] == widget.matchId) {
        setState(() => _isOtherTyping = false);
      }
    });

    socket.on('messages-seen', (data) {
      if (data['matchId'] == widget.matchId) {
        setState(() {
          for (var i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].sender == _myId && !_messages[i].seen) {
              _messages[i] = MessageModel(
                id: _messages[i].id,
                matchId: _messages[i].matchId,
                sender: _messages[i].sender,
                text: _messages[i].text,
                seen: true,
                createdAt: _messages[i].createdAt,
              );
            }
          }
        });
      }
    });

    socket.markSeen(widget.matchId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.selectionClick();
    final socket = ref.read(socketServiceProvider);
    socket.sendMessage(widget.matchId, text);
    socket.stopTyping(widget.matchId);
    _textController.clear();
  }

  void _onTextChanged(String value) {
    final socket = ref.read(socketServiceProvider);
    if (value.isNotEmpty) {
      socket.startTyping(widget.matchId);
    } else {
      socket.stopTyping(widget.matchId);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    final socket = ref.read(socketServiceProvider);
    socket.leaveRoom(widget.matchId);
    socket.off('new-message');
    socket.off('user-typing');
    socket.off('user-stopped-typing');
    socket.off('messages-seen');
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatAppBar(other: widget.other),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _TypingIndicator(visible: _isOtherTyping),
          _InputBar(
            controller: _textController,
            hasText: _hasText,
            onChanged: _onTextChanged,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_messages.isEmpty) {
      return _EmptyChat(name: widget.other?.name);
    }

    // Build interleaved list with date dividers + grouped bubbles.
    final items = <_ChatItem>[];
    DateTime? lastDay;
    String? lastSender;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final day = DateTime(
          m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_DateItem(day));
        lastSender = null;
      }
      lastDay = day;

      final showTail = lastSender != m.sender;
      items.add(_MessageItem(m, showTail: showTail));
      lastSender = m.sender;
    }

    return Column(
      children: [
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _DateItem) {
                return _DateDivider(date: item.date);
              }
              final mi = item as _MessageItem;
              final isMe = mi.message.sender == _myId;
              return _MessageBubble(
                message: mi.message,
                isMe: isMe,
                showTail: mi.showTail,
              );
            },
          ),
        ),
      ],
    );
  }
}

sealed class _ChatItem {}

class _DateItem extends _ChatItem {
  final DateTime date;
  _DateItem(this.date);
}

class _MessageItem extends _ChatItem {
  final MessageModel message;
  final bool showTail;
  _MessageItem(this.message, {required this.showTail});
}

class _ChatAppBar extends StatelessWidget {
  final UserModel? other;

  const _ChatAppBar({required this.other});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              ClayContainer(
                borderRadius: 24,
                depth: 0.5,
                padding: const EdgeInsets.all(3),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.grape],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: ClipOval(
                  child: (other?.firstPhoto.isNotEmpty ?? false)
                      ? AppCachedImage(
                          imageUrl: other!.firstPhoto,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.person,
                              size: 20, color: AppColors.textHint),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      other?.name ?? 'Conversation',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.likeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Active now',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert_rounded),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayDate = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dayDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[d.weekday - 1];
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTail;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showTail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showTail ? 8 : 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: ClayContainer(
            depth: 0.55,
            borderRadius: 20,
            padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: isMe ? null : Clay.surface(context),
            gradient: isMe
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.grape],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppDateUtils.formatMessageTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isMe ? Colors.white70 : AppColors.textHint,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.seen ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.seen
                            ? AppColors.secondary
                            : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool visible;

  const _TypingIndicator({required this.visible});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !widget.visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClayContainer(
                  depth: 0.5,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: AnimatedBuilder(
                    animation: _ctl,
                    builder: (_, __) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final phase = (_ctl.value + i * 0.18) % 1.0;
                          final alpha =
                              (0.3 + 0.7 * (1 - (phase * 2 - 1).abs()))
                                  .clamp(0.3, 1.0);
                          return Padding(
                            padding: EdgeInsets.only(
                                right: i == 2 ? 0 : 4),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: alpha),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Clay.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ClayContainer(
                  pressed: true,
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 15,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      isCollapsed: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                scale: hasText ? 1.0 : 0.0,
                child: _SquishCircle(
                  onTap: hasText ? onSend : null,
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A puffy clay circle that squishes on tap — used for the send button.
class _SquishCircle extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SquishCircle({required this.child, this.onTap});

  @override
  State<_SquishCircle> createState() => _SquishCircleState();
}

class _SquishCircleState extends State<_SquishCircle> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: ClayContainer(
          width: 50,
          height: 50,
          borderRadius: 25,
          depth: 0.8,
          pressed: _down,
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.grape],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String? name;

  const _EmptyChat({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name != null ? 'Say hi to $name' : 'Start the conversation',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Comments on photos get 3× more replies than plain "hi".',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
