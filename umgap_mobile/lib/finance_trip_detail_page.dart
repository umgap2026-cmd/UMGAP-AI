import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

// ════════════════════════════════════════════
//  DETAIL PERJALANAN — semua aksi dalam 1 trip
// ════════════════════════════════════════════
class FinanceTripDetailPage extends StatefulWidget {
  final int tripId;
  const FinanceTripDetailPage({super.key, required this.tripId});
  @override State<FinanceTripDetailPage> createState() => _FinanceTripDetailPageState();
}

class _FinanceTripDetailPageState extends State<FinanceTripDetailPage> {
  bool  _loading = true;
  Map<String, dynamic> _data = {};
  List<dynamic> _materials   = [];

  bool get _isOpen {
    final trip = _data['trip'];
    if (trip == null) return false;
    return '${(trip as Map<String, dynamic>)['status']}' == 'OPEN';
  }

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final tripKey = CacheService.kTripDetail(widget.tripId);
    // Materials dari cache dulu
    final cachedMat = await CacheService.get(CacheService.kMaterials);
    // Trip detail dari cache dulu
    final cachedTrip = await CacheService.get(tripKey);
    if (cachedTrip != null && mounted) {
      setState(() {
        _data      = cachedTrip;
        _materials = cachedMat != null
            ? List<dynamic>.from(cachedMat['materials'] ?? [])
            : [];
        _loading   = false;
      });
    } else {
      setState(() => _loading = true);
    }
    // Background refresh
    try {
      final results = await Future.wait([
        ApiService.financeTripDetail(tripId: widget.tripId),
        ApiService.financeGetMaterials(),
      ]);
      if (!mounted) return;
      final tripData = results[0] as Map<String, dynamic>;
      final matData  = results[1] as Map<String, dynamic>;
      await Future.wait([
        CacheService.set(tripKey, tripData),
        CacheService.set(CacheService.kMaterials, matData),
      ]);
      setState(() {
        _data      = tripData;
        _materials = matData['materials'] ?? [];
        _loading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  // ── Input Jual ke Lapak ──────────────────
  Future<void> _addSell() async {
    final parties = List<dynamic>.from(_data['parties'] ?? []);
    await _showItemDialog(
      title:     'Jual ke Lapak',
      color:     UColors.primary,
      icon:      Icons.arrow_upward_rounded,
      showParty: true,
      parties:   parties,
      showPayment: true,
      onSubmit:  (partyId, partyName, payType, items) async {
        await ApiService.financeTripSell(
          tripId:      widget.tripId,
          partyId:     partyId,
          partyName:   partyName,
          paymentType: payType,
          items:       items,
        );
      },
    );
  }

  // ── Input Beli di Jakarta ────────────────
  Future<void> _addBuy() async {
    await _showItemDialog(
      title:     'Beli Barang di Jakarta',
      color:     UColors.success,
      icon:      Icons.arrow_downward_rounded,
      showParty: false,
      parties:   [],
      showPayment: false,
      onSubmit:  (_, __, ___, items) async {
        await ApiService.financeTripBuy(
          tripId: widget.tripId,
          items:  items,
        );
      },
    );
  }

  // ── Input Pengeluaran ────────────────────
  Future<void> _addExpense() async {
    final nameCtrl = TextEditingController();
    final nomCtrl  = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Pengeluaran'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildField(nameCtrl, 'Keterangan', Icons.label_outline_rounded,
              TextInputType.text, hint: 'Ongkir, Makan, Bensin...'),
          const SizedBox(height: USpace.sm),
          _buildField(nomCtrl, 'Nominal (Rp)', Icons.attach_money_rounded,
              TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.warning,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeTripExpense(tripId: widget.tripId, items: [{
        'expense_name': nameCtrl.text.trim().isEmpty ? 'Pengeluaran' : nameCtrl.text.trim(),
        'subtotal':     double.tryParse(nomCtrl.text) ?? 0,
      }]);
      if (mounted) { uSnack(context, 'Pengeluaran dicatat ✓'); _load(); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
    nameCtrl.dispose(); nomCtrl.dispose();
  }

  // ── Input Balikan ────────────────────────
  Future<void> _addReturn() async {
    int? matId;
    final qtyCtrl   = TextEditingController();
    final noteCtrl  = TextEditingController();
    bool toStock    = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
          title: const Text('Catat Balikan Barang'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: matId,
              decoration: InputDecoration(labelText: 'Jenis Barang',
                  filled: true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                      borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
              hint: const Text('Pilih barang'),
              items: _materials.map((m) {
                final mat = m as Map<String, dynamic>;
                return DropdownMenuItem<int>(
                  value: int.tryParse('${mat['id']}') ?? 0,
                  child: Text('${mat['name']}', style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (v) => setS(() => matId = v),
            ),
            const SizedBox(height: USpace.sm),
            _buildField(qtyCtrl, 'Berat (kg)', Icons.scale_rounded,
                TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: USpace.sm),
            _buildField(noteCtrl, 'Keterangan', Icons.note_alt_outlined,
                TextInputType.text, hint: 'Contoh: barang kotor'),
            const SizedBox(height: USpace.sm),
            // Toggle masuk stok atau dibuang
            GestureDetector(
              onTap: () => setS(() => toStock = !toStock),
              child: Container(
                padding: const EdgeInsets.all(USpace.md),
                decoration: BoxDecoration(
                  color: toStock ? UColors.successLight : UColors.dangerLight,
                  borderRadius: BorderRadius.circular(URadius.md),
                  border: Border.all(color: toStock
                      ? UColors.success.withOpacity(0.3)
                      : UColors.danger.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(toStock ? Icons.inventory_2_rounded : Icons.delete_outline_rounded,
                      color: toStock ? UColors.success : UColors.danger, size: 20),
                  const SizedBox(width: USpace.sm),
                  Text(toStock ? 'Masuk kembali ke stok' : 'Dibuang / tidak dipakai',
                      style: TextStyle(
                          color: toStock ? UColors.success : UColors.danger,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(URadius.sm))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (matId == null || !mounted) return;
    try {
      await ApiService.financeTripReturn(tripId: widget.tripId, items: [{
        'material_id':    matId,
        'qty_kg':         double.tryParse(qtyCtrl.text) ?? 0,
        'return_to_stock': toStock,
        'note':           noteCtrl.text.trim(),
      }]);
      if (mounted) {
        uSnack(context, toStock ? 'Balikan masuk stok ✓' : 'Balikan dicatat (dibuang) ✓');
        _load();
      }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
    qtyCtrl.dispose(); noteCtrl.dispose();
  }

  // ── Tutup perjalanan ─────────────────────
  Future<void> _closeTrip() async {
    final summary = (_data['summary'] ?? {}) as Map<String, dynamic>;
    final net     = (double.tryParse('${summary['net_result'] ?? 0}') ?? 0).toInt();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Tutup Perjalanan?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Setelah ditutup tidak bisa tambah transaksi lagi.',
              style: TextStyle(fontSize: 13, color: UColors.textSoft)),
          const SizedBox(height: USpace.base),
          Container(
            padding: const EdgeInsets.all(USpace.base),
            decoration: BoxDecoration(
              color: net >= 0 ? UColors.successLight : UColors.dangerLight,
              borderRadius: BorderRadius.circular(URadius.md),
            ),
            child: Row(children: [
              Icon(net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: net >= 0 ? UColors.success : UColors.danger),
              const SizedBox(width: USpace.sm),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Estimasi Hasil Bersih',
                    style: TextStyle(fontSize: 11, color: UColors.textSoft)),
                Text(uRupiah(net), style: TextStyle(
                    color: net >= 0 ? UColors.success : UColors.danger,
                    fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup Perjalanan', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      HapticFeedback.heavyImpact();
      final res = await ApiService.financeTripClose(tripId: widget.tripId);
      if (!mounted) return;
      final finalNet = (double.tryParse('${res['net_result'] ?? 0}') ?? 0).toInt();
      uSnack(context, 'Perjalanan ditutup! Hasil: ${uRupiah(finalNet)}');
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  // ── Generic item dialog ──────────────────
  Future<void> _showItemDialog({
    required String title,
    required Color  color,
    required IconData icon,
    required bool showParty,
    required bool showPayment,
    required List<dynamic> parties,
    required Future<void> Function(int? partyId, String partyName,
        String payType, List<Map<String, dynamic>> items) onSubmit,
  }) async {
    int?   partyId;
    String partyName  = '';
    String payType    = 'CASH';
    final  items      = <Map<String, dynamic>>[];
    items.add({
      'material_id': null,
      'qty_ctrl':    TextEditingController(),
      'price_ctrl':  TextEditingController(),
    });

    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          int total = items.fold<int>(0, (sum, item) {
            final qty   = double.tryParse((item['qty_ctrl'] as TextEditingController).text) ?? 0;
            final price = double.tryParse((item['price_ctrl'] as TextEditingController).text) ?? 0;
            return sum + (qty * price).toInt();
          });

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, sc) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(URadius.x2l)),
              ),
              child: Column(children: [
                // Handle bar
                Container(margin: const EdgeInsets.only(top: USpace.md, bottom: USpace.sm),
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: UColors.textSoft.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(USpace.base, 0, USpace.base, USpace.md),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(URadius.sm)),
                        child: Icon(icon, color: color, size: 18)),
                    const SizedBox(width: USpace.md),
                    Expanded(child: Text(title, style: UText.h4)),
                    Text(uRupiah(total), style: UText.h5.copyWith(color: color)),
                  ]),
                ),
                Divider(height: 1, color: UColors.divider),
                Expanded(child: ListView(controller: sc,
                  padding: const EdgeInsets.all(USpace.base),
                  children: [
                    // Pilih lapak
                    if (showParty) ...[
                      if (parties.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: partyId,
                          decoration: InputDecoration(labelText: 'Pilih Lapak',
                              filled: true, fillColor: UColors.inputBg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                                  borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                                  borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
                          hint: const Text('Pilih lapak atau ketik baru'),
                          items: parties.map((p) {
                            final party = p as Map<String, dynamic>;
                            return DropdownMenuItem<int>(
                              value: int.tryParse('${party['id']}') ?? 0,
                              child: Text('${party['name']}'),
                            );
                          }).toList(),
                          onChanged: (v) => setS(() => partyId = v),
                        ),
                      const SizedBox(height: USpace.sm),
                      _buildField2(
                        label:   partyId == null ? 'Nama Lapak Baru' : 'Atau ketik nama baru',
                        icon:    Icons.storefront_rounded,
                        keyboard: TextInputType.text,
                        onChanged: (v) => partyName = v,
                      ),
                      const SizedBox(height: USpace.md),
                    ],

                    // Payment type
                    if (showPayment) ...[
                      Text('Metode Pembayaran', style: UText.label.copyWith(
                          color: UColors.textMid)),
                      const SizedBox(height: USpace.sm),
                      Row(children: ['CASH', 'TRANSFER', 'HUTANG'].map((p) =>
                          Expanded(child: GestureDetector(
                            onTap: () => setS(() => payType = p),
                            child: Container(
                              margin: const EdgeInsets.only(right: USpace.sm),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: payType == p ? color : UColors.surface,
                                borderRadius: BorderRadius.circular(URadius.sm),
                                border: Border.all(color: payType == p
                                    ? color : UColors.divider),
                              ),
                              child: Center(child: Text(p, style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: payType == p ? Colors.white : UColors.textMid))),
                            ),
                          ))).toList(),
                      ),
                      const SizedBox(height: USpace.lg),
                    ],

                    // Items
                    Row(children: [
                      Text('Barang', style: UText.h5), const Spacer(),
                      GestureDetector(
                        onTap: () => setS(() => items.add({
                          'material_id': null,
                          'qty_ctrl':    TextEditingController(),
                          'price_ctrl':  TextEditingController(),
                        })),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: USpace.md, vertical: 5),
                          decoration: BoxDecoration(color: color,
                              borderRadius: BorderRadius.circular(URadius.full)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Tambah', style: TextStyle(color: Colors.white,
                                fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: USpace.sm),

                    ...items.asMap().entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: USpace.sm),
                      padding: const EdgeInsets.all(USpace.md),
                      decoration: BoxDecoration(color: UColors.surface,
                          borderRadius: BorderRadius.circular(URadius.md),
                          border: Border.all(color: UColors.divider)),
                      child: Column(children: [
                        Row(children: [
                          Text('Barang ${e.key + 1}',
                              style: UText.caption.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (items.length > 1)
                            GestureDetector(onTap: () => setS(() => items.removeAt(e.key)),
                                child: const Icon(Icons.close_rounded,
                                    color: UColors.danger, size: 18)),
                        ]),
                        const SizedBox(height: USpace.sm),
                        DropdownButtonFormField<int>(
                          value: e.value['material_id'],
                          decoration: InputDecoration(labelText: 'Jenis Barang',
                              filled: true, fillColor: Colors.white,
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(URadius.sm),
                                  borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(URadius.sm),
                                  borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
                          hint: const Text('Pilih barang', style: TextStyle(fontSize: 13)),
                          items: _materials.map((m) {
                            final mat  = m as Map<String, dynamic>;
                            final stok = double.tryParse('${mat['qty_kg'] ?? 0}') ?? 0.0;
                            final avg  = (double.tryParse('${mat['avg_cost_per_kg'] ?? 0}') ?? 0).toInt();
                            return DropdownMenuItem<int>(
                              value: int.tryParse('${mat['id']}') ?? 0,
                              child: Text(
                                '${mat['name']} · ${stok.toStringAsFixed(1)}kg · ${uRupiah(avg)}/kg',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: stok <= 0 ? UColors.textSoft : UColors.textDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setS(() => e.value['material_id'] = v),
                        ),
                        // Info stok setelah pilih material
                        if (e.value['material_id'] != null) Builder(builder: (_) {
                          final selected = _materials.firstWhere(
                                (m) => (int.tryParse('${(m as Map)['id']}') ?? 0) == e.value['material_id'],
                            orElse: () => <String, dynamic>{},
                          ) as Map<String, dynamic>;
                          final stok = double.tryParse('${selected['qty_kg'] ?? 0}') ?? 0.0;
                          final avg  = (double.tryParse('${selected['avg_cost_per_kg'] ?? 0}') ?? 0).toInt();
                          return Container(
                            margin: const EdgeInsets.only(top: USpace.xs),
                            padding: const EdgeInsets.symmetric(
                                horizontal: USpace.md, vertical: 6),
                            decoration: BoxDecoration(
                              color: stok > 0 ? UColors.successLight : UColors.dangerLight,
                              borderRadius: BorderRadius.circular(URadius.xs),
                            ),
                            child: Row(children: [
                              Icon(stok > 0
                                  ? Icons.inventory_2_rounded
                                  : Icons.warning_amber_rounded,
                                  color: stok > 0 ? UColors.success : UColors.danger,
                                  size: 13),
                              const SizedBox(width: 6),
                              Text(
                                stok > 0
                                    ? 'Tersedia: ${stok.toStringAsFixed(1)} kg  •  HPP: ${uRupiah(avg)}/kg'
                                    : 'Stok kosong!',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: stok > 0 ? UColors.success : UColors.danger),
                              ),
                            ]),
                          );
                        }),
                        const SizedBox(height: USpace.sm),
                        Row(children: [
                          Expanded(child: TextField(
                            controller: e.value['qty_ctrl'],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setS(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(labelText: 'Kg',
                                filled: true, fillColor: Colors.white, isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(URadius.sm),
                                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(URadius.sm),
                                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
                          )),
                          const SizedBox(width: USpace.sm),
                          Expanded(child: TextField(
                            controller: e.value['price_ctrl'],
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setS(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(labelText: 'Harga/kg',
                                filled: true, fillColor: Colors.white, isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(URadius.sm),
                                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(URadius.sm),
                                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
                          )),
                        ]),
                      ]),
                    )),

                    const SizedBox(height: USpace.x2l),
                  ],
                )),
                // Submit bar
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      USpace.base, USpace.md, USpace.base, USpace.x2l),
                  decoration: BoxDecoration(color: Colors.white,
                      boxShadow: UShadow.md(color)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Text('Total:', style: UText.h5), const Spacer(),
                      Text(uRupiah(total), style: UText.h4.copyWith(color: color)),
                    ]),
                    const SizedBox(height: USpace.md),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(URadius.md))),
                      onPressed: () async {
                        final submitItems = items.map((item) => {
                          'material_id':  item['material_id'],
                          'qty_kg':       double.tryParse(
                              (item['qty_ctrl'] as TextEditingController).text) ?? 0,
                          'price_per_kg': double.tryParse(
                              (item['price_ctrl'] as TextEditingController).text) ?? 0,
                        }).toList();
                        Navigator.pop(ctx);
                        try {
                          HapticFeedback.mediumImpact();
                          await onSubmit(partyId, partyName, payType, submitItems);
                          if (mounted) { uSnack(context, 'Berhasil disimpan ✓'); _load(); }
                        } catch (e) {
                          if (mounted) uSnack(context, e.toString(), isError: true);
                        }
                      },
                      child: Text('Simpan', style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                    ),
                  ]),
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
    if (_loading) {
      return const Scaffold(backgroundColor: UColors.surface,
          body: Center(child: CircularProgressIndicator(color: UColors.primary)));
    }

    final trip    = (_data['trip']    ?? {}) as Map<String, dynamic>;
    final items   = List<dynamic>.from(_data['items']   ?? []);
    final summary = (_data['summary'] ?? {}) as Map<String, dynamic>;

    int _i(dynamic v) => (double.tryParse('${v ?? 0}') ?? 0).toInt();
    final totalJual    = _i(summary['total_jual']);
    final totalBeli    = _i(summary['total_beli']);
    final totalExpense = _i(summary['total_expense']);
    final net          = _i(summary['net_result']);

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(
              USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Column(children: [
            Row(children: [
              UBackButton(), const SizedBox(width: USpace.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${trip['note'] ?? 'Perjalanan #${widget.tripId}'}',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${trip['trip_date'] ?? '-'}',
                    style: const TextStyle(color: Colors.white54,
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ])),
              UBadge(_isOpen ? 'BERLANGSUNG' : 'SELESAI'),
            ]),
            const SizedBox(height: USpace.base),
            // Summary bar
            Row(children: [
              _SumItem('Jual',    uRupiah(totalJual),    UColors.success),
              _SumItem('Beli',    uRupiah(totalBeli),    const Color(0xFFEF9A9A)),
              _SumItem('Biaya',   uRupiah(totalExpense), UColors.warning),
              _SumItem('Bersih',  uRupiah(net),
                  net >= 0 ? UColors.cyan : const Color(0xFFEF9A9A)),
            ]),
          ]),
        )),

        Expanded(child: RefreshIndicator(
          color: UColors.primary, onRefresh: _load,
          child: ListView(physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                USpace.base, USpace.base, USpace.base,
                _isOpen ? 160 : 40),
            children: [
              // Daftar transaksi
              if (items.isEmpty)
                UEmptyState(icon: Icons.receipt_long_rounded,
                    title: 'Belum ada transaksi',
                    subtitle: 'Tap tombol di bawah untuk mulai catat')
              else ...[
                USectionHeader(title: 'Transaksi'),
                const SizedBox(height: USpace.sm),
                ...items.map((item) => _ItemCard(item: item as Map<String, dynamic>)),
              ],
            ],
          ),
        )),
      ]),

      // Action buttons — hanya jika masih OPEN
      bottomSheet: _isOpen ? Container(
        padding: const EdgeInsets.fromLTRB(
            USpace.base, USpace.md, USpace.base, USpace.x2l),
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: UShadow.lg(UColors.primary)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: _ActionBtn('Jual', Icons.arrow_upward_rounded,
                UColors.primary, _addSell)),
            const SizedBox(width: USpace.sm),
            Expanded(child: _ActionBtn('Beli', Icons.arrow_downward_rounded,
                UColors.success, _addBuy)),
            const SizedBox(width: USpace.sm),
            Expanded(child: _ActionBtn('Biaya', Icons.remove_circle_outline_rounded,
                UColors.warning, _addExpense)),
            const SizedBox(width: USpace.sm),
            Expanded(child: _ActionBtn('Balikan', Icons.undo_rounded,
                UColors.purple, _addReturn)),
          ]),
          const SizedBox(height: USpace.md),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: UColors.navy,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(URadius.md))),
            onPressed: _closeTrip,
            child: const Text('Tutup & Selesaikan Perjalanan',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ) : null,
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      TextInputType keyboard, {String? hint}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard,
      style: const TextStyle(fontSize: 14, color: UColors.textDark),
      decoration: InputDecoration(labelText: label, hintText: hint,
          labelStyle: UText.label.copyWith(color: UColors.textSoft),
          prefixIcon: Icon(icon, color: UColors.primary, size: 18),
          filled: true, fillColor: UColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))),
    );
  }

  Widget _buildField2({required String label, required IconData icon,
    required TextInputType keyboard, required Function(String) onChanged}) {
    return TextField(onChanged: onChanged, keyboardType: keyboard,
        style: const TextStyle(fontSize: 14, color: UColors.textDark),
        decoration: InputDecoration(labelText: label,
            labelStyle: UText.label.copyWith(color: UColors.textSoft),
            prefixIcon: Icon(icon, color: UColors.primary, size: 18),
            filled: true, fillColor: UColors.inputBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(URadius.md),
                borderSide: BorderSide(color: UColors.primary.withOpacity(0.15)))));
  }
}

// ── Item Card ──────────────────────────────
class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemCard({required this.item});

  Color get _color {
    switch ('${item['type']}') {
      case 'JUAL':    return UColors.primary;
      case 'BELI':    return UColors.success;
      case 'EXPENSE': return UColors.warning;
      case 'RETURN':  return UColors.purple;
      default:        return UColors.textSoft;
    }
  }

  String get _label {
    switch ('${item['type']}') {
      case 'JUAL':    return 'Jual ke lapak';
      case 'BELI':    return 'Beli di Jakarta';
      case 'EXPENSE': return '${item['expense_name'] ?? 'Pengeluaran'}';
      case 'RETURN':  return 'Balikan barang';
      default:        return '${item['type']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (double.tryParse('${item['subtotal'] ?? 0}') ?? 0).toInt();
    final qty      = (double.tryParse('${item['qty_kg'] ?? 0}') ?? 0);
    final type     = '${item['type']}';

    return Container(
      margin: const EdgeInsets.only(bottom: USpace.sm),
      padding: const EdgeInsets.all(USpace.md),
      decoration: BoxDecoration(color: UColors.card,
          borderRadius: BorderRadius.circular(URadius.lg),
          boxShadow: UShadow.card),
      child: Row(children: [
        Container(width: 4, height: 44, color: _color,
            margin: const EdgeInsets.only(right: USpace.md)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label, style: UText.h5.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            if (item['material_name'] != null && type != 'EXPENSE')
              Text('${item['material_name']}', style: UText.caption),
            if (qty > 0) ...[
              const Text(' • ', style: TextStyle(color: UColors.textSoft, fontSize: 11)),
              Text('${qty.toStringAsFixed(1)} kg', style: UText.caption),
            ],
            if (item['party_name'] != null) ...[
              const Text(' • ', style: TextStyle(color: UColors.textSoft, fontSize: 11)),
              Text('${item['party_name']}', style: UText.caption),
            ],
            if (item['payment_type'] != null && type == 'JUAL') ...[
              const SizedBox(width: 4),
              UBadge('${item['payment_type']}'),
            ],
          ]),
        ])),
        Text(uRupiah(subtotal), style: UText.bodyS.copyWith(
            color: _color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Micro widgets ─────────────────────────
class _SumItem extends StatelessWidget {
  final String label, value; final Color color;
  const _SumItem(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9,
        fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(color: color, fontSize: 11,
        fontWeight: FontWeight.w800),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]));
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      height: 56,
      decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(URadius.sm),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color,
            fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}