import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_my_attendance_page.dart';
import 'admin_attendance_history_page.dart';
import 'admin_submit_attendance_page.dart';

// ── Color tokens ─────────────────────────────
const _navy    = Color(0xFF0B1733);
const _navyMid = Color(0xFF14275C);
const _blue    = Color(0xFF1565C0);
const _blueMid = Color(0xFF1E88E5);
const _cyan    = Color(0xFF29B6F6);
const _teal    = Color(0xFF00BCD4);
const _green   = Color(0xFF00C853);
const _bg      = Color(0xFFF2F5FC);

class AdminAttendancePage extends StatelessWidget {
  const AdminAttendancePage({super.key});

  static const _menus = [
    _AttMenu(
      title:    'Absen Saya',
      subtitle: 'Input & lihat riwayat absensi saya sendiri',
      icon:     Icons.fingerprint_rounded,
      color:    Color(0xFF1565C0),
      tag:      'Personal',
      page:     _PageKey.mySelf,
    ),
    _AttMenu(
      title:    'Absen Karyawan',
      subtitle: 'Absenkan karyawan yang tidak punya HP',
      icon:     Icons.groups_rounded,
      color:    Color(0xFF00BCD4),
      tag:      'Tim',
      page:     _PageKey.submit,
    ),
    _AttMenu(
      title:    'Riwayat Absensi',
      subtitle: 'Lihat seluruh rekap absensi karyawan',
      icon:     Icons.history_rounded,
      color:    Color(0xFF1E88E5),
      tag:      'Laporan',
      page:     _PageKey.history,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────
          _buildHeader(context),

          // ── Menu list ───────────────────────
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: _menus.length,
              itemBuilder: (_, i) => _MenuTile(
                menu: _menus[i],
                onTap: () => _navigate(context, _menus[i].page),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
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
                  child: Text('Absensi Admin',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
              ]),

              const SizedBox(height: 22),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_cyan.withOpacity(0.3),
                          _cyan.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _cyan.withOpacity(0.25)),
                    ),
                    child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: _cyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Panel Absensi',
                            style: TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('Kelola semua absensi tim',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                  // Live dot
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _green.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: _green.withOpacity(0.5),
                              blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text('Live',
                          style: TextStyle(
                              color: _green, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, _PageKey page) {
    Widget dest;
    switch (page) {
      case _PageKey.mySelf:
        dest = const AdminMyAttendancePage();
        break;
      case _PageKey.submit:
        dest = const AdminSubmitAttendancePage();
        break;
      case _PageKey.history:
        dest = const AdminAttendanceHistoryPage();
        break;
    }
    Navigator.push(context, _slide(dest));
  }

  PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

enum _PageKey { mySelf, submit, history }

class _AttMenu {
  final String   title, subtitle, tag;
  final IconData icon;
  final Color    color;
  final _PageKey page;
  const _AttMenu({required this.title, required this.subtitle,
    required this.icon, required this.color, required this.tag,
    required this.page});
}

// ════════════════════════════════════════════
//  MENU TILE
// ════════════════════════════════════════════
class _MenuTile extends StatefulWidget {
  final _AttMenu menu;
  final VoidCallback onTap;
  const _MenuTile({required this.menu, required this.onTap});
  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80),
        reverseDuration: const Duration(milliseconds: 160));
    _s = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = widget.menu;
    return GestureDetector(
      onTapDown:  (_) => _c.forward(),
      onTapUp:    (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: m.color.withOpacity(0.08),
                  blurRadius: 16, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              // Icon box
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [m.color.withOpacity(0.15),
                      m.color.withOpacity(0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: m.color.withOpacity(0.15)),
                ),
                child: Icon(m.icon, color: m.color, size: 26),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(m.title,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w800, color: _navy)),
                    ),
                    // Tag badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: m.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: m.color.withOpacity(0.15)),
                      ),
                      child: Text(m.tag,
                          style: TextStyle(fontSize: 10,
                              color: m.color, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(m.subtitle,
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFF6B7A8D), height: 1.3,
                          fontWeight: FontWeight.w500)),
                ],
              )),

              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: m.color.withOpacity(0.4)),
            ]),
          ),
        ),
      ),
    );
  }
}