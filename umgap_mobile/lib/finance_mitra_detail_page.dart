import 'package:flutter/material.dart';
import 'api_service.dart';
import 'u_kit.dart';
import 'nota_detail_page.dart';

class FinanceMitraDetailPage extends StatefulWidget {
  final int partyId;
  const FinanceMitraDetailPage({super.key, required this.partyId});
  @override State<FinanceMitraDetailPage> createState() => _FinanceMitraDetailPageState();
}

class _FinanceMitraDetailPageState extends State<FinanceMitraDetailPage> {
  bool _loading = true;
  Map<String, dynamic> _party = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeGetPartyDetail(widget.partyId);
      if (!mounted) return;
      setState(() { _party = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _sendReminder() async {
    try {
      await ApiService.financeSendPartyReminder(widget.partyId);
      if (mounted) uSnack(context, 'Pengingat WA sedang dikirim ✓');
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _showEdit() async {
    final nameCtrl  = TextEditingController(text: '${_party['name'] ?? ''}');
    final phoneCtrl = TextEditingController(text: '${_party['phone'] ?? ''}');
    final noteCtrl  = TextEditingController(text: '${_party['note'] ?? ''}');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        bool saving = false;
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
              const Text('Edit Mitra', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Nama *',
                      prefixIcon: const Icon(Icons.person_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'No. HP',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl,
                  decoration: InputDecoration(labelText: 'Catatan',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) { uSnack(context, 'Nama wajib diisi', isError: true); return; }
                    setS(() => saving = true);
                    try {
                      await ApiService.financeEditParty(
                          partyId: widget.partyId, name: name,
                          phone: phoneCtrl.text.trim(), note: noteCtrl.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) { uSnack(context, 'Mitra berhasil diperbarui ✓'); _load(); }
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Hapus mitra ini?'),
        content: Text('${_party['name']}'),
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
    if (ok != true) return;
    try {
      await ApiService.financeDeleteParty(widget.partyId);
      if (mounted) { uSnack(context, 'Mitra berhasil dihapus ✓'); Navigator.pop(context); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debts = List<dynamic>.from(_party['debts'] ?? []);
    final piutang = uInt(_party['total_piutang']);
    final hutang  = uInt(_party['total_hutang']);
    final net     = (_party['saldo_net'] as num?)?.toDouble() ?? (piutang - hutang).toDouble();
    final phone   = '${_party['phone'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_party['name'] ?? ''}', style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(phone.isEmpty ? 'Belum ada no. HP' : phone,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            UHeaderIconBtn(icon: Icons.edit_rounded, onTap: _showEdit),
            UHeaderIconBtn(icon: Icons.delete_outline_rounded, onTap: _confirmDelete),
          ]),
        )),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else Expanded(child: RefreshIndicator(
          color: UColors.primary, onRefresh: _load,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(USpace.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: net >= 0
                      ? [UColors.success, const Color(0xFF22C55E)]
                      : [UColors.danger, const Color(0xFFEF4444)]),
                  borderRadius: BorderRadius.circular(URadius.lg),
                  boxShadow: UShadow.card,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SALDO BERSIH', style: TextStyle(
                      color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(uRupiah(net.abs().toInt()), style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    net > 0 ? 'Mereka perlu menyelesaikan ke kami'
                        : net < 0 ? 'Kami perlu menyelesaikan ke mereka' : 'Saldo sudah nol',
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  const SizedBox(height: 2),
                  Text('Piutang ${uRupiah(piutang)} • Hutang ${uRupiah(hutang)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ]),
              ),
              const SizedBox(height: USpace.md),
              SizedBox(width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: (phone.isEmpty || debts.isEmpty) ? null : _sendReminder,
                  icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                  label: const Text('Kirim Pengingat WA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.md))),
                ),
              ),
              if (phone.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Isi nomor HP dulu lewat tombol Edit di atas.', style: UText.caption),
                ),
              const SizedBox(height: USpace.lg),
              USectionHeader(title: 'Rincian Terbuka'),
              const SizedBox(height: USpace.sm),
              if (debts.isEmpty)
                UEmptyState(icon: Icons.check_circle_outline_rounded,
                    title: 'Tidak ada hutang/piutang terbuka', subtitle: '')
              else
                ...debts.map((d) {
                  final m = d as Map<String, dynamic>;
                  final isHutang = m['type'] == 'HUTANG';
                  final color = isHutang ? UColors.danger : UColors.success;
                  final txnId = (m['transaction_id'] as num?)?.toInt();
                  return Container(
                    margin: const EdgeInsets.only(bottom: USpace.sm),
                    padding: const EdgeInsets.all(USpace.base),
                    decoration: BoxDecoration(color: UColors.card,
                        borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${m['label'] ?? (isHutang ? 'Hutang' : 'Piutang')}',
                            style: UText.h5.copyWith(fontSize: 13))),
                        Text(uRupiah(uInt(m['remaining'])), style: TextStyle(
                            color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                      ]),
                      if ('${m['created_at_wib'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('${m['created_at_wib']}${('${m['note'] ?? ''}'.isNotEmpty) ? ' • ${m['note']}' : ''}',
                            style: UText.caption),
                      ],
                      if (txnId != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => NotaDetailPage(txnId: txnId))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: UColors.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(URadius.full)),
                            child: const Text('🧾 Lihat Nota', style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w800, color: UColors.primary)),
                          ),
                        ),
                      ],
                    ]),
                  );
                }),
            ],
          ),
        )),
      ]),
    );
  }
}
