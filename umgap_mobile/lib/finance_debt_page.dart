import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

class FinanceDebtPage extends StatefulWidget {
  const FinanceDebtPage({super.key});
  @override State<FinanceDebtPage> createState() => _FinanceDebtPageState();
}

class _FinanceDebtPageState extends State<FinanceDebtPage> {
  bool  _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeGetDebts();
      if (!mounted) return;
      setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _bayar(Map<String, dynamic> debt) async {
    final ctrl = TextEditingController(
        text: '${int.tryParse('${debt["remaining"] ?? 0}') ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: Text('Bayar ${debt['type'] == 'HUTANG' ? 'Hutang' : 'Terima Piutang'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${debt['party_name']}', style: UText.h5),
          const SizedBox(height: 4),
          Text('Sisa: ${uRupiah(int.tryParse('${debt["remaining"] ?? 0}') ?? 0)}', style: UText.bodyS),
          const SizedBox(height: USpace.base),
          TextField(controller: ctrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Jumlah dibayar',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  filled: true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financePayDebt(debtId: int.tryParse('${debt["id"]}') ?? 0,
          amount: double.tryParse(ctrl.text) ?? 0);
      if (mounted) { uSnack(context, 'Berhasil dicatat ✓'); _load(); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hutang       = List<dynamic>.from(_data['hutang']        ?? []);
    final piutang      = List<dynamic>.from(_data['piutang']       ?? []);
    final totalHutang  = (_data['total_hutang']  as num?)?.toInt() ?? 0;
    final totalPiutang = int.tryParse('${_data["total_piutang"] ?? 0}') ?? 0;

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            const Expanded(child: Text('Hutang & Piutang',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else Expanded(child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
          children: [
            Row(children: [
              Expanded(child: _DebtSummary(label: 'Total Hutang',
                  value: uRupiah(totalHutang), color: UColors.danger)),
              const SizedBox(width: USpace.md),
              Expanded(child: _DebtSummary(label: 'Total Piutang',
                  value: uRupiah(totalPiutang), color: UColors.success)),
            ]),
            const SizedBox(height: USpace.lg),
            if (hutang.isNotEmpty) ...[
              USectionHeader(title: 'Hutang Kita'),
              const SizedBox(height: USpace.sm),
              ...hutang.map((d) => _DebtCard(debt: d as Map<String, dynamic>,
                  color: UColors.danger, onBayar: () => _bayar(d))),
              const SizedBox(height: USpace.lg),
            ],
            if (piutang.isNotEmpty) ...[
              USectionHeader(title: 'Piutang (Orang Hutang ke Kita)'),
              const SizedBox(height: USpace.sm),
              ...piutang.map((d) => _DebtCard(debt: d as Map<String, dynamic>,
                  color: UColors.success, onBayar: () => _bayar(d))),
            ],
            if (hutang.isEmpty && piutang.isEmpty)
              UEmptyState(icon: Icons.account_balance_rounded,
                  title: 'Tidak ada hutang/piutang', subtitle: 'Semua sudah lunas 🎉'),
          ],
        )),
      ]),
    );
  }
}

class _DebtSummary extends StatelessWidget {
  final String label, value; final Color color;
  const _DebtSummary({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(USpace.base),
    decoration: BoxDecoration(color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: UText.caption),
      const SizedBox(height: 4),
      Text(value, style: UText.h5.copyWith(color: color)),
    ]),
  );
}

class _DebtCard extends StatelessWidget {
  final Map<String, dynamic> debt; final Color color; final VoidCallback onBayar;
  const _DebtCard({required this.debt, required this.color, required this.onBayar});
  @override
  Widget build(BuildContext context) {
    final remaining = int.tryParse('${debt["remaining"] ?? 0}') ?? 0;
    final amount    = (debt['amount']    as num?)?.toInt() ?? 0;
    final pct       = amount > 0 ? 1 - (remaining / amount) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${debt['party_name']}', style: UText.h5)),
          GestureDetector(onTap: onBayar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: 6),
              decoration: BoxDecoration(color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(URadius.full),
                  border: Border.all(color: color.withOpacity(0.3))),
              child: Text('Bayar', style: TextStyle(color: color,
                  fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('Sisa: ', style: UText.bodyS),
          Text(uRupiah(remaining), style: UText.bodyS.copyWith(
              color: color, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('dari ${uRupiah(amount)}', style: UText.caption),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0),
                minHeight: 6, backgroundColor: color.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(color))),
        if (debt['note'] != null && '${debt['note']}'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${debt['note']}', style: UText.caption,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}