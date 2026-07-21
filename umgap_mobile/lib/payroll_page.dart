import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ════════════════════════════════════════════
//  PAYROLL PAGE  —  Professional Edition
// ════════════════════════════════════════════
class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});
  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  // ── State ────────────────────────────────
  bool   _loading = true;
  Map<String, dynamic> _data = {};
  String _month   = _currentMonth();   // "YYYY-MM"
  final  _search  = TextEditingController();
  String _query   = '';

  // ── Init ─────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────
  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}';
  }

  String _monthLabel(String m) {
    const names = ['','Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'];
    final parts = m.split('-');
    return '${names[int.parse(parts[1])]} ${parts[0]}';
  }

  void _prevMonth() {
    final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
    final prev = DateTime(d.year, d.month - 1);
    setState(() => _month = '${prev.year.toString().padLeft(4,'0')}-${prev.month.toString().padLeft(2,'0')}');
    _load();
  }

  void _nextMonth() {
    final d = DateTime(int.parse(_month.split('-')[0]), int.parse(_month.split('-')[1]));
    final next = DateTime(d.year, d.month + 1);
    setState(() => _month = '${next.year.toString().padLeft(4,'0')}-${next.month.toString().padLeft(2,'0')}');
    _load();
  }

  Future<void> _pickMonth(BuildContext context) async {
    final parts  = _month.split('-');
    int selYear  = int.parse(parts[0]);
    int selMonth = int.parse(parts[1]);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MonthPickerSheet(
        year: selYear, month: selMonth,
        onSelect: (y, m) {
          setState(() => _month =
          '${y.toString().padLeft(4,'0')}-${m.toString().padLeft(2,'0')}');
          _load();
        },
      ),
    );
  }

  // ── Load data ────────────────────────────
  Future<void> _load() async {
    final cKey = CacheService.kPayroll(_month);
    final cached = await CacheService.get(cKey);
    if (cached != null && mounted) setState(() { _data = cached; _loading = false; });
    else setState(() => _loading = true);
    try {
      final result = await ApiService.getPayroll(month: _month);
      if (!mounted) return;
      await CacheService.set(cKey, result);
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  // ── Format Rupiah ─────────────────────────
  String _rp(dynamic v) {
    final n = (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    if (n == 0) return 'Rp -';
    return 'Rp ${n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // ── Computed salary ───────────────────────
  int _totalGaji(Map<String, dynamic> item) {
    final daily   = (item['daily_salary']   as num?)?.toInt() ?? 0;
    final monthly = (item['monthly_salary'] as num?)?.toInt() ?? 0;
    final present = (item['days_present']   as num?)?.toInt() ?? 0;
    final sick    = (item['days_sick']      as num?)?.toInt() ?? 0;
    final leave   = (item['days_leave']     as num?)?.toInt() ?? 0;
    if (monthly > 0) return monthly;
    return (present + sick + leave) * daily;
  }

  // ── Summary totals ────────────────────────
  Map<String, int> _summary(List rows) {
    int totalGaji = 0, totalHadir = 0, totalAbsen = 0;
    for (final r in rows) {
      totalGaji  += _totalGaji(Map<String, dynamic>.from(r));
      totalHadir += (r['days_present'] as num?)?.toInt() ?? 0;
      totalAbsen += (r['days_absent']  as num?)?.toInt() ?? 0;
    }
    return {'gaji': totalGaji, 'hadir': totalHadir, 'absen': totalAbsen};
  }

  // ════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final allRows = List<dynamic>.from(_data['payroll'] ?? []);
    final workdays = (_data['workdays'] as num?)?.toInt() ?? 0;

    final rows = _query.isEmpty
        ? allRows
        : allRows.where((r) =>
        '${r['name']}'.toLowerCase().contains(_query)).toList();

    final sum = _summary(rows);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Sliver App Bar ───────────────
          SliverAppBar(
            expandedHeight: 170,
            floating: false,
            pinned: true,
            backgroundColor: UColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Penggajian',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [UColors.primaryDark, UColors.primaryMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // ── Month navigator ──
                        Row(children: [
                          _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickMonth(context),
                              child: Column(children: [
                                Text(_monthLabel(_month),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.calendar_month_rounded,
                                      color: Colors.white.withOpacity(0.6), size: 12),
                                  const SizedBox(width: 4),
                                  Text('$workdays hari kerja',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                ]),
                              ]),
                            ),
                          ),
                          _NavBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Summary strip ─────────────────
          SliverToBoxAdapter(
            child: Container(
              color: UColors.primaryDark,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  boxShadow: [BoxShadow(
                      color: UColors.primary.withOpacity(0.12),
                      blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  _SummaryTile(
                    label: 'Total Gaji',
                    value: _rp(sum['gaji']),
                    icon: Icons.account_balance_wallet_rounded,
                    color: UColors.primary,
                  ),
                  _Divider(),
                  _SummaryTile(
                    label: 'Total Hadir',
                    value: '${sum['hadir']}',
                    icon: Icons.check_circle_rounded,
                    color: UColors.success,
                  ),
                  _Divider(),
                  _SummaryTile(
                    label: 'Karyawan',
                    value: '${rows.length}',
                    icon: Icons.people_rounded,
                    color: UColors.info,
                  ),
                ]),
              ),
            ),
          ),

          // ── Search bar ───────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 13, color: UColors.textDark,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Cari nama karyawan...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: UColors.primary, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 18),
                      onPressed: () { _search.clear(); setState(() => _query = ''); })
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF2F5FC),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: UColors.primaryMid, width: 1.5)),
                ),
              ),
            ),
          ),

          // ── Sticky bottom border of header ─
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
          ),
        ],

        // ── Body ─────────────────────────────
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: UColors.primary))
            : rows.isEmpty
            ? _EmptyState(
            hasQuery: _query.isNotEmpty,
            onClear: () { _search.clear(); setState(() => _query = ''); })
            : RefreshIndicator(
          color: UColors.primary,
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            itemCount: rows.length,
            itemBuilder: (_, i) => _PayrollCard(
              item: Map<String, dynamic>.from(rows[i]),
              workdays: workdays,
              totalGaji: _totalGaji(Map<String, dynamic>.from(rows[i])),
              rp: _rp,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  PAYROLL CARD
// ════════════════════════════════════════════
class _PayrollCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int workdays;
  final int totalGaji;
  final String Function(dynamic) rp;

  const _PayrollCard({
    required this.item,
    required this.workdays,
    required this.totalGaji,
    required this.rp,
  });

  static const _statItems = [
    {'key': 'days_present', 'label': 'Hadir',  'icon': Icons.check_circle_rounded,    'color': UColors.success},
    {'key': 'days_sick',    'label': 'Sakit',  'icon': Icons.medical_services_rounded, 'color': UColors.warning},
    {'key': 'days_leave',   'label': 'Izin',   'icon': Icons.beach_access_rounded,     'color': UColors.info},
    {'key': 'days_absent',  'label': 'Absen',  'icon': Icons.cancel_rounded,           'color': UColors.danger},
  ];

  @override
  Widget build(BuildContext context) {
    final name    = '${item['name'] ?? '?'}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final present = (item['days_present'] as num?)?.toInt() ?? 0;
    final absent  = (item['days_absent']  as num?)?.toInt() ?? 0;
    final hasPct  = workdays > 0;
    final pct     = hasPct ? (present / workdays).clamp(0.0, 1.0) : 0.0;

    // Accent: merah kalau banyak absen, hijau kalau bagus
    final accentColor = absent > 3
        ? UColors.danger
        : absent > 0
        ? UColors.warning
        : UColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: UColors.primary.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Top accent bar ─────────────────
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Header row ─────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [UColors.primaryDark, UColors.primaryMid],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: UColors.primary.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15))),
              ),
              const SizedBox(width: 12),

              // Name + gaji harian
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: UColors.textDark)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: UColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        (item['monthly_salary'] as num?)?.toInt() == 0 ||
                            item['monthly_salary'] == null
                            ? '${rp(item['daily_salary'])}/hari'
                            : '${rp(item['monthly_salary'])}/bln',
                        style: const TextStyle(
                            fontSize: 11, color: UColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ])),

              // Total gaji
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Total Gaji', style: TextStyle(
                    fontSize: 10, color: UColors.textMid,
                    fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(rp(totalGaji), style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: UColors.primaryDark)),
              ]),
            ]),

            const SizedBox(height: 14),

            // ── Attendance progress bar ─────
            if (workdays > 0) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Kehadiran', style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
                Text('$present / $workdays hari',
                    style: const TextStyle(
                        fontSize: 11, color: UColors.primary,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(
                      pct >= 0.9 ? UColors.success
                          : pct >= 0.7 ? UColors.primary
                          : UColors.warning),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Stats row ──────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: _statItems.map((s) {
                  final val = (item[s['key']] as num?)?.toInt() ?? 0;
                  return Expanded(child: Column(children: [
                    Icon(s['icon'] as IconData,
                        color: (s['color'] as Color).withOpacity(val == 0 ? 0.3 : 1),
                        size: 20),
                    const SizedBox(height: 4),
                    Text('$val',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: val == 0
                                ? Colors.grey.shade300
                                : s['color'] as Color)),
                    Text('${s['label']}',
                        style: const TextStyle(
                            fontSize: 10, color: UColors.textMid,
                            fontWeight: FontWeight.w500)),
                  ]));
                }).toList(),
              ),
            ),

          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════
//  MONTH PICKER BOTTOM SHEET
// ════════════════════════════════════════════
class _MonthPickerSheet extends StatefulWidget {
  final int year, month;
  final void Function(int y, int m) onSelect;
  const _MonthPickerSheet({required this.year, required this.month,
    required this.onSelect});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  static const _months = ['Jan','Feb','Mar','Apr','Mei','Jun',
    'Jul','Agu','Sep','Okt','Nov','Des'];

  @override
  void initState() { super.initState(); _year = widget.year; }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Year nav
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left_rounded),
            color: UColors.primary,
          ),
          Text('$_year', style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: UColors.textDark)),
          IconButton(
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right_rounded),
            color: UColors.primary,
          ),
        ]),
        const SizedBox(height: 12),

        // Month grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: 1.7),
          itemCount: 12,
          itemBuilder: (_, i) {
            final isSelected = _year == widget.year && (i + 1) == widget.month;
            return GestureDetector(
              onTap: () {
                widget.onSelect(_year, i + 1);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                      colors: [UColors.primaryDark, UColors.primaryMid])
                      : null,
                  color: isSelected ? null : const Color(0xFFF2F5FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(_months[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isSelected ? Colors.white : UColors.textDark))),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════
//  MICRO WIDGETS
// ════════════════════════════════════════════
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryTile({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 16),
    ),
    const SizedBox(height: 5),
    Text(value, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w800, color: color),
        overflow: TextOverflow.ellipsis),
    Text(label, style: const TextStyle(
        fontSize: 10, color: UColors.textMid, fontWeight: FontWeight.w500)),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 40,
      color: Colors.grey.shade100);
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onClear;
  const _EmptyState({required this.hasQuery, required this.onClear});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Icon(hasQuery ? Icons.search_off_rounded : Icons.payments_rounded,
        size: 56, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text(
        hasQuery ? 'Tidak ada hasil untuk pencarian ini' : 'Tidak ada data payroll',
        style: TextStyle(color: Colors.grey.shade400,
            fontWeight: FontWeight.w600, fontSize: 14)),
    if (hasQuery) ...[
      const SizedBox(height: 8),
      TextButton(onPressed: onClear,
          child: const Text('Hapus pencarian',
              style: TextStyle(color: UColors.primary))),
    ],
  ],
  ));
}