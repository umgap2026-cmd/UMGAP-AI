import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'u_kit.dart';

// ════════════════════════════════════════════
//  CAPTION AI — generate caption produk (OpenAI),
//  mirror /caption di web (templates/caption.html
//  bagian "Caption AI").
// ════════════════════════════════════════════
class CaptionAiPage extends StatefulWidget {
  const CaptionAiPage({super.key});
  @override
  State<CaptionAiPage> createState() => _CaptionAiPageState();
}

class _CaptionAiPageState extends State<CaptionAiPage> {
  final _productCtrl = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _brandCtrl   = TextEditingController();
  final _notesCtrl   = TextEditingController();

  String _platform = 'Instagram';
  String _style    = 'Santai';
  bool   _loading  = false;
  List<String> _variants = [];

  static const _platforms = ['Instagram', 'TikTok', 'WhatsApp'];
  static const _styles    = ['Santai', 'Promo', 'Storytelling', 'Serius'];

  @override
  void dispose() {
    _productCtrl.dispose(); _priceCtrl.dispose();
    _brandCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_productCtrl.text.trim().isEmpty) {
      uSnack(context, 'Nama produk wajib diisi', isError: true);
      return;
    }
    setState(() { _loading = true; _variants = []; });
    try {
      final caption = await ApiService.generateCaptionAi(
        product: _productCtrl.text.trim(),
        price: _priceCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        platform: _platform,
        style: _style,
        notes: _notesCtrl.text.trim(),
      );
      final parts = caption
          .split(RegExp(r'─+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _variants = parts.isEmpty ? [caption.trim()] : parts);
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    uSnack(context, 'Caption disalin ✓');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: const UAppBar(title: '✨ Caption AI'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _Card(children: [
            UField(controller: _productCtrl, label: 'Nama Produk *',
                hint: 'Contoh: Kabel Tembaga BC 2.5mm', prefixIcon: Icons.inventory_2_rounded),
            const SizedBox(height: 12),
            UField(controller: _priceCtrl, label: 'Harga (opsional)',
                hint: 'Contoh: 150000', prefixIcon: Icons.payments_rounded,
                keyboard: TextInputType.number),
            const SizedBox(height: 12),
            UField(controller: _brandCtrl, label: 'Brand / Toko (opsional)',
                hint: 'Contoh: ARV LOGAM', prefixIcon: Icons.storefront_rounded),
            const SizedBox(height: 14),
            const Text('Platform', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: UColors.textMid)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _platforms.map((p) =>
                _Chip(label: p, active: _platform == p,
                    onTap: () => setState(() => _platform = p))).toList()),
            const SizedBox(height: 14),
            const Text('Gaya Penulisan', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: UColors.textMid)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _styles.map((s) =>
                _Chip(label: s, active: _style == s,
                    onTap: () => setState(() => _style = s))).toList()),
            const SizedBox(height: 12),
            UField(controller: _notesCtrl, label: 'Catatan Pendukung (opsional)',
                hint: 'Contoh: stok terbatas, promo akhir bulan',
                prefixIcon: Icons.note_alt_outlined, maxLines: 2),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                  backgroundColor: UColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Generate Caption', style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 15)),
                    ]),
            ),
          ),
          if (_variants.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Hasil', style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: UColors.textDark)),
            const SizedBox(height: 10),
            for (int i = 0; i < _variants.length; i++) ...[
              _Card(children: [
                Row(children: [
                  Expanded(child: Text('Versi ${i + 1}', style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: UColors.primary))),
                  GestureDetector(
                    onTap: () => _copy(_variants[i]),
                    child: const Icon(Icons.copy_rounded, size: 18, color: UColors.primary),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(_variants[i], style: const TextStyle(fontSize: 13,
                    color: UColors.textDark, height: 1.5)),
              ]),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 14, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Chip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? UColors.primary : UColors.inputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? UColors.primary : UColors.primary.withOpacity(0.15)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Colors.white : UColors.textMid)),
    ),
  );
}
