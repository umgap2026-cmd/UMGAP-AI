import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';

// ── Color tokens ─────────────────────────────
const _navy    = Color(0xFF0B1733);
const _navyMid = Color(0xFF14275C);
const _blue    = Color(0xFF1565C0);
const _blueMid = Color(0xFF1E88E5);
const _cyan    = Color(0xFF29B6F6);
const _teal    = Color(0xFF00BCD4);
const _green   = Color(0xFF00C853);
const _red     = Color(0xFFE53935);
const _bg      = Color(0xFFF2F5FC);

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool          _loading = true;
  List<dynamic> _rows    = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }


  // ── Lihat profil karyawan ────────────────────
  Future<void> _showUserProfile(int userId, String name) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserProfileSheet(userId: userId, name: name),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getUsers();
      if (!mounted) return;
      setState(() { _rows = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((e) {
      final m = Map<String, dynamic>.from(e);
      return '${m['name']}'.toLowerCase().contains(q) ||
          '${m['email']}'.toLowerCase().contains(q);
    }).toList();
  }

  // ── Open add/edit dialog ───────────────────
  Future<void> _openForm({Map<String, dynamic>? item}) async {
    final nameC   = TextEditingController(text: item?['name']?.toString() ?? '');
    final emailC  = TextEditingController(text: item?['email']?.toString() ?? '');
    final passC   = TextEditingController();
    final salaryC = TextEditingController(
        text: item?['daily_salary']?.toString() ?? '0');
    String role   = item?['role']?.toString() ?? 'employee';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: _navy.withOpacity(0.18),
                    blurRadius: 30, offset: const Offset(0, 10))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Dialog header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_navy, _navyMid, _blue],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item == null ? 'Tambah User' : 'Edit User',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),

              // Fields
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _DField(ctrl: nameC,   label: 'Nama Lengkap',
                      icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _DField(ctrl: emailC,  label: 'Email',
                      icon: Icons.email_outlined,
                      type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _DField(ctrl: passC,
                      label: item == null
                          ? 'Password'
                          : 'Password Baru (kosongkan jika tidak diubah)',
                      icon: Icons.lock_outline_rounded, obscure: true),
                  const SizedBox(height: 12),
                  _DField(ctrl: salaryC, label: 'Gaji Harian (Rp)',
                      icon: Icons.payments_rounded,
                      type: TextInputType.number),
                  const SizedBox(height: 12),

                  // Role dropdown
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Role', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF4A5568))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _blue.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'employee',
                                child: Text('Employee')),
                            DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin')),
                            DropdownMenuItem(
                                value: 'owner',
                                child: Text('Owner / Pemilik')),
                          ],
                          onChanged: (v) =>
                              setLocal(() => role = v ?? 'employee'),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: _DialogBtn(
                        label: 'Batal',
                        outlined: true,
                        onTap: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogBtn(
                        label: 'Simpan',
                        onTap: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

    if (ok != true) return;

    final payload = <String, dynamic>{
      'name':         nameC.text.trim(),
      'email':        emailC.text.trim(),
      'role':         role,
      'daily_salary': int.tryParse(salaryC.text) ?? 0,
      if (item == null) 'password': passC.text,
      if (item != null && passC.text.isNotEmpty)
        'new_password': passC.text,
    };

    try {
      if (item == null) {
        await ApiService.createUser(payload);
      } else {
        await ApiService.updateUser(item['id'], payload);
      }
      await _load();
      if (mounted) {
        uSnack(context,
            item == null ? 'User berhasil ditambahkan' : 'User berhasil diupdate');
      }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus User',
            style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
        content: Text('Hapus akun ${item['name']}? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteUser(item['id']);
      await _load();
      if (mounted) uSnack(context, 'User dihapus');
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final filtered = _filtered;
    final total    = _rows.length;
    final admins   = _rows.where((e) => e['role'] == 'admin').length;
    final employees = total - admins;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────
          _buildHeader(total: total, admins: admins, employees: employees),

          // ── Search ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _SearchBar(controller: _search),
          ),

          // ── List ────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: _blue))
                : filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              color: _blue,
              onRefresh: _load,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = Map<String, dynamic>.from(filtered[i]);
                  return _UserCard(
                    item: item,
                    onEdit:   () => _openForm(item: item),
                    onDelete: () => _deleteUser(item),
                    onViewProfile: () => _showUserProfile(
                        (item['id'] as num).toInt(), item['name'] ?? '-'),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // ── FAB ─────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _blue,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Tambah User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader({required int total, required int admins,
    required int employees}) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyMid, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Kelola User',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: _load,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // Stat pills
              Row(children: [
                _StatPill(label: 'Total', value: '$total',
                    icon: Icons.people_alt_rounded, color: _cyan),
                const SizedBox(width: 10),
                _StatPill(label: 'Admin', value: '$admins',
                    icon: Icons.admin_panel_settings_rounded,
                    color: _teal),
                const SizedBox(width: 10),
                _StatPill(label: 'Karyawan', value: '$employees',
                    icon: Icons.badge_rounded, color: _green),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: _blue.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(Icons.people_outline_rounded,
              color: _blue.withOpacity(0.35), size: 36),
        ),
        const SizedBox(height: 14),
        const Text('Tidak ada user',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: _navy)),
        const SizedBox(height: 4),
        Text('Coba ubah kata pencarian',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]),
    );
  }
}

// ════════════════════════════════════════════
//  USER CARD
// ════════════════════════════════════════════
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit, onDelete, onViewProfile;
  const _UserCard(
      {required this.item, required this.onEdit,
        required this.onDelete, required this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    final isAdmin   = item['role'] == 'admin';
    final isOwner   = item['role'] == 'owner';
    final name      = '${item['name']}';
    final email     = '${item['email']}';
    final salary    = item['daily_salary'] ?? 0;
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final cardColor = isAdmin ? _navyMid : isOwner ? const Color(0xFFF57F00) : _blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Avatar — klik untuk lihat profil
          GestureDetector(
            onTap: onViewProfile,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isAdmin
                      ? [_navy, _navyMid]
                      : isOwner
                      ? [const Color(0xFFF57F00), const Color(0xFFFF9800)]
                      : [_blue, _blueMid],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(
                    color: cardColor.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: ClipOval(
                child: (item['avatar'] != null && (item['avatar'] as String).isNotEmpty)
                    ? Image.memory(base64Decode(item['avatar'] as String),
                    fit: BoxFit.cover, width: 46, height: 46)
                    : Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 18))),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700, color: _navy)),
                ),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? _navy.withOpacity(0.08)
                        : isOwner
                        ? const Color(0xFFF57F00).withOpacity(0.08)
                        : _blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isAdmin
                            ? _navy.withOpacity(0.15)
                            : isOwner
                            ? const Color(0xFFF57F00).withOpacity(0.15)
                            : _blue.withOpacity(0.15)),
                  ),
                  child: Text(
                    isAdmin ? '⚡ Admin' : isOwner ? '💼 Owner' : '👤 Employee',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: isAdmin
                            ? _navy
                            : isOwner
                            ? const Color(0xFFF57F00)
                            : _blue),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A8D))),
              const SizedBox(height: 2),
              Text('Gaji Harian: Rp $salary',
                  style: TextStyle(fontSize: 11,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500)),
            ]),
          ),

          // Actions
          Column(mainAxisSize: MainAxisSize.min, children: [
            _IconAction(
              icon: Icons.edit_rounded,
              color: _blue,
              onTap: onEdit,
            ),
            const SizedBox(height: 4),
            _IconAction(
              icon: Icons.delete_outline_rounded,
              color: _red,
              onTap: onDelete,
            ),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  SMALL COMPONENTS
// ════════════════════════════════════════════
class _StatPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: _navy,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Cari nama atau email...',
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _blue, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFFB0BEC5), size: 18),
            onPressed: () => controller.clear())
            : null,
        filled: true, fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blueMid, width: 1.5)),
      ),
    ),
  );
}

class _DField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  const _DField({required this.ctrl, required this.label,
    required this.icon, this.obscure = false, this.type});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w700, color: Color(0xFF4A5568))),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, obscureText: obscure, keyboardType: type,
        style: const TextStyle(fontSize: 13, color: _navy,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _blue, size: 16),
          filled: true, fillColor: const Color(0xFFF2F5FC),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: _blue.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: _blue.withOpacity(0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _blueMid, width: 1.5)),
        ),
      ),
    ],
  );
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;
  const _DialogBtn(
      {required this.label, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        gradient: outlined
            ? null
            : const LinearGradient(colors: [_navy, _blue],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: outlined ? null : null,
        borderRadius: BorderRadius.circular(12),
        border: outlined
            ? Border.all(color: _blue.withOpacity(0.3))
            : null,
        boxShadow: outlined
            ? []
            : [BoxShadow(color: _blue.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                color: outlined ? _blue : Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

// ════════════════════════════════════════════
//  USER PROFILE BOTTOM SHEET
// ════════════════════════════════════════════
class _UserProfileSheet extends StatefulWidget {
  final int    userId;
  final String name;
  const _UserProfileSheet({required this.userId, required this.name});
  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  bool   _loading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getUserProfile(widget.userId);
      if (mounted) setState(() { _profile = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _rpFormat(dynamic v) {
    final n = (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    if (n == 0) return 'Rp -';
    return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final name     = '${_profile['name'] ?? widget.name}';
    final email    = '${_profile['email'] ?? '-'}';
    final role     = '${_profile['role'] ?? '-'}';
    final phone    = '${_profile['phone'] ?? '-'}';
    final address  = '${_profile['address'] ?? '-'}';
    final birth    = '${_profile['birth_date'] ?? '-'}';
    final join     = '${_profile['join_date'] ?? '-'}';
    final poin     = (_profile['points'] as num?)?.toInt() ?? 0;
    final hadir    = (_profile['hadir_bulan_ini'] as num?)?.toInt() ?? 0;
    final total    = (_profile['total_hadir'] as num?)?.toInt() ?? 0;
    final daily    = (_profile['daily_salary'] as num?)?.toInt() ?? 0;
    final monthly  = (_profile['monthly_salary'] as num?)?.toInt() ?? 0;
    final avatar   = _profile['avatar'] as String?;
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final isAdmin  = role == 'admin';
    final isOwner  = role == 'owner';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
          color: Color(0xFFF2F5FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        // Handle
        Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),

        // Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: isAdmin
                      ? [const Color(0xFF0B1733), const Color(0xFF14275C)]
                      : isOwner
                      ? [const Color(0xFFE65100), const Color(0xFFF57F00)]
                      : [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Row(children: [
            // Avatar
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  color: Colors.white.withOpacity(0.1)),
              child: ClipOval(
                child: (avatar != null && avatar.isNotEmpty)
                    ? Image.memory(base64Decode(avatar),
                    fit: BoxFit.cover, width: 64, height: 64)
                    : Center(child: Text(initials,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(email, style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                _SPill(label: isAdmin ? '⚡ Admin' : isOwner ? '💼 Owner' : '👤 Karyawan'),
                const SizedBox(width: 6),
                _SPill(label: '⭐ $poin Poin'),
              ]),
            ])),
          ]),
        ),

        // Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            children: [
              // Stats row
              Row(children: [
                _StatBox(label: 'Hadir Bulan Ini', value: '$hadir hari', color: const Color(0xFF00C853)),
                const SizedBox(width: 10),
                _StatBox(label: 'Total Hadir', value: '$total hari', color: const Color(0xFF1565C0)),
                const SizedBox(width: 10),
                _StatBox(label: 'Gaji', value: monthly > 0 ? _rpFormat(monthly) : _rpFormat(daily), color: const Color(0xFFFF6D00)),
              ]),
              const SizedBox(height: 14),

              // Data pribadi
              _SCard(title: 'Data Pribadi', children: [
                _SRow(label: 'No. HP',    value: phone),
                _SRow(label: 'Tgl Lahir', value: birth),
                _SRow(label: 'Tgl Masuk', value: join),
                _SRow(label: 'Alamat',    value: address, isLast: true),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SPill extends StatelessWidget {
  final String label;
  const _SPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Text(value, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9,
                color: UColors.textLight, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: UColors.textDark)),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

class _SRow extends StatelessWidget {
  final String label, value;
  final bool isLast;
  const _SRow({required this.label, required this.value, this.isLast = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      SizedBox(width: 90, child: Text(label,
          style: const TextStyle(fontSize: 12, color: UColors.textLight,
              fontWeight: FontWeight.w500))),
      Expanded(child: Text(value.isEmpty || value == 'null' ? '-' : value,
          style: const TextStyle(fontSize: 12, color: UColors.textDark,
              fontWeight: FontWeight.w700))),
    ]),
    if (!isLast) ...[
      const SizedBox(height: 8),
      Divider(color: Colors.grey.shade100, height: 1),
      const SizedBox(height: 8),
    ],
  ]);
}