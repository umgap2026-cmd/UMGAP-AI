import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'u_kit.dart';
import 'invoice_page.dart';
import 'invoice_print_page.dart';

// ════════════════════════════════════════════
//  DETAIL NOTA — dipanggil dari Riwayat Nota
//  (baca fin_transactions via get_fin_invoice_detail,
//   sumber yg sama dgn invoice_print.html di web)
// ════════════════════════════════════════════
class NotaDetailPage extends StatefulWidget {
  final int txnId;
  const NotaDetailPage({super.key, required this.txnId});

  @override
  State<NotaDetailPage> createState() => _NotaDetailPageState();
}

class _NotaDetailPageState extends State<NotaDetailPage> {
  bool _loading = true;
  bool _cancelling = false;
  bool _changed = false;
  Map<String, dynamic>? _invoice;
  List<dynamic> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.invoiceFullDetail(widget.txnId);
      if (!mounted) return;
      setState(() {
        _invoice = Map<String, dynamic>.from(res['invoice'] ?? {});
        _items   = List<dynamic>.from(res['items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  void _printNota() {
    final inv = _invoice;
    if (inv == null) return;
    final isBeli = inv['nota_type'] == 'BELI';
    final cartItems = _items.map((it) {
      final m = Map<String, dynamic>.from(it);
      final note = '${m['note'] ?? ''}';
      return CartItem(
        productId:   (m['material_id'] as num?)?.toInt() ?? 0,
        productName: '${m['product_name'] ?? '-'}',
        price:       (m['price'] as num?)?.toInt() ?? 0,
        qty:         (m['qty'] as num?)?.toDouble() ?? 0,
        isReturn:    m['is_return'] == true,
        note:        note.isNotEmpty ? note : null,
      );
    }).toList();

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoicePrintPage(
        invoiceId:       inv['id'],
        invoiceNo:       '${inv['invoice_no'] ?? ''}',
        customerName:    '${inv['customer_name'] ?? ''}',
        customerPhone:   '${inv['customer_phone'] ?? ''}',
        paymentMethod:   '${inv['payment_method'] ?? 'CASH'}',
        notes:           '${inv['notes'] ?? ''}',
        discount:        (inv['discount'] as num?)?.toDouble() ?? 0,
        subtotal:        (inv['subtotal'] as num?)?.toDouble() ?? 0,
        reverseSubtotal: (inv['reverse_subtotal'] as num?)?.toDouble() ?? 0,
        grandTotal:      (inv['grand_total'] as num?)?.toDouble() ?? 0,
        items:           cartItems,
        isPaid:          inv['is_paid'] == true,
        isBeli:          isBeli,
      ),
    ));
  }

  Future<void> _editNota() async {
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => InvoicePage(editTxnId: widget.txnId),
    ));
    if (updated == true) {
      _changed = true;
      _load();
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? UColors.danger : UColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _rp(num v) {
    final s = v.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return (v < 0 ? '-Rp ' : 'Rp ') + s;
  }

  Future<void> _cancelNota() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Batalkan Nota?'),
        content: const Text(
            'Stok & HPP gudang akan dikembalikan ke kondisi sebelum nota ini, '
            'dan hutang/piutang terkait dihapus. Aksi ini tidak bisa dibatalkan lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _cancelling = true);
    try {
      await ApiService.invoiceCancel(widget.txnId);
      if (!mounted) return;
      _snack('✓ Nota dibatalkan, stok & HPP sudah dikembalikan');
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal membatalkan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _buildWaText() {
    final inv = _invoice!;
    final isBeli = inv['nota_type'] == 'BELI';
    final buf = StringBuffer();
    buf.writeln('🧾 *${isBeli ? "Nota Pembelian" : "Nota Penjualan"}*');
    buf.writeln('No. Nota : ${inv['invoice_no'] ?? '-'}');
    buf.writeln('Tanggal  : ${inv['created_at_wib'] ?? '-'}');
    buf.writeln('${isBeli ? "Pemasok" : "Customer"} : ${inv['customer_name']?.toString().isNotEmpty == true ? inv['customer_name'] : '-'}');
    buf.writeln('');
    for (final it in _items) {
      final item = it as Map<String, dynamic>;
      final isReturn = item['is_return'] == true;
      final qty = (item['qty'] as num?)?.toDouble() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final sub = (item['subtotal'] as num?)?.toDouble() ?? 0;
      buf.writeln('${isReturn ? "🔁 " : ""}${item['product_name'] ?? '-'}');
      buf.writeln('  ${_fmtQty(qty)} ${item['unit'] ?? ''} x ${_rp(price)} = '
          '${isReturn ? "-" : ""}${_rp(sub)}');
    }
    buf.writeln('');
    buf.writeln('Subtotal : ${_rp((inv['subtotal'] as num?)?.toDouble() ?? 0)}');
    final revSub = (inv['reverse_subtotal'] as num?)?.toDouble() ?? 0;
    if (revSub > 0) buf.writeln('Barang Balik : -${_rp(revSub)}');
    final disc = (inv['discount'] as num?)?.toDouble() ?? 0;
    if (disc > 0) buf.writeln('Diskon : -${_rp(disc)}');
    buf.writeln('*TOTAL : ${_rp((inv['grand_total'] as num?)?.toDouble() ?? 0)}*');
    buf.writeln(inv['is_paid'] == true ? '✅ Lunas' : '⏳ Belum Lunas');
    return buf.toString();
  }

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  Future<void> _shareWa() async {
    if (_invoice == null) return;
    final text = _buildWaText();
    final encoded = Uri.encodeComponent(text);
    final waScheme = Uri.parse('whatsapp://send?text=$encoded');
    final waWeb    = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(waScheme)) {
      await launchUrl(waScheme, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(waWeb)) {
      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
      return;
    }
    await Share.share(text, subject: 'Nota ${_invoice!['invoice_no'] ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: UColors.surface,
        appBar: UAppBar(
          title: _invoice?['invoice_no'] ?? 'Detail Nota',
          onBack: () => Navigator.pop(context, _changed),
          actions: [
            if (_invoice != null)
              IconButton(
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                tooltip: 'Cetak / Share PDF & Gambar',
                onPressed: _printNota,
              ),
            if (_invoice != null && _invoice!['cancelled_at'] == null)
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                tooltip: 'Edit Nota',
                onPressed: _editNota,
              ),
            if (_invoice != null)
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Share ke WA',
                onPressed: _shareWa,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: UColors.primary))
            : _error != null
            ? Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: UColors.danger),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: UColors.textMid)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ]),
        ))
            : _buildDetail(),
      ),
    );
  }

  Widget _buildDetail() {
    final inv = _invoice!;
    final isBeli = inv['nota_type'] == 'BELI';
    final isPaid = inv['is_paid'] == true;
    final isCancelled = inv['cancelled_at'] != null;
    final hasMixed = inv['has_mixed_items'] == true;
    final typeColor = isBeli ? const Color(0xFF00796B) : UColors.primary;

    final forwardItems = _items.where((e) => (e as Map)['is_return'] != true).toList();
    final reverseItems = _items.where((e) => (e as Map)['is_return'] == true).toList();

    return RefreshIndicator(
      color: UColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Header card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [typeColor, typeColor.withOpacity(0.75)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(isBeli ? '📦 Nota Pembelian' : '🛒 Nota Penjualan',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                    child: const Text('❌ Dibatalkan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                    child: Text(isPaid ? '✅ Lunas' : '⏳ Belum Lunas',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 8),
              Text('${inv['invoice_no'] ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 4),
              Text('${inv['created_at_wib'] ?? '-'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Info card ──
          _InfoCard(children: [
            _InfoRow(isBeli ? 'Pemasok' : 'Customer', inv['customer_name']?.toString().isNotEmpty == true ? inv['customer_name'] : '-'),
            if (inv['customer_phone']?.toString().isNotEmpty == true)
              _InfoRow('No. HP', inv['customer_phone']),
            _InfoRow('Kasir', inv['created_by_name'] ?? '-'),
            _InfoRow('Pembayaran', inv['payment_method'] ?? '-'),
            if (inv['notes']?.toString().isNotEmpty == true)
              _InfoRow('Catatan', inv['notes']),
          ]),
          const SizedBox(height: 14),

          // ── Items ──
          _InfoCard(children: [
            Text('🛍️ Item Nota', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: UColors.textDark)),
            const SizedBox(height: 10),
            if (hasMixed) ...[
              Text(isBeli ? '📤 Barang Dibeli' : '📤 Barang Terjual',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: UColors.textMid)),
              const SizedBox(height: 6),
              ...forwardItems.map((e) => _ItemRow(item: e as Map<String, dynamic>, rp: _rp)),
              const SizedBox(height: 12),
              Text(isBeli ? '📥 Barang Dijual Balik' : '📥 Barang Dibeli Balik',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFC2410C))),
              const SizedBox(height: 6),
              ...reverseItems.map((e) => _ItemRow(item: e as Map<String, dynamic>, rp: _rp)),
            ] else
              ..._items.map((e) => _ItemRow(item: e as Map<String, dynamic>, rp: _rp)),
          ]),
          const SizedBox(height: 14),

          // ── Ringkasan ──
          _InfoCard(children: [
            Text('💰 Ringkasan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: UColors.textDark)),
            const SizedBox(height: 10),
            _SumRow('Subtotal', _rp((inv['subtotal'] as num?)?.toDouble() ?? 0)),
            if ((inv['reverse_subtotal'] as num?)?.toDouble() != null && ((inv['reverse_subtotal'] as num).toDouble()) > 0) ...[
              const SizedBox(height: 6),
              _SumRow('🔁 Barang Balik', '− ${_rp((inv['reverse_subtotal'] as num).toDouble())}', color: const Color(0xFFC2410C)),
            ],
            for (final d in List<Map<String, dynamic>>.from(inv['discount_breakdown'] ?? [])) ...[
              const SizedBox(height: 6),
              _SumRow('${d['label']}', '− ${_rp((d['amount'] as num?)?.toDouble() ?? 0)}', color: UColors.danger),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(children: [
              const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: UColors.primaryDark)),
              const Spacer(),
              Text(_rp((inv['grand_total'] as num?)?.toDouble() ?? 0),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: typeColor)),
            ]),
          ]),

          if (!isCancelled) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancelNota,
                icon: _cancelling
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UColors.danger))
                    : const Icon(Icons.cancel_outlined, color: UColors.danger),
                label: Text(_cancelling ? 'Membatalkan…' : 'Batalkan Nota',
                    style: const TextStyle(color: UColors.danger, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: UColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 12, color: UColors.textLight, fontWeight: FontWeight.w700))),
      Expanded(child: Text('$value', style: const TextStyle(fontSize: 13, color: UColors.textDark, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(num) rp;
  const _ItemRow({required this.item, required this.rp});

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final isReturn = item['is_return'] == true;
    final qty = (item['qty'] as num?)?.toDouble() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final sub = (item['subtotal'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['product_name'] ?? '-'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: UColors.textDark)),
            Text('${_fmtQty(qty)} ${item['unit'] ?? ''} × ${rp(price)}',
                style: const TextStyle(fontSize: 11.5, color: UColors.textMid)),
            if (item['note']?.toString().isNotEmpty == true)
              Text('${item['note']}', style: const TextStyle(fontSize: 11, color: UColors.textLight, fontStyle: FontStyle.italic)),
          ]),
        ),
        Text((isReturn ? '− ' : '') + rp(sub),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                color: isReturn ? const Color(0xFFC2410C) : UColors.primary)),
      ]),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _SumRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 13, color: UColors.textMid)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? UColors.textDark)),
  ]);
}
