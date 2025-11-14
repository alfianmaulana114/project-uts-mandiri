import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Service untuk handle local notifications
/// Menggunakan flutter_local_notifications untuk scheduling notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Inisialisasi notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    try {
      // Gunakan offset dari DateTime untuk memetakan ke IANA timezone (Indonesia)
      final int offsetHours = DateTime.now().timeZoneOffset.inHours;
      final String iana = _mapOffsetToIana(offsetHours);
      tz.setLocalLocation(tz.getLocation(iana));
      print('🕒 Using timezone (by offset): ' + iana + ' (UTC' + (offsetHours >= 0 ? '+' : '') + offsetHours.toString() + ')');
    } catch (e) {
      // Fallback ke Asia/Jakarta jika gagal deteksi timezone
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      print('⚠️ Failed to set timezone by offset, fallback to Asia/Jakarta. Error: ' + e.toString());
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions untuk Android
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      // Request notification permission (Android 13+)
      final permissionGranted = await androidImplementation.requestNotificationsPermission();
      print('📱 Notification permission granted: $permissionGranted');
      final areEnabled = await androidImplementation.areNotificationsEnabled();
      print('📱 Are notifications enabled (system-level): $areEnabled');
      
      // Request exact alarm permission (Android 12+)
      final exactAlarmRequested = await androidImplementation.requestExactAlarmsPermission();
      print('⏰ Exact alarms permission request result: $exactAlarmRequested');
      
      // Create notification channel untuk Android 8.0+
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'deadline_channel',
          'Deadline Reminders',
          description: 'Notifications untuk reminder deadline todo',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      print('📱 Notification channel created');
    }

    // Request permissions untuk iOS
    final iosImplementation = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  /// Map offset jam ke IANA timezone untuk wilayah Indonesia
  /// 7 -> Asia/Jakarta (WIB), 8 -> Asia/Makassar (WITA), 9 -> Asia/Jayapura (WIT)
  String _mapOffsetToIana(int offsetHours) {
    switch (offsetHours) {
      case 7:
        return 'Asia/Jakarta';
      case 8:
        return 'Asia/Makassar';
      case 9:
        return 'Asia/Jayapura';
      default:
        // Default ke Asia/Jakarta untuk mayoritas pengguna
        return 'Asia/Jakarta';
    }
  }

  /// Handler ketika notification di-tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📲 Notification tapped: ${response.id}');
  }

  /// Schedule notifications untuk deadline todo
  /// Sesuai permintaan: 1 minggu, 3 hari, 2 hari, 1 hari, 12 jam,
  /// 6 jam, 3 jam, 2 jam, 1 jam, 30 menit, 15 menit, 10 menit,
  /// 5 menit, 1 menit sebelum deadline
  Future<void> scheduleDeadlineNotifications({
    required String todoId,
    required String todoTitle,
    required DateTime deadline,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel existing notifications untuk todo ini
    await cancelDeadlineNotifications(todoId);

    // List waktu reminder sesuai permintaan user
    final reminderIntervals = [
      const Duration(days: 7),       // 1 minggu
      const Duration(days: 3),       // 3 hari
      const Duration(days: 2),       // 2 hari
      const Duration(days: 1),       // 1 hari
      const Duration(hours: 12),     // 12 jam
      const Duration(hours: 6),      // 6 jam
      const Duration(hours: 3),      // 3 jam
      const Duration(hours: 2),      // 2 jam
      const Duration(hours: 1),      // 1 jam
      const Duration(minutes: 30),   // 30 menit
      const Duration(minutes: 15),   // 15 menit
      const Duration(minutes: 10),   // 10 menit
      const Duration(minutes: 5),    // 5 menit
      const Duration(minutes: 1),    // 1 menit
    ];

    int notificationId = 0;
    final now = tz.TZDateTime.now(tz.local);
    final deadlineTz = tz.TZDateTime.from(deadline, tz.local);

    for (final interval in reminderIntervals) {
      final reminderTime = deadlineTz.subtract(interval);

      // Skip jika waktu reminder sudah lewat (kecuali saat deadline yang masih future)
      if (reminderTime.isBefore(now) && interval.inSeconds > 0) {
        continue;
      }

      notificationId++;

      // Generate unique notification ID: todoId + notificationId
      // Menggunakan hash dari todoId untuk mendapatkan base ID
      final baseId = todoId.hashCode.abs() % 10000;
      final uniqueId = baseId * 1000 + notificationId; // Gunakan 1000 untuk lebih banyak slot

      final title = _getNotificationTitle(interval, deadlineTz);
      final body = 'Deadline: $todoTitle';

      await _scheduleNotification(
        id: uniqueId,
        title: title,
        body: body,
        scheduledDate: reminderTime,
        payload: todoId,
      );

      print('📅 Scheduled notification: $title at ${reminderTime.toString()}');
    }
    
    // Fallback: jika semua interval terlewat (tidak ada schedule), buat satu notifikasi testing
    if (notificationId == 0) {
      final fallbackTime = now.add(const Duration(seconds: 30));
      final fallbackTitle = '⚡ Pengingat cepat (uji notifikasi)';
      final fallbackBody = 'Tes notifikasi untuk: ' + todoTitle;
      // Generate fallback unique ID
      final baseId = todoId.hashCode.abs() % 10000;
      final uniqueId = baseId * 1000 + 999; // gunakan slot 999 untuk fallback

      await _scheduleNotification(
        id: uniqueId,
        title: fallbackTitle,
        body: fallbackBody,
        scheduledDate: fallbackTime,
        payload: todoId,
      );
      print('🛟 Fallback notification scheduled at ${fallbackTime.toString()}');
    }

    print('✅ Scheduled ${notificationId} notifications for todo: $todoTitle');
  }

  /// Get notification title berdasarkan interval
  String _getNotificationTitle(Duration interval, tz.TZDateTime deadline) {
    if (interval.inSeconds == 0) {
      return '🚨 DEADLINE SEKARANG!';
    } else if (interval.inDays >= 30) {
      return '📅 Deadline dalam 1 bulan';
    } else if (interval.inDays >= 14) {
      return '📅 Deadline dalam 2 minggu';
    } else if (interval.inDays >= 7) {
      return '📅 Deadline dalam 1 minggu';
    } else if (interval.inDays >= 3) {
      return '📅 Deadline dalam 3 hari';
    } else if (interval.inDays >= 2) {
      return '📅 Deadline dalam 2 hari';
    } else if (interval.inHours >= 24 || interval.inDays >= 1) {
      return '⏰ Deadline dalam 1 hari';
    } else if (interval.inHours >= 12) {
      return '⏰ Deadline dalam 12 jam';
    } else if (interval.inHours >= 6) {
      return '⏰ Deadline dalam 6 jam';
    } else if (interval.inHours >= 3) {
      return '⏰ Deadline dalam 3 jam';
    } else if (interval.inHours >= 2) {
      return '⏰ Deadline dalam 2 jam';
    } else if (interval.inHours >= 1) {
      return '⏰ Deadline dalam 1 jam';
    } else if (interval.inMinutes >= 30) {
      return '⚡ Deadline dalam 30 menit';
    } else if (interval.inMinutes >= 15) {
      return '⚡ Deadline dalam 15 menit';
    } else if (interval.inMinutes >= 10) {
      return '⚡ Deadline dalam 10 menit';
    } else if (interval.inMinutes >= 5) {
      return '⚡ Deadline dalam 5 menit';
    } else if (interval.inMinutes >= 1) {
      return '⚡ Deadline dalam 1 menit';
    } else {
      return '🚨 DEADLINE SEKARANG!';
    }
  }

  /// Schedule single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // Convert DateTime to TZDateTime
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // Android notification details - Native-like notifications seperti HP
      final androidDetails = AndroidNotificationDetails(
        'deadline_channel',
        'Deadline Reminders',
        channelDescription: 'Notifications untuk reminder deadline todo',
        importance: Importance.max, // Max importance untuk muncul di atas
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]), // Vibration pattern
        playSound: true,
        // Gunakan default sound system
        icon: '@mipmap/ic_launcher', // Small icon (akan muncul di status bar)
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Large icon (untuk expanded notification)
        styleInformation: BigTextStyleInformation(
          body, // Body text untuk expanded view
          htmlFormatBigText: false,
          contentTitle: title,
        ),
        visibility: NotificationVisibility.public, // Tampilkan di lock screen
        category: AndroidNotificationCategory.reminder, // Category reminder
        channelShowBadge: true, // Show badge
        ongoing: false,
        autoCancel: true, // Auto cancel ketika di-tap
        ticker: 'Deadline reminder', // Ticker text (muncul saat notification masuk)
        showProgress: false,
      );

      // iOS notification details - Native iOS notifications
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, // Tampilkan alert
        presentBadge: true, // Tampilkan badge
        presentSound: true, // Play sound
        sound: 'default', // Default iOS sound
        interruptionLevel: InterruptionLevel.active, // Active interruption (muncul di atas)
        threadIdentifier: 'deadline-reminders', // Thread identifier untuk grouping
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Pastikan waktu scheduled date di masa depan
      if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print('⚠️ Skipping notification scheduled in the past: ${tzScheduledDate.toString()}');
        return;
      }

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Exact scheduling, even in doze mode
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      print('✅ Notification scheduled: $title at ${tzScheduledDate.toString()}');
      print('   Current time: ${tz.TZDateTime.now(tz.local).toString()}');
      print('   Time until notification: ${tzScheduledDate.difference(tz.TZDateTime.now(tz.local))}');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Cancel semua notifications untuk todo tertentu
  Future<void> cancelDeadlineNotifications(String todoId) async {
    try {
      // Cancel notifications dengan ID yang berhubungan dengan todoId
      // Kita cancel dengan range ID yang mungkin digunakan (18 notifikasi)
      final baseId = todoId.hashCode.abs() % 10000;
      
      for (int i = 1; i <= 18; i++) {
        final uniqueId = baseId * 1000 + i;
        await _notifications.cancel(uniqueId);
      }

      print('✅ Cancelled notifications for todo: $todoId');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }

  /// Cancel semua notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('✅ Cancelled all notifications');
  }

  /// Show immediate notification (untuk testing)
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'deadline_channel',
      'Deadline Reminders',
      channelDescription: 'Notifications untuk reminder deadline todo',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      channelShowBadge: true,
      autoCancel: true,
      ticker: 'Test notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.active,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      'Test Notification',
      'Notification service is working!',
      notificationDetails,
    );
  }
}

