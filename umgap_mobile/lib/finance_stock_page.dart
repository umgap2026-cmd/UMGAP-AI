import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ── Responsive font size ──────────────────────────────────────
double _rfs(BuildContext context, double base) {
  final w = MediaQuery.of(context).size.width;
  if (w < 360) return base * 0.88;
  if (w > 430) return base * 1.08;
  return base;
}

// ── Format compact: 1.2 M, 500 Jt, 150 Rb, 5.000 ────────────
String _compact(num v) {
  if (v <= 0) return 'Rp -';
  if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)} M';
  if (v >= 1000000)    return 'Rp ${(v / 1000000).toStringAsFixed(1)} Jt';
  if (v >= 1000)       return 'Rp ${(v / 1000).toStringAsFixed(0)} Rb';
  return 'Rp ${v.toStringAsFixed(0)}';
}

// ── Format HPP tetap full tapi compact ───────────────────────
String _compactHpp(num v) {
  if (v <= 0) return 'Rp -';
  if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(1)} Jt';
  if (v >= 1000)    return 'Rp ${(v / 1000).toStringAsFixed(0)} Rb';
  return 'Rp ${v.toStringAsFixed(0)}';
}

class FinanceStockPage extends StatefulWidget {
  const FinanceStockPage({super.key});
  @override
  State<FinanceStockPage> createState() => _FinanceStockPageState();
}

class _FinanceStockPageState extends State<FinanceStockPage> {
  bool          _loading = true;
  List<dynamic> _materials = [];
  int           _totalValue = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Tampilkan cache dulu (instant)
    final cached = await CacheService.get(CacheService.kMaterials);
    if (cached != null && mounted) {
      setState(() {
        _materials  = List<dynamic>.from(cached['materials'] ?? []);
        _totalValue = (cached['total_value'] as num?)?.toInt() ?? 0;
        _loading    = false;
      });
    } else {
      setState(() => _loading = true);
    }
    // Fetch API di background
    try {
      final res = await ApiService.financeGetMaterials();
      if (!mounted) return;
      await CacheService.set(CacheService.kMaterials, res);
      final mats  = List<dynamic>.from(res['materials'] ?? []);
      final total = (res['total_value'] as num?)?.toInt() ?? 0;
      setState(() { _materials = mats; _totalValue = total; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_materials.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _showAddMaterial() async {
    final nameCtrl  = TextEditingController();
    final unitCtrl  = TextEditingController(text: 'kg');
    final qtyCtrl   = TextEditingController();
    final priceCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          bool saving = false;
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: bottom + 24, left: 20, right: 20, top: 6),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 18),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00838F).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_box_rounded,
                        color: Color(0xFF00838F), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tambah Barang Baru',
                        style: TextStyle(fontSize: _rfs(ctx, 16),
                            fontWeight: FontWeight.w800)),
                    Text('Langsung masuk ke daftar stok gudang',
                        style: TextStyle(fontSize: _rfs(ctx, 11),
                            color: const Color(0xFF90A4AE))),
                  ])),
                ]),
                const SizedBox(height: 20),
                _StockField(controller: nameCtrl,
                    label: 'Nama Barang *', hint: 'Contoh: BC, TM',
                    icon: Icons.label_rounded, autofocus: true),
                const SizedBox(height: 12),
                _StockField(controller: unitCtrl,
                    label: 'Satuan', hint: 'kg / liter / pcs',
                    icon: Icons.straighten_rounded),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Stok Awal (opsional)',
                        style: TextStyle(fontSize: _rfs(ctx, 11),
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StockField(controller: qtyCtrl,
                      label: 'Jumlah Awal', hint: '0',
                      icon: Icons.inventory_2_rounded,
                      keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 10),
                  Expanded(child: _StockField(controller: priceCtrl,
                      label: 'Harga Beli', hint: '0',
                      icon: Icons.price_check_rounded,
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                ]),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final name  = nameCtrl.text.trim();
                      final unit  = unitCtrl.text.trim().isEmpty ? 'kg' : unitCtrl.text.trim();
                      final qty   = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      if (name.isEmpty) { uSnack(context, 'Nama barang wajib diisi', isError: true); return; }
                      if (qty > 0 && price <= 0) { uSnack(context, 'Harga beli wajib diisi jika ada stok awal', isError: true); return; }
                      setS(() => saving = true);
                      try {
                        await ApiService.financeAddMaterial(name: name, unit: unit, initQty: qty, initPrice: price);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) { uSnack(context, '✓ Barang "$name" berhasil ditambahkan'); await _load(); }
                      } catch (e) {
                        if (mounted) uSnack(context, e.toString(), isError: true);
                        setS(() => saving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00838F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    child: saving
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Simpan Barang', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: _rfs(ctx, 15))),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMaterial,
        backgroundColor: const Color(0xFF00838F),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Barang Baru', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700,
            fontSize: _rfs(context, 13))),
      ),
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stok Gudang', style: TextStyle(
                  color: Colors.white, fontSize: _rfs(context, 18), fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Total nilai: ${_compact(_totalValue)}', style: TextStyle(
                  color: Colors.white70, fontSize: _rfs(context, 12), fontWeight: FontWeight.w600)),
            ])),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else if (_materials.isEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, size: _rfs(context, 52), color: UColors.textLight),
            SizedBox(height: _rfs(context, 10)),
            Text('Belum ada barang di gudang', style: TextStyle(
                fontSize: _rfs(context, 14), color: UColors.textLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Tap "＋ Barang Baru" untuk menambahkan', style: TextStyle(
                fontSize: _rfs(context, 12), color: UColors.textLight)),
          ])))
        else
          Expanded(child: RefreshIndicator(
            color: UColors.primary, onRefresh: _load,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  USpace.base, USpace.base, USpace.base, _rfs(context, 100)),
              itemCount: _materials.length,
              itemBuilder: (ctx, i) {
                final m     = _materials[i] as Map<String, dynamic>;
                double toD(dynamic v) => v == null ? 0.0 : double.tryParse('$v') ?? 0.0;
                int toI(dynamic v)    => v == null ? 0 : (double.tryParse('$v') ?? 0).toInt();
                final qty   = toD(m['qty_kg']);
                final avg   = toI(m['avg_cost_per_kg']);
                final value = toI(m['total_value']);
                final color = qty > 0 ? const Color(0xFF00838F) : UColors.textLight;

                return Container(
                  margin: const EdgeInsets.only(bottom: USpace.sm),
                  decoration: BoxDecoration(
                      color: UColors.card,
                      borderRadius: BorderRadius.circular(URadius.lg),
                      boxShadow: UShadow.card),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(URadius.lg),
                    child: IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Accent bar kiri
                        Container(width: 5, color: color),

                        // Info kiri — Expanded supaya tidak overflow
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(_rfs(ctx, 12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${m['name']}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: _rfs(ctx, 14),
                                          fontWeight: FontWeight.w700,
                                          color: UColors.textDark)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${qty.toStringAsFixed(1)} ${m['unit'] ?? 'kg'}'
                                        '  •  HPP: ${_compactHpp(avg)}/kg',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        fontSize: _rfs(ctx, 11),
                                        color: UColors.textMid),
                                  ),
                                ]),
                          ),
                        ),

                        // Nilai kanan — lebar tetap agar tidak overflow
                        Container(
                          constraints: BoxConstraints(
                              minWidth: _rfs(ctx, 90),
                              maxWidth: _rfs(ctx, 130)),
                          padding: EdgeInsets.all(_rfs(ctx, 12)),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_compact(value),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: _rfs(ctx, 13),
                                        color: color,
                                        fontWeight: FontWeight.w800)),
                                Text('Nilai stok',
                                    style: TextStyle(
                                        fontSize: _rfs(ctx, 10),
                                        color: UColors.textLight)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          )),
      ]),
    );
  }
}

class _StockField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  const _StockField({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    this.keyboard, this.inputFormatters, this.autofocus = false,
  });
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: _rfs(context, 12),
            fontWeight: FontWeight.w700, color: const Color(0xFF4A5568))),
        const SizedBox(height: 6),
        TextField(
          controller: controller, autofocus: autofocus,
          keyboardType: keyboard, inputFormatters: inputFormatters,
          style: TextStyle(fontSize: _rfs(context, 13)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: const Color(0xFF90A4AE),
                fontSize: _rfs(context, 12)),
            prefixIcon: Icon(icon, color: const Color(0xFF00838F),
                size: _rfs(context, 18)),
            filled: true, fillColor: const Color(0xFFF4F7FF),
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: _rfs(context, 12)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00838F).withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF00838F).withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00838F), width: 1.5)),
          ),
        ),
      ]);
}