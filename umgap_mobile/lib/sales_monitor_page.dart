import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

//  SALES MONITOR PAGE
// ════════════════════════════════════════════
class SalesMonitorPage extends StatefulWidget {
  const SalesMonitorPage({super.key});
  @override
  State<SalesMonitorPage> createState() => _SalesMonitorPageState();
}

class _SalesMonitorPageState extends State<SalesMonitorPage> with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, dynamic> data = {};
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); load(); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final result = await ApiService.getSalesMonitor();
      if (!mounted) return;
      setState(() { data = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = List<dynamic>.from(data['summary'] ?? []);
    final rows    = List<dynamic>.from(data['rows'] ?? []);

    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [UColors.primaryDark, UColors.primary, UColors.primaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Monitor Sales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white, indicatorWeight: 3,
              labelColor: Colors.white, unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [Tab(text: 'Ringkasan'), Tab(text: 'Riwayat')],
            ),
          ])),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : TabBarView(controller: _tab, children: [
        // Ringkasan
        RefreshIndicator(color: UColors.primary, onRefresh: load,
          child: summary.isEmpty
              ? const UEmptyState(icon: Icons.bar_chart_rounded, title: 'Tidak ada data ringkasan')
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: summary.length,
            itemBuilder: (_, i) {
              final item = Map<String, dynamic>.from(summary[i]);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: UColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Center(child: Text('${item['employee_name']}'.isNotEmpty ? '${item['employee_name']}'[0].toUpperCase() : '?',
                          style: const TextStyle(color: UColors.primary, fontWeight: FontWeight.w800, fontSize: 16)))),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${item['employee_name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UColors.textDark))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [UColors.primaryDark, UColors.primaryMid]), borderRadius: BorderRadius.circular(12)),
                    child: Text('${item['total_qty']} pcs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              );
            },
          ),
        ),
        // Riwayat
        RefreshIndicator(color: UColors.primary, onRefresh: load,
          child: rows.isEmpty
              ? const UEmptyState(icon: Icons.receipt_long_rounded, title: 'Tidak ada riwayat')
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final item = Map<String, dynamic>.from(rows[i]);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item['employee_name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: UColors.textDark)),
                      const SizedBox(height: 3),
                      Text('${item['product_name']} × ${item['qty']}', style: const TextStyle(fontSize: 12, color: UColors.textMid)),
                      if ('${item['note'] ?? ''}'.isNotEmpty)
                        Text('${item['note']}', style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                    ])),
                    UBadge('${item['status']}'),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════