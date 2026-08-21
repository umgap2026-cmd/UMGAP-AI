import 'package:flutter/material.dart';
import 'api_service.dart';
import 'u_kit.dart';

class FinanceShrinkageReportPage extends StatefulWidget {
  const FinanceShrinkageReportPage({super.key});
  @override State<FinanceShrinkageReportPage> createState() => _FinanceShrinkageReportPageState();
}

class _FinanceShrinkageReportPageState extends State<FinanceShrinkageReportPage> {
  bool _loading = true;
  late DateTime _from;
  late DateTime _to;
  List<dynamic> _rows = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to   = DateTime(now.year, now.month, now.day);
    _load();
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _disp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeShrinkageReport(from: _iso(_from), to: _iso(_to));
      if (!mounted) return;
      setState(() { _rows = res; _loading = false; });
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
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
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
      firstDate: DateTime(2024),
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
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.base),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            const Expanded(child: Text('📉 Laporan Susut',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 0),
          child: Row(children: [
            Expanded(child: _DateChip(label: 'Dari', value: _disp(_from), onTap: _pickFrom)),
            const SizedBox(width: USpace.sm),
            Expanded(child: _DateChip(label: 'Sampai', value: _disp(_to), onTap: _pickTo)),
          ]),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : RefreshIndicator(color: UColors.primary, onRefresh: _load,
                child: _rows.isEmpty
                    ? ListView(physics: const BouncingScrollPhysics(), children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                        UEmptyState(icon: Icons.trending_down_rounded,
                            title: 'Belum ada data stok di rentang ini'),
                      ])
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
                        children: _rows.map((r) => _ShrinkageCard(row: r as Map<String, dynamic>)).toList(),
                      ),
              )),
      ]),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: USpace.sm),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.md), boxShadow: UShadow.card),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, size: 14, color: UColors.primary),
        const SizedBox(width: USpace.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: UText.caption),
          Text(value, style: UText.h5.copyWith(fontSize: 13)),
        ])),
      ]),
    ),
  );
}

class _ShrinkageCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ShrinkageCard({required this.row});

  String _fmtQty(dynamic v) {
    final n = double.tryParse('$v') ?? 0;
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final name  = '${row['name'] ?? '-'}';
    final unit  = '${row['unit'] ?? ''}';
    final totalIn  = row['total_in'];
    final totalOut = row['total_out'];
    final totalSusut = row['total_susut'];
    final susutPct = double.tryParse('${row['susut_pct'] ?? 0}') ?? 0;

    final Color color = susutPct > 5
        ? UColors.danger
        : (susutPct > 0 ? UColors.amber : UColors.success);

    return Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 34, color: color,
              margin: const EdgeInsets.only(right: USpace.md)),
          Expanded(child: Text(name, style: UText.h5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(URadius.full),
                border: Border.all(color: color.withOpacity(0.3))),
            child: Text('${susutPct.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: USpace.md),
        Row(children: [
          Expanded(child: _MiniStat('Masuk', '${_fmtQty(totalIn)} $unit')),
          Expanded(child: _MiniStat('Keluar', '${_fmtQty(totalOut)} $unit')),
          Expanded(child: _MiniStat('Susut', '${_fmtQty(totalSusut)} $unit', color: color, bold: true)),
        ]),
      ]),
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
