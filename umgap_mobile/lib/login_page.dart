import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api_service.dart';
import 'home_page.dart';
import 'notification_service.dart';
import 'u_kit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading       = false;
  bool _googleLoading = false;
  bool _obscure       = true;

  late AnimationController _ac;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const _webClientId =
      '153316741169-sjsgn3bdsop41hp5m8lhf7ppifla29lu.apps.googleusercontent.com';

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
  );

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _fadeAnim  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.14), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ac.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterLogin(Map<String, dynamic> data) async {
    final role = (data['user']['role'] ?? '') as String;
    if (role != 'admin') {
      try {
        await NotificationService.scheduleAttendanceReminder(hour: 6, minute: 45);
      } catch (_) {}
    }
    try { await NotificationService.setupFCM(); } catch (_) {}
    if (!mounted) return;
    uSnack(context, 'Selamat datang kembali! 👋');
    Navigator.pushReplacement(
      context,
      uRoute(HomePage(role: role, name: data['user']['name'] ?? '')),
    );
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      HapticFeedback.vibrate();
      uSnack(context, 'Email dan password wajib diisi', isError: true);
      return;
    }
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();
    try {
      HapticFeedback.mediumImpact();
      final data = await ApiService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      await _afterLogin(data);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) { setState(() => _googleLoading = false); return; }
      final auth    = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) uSnack(context, 'Gagal mendapat token Google.', isError: true);
        setState(() => _googleLoading = false);
        return;
      }
      final data = await ApiService.googleLogin(idToken: idToken);
      await _afterLogin(data);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'sign_in_failed' when (e.message ?? '').contains('ApiException: 10') =>
        'Konfigurasi Google Sign-In belum lengkap.',
        'sign_in_failed' when (e.message ?? '').contains('ApiException: 7') =>
        'Tidak ada koneksi internet.',
        'sign_in_cancelled' => '',
        _ => 'Login Google gagal: ${e.message}',
      };
      if (msg.isNotEmpty) uSnack(context, msg, isError: true);
    } catch (e) {
      if (mounted) uSnack(context, 'Login Google gagal.', isError: true);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final anyLoading = _loading || _googleLoading;

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        // ── Hero header ─────────────────────────────
        Expanded(flex: 5, child: _buildHero()),

        // ── Form card ───────────────────────────────
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                USpace.lg, USpace.lg, USpace.lg, USpace.x2l),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildForm(anyLoading),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Hero ──────────────────────────────────────
  Widget _buildHero() {
    return UHeader(
      child: Stack(children: [
        // Orbs
        Positioned(top: -40, right: -30,
            child: _Orb(160, Colors.white.withOpacity(0.04))),
        Positioned(bottom: -20, left: -20,
            child: _Orb(100, Colors.white.withOpacity(0.04))),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.lg, 0, USpace.lg, USpace.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: USpace.xl),
              // Logo
              Container(
                padding: const EdgeInsets.all(USpace.base),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const UmgapLogo(size: 52),
              ),
              const SizedBox(height: USpace.base),
              const Text('UMGAP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  )),
              const SizedBox(height: 6),
              Text('Manajemen Karyawan Modern',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Form ──────────────────────────────────────
  Widget _buildForm(bool anyLoading) {
    return Container(
      padding: const EdgeInsets.all(USpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: UShadow.md(UColors.primary),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Selamat Datang', style: UText.h3),
        const SizedBox(height: USpace.xs),
        Text('Masuk untuk melanjutkan', style: UText.bodyS),

        const SizedBox(height: USpace.xl),

        // Email
        UField(
          controller:  _emailCtrl,
          label:       'EMAIL',
          hint:        'nama@perusahaan.com',
          keyboard:    TextInputType.emailAddress,
          prefixIcon:  Icons.email_outlined,
          onSubmitted: (_) => anyLoading ? null : _login(),
        ),

        const SizedBox(height: USpace.md),

        // Password
        UField(
          controller:    _passwordCtrl,
          label:         'PASSWORD',
          hint:          '••••••••',
          obscure:       _obscure,
          prefixIcon:    Icons.lock_outline_rounded,
          suffixWidget:  GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: UColors.textLight, size: 18,
            ),
          ),
          onSubmitted: (_) => anyLoading ? null : _login(),
        ),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/forgot'),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 0, vertical: USpace.sm)),
            child: Text('Lupa password?',
                style: UText.caption.copyWith(
                    color: UColors.primary, fontWeight: FontWeight.w700)),
          ),
        ),

        // Login button
        UButton(
          label:     'Masuk',
          onPressed: anyLoading ? null : _login,
          loading:   _loading,
          icon:      Icons.arrow_forward_rounded,
        ),

        const SizedBox(height: USpace.base),

        // Divider
        Row(children: [
          const Expanded(child: Divider(color: UColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: USpace.md),
            child: Text('atau', style: UText.caption),
          ),
          const Expanded(child: Divider(color: UColors.divider)),
        ]),

        const SizedBox(height: USpace.base),

        // Google button
        _GoogleBtn(
          loading:  _googleLoading,
          disabled: anyLoading,
          onTap:    _loginGoogle,
        ),

        const SizedBox(height: USpace.lg),

        Center(
          child: Text('UMGAP v1.1.0 • Hak Cipta Dilindungi',
              style: UText.caption.copyWith(color: UColors.textLight)),
        ),
      ]),
    );
  }
}

// ─── Google Button ─────────────────────────────
class _GoogleBtn extends StatefulWidget {
  final bool loading, disabled;
  final VoidCallback onTap;
  const _GoogleBtn({required this.loading, required this.disabled, required this.onTap});

  @override
  State<_GoogleBtn> createState() => _GoogleBtnState();
}

class _GoogleBtnState extends State<_GoogleBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); if (!widget.disabled) widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color:         Colors.white,
          borderRadius:  BorderRadius.circular(URadius.md),
          border:        Border.all(
              color: widget.disabled ? UColors.divider : UColors.divider,
              width: 1.5),
          boxShadow: widget.disabled ? [] : UShadow.sm(Colors.black),
        ),
        child: Center(
          child: widget.loading
              ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4))))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/google_icon.png', width: 20, height: 20),
            const SizedBox(width: USpace.sm),
            Text('Masuk dengan Google',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: widget.disabled ? UColors.textLight : UColors.textDark,
                )),
          ]),
        ),
      ),
    ),
  );
}

class _Orb extends StatelessWidget {
  final double size; final Color color;
  const _Orb(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}