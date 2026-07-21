import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import './api_service.dart';
import 'attendance_page.dart';
import 'admin_attendance_page.dart';
import 'admin_attendance_approval_page.dart';
import 'notifications_page.dart';
import 'products_page.dart';
import 'sales_page.dart';
import 'sales_monitor_page.dart';
import 'users_page.dart';
import 'payroll_page.dart';
import 'stats_page.dart';
import 'points_page.dart';
import 'invoice_page.dart';
import 'login_page.dart';
import 'biofinger_mapping_page.dart';
import 'admin_buy_prices_page.dart';
import 'admin_hpp_ai_page.dart';
import 'u_kit.dart';
import 'notification_service.dart';
import 'profile_page.dart';
import 'payslip_page.dart';
import 'finance_kasir_page.dart';

const _cGreen = Color(0xFF00C853);
const _cOrange = Color(0xFFFF6D00);
const _cPurple = Color(0xFF7C4DFF);
const _cTeal = Color(0xFF00BCD4);
const _cAmber = Color(0xFFFFAB00);
const _cRed = Color(0xFFE53935);
const _cBlue = Color(0xFF1565C0);

class HomePage extends StatefulWidget {
  final String role;
  final String name;

  const HomePage({
    super.key,
    required this.role,
    required this.name,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, dynamic> _dashData = {};
  Map<String, dynamic> _ownerStats = {};

  int _notifCount = 0;
  bool _dashLoading = true;
  bool _ownerLoading = false;
  bool _aiLoading = false;

  String? _avatarBase64;
  Map<String, dynamic>? _todayAttendance;

  late Timer _clock;
  DateTime _now = DateTime.now();
  late AnimationController _entryCtrl;
  late StreamSubscription<RemoteMessage> _msgSub;

  bool get isAdmin => widget.role == 'admin';
  bool get isOwner => widget.role == 'owner';
  bool get isAdminOrOwner => isAdmin || isOwner;

  List<Map<String, dynamic>> get _shortcutMenus => isAdmin
      ? [
    {
      'title': 'Kasir & Keuangan',
      'icon': Icons.store_rounded,
      'color': _cGreen
    },
    {
      'title': 'Absensi',
      'icon': Icons.fingerprint_rounded,
      'color': UColors.primary
    },
    {
      'title': 'Payroll',
      'icon': Icons.payments_rounded,
      'color': _cTeal
    },
    {
      'title': 'Statistik',
      'icon': Icons.bar_chart_rounded,
      'color': _cPurple
    },
    {
      'title': 'Nota',
      'icon': Icons.receipt_long_rounded,
      'color': _cOrange
    },
    {
      'title': 'Lainnya',
      'icon': Icons.apps_rounded,
      'color': UColors.textSoft
    },
  ]
      : isOwner
      ? [
    {
      'title': 'Kasir',
      'icon': Icons.store_rounded,
      'color': _cGreen
    },
    {
      'title': 'Statistik',
      'icon': Icons.insights_rounded,
      'color': _cPurple
    },
    {
      'title': 'Harga Beli',
      'icon': Icons.price_change_rounded,
      'color': _cTeal
    },
    {
      'title': 'AI Review',
      'icon': Icons.auto_awesome_rounded,
      'color': _cAmber
    },
    {
      'title': 'Lainnya',
      'icon': Icons.apps_rounded,
      'color': UColors.textSoft
    },
  ]
      : [
    {
      'title': 'Absensi',
      'icon': Icons.fingerprint_rounded,
      'color': UColors.primary
    },
    {
      'title': 'Slip Gaji',
      'icon': Icons.payments_rounded,
      'color': _cGreen
    },
  ];

  List<Map<String, dynamic>> get _gridMenus => isAdmin
      ? [
    {
      'title': 'Kelola User',
      'icon': Icons.people_alt_rounded,
      'color': _cTeal
    },
    {
      'title': 'Pengumuman',
      'icon': Icons.campaign_rounded,
      'color': UColors.primary
    },
    {
      'title': 'Absensi',
      'icon': Icons.fingerprint_rounded,
      'color': UColors.primaryMid
    },
    {
      'title': 'Persetujuan Absensi',
      'icon': Icons.fact_check_rounded,
      'color': _cPurple
    },
    {
      'title': 'Kasir & Keuangan',
      'icon': Icons.store_rounded,
      'color': _cGreen
    },
    {
      'title': 'Payroll',
      'icon': Icons.payments_rounded,
      'color': _cGreen
    },
    {
      'title': 'Statistik',
      'icon': Icons.insights_rounded,
      'color': _cPurple
    },
    {
      'title': 'Input Poin',
      'icon': Icons.star_rounded,
      'color': _cAmber
    },
    {
      'title': 'Fingerprint',
      'icon': Icons.fingerprint_rounded,
      'color': _cGreen
    },
    {
      'title': 'Nota',
      'icon': Icons.receipt_long_rounded,
      'color': UColors.primary
    },
    {
      'title': 'Harga Beli',
      'icon': Icons.price_change_rounded,
      'color': _cTeal
    },
    {
      'title': 'HPP AI',
      'icon': Icons.auto_graph_rounded,
      'color': _cPurple
    },
  ]
      : isOwner
      ? [
    {
      'title': 'Kasir & Keuangan',
      'icon': Icons.store_rounded,
      'color': _cGreen
    },
    {
      'title': 'Statistik',
      'icon': Icons.insights_rounded,
      'color': _cPurple
    },
    {
      'title': 'Nota',
      'icon': Icons.receipt_long_rounded,
      'color': _cOrange
    },
    {
      'title': 'Harga Beli',
      'icon': Icons.price_change_rounded,
      'color': _cTeal
    },
    {
      'title': 'HPP AI',
      'icon': Icons.auto_graph_rounded,
      'color': _cPurple
    },
    {
      'title': 'AI Review',
      'icon': Icons.auto_awesome_rounded,
      'color': _cAmber
    },
    {
      'title': 'Profil',
      'icon': Icons.person_rounded,
      'color': UColors.navyMid
    },
  ]
      : [
    {
      'title': 'Absensi',
      'icon': Icons.fingerprint_rounded,
      'color': UColors.primary
    },
    {
      'title': 'Slip Gaji',
      'icon': Icons.payments_rounded,
      'color': _cGreen
    },
    {
      'title': 'Profil',
      'icon': Icons.person_rounded,
      'color': UColors.navyMid
    },
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _loadDashboard();
    _loadOwnerStats();
    _loadAvatar();
    _loadTodayAttendance();

    _msgSub = NotificationService.onMessageStream.listen((_) {
      if (mounted) {
        _loadDashboard();
        _loadOwnerStats();
        _loadTodayAttendance();
      }
    });

    Future.microtask(() async {
      try {
        await NotificationService.init();
        await NotificationService.setupFCM();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.cancel();
    _entryCtrl.dispose();
    _msgSub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadDashboard();
      _loadOwnerStats();
      _loadAvatar();
      _loadTodayAttendance();
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final p = await ApiService.getMyProfile();
      final a = p['avatar'] as String?;
      if (mounted && a != null && a.isNotEmpty) {
        setState(() => _avatarBase64 = a);
      }
    } catch (_) {}
  }

  Future<void> _loadTodayAttendance() async {
    if (isAdmin || isOwner) return;

    try {
      final history = await ApiService.getAttendanceHistory();
      if (!mounted) return;

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      Map<String, dynamic>? found;

      for (final item in history) {
        final m = item as Map<String, dynamic>;
        if ((m['work_date'] ?? '').toString().startsWith(todayStr)) {
          found = m;
          break;
        }
      }

      setState(() => _todayAttendance = found);
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    try {
      final futures = await Future.wait([
        ApiService.getDashboard().catchError((_) => <String, dynamic>{}),
        ApiService.getNotifications().catchError((_) => <dynamic>[]),
      ]);

      if (!mounted) return;

      final r = futures[0] as Map<String, dynamic>;
      final nl = futures[1] as List<dynamic>;
      final unread = nl.where((i) => (i as Map)['is_read'] == false).length;

      setState(() {
        _dashData = r;
        _notifCount = unread;
        _dashLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _dashLoading = false);
    }
  }

  Future<void> _loadOwnerStats() async {
    if (!isOwner) return;

    setState(() => _ownerLoading = true);

    try {
      final data = await ApiService.getOwnerInsight();

      if (!mounted) return;

      setState(() {
        _ownerStats = data;
        _ownerLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _ownerLoading = false);
    }
  }

  Future<void> _openAiReview() async {
    if (!isOwner) return;

    setState(() => _aiLoading = true);

    try {
      final result = await ApiService.getOwnerAiReview({
        'salary': _num(_ownerStats['salary_total']),
        'stock': _num(_ownerStats['stock_value']),
        'revenue': _num(_ownerStats['revenue']),
        'profit': _num(_ownerStats['profit']),
        'debt': _num(_ownerStats['debt_total']),
        'receivable': _num(_ownerStats['receivable_total']),
        'quality_score': _num(_ownerStats['quality_score']),
        'health_score': _num(_ownerStats['health_score']),
      });

      if (!mounted) return;

      final analysis = (result['analysis'] ?? result['review'] ?? '').toString();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AiReviewSheet(
          analysis: analysis.isEmpty
              ? 'AI belum memberikan hasil analisa.'
              : analysis,
        ),
      );
    } catch (e) {
      if (mounted) {
        uSnack(context, 'Gagal memuat AI Review: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _go(String title) {
    if (title == 'AI Review') {
      _openAiReview();
      return;
    }

    final routes = <String, Widget>{
      'Pengumuman': const NotificationsPage(),
      'Absensi': isAdmin || isOwner
          ? const AdminAttendancePage()
          : const AttendancePage(),
      'Persetujuan Absensi': const AdminAttendanceApprovalPage(),
      'Kelola User': const UsersPage(),
      'Produk Global': const ProductsPage(),
      'Penjualan': const SalesPage(),
      'Monitor Sales': const SalesMonitorPage(),
      'Payroll': const PayrollPage(),
      'Statistik': const StatsPage(),
      'Input Poin': const PointsPage(),
      'Nota': const InvoicePage(),
      'Fingerprint': const BiofingerMappingPage(),
      'Harga Beli': const AdminBuyPricesPage(),
      'HPP AI': const AdminHppAiPage(),
      'Profil': const ProfilePage(),
      'Slip Gaji': const PayslipPage(),
      'Kasir & Keuangan': const FinanceKasirPage(),
      'Kasir': const FinanceKasirPage(),
    };

    if (title == 'Lainnya') {
      _showAllMenus();
      return;
    }

    final page = routes[title];

    if (page == null) {
      uSnack(context, '$title belum tersedia');
      return;
    }

    if (title == 'Pengumuman') {
      Navigator.push(context, uRoute(page)).then((_) => _loadDashboard());
    } else if (title == 'Profil') {
      Navigator.push(context, uRoute(page)).then((_) => _loadAvatar());
    } else if (title == 'Absensi' && !isAdmin && !isOwner) {
      Navigator.push(context, uRoute(page)).then((_) => _loadTodayAttendance());
    } else {
      Navigator.push(context, uRoute(page)).then((_) {
        _loadDashboard();
        _loadOwnerStats();
      });
    }
  }

  void _openNotif() {
    Navigator.push(context, uRoute(const NotificationsPage()))
        .then((_) => _loadDashboard());
  }

  void _logout() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(URadius.lg),
      ),
      title: Text('Keluar', style: UText.h4),
      content: Text('Yakin ingin keluar dari UMGAP?', style: UText.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: UColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(URadius.sm),
            ),
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.logout();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              uRoute(const LoginPage()),
                  (_) => false,
            );
          },
          child: const Text(
            'Keluar',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  void _showAllMenus() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllMenusSheet(
      menus: _gridMenus,
      onTap: (t) {
        Navigator.pop(context);
        _go(t);
      },
    ),
  );

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _rp(dynamic v) {
    final n = _num(v).round();
    if (n <= 0) return 'Rp 0';
    return 'Rp ${n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    )}';
  }

  String _compactRp(dynamic v) {
    final n = _num(v);
    if (n >= 1000000000) {
      return 'Rp ${(n / 1000000000).toStringAsFixed(1)} M';
    }
    if (n >= 1000000) {
      return 'Rp ${(n / 1000000).toStringAsFixed(1)} Jt';
    }
    if (n >= 1000) {
      return 'Rp ${(n / 1000).toStringAsFixed(0)} Rb';
    }
    return _rp(n);
  }

  String get _initials => uInitials(widget.name);

  String get _greeting {
    final h = _now.hour;
    if (h < 11) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _timeStr =>
      '${_pad(_now.hour)}:${_pad(_now.minute)}:${_pad(_now.second)}';

  String get _dateStr {
    const d = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const m = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${d[_now.weekday]}, ${_now.day} ${m[_now.month]} ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final summary = Map<String, dynamic>.from(_dashData['summary'] ?? {});
    final poin = _dashData['points_admin'] ?? 0;
    final alreadyAbsen = _todayAttendance != null;

    final absenTime = () {
      if (_todayAttendance == null) return '';
      final raw = (_todayAttendance!['checkin_at'] ??
          _todayAttendance!['created_at'] ??
          '') as String;
      try {
        final dt = DateTime.parse(raw).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return raw.length >= 5 ? raw.substring(0, 5) : raw;
      }
    }();

    return Scaffold(
      backgroundColor: UColors.surface,
      body: RefreshIndicator(
        color: UColors.primary,
        onRefresh: () async {
          await _loadDashboard();
          await _loadOwnerStats();
          await _loadAvatar();
          await _loadTodayAttendance();
        },
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                USpace.base,
                USpace.base,
                USpace.base,
                0,
              ),
              child: isOwner
                  ? _OwnerBusinessCard(
                stats: _ownerStats,
                loading: _ownerLoading,
                aiLoading: _aiLoading,
                dateLabel: _dateStr,
                formatRp: _compactRp,
                onRefresh: _loadOwnerStats,
                onAiReview: _openAiReview,
              )
                  : isAdmin
                  ? _AdminOverviewCard(
                summary: summary,
                timeStr: _timeStr,
              )
                  : _UserOverviewCard(
                poin: poin,
                timeStr: _timeStr,
                alreadyAbsen: alreadyAbsen,
                absenTime: absenTime,
                onAbsen: () => Navigator.push(
                  context,
                  uRoute(const AttendancePage()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                USpace.base,
                USpace.lg,
                0,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      right: USpace.base,
                      bottom: USpace.md,
                    ),
                    child: Text(
                      'Akses Cepat',
                      style: UText.label.copyWith(
                        color: UColors.textMid,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _shortcutMenus.length,
                      itemBuilder: (_, i) {
                        final m = _shortcutMenus[i];
                        final color = m['color'] as Color;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _go(m['title'] as String);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: USpace.sm),
                            padding: const EdgeInsets.symmetric(
                              horizontal: USpace.base,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(URadius.sm),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  m['icon'] as IconData,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m['title'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                USpace.base,
                USpace.xl,
                USpace.base,
                USpace.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Menu Utama', style: UText.h4),
                  if (isAdmin || isOwner)
                    GestureDetector(
                      onTap: _showAllMenus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: USpace.md,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: UColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(URadius.full),
                        ),
                        child: Text(
                          'Lihat Semua',
                          style: UText.caption.copyWith(
                            color: UColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                USpace.base,
                0,
                USpace.base,
                40,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: isAdmin || isOwner
                    ? (_gridMenus.length > 8 ? 8 : _gridMenus.length)
                    : _gridMenus.length,
                itemBuilder: (_, i) => _GridMenuCard(
                  title: _gridMenus[i]['title'] as String,
                  icon: _gridMenus[i]['icon'] as IconData,
                  color: _gridMenus[i]['color'] as Color,
                  onTap: () => _go(_gridMenus[i]['title'] as String),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return UHeader(
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: 20,
            child: _Orb(130, Colors.white.withOpacity(0.04)),
          ),
          Positioned(
            bottom: 20,
            left: -20,
            child: _Orb(90, Colors.white.withOpacity(0.04)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              USpace.lg,
              USpace.base,
              USpace.lg,
              USpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, uRoute(const ProfilePage()))
                            .then((_) => _loadAvatar());
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [UColors.cyan, UColors.primaryMid],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: UShadow.md(UColors.cyan),
                        ),
                        child: ClipOval(
                          child: _avatarBase64 != null &&
                              _avatarBase64!.isNotEmpty
                              ? Image.memory(
                            base64Decode(_avatarBase64!),
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            gaplessPlayback: true,
                          )
                              : Center(
                            child: Text(
                              _initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: USpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _greeting,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    UHeaderIconBtn(
                      icon: Icons.notifications_outlined,
                      badge: _notifCount > 0 ? '$_notifCount' : null,
                      onTap: _openNotif,
                    ),
                    const SizedBox(width: USpace.sm),
                    UHeaderIconBtn(
                      icon: Icons.logout_rounded,
                      onTap: _logout,
                    ),
                  ],
                ),
                const SizedBox(height: USpace.base),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      UGlassPill(
                        icon: Icons.calendar_today_rounded,
                        label: _dateStr,
                      ),
                      const SizedBox(width: USpace.sm),
                      UGlassPill(
                        icon: isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : isOwner
                            ? Icons.business_center_rounded
                            : Icons.badge_rounded,
                        label: isAdmin
                            ? 'Administrator'
                            : isOwner
                            ? 'Pemilik'
                            : 'Karyawan',
                        accentColor:
                        isAdmin ? UColors.cyan : isOwner ? _cAmber : _cGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerBusinessCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool loading;
  final bool aiLoading;
  final String dateLabel;
  final String Function(dynamic) formatRp;
  final VoidCallback onRefresh;
  final VoidCallback onAiReview;

  const _OwnerBusinessCard({
    required this.stats,
    required this.loading,
    required this.aiLoading,
    required this.dateLabel,
    required this.formatRp,
    required this.onRefresh,
    required this.onAiReview,
  });

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _score(dynamic v) {
    final n = _num(v).round();
    if (n <= 0) return '-';
    return '$n/100';
  }

  @override
  Widget build(BuildContext context) {
    final revenue = stats['revenue'] ?? stats['total_revenue'] ?? 0;
    final profit = stats['profit'] ?? stats['profit_estimation'] ?? 0;
    final salary = stats['salary_total'] ?? stats['total_salary'] ?? 0;
    final stock = stats['stock_value'] ?? stats['total_stock'] ?? 0;
    final debt = stats['debt_total'] ?? stats['total_debt'] ?? 0;
    final receivable =
        stats['receivable_total'] ?? stats['total_receivable'] ?? 0;
    final health = stats['health_score'] ?? stats['company_score'] ?? 0;
    final quality = stats['quality_score'] ?? stats['attendance_quality'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UColors.navy, Color(0xFF102C63), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: [
          BoxShadow(
            color: UColors.navy.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -24,
            child: _Orb(130, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -35,
            left: 30,
            child: _Orb(95, Colors.white.withOpacity(0.035)),
          ),
          Padding(
            padding: const EdgeInsets.all(USpace.lg),
            child: loading
                ? const SizedBox(
              height: 190,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Owner Business Control',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Kesehatan Perusahaan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _cAmber.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(URadius.md),
                        border: Border.all(
                          color: _cAmber.withOpacity(0.26),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.health_and_safety_rounded,
                            color: _cAmber,
                            size: 20,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _score(health),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: USpace.base),
                Row(
                  children: [
                    Expanded(
                      child: _OwnerMainMetric(
                        title: 'Omzet',
                        value: formatRp(revenue),
                        icon: Icons.trending_up_rounded,
                        color: _cGreen,
                      ),
                    ),
                    const SizedBox(width: USpace.sm),
                    Expanded(
                      child: _OwnerMainMetric(
                        title: 'Profit Est.',
                        value: formatRp(profit),
                        icon: Icons.account_balance_wallet_rounded,
                        color: _cAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: USpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _OwnerMiniMetric(
                        title: 'Gaji',
                        value: formatRp(salary),
                        icon: Icons.payments_rounded,
                        color: _cRed,
                      ),
                    ),
                    const SizedBox(width: USpace.sm),
                    Expanded(
                      child: _OwnerMiniMetric(
                        title: 'Stok',
                        value: formatRp(stock),
                        icon: Icons.inventory_2_rounded,
                        color: _cTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: USpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _OwnerMiniMetric(
                        title: 'Hutang',
                        value: formatRp(debt),
                        icon: Icons.outbound_rounded,
                        color: _cOrange,
                      ),
                    ),
                    const SizedBox(width: USpace.sm),
                    Expanded(
                      child: _OwnerMiniMetric(
                        title: 'Piutang',
                        value: formatRp(receivable),
                        icon: Icons.call_received_rounded,
                        color: _cBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: USpace.base),
                Container(
                  padding: const EdgeInsets.all(USpace.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(URadius.md),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _cPurple.withOpacity(0.18),
                          borderRadius:
                          BorderRadius.circular(URadius.sm),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: _cPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: USpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kualitas Operasional',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Skor absensi & kualitas kerja: ${_score(quality)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.48),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: USpace.base),
                GestureDetector(
                  onTap: aiLoading ? null : onAiReview,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cAmber, _cOrange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(URadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: _cAmber.withOpacity(0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: aiLoading
                          ? const _AiLoadingButton()
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                          SizedBox(width: 9),
                          Text(
                            'Review Perusahaan dengan AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerMainMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OwnerMainMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(USpace.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(URadius.md),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.48),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerMiniMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OwnerMiniMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(USpace.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(URadius.sm),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(URadius.sm),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.44),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReviewSheet extends StatelessWidget {
  final String analysis;

  const _AiReviewSheet({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: UColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(URadius.x2l),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: USpace.md, bottom: USpace.sm),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: UColors.textSoft.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              USpace.lg,
              USpace.sm,
              USpace.lg,
              USpace.base,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_cAmber, _cOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(URadius.md),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: USpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Review Perusahaan', style: UText.h4),
                      const SizedBox(height: 2),
                      Text(
                        'Analisa otomatis berdasarkan data owner',
                        style: UText.caption.copyWith(
                          color: UColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                USpace.lg,
                0,
                USpace.lg,
                40,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(USpace.lg),
                decoration: BoxDecoration(
                  color: UColors.card,
                  borderRadius: BorderRadius.circular(URadius.lg),
                  boxShadow: UShadow.card,
                ),
                child: Text(
                  analysis,
                  style: UText.body.copyWith(
                    height: 1.55,
                    color: UColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingButton extends StatefulWidget {
  const _AiLoadingButton();

  @override
  State<_AiLoadingButton> createState() => _AiLoadingButtonState();
}

class _AiLoadingButtonState extends State<_AiLoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;

  int _seconds = 0;

  String get _label {
    if (_seconds < 3) return 'Mengumpulkan data...';
    if (_seconds < 6) return 'Menganalisa keuangan...';
    if (_seconds < 9) return 'Menyusun insight AI...';
    return 'Hampir selesai...';
  }

  int get _progress {
    if (_seconds >= 12) return 95;
    return ((_seconds / 12) * 95).round();
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            '$_label $_progress%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminOverviewCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String timeStr;

  const _AdminOverviewCard({
    required this.summary,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: UShadow.md(UColors.primary),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              USpace.lg,
              USpace.base,
              USpace.lg,
              USpace.base,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UColors.navy, UColors.navyMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(URadius.xl),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Overview",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _cGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(URadius.sm),
                    border: Border.all(color: _cGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _cGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _cGreen.withOpacity(0.5),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: _cGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(USpace.base),
            child: Row(
              children: [
                _StatTile(
                  icon: Icons.people_alt_rounded,
                  value: '${summary['total_employees'] ?? 0}',
                  label: 'Karyawan',
                  color: UColors.primary,
                ),
                _VSep(),
                _StatTile(
                  icon: Icons.fingerprint_rounded,
                  value: '${summary['total_attendance_today'] ?? 0}',
                  label: 'Hadir',
                  color: UColors.success,
                ),
                _VSep(),
                _StatTile(
                  icon: Icons.pending_actions_rounded,
                  value: '${summary['total_pending'] ?? 0}',
                  label: 'Pending',
                  color: UColors.warning,
                ),
                _VSep(),
                _StatTile(
                  icon: Icons.inventory_2_rounded,
                  value: '${summary['total_products'] ?? 0}',
                  label: 'Produk',
                  color: _cPurple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserOverviewCard extends StatefulWidget {
  final int poin;
  final String timeStr;
  final VoidCallback onAbsen;
  final bool alreadyAbsen;
  final String absenTime;

  const _UserOverviewCard({
    required this.poin,
    required this.timeStr,
    required this.onAbsen,
    required this.alreadyAbsen,
    required this.absenTime,
  });

  @override
  State<_UserOverviewCard> createState() => _UserOverviewCardState();
}

class _UserOverviewCardState extends State<_UserOverviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UColors.navy, UColors.navyMid, Color(0xFF1A3A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: [
          BoxShadow(
            color: UColors.navy.withOpacity(0.32),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: UColors.cyan.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -25,
            right: -10,
            child: _Orb(100, Colors.white.withOpacity(0.04)),
          ),
          Positioned(
            bottom: -25,
            left: 50,
            child: _Orb(70, Colors.white.withOpacity(0.03)),
          ),
          Padding(
            padding: const EdgeInsets.all(USpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.alreadyAbsen
                                ? 'Jam Masuk'
                                : 'Clock In Time',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.timeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(URadius.md),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.13),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: _cAmber,
                            size: 22,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.poin}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const Text(
                            'Poin',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: USpace.base),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: USpace.base),
                if (widget.alreadyAbsen) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: USpace.base,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: UColors.success.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(URadius.md),
                      border: Border.all(
                        color: UColors.success.withOpacity(0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: UColors.success.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: UColors.success,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: USpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sudah Absen Hari Ini',
                                style: TextStyle(
                                  color: UColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (widget.absenTime.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Tercatat masuk pukul ${widget.absenTime}',
                                  style: TextStyle(
                                    color:
                                    UColors.success.withOpacity(0.70),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: UColors.success,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: USpace.sm),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onAbsen();
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(URadius.sm),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.13),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Lihat Riwayat Absensi',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) =>
                        Transform.scale(scale: _pulse.value, child: child),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onAbsen();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [UColors.cyan, UColors.primaryMid],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(URadius.md),
                          boxShadow: UShadow.lg(UColors.cyan),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Absen Sekarang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: USpace.sm),
                  Center(
                    child: Text(
                      'Belum absen hari ini — tap untuk mulai',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.30),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridMenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GridMenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_GridMenuCard> createState() => _GridMenuCardState();
}

class _GridMenuCardState extends State<_GridMenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _s = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          decoration: BoxDecoration(
            color: UColors.card,
            borderRadius: BorderRadius.circular(URadius.md),
            boxShadow: UShadow.card,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(URadius.sm),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: USpace.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: UText.caption.copyWith(
                    color: UColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllMenusSheet extends StatelessWidget {
  final List<Map<String, dynamic>> menus;
  final void Function(String) onTap;

  const _AllMenusSheet({
    required this.menus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: UColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(URadius.x2l),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: USpace.md,
              bottom: USpace.sm,
            ),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: UColors.textSoft.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              USpace.lg,
              USpace.sm,
              USpace.lg,
              USpace.base,
            ),
            child: Row(
              children: [
                Text('Semua Menu', style: UText.h3),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                USpace.base,
                0,
                USpace.base,
                40,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: menus.length,
              itemBuilder: (_, i) => _GridMenuCard(
                title: menus[i]['title'] as String,
                icon: menus[i]['icon'] as IconData,
                color: menus[i]['color'] as Color,
                onTap: () => onTap(menus[i]['title'] as String),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(URadius.sm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: UText.caption.copyWith(height: 1.3),
        ),
      ],
    ),
  );
}

class _VSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: UColors.divider);
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
    ),
  );
}