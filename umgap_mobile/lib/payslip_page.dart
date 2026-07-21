import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ════════════════════════════════════════════
//  PAYSLIP PAGE — Slip Gaji Mingguan Karyawan
// ════════════════════════════════════════════
class PayslipPage extends StatefulWidget {
  const PayslipPage({super.key});
  @override
  State<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends State<PayslipPage> {
  bool   _loading = true;
  Map<String, dynamic> _data = {};

  // Senin minggu berjalan
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _load();
  }

  String get _weekParam =>
      '${_weekStart.year}-${_weekStart.month.toString().padLeft(2,'0')}-${_weekStart.day.toString().padLeft(2,'0')}';

  Future<void> _load() async {
    final cKey = CacheService.kPayslip(_weekParam);
    final cached = await CacheService.get(cKey);
    if (cached != null && mounted) setState(() { _data = cached; _loading = false; });
    else setState(() => _loading = true);
    try {
      final res = await ApiService.getMyPayslip(week: _weekParam);
      if (!mounted) return;
      await CacheService.set(cKey, res);
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    final next = _weekStart.add(const Duration(days: 7));
    if (next.isAfter(DateTime.now())) return; // tidak bisa ke depan
    setState(() => _weekStart = next);
    _load();
  }

  bool get _canNext =>
      _weekStart.add(const Duration(days: 7)).isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        _buildHeader(),
        if (_loading)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: UColors.primary)))
        else
          Expanded(child: RefreshIndicator(
            color:     UColors.primary,
            onRefresh: _load,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.base, USpace.base, 48),
              children: [
                _buildSlipCard(),
                const SizedBox(height: USpace.md),
                _buildDayDetail(),
                const SizedBox(height: USpace.md),
                _buildInfoNote(),
              ],
            ),
          )),
      ]),
    );
  }

  // ── Header ──────────────────────────────────
  Widget _buildHeader() {
    final label = _data['week_label'] ?? _weekParam;

    return UHeader(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            USpace.sm, USpace.sm, USpace.base, USpace.xl),
        child: Column(children: [
          // Top bar
          Row(children: [
            UBackButton(),
            const SizedBox(width: USpace.md),
            Expanded(child: Text('Slip Gaji Mingguan',
                style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: USpace.lg),

          // Week navigator
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Prev
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _prevWeek(); },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: USpace.lg),
            Column(children: [
              Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded,
                    color: Colors.white.withOpacity(0.55), size: 12),
                const SizedBox(width: 4),
                Text('${_data['workdays'] ?? 6} hari kerja',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ]),
            const SizedBox(width: USpace.lg),
            // Next
            GestureDetector(
              onTap: _canNext
                  ? () { HapticFeedback.lightImpact(); _nextWeek(); }
                  : null,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _canNext
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: _canNext
                        ? Colors.white
                        : Colors.white.withOpacity(0.25),
                    size: 22),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Slip Card Utama ─────────────────────────
  Widget _buildSlipCard() {
    final name        = '${_data['employee_name'] ?? '-'}';
    final present     = (_data['days_present']  as num?)?.toInt() ?? 0;
    final sick        = (_data['days_sick']     as num?)?.toInt() ?? 0;
    final leave       = (_data['days_leave']    as num?)?.toInt() ?? 0;
    final absent      = (_data['days_absent']   as num?)?.toInt() ?? 0;
    final late        = (_data['days_late']     as num?)?.toInt() ?? 0;
    final dailySalary = (_data['daily_salary']  as num?)?.toInt() ?? 0;
    final totalGaji   = (_data['weekly_salary'] as num?)?.toInt() ?? 0;
    final salaryType  = '${_data['salary_type'] ?? 'daily'}';
    final workdays    = (_data['workdays']      as num?)?.toInt() ?? 6;

    final pct = workdays > 0 ? present / workdays : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UColors.navy, UColors.navyMid, Color(0xFF1A3A7A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: UShadow.lg(UColors.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(USpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header slip
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(URadius.sm),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: USpace.md),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SLIP GAJI MINGGUAN',
                  style: TextStyle(color: Colors.white54, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w800)),
            ])),
            // Badge tipe gaji
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(URadius.full),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: Text(
                salaryType == 'monthly' ? 'Bulanan' : 'Harian',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          const SizedBox(height: USpace.lg),

          // Divider gradient
          Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0)]))),

          const SizedBox(height: USpace.base),

          // Stat chips
          Row(children: [
            _SlipStat('Hadir',  '$present', UColors.success),
            _SlipStat('Sakit',  '$sick',    UColors.info),
            _SlipStat('Izin',   '$leave',   UColors.purple),
            _SlipStat('Absen',  '$absent',  UColors.danger),
            _SlipStat('Telat',  '$late',    UColors.warning),
          ]),

          const SizedBox(height: USpace.base),

          // Progress bar kehadiran
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Kehadiran', style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$present / $workdays hari',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:          pct.clamp(0.0, 1.0),
                minHeight:      7,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor:     AlwaysStoppedAnimation(
                  pct >= 0.9 ? UColors.success
                      : pct >= 0.6 ? UColors.cyan
                      : UColors.warning,
                ),
              ),
            ),
          ]),

          const SizedBox(height: USpace.base),

          // Divider
          Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0)]))),

          const SizedBox(height: USpace.base),

          // Kalkulasi gaji
          if (salaryType != 'monthly') ...[
            _SlipRow(
              label: 'Gaji per Hari',
              value: uRupiah(dailySalary),
              isLight: true,
            ),
            _SlipRow(
              label: 'Hari Dihitung',
              value: '${present + sick + leave} hari',
              isLight: true,
            ),
            const SizedBox(height: USpace.sm),
          ] else ...[
            _SlipRow(
              label: 'Estimasi Mingguan',
              value: '(dari gaji bulanan)',
              isLight: true,
            ),
            const SizedBox(height: USpace.sm),
          ],

          // Total
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: USpace.base, vertical: USpace.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(URadius.md),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: USpace.sm),
              const Text('Total Estimasi Minggu Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(uRupiah(totalGaji), style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          ),

          const SizedBox(height: USpace.md),

          // Disclaimer
          Text('* Estimasi berdasarkan kehadiran. Gaji resmi ditetapkan admin.',
              style: TextStyle(color: Colors.white.withOpacity(0.35),
                  fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── Detail per Hari ─────────────────────────
  Widget _buildDayDetail() {
    final days = List<dynamic>.from(_data['days_detail'] ?? []);
    if (days.isEmpty) return const SizedBox();

    return Container(
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.card,
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              USpace.base, USpace.md, USpace.base, USpace.md),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: UColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(URadius.xs),
              ),
              child: const Icon(Icons.calendar_view_week_rounded,
                  color: UColors.primary, size: 16),
            ),
            const SizedBox(width: USpace.sm),
            Text('Detail Harian', style: UText.h5),
          ]),
        ),
        Divider(height: 1, color: UColors.divider),

        // List hari
        ...days.asMap().entries.map((entry) {
          final i    = entry.key;
          final day  = entry.value as Map;
          final status      = '${day['status'] ?? 'BELUM'}';
          final arrivalType = '${day['arrival_type'] ?? '-'}';
          final dayName     = '${day['day_name'] ?? '-'}';
          final checkin     = '${day['checkin_at'] ?? '-'}';
          final note        = '${day['note'] ?? ''}';
          final isLast      = i == days.length - 1;

          final statusColor = _statusColor(status);
          final statusLabel = _statusLabel(status, arrivalType);
          final statusIcon  = _statusIcon(status);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: USpace.base, vertical: 12),
              child: Row(children: [
                // Hari
                SizedBox(
                  width: 60,
                  child: Text(dayName, style: UText.bodyS.copyWith(
                      fontWeight: FontWeight.w700, color: UColors.textDark)),
                ),
                // Icon status
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 15),
                ),
                const SizedBox(width: USpace.sm),
                // Status + jam
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(statusLabel, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: statusColor)),
                  if (checkin != '-' && checkin.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text('Masuk: ${_formatCheckin(checkin)}',
                        style: UText.caption),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(note, style: UText.caption,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ])),
                // Badge
                UBadge(statusLabel, color: statusColor),
              ]),
            ),
            if (!isLast) Divider(height: 1, color: UColors.divider),
          ]);
        }),
      ]),
    );
  }

  // ── Info note ───────────────────────────────
  Widget _buildInfoNote() {
    return UInfoBox(
      'Slip ini bersifat estimasi. Jumlah gaji final ditentukan oleh admin '
          'melalui modul Payroll. Hubungi admin untuk informasi lebih lanjut.',
      variant: UInfoBoxVariant.info,
    );
  }

  // ── Helpers ─────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PRESENT': return UColors.success;
      case 'SICK':    return UColors.info;
      case 'LEAVE':   return UColors.purple;
      case 'ABSENT':  return UColors.danger;
      default:        return UColors.textSoft;
    }
  }

  String _statusLabel(String status, String arrival) {
    if (status == 'PRESENT') {
      return arrival == 'LATE' ? 'Hadir (Terlambat)' : 'Hadir';
    }
    switch (status) {
      case 'SICK':   return 'Sakit';
      case 'LEAVE':  return 'Izin';
      case 'ABSENT': return 'Absen';
      default:       return 'Belum Absen';
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case 'PRESENT': return Icons.check_circle_rounded;
      case 'SICK':    return Icons.medical_services_rounded;
      case 'LEAVE':   return Icons.beach_access_rounded;
      case 'ABSENT':  return Icons.cancel_rounded;
      default:        return Icons.radio_button_unchecked_rounded;
    }
  }

  String _formatCheckin(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} WIB';
    } catch (_) {
      return raw.length >= 5 ? raw.substring(0, 5) : raw;
    }
  }
}

// ════════════════════════════════════════════
//  MICRO WIDGETS
// ════════════════════════════════════════════
class _SlipStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _SlipStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(
        color:      int.tryParse(value) == 0
            ? Colors.white24 : color,
        fontSize:   18,
        fontWeight: FontWeight.w900,
        fontFeatures: const [FontFeature.tabularFigures()])),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(
        color: Colors.white38, fontSize: 9,
        fontWeight: FontWeight.w600)),
  ]));
}

class _SlipRow extends StatelessWidget {
  final String label, value;
  final bool   isLight;
  const _SlipRow({required this.label, required this.value,
    this.isLight = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label, style: TextStyle(
          color: isLight ? Colors.white54 : Colors.white70,
          fontSize: 12, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(
          color: isLight ? Colors.white70 : Colors.white,
          fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}