import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message_model.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  bool _isLoading = true;
  bool _isSending = false;
  String _conversationName = 'Chat';
  String _conversationType = 'private';
  List<ChatMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadMessages(isPolling: true);
      }
    });
  }

  Future<void> _loadMessages({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() => _isLoading = true);
    }

    try {
      final api = ref.read(apiClientProvider);
      final currentUserId = ref.read(authProvider).user?.id ?? '';

      final res = await api.get(ApiEndpoints.conversationMessages(widget.conversationId));

      if (res.data != null && res.data['success'] == true) {
        final list = (res.data['data'] as List<dynamic>?) ?? [];
        final convInfo = res.data['conversation'] as Map<String, dynamic>?;

        final newMessages = list
            .map((item) => ChatMessageModel.fromJson(
                  item as Map<String, dynamic>,
                  currentUserId: currentUserId,
                ))
            .toList();

        if (mounted) {
          setState(() {
            _messages = newMessages;
            if (convInfo != null) {
              _conversationName = convInfo['name']?.toString() ?? _conversationName;
              _conversationType = convInfo['type']?.toString() ?? _conversationType;
            }
            if (!isPolling) _isLoading = false;
          });
        }
      } else {
        if (!isPolling && mounted) {
          setState(() => _isLoading = false);
          AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to load messages', isError: true);
        }
      }
    } catch (e) {
      if (!isPolling && mounted) {
        setState(() => _isLoading = false);
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final api = ref.read(apiClientProvider);
      final currentUserId = ref.read(authProvider).user?.id ?? '';

      final res = await api.post(
        ApiEndpoints.sendMessage(widget.conversationId),
        data: {'content': text},
      );

      if (mounted) {
        setState(() => _isSending = false);
        if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
          final newMsg = ChatMessageModel.fromJson(
            res.data['data'] as Map<String, dynamic>,
            currentUserId: currentUserId,
          );
          setState(() {
            _messages.add(newMsg);
          });
          _scrollToBottom();
        } else {
          AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to send', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String typeLabel;
    switch (_conversationType) {
      case 'room':
        typeLabel = 'Room Group';
        break;
      case 'community':
        typeLabel = 'Community';
        break;
      default:
        typeLabel = 'Direct Message';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conversationName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              typeLabel,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nSay hello to start the conversation!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.isMe;
    final isOwner = msg.senderRole == 'owner';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: isOwner ? AppColors.primary : AppColors.surface,
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: isOwner ? Colors.white : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            msg.senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOwner ? AppColors.primary : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OWNER',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (msg.createdAt != null)
                    Text(
                      '${msg.createdAt!.hour}:${msg.createdAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : AppColors.textLight,
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

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: const TextStyle(color: AppColors.textLight),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
