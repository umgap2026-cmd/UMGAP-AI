import 'package:flutter/material.dart';
import 'api_service.dart';
import 'nota_detail_page.dart';
import 'u_kit.dart';

class FinanceHppDiagnosticsPage extends StatefulWidget {
  const FinanceHppDiagnosticsPage({super.key});
  @override
  State<FinanceHppDiagnosticsPage> createState() => _FinanceHppDiagnosticsPageState();
}

class _FinanceHppDiagnosticsPageState extends State<FinanceHppDiagnosticsPage> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeHppDiagnostics();
      if (!mounted) return;
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOrphan = uInt(_data['total_orphan']);
    final rows = List<dynamic>.from(_data['rows'] ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🔍 Diagnostik HPP', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Cek penjualan tanpa catatan biaya di titik waktunya',
                  style: TextStyle(color: Colors.white.withOpacity(0.75),
                      fontSize: 11.5, fontWeight: FontWeight.w500)),
            ])),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else
          Expanded(child: RefreshIndicator(color: UColors.primary, onRefresh: _load,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
              children: [
                _HeroCard(totalOrphan: totalOrphan),
                if (totalOrphan > 0) ...[
                  const SizedBox(height: USpace.lg),
                  USectionHeader(title: 'Transaksi Terdampak'),
                  const SizedBox(height: USpace.sm),
                  ...rows.map((r) => _OrphanCard(row: r)),
                ],
              ],
            ),
          )),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int totalOrphan;
  const _HeroCard({required this.totalOrphan});

  @override
  Widget build(BuildContext context) {
    final healthy = totalOrphan == 0;
    final color = healthy ? UColors.success : UColors.danger;
    final bg = healthy ? UColors.successLight : UColors.dangerLight;
    return Container(
      padding: const EdgeInsets.all(USpace.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.card,
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(healthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: color, size: 26),
          const SizedBox(width: USpace.sm),
          Expanded(child: Text(
              healthy
                  ? '✓ Semua penjualan punya catatan biaya (HPP) akurat'
                  : 'Ditemukan transaksi dengan HPP tidak akurat',
              style: UText.h5.copyWith(color: color))),
        ]),
        const SizedBox(height: USpace.md),
        Text('$totalOrphan transaksi',
            style: UText.h1.copyWith(color: color, fontSize: 34)),
        if (!healthy) ...[
          const SizedBox(height: USpace.sm),
          Text(
            'Transaksi ini pakai HPP rata-rata SAAT INI (bukan saat transaksi dibuat) -- bisa bikin laporan HPP historis meleset.',
            style: UText.bodyS.copyWith(color: color.withOpacity(0.9)),
          ),
        ],
      ]),
    );
  }
}

class _OrphanCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _OrphanCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final txnId = (row['transaction_id'] as num?)?.toInt();
    final materialName = '${row['material_name'] ?? '-'}';
    final partyName = '${row['party_name'] ?? '-'}';
    final unit = '${row['unit'] ?? 'kg'}';
    final qty = row['qty_kg'];
    final pricePerKg = row['price_per_kg'];
    final estHpp = row['estimated_hpp_now'];
    final dateWib = '${row['created_at_wib'] ?? ''}';

    final card = Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$materialName · $partyName', style: UText.h5)),
          if (txnId != null)
            Icon(Icons.chevron_right_rounded, color: UColors.textLight, size: 18),
        ]),
        if (dateWib.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(dateWib, style: UText.caption),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MiniStat('Qty', '$qty $unit')),
          Expanded(child: _MiniStat('Harga/kg', uRupiah(pricePerKg))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: USpace.sm),
          decoration: BoxDecoration(
            color: UColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(URadius.sm),
          ),
          child: Row(children: [
            const Icon(Icons.calculate_outlined, color: UColors.danger, size: 15),
            const SizedBox(width: 6),
            Text('Est. HPP Sekarang: ', style: UText.bodyS.copyWith(color: UColors.danger)),
            Text(uRupiah(estHpp), style: UText.bodyS.copyWith(
                color: UColors.danger, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );

    if (txnId != null) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => NotaDetailPage(txnId: txnId))),
        child: card,
      );
    }
    return card;
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: UColors.textLight)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w700, color: UColors.textDark)),
  ]);
}
