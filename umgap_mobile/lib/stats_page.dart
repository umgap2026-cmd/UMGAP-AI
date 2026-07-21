import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ════════════════════════════════════════════
//  STATS PAGE — Professional Edition
// ════════════════════════════════════════════
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {

  // ── State ─────────────────────────────────
  bool   _loading    = true;
  bool   _exporting  = false;
  Map<String, dynamic> _data = {};
  String _mode   = 'month';       // 'month' | 'range'
  String _month  = _currentMonth();
  DateTime? _dateFrom, _dateTo;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static String _currentMonth() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4,'0')}-${n.month.toString().padLeft(2,'0')}';
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  // ── Load ──────────────────────────────────
  Future<void> _load() async {
    final cKey = CacheService.kStats(_mode == 'range'
        ? '${_dateFrom}_${_dateTo}' : _month);
    final cached = await CacheService.get(cKey);
    if (cached != null && mounted) setState(() { _data = cached; _loading = false; });
    else setState(() => _loading = true);
    _fadeCtrl.reset();
    try {
      Map<String, dynamic> result;
      if (_mode == 'range' && _dateFrom != null && _dateTo != null) {
        result = await ApiService.getStats(
          dateFrom: _fmtDate(_dateFrom!),
          dateTo:   _fmtDate(_dateTo!),
        );
      } else {
        result = await ApiService.getStats(month: _month);
      }
      if (!mounted) return;
      await CacheService.set(cKey, result);
      setState(() { _data = result; _loading = false; });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-'
          '${d.month.toString().padLeft(2,'0')}-'
          '${d.day.toString().padLeft(2,'0')}';

  // ── Export Excel ─────────────────────────
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ApiService.downloadStatsExcel(
        month:    _mode == 'month' ? _month : null,
        dateFrom: _mode == 'range' && _dateFrom != null ? _fmtDate(_dateFrom!) : null,
        dateTo:   _mode == 'range' && _dateTo   != null ? _fmtDate(_dateTo!)   : null,
      );
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/UMGAP_Kehadiran.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Laporan Kehadiran UMGAP',
      );
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Date range picker ─────────────────────
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate:   DateTime(2023),
      lastDate:    DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: UColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _mode     = 'range';
        _dateFrom = picked.start;
        _dateTo   = picked.end;
      });
      _load();
    }
  }

  Future<void> _pickMonth(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MonthSheet(
        current: _month,
        onSelect: (m) {
          setState(() { _mode = 'month'; _month = m; });
          _load();
        },
      ),
    );
  }

  // ── Period label ─────────────────────────
  String get _periodLabel {
    if (_mode == 'range' && _dateFrom != null && _dateTo != null) {
      return '${_shortDate(_dateFrom!)} – ${_shortDate(_dateTo!)}';
    }
    final parts = _month.split('-');
    const names = ['','Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'];
    return '${names[int.parse(parts[1])]} ${parts[0]}';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/'
          '${d.month.toString().padLeft(2,'0')}/'
          '${d.year}';

  // ── Data helpers ──────────────────────────
  List<dynamic> get _employees =>
      List<dynamic>.from(_data['employees'] ?? []);

  int _val(Map m, String k) => (m[k] as num?)?.toInt() ?? 0;

  String _rp(dynamic v) {
    final n = (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    if (n == 0) return 'Rp -';
    return 'Rp ${n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final employees = _employees;
    final workdays  = _val(_data, 'workdays');

    // Aggregated summary
    int totPresent = 0, totLate = 0, totSick = 0,
        totLeave = 0, totAbsent = 0, totSalary = 0;
    for (final e in employees) {
      final m = Map<String, dynamic>.from(e);
      totPresent += _val(m, 'present_days');
      totLate    += _val(m, 'late_days');
      totSick    += _val(m, 'sick_days');
      totLeave   += _val(m, 'leave_days');
      totAbsent  += _val(m, 'absent_days');
      final daily   = _val(m, 'daily_salary');
      final monthly = _val(m, 'monthly_salary');
      final worked  = _val(m,'present_days') + _val(m,'late_days') +
          _val(m,'sick_days')    + _val(m,'leave_days');
      totSalary += monthly > 0 ? monthly : worked * daily;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── App Bar ──────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: UColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Export button
              _exporting
                  ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
                  : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Export Excel',
                  onPressed: _export),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [UColors.primaryDark, UColors.primaryMid],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statistik Kehadiran',
                          style: TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      // ── Filter chips ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _FilterChip(
                            label: _periodLabel,
                            icon: Icons.calendar_month_rounded,
                            onTap: () => _pickMonth(context),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Rentang Tanggal',
                            icon: Icons.date_range_rounded,
                            active: _mode == 'range',
                            onTap: _pickRange,
                          ),
                        ]),
                      ),
                    ],
                  ),
                )),
              ),
            ),
          ),

          // ── Summary Cards ─────────────────
          SliverToBoxAdapter(child: _SummaryBar(
            workdays: workdays,
            employees: employees.length,
            totPresent: totPresent,
            totAbsent: totAbsent,
            totSalary: totSalary,
            rp: _rp,
          )),

          // ── Attendance Chart ──────────────
          if (!_loading && employees.isNotEmpty)
            SliverToBoxAdapter(child: _AttendanceChart(
              employees: employees,
              valFn: _val,
            )),
        ],

        body: _loading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : employees.isEmpty
            ? _EmptyState(onRefresh: _load)
            : FadeTransition(
          opacity: _fadeAnim,
          child: RefreshIndicator(
            color: UColors.primary,
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: employees.length,
              itemBuilder: (_, i) {
                final e = Map<String, dynamic>.from(employees[i]);
                return _EmployeeCard(
                  data: e,
                  workdays: workdays,
                  rp: _rp,
                  valFn: _val,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  SUMMARY BAR
// ════════════════════════════════════════════
class _SummaryBar extends StatelessWidget {
  final int workdays, employees, totPresent, totAbsent, totSalary;
  final String Function(dynamic) rp;
  const _SummaryBar({required this.workdays, required this.employees,
    required this.totPresent, required this.totAbsent,
    required this.totSalary, required this.rp});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UColors.primaryDark,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: UColors.primary.withOpacity(0.12),
              blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Row(children: [
            _MiniCard(
              value: '$workdays',
              label: 'Hari Kerja',
              icon: Icons.work_outline_rounded,
              color: UColors.primary,
              flex: 1,
            ),
            const SizedBox(width: 10),
            _MiniCard(
              value: '$employees',
              label: 'Karyawan',
              icon: Icons.people_outline_rounded,
              color: UColors.info,
              flex: 1,
            ),
            const SizedBox(width: 10),
            _MiniCard(
              value: '$totPresent',
              label: 'Total Hadir',
              icon: Icons.check_circle_outline_rounded,
              color: UColors.success,
              flex: 1,
            ),
            const SizedBox(width: 10),
            _MiniCard(
              value: '$totAbsent',
              label: 'Total Absen',
              icon: Icons.cancel_outlined,
              color: UColors.danger,
              flex: 1,
            ),
          ]),
          const SizedBox(height: 12),
          // Total salary row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [UColors.primaryDark, UColors.primaryMid]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Estimasi Total Gaji',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                Text(rp(totSalary),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final int flex;
  const _MiniCard({required this.value, required this.label,
    required this.icon, required this.color, required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9,
            color: UColors.textMid, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ════════════════════════════════════════════
//  ATTENDANCE CHART (Custom bar chart)
// ════════════════════════════════════════════
class _AttendanceChart extends StatelessWidget {
  final List<dynamic> employees;
  final int Function(Map, String) valFn;
  const _AttendanceChart({required this.employees, required this.valFn});

  @override
  Widget build(BuildContext context) {
    // Take top 8 by name
    final list = employees.take(8).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: UColors.primary.withOpacity(0.07),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Grafik Kehadiran',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: UColors.primaryDark)),
          // Legend
          Row(children: [
            _LegendDot(color: UColors.success, label: 'Hadir'),
            const SizedBox(width: 8),
            _LegendDot(color: UColors.warning, label: 'Absen'),
          ]),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _BarChartPainter(
              items: list.map((e) {
                final m = Map<String, dynamic>.from(e);
                return _BarItem(
                  name: '${m['employee_name'] ?? '?'}'.split(' ').first,
                  present: valFn(m, 'present_days') + valFn(m, 'late_days'),
                  absent:  valFn(m, 'absent_days'),
                );
              }).toList(),
            ),
            size: const Size(double.infinity, 140),
          ),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 10, color: UColors.textMid,
        fontWeight: FontWeight.w500)),
  ]);
}

class _BarItem {
  final String name;
  final int present, absent;
  _BarItem({required this.name, required this.present, required this.absent});
}

class _BarChartPainter extends CustomPainter {
  final List<_BarItem> items;
  _BarChartPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    final maxVal = items.map((e) => e.present + e.absent)
        .fold(0, math.max).toDouble();
    if (maxVal == 0) return;

    final barW    = (size.width / items.length) * 0.5;
    final spacing = (size.width / items.length);
    final chartH  = size.height - 28;   // leave space for labels

    final paintPresent = Paint()
      ..color = UColors.success
      ..style = PaintingStyle.fill;
    final paintAbsent = Paint()
      ..color = UColors.warning.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < items.length; i++) {
      final item    = items[i];
      final centerX = spacing * i + spacing / 2;
      final totalH  = (item.present + item.absent) / maxVal * chartH;
      final presentH = item.present / maxVal * chartH;
      final absentH  = item.absent  / maxVal * chartH;

      final left  = centerX - barW / 2;
      final right = centerX + barW / 2;

      // Absent bar (bottom)
      if (absentH > 0) {
        final top = chartH - absentH;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(left, top, right, chartH,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          paintAbsent,
        );
      }

      // Present bar (stacked on top)
      if (presentH > 0) {
        final top = chartH - totalH;
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(left, top, right, chartH - absentH,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          paintPresent,
        );
      }

      // Name label
      final tp = TextPainter(
        text: TextSpan(text: item.name,
            style: const TextStyle(fontSize: 9, color: UColors.textMid,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: spacing);
      tp.paint(canvas, Offset(centerX - tp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.items != items;
}

// ════════════════════════════════════════════
//  EMPLOYEE CARD
// ════════════════════════════════════════════
class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int workdays;
  final String Function(dynamic) rp;
  final int Function(Map, String) valFn;
  const _EmployeeCard({required this.data, required this.workdays,
    required this.rp, required this.valFn});

  @override
  Widget build(BuildContext context) {
    final name     = '${data['employee_name'] ?? '?'}';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final present  = valFn(data, 'present_days') + valFn(data, 'late_days');
    final absent   = valFn(data, 'absent_days');
    final sick     = valFn(data, 'sick_days');
    final leave    = valFn(data, 'leave_days');
    final daily    = valFn(data, 'daily_salary');
    final monthly  = valFn(data, 'monthly_salary');
    final worked   = present + sick + leave;
    final totalGaji = monthly > 0 ? monthly : worked * daily;
    final pct       = workdays > 0 ? (present / workdays).clamp(0.0, 1.0) : 0.0;
    final accentColor = absent > 3 ? UColors.danger
        : absent > 0 ? UColors.warning : UColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: UColors.primary.withOpacity(0.07),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 4, decoration: BoxDecoration(
            color: accentColor,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18)))),

        Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [UColors.primaryDark, UColors.primaryMid]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(initial,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 15))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800, color: UColors.primaryDark)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: UColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    monthly > 0
                        ? '${rp(monthly)}/bln'
                        : '${rp(daily)}/hari',
                    style: const TextStyle(fontSize: 10, color: UColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Total Gaji', style: TextStyle(
                  fontSize: 10, color: UColors.textMid)),
              Text(rp(totalGaji), style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: UColors.primaryDark)),
            ]),
          ]),

          if (workdays > 0) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Kehadiran', style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
              Text('$present / $workdays hari',
                  style: const TextStyle(fontSize: 11,
                      color: UColors.primary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(
                    pct >= 0.9 ? UColors.success
                        : pct >= 0.7 ? UColors.primary
                        : UColors.warning),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _Stat(Icons.check_circle_rounded,  UColors.success, present,  'Hadir'),
              _Stat(Icons.schedule_rounded,      UColors.warning, valFn(data,'late_days'), 'Telat'),
              _Stat(Icons.medical_services_rounded, UColors.info, sick,    'Sakit'),
              _Stat(Icons.beach_access_rounded,  const Color(0xFF7B1FA2), leave, 'Izin'),
              _Stat(Icons.cancel_rounded,        UColors.danger, absent,   'Absen'),
            ]),
          ),
        ])),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int val;
  final String label;
  const _Stat(this.icon, this.color, this.val, this.label);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: val == 0 ? Colors.grey.shade300 : color, size: 18),
    const SizedBox(height: 3),
    Text('$val', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
        color: val == 0 ? Colors.grey.shade300 : color)),
    Text(label, style: const TextStyle(fontSize: 9,
        color: UColors.textMid, fontWeight: FontWeight.w500)),
  ]));
}

// ════════════════════════════════════════════
//  MONTH PICKER
// ════════════════════════════════════════════
class _MonthSheet extends StatefulWidget {
  final String current;
  final void Function(String) onSelect;
  const _MonthSheet({required this.current, required this.onSelect});
  @override State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late int _year;
  static const _m = ['Jan','Feb','Mar','Apr','Mei','Jun',
    'Jul','Agu','Sep','Okt','Nov','Des'];

  @override
  void initState() {
    super.initState();
    _year = int.parse(widget.current.split('-')[0]);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(
          color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left_rounded), color: UColors.primary),
        Text('$_year', style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: UColors.textDark)),
        IconButton(onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right_rounded), color: UColors.primary),
      ]),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 10,
            crossAxisSpacing: 10, childAspectRatio: 1.7),
        itemCount: 12,
        itemBuilder: (_, i) {
          final sel = widget.current ==
              '${_year.toString().padLeft(4,'0')}-${(i+1).toString().padLeft(2,'0')}';
          return GestureDetector(
            onTap: () {
              widget.onSelect('${_year.toString().padLeft(4,'0')}-'
                  '${(i+1).toString().padLeft(2,'0')}');
              Navigator.pop(context);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(
                    colors: [UColors.primaryDark, UColors.primaryMid]) : null,
                color: sel ? null : const Color(0xFFF2F5FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(_m[i], style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: sel ? Colors.white : UColors.textDark))),
            ),
          );
        },
      ),
    ]),
  );
}

// ════════════════════════════════════════════
//  MISC WIDGETS
// ════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon,
    this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active ? UColors.primary : Colors.white.withOpacity(0.4),
            width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: active ? UColors.primary : Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            color: active ? UColors.primary : Colors.white,
            fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey.shade200),
    const SizedBox(height: 12),
    Text('Tidak ada data untuk periode ini',
        style: TextStyle(color: Colors.grey.shade400,
            fontWeight: FontWeight.w600, fontSize: 14)),
    const SizedBox(height: 12),
    TextButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Muat Ulang'),
      style: TextButton.styleFrom(foregroundColor: UColors.primary),
    ),
  ]));
}