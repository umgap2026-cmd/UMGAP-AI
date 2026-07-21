import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

import '../api_service.dart';

// ════════════════════════════════════════════
//  BACKGROUND HANDLER — harus top-level function
// ════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Tampilkan notifikasi lokal saat app di background/terminated
  await NotificationService.init();
  await NotificationService.showFcmNotification(message);
}

// ════════════════════════════════════════════
//  NOTIFICATION SERVICE
// ════════════════════════════════════════════
class NotificationService {

  static final _onMessageController =
  StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get onMessageStream =>
      _onMessageController.stream;

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _fcmSetup    = false;

  // ── Init ────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Buat channel Android
    const channel = AndroidNotificationChannel(
      'umgap_main_channel',
      'UMGAP Notifikasi',
      description: 'Notifikasi absensi dan pengumuman UMGAP',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Buat channel pengingat absen
    const reminderChannel = AndroidNotificationChannel(
      'umgap_reminder_channel',
      'Pengingat Absen Harian',
      description: 'Pengingat absen setiap pagi',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);

    await _requestPermissions();
    _initialized = true;
  }

  static void _onTap(NotificationResponse res) {
    // Bisa tambahkan navigasi ke halaman tertentu di sini
  }

  // ── Request permissions ──────────────────────
  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      final p = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await p?.requestNotificationsPermission();
      await p?.requestExactAlarmsPermission();
    }
    if (Platform.isIOS) {
      final p = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await p?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── Notification details ─────────────────────
  static NotificationDetails _details({String channel = 'umgap_main_channel'}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channel == 'umgap_main_channel' ? 'UMGAP Notifikasi' : 'Pengingat Absen',
        channelDescription: 'Notifikasi UMGAP',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ════════════════════════════════════════════
  //  FIREBASE MESSAGING SETUP
  // ════════════════════════════════════════════
  static Future<void> setupFCM() async {
    if (_fcmSetup) {
      // Hanya refresh token, jangan tambah listener baru
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _registerToken(token);
      } catch (_) {}
      return;
    }
    _fcmSetup = true;

    final messaging = FirebaseMessaging.instance;

    // Minta permission FCM
    await messaging.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,
    );

    // Paksa tampilkan notif saat app foreground (iOS)
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Dapatkan token dan daftarkan ke backend
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      await _registerToken(newToken);
    });

    // ── Foreground: app sedang dibuka ──────────
    // SATU listener saja — tampilkan notif + trigger badge stream
    FirebaseMessaging.onMessage.listen((message) async {
      await showFcmNotification(message);
      _onMessageController.add(message); // trigger badge refresh di home
    });

    // ── Background tap: user klik notif ────────
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _onMessageController.add(message); // trigger badge refresh
    });

    // ── Terminated: app di-launch dari notif ───
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _onMessageController.add(initial);
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await ApiService.registerFcmToken(token: token, platform: platform);
    } catch (_) {}
  }

  // ── Tampilkan notif dari FCM ─────────────────
  static Future<void> showFcmNotification(RemoteMessage message) async {
    // Ambil dari notification block dulu, fallback ke data (data-only message)
    final title = message.notification?.title
        ?? message.data['title']
        ?? 'UMGAP';
    final body  = message.notification?.body
        ?? message.data['body']
        ?? '';

    if (body.isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'umgap_main_channel',
          'UMGAP Notifikasi',
          channelDescription: 'Notifikasi absensi dan pengumuman UMGAP',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ════════════════════════════════════════════
  //  LOCAL SCHEDULED — Pengingat 06:45 WIB
  // ════════════════════════════════════════════
  static Future<void> scheduleAttendanceReminder({
    int hour   = 6,
    int minute = 45,
  }) async {
    await _plugin.cancel(1001);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      hour, minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    debugPrint('=== REMINDER: now=$now, scheduled=$scheduled, diff=${scheduled.difference(now).inMinutes} menit');

    await _plugin.zonedSchedule(
      1001,
      '⏰ Waktunya Absen!',
      'Jangan lupa check-in hari ini. Buka UMGAP sekarang.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'umgap_reminder_channel',
          'Pengingat Absen Harian',
          channelDescription: 'Pengingat absen setiap pagi',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock, // ← ganti ini
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      // matchDateTimeComponents dihapus dulu untuk test
    );

    debugPrint('=== REMINDER scheduled OK');
  }

  static Future<void> cancelAttendanceReminder() async {
    await _plugin.cancel(1001);

  }

  // ── Show instant notification (manual) ───────
  static Future<void> showNow({
    required String title,
    required String body,
    int id = 9000,
  }) async {
    await _plugin.show(id, title, body, _details());
  }

  static Future<void> showTestNotification() async {
    await showNow(
      id:    9999,
      title: '✅ Test Notifikasi',
      body:  'Notifikasi UMGAP berhasil aktif!',
    );
  }
}