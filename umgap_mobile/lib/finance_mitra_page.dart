import 'package:flutter/material.dart';
import 'api_service.dart';
import 'u_kit.dart';
import 'finance_mitra_detail_page.dart';

class FinanceMitraPage extends StatefulWidget {
  const FinanceMitraPage({super.key});
  @override State<FinanceMitraPage> createState() => _FinanceMitraPageState();
}

class _FinanceMitraPageState extends State<FinanceMitraPage> {
  bool _loading = true;
  List<dynamic> _parties = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.financeGetParties(search: _query.trim().isEmpty ? null : _query.trim());
      if (!mounted) return;
      setState(() { _parties = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _showAddParty() async {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl  = TextEditingController();

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
              const Text('+ Tambah Mitra', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Nama *',
                      prefixIcon: const Icon(Icons.person_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'No. HP (opsional)',
                      prefixIcon: const Icon(Icons.phone_rounded),
                      filled: true, fillColor: UColors.inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl,
                  decoration: InputDecoration(labelText: 'Catatan (opsional)',
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
                      await ApiService.financeAddParty(
                          name: name, phone: phoneCtrl.text.trim(), note: noteCtrl.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) { uSnack(context, 'Mitra berhasil ditambahkan ✓'); _load(); }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddParty,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Mitra', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            const Expanded(child: Text('Saldo Mitra',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            UHeaderIconBtn(icon: Icons.refresh_rounded, onTap: _load),
          ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) { _query = v; },
            onSubmitted: (_) => _load(),
            style: const TextStyle(fontSize: 14, color: UColors.textDark),
            decoration: InputDecoration(
              hintText: 'Cari nama mitra…',
              hintStyle: const TextStyle(color: UColors.textLight, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: UColors.primary, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: UColors.textLight, size: 18),
                      onPressed: () { _searchCtrl.clear(); _query = ''; _load(); },
                    )
                  : null,
              filled: true, fillColor: UColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
        else if (_parties.isEmpty)
          Expanded(child: UEmptyState(icon: Icons.people_alt_rounded,
              title: 'Belum ada mitra tersimpan', subtitle: 'Tap "Tambah Mitra" untuk menambahkan'))
        else Expanded(child: RefreshIndicator(
          color: UColors.primary, onRefresh: _load,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(USpace.base, USpace.base, USpace.base, 100),
            itemCount: _parties.length,
            itemBuilder: (ctx, i) {
              final p = _parties[i] as Map<String, dynamic>;
              final piutang = uInt(p['total_piutang']);
              final hutang  = uInt(p['total_hutang']);
              final net     = (p['saldo_net'] as num?)?.toDouble() ?? (piutang - hutang).toDouble();
              final color   = net > 0 ? UColors.success : (net < 0 ? UColors.danger : UColors.textLight);
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FinanceMitraDetailPage(partyId: (p['id'] as num).toInt()))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: USpace.sm),
                  padding: const EdgeInsets.all(USpace.base),
                  decoration: BoxDecoration(color: UColors.card,
                      borderRadius: BorderRadius.circular(URadius.lg), boxShadow: UShadow.card),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p['name']}', style: UText.h5),
                      const SizedBox(height: 2),
                      Text('${p['phone'] ?? "Belum ada no. HP"}', style: UText.caption),
                    ])),
                    Text(uRupiah(net.abs().toInt()), style: TextStyle(
                        color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: UColors.textLight),
                  ]),
                ),
              );
            },
          ),
        )),
      ]),
    );
  }
}
