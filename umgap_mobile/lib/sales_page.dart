import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

// ════════════════════════════════════════════
//  SALES PAGE
// ════════════════════════════════════════════
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  bool loading = true;
  List<dynamic> rows = [];
  List<dynamic> products = [];
  int? selectedProductId;
  final qty  = TextEditingController(text: '1');
  final note = TextEditingController();
  bool submitting = false;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { qty.dispose(); note.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final sales = await ApiService.getSales();
      final prod  = await ApiService.getGlobalProducts();
      if (!mounted) return;
      setState(() {
        rows = sales; products = prod; loading = false;
        if (products.isNotEmpty && selectedProductId == null) {
          selectedProductId = products.first['id'] as int;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> submit() async {
    if (selectedProductId == null) return;
    setState(() => submitting = true);
    try {
      await ApiService.submitSale(productId: selectedProductId!, qty: int.tryParse(qty.text) ?? 0, note: note.text);
      note.clear(); qty.text = '1';
      await load();
      if (mounted) uSnack(context, 'Penjualan berhasil dicatat');
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
    }
    if (mounted) setState(() => submitting = false);
  }

  Color _statusColor(String s) {
    final u = s.toUpperCase();
    if (u.contains('APPROVED')) return UColors.success;
    if (u.contains('PENDING'))  return UColors.purple;
    if (u.contains('REJECTED')) return UColors.danger;
    return UColors.textLight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: UAppBar(title: 'Penjualan'),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : RefreshIndicator(
        color: UColors.primary, onRefresh: load,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // ── Form card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.09), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: UColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.shopping_bag_rounded, color: UColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Input Penjualan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: UColors.textDark)),
                ]),
                const SizedBox(height: 18),
                const Text('Produk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UColors.textMid)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: UColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UColors.primary.withOpacity(0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedProductId,
                      isExpanded: true,
                      items: products.map((e) {
                        final item = Map<String, dynamic>.from(e);
                        return DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text('${item['name']} — Rp ${item['price']}', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedProductId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: UField(controller: qty, label: 'Qty', keyboard: TextInputType.number, prefixIcon: Icons.numbers_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: UField(controller: note, label: 'Catatan', prefixIcon: Icons.note_alt_outlined)),
                ]),
                const SizedBox(height: 18),
                UButton(label: 'Kirim Penjualan', onPressed: submitting ? null : submit, loading: submitting, icon: Icons.send_rounded),
              ]),
            ),

            const SizedBox(height: 24),
            const USectionHeader(title: 'Riwayat Penjualan'),
            const SizedBox(height: 12),

            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: UEmptyState(icon: Icons.shopping_bag_rounded, title: 'Belum ada penjualan'),
              )
            else
              ...rows.map((e) {
                final item = Map<String, dynamic>.from(e);
                final status = '${item['status'] ?? '-'}';
                final sc = _statusColor(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Row(children: [
                      Container(width: 5, color: sc, height: 68),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${item['product_name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: UColors.textDark)),
                            const SizedBox(height: 3),
                            Text('Qty: ${item['qty'] ?? 0}${item['note'] != null && '${item['note']}'.isNotEmpty ? " • ${item['note']}" : ""}',
                                style: const TextStyle(fontSize: 12, color: UColors.textMid)),
                          ])),
                          UBadge(status, color: sc),
                        ]),
                      )),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════