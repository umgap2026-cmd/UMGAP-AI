import 'package:flutter/material.dart';
import 'api_service.dart';
import 'u_kit.dart';

class FinanceCustomerProfitabilityPage extends StatefulWidget {
  const FinanceCustomerProfitabilityPage({super.key});
  @override
  State<FinanceCustomerProfitabilityPage> createState() => _FinanceCustomerProfitabilityPageState();
}

class _FinanceCustomerProfitabilityPageState extends State<FinanceCustomerProfitabilityPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeCustomerProfitability(
          from: _fmt(_from), to: _fmt(_to));
      if (!mounted) return;
      setState(() {
        _rows = List<dynamic>.from(res).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: _to,
    );
    if (picked != null) {
      setState(() => _from = picked);
      _load();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _to = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            const Expanded(child: Text('🏆 Pelanggan Menguntungkan', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, 0),
          child: Row(children: [
            Expanded(child: _DateBtn(label: 'Dari', value: _fmtDisplay(_from), onTap: _pickFrom)),
            const SizedBox(width: USpace.md),
            Expanded(child: _DateBtn(label: 'Sampai', value: _fmtDisplay(_to), onTap: _pickTo)),
          ]),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else
          Expanded(child: RefreshIndicator(color: UColors.primary, onRefresh: _load,
            child: _rows.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                    const UEmptyState(
                      icon: Icons.emoji_events_rounded,
                      title: 'Belum ada data pelanggan di rentang ini',
                    ),
                  ])
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
                    children: [
                      _ChampionCard(customer: _rows.first),
                      const SizedBox(height: USpace.lg),
                      USectionHeader(title: 'Peringkat Semua Pelanggan'),
                      const SizedBox(height: USpace.sm),
                      for (var i = 0; i < _rows.length; i++)
                        _CustomerCard(rank: i + 1, customer: _rows[i]),
                    ],
                  ),
          )),
      ]),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateBtn({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: USpace.sm),
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.md),
        boxShadow: UShadow.card,
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, color: UColors.primary, size: 14),
        const SizedBox(width: USpace.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: UColors.textLight)),
          Text(value, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: UColors.textDark)),
        ])),
      ]),
    ),
  );
}

class _ChampionCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  const _ChampionCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = '${customer['party_name'] ?? '-'}';
    final keuntungan = customer['keuntungan'];
    final jumlahTxn = uInt(customer['jumlah_transaksi']);
    return Container(
      padding: const EdgeInsets.all(USpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFFF9A825)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.lg(UColors.success),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: USpace.sm),
          Expanded(child: Text('Pelanggan Paling Menguntungkan', style: TextStyle(
              color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: USpace.sm),
        Text(name, style: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: USpace.sm),
        Text(uRupiah(keuntungan), style: const TextStyle(
            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('$jumlahTxn transaksi', style: TextStyle(
            color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> customer;
  const _CustomerCard({required this.rank, required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = '${customer['party_name'] ?? '-'}';
    final jumlahTxn = uInt(customer['jumlah_transaksi']);
    final omzet = customer['omzet'];
    final hpp = customer['hpp'];
    final keuntungan = customer['keuntungan'];
    final pct = (customer['keuntungan_pct'] as num?)?.toDouble() ?? 0.0;
    final negative = pct < 0;
    final accent = negative ? UColors.danger : UColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(width: 4, color: accent),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(USpace.base),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: UColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Text('#$rank', style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: UColors.primary)),
              ),
              const SizedBox(width: USpace.sm),
              Expanded(child: Text(name, style: UText.h5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(URadius.full),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Text('${pct.toStringAsFixed(1)}%', style: TextStyle(
                    color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('$jumlahTxn transaksi', style: UText.caption),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _MiniStat('Omzet', uRupiah(omzet))),
              Expanded(child: _MiniStat('HPP', uRupiah(hpp))),
              Expanded(child: _MiniStat('Untung', uRupiah(keuntungan), color: accent, bold: true)),
            ]),
          ]),
        )),
      ])),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold;
  const _MiniStat(this.label, this.value, {this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: UColors.textLight)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(fontSize: 12,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        color: color ?? UColors.textDark)),
  ]);
}
