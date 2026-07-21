import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ════════════════════════════════════════════
//  OWNER STATS PAGE
//  Statistik lengkap: Keuangan + SDM + Stok
// ════════════════════════════════════════════
class OwnerStatsPage extends StatefulWidget {
  const OwnerStatsPage({super.key});
  @override State<OwnerStatsPage> createState() => _OwnerStatsPageState();
}

class _OwnerStatsPageState extends State<OwnerStatsPage>
    with SingleTickerProviderStateMixin {

  bool   _loading   = true;
  bool   _exporting = false;
  Map<String, dynamic> _data = {};
  String _month = _nowMonth();
  late TabController _tab;

  static String _nowMonth() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4,'0')}-${n.month.toString().padLeft(2,'0')}';
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    final cached = await CacheService.get(CacheService.kOwnerStatsM(_month));
    if (cached != null && mounted) setState(() { _data = cached; _loading = false; });
    else setState(() => _loading = true);
    try {
      final res = await ApiService.getOwnerStats(month: _month);
      if (!mounted) return;
      await CacheService.set(CacheService.kOwnerStatsM(_month), res);
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ApiService.downloadOwnerStatsExcel(month: _month);
      final dir   = await getTemporaryDirectory();
      final file  = File('${dir.path}/UMGAP_Laporan_Keuangan_$_month.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          subject: 'Laporan Keuangan UMGAP $_month');
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickMonth() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MonthPicker(current: _month, onSelect: (m) {
        setState(() => _month = m);
        _load();
      }),
    );
  }

  // ── Helpers ───────────────────────────────
  int    _i(dynamic v) => v == null ? 0 : (double.tryParse('$v') ?? 0).toInt();
  double _d(dynamic v) => double.tryParse('$v') ?? 0.0;
  String _rp(dynamic v) {
    final n = _i(v);
    final abs = n.abs();
    final neg = n < 0 ? '-' : '';
    if (abs == 0) return 'Rp -';
    if (abs >= 1000000000) return '${neg}Rp ${(abs/1000000000).toStringAsFixed(1)}M';
    if (abs >= 1000000)    return '${neg}Rp ${(abs/1000000).toStringAsFixed(1)} Jt';
    if (abs >= 1000)       return '${neg}Rp ${(abs/1000).toStringAsFixed(0)}K';
    return '${neg}Rp $abs';
  }

  String get _periodLabel {
    final parts = _month.split('-');
    const mn = ['','Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'];
    return '${mn[int.parse(parts[1])]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FC),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: UColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded),
                tooltip: 'Pilih Bulan',
                onPressed: _pickMonth,
              ),
              _exporting
                  ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
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
                    colors: [UColors.navy, Color(0xFF0E7490)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Statistik Bisnis',
                          style: TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _pickMonth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_month_rounded,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Text(_periodLabel, style: const TextStyle(
                                color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded,
                                color: Colors.white54, size: 16),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                )),
              ),
            ),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: UColors.cyan,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(text: 'Keuangan'),
                Tab(text: 'Stok & Trip'),
                Tab(text: 'SDM & Gaji'),
                Tab(text: 'Hutang'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : TabBarView(controller: _tab, children: [
          _buildKeuangan(),
          _buildStokTrip(),
          _buildSDM(),
          _buildHutang(),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════
  //  TAB 1 — KEUANGAN
  // ════════════════════════════════════════
  Widget _buildKeuangan() {
    final fin    = (_data['finance_summary'] ?? {}) as Map<String, dynamic>;
    final trend  = List<dynamic>.from(_data['daily_trend'] ?? []);
    final mats   = List<dynamic>.from(_data['top_materials'] ?? []);

    final revenue     = _i(fin['total_revenue']);
    final buying      = _i(fin['total_buying']);
    final expense     = _i(fin['total_expense']);
    final grossProfit = _i(fin['gross_profit']);
    final netFinal    = _i(fin['net_profit_final']);
    final stok        = _i(fin['stok_value']);
    final revChange   = fin['revenue_vs_prev'];
    final profChange  = fin['profit_vs_prev'];

    return RefreshIndicator(color: UColors.primary, onRefresh: _load,
      child: ListView(physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // ── Ringkasan utama ─────────────────
          _SectionLabel('Ringkasan Bulan Ini'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _FinCard('Omzet', _rp(revenue),
                Icons.trending_up_rounded, UColors.success,
                change: revChange)),
            const SizedBox(width: 10),
            Expanded(child: _FinCard('Laba Kotor', _rp(grossProfit),
                Icons.account_balance_wallet_rounded,
                grossProfit >= 0 ? UColors.primary : UColors.danger,
                change: profChange)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FinCard('Modal Beli', _rp(buying),
                Icons.shopping_cart_outlined, UColors.textSoft)),
            const SizedBox(width: 10),
            Expanded(child: _FinCard('Biaya Ops', _rp(expense),
                Icons.receipt_outlined, UColors.warning)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FinCard('Nilai Stok', _rp(stok),
                Icons.inventory_2_rounded, const Color(0xFF00838F))),
            const SizedBox(width: 10),
            Expanded(child: _FinCard('Laba Bersih*', _rp(netFinal),
                Icons.savings_rounded,
                netFinal >= 0 ? UColors.success : UColors.danger,
                subtitle: '*setelah gaji')),
          ]),

          const SizedBox(height: 16),

          // ── Tren harian ─────────────────────
          if (trend.isNotEmpty) ...[
            _SectionLabel('Tren Penjualan 14 Hari'),
            const SizedBox(height: 8),
            _TrendChart(trend: trend, iRp: _rp),
            const SizedBox(height: 16),
          ],

          // ── Top material ────────────────────
          if (mats.isNotEmpty) ...[
            _SectionLabel('Top Material Terjual'),
            const SizedBox(height: 8),
            ...mats.asMap().entries.map((e) {
              final m     = e.value as Map<String, dynamic>;
              final rank  = e.key + 1;
              final kg    = _d(m['kg']);
              final nilai = _i(m['nilai']);
              final maxN  = _i((mats.first as Map)['nilai']);
              final pct   = maxN > 0 ? nilai / maxN : 0.0;
              return _MaterialRow(
                rank: rank, name: '${m['name']}',
                kg: kg, nilai: nilai, pct: pct, rp: _rp,
              );
            }),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  TAB 2 — STOK & TRIP JAKARTA
  // ════════════════════════════════════════
  Widget _buildStokTrip() {
    final stoks  = List<dynamic>.from(_data['stok_detail'] ?? []);
    final trips  = (_data['trips_summary'] ?? {}) as Map<String, dynamic>;
    final tlist  = List<dynamic>.from(trips['trips'] ?? []);

    return RefreshIndicator(color: UColors.primary, onRefresh: _load,
      child: ListView(physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // ── Stok ────────────────────────────
          _SectionLabel('Stok Gudang Saat Ini'),
          const SizedBox(height: 8),
          if (stoks.isEmpty)
            _Empty('Belum ada stok')
          else
            ...stoks.map((s) {
              final m = s as Map<String, dynamic>;
              final val = _i(m['total_value']);
              final stokList = stoks.map((x) => _i((x as Map)['total_value'])).toList();
              final maxV = stokList.isEmpty ? 1 : stokList.reduce(math.max);
              return _StokRow(
                name: '${m['name']}',
                kg: _d(m['qty_kg']),
                avgCost: _i(m['avg_cost']),
                totalValue: val,
                pct: maxV > 0 ? val / maxV : 0.0,
                rp: _rp,
              );
            }),

          const SizedBox(height: 20),

          // ── Trip Jakarta ─────────────────────
          _SectionLabel('Perjalanan Jakarta'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatPill('${_i(trips['total_trip'])} trip',
                'Total', UColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill('${_i(trips['open_trip'])} terbuka',
                'Status', UColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(_rp(trips['total_jual']),
                'Total Jual', UColors.success)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatPill(_rp(trips['net_result']),
                'Hasil Bersih',
                _i(trips['net_result']) >= 0 ? UColors.success : UColors.danger)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(_rp(trips['total_expense']),
                'Total Biaya', UColors.warning)),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ]),
          const SizedBox(height: 10),
          if (tlist.isEmpty)
            _Empty('Belum ada perjalanan bulan ini')
          else ...[
            ...tlist.map((t) {
              final trip = t as Map<String, dynamic>;
              final isOpen = '${trip['status']}' == 'OPEN';
              final net = _i(trip['net']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isOpen
                      ? UColors.primary.withOpacity(0.2)
                      : UColors.divider),
                ),
                child: Row(children: [
                  Container(width: 4, height: 40,
                      color: isOpen ? UColors.warning : UColors.success,
                      margin: const EdgeInsets.only(right: 12)),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${trip['note']}',
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 13, color: UColors.textDark)),
                    Text('${trip['date']}  •  ${isOpen ? 'Berlangsung' : 'Selesai'}',
                        style: UText.caption),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_rp(net), style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: net >= 0 ? UColors.success : UColors.danger)),
                    Text('bersih', style: UText.caption),
                  ]),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  TAB 3 — SDM & GAJI
  // ════════════════════════════════════════
  Widget _buildSDM() {
    final hr   = (_data['hr_summary'] ?? {}) as Map<String, dynamic>;
    final emps = List<dynamic>.from(hr['employees'] ?? []);
    final totalGaji = _i(hr['salary_total']);

    return RefreshIndicator(color: UColors.primary, onRefresh: _load,
      child: ListView(physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          // Ringkasan
          _SectionLabel('Ringkasan SDM'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatPill('${_i(hr['employee_count'])} orang',
                'Karyawan', UColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _StatPill(_rp(totalGaji),
                'Est. Gaji Total', UColors.warning)),
          ]),
          const SizedBox(height: 16),

          _SectionLabel('Detail per Karyawan'),
          const SizedBox(height: 8),
          if (emps.isEmpty)
            _Empty('Belum ada data karyawan')
          else
            ...emps.map((e) {
              final emp    = e as Map<String, dynamic>;
              final gaji   = _i(emp['gaji']);
              final worked = _i(emp['worked']);
              final absent = _i(emp['absent']);
              final late   = _i(emp['late']);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: UShadow.card,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: UColors.primary.withOpacity(0.10),
                      child: Text(
                        ('${emp['name']}').isNotEmpty
                            ? ('${emp['name']}')[0].toUpperCase() : '?',
                        style: const TextStyle(color: UColors.primary,
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${emp['name']}', style: UText.h5),
                      Text(_i(emp['monthly_salary']) > 0
                          ? 'Gaji Bulanan: ${_rp(emp['monthly_salary'])}'
                          : 'Harian: ${_rp(emp['daily_salary'])}/hari',
                          style: UText.caption),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_rp(gaji), style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15,
                          color: UColors.success)),
                      const Text('est. gaji', style: TextStyle(
                          fontSize: 10, color: UColors.textSoft)),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _EmpStat('✅', '$worked', 'Hadir'),
                    _EmpStat('❌', '$absent', 'Absen'),
                    _EmpStat('⏰', '$late', 'Telat'),
                    _EmpStat('🤒', '${_i(emp['sick'])}', 'Sakit'),
                  ]),
                ]),
              );
            }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //  TAB 4 — HUTANG & PIUTANG
  // ════════════════════════════════════════
  Widget _buildHutang() {
    final d    = (_data['debts_summary'] ?? {}) as Map<String, dynamic>;
    final items = List<dynamic>.from(d['items'] ?? []);
    final hutang  = _i(d['hutang']);
    final piutang = _i(d['piutang']);
    final ageHutang = _i(d['oldest_hutang_days']);

    return RefreshIndicator(color: UColors.primary, onRefresh: _load,
      child: ListView(physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          _SectionLabel('Status Hutang & Piutang'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _FinCard('Hutang Kita', _rp(hutang),
                Icons.arrow_upward_rounded, UColors.danger,
                subtitle: '${_i(d['hutang_count'])} item')),
            const SizedBox(width: 10),
            Expanded(child: _FinCard('Piutang', _rp(piutang),
                Icons.arrow_downward_rounded, UColors.success,
                subtitle: '${_i(d['piutang_count'])} item')),
          ]),
          if (ageHutang > 30) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: UColors.danger.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: UColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'Ada hutang tertua $ageHutang hari — segera diselesaikan!',
                    style: const TextStyle(color: UColors.danger,
                        fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
          const SizedBox(height: 16),

          if (items.isEmpty)
            _Empty('Tidak ada hutang/piutang aktif 🎉')
          else ...[
            _SectionLabel('Detail Hutang & Piutang'),
            const SizedBox(height: 8),
            ...items.map((item) {
              final it = item as Map<String, dynamic>;
              final isHutang = '${it['type']}' == 'HUTANG';
              final age = _i(it['age_days']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isHutang
                      ? UColors.danger.withOpacity(0.15)
                      : UColors.success.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Icon(isHutang ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                      color: isHutang ? UColors.danger : UColors.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it['party']}', style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('$age hari yang lalu  •  ${isHutang ? 'Hutang' : 'Piutang'}',
                        style: TextStyle(fontSize: 11,
                            color: age > 30 ? UColors.danger : UColors.textSoft)),
                  ])),
                  Text(_rp(it['remaining']), style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13,
                      color: isHutang ? UColors.danger : UColors.success)),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  MICRO WIDGETS
// ════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(text, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w800,
        color: UColors.textDark, letterSpacing: 0.2)),
  );
}

class _FinCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final dynamic change;
  final String? subtitle;
  const _FinCard(this.label, this.value, this.icon, this.color,
      {this.change, this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: UShadow.card,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: color,
            fontWeight: FontWeight.w700)),
        if (change != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: (change as double) >= 0
                  ? UColors.successLight : UColors.dangerLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${(change as double) >= 0 ? '↑' : '↓'}${(change as double).abs()}%',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: (change as double) >= 0 ? UColors.success : UColors.danger)),
          ),
        ],
      ]),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
          color: UColors.textDark)),
      if (subtitle != null) Text(subtitle!, style: UText.caption),
    ]),
  );
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
          color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: UColors.textSoft,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _MaterialRow extends StatelessWidget {
  final int rank, nilai;
  final double kg, pct;
  final String name;
  final String Function(dynamic) rp;
  const _MaterialRow({required this.rank, required this.name, required this.kg,
    required this.nilai, required this.pct, required this.rp});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12), boxShadow: UShadow.card),
    child: Row(children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(color: rank <= 3
            ? UColors.primary.withOpacity(0.10) : UColors.surface,
            borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('$rank',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: rank <= 3 ? UColors.primary : UColors.textSoft))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 3),
        ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0),
                minHeight: 5, backgroundColor: UColors.divider,
                valueColor: AlwaysStoppedAnimation(
                    rank == 1 ? UColors.success : UColors.primary.withOpacity(0.6)))),
      ])),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rp(nilai), style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 13, color: UColors.success)),
        Text('${kg.toStringAsFixed(1)} kg', style: UText.caption),
      ]),
    ]),
  );
}

class _StokRow extends StatelessWidget {
  final String name;
  final double kg, pct;
  final int avgCost, totalValue;
  final String Function(dynamic) rp;
  const _StokRow({required this.name, required this.kg, required this.avgCost,
    required this.totalValue, required this.pct, required this.rp});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12), boxShadow: UShadow.card),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 3),
        Text('HPP: ${rp(avgCost)}/kg', style: UText.caption),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0),
                minHeight: 5, backgroundColor: UColors.divider,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00838F)))),
      ])),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rp(totalValue), style: const TextStyle(fontWeight: FontWeight.w900,
            fontSize: 14, color: Color(0xFF00838F))),
        Text('${kg.toStringAsFixed(1)} kg', style: UText.caption),
      ]),
    ]),
  );
}

class _TrendChart extends StatelessWidget {
  final List<dynamic> trend;
  final String Function(dynamic) iRp;
  const _TrendChart({required this.trend, required this.iRp});

  @override
  Widget build(BuildContext context) {
    final vals = trend.map((t) {
      final m = t as Map<String, dynamic>;
      return (double.tryParse('${m['jual'] ?? 0}') ?? 0.0);
    }).toList();
    final maxVal = vals.isEmpty ? 1.0
        : vals.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    final today = DateTime.now().toString().substring(0, 10);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14), boxShadow: UShadow.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trend.asMap().entries.map((e) {
              final t   = e.value as Map<String, dynamic>;
              final val = double.tryParse('${t['jual'] ?? 0}') ?? 0.0;
              final h   = val / maxVal;
              final isToday = '${t['date']}' == today;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200 + e.key * 15),
                  height: (h * 88).clamp(2.0, 88.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isToday
                          ? [UColors.primary, UColors.primaryMid]
                          : val > 0
                          ? [UColors.success.withOpacity(0.9), UColors.success.withOpacity(0.5)]
                          : [UColors.divider, UColors.divider],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ));
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(trend.isNotEmpty ? '${(trend.first as Map)['label']}' : '',
              style: const TextStyle(fontSize: 9, color: UColors.textSoft)),
          const Spacer(),
          Container(width: 8, height: 8, decoration: BoxDecoration(
              color: UColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          const Text('Hari ini', style: TextStyle(fontSize: 9, color: UColors.textSoft)),
          const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: BoxDecoration(
              color: UColors.success.withOpacity(0.7),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          const Text('Ada transaksi', style: TextStyle(fontSize: 9, color: UColors.textSoft)),
          const Spacer(),
          Text(trend.isNotEmpty ? '${(trend.last as Map)['label']}' : '',
              style: const TextStyle(fontSize: 9, color: UColors.textSoft)),
        ]),
      ]),
    );
  }
}

class _EmpStat extends StatelessWidget {
  final String emoji, value, label;
  const _EmpStat(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800,
        fontSize: 14, color: UColors.textDark)),
    Text(label, style: const TextStyle(fontSize: 9, color: UColors.textSoft)),
  ]));
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.inbox_rounded, color: UColors.textLight, size: 40),
        const SizedBox(height: 8),
        Text(msg, style: UText.caption),
      ]),
    ),
  );
}

// ── Month Picker ──────────────────────────
class _MonthPicker extends StatefulWidget {
  final String current;
  final void Function(String) onSelect;
  const _MonthPicker({required this.current, required this.onSelect});
  @override State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late String _selected;
  @override void initState() { super.initState(); _selected = widget.current; }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final months = <String>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i);
      months.add('${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}');
    }
    const mn = ['','Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: UColors.divider,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Pilih Bulan', style: UText.h4),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: months.map((m) {
          final sel = m == _selected;
          final p   = m.split('-');
          return GestureDetector(
            onTap: () { Navigator.pop(context); widget.onSelect(m); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? UColors.primary : UColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel
                    ? UColors.primary : UColors.divider),
              ),
              child: Text('${mn[int.parse(p[1])]} ${p[0]}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : UColors.textDark)),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),
      ]),
    );
  }
}