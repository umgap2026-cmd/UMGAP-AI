import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';
import 'finance_beli_page.dart';
import 'finance_jual_page.dart';
import 'finance_expense_page.dart';
import 'finance_report_page.dart';
import 'finance_stock_page.dart';
import 'finance_debt_page.dart';
import 'finance_trip_page.dart';

// ════════════════════════════════════════════
//  FINANCE HOME — Menu utama kasir
// ════════════════════════════════════════════
class FinanceKasirPage extends StatefulWidget {
  const FinanceKasirPage({super.key});
  @override
  State<FinanceKasirPage> createState() => _FinanceKasirPageState();
}

class _FinanceKasirPageState extends State<FinanceKasirPage> {
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Tampilkan cache dulu (instant)
    final cached = await CacheService.get(CacheService.kKasirSummary);
    if (cached != null && mounted) {
      setState(() { _summary = cached['summary'] ?? cached; _loading = false; });
    }
    // Fetch API di background
    try {
      final res = await ApiService.financeReportDaily();
      if (!mounted) return;
      await CacheService.set(CacheService.kKasirSummary, res);
      setState(() { _summary = res['summary'] ?? {}; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    int _i(dynamic v) => v == null ? 0 : (double.tryParse('$v') ?? 0).toInt();
    final omzet  = _i(_summary['omzet_jual']);
    final keluar = _i(_summary['pengeluaran']);
    final laba   = _i(_summary['laba_kotor']);
    final stok   = _i(_summary['nilai_stok']);

    return Scaffold(
      backgroundColor: UColors.surface,
      body: RefreshIndicator(
        color:     UColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),

            // ── Ringkasan hari ini ─────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.base, USpace.base, 0),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(
                  color: UColors.primary))
                  : _buildSummaryCard(omzet, keluar, laba, stok),
            ),

            // ── 3 Tombol Utama ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.lg, USpace.base, 0),
              child: Text('Transaksi', style: UText.h4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.md, USpace.base, 0),
              child: Row(children: [
                Expanded(child: _BigActionBtn(
                  icon:    Icons.arrow_downward_rounded,
                  label:   'Orang\nJual',
                  color:   UColors.success,
                  onTap:   () => _go(const FinanceBeliPage()),
                )),
                const SizedBox(width: USpace.md),
                Expanded(child: _BigActionBtn(
                  icon:    Icons.arrow_upward_rounded,
                  label:   'Orang\nBeli',
                  color:   UColors.primary,
                  onTap:   () => _go(const FinanceJualPage()),
                )),
                const SizedBox(width: USpace.md),
                Expanded(child: _BigActionBtn(
                  icon:    Icons.remove_circle_outline_rounded,
                  label:   'Keluar\nUang',
                  color:   UColors.warning,
                  onTap:   () => _go(const FinanceExpensePage()),
                )),
              ]),
            ),

            // ── Menu lainnya ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.xl, USpace.base, 0),
              child: Text('Lainnya', style: UText.h4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  USpace.base, USpace.md, USpace.base, 40),
              child: Column(children: [
                _MenuTile(
                  icon:    Icons.bar_chart_rounded,
                  color:   UColors.primary,
                  label:   'Laporan Keuangan',
                  sub:     'Harian & mingguan',
                  onTap:   () => _go(const FinanceReportPage()),
                ),
                const SizedBox(height: USpace.sm),
                _MenuTile(
                  icon:    Icons.inventory_2_rounded,
                  color:   const Color(0xFF00838F),
                  label:   'Stok Gudang',
                  sub:     'Lihat & riwayat stok',
                  onTap:   () => _go(const FinanceStockPage()),
                ),
                const SizedBox(height: USpace.sm),
                _MenuTile(
                  icon:    Icons.local_shipping_rounded,
                  color:   UColors.primaryDark,
                  label:   'Perjalanan Retail',
                  sub:     'Catat jual, beli & biaya trip',
                  onTap:   () => _go(const FinanceTripPage()),
                ),
                const SizedBox(height: USpace.sm),
                _MenuTile(
                  icon:    Icons.account_balance_rounded,
                  color:   UColors.warning,
                  label:   'Hutang & Piutang',
                  sub:     'Catat & tandai lunas',
                  onTap:   () => _go(const FinanceDebtPage()),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _go(Widget page) {
    HapticFeedback.mediumImpact();
    Navigator.push(context, uRoute(page)).then((_) => _load());
  }

  Widget _buildHeader() {
    return UHeader(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            USpace.base, USpace.sm, USpace.base, USpace.xl),
        child: Column(children: [
          Row(children: [
            UBackButton(),
            const SizedBox(width: USpace.md),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kasir & Keuangan', style: TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('UMGAP Finance', style: TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w500)),
              ],
            )),
            // Tanggal hari ini
            UGlassPill(
              icon:  Icons.calendar_today_rounded,
              label: _todayStr(),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSummaryCard(int omzet, int keluar, int laba, int stok) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UColors.navy, UColors.navyMid, Color(0xFF1A3A7A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(URadius.xl),
        boxShadow: UShadow.lg(UColors.primary),
      ),
      padding: const EdgeInsets.all(USpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.today_rounded, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text('Hari Ini — ${_todayStr()}',
              style: const TextStyle(color: Colors.white54,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: USpace.base),

        // Pemasukan & Pengeluaran
        Row(children: [
          Expanded(child: _SummaryItem(
            label: 'Pemasukan',
            value: uRupiah(omzet),
            color: UColors.success,
            icon:  Icons.arrow_downward_rounded,
          )),
          Container(width: 1, height: 50,
              color: Colors.white.withOpacity(0.10)),
          Expanded(child: _SummaryItem(
            label: 'Pengeluaran',
            value: uRupiah(keluar),
            color: const Color(0xFFEF9A9A),
            icon:  Icons.arrow_upward_rounded,
          )),
        ]),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: USpace.md),
          child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0),
              ]))),
        ),

        // Laba hari ini
        Row(children: [
          const Icon(Icons.trending_up_rounded,
              color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          const Text('Laba Kotor Hari Ini',
              style: TextStyle(color: Colors.white60,
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(uRupiah(laba), style: TextStyle(
            color: laba >= 0 ? UColors.success : const Color(0xFFEF9A9A),
            fontSize: 16, fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
        ]),

        const SizedBox(height: USpace.sm),

        // Nilai stok gudang
        Row(children: [
          const Icon(Icons.inventory_2_rounded,
              color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          const Text('Nilai Stok Gudang',
              style: TextStyle(color: Colors.white60,
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(uRupiah(stok), style: const TextStyle(
            color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          )),
        ]),
      ]),
    );
  }

  String _todayStr() {
    final n = DateTime.now();
    const m = ['','Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'];
    return '${n.day} ${m[n.month]} ${n.year}';
  }
}

// ════════════════════════════════════════════
//  BIG ACTION BUTTON
// ════════════════════════════════════════════
class _BigActionBtn extends StatefulWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _BigActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});
  @override State<_BigActionBtn> createState() => _BigActionBtnState();
}

class _BigActionBtnState extends State<_BigActionBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale:    _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.color.withOpacity(0.85), widget.color],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(URadius.lg),
          boxShadow: UShadow.md(widget.color),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: USpace.sm),
          Text(widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w800,
                  height: 1.3)),
        ]),
      ),
    ),
  );
}

// ════════════════════════════════════════════
//  MENU TILE
// ════════════════════════════════════════════
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, sub;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.color,
    required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.card,
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(URadius.sm),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: USpace.md),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: UText.h5),
          const SizedBox(height: 2),
          Text(sub, style: UText.caption),
        ])),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: color.withOpacity(0.4)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════
//  SUMMARY ITEM
// ════════════════════════════════════════════
class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color  color;
  final IconData icon;
  const _SummaryItem({required this.label, required this.value,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900,
          fontFeatures: [FontFeature.tabularFigures()])),
    ],
  );
}