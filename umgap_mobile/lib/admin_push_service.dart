import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';

class AdminPushService {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    await Firebase.initializeApp();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ambil token awal
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _sendTokenToBackend(token);
    }

    // kalau token berubah
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(newToken);
    });

    // optional: foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // kalau mau nanti bisa dipantulkan ke local notification
      // print('FCM foreground: ${message.notification?.title}');
    });

    _ready = true;
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      await ApiService.registerFcmToken(
        token: fcmToken,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
    } catch (_) {
      // diamkan dulu supaya login tidak gagal hanya karena push token
    }
  }
}