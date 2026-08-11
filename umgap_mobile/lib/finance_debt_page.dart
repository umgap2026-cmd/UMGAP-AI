import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
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
    final ctrl = TextEditingController(text: '${uInt(debt["remaining"])}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: Text('Bayar ${debt['type'] == 'HUTANG' ? 'Hutang' : 'Terima Piutang'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${debt['party_name']}', style: UText.h5),
          const SizedBox(height: 4),
          Text('Sisa: ${uRupiah(debt["remaining"])}', style: UText.bodyS),
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

  Future<void> _addDebt(String type) async {
    final nameCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl   = TextEditingController();
    String reason = 'HUTANG_BARANG';
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final isHutang = type == 'HUTANG';
        return Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              Text(isHutang ? '+ Tambah Hutang' : '+ Tambah Piutang',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                      labelText: isHutang ? 'Nama Pemasok *' : 'Nama Pelanggan *',
                      prefixIcon: const Icon(Icons.person_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      labelText: 'Jumlah (Rp) *',
                      prefixIcon: const Icon(Icons.payments_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              const Text('Alasan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: UColors.textMid)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => reason = 'HUTANG_BARANG'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: reason == 'HUTANG_BARANG' ? UColors.primary : UColors.inputBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('📦 Hutang Barang', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: reason == 'HUTANG_BARANG' ? Colors.white : UColors.textMid))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => reason = 'TITIP_DANA'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: reason == 'TITIP_DANA' ? UColors.primary : UColors.inputBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('💰 Titip Dana', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: reason == 'TITIP_DANA' ? Colors.white : UColors.textMid))),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl,
                  decoration: InputDecoration(
                      labelText: 'Catatan (opsional)',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final name = nameCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (name.isEmpty) { uSnack(context, 'Nama wajib diisi', isError: true); return; }
                    if (amount <= 0) { uSnack(context, 'Jumlah harus lebih dari 0', isError: true); return; }
                    setS(() => saving = true);
                    try {
                      await ApiService.financeAddDebt(
                        type: type, partyName: name, amount: amount,
                        note: noteCtrl.text.trim(), reason: reason,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) { uSnack(context, 'Berhasil dicatat ✓'); _load(); }
                    } catch (e) {
                      if (mounted) uSnack(context, e.toString(), isError: true);
                      setS(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _pickAddType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.arrow_upward_rounded, color: UColors.danger),
            title: const Text('Tambah Hutang (ke Pemasok)'),
            onTap: () => Navigator.pop(ctx, 'HUTANG'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward_rounded, color: UColors.success),
            title: const Text('Tambah Piutang (dari Pelanggan)'),
            onTap: () => Navigator.pop(ctx, 'PIUTANG'),
          ),
        ]),
      ),
    );
    if (type != null) _addDebt(type);
  }

  Future<void> _editDebt(Map<String, dynamic> debt) async {
    final nameCtrl   = TextEditingController(text: '${debt['party_name'] ?? ''}');
    final amountCtrl = TextEditingController(text: '${(debt['amount'] as num?)?.toInt() ?? 0}');
    final noteCtrl   = TextEditingController(text: '${debt['note'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Edit Data'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jumlah Total (Rp)')),
          const SizedBox(height: 10),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeEditDebt(
        debtId: int.tryParse('${debt["id"]}') ?? 0,
        partyName: nameCtrl.text.trim(),
        amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
        note: noteCtrl.text.trim(),
      );
      if (mounted) { uSnack(context, 'Berhasil diubah ✓'); _load(); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _deleteDebt(Map<String, dynamic> debt) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Hapus data ini?'),
        content: Text('${debt['party_name']} — ${uRupiah((debt['remaining'] as num?)?.toInt() ?? 0)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeDeleteDebt(int.tryParse('${debt["id"]}') ?? 0);
      if (mounted) { uSnack(context, 'Berhasil dihapus ✓'); _load(); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hutang       = List<dynamic>.from(_data['hutang']        ?? []);
    final piutang      = List<dynamic>.from(_data['piutang']       ?? []);
    final totalHutang  = uInt(_data['total_hutang']);
    final totalPiutang = uInt(_data['total_piutang']);

    return Scaffold(
      backgroundColor: UColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAddType,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
      ),
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
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 100),
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
                  color: UColors.danger, onBayar: () => _bayar(d),
                  onEdit: () => _editDebt(d), onDelete: () => _deleteDebt(d))),
              const SizedBox(height: USpace.lg),
            ],
            if (piutang.isNotEmpty) ...[
              USectionHeader(title: 'Piutang (Orang Hutang ke Kita)'),
              const SizedBox(height: USpace.sm),
              ...piutang.map((d) => _DebtCard(debt: d as Map<String, dynamic>,
                  color: UColors.success, onBayar: () => _bayar(d),
                  onEdit: () => _editDebt(d), onDelete: () => _deleteDebt(d))),
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
  final Map<String, dynamic> debt; final Color color;
  final VoidCallback onBayar, onEdit, onDelete;
  const _DebtCard({required this.debt, required this.color,
      required this.onBayar, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final remaining = uInt(debt['remaining']);
    final amount    = (debt['amount']    as num?)?.toInt() ?? 0;
    final paid      = (debt['paid_amount'] as num?)?.toInt() ?? (amount - remaining);
    final pct       = amount > 0 ? 1 - (remaining / amount) : 0.0;
    final dateWib   = '${debt['created_at_wib'] ?? ''}';
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
        if (dateWib.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(dateWib, style: UText.caption),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _MiniStat('Total', uRupiah(amount))),
          Expanded(child: _MiniStat('Sudah Dibayar', uRupiah(paid))),
          Expanded(child: _MiniStat('Sisa', uRupiah(remaining), color: color, bold: true)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0),
                minHeight: 6, backgroundColor: color.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(color))),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (debt['reason'] == 'TITIP_DANA'
                  ? const Color(0xFF2563EB) : const Color(0xFF92400E)).withOpacity(0.10),
              borderRadius: BorderRadius.circular(URadius.full),
            ),
            child: Text(
              debt['reason'] == 'TITIP_DANA' ? '💰 Titip Dana' : '📦 Hutang Barang',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
                  color: debt['reason'] == 'TITIP_DANA'
                      ? const Color(0xFF1D4ED8) : const Color(0xFF92400E)),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, size: 16, color: UColors.textMid)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded, size: 16, color: UColors.danger)),
          ),
        ]),
        if (debt['note'] != null && '${debt['note']}'.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${debt['note']}', style: UText.caption,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
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
