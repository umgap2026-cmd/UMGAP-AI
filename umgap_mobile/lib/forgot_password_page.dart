import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'u_kit.dart';

enum _FpMethod { wa, email }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _step = 1; // 1 = pilih metode, 2 = OTP, 3 = password baru

  _FpMethod? _method;
  final _identifierCtrl = TextEditingController();

  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());

  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;

  String _maskedTarget = '';
  String? _resetToken;

  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _identifier => _identifierCtrl.text.trim();
  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 45);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown -= 1;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    if (_method == null) {
      uSnack(context, 'Pilih metode verifikasi dulu', isError: true);
      return;
    }
    if (_identifier.isEmpty) {
      uSnack(context, 'Isi email atau nomor WhatsApp dulu', isError: true);
      return;
    }
    if (_method == _FpMethod.email && !_identifier.contains('@')) {
      uSnack(context, 'Format email tidak valid', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      final data = await ApiService.forgotPasswordRequest(_identifier);
      if (!mounted) return;
      setState(() {
        _maskedTarget = (data['masked_wa'] ?? data['masked_email'] ?? '').toString();
        _step = 2;
      });
      for (final c in _otpCtrls) {
        c.clear();
      }
      _startCooldown();
      FocusScope.of(context).requestFocus(_otpFocus[0]);
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        uSnack(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6 || _verifying) return;
    setState(() => _verifying = true);
    try {
      final data = await ApiService.forgotPasswordVerify(
        identifier: _identifier,
        otp: _otp,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = (data['reset_token'] ?? '').toString();
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      uSnack(context, e.toString(), isError: true);
      for (final c in _otpCtrls) {
        c.clear();
      }
      FocusScope.of(context).requestFocus(_otpFocus[0]);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _savePassword() async {
    final pw = _newPwCtrl.text;
    final cpw = _confirmPwCtrl.text;
    if (pw.isEmpty || cpw.isEmpty) {
      uSnack(context, 'Isi password baru dan konfirmasinya', isError: true);
      return;
    }
    if (pw.length < 6) {
      uSnack(context, 'Password minimal 6 karakter', isError: true);
      return;
    }
    if (pw != cpw) {
      uSnack(context, 'Konfirmasi password tidak sama', isError: true);
      return;
    }
    if (_resetToken == null || _resetToken!.isEmpty) {
      uSnack(context, 'Sesi reset tidak valid, mulai ulang.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.forgotPasswordReset(
        resetToken: _resetToken!,
        newPassword: pw,
      );
      if (!mounted) return;
      uSnack(context, 'Password berhasil diubah. Silakan login.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _backToStep1() {
    _cooldownTimer?.cancel();
    setState(() {
      _step = 1;
      _cooldown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              USpace.lg, USpace.base, USpace.lg, USpace.x2l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: UColors.card,
                    borderRadius: BorderRadius.circular(URadius.sm),
                    boxShadow: UShadow.sm(UColors.primary),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: UColors.textDark, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: USpace.lg),
            _buildStepDots(),
            const SizedBox(height: USpace.lg),
            if (_step == 1) _buildStep1(),
            if (_step == 2) _buildStep2(),
            if (_step == 3) _buildStep3(),
          ]),
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    Widget dot(bool active) => Expanded(
      child: Container(
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(URadius.full),
          gradient: active
              ? const LinearGradient(colors: [UColors.primary, UColors.primaryMid])
              : null,
          color: active ? null : UColors.divider,
        ),
      ),
    );
    return Row(children: [
      dot(_step >= 1), dot(_step >= 2), dot(_step >= 3),
    ]);
  }

  // ── STEP 1: pilih metode + identifier ──────────────
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Lupa Password', style: UText.h2),
      const SizedBox(height: USpace.xs),
      Text('Pilih cara verifikasi buat reset password akunmu.',
          style: UText.body),
      const SizedBox(height: USpace.xl),
      Row(children: [
        Expanded(child: _methodChip(
          method: _FpMethod.wa,
          icon: Icons.chat_bubble_rounded,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
        )),
        const SizedBox(width: USpace.md),
        Expanded(child: _methodChip(
          method: _FpMethod.email,
          icon: Icons.email_rounded,
          label: 'Email',
          color: const Color(0xFFEA4335),
        )),
      ]),
      const SizedBox(height: USpace.lg),
      UField(
        controller: _identifierCtrl,
        label: _method == _FpMethod.email ? 'EMAIL' : 'NO. WHATSAPP',
        hint: _method == _FpMethod.email
            ? 'email@domain.com'
            : '08xxxxxxxxxx',
        keyboard: _method == _FpMethod.email
            ? TextInputType.emailAddress
            : TextInputType.phone,
        prefixIcon: _method == _FpMethod.email
            ? Icons.email_outlined
            : Icons.phone_outlined,
        onSubmitted: (_) => _sending ? null : _sendOtp(),
      ),
      const SizedBox(height: USpace.xl),
      UButton(
        label: 'Kirim Kode OTP',
        loading: _sending,
        onPressed: _sending ? null : _sendOtp,
        icon: Icons.send_rounded,
      ),
    ]);
  }

  Widget _methodChip({
    required _FpMethod method,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final selected = _method == method;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _method = method);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: USpace.lg),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg),
          border: Border.all(
              color: selected ? color : UColors.divider, width: 1.6),
          boxShadow: selected ? UShadow.sm(color) : UShadow.card,
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: USpace.sm),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: selected ? color : UColors.textMid,
          )),
        ]),
      ),
    );
  }

  // ── STEP 2: OTP ─────────────────────────────────────
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Masukkan Kode OTP', style: UText.h2),
      const SizedBox(height: USpace.xs),
      Text(
        _maskedTarget.isEmpty
            ? 'Kode 6 digit sudah dikirim. Berlaku 10 menit.'
            : 'Kode 6 digit dikirim ke $_maskedTarget. Berlaku 10 menit.',
        style: UText.body,
      ),
      const SizedBox(height: USpace.xl),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => _otpBox(i)),
      ),
      const SizedBox(height: USpace.xl),
      UButton(
        label: 'Verifikasi',
        loading: _verifying,
        onPressed: (_otp.length == 6 && !_verifying) ? _verifyOtp : null,
        icon: Icons.check_circle_outline_rounded,
      ),
      const SizedBox(height: USpace.lg),
      Center(
        child: _cooldown > 0
            ? Text('Kirim ulang OTP dalam ${_cooldown}s',
                style: UText.caption)
            : TextButton(
                onPressed: _sending ? null : _sendOtp,
                child: Text('Kirim ulang OTP',
                    style: UText.bodyS.copyWith(
                        color: UColors.primary, fontWeight: FontWeight.w700)),
              ),
      ),
      Center(
        child: TextButton(
          onPressed: _backToStep1,
          child: Text('← Ganti metode verifikasi',
              style: UText.caption.copyWith(color: UColors.textSoft)),
        ),
      ),
    ]);
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 44, height: 54,
      child: TextField(
        controller: _otpCtrls[i],
        focusNode: _otpFocus[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: UColors.textDark),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: UColors.inputBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: const BorderSide(color: UColors.primaryMid, width: 1.5)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            FocusScope.of(context).requestFocus(_otpFocus[i + 1]);
          }
          if (v.isEmpty && i > 0) {
            FocusScope.of(context).requestFocus(_otpFocus[i - 1]);
          }
          setState(() {});
          if (_otp.length == 6) _verifyOtp();
        },
      ),
    );
  }

  // ── STEP 3: password baru ──────────────────────────
  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 64, height: 64,
        margin: const EdgeInsets.only(bottom: USpace.base),
        decoration: BoxDecoration(
          color: UColors.successLight,
          shape: BoxShape.circle,
          border: Border.all(color: UColors.success, width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: UColors.success, size: 32),
      ),
      Text('Verifikasi Berhasil', style: UText.h2),
      const SizedBox(height: USpace.xs),
      Text('Sekarang buat password baru untuk akunmu.', style: UText.body),
      const SizedBox(height: USpace.xl),
      UField(
        controller: _newPwCtrl,
        label: 'PASSWORD BARU',
        hint: 'Minimal 6 karakter',
        obscure: _obscureNew,
        prefixIcon: Icons.lock_outline_rounded,
        suffixWidget: GestureDetector(
          onTap: () => setState(() => _obscureNew = !_obscureNew),
          child: Icon(
            _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: UColors.textLight, size: 18,
          ),
        ),
      ),
      const SizedBox(height: USpace.md),
      UField(
        controller: _confirmPwCtrl,
        label: 'KONFIRMASI PASSWORD',
        hint: 'Ulangi password baru',
        obscure: _obscureConfirm,
        prefixIcon: Icons.lock_outline_rounded,
        suffixWidget: GestureDetector(
          onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
          child: Icon(
            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: UColors.textLight, size: 18,
          ),
        ),
        onSubmitted: (_) => _saving ? null : _savePassword(),
      ),
      const SizedBox(height: USpace.xl),
      UButton(
        label: 'Simpan Password Baru',
        loading: _saving,
        onPressed: _saving ? null : _savePassword,
        icon: Icons.save_rounded,
      ),
    ]);
  }
}
