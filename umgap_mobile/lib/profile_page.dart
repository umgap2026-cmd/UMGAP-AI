import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  final _picker  = ImagePicker();

  bool   _loading  = true;
  bool   _saving   = false;
  bool   _editMode = false;
  Map<String, dynamic> _profile = {};

  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _birthDate;
  String? _joinDate;
  String? _avatarBase64;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await CacheService.get(CacheService.kProfile);
    if (cached != null && mounted) {
      setState(() {
        _profile          = cached;
        _phoneCtrl.text   = cached['phone']   ?? '';
        _addressCtrl.text = cached['address'] ?? '';
        _birthDate        = cached['birth_date'];
        _joinDate         = cached['join_date'];
        _avatarBase64     = cached['avatar'];
        _loading          = false;
      });
    }
    try {
      final res = await ApiService.getMyProfile();
      if (!mounted) return;
      await CacheService.set(CacheService.kProfile, res);
      setState(() {
        _profile          = res;
        _phoneCtrl.text   = res['phone']   ?? '';
        _addressCtrl.text = res['address'] ?? '';
        _birthDate        = res['birth_date'];
        _joinDate         = res['join_date'];
        _avatarBase64     = res['avatar'];
        _loading          = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_profile.isEmpty) uSnack(context, 'Gagal memuat profil', isError: true);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 70);
    if (file == null || !mounted) return;

    final bytes = await File(file.path).readAsBytes();
    setState(() => _avatarBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      HapticFeedback.mediumImpact();
      await ApiService.updateMyProfile({
        'phone':      _phoneCtrl.text.trim(),
        'address':    _addressCtrl.text.trim(),
        'birth_date': _birthDate,
        'join_date':  _joinDate,
        'avatar':     _avatarBase64,
      });
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() { _editMode = false; _saving = false; });
        uSnack(context, 'Profil berhasil disimpan ✓');
        _load();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        setState(() => _saving = false);
        uSnack(context, 'Gagal menyimpan: $e', isError: true);
      }
    }
  }

  Future<void> _pickDate(bool isBirth) async {
    final now = DateTime.now();
    final initial = isBirth
        ? (_birthDate != null ? DateTime.tryParse(_birthDate!) ?? DateTime(1990) : DateTime(1990))
        : (_joinDate  != null ? DateTime.tryParse(_joinDate!)  ?? now : now);
    final picked = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   DateTime(1950),
      lastDate:    DateTime(2100),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: UColors.primary)),
          child: child!),
    );
    if (picked == null || !mounted) return;
    final str = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
    setState(() => isBirth ? _birthDate = str : _joinDate = str);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    if (_loading) {
      return const Scaffold(
        backgroundColor: UColors.surface,
        body: Center(child: CircularProgressIndicator(color: UColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: UColors.surface,
      body: RefreshIndicator(
        color:     UColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.base, USpace.base, USpace.x3l),
              sliver: SliverList(delegate: SliverChildListDelegate([
                _buildInfoCard(),
                const SizedBox(height: USpace.md),
                _buildPersonalCard(),
                const SizedBox(height: USpace.md),
                _buildSalaryCard(),
                const SizedBox(height: USpace.md),
                _buildReminderCard(),
                if (_editMode) ...[
                  const SizedBox(height: USpace.base),
                  UButton(label: 'Simpan Perubahan', onPressed: _saving ? null : _save,
                      loading: _saving, icon: Icons.check_rounded),
                  const SizedBox(height: USpace.sm),
                  UButton(
                    label:    'Batal',
                    onPressed: () { HapticFeedback.lightImpact(); setState(() => _editMode = false); },
                    outlined: true,
                    color:    UColors.textSoft,
                  ),
                ],
              ])),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────
  Widget _buildHeader() {
    final name  = '${_profile['name'] ?? '-'}';
    final email = '${_profile['email'] ?? '-'}';
    final role  = '${_profile['role'] ?? '-'}';
    final poin  = (_profile['points_admin'] as num?)?.toInt() ?? 0;

    return UHeader(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.sm, USpace.base, USpace.x2l),
        child: Column(children: [
          // Top bar
          Row(children: [
            UBackButton(),
            const Spacer(),
            // Edit toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _editMode = !_editMode);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(URadius.full),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _editMode ? Icons.close_rounded : Icons.edit_rounded,
                    color: Colors.white, size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(_editMode ? 'Batal' : 'Edit',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),

          const SizedBox(height: USpace.xl),

          // Avatar
          GestureDetector(
            onTap: _editMode ? _pickImage : null,
            child: Stack(children: [
              // Avatar circle
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [UColors.cyan, UColors.primaryMid],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.30), width: 3),
                  boxShadow: UShadow.lg(UColors.cyan),
                ),
                child: ClipOval(
                  child: _avatarBase64 != null && _avatarBase64!.isNotEmpty
                      ? Image.memory(base64Decode(_avatarBase64!),
                      fit: BoxFit.cover, gaplessPlayback: true)
                      : Center(child: Text(uInitials(name),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.w900))),
                ),
              ),
              // Camera badge — only in edit mode
              if (_editMode)
                Positioned(bottom: 0, right: 0,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: UColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: USpace.md),

          // Name
          Text(name, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(email, style: TextStyle(
              color: Colors.white.withOpacity(0.55), fontSize: 12,
              fontWeight: FontWeight.w500)),

          const SizedBox(height: USpace.md),

          // Role + Poin pills
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            UGlassPill(
              icon: role == 'admin'
                  ? Icons.admin_panel_settings_rounded
                  : role == 'owner'
                  ? Icons.business_center_rounded
                  : Icons.badge_rounded,
              label: role == 'admin'
                  ? 'Administrator'
                  : role == 'owner'
                  ? 'Pemilik'
                  : 'Karyawan',
              accentColor: role == 'admin'
                  ? UColors.cyan
                  : role == 'owner'
                  ? const Color(0xFFFFA000)
                  : UColors.primaryLight,
            ),
            const SizedBox(width: USpace.sm),
            UGlassPill(
              icon: Icons.star_rounded,
              label: '$poin Poin',
              accentColor: const Color(0xFFFFD54F),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Info Card ───────────────────────────────
  Widget _buildInfoCard() {
    return USectionCard(
      title:    'Informasi Akun',
      icon:     Icons.person_rounded,
      iconColor: UColors.primary,
      child: Column(children: [
        UInfoRow(label: 'Nama', value: '${_profile['name'] ?? '-'}'),
        UInfoRow(label: 'Email', value: '${_profile['email'] ?? '-'}'),
        UInfoRow(label: 'Role',
            value: '${_profile['role'] ?? '-'}', showDivider: false),
      ]),
    );
  }

  // ── Personal Card ───────────────────────────
  Widget _buildPersonalCard() {
    return USectionCard(
      title:     'Data Pribadi',
      icon:      Icons.contact_page_rounded,
      iconColor: UColors.info,
      trailing:  _editMode ? null : null,
      child: Column(children: [
        // Phone
        _editMode
            ? _buildEditField('No. HP', _phoneCtrl,
            Icons.phone_rounded, TextInputType.phone)
            : UInfoRow(label: 'No. HP',
            value: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : '-'),

        // Address
        _editMode
            ? _buildEditField('Alamat', _addressCtrl,
            Icons.home_rounded, TextInputType.streetAddress, maxLines: 2)
            : UInfoRow(label: 'Alamat',
            value: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : '-'),

        // Birth date
        _editMode
            ? _DatePicker(
          label:    'Tgl Lahir',
          icon:     Icons.cake_rounded,
          value:    _birthDate,
          hint:     'Pilih tanggal lahir',
          onTap:    () => _pickDate(true),
        )
            : UInfoRow(label: 'Tgl Lahir', value: _birthDate ?? '-'),

        // Join date
        _editMode
            ? _DatePicker(
          label:    'Tgl Masuk',
          icon:     Icons.work_rounded,
          value:    _joinDate,
          hint:     'Pilih tanggal bergabung',
          onTap:    () => _pickDate(false),
        )
            : UInfoRow(label: 'Tgl Masuk',
            value: _joinDate ?? '-', showDivider: false),
      ]),
    );
  }

  // ── Salary Card ─────────────────────────────
  Widget _buildSalaryCard() {
    final daily   = (_profile['daily_salary']   as num?)?.toInt() ?? 0;
    final monthly = (_profile['monthly_salary'] as num?)?.toInt() ?? 0;

    return USectionCard(
      title:     'Informasi Gaji',
      icon:      Icons.account_balance_wallet_rounded,
      iconColor: UColors.success,
      child: Column(children: [
        UInfoRow(label: 'Tipe Gaji',
            value: monthly > 0 ? 'Bulanan' : 'Harian'),
        if (daily > 0)
          UInfoRow(label: 'Gaji Harian', value: uRupiah(daily)),
        if (monthly > 0)
          UInfoRow(label: 'Gaji Bulanan', value: uRupiah(monthly), showDivider: false),
        if (daily == 0 && monthly == 0)
          UInfoRow(label: 'Gaji', value: 'Belum diset oleh admin',
              showDivider: false),
      ]),
    );
  }

  // ── Reminder Card ───────────────────────────
  Widget _buildReminderCard() {
    return USectionCard(
      title:     'Pengingat Absen',
      icon:      Icons.alarm_rounded,
      iconColor: UColors.warning,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: UColors.successLight,
            borderRadius: BorderRadius.circular(URadius.sm),
          ),
          child: const Icon(Icons.notifications_active_rounded,
              color: UColors.success, size: 18),
        ),
        const SizedBox(width: USpace.md),
        const Expanded(child: Text(
          'Pengingat absen otomatis dikirim setiap pagi jam 06:00 WIB via notifikasi.',
          style: UText.bodyS,
        )),
      ]),
    );
  }

  // ── Edit field helper ────────────────────────
  Widget _buildEditField(String label, TextEditingController ctrl,
      IconData icon, TextInputType keyboard, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: USpace.sm),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: UColors.textDark,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText:    label,
          labelStyle:   UText.caption.copyWith(color: UColors.textSoft),
          prefixIcon:   Icon(icon, size: 18, color: UColors.primary),
          filled:       true,
          fillColor:    UColors.inputBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: USpace.base, vertical: USpace.md),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: const BorderSide(
                  color: UColors.primaryMid, width: 1.5)),
        ),
      ),
    );
  }
}

// ─── Date Picker Row ─────────────────────────
class _DatePicker extends StatelessWidget {
  final String label, hint;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: USpace.base, vertical: USpace.md),
      decoration: BoxDecoration(
        color:        UColors.inputBg,
        borderRadius: BorderRadius.circular(URadius.md),
        border:       Border.all(color: UColors.primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: UColors.primary, size: 18),
        const SizedBox(width: USpace.sm),
        Expanded(child: Text(value ?? hint,
            style: TextStyle(
              fontSize: 13,
              color: value != null ? UColors.textDark : UColors.textLight,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
            ))),
        const Icon(Icons.keyboard_arrow_down_rounded,
            color: UColors.textSoft, size: 18),
      ]),
    ),
  );
}

// ─── Image Source Bottom Sheet ───────────────
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(URadius.xl)),
    ),
    padding: const EdgeInsets.fromLTRB(
        USpace.lg, USpace.sm, USpace.lg, USpace.x2l),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle bar
      Container(width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: USpace.base),
          decoration: BoxDecoration(
              color: UColors.divider,
              borderRadius: BorderRadius.circular(2))),

      Text('Ganti Foto Profil', style: UText.h5),
      const SizedBox(height: USpace.base),

      _SourceTile(
        icon:  Icons.camera_alt_rounded,
        label: 'Ambil dari Kamera',
        onTap: () => Navigator.pop(context, ImageSource.camera),
      ),
      const SizedBox(height: USpace.sm),
      _SourceTile(
        icon:  Icons.photo_library_rounded,
        label: 'Pilih dari Galeri',
        onTap: () => Navigator.pop(context, ImageSource.gallery),
      ),
    ]),
  );
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(
        color: UColors.surface,
        borderRadius: BorderRadius.circular(URadius.md),
        border: Border.all(color: UColors.divider),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: UColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(URadius.xs)),
          child: Icon(icon, color: UColors.primary, size: 18),
        ),
        const SizedBox(width: USpace.md),
        Text(label, style: UText.body.copyWith(
            color: UColors.textDark, fontWeight: FontWeight.w600)),
        const Spacer(),
        const Icon(Icons.arrow_forward_ios_rounded,
            color: UColors.textSoft, size: 13),
      ]),
    ),
  );
}