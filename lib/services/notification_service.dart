import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Global navigator key for navigation from notification taps
  static GlobalKey<NavigatorState>? navigatorKey;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Initialize the notification service
  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for notifications
    await _requestPermissions();

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request permissions for local notifications
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      // Request permissions for Firebase messaging
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      developer.log('User granted permission: ${settings.authorizationStatus}');
    } catch (e) {
      developer.log('Permission request failed: $e');
      // Continue without permissions
    }
  }

  // Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      developer.log('FCM Token: $token');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? 'You have a new message',
          payload: message.data.toString(),
        );
      });

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // Handle notification when app is terminated
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }
    } catch (e) {
      developer.log('Firebase Messaging initialization failed: $e');
      // Continue without Firebase messaging
    }
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'workshop_notifications',
          'Workshop Notifications',
          channelDescription: 'Notifications for workshop activities',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      developer.log('Notification payload: $payload');

      // Parse the payload and handle navigation
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final type = parts[0];
        final data = parts[1];

        switch (type) {
          case 'payment':
            _navigateToPaymentDetails(data);
            break;
          case 'service_reminder':
            _navigateToServiceDetails(data);
            break;
          case 'reply':
            _navigateToReplyDetails(data);
            break;
          default:
            _handleNotificationTap({'payload': payload});
        }
      } else {
        _handleNotificationTap({'payload': payload});
      }
    }
  }

  // Navigate to payment details
  void _navigateToPaymentDetails(String paymentData) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(
        '/payment_notification',
        arguments: {'paymentId': paymentData},
      );
    }
  }

  // Navigate to service details
  void _navigateToServiceDetails(String vehicleId) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(
        '/service_notification',
        arguments: {'vehicleId': vehicleId},
      );
    }
  }

  // Navigate to reply details
  void _navigateToReplyDetails(String customerId) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(
        '/reply_notification',
        arguments: {'customerId': customerId},
      );
    }
  }

  // Handle notification tap navigation
  void _handleNotificationTap(Map<String, dynamic> data) {
    // You can implement navigation logic here based on notification data
    developer.log('Handling notification tap with data: $data');
  }

  // Public method to show service reminder notification
  Future<void> showServiceReminder({
    required String vehicleId,
    required String message,
  }) async {
    // Save to Firebase first
    await _saveNotificationToFirebase(
      type: 'service',
      title: 'Service Reminder',
      message: message,
      data: {'vehicleId': vehicleId},
    );

    await _showLocalNotification(
      title: 'Service Reminder',
      body: message,
      payload: 'service_reminder:$vehicleId',
    );
  }

  // Public method to show payment notification
  Future<void> showPaymentNotification({
    required String amount,
    required String customerId,
    String? invoiceId,
    String? customerName,
  }) async {
    // Generate payment ID in P1001 format
    String paymentId = _generatePaymentId(invoiceId ?? customerId);

    // Save to Firebase first
    await _saveNotificationToFirebase(
      type: 'payment',
      title: 'Payment Received',
      message: 'RM $amount payment confirmed',
      data: {
        'amount': amount,
        'customerId': customerId,
        'invoiceId': invoiceId,
        'customerName': customerName,
        'paymentId': paymentId,
      },
    );

    await _showLocalNotification(
      title: 'Payment Received',
      body: 'RM $amount payment confirmed',
      payload: 'payment:${invoiceId ?? customerId}',
    );
  }

  // Generate payment ID in P1001 format
  String _generatePaymentId(String sourceId) {
    // Extract numeric part from source ID if it contains numbers
    final RegExp regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(sourceId);

    if (match != null) {
      final numericPart = match.group(0)!;
      return 'P$numericPart';
    } else {
      // If no numbers found, use current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shortId = (timestamp % 10000).toString().padLeft(4, '0');
      return 'P$shortId';
    }
  }

  // Public method to show new reply notification
  Future<void> showNewReplyNotification({
    required String message,
    required String customerId,
  }) async {
    // Save to Firebase first
    await _saveNotificationToFirebase(
      type: 'reply',
      title: 'New Reply',
      message: message,
      data: {'customerId': customerId},
    );

    await _showLocalNotification(
      title: 'New Reply',
      body: message,
      payload: 'reply:$customerId',
    );
  }

  // Save notification to Firebase
  Future<void> _saveNotificationToFirebase({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Notifications').add({
        'type': type,
        'title': title,
        'message': message,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      developer.log('Notification saved to Firebase successfully');
    } catch (e) {
      developer.log('Error saving notification to Firebase: $e');
      // Don't throw - notification failure shouldn't break the flow
    }
  }

  // Get notifications from Firebase
  Future<List<Map<String, dynamic>>> getNotificationsFromFirebase() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('Notifications')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'],
          'title': data['title'],
          'message': data['message'],
          'data': data['data'] ?? {},
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.parse(
                data['createdAt'] ?? DateTime.now().toIso8601String(),
              ),
          'isRead': data['isRead'] ?? false,
        };
      }).toList();
    } catch (e) {
      developer.log('Error fetching notifications from Firebase: $e');
      return [];
    }
  }

  // Mark notification as read in Firebase
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .update({'isRead': true});
      developer.log('Notification marked as read in Firebase');
    } catch (e) {
      developer.log('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read in Firebase
  Future<void> markAllNotificationsAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('Notifications')
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      developer.log('All notifications marked as read in Firebase');
    } catch (e) {
      developer.log('Error marking all notifications as read: $e');
    }
  }

  // Delete notification from Firebase
  Future<void> deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notificationId)
          .delete();
      developer.log('Notification deleted from Firebase');
    } catch (e) {
      developer.log('Error deleting notification: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  // Delete all notifications from Firebase
  Future<void> deleteAllNotifications() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot =
          await FirebaseFirestore.instance.collection('Notifications').get();

      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      developer.log('All notifications deleted from Firebase');
    } catch (e) {
      developer.log('Error deleting all notifications: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  // Get FCM token for sending targeted notifications
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
}
