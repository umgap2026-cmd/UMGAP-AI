import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'u_kit.dart';
import 'nota_detail_page.dart';

// ════════════════════════════════════════════
//  RIWAYAT NOTA — mirror dari web /nota
// ════════════════════════════════════════════
class NotaHistoryPage extends StatefulWidget {
  const NotaHistoryPage({super.key});

  @override
  State<NotaHistoryPage> createState() => _NotaHistoryPageState();
}

class _NotaHistoryPageState extends State<NotaHistoryPage> {
  bool _loading = true;
  List<dynamic> _invoices = [];
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'SEMUA';   // SEMUA | JUAL | BELI
  String _statusFilter = 'SEMUA'; // SEMUA | LUNAS | BELUM
  String _editedFilter = 'SEMUA'; // SEMUA | EDITED | NEW

  final _typeChips = const [
    {'value': 'SEMUA', 'label': 'Semua'},
    {'value': 'JUAL',  'label': '🛒 Jual'},
    {'value': 'BELI',  'label': '📦 Beli'},
  ];
  final _statusChips = const [
    {'value': 'SEMUA', 'label': 'Semua'},
    {'value': 'LUNAS', 'label': '✅ Lunas'},
    {'value': 'BELUM', 'label': '⏳ Belum'},
  ];
  final _editedChips = const [
    {'value': 'SEMUA',  'label': 'Semua'},
    {'value': 'EDITED', 'label': '✏️ Baru Diedit'},
    {'value': 'NEW',    'label': 'Belum Diedit'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.invoiceHistory(limit: 300);
      if (!mounted) return;
      setState(() {
        _invoices = List<dynamic>.from(res['invoices'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Gagal memuat riwayat nota: $e', isError: true);
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

  String _notaType(String invoiceNo) =>
      invoiceNo.toUpperCase().startsWith('BELI') ? 'BELI' : 'JUAL';

  List<dynamic> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _invoices.where((e) {
      final inv = e as Map<String, dynamic>;
      final no      = '${inv['invoice_no'] ?? ''}';
      final cust    = '${inv['customer_name'] ?? ''}';
      final kasir   = '${inv['created_by_name'] ?? ''}';
      final isPaid  = inv['is_paid'] == true;
      final type    = _notaType(no);
      final isEdited = inv['is_edited'] == true;

      final matchQ = q.isEmpty ||
          no.toLowerCase().contains(q) ||
          cust.toLowerCase().contains(q) ||
          kasir.toLowerCase().contains(q);
      final matchType   = _typeFilter == 'SEMUA' || type == _typeFilter;
      final matchStatus = _statusFilter == 'SEMUA' ||
          (_statusFilter == 'LUNAS' && isPaid) ||
          (_statusFilter == 'BELUM' && !isPaid);
      final matchEdited = _editedFilter == 'SEMUA' ||
          (_editedFilter == 'EDITED' && isEdited) ||
          (_editedFilter == 'NEW' && !isEdited);
      return matchQ && matchType && matchStatus && matchEdited;
    }).toList();
  }

  Future<void> _shareList(List<dynamic> list) async {
    if (list.isEmpty) {
      _snack('Tidak ada nota utk dibagikan', isError: true);
      return;
    }
    final buf = StringBuffer('🧾 *Ringkasan Riwayat Nota*\n\n');
    double total = 0;
    for (var i = 0; i < list.length; i++) {
      final inv = list[i] as Map<String, dynamic>;
      final grand = (inv['grand_total'] as num?)?.toDouble() ?? 0;
      total += grand;
      final paidIco = inv['is_paid'] == true ? '✅' : '⏳';
      buf.writeln('${i + 1}. ${inv['invoice_no'] ?? '-'} — '
          '${inv['customer_name'] ?? '-'} — ${_rp(grand)} $paidIco');
    }
    buf.writeln('\nTotal ${list.length} nota — ${_rp(total)}');
    await _launchWhatsAppText(buf.toString());
  }

  Future<void> _launchWhatsAppText(String text) async {
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
    await Share.share(text, subject: 'Riwayat Nota UMGAP');
  }

  String _rp(num v) {
    final s = v.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return (v < 0 ? '-Rp ' : 'Rp ') + s;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: UAppBar(
        title: 'Riwayat Nota',
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Share ke WA',
            onPressed: () => _shareList(filtered),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: UColors.textDark),
              decoration: InputDecoration(
                hintText: 'No. nota / nama customer / kasir…',
                hintStyle: const TextStyle(color: UColors.textLight, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: UColors.primary, size: 20),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.list_alt_rounded, color: UColors.primary, size: 20),
                    tooltip: 'Pilih kasir',
                    onPressed: () async {
                      final names = _invoices
                          .map((e) => '${(e as Map)['created_by_name'] ?? ''}')
                          .where((n) => n.isNotEmpty).toList();
                      final picked = await uShowNamePicker(context,
                          title: 'Pilih Kasir', names: names,
                          allLabel: 'Semua Kasir');
                      if (picked != null) {
                        setState(() => _searchCtrl.text = picked);
                      }
                    },
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: UColors.textLight, size: 18),
                      onPressed: () { _searchCtrl.clear(); setState(() {}); },
                    ),
                ]),
                filled: true,
                fillColor: UColors.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: UColors.primaryMid, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ChipRow(
                items: _typeChips,
                selected: _typeFilter,
                onSelect: (v) => setState(() => _typeFilter = v),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ChipRow(
                items: _statusChips,
                selected: _statusFilter,
                onSelect: (v) => setState(() => _statusFilter = v),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ChipRow(
                items: _editedChips,
                selected: _editedFilter,
                onSelect: (v) => setState(() => _editedFilter = v),
              )),
            ]),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Text('${filtered.length} nota ditemukan',
                style: const TextStyle(fontSize: 12, color: UColors.textMid, fontWeight: FontWeight.w500)),
          ]),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: UColors.primary.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text('Belum ada nota yang cocok dengan filter ini',
                style: TextStyle(color: UColors.textMid, fontWeight: FontWeight.w500)),
          ]))
              : RefreshIndicator(
            color: UColors.primary,
            onRefresh: _load,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final inv = filtered[i] as Map<String, dynamic>;
                return _NotaCard(
                  inv: inv,
                  notaType: _notaType('${inv['invoice_no'] ?? ''}'),
                  rp: _rp,
                  onTap: () async {
                    final changed = await Navigator.push<bool>(context, MaterialPageRoute(
                      builder: (_) => NotaDetailPage(txnId: inv['id'] as int),
                    ));
                    if (changed == true) _load();
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<Map<String, String>> items;
  final String selected;
  final void Function(String) onSelect;
  const _ChipRow({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final t = items[i];
        final isSelected = selected == t['value'];
        return GestureDetector(
          onTap: () => onSelect(t['value']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? UColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? UColors.primary : UColors.primary.withOpacity(0.25),
                  width: 1.5),
            ),
            child: Text(t['label']!,
                style: TextStyle(
                    color: isSelected ? Colors.white : UColors.primary,
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );
      },
    ),
  );
}

class _NotaCard extends StatelessWidget {
  final Map<String, dynamic> inv;
  final String notaType;
  final String Function(num) rp;
  final VoidCallback onTap;
  const _NotaCard({
    required this.inv,
    required this.notaType,
    required this.rp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = inv['is_paid'] == true;
    final grand  = (inv['grand_total'] as num?)?.toDouble() ?? 0;
    final isEdited = inv['is_edited'] == true;
    final typeColor = notaType == 'BELI' ? const Color(0xFF00796B) : UColors.primary;
    final statusColor = isPaid ? UColors.success : UColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: typeColor.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(children: [
            Container(width: 4, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(notaType == 'BELI' ? '📦 Beli' : '🛒 Jual',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: typeColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${inv['invoice_no'] ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: UColors.textDark))),
                  ]),
                  const SizedBox(height: 6),
                  Text('${inv['created_at_wib'] ?? '-'} • ${inv['customer_name']?.toString().isNotEmpty == true ? inv['customer_name'] : '-'}',
                      style: const TextStyle(fontSize: 11.5, color: UColors.textMid)),
                  const SizedBox(height: 2),
                  Text('Kasir ${inv['created_by_name'] ?? '-'} • ${inv['payment_method'] ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                  if (isEdited) ...[
                    const SizedBox(height: 2),
                    Text(
                        '✏️ Diedit oleh ${inv['edited_by_name'] ?? '-'} • ${inv['updated_at_wib'] ?? '-'}',
                        style: const TextStyle(fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309))),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusColor.withOpacity(0.3))),
                      child: Text(isPaid ? '✅ Lunas' : '⏳ Belum',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
                    ),
                    const Spacer(),
                    Text(rp(grand),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: typeColor)),
                  ]),
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded, color: UColors.textLight),
            ),
          ]),
        ),
      ),
    );
  }
}
