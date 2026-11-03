import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_model.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ConversationModel> _conversations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.conversations);

      if (res.data != null && res.data['success'] == true) {
        final list = (res.data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _conversations = list.map((item) => ConversationModel.fromJson(item as Map<String, dynamic>)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.data?['message']?.toString() ?? 'Failed to load conversations';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<ConversationModel> get _filteredConversations {
    switch (_tabController.index) {
      case 1:
        return _conversations.where((c) => c.type == 'private').toList();
      case 2:
        return _conversations.where((c) => c.type == 'room').toList();
      case 3:
        return _conversations.where((c) => c.type == 'community').toList();
      default:
        return _conversations;
    }
  }

  Future<void> _startOwnerChat() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(ApiEndpoints.privateConversation, data: {});
      if (mounted && res.data != null && res.data['data'] != null) {
        final convId = res.data['data']['_id']?.toString();
        if (convId != null) {
          context.push('/chat/$convId').then((_) => _fetchConversations());
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final displayed = _filteredConversations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages & Groups'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Direct'),
            Tab(text: 'Rooms'),
            Tab(text: 'Community'),
          ],
        ),
      ),
      floatingActionButton: !isOwner
          ? FloatingActionButton.extended(
              onPressed: _startOwnerChat,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
              label: const Text('Chat with Owner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? EmptyStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to Load Chats',
                  description: _errorMessage!,
                  actionText: 'Retry',
                  onAction: _fetchConversations,
                )
              : displayed.isEmpty
                  ? EmptyStateView(
                      icon: Icons.chat_outlined,
                      title: 'No Conversations',
                      description: 'No messages found in this category.',
                      actionText: 'Refresh',
                      onAction: _fetchConversations,
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchConversations,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayed.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conv = displayed[index];
                          return _buildConversationTile(conv);
                        },
                      ),
                    ),
    );
  }

  Widget _buildConversationTile(ConversationModel conv) {
    IconData icon;
    Color iconColor;
    String typeBadge;

    switch (conv.type) {
      case 'community':
        icon = Icons.forum_rounded;
        iconColor = AppColors.primary;
        typeBadge = 'Community';
        break;
      case 'room':
        icon = Icons.meeting_room_rounded;
        iconColor = AppColors.info;
        typeBadge = 'Room Group';
        break;
      default:
        icon = Icons.person_rounded;
        iconColor = AppColors.success;
        typeBadge = 'Direct';
    }

    return InkWell(
      onTap: () {
        context.push('/chat/${conv.id}').then((_) => _fetchConversations());
      },
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, color: iconColor, size: 24),
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
                          conv.displayName,
                          style: AppTextStyles.h3.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          typeBadge,
                          style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessageText.isNotEmpty ? conv.lastMessageText : 'No messages yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: conv.unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
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
