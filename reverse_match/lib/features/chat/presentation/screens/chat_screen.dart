import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ChatScreen({super.key, required this.matchId});

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _setupSocket();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    _myId = await ref.read(secureStorageProvider).getUserId();
    setState(() {});
  }

  void _onScroll() {
    // Load older messages when scrolled near the top
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadMessages() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        ApiEndpoints.messages(widget.matchId),
        queryParameters: {'page': 1, 'limit': AppConstants.messagePageSize},
      );
      final messages = (response.data['messages'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList();
      _hasMore = response.data['hasMore'] ?? false;
      _currentPage = 1;
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoading = false;
      });
      _scrollToBottom();
      _markSeenViaHttp();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        ApiEndpoints.messages(widget.matchId),
        queryParameters: {
          'page': _currentPage + 1,
          'limit': AppConstants.messagePageSize,
        },
      );
      final olderMessages = (response.data['messages'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList();
      _hasMore = response.data['hasMore'] ?? false;
      _currentPage++;

      // Preserve scroll position when prepending older messages
      final oldOffset = _scrollController.offset;
      setState(() {
        _messages.insertAll(0, olderMessages);
        _isLoadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            oldOffset + olderMessages.length * 60.0, // Approximate height
          );
        }
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  /// Mark messages as seen via HTTP as a fallback for when socket isn't connected.
  Future<void> _markSeenViaHttp() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put(ApiEndpoints.markSeen(widget.matchId));
    } catch (_) {}
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

    // Mark existing messages as seen via socket
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
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Say hello!',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          if (_isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMe = msg.sender == _myId;
                                return _MessageBubble(
                                  message: msg,
                                  isMe: isMe,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          // Typing indicator
          if (_isOtherTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'typing...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
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
                    color: isMe ? Colors.white70 : AppColors.textHint,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.seen ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
