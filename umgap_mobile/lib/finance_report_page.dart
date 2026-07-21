import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

class FinanceReportPage extends StatefulWidget {
  const FinanceReportPage({super.key});
  @override State<FinanceReportPage> createState() => _FinanceReportPageState();
}

class _FinanceReportPageState extends State<FinanceReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool  _loading  = false;
  DateTime _weekStart = DateTime.now();
  Map<String, dynamic> _daily  = {};
  Map<String, dynamic> _weekly = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadDaily(); _loadWeekly();
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadDaily() async {
    // Cache dulu
    final cached = await CacheService.get(CacheService.kReportDaily);
    if (cached != null && mounted) {
      setState(() { _daily = cached; _loading = false; });
    } else {
      setState(() => _loading = true);
    }
    // Background refresh
    try {
      final res = await ApiService.financeReportDaily();
      if (!mounted) return;
      await CacheService.set(CacheService.kReportDaily, res);
      setState(() { _daily = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadWeekly() async {
    final weekStr = '${_weekStart.year}-${_weekStart.month.toString().padLeft(2,'0')}-${_weekStart.day.toString().padLeft(2,'0')}';
    final cacheKey = CacheService.kReportWeekly(weekStr);
    // Cache dulu
    final cached = await CacheService.get(cacheKey);
    if (cached != null && mounted) setState(() => _weekly = cached);
    // Background refresh
    try {
      final res = await ApiService.financeReportWeekly(week: weekStr);
      if (!mounted) return;
      await CacheService.set(cacheKey, res);
      setState(() => _weekly = res);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, 0),
              child: Row(children: [
                UBackButton(), const SizedBox(width: USpace.md),
                const Text('Laporan Keuangan', style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
            TabBar(
                controller: _tab,
                indicatorColor: UColors.cyan,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: const [Tab(text: 'Hari Ini'), Tab(text: 'Mingguan')]),
            const SizedBox(height: 4),
          ]),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : TabBarView(controller: _tab, children: [
          _buildDaily(),
          _buildWeekly(),
        ])),
      ]),
    );
  }

  Widget _buildDaily() {
    final s    = (_daily['summary'] ?? {}) as Map<String, dynamic>;
    final txns = List<dynamic>.from(_daily['transactions'] ?? []);
    int _i(dynamic v) => v == null ? 0 : (double.tryParse('$v') ?? 0).toInt();
    final omzet      = _i(s['omzet_jual']);
    final keluar     = _i(s['pengeluaran']);
    final hpp        = _i(s['hpp']);
    final laba       = _i(s['laba_kotor']);
    final stok       = _i(s['nilai_stok']);
    final tripJual   = _i(s['trip_jual']);
    final tripBeli   = _i(s['trip_beli']);
    final tripExpense= _i(s['trip_expense']);

    return RefreshIndicator(color: UColors.primary, onRefresh: _loadDaily,
      child: ListView(physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
        children: [
          _ReportCard(rows: [
            _ReportRow('Omzet Penjualan', uRupiah(omzet), UColors.primary),
            _ReportRow('HPP Barang',      uRupiah(hpp),   UColors.textSoft),
            _ReportRow('Pengeluaran',     uRupiah(keluar),UColors.warning),
          ], total: _ReportRow('Laba Kotor', uRupiah(laba),
              laba >= 0 ? UColors.success : UColors.danger)),
          const SizedBox(height: USpace.md),
          _ReportCard(rows: [
            _ReportRow('Nilai Stok Gudang', uRupiah(stok), const Color(0xFF00838F)),
          ], total: null),
          if (tripJual > 0 || tripBeli > 0 || tripExpense > 0) ...[
            const SizedBox(height: USpace.md),
            Container(
              decoration: BoxDecoration(
                color: UColors.card,
                borderRadius: BorderRadius.circular(URadius.lg),
                boxShadow: UShadow.card,
                border: Border.all(color: UColors.primary.withOpacity(0.15)),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, 0),
                  child: Row(children: [
                    const Icon(Icons.local_shipping_rounded,
                        color: UColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text('Perjalanan Jakarta',
                        style: UText.bodyS.copyWith(
                            color: UColors.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (tripJual > 0) Padding(
                  padding: const EdgeInsets.fromLTRB(USpace.base, USpace.sm, USpace.base, 0),
                  child: Row(children: [
                    Text('Penjualan di Jakarta', style: UText.bodyS),
                    const Spacer(),
                    Text(uRupiah(tripJual), style: UText.bodyS.copyWith(
                        color: UColors.success, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (tripBeli > 0) Padding(
                  padding: const EdgeInsets.fromLTRB(USpace.base, USpace.sm, USpace.base, 0),
                  child: Row(children: [
                    Text('Pembelian di Jakarta', style: UText.bodyS),
                    const Spacer(),
                    Text(uRupiah(tripBeli), style: UText.bodyS.copyWith(
                        color: UColors.textSoft, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (tripExpense > 0) Padding(
                  padding: const EdgeInsets.fromLTRB(USpace.base, USpace.sm, USpace.base, 0),
                  child: Row(children: [
                    Text('Biaya Perjalanan', style: UText.bodyS),
                    const Spacer(),
                    Text(uRupiah(tripExpense), style: UText.bodyS.copyWith(
                        color: UColors.warning, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: USpace.base),
              ]),
            ),
          ],
          const SizedBox(height: USpace.lg),
          if (txns.isNotEmpty) ...[
            USectionHeader(title: 'Transaksi Hari Ini'),
            const SizedBox(height: USpace.sm),
            ...txns.map((t) => _TxnCard(txn: t as Map<String, dynamic>)),
          ] else
            UEmptyState(icon: Icons.receipt_long_rounded,
                title: 'Belum ada transaksi hari ini',
                subtitle: 'Mulai catat dari menu Kasir'),
        ],
      ),
    );
  }

  Widget _buildWeekly() {
    final s     = (_weekly['summary'] ?? {}) as Map<String, dynamic>;
    final label = '${_weekly['week_label'] ?? ''}';
    int _i(dynamic v) => v == null ? 0 : (double.tryParse('$v') ?? 0).toInt();
    final omzet = _i(s['omzet_jual']);
    final modal = _i(s['modal_beli']);
    final hpp   = _i(s['hpp']);
    final biaya = _i(s['biaya_ops']);
    final laba  = _i(s['laba_bersih']);

    return ListView(physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(onTap: () {
            setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
            _loadWeekly();
          }, child: const Icon(Icons.chevron_left_rounded, color: UColors.primary, size: 28)),
          const SizedBox(width: USpace.base),
          Text(label, style: UText.h5),
          const SizedBox(width: USpace.base),
          GestureDetector(onTap: () {
            final next = _weekStart.add(const Duration(days: 7));
            if (!next.isAfter(DateTime.now())) {
              setState(() => _weekStart = next);
              _loadWeekly();
            }
          }, child: Icon(Icons.chevron_right_rounded,
              color: _weekStart.add(const Duration(days: 7)).isAfter(DateTime.now())
                  ? UColors.textLight : UColors.primary, size: 28)),
        ]),
        const SizedBox(height: USpace.base),
        _ReportCard(rows: [
          _ReportRow('Omzet Penjualan',    uRupiah(omzet), UColors.primary),
          _ReportRow('Modal Beli',         uRupiah(modal), UColors.textSoft),
          _ReportRow('HPP Terjual',        uRupiah(hpp),   UColors.textSoft),
          _ReportRow('Biaya Operasional',  uRupiah(biaya), UColors.warning),
        ], total: _ReportRow('Laba Bersih', uRupiah(laba),
            laba >= 0 ? UColors.success : UColors.danger)),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────
class _ReportRow {
  final String label, value; final Color color;
  _ReportRow(this.label, this.value, this.color);
}

class _ReportCard extends StatelessWidget {
  final List<_ReportRow> rows; final _ReportRow? total;
  const _ReportCard({required this.rows, required this.total});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
    child: Column(children: [
      ...rows.map((r) => Padding(
        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, 0),
        child: Row(children: [
          Text(r.label, style: UText.bodyS), const Spacer(),
          Text(r.value, style: UText.bodyS.copyWith(
              color: r.color, fontWeight: FontWeight.w700)),
        ]),
      )),
      if (total != null) ...[
        Padding(padding: const EdgeInsets.symmetric(
            horizontal: USpace.base, vertical: USpace.md),
            child: Divider(color: UColors.divider)),
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.base, 0, USpace.base, USpace.base),
          child: Row(children: [
            Text(total!.label, style: UText.h5), const Spacer(),
            Text(total!.value, style: UText.h4.copyWith(color: total!.color)),
          ]),
        ),
      ] else const SizedBox(height: USpace.base),
    ]),
  );
}

class _TxnCard extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _TxnCard({required this.txn});

  Color get _color {
    switch ('${txn['type']}') {
      case 'BELI_GUDANG':       return UColors.success;
      case 'JUAL_GUDANG':       return UColors.primary;
      case 'PENGELUARAN':       return UColors.warning;
      case 'JUAL_TRIP':         return UColors.primary;
      case 'BELI_TRIP':         return UColors.success;
      case 'PENGELUARAN_TRIP':  return UColors.warning;
      case 'RETURN_TRIP':       return UColors.purple;
      default:                  return UColors.textSoft;
    }
  }

  String get _label {
    switch ('${txn['type']}') {
      case 'BELI_GUDANG':       return 'Beli dari orang';
      case 'JUAL_GUDANG':       return 'Jual ke orang';
      case 'PENGELUARAN':       return 'Pengeluaran';
      case 'JUAL_TRIP':         return '🚛 Jual di Jakarta';
      case 'BELI_TRIP':         return '🚛 Beli di Jakarta';
      case 'PENGELUARAN_TRIP':  return '🚛 Biaya Perjalanan';
      case 'RETURN_TRIP':       return '🚛 Balikan Barang';
      default:                  return '${txn['type']}';
    }
  }

  bool get _isTrip => '${txn['type']}'.endsWith('_TRIP');

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: USpace.sm),
    padding: const EdgeInsets.all(USpace.md),
    decoration: BoxDecoration(color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
    child: Row(children: [
      Container(width: 4, height: 44, color: _color,
          margin: const EdgeInsets.only(right: USpace.md)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_label, style: UText.h5.copyWith(fontSize: 13)),
          if (_isTrip) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: UColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('TRIP', style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: UColors.primary)),
            ),
          ],
        ]),
        if ((txn['party_name'] ?? txn['note'] ?? '').toString().isNotEmpty)
          Text('${txn['party_name'] ?? txn['note'] ?? ''}',
              style: UText.caption, maxLines: 1,
              overflow: TextOverflow.ellipsis),
      ])),
      Text(uRupiah((double.tryParse('${txn['total_amount'] ?? 0}') ?? 0).toInt()),
          style: UText.bodyS.copyWith(color: _color, fontWeight: FontWeight.w800)),
    ]),
  );
}