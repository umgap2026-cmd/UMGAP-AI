// ════════════════════════════════════════════
//  finance_expense_page.dart — Pengeluaran
// ════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';

class FinanceExpensePage extends StatefulWidget {
  const FinanceExpensePage({super.key});
  @override State<FinanceExpensePage> createState() => _FinanceExpensePageState();
}

class _FinanceExpensePageState extends State<FinanceExpensePage> {
  final _noteCtrl = TextEditingController();
  bool  _loading  = false;
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _addItem(); }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  void _addItem() => setState(() => _items.add({
    'name':    TextEditingController(),
    'nominal': TextEditingController(),
  }));

  void _removeItem(int i) {
    (_items[i]['name']    as TextEditingController).dispose();
    (_items[i]['nominal'] as TextEditingController).dispose();
    setState(() => _items.removeAt(i));
  }

  int get _total => _items.fold(0, (sum, item) =>
  sum + (int.tryParse((item['nominal'] as TextEditingController).text) ?? 0));

  Future<void> _submit() async {
    if (_items.isEmpty) { uSnack(context, 'Tambah minimal 1 pengeluaran', isError: true); return; }
    for (final item in _items) {
      if ((item['name'] as TextEditingController).text.trim().isEmpty) {
        uSnack(context, 'Isi nama pengeluaran', isError: true); return;
      }
      if ((int.tryParse((item['nominal'] as TextEditingController).text) ?? 0) <= 0) {
        uSnack(context, 'Isi nominal pengeluaran', isError: true); return;
      }
    }

    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
    try {
      await ApiService.financeExpense(
        note:  _noteCtrl.text.trim(),
        items: _items.map((item) => {
          'expense_name': (item['name'] as TextEditingController).text.trim(),
          'subtotal':     int.tryParse((item['nominal'] as TextEditingController).text) ?? 0,
        }).toList(),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      uSnack(context, 'Pengeluaran disimpan ✓');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pengeluaran', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Ongkir, makan, operasional, dll',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
          ]),
        )),
        Expanded(child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 120),
          children: [
            UField(controller: _noteCtrl, label: 'KETERANGAN (opsional)',
                hint: 'Contoh: Perjalanan Jakarta', prefixIcon: Icons.note_alt_outlined),
            const SizedBox(height: USpace.lg),
            Row(children: [
              Text('Detail Pengeluaran', style: UText.h5), const Spacer(),
              GestureDetector(onTap: _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: USpace.xs + 2),
                  decoration: BoxDecoration(color: UColors.warning,
                      borderRadius: BorderRadius.circular(URadius.full)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Tambah', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: USpace.sm),
            ..._items.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: USpace.sm),
              padding: const EdgeInsets.all(USpace.md),
              decoration: BoxDecoration(color: UColors.card,
                  borderRadius: BorderRadius.circular(URadius.lg),
                  boxShadow: UShadow.card, border: Border.all(color: UColors.divider)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [
                  TextField(
                    controller: e.value['name'] as TextEditingController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: UColors.textDark, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(hintText: 'Nama pengeluaran (Ongkir, Makan...)',
                        hintStyle: UText.caption.copyWith(color: UColors.textLight),
                        filled: true, fillColor: UColors.inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                            borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                            borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: USpace.base, vertical: USpace.sm)),
                  ),
                  const SizedBox(height: USpace.sm),
                  TextField(
                    controller: e.value['nominal'] as TextEditingController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: UColors.textDark, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(hintText: 'Nominal (Rp)',
                        hintStyle: UText.caption.copyWith(color: UColors.textLight),
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: UColors.warning, size: 18),
                        filled: true, fillColor: UColors.inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                            borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                            borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: USpace.base, vertical: USpace.sm)),
                  ),
                ])),
                const SizedBox(width: USpace.sm),
                if (_items.length > 1)
                  GestureDetector(onTap: () => _removeItem(e.key),
                      child: const Icon(Icons.close_rounded, color: UColors.danger, size: 20)),
              ]),
            )),
          ],
        )),
      ]),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, USpace.x2l),
        decoration: BoxDecoration(color: UColors.card, boxShadow: UShadow.lg(UColors.warning)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('Total Keluar:', style: UText.h5), const Spacer(),
            Text(uRupiah(_total), style: UText.h4.copyWith(color: UColors.warning)),
          ]),
          const SizedBox(height: USpace.md),
          UButton(label: 'Simpan Pengeluaran', onPressed: _loading ? null : _submit,
              loading: _loading, icon: Icons.save_rounded,
              color: UColors.warning),
        ]),
      ),
    );
  }
}