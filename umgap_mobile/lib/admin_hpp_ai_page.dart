import 'package:flutter/material.dart';

import 'api_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMid = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kAccent = Color(0xFF00B0FF);
const _kSurface = Color(0xFFF4F7FF);
const _kTextDark = Color(0xFF0D1B3E);
const _kTextMid = Color(0xFF4A5568);
const _kTextLight = Color(0xFF90A4AE);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFE65100);
const _kDanger = Color(0xFFC62828);

class AdminHppAiPage extends StatefulWidget {
  const AdminHppAiPage({super.key});

  @override
  State<AdminHppAiPage> createState() => _AdminHppAiPageState();
}

class _AdminHppAiPageState extends State<AdminHppAiPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _productNameController = TextEditingController();
  final _batchSizeController = TextEditingController(text: '1');
  final _packagingCostController = TextEditingController(text: '0');
  final _overheadCostController = TextEditingController(text: '0');
  final _laborCostController = TextEditingController(text: '0');
  final _otherCostController = TextEditingController(text: '0');
  final _targetMarginController = TextEditingController(text: '30');
  final _desiredSellingPriceController = TextEditingController(text: '0');

  bool _loading = false;
  Map<String, dynamic>? _result;
  final List<Map<String, TextEditingController>> _items = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addItem(prefillName: 'Bahan Utama');
    _addItem(prefillName: 'Bahan Pendukung');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productNameController.dispose();
    _batchSizeController.dispose();
    _packagingCostController.dispose();
    _overheadCostController.dispose();
    _laborCostController.dispose();
    _otherCostController.dispose();
    _targetMarginController.dispose();
    _desiredSellingPriceController.dispose();
    for (final item in _items) {
      for (final c in item.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addItem({String prefillName = ''}) {
    setState(() {
      _items.add({
        'name': TextEditingController(text: prefillName),
        'qty': TextEditingController(text: '1'),
        'unit': TextEditingController(text: 'pcs'),
        'unit_cost': TextEditingController(text: '0'),
      });
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final removed = _items.removeAt(index);
    for (final c in removed.values) {
      c.dispose();
    }
    setState(() {});
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final items = _items.map((item) {
        return {
          'name': item['name']!.text.trim(),
          'qty': double.tryParse(item['qty']!.text.replaceAll(',', '.')) ?? 0,
          'unit': item['unit']!.text.trim().isEmpty ? 'pcs' : item['unit']!.text.trim(),
          'unit_cost': double.tryParse(item['unit_cost']!.text.replaceAll(',', '.')) ?? 0,
        };
      }).where((e) => (e['name'] as String).isNotEmpty).toList();

      if (items.isEmpty) {
        throw 'Minimal isi 1 bahan baku';
      }

      final result = await ApiService.calculateHppAi(
        productName: _productNameController.text.trim(),
        batchSize: int.tryParse(_batchSizeController.text) ?? 1,
        packagingCost: double.tryParse(_packagingCostController.text.replaceAll(',', '.')) ?? 0,
        overheadCost: double.tryParse(_overheadCostController.text.replaceAll(',', '.')) ?? 0,
        laborCost: double.tryParse(_laborCostController.text.replaceAll(',', '.')) ?? 0,
        otherCost: double.tryParse(_otherCostController.text.replaceAll(',', '.')) ?? 0,
        targetMarginPercent: double.tryParse(_targetMarginController.text.replaceAll(',', '.')) ?? 0,
        desiredSellingPrice: double.tryParse(_desiredSellingPriceController.text.replaceAll(',', '.')) ?? 0,
        items: items,
      );

      if (!mounted) return;
      setState(() => _result = result);
      _showSnack('Analisis HPP AI berhasil dibuat');
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal hitung HPP: $e', isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _kDanger : _kPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _rupiah(dynamic value) {
    final number = (value is num) ? value.toDouble() : double.tryParse('$value') ?? 0;
    final fixed = number.toStringAsFixed(number % 1 == 0 ? 0 : 2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final buffer = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    final whole = buffer.toString().split('').reversed.join();
    final decimal = parts.length > 1 && parts[1] != '00' ? ',${parts[1]}' : '';
    return 'Rp $whole$decimal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFormTab(), _buildInsightTab()],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: _kPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Bahan', style: TextStyle(color: Colors.white)),
      )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimaryDark, _kPrimary, _kPrimaryMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'HPP AI',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                tabs: const [
                  Tab(text: 'Kalkulator'),
                  Tab(text: 'Insight AI'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimaryDark, _kPrimaryMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: _kPrimary.withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Analisis Harga Pokok Produksi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(height: 2),
                    Text('Hitung HPP + insight AI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Cocok untuk admin sebelum tetapkan harga jual', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Informasi Produk'),
        const SizedBox(height: 10),
        _StyledTextField(controller: _productNameController, hint: 'Contoh: Roti Coklat Premium', icon: Icons.inventory_2_outlined),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StyledTextField(controller: _batchSizeController, hint: 'Batch size', icon: Icons.layers_outlined, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _StyledTextField(controller: _targetMarginController, hint: 'Margin %', icon: Icons.percent_rounded, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        _StyledTextField(controller: _desiredSellingPriceController, hint: 'Harga jual yang diinginkan', icon: Icons.sell_outlined, keyboardType: TextInputType.number),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Biaya Tambahan'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StyledTextField(controller: _packagingCostController, hint: 'Packaging', icon: Icons.all_inbox_rounded, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _StyledTextField(controller: _overheadCostController, hint: 'Overhead', icon: Icons.home_repair_service_rounded, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StyledTextField(controller: _laborCostController, hint: 'Tenaga kerja', icon: Icons.badge_outlined, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _StyledTextField(controller: _otherCostController, hint: 'Biaya lain', icon: Icons.more_horiz_rounded, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Bahan Baku'),
        const SizedBox(height: 10),
        ...List.generate(_items.length, (index) => _ingredientCard(index)),
        const SizedBox(height: 22),
        _GradientButton(label: 'Hitung HPP AI', onPressed: _loading ? null : _submit, loading: _loading),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _ingredientCard(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_basket_rounded, color: _kPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Bahan ${index + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
              ),
              if (_items.length > 1)
                GestureDetector(
                  onTap: () => _removeItem(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _kDanger.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: _kDanger, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _StyledTextField(controller: item['name']!, hint: 'Nama bahan', icon: Icons.edit_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StyledTextField(controller: item['qty']!, hint: 'Qty', icon: Icons.numbers_rounded, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _StyledTextField(controller: item['unit']!, hint: 'Unit', icon: Icons.straighten_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          _StyledTextField(controller: item['unit_cost']!, hint: 'Harga per unit', icon: Icons.payments_outlined, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildInsightTab() {
    if (_result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 60, color: _kPrimary.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text('Belum ada analisis HPP', style: TextStyle(color: _kTextMid)),
            const SizedBox(height: 6),
            const Text('Isi kalkulator lalu tekan Hitung HPP AI', style: TextStyle(color: _kTextLight, fontSize: 12)),
          ],
        ),
      );
    }

    final summary = Map<String, dynamic>.from(_result!['summary'] ?? {});
    final ai = Map<String, dynamic>.from(_result!['ai'] ?? {});
    final topCostItems = List<Map<String, dynamic>>.from(_result!['top_cost_items'] ?? const []);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _resultHero(summary),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Ringkasan Biaya'),
        const SizedBox(height: 10),
        _metricGrid(summary),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Komponen Biaya Terbesar'),
        const SizedBox(height: 10),
        ...topCostItems.map((item) => _topCostCard(item)),
        const SizedBox(height: 20),
        const _SectionHeader(title: 'Insight AI'),
        const SizedBox(height: 10),
        _aiSummaryCard(ai),
        const SizedBox(height: 10),
        _bulletCard('Saran Optimasi', Icons.lightbulb_outline_rounded, _kSuccess, List<String>.from(ai['suggestions'] ?? const [])),
        const SizedBox(height: 10),
        _bulletCard('Risiko yang Perlu Dicek', Icons.warning_amber_rounded, _kWarning, List<String>.from(ai['risks'] ?? const [])),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _resultHero(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimaryDark, _kPrimaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rekomendasi Harga', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            _rupiah(summary['recommended_selling_price']),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'HPP / unit ${_rupiah(summary['hpp_per_unit'])} • Margin estimasi ${summary['estimated_margin_percent'] ?? 0}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(Map<String, dynamic> summary) {
    final cards = [
      {'label': 'Bahan Baku', 'value': _rupiah(summary['total_material_cost']), 'icon': Icons.shopping_basket_rounded, 'color': _kPrimary},
      {'label': 'Total Biaya', 'value': _rupiah(summary['total_cost']), 'icon': Icons.account_balance_wallet_rounded, 'color': _kWarning},
      {'label': 'Profit / Unit', 'value': _rupiah(summary['estimated_profit_per_unit']), 'icon': Icons.trending_up_rounded, 'color': _kSuccess},
      {'label': 'Harga Jual Input', 'value': _rupiah(summary['desired_selling_price']), 'icon': Icons.sell_rounded, 'color': _kAccent},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MiniStatCard(label: cards[0]['label'] as String, value: cards[0]['value'] as String, icon: cards[0]['icon'] as IconData, color: cards[0]['color'] as Color)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStatCard(label: cards[1]['label'] as String, value: cards[1]['value'] as String, icon: cards[1]['icon'] as IconData, color: cards[1]['color'] as Color)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MiniStatCard(label: cards[2]['label'] as String, value: cards[2]['value'] as String, icon: cards[2]['icon'] as IconData, color: cards[2]['color'] as Color)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStatCard(label: cards[3]['label'] as String, value: cards[3]['value'] as String, icon: cards[3]['icon'] as IconData, color: cards[3]['color'] as Color)),
          ],
        ),
      ],
    );
  }

  Widget _topCostCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 56,
            decoration: BoxDecoration(color: _kWarning, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['name'] ?? '-'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
                const SizedBox(height: 4),
                Text('${item['qty'] ?? 0} ${item['unit'] ?? ''} × ${_rupiah(item['unit_cost'])}', style: const TextStyle(fontSize: 12, color: _kTextMid)),
              ],
            ),
          ),
          Text(_rupiah(item['subtotal']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kWarning)),
        ],
      ),
    );
  }

  Widget _aiSummaryCard(Map<String, dynamic> ai) {
    final available = ai['available'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: available
              ? [const Color(0xFFE3F2FD), const Color(0xFFF3F8FF)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFF8F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (available ? _kPrimary : _kWarning).withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (available ? _kPrimary : _kWarning).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(available ? Icons.auto_awesome_rounded : Icons.info_outline_rounded, color: available ? _kPrimary : _kWarning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(available ? 'Insight OpenAI Aktif' : 'Fallback Insight Lokal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: available ? _kPrimaryDark : _kWarning)),
                const SizedBox(height: 6),
                Text('${ai['summary'] ?? '-'}', style: const TextStyle(fontSize: 13, color: _kTextMid, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletCard(String title, IconData icon, Color color, List<String> items) {
    final list = items.isEmpty ? ['Belum ada data.'] : items;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ...list.map((text) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: _kTextMid, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimaryDark, _kAccent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kPrimaryDark)),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
        prefixIcon: Icon(icon, color: _kPrimary, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimaryMid, width: 1.5)),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const _GradientButton({required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)])
              : const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null ? [] : [BoxShadow(color: _kPrimary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: _kTextMid, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
