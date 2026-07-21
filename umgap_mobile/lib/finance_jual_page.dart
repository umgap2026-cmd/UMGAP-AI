// ════════════════════════════════════════════
//  finance_jual_page.dart
// ════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

class FinanceJualPage extends StatefulWidget {
  const FinanceJualPage({super.key});
  @override State<FinanceJualPage> createState() => _FinanceJualPageState();
}

class _FinanceJualPageState extends State<FinanceJualPage> {
  final _nameCtrl = TextEditingController();
  bool  _isDebt   = false;
  bool  _loading  = false;
  bool  _matLoading = true;
  List<dynamic> _materials = [];
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _loadMaterials(); }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadMaterials() async {
    // Cache dulu
    final cached = await CacheService.get(CacheService.kMaterials);
    if (cached != null && mounted) {
      setState(() { _materials = cached['materials'] ?? []; _matLoading = false; });
    }
    // Background refresh
    try {
      final res = await ApiService.financeGetMaterials();
      if (!mounted) return;
      await CacheService.set(CacheService.kMaterials, res);
      setState(() { _materials = res['materials'] ?? []; _matLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _matLoading = false);
    }
  }

  void _addItem() => setState(() => _items.add({
    'material_id':  null,
    'qty_kg':       TextEditingController(),
    'price_per_kg': TextEditingController(),
  }));

  void _removeItem(int i) {
    (_items[i]['qty_kg']       as TextEditingController).dispose();
    (_items[i]['price_per_kg'] as TextEditingController).dispose();
    setState(() => _items.removeAt(i));
  }

  int get _total => _items.fold(0, (sum, item) {
    final qty   = double.tryParse((item['qty_kg']       as TextEditingController).text) ?? 0;
    final price = double.tryParse((item['price_per_kg'] as TextEditingController).text) ?? 0;
    return sum + (qty * price).toInt();
  });

  Future<void> _submit() async {
    if (_items.isEmpty) { uSnack(context, 'Tambah minimal 1 barang', isError: true); return; }
    for (final item in _items) {
      if (item['material_id'] == null) { uSnack(context, 'Pilih jenis barang', isError: true); return; }
      if ((double.tryParse((item['qty_kg'] as TextEditingController).text) ?? 0) <= 0) {
        uSnack(context, 'Isi berat (kg)', isError: true); return;
      }
    }
    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
    try {
      final res = await ApiService.financeJual(
        partyName: _nameCtrl.text.trim(),
        isDebt:    _isDebt,
        items:     _items.map((item) => {
          'material_id':  item['material_id'],
          'qty_kg':       double.tryParse((item['qty_kg'] as TextEditingController).text) ?? 0,
          'price_per_kg': double.tryParse((item['price_per_kg'] as TextEditingController).text) ?? 0,
        }).toList(),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      final laba = int.tryParse('${res['laba'] ?? 0}') ?? 0;
      await showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(USpace.base),
                decoration: BoxDecoration(color: UColors.infoLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: UColors.primary, size: 40)),
            const SizedBox(height: USpace.base),
            Text('Terjual!', style: UText.h3),
            const SizedBox(height: USpace.xs),
            Text('Total: ${uRupiah(_total)}',
                style: UText.body.copyWith(color: UColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Laba: ${uRupiah(laba)}',
                style: TextStyle(
                    color: laba >= 0 ? UColors.success : UColors.danger,
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          actions: [SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.md))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ))],
        ),
      );
      if (mounted) Navigator.pop(context);
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
            UBackButton(),
            const SizedBox(width: USpace.md),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Orang Beli dari Kita', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Stok keluar + hitung laba', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: UColors.primary.withOpacity(0.30), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)),
          ]),
        )),
        Expanded(child: _matLoading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : ListView(physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 120),
          children: [
            UField(controller: _nameCtrl, label: 'NAMA PEMBELI (opsional)',
                hint: 'Contoh: Bu Sari', prefixIcon: Icons.person_outline_rounded),
            const SizedBox(height: USpace.base),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _isDebt = !_isDebt); },
              child: Container(
                padding: const EdgeInsets.all(USpace.md),
                decoration: BoxDecoration(
                  color: _isDebt ? UColors.warningLight : UColors.card,
                  borderRadius: BorderRadius.circular(URadius.md),
                  border: Border.all(color: _isDebt ? UColors.warning.withOpacity(0.4) : UColors.divider),
                ),
                child: Row(children: [
                  Icon(_isDebt ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: _isDebt ? UColors.warning : UColors.textSoft),
                  const SizedBox(width: USpace.sm),
                  Text('Belum dibayar (piutang)', style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isDebt ? UColors.warning : UColors.textMid)),
                ]),
              ),
            ),
            const SizedBox(height: USpace.lg),
            Row(children: [
              Text('Barang', style: UText.h5),
              const Spacer(),
              GestureDetector(
                onTap: _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: USpace.md, vertical: USpace.xs + 2),
                  decoration: BoxDecoration(color: UColors.primary,
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
            ..._items.asMap().entries.map((e) => _JualItemCard(
              index: e.key, item: e.value, materials: _materials,
              onRemove: () => _removeItem(e.key), onChanged: () => setState(() {}),
            )),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(USpace.xl),
                decoration: BoxDecoration(color: UColors.card,
                    borderRadius: BorderRadius.circular(URadius.lg),
                    border: Border.all(color: UColors.divider)),
                child: Column(children: [
                  Icon(Icons.add_box_outlined, color: UColors.textSoft, size: 40),
                  const SizedBox(height: USpace.sm),
                  Text('Tap "Tambah" untuk input barang', style: UText.bodyS),
                ]),
              ),
          ],
        )),
      ]),
      bottomSheet: _items.isEmpty ? null : Container(
        padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, USpace.x2l),
        decoration: BoxDecoration(color: UColors.card, boxShadow: UShadow.lg(UColors.primary)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('Total:', style: UText.h5), const Spacer(),
            Text(uRupiah(_total), style: UText.h4.copyWith(color: UColors.primary)),
          ]),
          const SizedBox(height: USpace.md),
          UButton(label: 'Simpan Transaksi Jual', onPressed: _loading ? null : _submit,
              loading: _loading, icon: Icons.save_rounded),
        ]),
      ),
    );
  }
}

class _JualItemCard extends StatelessWidget {
  final int index; final Map<String, dynamic> item;
  final List<dynamic> materials;
  final VoidCallback onRemove, onChanged;
  const _JualItemCard({required this.index, required this.item,
    required this.materials, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final qtyCtrl   = item['qty_kg']       as TextEditingController;
    final priceCtrl = item['price_per_kg'] as TextEditingController;
    final qty       = double.tryParse(qtyCtrl.text)   ?? 0;
    final price     = double.tryParse(priceCtrl.text) ?? 0;
    final subtotal  = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: USpace.md),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg),
          boxShadow: UShadow.card, border: Border.all(color: UColors.divider)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.sm, USpace.sm, USpace.sm),
          decoration: BoxDecoration(color: UColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(URadius.lg)),
              border: Border(bottom: BorderSide(color: UColors.divider))),
          child: Row(children: [
            Text('Barang ${index + 1}', style: UText.h5.copyWith(color: UColors.primary)),
            const Spacer(),
            if (subtotal > 0) Text(uRupiah(subtotal.toInt()),
                style: UText.bodyS.copyWith(color: UColors.primary, fontWeight: FontWeight.w800)),
            const SizedBox(width: USpace.sm),
            GestureDetector(onTap: onRemove,
                child: const Icon(Icons.close_rounded, color: UColors.danger, size: 20)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(USpace.base), child: Column(children: [
          DropdownButtonFormField<int>(
            value: item['material_id'],
            decoration: InputDecoration(labelText: 'Jenis Barang',
                labelStyle: UText.label.copyWith(color: UColors.textSoft),
                prefixIcon: const Icon(Icons.category_rounded, color: UColors.primary, size: 18),
                filled: true, fillColor: UColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                contentPadding: const EdgeInsets.symmetric(horizontal: USpace.base, vertical: USpace.md)),
            hint: const Text('Pilih jenis barang'),
            items: materials.map((m) {
              final mat = m as Map<String, dynamic>;
              final stok = double.tryParse('${mat['qty_kg']}') ?? 0.0;
              final matId = int.tryParse('${mat['id']}') ?? 0;
              return DropdownMenuItem<int>(
                value: matId,
                child: Text('${mat['name']} (${stok.toStringAsFixed(1)} kg)',
                    style: TextStyle(fontSize: 13,
                        color: stok <= 0 ? UColors.textSoft : UColors.textDark)),
              );
            }).toList(),
            onChanged: (val) { item['material_id'] = val; onChanged(); },
          ),
          const SizedBox(height: USpace.sm),
          Row(children: [
            Expanded(child: _buildField(qtyCtrl, 'Berat (kg)', Icons.scale_rounded, onChanged)),
            const SizedBox(width: USpace.sm),
            Expanded(child: _buildField(priceCtrl, 'Harga/kg', Icons.attach_money_rounded, onChanged)),
          ]),
        ])),
      ]),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, VoidCallback onChange) {
    return TextField(
      controller: ctrl, keyboardType: TextInputType.number, onChanged: (_) => onChange(),
      style: const TextStyle(fontSize: 14, color: UColors.textDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(labelText: label,
          labelStyle: UText.label.copyWith(color: UColors.textSoft),
          prefixIcon: Icon(icon, color: UColors.primary, size: 18),
          filled: true, fillColor: UColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          contentPadding: const EdgeInsets.symmetric(horizontal: USpace.base, vertical: USpace.md)),
    );
  }
}