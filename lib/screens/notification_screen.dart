// lib/screens/notification_screen.dart

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import 'destination_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notifService = NotificationService();
  final FirebaseService _firebaseService = FirebaseService();
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifs = await _notifService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _notifService.markAllAsRead();
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear All Notifications?', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('This will permanently delete all notifications.',
          style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All')),
        ],
      ),
    );
    if (confirm == true) {
      await _notifService.clearAll();
      _loadNotifications();
    }
  }

  Future<void> _onNotificationTap(AppNotification notif) async {
    // Mark as read
    if (!notif.isRead) {
      await _notifService.markAsRead(notif.id);
    }

    // Navigate to destination if available
    if (notif.destinationId != null && notif.destinationId!.isNotEmpty) {
      final dest = await _firebaseService.getDestinationById(notif.destinationId!);
      if (dest != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DestinationDetailScreen(destination: dest),
        ));
        return;
      }
    }

    _loadNotifications();
  }

  Future<void> _deleteNotification(AppNotification notif) async {
    await _notifService.deleteNotification(notif.id);
    setState(() => _notifications.remove(notif));
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text('Notifications', style: TextStyle(
              color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textPrimary(context)),
              color: AppColors.surface(context),
              onSelected: (value) {
                if (value == 'read') _markAllRead();
                if (value == 'clear') _clearAll();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'read', child: Row(children: [
                  Icon(Icons.done_all, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Mark all read', style: TextStyle(color: AppColors.textPrimary(context))),
                ])),
                PopupMenuItem(value: 'clear', child: Row(children: [
                  const Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Clear all', style: TextStyle(color: AppColors.textPrimary(context))),
                ])),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationCard(context, _notifications[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle),
            child: Icon(Icons.notifications_off_outlined,
              size: 60, color: AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 24),
          Text('No notifications yet', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
          const SizedBox(height: 8),
          Text('Travel tips, trip reminders and alerts\nwill show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textHint(context), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notif) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notif),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: () => _onNotificationTap(notif),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead
                ? AppColors.card(context)
                : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.border(context)
                  : AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getTypeColor(notif.type).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(_getTypeIcon(notif.type),
                  color: _getTypeColor(notif.type), size: 22),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(notif.title, style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: AppColors.textPrimary(context))),
                        ),
                        Text(notif.timeAgo, style: TextStyle(
                          fontSize: 11, color: AppColors.textHint(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(notif.body, style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary(context), height: 1.4),
                      maxLines: 3, overflow: TextOverflow.ellipsis),

                    // Destination link
                    if (notif.destinationId != null && notif.destinationId!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.explore, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Tap to explore', style: TextStyle(
                              fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Unread dot
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.dailyTip: return const Color(0xFF1E88E5);
      case NotificationType.tripReminder: return AppColors.primary;
      case NotificationType.newDestination: return const Color(0xFFE65100);
      case NotificationType.weatherAlert: return const Color(0xFF7B1FA2);
      case NotificationType.system: return const Color(0xFF546E7A);
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.dailyTip: return Icons.lightbulb_outline;
      case NotificationType.tripReminder: return Icons.luggage;
      case NotificationType.newDestination: return Icons.place;
      case NotificationType.weatherAlert: return Icons.cloud;
      case NotificationType.system: return Icons.info_outline;
    }
  }
}