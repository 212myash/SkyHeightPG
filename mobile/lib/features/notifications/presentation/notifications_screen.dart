import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.notifications);

      if (res.data != null && res.data['success'] == true) {
        final list = (res.data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _notifications = list.map((item) => NotificationModel.fromJson(item as Map<String, dynamic>)).toList();
            _unreadCount = (res.data['unreadCount'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.data?['message']?.toString() ?? 'Failed to load notifications';
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

  Future<void> _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.put(ApiEndpoints.markNotificationRead(notif.id));
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            id: notif.id,
            title: notif.title,
            message: notif.message,
            category: notif.category,
            audience: notif.audience,
            targetRoomNumber: notif.targetRoomNumber,
            isRead: true,
            readAt: DateTime.now(),
            dueDate: notif.dueDate,
            createdAt: notif.createdAt,
            senderName: notif.senderName,
          );
          _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(ApiEndpoints.markAllNotificationsRead);
      if (mounted && res.data?['success'] == true) {
        setState(() {
          _notifications = _notifications
              .map((n) => NotificationModel(
                    id: n.id,
                    title: n.title,
                    message: n.message,
                    category: n.category,
                    audience: n.audience,
                    targetRoomNumber: n.targetRoomNumber,
                    isRead: true,
                    readAt: DateTime.now(),
                    dueDate: n.dueDate,
                    createdAt: n.createdAt,
                    senderName: n.senderName,
                  ))
              .toList();
          _unreadCount = 0;
        });
        AppDialog.showSnackBar(context, 'All notifications marked as read.');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  void _showReplyModal(NotificationModel notif) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.reply_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reply to Owner',
                      style: AppTextStyles.h3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Re: ${notif.title}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replyController,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type your message to the apartment owner...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Send Reply to Owner Chat',
                icon: Icons.send_rounded,
                onPressed: () async {
                  final text = replyController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(modalCtx).pop();
                  _submitReply(notif, text);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReply(NotificationModel notif, String replyText) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiEndpoints.replyNotification(notif.id),
        data: {'message': replyText},
      );
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          AppDialog.showSnackBar(context, 'Reply sent! Opening conversation with Owner...');
          final convId = res.data['data']?['conversationId']?.toString();
          if (convId != null) {
            context.push('/chat/$convId');
          }
        } else {
          AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to send reply', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'rent_reminder':
        return Icons.currency_rupee_rounded;
      case 'electricity_bill':
        return Icons.bolt_rounded;
      case 'payment_reminder':
      case 'payment_received':
        return Icons.receipt_long_rounded;
      case 'maintenance':
        return Icons.build_circle_outlined;
      case 'security_alert':
        return Icons.security_rounded;
      case 'registration_update':
        return Icons.person_add_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'rent_reminder':
      case 'electricity_bill':
      case 'security_alert':
        return AppColors.primary;
      case 'payment_received':
      case 'registration_update':
        return AppColors.success;
      case 'maintenance':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark All Read',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/notifications/create').then((_) => _fetchNotifications()),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
              label: const Text('Send Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? EmptyStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to Load Notifications',
                  description: _errorMessage!,
                  actionText: 'Retry',
                  onAction: _fetchNotifications,
                )
              : _notifications.isEmpty
                  ? EmptyStateView(
                      icon: Icons.notifications_none_rounded,
                      title: 'No Notifications',
                      description: 'You have no notices or announcements right now.',
                      actionText: 'Refresh',
                      onAction: _fetchNotifications,
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          return _buildNotificationCard(notif, isOwner);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, bool isOwner) {
    final catColor = _getCategoryColor(notif.category);
    final catIcon = _getCategoryIcon(notif.category);

    return InkWell(
      onTap: () => _markAsRead(notif),
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: catColor.withValues(alpha: 0.12),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notif.category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ),
                    if (notif.targetRoomNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Room ${notif.targetRoomNumber}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notif.createdAt != null)
                      Text(
                        '${notif.createdAt!.day}/${notif.createdAt!.month}  ${notif.createdAt!.hour}:${notif.createdAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
                    if (!isOwner) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showReplyModal(notif),
                        icon: const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                        label: const Text('Reply', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
