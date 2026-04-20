// lib/services/notification_service.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../widgets/in_app_notification_banner.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set this from main.dart so we can show floating banners from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Show floating in-app banner on current screen
  void _showBanner({
    required String title,
    required String body,
    IconData icon = Icons.notifications,
    Color iconColor = const Color(0xFF1B8A6B),
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    InAppNotificationBanner().show(
      context,
      title: title,
      body: body,
      icon: icon,
      iconColor: iconColor,
    );
  }

  // ═══════════════════════════════════════════
  // INIT — Call once in main.dart
  // ═══════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(settings);
    _initialized = true;

    // Generate daily tip if none today
    await _generateDailyTipIfNeeded();
  }

  // ═══════════════════════════════════════════
  // PUSH NOTIFICATION
  // ═══════════════════════════════════════════
  Future<void> showPushNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'govista_channel',
      'GoVista Notifications',
      channelDescription: 'Travel tips, trip reminders and alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1B8A6B),
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(id, title, body, details);
  }

  // ═══════════════════════════════════════════
  // FIRESTORE — In-app notification history
  // ═══════════════════════════════════════════
  Future<void> addNotification(AppNotification notification) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .add(notification.toMap());
  }

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    if (_userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => AppNotification.fromFirestore(d)).toList();
    } catch (e) {
      print('Get notifications error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    if (_userId == null) return 0;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  Future<void> deleteNotification(String id) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .doc(id)
        .delete();
  }

  Future<void> clearAll() async {
    if (_userId == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ═══════════════════════════════════════════
  // AUTO GENERATORS
  // ═══════════════════════════════════════════

  /// Daily travel tip — picks a random destination
  Future<void> _generateDailyTipIfNeeded() async {
    if (_userId == null) return;

    try {
      // Check if a tip was already sent today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final existing = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .where('type', isEqualTo: 'dailyTip')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      if (existing.docs.isNotEmpty) return; // Already sent today

      // Pick a random destination
      final destinations = await _firestore.collection('destinations').get();
      if (destinations.docs.isEmpty) return;

      final random = Random();
      final randomDest = destinations.docs[random.nextInt(destinations.docs.length)];
      final destData = randomDest.data();
      final destName = destData['name'] ?? 'a hidden gem';
      final destState = destData['state'] ?? '';
      final destImage = destData['image'] ?? '';
      final destRating = destData['rating'] ?? 0;

      final tips = [
        'Did you know $destName in $destState is rated $destRating⭐? Discover its hidden trails and local culture!',
        'Looking for your next adventure? $destName in $destState is calling! Plan your trip today.',
        'Escape the routine! $destName offers breathtaking views and unforgettable experiences.',
        'Travel tip: $destName is best visited ${destData['bestTime'] ?? 'year-round'}. Start planning!',
        'Adventure awaits in $destName, $destState. Generate an AI itinerary and explore!',
        'Your next mountain escape? $destName has ${destData['places']?.length ?? 'many'} amazing places to visit!',
      ];

      final tipBody = tips[random.nextInt(tips.length)];

      final notification = AppNotification(
        id: '',
        title: '🌄 Daily Travel Inspiration',
        body: tipBody,
        type: NotificationType.dailyTip,
        createdAt: DateTime.now(),
        destinationId: randomDest.id,
        imageUrl: destImage,
      );

      await addNotification(notification);

      // Also show push notification + in-app banner
      await showPushNotification(
        title: '🌄 Daily Travel Inspiration',
        body: tipBody,
        id: 1,
      );
      _showBanner(title: '🌄 Daily Travel Inspiration', body: tipBody, icon: Icons.lightbulb_outline, iconColor: const Color(0xFF1E88E5));
    } catch (e) {
      print('Daily tip error: $e');
    }
  }

  /// Trip reminder — call when user saves a trip
  Future<void> sendTripSavedNotification(String destinationName, int days) async {
    final notification = AppNotification(
      id: '',
      title: '✅ Trip Saved!',
      body: 'Your $days-day $destinationName itinerary is saved. Don\'t forget to pack your bags!',
      type: NotificationType.tripReminder,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
    await showPushNotification(
      title: '✅ Trip Saved!',
      body: 'Your $days-day $destinationName itinerary is ready to go!',
      id: 2,
    );
    _showBanner(title: '✅ Trip Saved!', body: 'Your $days-day $destinationName itinerary is ready!', icon: Icons.luggage, iconColor: const Color(0xFF1B8A6B));
  }

  /// Weather alert — generic seasonal tip
  Future<void> sendWeatherAlert(String destinationName, String alert) async {
    final notification = AppNotification(
      id: '',
      title: '🌦️ Weather Update',
      body: '$destinationName: $alert',
      type: NotificationType.weatherAlert,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
    await showPushNotification(
      title: '🌦️ Weather Alert',
      body: '$destinationName: $alert',
      id: 3,
    );
    _showBanner(title: '🌦️ Weather Alert', body: '$destinationName: $alert', icon: Icons.cloud, iconColor: const Color(0xFF7B1FA2));
  }

  /// Welcome notification — call after first signup
  Future<void> sendWelcomeNotification(String userName) async {
    final notification = AppNotification(
      id: '',
      title: '🎉 Welcome to GoVista!',
      body: 'Hey $userName! Your AI-powered travel companion is ready. Explore 76+ destinations across the Himalayas.',
      type: NotificationType.system,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
    await showPushNotification(
      title: '🎉 Welcome to GoVista!',
      body: 'Your AI travel companion is ready. Start exploring!',
      id: 0,
    );
    _showBanner(title: '🎉 Welcome to GoVista!', body: 'Hey $userName! Explore 76+ Himalayan destinations.', icon: Icons.travel_explore, iconColor: const Color(0xFF1B8A6B));
  }

  /// Welcome back — call on every re-login
  Future<void> sendWelcomeBackNotification(String userName) async {
    final greetings = [
      'Welcome back, $userName! Ready for your next adventure?',
      'Hey $userName! The mountains missed you. Where to next?',
      'Good to see you again, $userName! New destinations are waiting.',
      '$userName is back! Let\'s plan something amazing today.',
      'Welcome back, $userName! Your saved trips are waiting for you.',
    ];
    final body = greetings[DateTime.now().millisecond % greetings.length];

    final notification = AppNotification(
      id: '',
      title: '👋 Welcome Back!',
      body: body,
      type: NotificationType.system,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
    await showPushNotification(
      title: '👋 Welcome Back!',
      body: body,
      id: 0,
    );
    _showBanner(title: '👋 Welcome Back!', body: body, icon: Icons.waving_hand, iconColor: const Color(0xFFFF9800));
  }

  /// New destination added
  Future<void> sendNewDestinationNotification(String destName, String state) async {
    final notification = AppNotification(
      id: '',
      title: '📍 New Destination Added!',
      body: '$destName, $state is now available. Be among the first to explore it!',
      type: NotificationType.newDestination,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
    await showPushNotification(
      title: '📍 New Destination!',
      body: '$destName, $state is now on GoVista!',
      id: 4,
    );
    _showBanner(title: '📍 New Destination!', body: '$destName, $state is now on GoVista!', icon: Icons.place, iconColor: const Color(0xFFE65100));
  }
}