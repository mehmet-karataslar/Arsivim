import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/reminder_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Set local timezone
      final String timeZoneName = _getLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings
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

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      _isInitialized = true;
      print('✅ Notification service initialized successfully');
    } catch (e) {
      print('❌ Notification service initialization failed: $e');
    }
  }

  /// Get local timezone name
  String _getLocalTimeZone() {
    // Default to Europe/Berlin for German timezone
    // You can make this configurable based on user settings
    return 'Europe/Berlin';
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reminders',
      'Hatırlatıcılar',
      description: 'Arşiv uygulaması hatırlatıcı bildirimleri',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Here you can navigate to specific screens based on payload
    // For example, navigate to calendar screen or specific reminder
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  /// Schedule notification for reminder
  Future<void> scheduleReminder(ReminderModel reminder) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!reminder.isEnabled) return;

    try {
      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        reminder.reminderDate,
        tz.local,
      );

      // Check if the scheduled date is in the future
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print('⚠️ Reminder date is in the past, skipping: ${reminder.title}');
        return;
      }

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'reminders',
        'Hatırlatıcılar',
        channelDescription: 'Arşiv uygulaması hatırlatıcı bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        reminder.id ?? DateTime.now().millisecondsSinceEpoch,
        reminder.title,
        reminder.description,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_${reminder.id}',
      );

      print('✅ Reminder scheduled: ${reminder.title} at $scheduledDate');

      // Schedule recurring reminders if needed
      if (reminder.recurrenceType != RecurrenceType.NONE) {
        await _scheduleRecurringReminder(reminder, scheduledDate);
      }
    } catch (e) {
      print('❌ Error scheduling reminder: $e');
    }
  }

  /// Schedule recurring reminders
  Future<void> _scheduleRecurringReminder(
    ReminderModel reminder,
    tz.TZDateTime initialDate,
  ) async {
    if (reminder.recurrenceType == RecurrenceType.NONE) return;

    // Schedule up to 10 occurrences in advance
    tz.TZDateTime nextDate = initialDate;
    for (int i = 0; i < 10; i++) {
      nextDate = _calculateNextOccurrence(nextDate, reminder.recurrenceType, reminder.recurrenceInterval ?? 1);
      
      if (nextDate.isAfter(tz.TZDateTime.now(tz.local).add(const Duration(days: 365)))) {
        break; // Don't schedule more than 1 year in advance
      }

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'reminders',
        'Hatırlatıcılar',
        channelDescription: 'Arşiv uygulaması hatırlatıcı bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      final int notificationId = (reminder.id ?? 0) * 1000 + i + 1;

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        reminder.title,
        reminder.description,
        nextDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_${reminder.id}_recurring_$i',
      );
    }
  }

  /// Calculate next occurrence based on recurrence type
  tz.TZDateTime _calculateNextOccurrence(
    tz.TZDateTime currentDate,
    RecurrenceType recurrenceType,
    int interval,
  ) {
    switch (recurrenceType) {
      case RecurrenceType.DAILY:
        return currentDate.add(Duration(days: interval));
      case RecurrenceType.WEEKLY:
        return currentDate.add(Duration(days: 7 * interval));
      case RecurrenceType.MONTHLY:
        return tz.TZDateTime(
          tz.local,
          currentDate.year,
          currentDate.month + interval,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      case RecurrenceType.QUARTERLY:
        return tz.TZDateTime(
          tz.local,
          currentDate.year,
          currentDate.month + (3 * interval),
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      case RecurrenceType.YEARLY:
        return tz.TZDateTime(
          tz.local,
          currentDate.year + interval,
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
      case RecurrenceType.CUSTOM:
        return currentDate.add(Duration(days: interval));
      default:
        return currentDate;
    }
  }

  /// Cancel reminder notification
  Future<void> cancelReminder(int reminderId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(reminderId);
      
      // Cancel recurring notifications (up to 10)
      for (int i = 1; i <= 10; i++) {
        await _flutterLocalNotificationsPlugin.cancel(reminderId * 1000 + i);
      }
      
      print('✅ Reminder cancelled: $reminderId');
    } catch (e) {
      print('❌ Error cancelling reminder: $e');
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'reminders',
      'Hatırlatıcılar',
      channelDescription: 'Arşiv uygulaması hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
} 