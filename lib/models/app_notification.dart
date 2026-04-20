// lib/models/app_notification.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  dailyTip,
  tripReminder,
  newDestination,
  weatherAlert,
  system,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? destinationId;
  final String? imageUrl;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.destinationId,
    this.imageUrl,
    this.data,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: _parseType(d['type'] ?? 'system'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: d['isRead'] ?? false,
      destinationId: d['destinationId'],
      imageUrl: d['imageUrl'],
      data: d['data'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'type': type.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'isRead': isRead,
    'destinationId': destinationId,
    'imageUrl': imageUrl,
    'data': data,
  };

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'dailyTip': return NotificationType.dailyTip;
      case 'tripReminder': return NotificationType.tripReminder;
      case 'newDestination': return NotificationType.newDestination;
      case 'weatherAlert': return NotificationType.weatherAlert;
      default: return NotificationType.system;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}