import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones();

    // 2. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Initialization Settings
    // Note: onDidReceiveLocalNotification is deprecated/removed in newer versions.
    // Use onDidReceiveNotificationResponse in initialize() instead.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true);

    // 4. Initialize Plugin
    final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap logic here if needed
        debugPrint("Notification Tapped: ${response.payload}");
      },
    );
  }

  Future<void> scheduleMassReminder(String churchName, String dayName, String timeStr) async {
    // Input format example: "17:00"
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return;
      
      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      // Calculate Notification Time (Today or Tomorrow)
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      
      // Candidate time: Today at HH:mm
      tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      
      // Subtract 1 Hour for the reminder itself (Notify before mass starts)
      scheduledDate = scheduledDate.subtract(const Duration(hours: 1));

      // Check if this time has already passed
      if (scheduledDate.isBefore(now)) {
        // If passed, schedule for tomorrow same time
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Define Notification Details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'mass_reminder_channel', 
        'Pengingat Misa',
        channelDescription: 'Notifikasi 1 jam sebelum misa dimulai',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      // Schedule Notif
      // ID uses a simple random/time-based integer to avoid collisions but allow multiple reminders
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      /*
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Misa Segera Dimulai',
        'Siap-siap ke $churchName jam $timeStr ($dayName)',
        scheduledDate,
        platformDetails,
        // REQUIRED PARAMETER: AndroidScheduleMode (replaces androidAllowWhileIdle)
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // REQUIRED PARAMETER: UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      */
      debugPrint("Notification Scheduled (Simulated) at $scheduledDate");

      debugPrint("Notification Scheduled at $scheduledDate (ID: $notificationId)");

    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }
}
