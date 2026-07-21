import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'notification_service.dart';
import 'u_kit.dart';
import 'api_service.dart';

// ── Color tokens ─────────────────────────────
const _navy    = Color(0xFF0B1733);
const _navyMid = Color(0xFF14275C);
const _blue    = Color(0xFF1565C0);
const _cyan    = Color(0xFF29B6F6);
const Color _white = Color(0xFFFFFFFF);

// ── Background FCM handler (top-level, wajib) ─
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage msg) =>
    firebaseMessagingBackgroundHandler(msg);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  FlutterError.onError = (FlutterErrorDetails d) {
    FlutterError.presentError(d);
    debugPrint('FLUTTER ERROR: ${d.exception}');
  };

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Wajib dipanggil SEBELUM runApp agar foreground notif tampil
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await NotificationService.init();

    // Minta izin exact alarm (Android 12+)
    if (Platform.isAndroid) {
      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    }

    debugPrint('APP START');
  } catch (e) {
    debugPrint('INIT ERROR: $e');
  }

  runApp(const UmgapApp());
}


// ════════════════════════════════════════════
//  APP ROOT
// ════════════════════════════════════════════
class UmgapApp extends StatefulWidget {
  const UmgapApp({super.key});
  @override
  State<UmgapApp> createState() => _UmgapAppState();
}

class _UmgapAppState extends State<UmgapApp> {
  @override
  void initState() {
    super.initState();
    _postInit();
  }

  Future<void> _postInit() async {
    try {
      await NotificationService.setupFCM();

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('=== FCM TOKEN: $token ===');

      // Restore reminder jika sebelumnya aktif
      const storage = FlutterSecureStorage();
      final remOn = await storage.read(key: 'reminder_on') ?? 'false';
      if (remOn == 'true') {
        final h = int.tryParse(
            await storage.read(key: 'reminder_hour') ?? '6') ??
            6;
        final m = int.tryParse(
            await storage.read(key: 'reminder_minute') ?? '45') ??
            45;
        await NotificationService.scheduleAttendanceReminder(
            hour: h, minute: m);
        debugPrint('=== Reminder restored: $h:$m ===');
      }
    } catch (e) {
      debugPrint('POST INIT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UMGAP',
      theme: ThemeData(
        colorSchemeSeed: UColors.primary,
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF2F5FC),
      ),
      home: const SplashPage(),
    );
  }
}

// ════════════════════════════════════════════
//  SPLASH PAGE — selaras dengan home_page
// ════════════════════════════════════════════
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _shimmerCtrl;

  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slide = Tween<Offset>(
        begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));

    _shimmer = CurvedAnimation(
        parent: _shimmerCtrl, curve: Curves.easeInOut);

    _checkLogin();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Versi aplikasi saat ini — update setiap rilis ──
  static const _currentVersion = '1.2.0';

  Future<void> _checkLogin() async {
    // Minimum splash duration
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // ── Cek versi sebelum lanjut ──────────────────────
    final shouldBlock = await _checkVersion();
    if (shouldBlock) return; // berhenti di sini, dialog sudah tampil

    final token = await _storage.read(key: 'token');
    final role  = await _storage.read(key: 'role');
    final name  = await _storage.read(key: 'name');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      uRoute(
        (token != null && token.isNotEmpty)
            ? HomePage(role: role ?? '', name: name ?? '')
            : const LoginPage(),
      ),
    );
  }

  // ── Cek versi ke server ────────────────────────────
  Future<bool> _checkVersion() async {
    try {
      final data = await ApiService.checkVersion();
      final forceUpdate    = data['force_update'] == true;
      final latestVersion  = data['latest_version'] ?? _currentVersion;
      final updateUrl      = data['update_url'] ?? '';
      final message        = data['message'] ?? 'Silakan update aplikasi.';

      if (forceUpdate && _currentVersion != latestVersion && mounted) {
        await _showForceUpdateDialog(message, updateUrl);
        return true; // block navigasi
      }
    } catch (_) {
      // Kalau server tidak bisa dihubungi, tetap lanjut
    }
    return false;
  }

  // ── Dialog force update ────────────────────────────
  Future<void> _showForceUpdateDialog(String message, String updateUrl) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Color(0xFF1565C0), size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Update Diperlukan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568))),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
              onPressed: () async {
                if (updateUrl.isNotEmpty) {
                  final uri = Uri.parse(updateUrl);
                  // ignore: deprecated_member_use
                  await canLaunchUrl(uri)
                  // ignore: deprecated_member_use
                      ? await launchUrl(uri,
                      mode: LaunchMode.externalApplication)
                      : null;
                }
              },
              child: const Text('Update Sekarang',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, _navyMid, _blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // ── Decorative orbs ──────────────
          Positioned(top: -50,   right: -30,
              child: _SplashOrb(160, Colors.white.withOpacity(0.04))),
          Positioned(top: 80,    right: 80,
              child: _SplashOrb(60,  Colors.white.withOpacity(0.03))),
          Positioned(bottom: -40, left: -30,
              child: _SplashOrb(180, Colors.white.withOpacity(0.04))),
          Positioned(bottom: 100, left: 60,
              child: _SplashOrb(50,  Colors.white.withOpacity(0.03))),

          // Accent line bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_cyan.withOpacity(0), _cyan, _cyan.withOpacity(0)],
                ),
              ),
            ),
          ),

          // ── Center content ───────────────
          SafeArea(
            child: Center(
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo ring
                      AnimatedBuilder(
                        animation: _shimmer,
                        builder: (_, child) => Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _cyan.withOpacity(
                                  0.2 + _shimmer.value * 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cyan.withOpacity(
                                    0.15 + _shimmer.value * 0.2),
                                blurRadius: 30 + _shimmer.value * 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: child,
                        ),
                        child: const UmgapLogo(size: 64),
                      ),

                      const SizedBox(height: 28),

                      // UMGAP wordmark
                      const Text('UMGAP',
                          style: TextStyle(
                              color: _white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 7)),

                      const SizedBox(height: 8),

                      // Divider aksen
                      Container(
                        width: 48, height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_cyan, _blue]),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text('Manajemen Karyawan Modern',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.50),
                              fontSize: 13,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500)),

                      const SizedBox(height: 52),

                      // Loading indicator
                      SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _cyan.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Splash orb ───────────────────────────────
class _SplashOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _SplashOrb(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}