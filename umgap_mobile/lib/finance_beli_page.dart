import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';

// ════════════════════════════════════════════
//  BELI DARI ORANG — stok masuk
// ════════════════════════════════════════════
class FinanceBeliPage extends StatefulWidget {
  const FinanceBeliPage({super.key});
  @override State<FinanceBeliPage> createState() => _FinanceBeliPageState();
}

class _FinanceBeliPageState extends State<FinanceBeliPage> {
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
    try {
      final res = await ApiService.financeGetMaterials();
      if (!mounted) return;
      setState(() { _materials = res['materials'] ?? []; _matLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _matLoading = false);
    }
  }

  void _addItem() {
    setState(() => _items.add({
      'material_id':   null,
      'material_name': '',
      'qty_kg':        TextEditingController(),
      'price_per_kg':  TextEditingController(),
    }));
  }

  void _removeItem(int i) {
    (_items[i]['qty_kg']       as TextEditingController).dispose();
    (_items[i]['price_per_kg'] as TextEditingController).dispose();
    setState(() => _items.removeAt(i));
  }

  int get _total => _items.fold(0, (sum, item) {
    final qty   = double.tryParse(
        (_items[_items.indexOf(item)]['qty_kg'] as TextEditingController).text) ?? 0;
    final price = double.tryParse(
        (_items[_items.indexOf(item)]['price_per_kg'] as TextEditingController).text) ?? 0;
    return sum + (qty * price).toInt();
  });

  Future<void> _submit() async {
    if (_items.isEmpty) {
      uSnack(context, 'Tambah minimal 1 barang', isError: true); return;
    }
    for (final item in _items) {
      if (item['material_id'] == null) {
        uSnack(context, 'Pilih jenis barang untuk semua item', isError: true); return;
      }
      final qty = double.tryParse(
          (item['qty_kg'] as TextEditingController).text) ?? 0;
      if (qty <= 0) {
        uSnack(context, 'Isi berat (kg) untuk semua item', isError: true); return;
      }
    }

    setState(() => _loading = true);
    HapticFeedback.heavyImpact();

    try {
      final itemsData = _items.map((item) => {
        'material_id':  item['material_id'],
        'qty_kg':       double.tryParse(
            (item['qty_kg'] as TextEditingController).text) ?? 0,
        'price_per_kg': double.tryParse(
            (item['price_per_kg'] as TextEditingController).text) ?? 0,
      }).toList();

      await ApiService.financeBeli(
        partyName: _nameCtrl.text.trim(),
        isDebt:    _isDebt,
        items:     itemsData,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      await _showSuccessDialog();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessDialog() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(URadius.xl)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(USpace.base),
          decoration: BoxDecoration(
              color: UColors.successLight, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: UColors.success, size: 40),
        ),
        const SizedBox(height: USpace.base),
        Text('Berhasil!', style: UText.h3),
        const SizedBox(height: USpace.xs),
        Text('Total: ${uRupiah(_total)}',
            style: UText.body.copyWith(color: UColors.success,
                fontWeight: FontWeight.w700)),
        if (_isDebt) ...[
          const SizedBox(height: USpace.xs),
          const Text('⚠️ Dicatat sebagai hutang',
              style: TextStyle(color: UColors.warning,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ]),
      actions: [
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: UColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(URadius.md))),
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _matLoading
            ? const Center(child: CircularProgressIndicator(
            color: UColors.primary))
            : ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              USpace.base, USpace.base, USpace.base, 120),
          children: [
            // Nama penjual
            UField(
              controller: _nameCtrl,
              label:      'NAMA PENJUAL (opsional)',
              hint:       'Contoh: Pak Budi',
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: USpace.base),

            // Apakah hutang?
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact();
              setState(() => _isDebt = !_isDebt); },
              child: Container(
                padding: const EdgeInsets.all(USpace.md),
                decoration: BoxDecoration(
                  color: _isDebt
                      ? UColors.warningLight
                      : UColors.card,
                  borderRadius: BorderRadius.circular(URadius.md),
                  border: Border.all(color: _isDebt
                      ? UColors.warning.withOpacity(0.4)
                      : UColors.divider),
                ),
                child: Row(children: [
                  Icon(_isDebt
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                      color: _isDebt ? UColors.warning : UColors.textSoft),
                  const SizedBox(width: USpace.sm),
                  Text('Belum dibayar (hutang)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isDebt ? UColors.warning : UColors.textMid)),
                ]),
              ),
            ),

            const SizedBox(height: USpace.lg),

            // Header barang
            Row(children: [
              Text('Barang', style: UText.h5),
              const Spacer(),
              GestureDetector(
                onTap: _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: USpace.md, vertical: USpace.xs + 2),
                  decoration: BoxDecoration(
                    color: UColors.primary,
                    borderRadius: BorderRadius.circular(URadius.full),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Tambah', style: TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: USpace.sm),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(USpace.xl),
                decoration: BoxDecoration(
                  color: UColors.card,
                  borderRadius: BorderRadius.circular(URadius.lg),
                  border: Border.all(color: UColors.divider),
                ),
                child: Column(children: [
                  Icon(Icons.add_box_outlined,
                      color: UColors.textSoft, size: 40),
                  const SizedBox(height: USpace.sm),
                  Text('Tap "Tambah" untuk input barang',
                      style: UText.bodyS),
                ]),
              )
            else
              ..._items.asMap().entries.map((e) =>
                  _ItemCard(
                    index:     e.key,
                    item:      e.value,
                    materials: _materials,
                    onRemove:  () => _removeItem(e.key),
                    onChanged: () => setState(() {}),
                  )),
          ],
        )),
      ]),

      // Bottom submit
      bottomSheet: _items.isEmpty ? null : Container(
        padding: const EdgeInsets.fromLTRB(
            USpace.base, USpace.md, USpace.base, USpace.x2l),
        decoration: BoxDecoration(
          color: UColors.card,
          boxShadow: UShadow.lg(UColors.primary),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('Total:', style: UText.h5),
            const Spacer(),
            Text(uRupiah(_total), style: UText.h4.copyWith(
                color: UColors.success)),
          ]),
          const SizedBox(height: USpace.md),
          UButton(
            label:     'Simpan Transaksi Beli',
            onPressed: _loading ? null : _submit,
            loading:   _loading,
            icon:      Icons.save_rounded,
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return UHeader(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            USpace.sm, USpace.sm, USpace.base, USpace.xl),
        child: Row(children: [
          UBackButton(),
          const SizedBox(width: USpace.md),
          const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Orang Jual ke Kita', style: TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text('Stok masuk + catat pembelian',
                style: TextStyle(color: Colors.white54,
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ])),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: UColors.success.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: Colors.white, size: 22),
          ),
        ]),
      ),
    );
  }
}

// ── Item Card ─────────────────────────────────
class _ItemCard extends StatelessWidget {
  final int   index;
  final Map<String, dynamic> item;
  final List<dynamic> materials;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemCard({required this.index, required this.item,
    required this.materials, required this.onRemove,
    required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final qtyCtrl   = item['qty_kg']       as TextEditingController;
    final priceCtrl = item['price_per_kg'] as TextEditingController;
    final qty       = double.tryParse(qtyCtrl.text)   ?? 0;
    final price     = double.tryParse(priceCtrl.text) ?? 0;
    final subtotal  = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: USpace.md),
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.card,
        border: Border.all(color: UColors.divider),
      ),
      child: Column(children: [
        // Header item
        Container(
          padding: const EdgeInsets.fromLTRB(
              USpace.base, USpace.sm, USpace.sm, USpace.sm),
          decoration: BoxDecoration(
            color: UColors.success.withOpacity(0.05),
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(URadius.lg)),
            border: Border(bottom: BorderSide(color: UColors.divider)),
          ),
          child: Row(children: [
            Text('Barang ${index + 1}',
                style: UText.h5.copyWith(color: UColors.success)),
            const Spacer(),
            if (subtotal > 0)
              Text(uRupiah(subtotal.toInt()),
                  style: UText.bodyS.copyWith(
                      color: UColors.success, fontWeight: FontWeight.w800)),
            const SizedBox(width: USpace.sm),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  color: UColors.danger, size: 20),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(USpace.base),
          child: Column(children: [
            // Pilih material
            DropdownButtonFormField<int>(
              value: item['material_id'],
              decoration: InputDecoration(
                labelText: 'Jenis Barang',
                labelStyle: UText.label.copyWith(color: UColors.textSoft),
                prefixIcon: const Icon(Icons.category_rounded,
                    color: UColors.primary, size: 18),
                filled:    true,
                fillColor: UColors.inputBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(
                        color: UColors.primary.withOpacity(0.15))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(
                        color: UColors.primary.withOpacity(0.15))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: USpace.base, vertical: USpace.md),
              ),
              hint: const Text('Pilih jenis barang'),
              items: materials.map((m) {
                final mat   = m as Map<String, dynamic>;
                final matId = int.tryParse('${mat['id']}') ?? 0;
                return DropdownMenuItem<int>(
                  value: matId,
                  child: Text('${mat['name']}',
                      style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                item['material_id'] = val;
                onChanged();
              },
            ),
            const SizedBox(height: USpace.sm),

            // Qty & Harga
            Row(children: [
              Expanded(child: TextField(
                controller:   qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged:    (_) => onChanged(),
                style: const TextStyle(fontSize: 14, color: UColors.textDark,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Berat (kg)',
                  labelStyle: UText.label.copyWith(color: UColors.textSoft),
                  prefixIcon: const Icon(Icons.scale_rounded,
                      color: UColors.primary, size: 18),
                  filled:    true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: USpace.base, vertical: USpace.md),
                ),
              )),
              const SizedBox(width: USpace.sm),
              Expanded(child: TextField(
                controller:   priceCtrl,
                keyboardType: TextInputType.number,
                onChanged:    (_) => onChanged(),
                style: const TextStyle(fontSize: 14, color: UColors.textDark,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Harga/kg',
                  labelStyle: UText.label.copyWith(color: UColors.textSoft),
                  prefixIcon: const Icon(Icons.attach_money_rounded,
                      color: UColors.primary, size: 18),
                  filled:    true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: USpace.base, vertical: USpace.md),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}