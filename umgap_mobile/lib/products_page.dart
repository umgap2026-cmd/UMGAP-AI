import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  bool loading = true;
  List<dynamic> rows = [];
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final result = await ApiService.getProducts();
      if (!mounted) return;
      setState(() { rows = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((e) => '${Map<String,dynamic>.from(e)['name']}'.toLowerCase().contains(q)).toList();
  }

  String _formatRp(dynamic v) {
    final n = int.tryParse('$v') ?? 0;
    return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> addOrEdit({Map<String, dynamic>? item}) async {
    final name  = TextEditingController(text: item?['name']?.toString() ?? '');
    final price = TextEditingController(text: item?['price']?.toString() ?? '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: UColors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_rounded, color: UColors.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Text(item == null ? 'Tambah Produk' : 'Edit Produk',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UColors.textDark)),
            ]),
            const SizedBox(height: 20),
            const Text('Nama Produk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UColors.textMid)),
            const SizedBox(height: 6),
            TextField(controller: name, decoration: InputDecoration(
              hintText: 'Contoh: Produk A',
              prefixIcon: const Icon(Icons.label_rounded, color: UColors.teal, size: 18),
              filled: true, fillColor: UColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: UColors.primaryMid, width: 1.5)),
            )),
            const SizedBox(height: 14),
            const Text('Harga', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UColors.textMid)),
            const SizedBox(height: 6),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(
              hintText: '0',
              prefixIcon: const Icon(Icons.payments_rounded, color: UColors.teal, size: 18),
              prefixText: 'Rp ',
              filled: true, fillColor: UColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: UColors.primaryMid, width: 1.5)),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: UButton(label: 'Batal', outlined: true, onPressed: () => Navigator.pop(context, false))),
              const SizedBox(width: 12),
              Expanded(child: UButton(label: 'Simpan', onPressed: () => Navigator.pop(context, true), color: UColors.teal)),
            ]),
          ]),
        ),
      ),
    );

    if (ok != true) return;
    try {
      if (item == null) {
        await ApiService.addProduct(name: name.text.trim(), price: int.tryParse(price.text) ?? 0);
      } else {
        await ApiService.updateProduct(id: item['id'], name: name.text.trim(), price: int.tryParse(price.text) ?? 0);
      }
      await load();
      if (mounted) uSnack(context, item == null ? 'Produk ditambahkan' : 'Produk diupdate');
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: UAppBar(title: 'Produk Global'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addOrEdit(),
        backgroundColor: UColors.teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _search, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              hintStyle: const TextStyle(color: UColors.textLight, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: UColors.teal, size: 20),
              filled: true, fillColor: UColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        loading
            ? const Expanded(child: Center(child: CircularProgressIndicator(color: UColors.primary)))
            : Expanded(
          child: filtered.isEmpty
              ? const UEmptyState(icon: Icons.inventory_2_rounded, title: 'Tidak ada produk')
              : RefreshIndicator(
            color: UColors.primary, onRefresh: load,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = Map<String, dynamic>.from(filtered[i]);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: UColors.teal.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(children: [
                      Container(width: 5, height: 64, color: UColors.teal),
                      Container(
                        width: 56, height: 64,
                        color: UColors.teal.withOpacity(0.07),
                        child: const Center(child: Icon(Icons.inventory_2_rounded, color: UColors.teal, size: 24)),
                      ),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${item['name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UColors.textDark)),
                          const SizedBox(height: 3),
                          Text(_formatRp(item['price']), style: const TextStyle(fontSize: 13, color: UColors.teal, fontWeight: FontWeight.w700)),
                        ]),
                      )),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_rounded, color: UColors.primary, size: 20), onPressed: () => addOrEdit(item: item)),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: UColors.danger, size: 20),
                          onPressed: () async {
                            await ApiService.deleteProduct(item['id']);
                            await load();
                            if (mounted) uSnack(context, 'Produk dihapus');
                          },
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}