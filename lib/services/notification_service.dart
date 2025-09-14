import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request permissions for Firebase messaging
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
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
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
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
      // Handle navigation based on payload
      _handleNotificationTap({'payload': payload});
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
  }) async {
    await _showLocalNotification(
      title: 'Payment Received',
      body: 'RM $amount payment confirmed',
      payload: 'payment:$customerId',
    );
  }

  // Public method to show new reply notification
  Future<void> showNewReplyNotification({
    required String message,
    required String customerId,
  }) async {
    await _showLocalNotification(
      title: 'New Reply',
      body: message,
      payload: 'reply:$customerId',
    );
  }

  // Get FCM token for sending targeted notifications
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
}