import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';
import 'invoice_print_page.dart';

// ── Responsive font size ──────────────────────────────────────
double _rfs(BuildContext context, double base) {
  final w = MediaQuery.of(context).size.width;
  if (w < 360) return base * 0.88;
  if (w > 430) return base * 1.08;
  return base;
}

// ════════════════════════════════════════════
//  Storage helpers — flutter_secure_storage
// ════════════════════════════════════════════
const _notaStorage = FlutterSecureStorage();

Future<void> saveNotaSetting(String key, String value) =>
    value.isEmpty
        ? _notaStorage.delete(key: key)
        : _notaStorage.write(key: key, value: value);

Future<String> readNotaSetting(String key) async =>
    await _notaStorage.read(key: key) ?? '';

// ── Storage keys ──────────────────────────────
const kNotaName  = 'nota_company_name';
const kNotaAddr  = 'nota_company_addr';
const kNotaPhone = 'nota_company_phone';
const kNotaLogo  = 'nota_logo_path';

// ── Colors ─────────────────────────────────────
const _cJualDark  = Color(0xFF0D47A1);
const _cJualMid   = Color(0xFF1565C0);
const _cJualLight = Color(0xFF1E88E5);
const _cBeliDark  = Color(0xFF00695C);
const _cBeliMid   = Color(0xFF00796B);
const _cBeliLight = Color(0xFF00897B);

// ════════════════════════════════════════════
//  MODEL
// ════════════════════════════════════════════
class CartItem {
  final int    productId;
  final String productName;
  final int    price;
  final double qty;

  double get subtotal => price * qty;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
  });

  CartItem copyWith({double? qty, int? price}) => CartItem(
    productId:   productId,
    productName: productName,
    price:       price ?? this.price,
    qty:         qty   ?? this.qty,
  );
}

String _fmtQty(double q) =>
    q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

String _rp(num v) {
  if (v == 0) return 'Rp -';
  final abs = v.abs();
  final neg = v < 0 ? '-' : '';
  return '$neg Rp ${abs.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

// ════════════════════════════════════════════
//  INVOICE PAGE
// ════════════════════════════════════════════
class InvoicePage extends StatefulWidget {
  final String?         initName;
  final String?         initPhone;
  final String?         initPayMethod;
  final String?         initNotes;
  final double?         initDiscount;
  final bool?           initIsPaid;
  final List<CartItem>? initCart;

  const InvoicePage({
    super.key,
    this.initName,
    this.initPhone,
    this.initPayMethod,
    this.initNotes,
    this.initDiscount,
    this.initIsPaid,
    this.initCart,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage>
    with SingleTickerProviderStateMixin {
  bool _loading    = true;
  bool _submitting = false;

  // ── Mode: false = JUAL, true = BELI ──────────
  bool _isBeli = false;

  // Animasi transisi mode
  late AnimationController _modeAnim;
  late Animation<double>   _modeProgress;

  List<dynamic> _materials = [];
  int?          _selId;

  final _qtyCtrl   = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _discCtrl;

  late String       _payMethod;
  late bool         _isPaid;
  late List<CartItem> _cart;

  // ── Color helpers ─────────────────────────────
  Color get _colorDark  => _isBeli ? _cBeliDark  : _cJualDark;
  Color get _colorMid   => _isBeli ? _cBeliMid   : _cJualMid;
  Color get _colorLight => _isBeli ? _cBeliLight : _cJualLight;

  @override
  void initState() {
    super.initState();
    _modeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _modeProgress = CurvedAnimation(
        parent: _modeAnim, curve: Curves.easeInOut);

    _nameCtrl  = TextEditingController(text: widget.initName  ?? '');
    _phoneCtrl = TextEditingController(text: widget.initPhone ?? '');
    _notesCtrl = TextEditingController(text: widget.initNotes ?? '');
    _discCtrl  = TextEditingController(
        text: (widget.initDiscount ?? 0).toInt().toString());
    _payMethod = widget.initPayMethod ?? 'CASH';
    _isPaid    = widget.initIsPaid   ?? true;
    _cart      = List<CartItem>.from(widget.initCart ?? []);

    _qtyCtrl.addListener(  () => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _discCtrl.addListener( () => setState(() {}));

    // Auto-save draft setiap field berubah
    _nameCtrl.addListener(_saveDraft);
    _phoneCtrl.addListener(_saveDraft);
    _notesCtrl.addListener(_saveDraft);
    _discCtrl.addListener(_saveDraft);

    // Load materials lalu cek draft (hanya jika bukan dari initCart)
    _loadMaterials().then((_) {
      if (widget.initCart == null || widget.initCart!.isEmpty) {
        _loadDraft();
      }
    });
  }

  @override
  void dispose() {
    _modeAnim.dispose();
    _qtyCtrl.dispose();  _priceCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _notesCtrl.dispose(); _discCtrl.dispose();
    super.dispose();
  }

  void _switchMode(bool toBeli) {
    if (_isBeli == toBeli) return;
    setState(() => _isBeli = toBeli);
    if (toBeli) _modeAnim.forward(); else _modeAnim.reverse();
    // Reset keranjang saat ganti mode (harga beli ≠ harga jual)
    if (_cart.isNotEmpty) {
      uSnack(context, 'Mode diganti — keranjang direset');
      setState(() {
        _cart.clear();
        _priceCtrl.clear();
        _qtyCtrl.text = '1';
      });
      _saveDraft();
    }
  }

  // ══════════════════════════════════════════════
  //  DRAFT — Auto-save & restore
  // ══════════════════════════════════════════════
  static const _kDraft = 'invoice_draft_v1';

  Future<void> _saveDraft() async {
    // Tidak perlu simpan kalau kosong
    if (_cart.isEmpty &&
        _nameCtrl.text.isEmpty &&
        _phoneCtrl.text.isEmpty) {
      await _notaStorage.delete(key: _kDraft);
      return;
    }
    try {
      final draft = {
        'name':    _nameCtrl.text,
        'phone':   _phoneCtrl.text,
        'notes':   _notesCtrl.text,
        'disc':    _discCtrl.text,
        'pay':     _payMethod,
        'isPaid':  _isPaid,
        'isBeli':  _isBeli,
        'savedAt': DateTime.now().toIso8601String(),
        'cart':    _cart.map((c) => {
          'id':    c.productId,
          'name':  c.productName,
          'price': c.price,
          'qty':   c.qty,
        }).toList(),
      };
      await _notaStorage.write(
          key: _kDraft, value: jsonEncode(draft));
    } catch (_) {}
  }

  Future<void> _loadDraft() async {
    try {
      final raw = await _notaStorage.read(key: _kDraft);
      if (raw == null || raw.isEmpty || !mounted) return;

      final d = jsonDecode(raw) as Map<String, dynamic>;
      final cartData = d['cart'] as List? ?? [];
      if (cartData.isEmpty && (d['name'] ?? '').toString().isEmpty) return;

      final draftCart = cartData.map((i) => CartItem(
        productId:   (i['id'] as num).toInt(),
        productName: i['name'] as String,
        price:       (i['price'] as num).toInt(),
        qty:         (i['qty'] as num).toDouble(),
      )).toList();

      final savedAt = DateTime.tryParse(d['savedAt'] ?? '');
      final timeStr = savedAt != null
          ? '${savedAt.day}/${savedAt.month} '
          '${savedAt.hour.toString().padLeft(2,'0')}:'
          '${savedAt.minute.toString().padLeft(2,'0')}'
          : '';

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.restore_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Expanded(child: Text('Ada Draft Tersimpan')),
          ]),
          content: Text(
            'Nota belum selesai dari $timeStr\n'
                '${draftCart.length} barang'
                '${(d['name'] ?? '').toString().isNotEmpty ? ' — ${d['name']}' : ''}\n\n'
                'Lanjut dari draft atau buat nota baru?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _clearDraft();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Buang',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _nameCtrl.text  = d['name']  ?? '';
                  _phoneCtrl.text = d['phone'] ?? '';
                  _notesCtrl.text = d['notes'] ?? '';
                  _discCtrl.text  = d['disc']  ?? '0';
                  _payMethod      = d['pay']   ?? 'CASH';
                  _isPaid         = d['isPaid'] ?? true;
                  final isBeli    = d['isBeli'] ?? false;
                  _isBeli         = isBeli;
                  if (isBeli) _modeAnim.forward();
                  _cart           = draftCart;
                });
              },
              child: const Text('Lanjut Draft',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (_) {
      await _clearDraft();
    }
  }

  Future<void> _clearDraft() async {
    try { await _notaStorage.delete(key: _kDraft); } catch (_) {}
  }

  // ── Load materials ─────────────────────────────
  Future<void> _loadMaterials() async {
    // Cache dulu — tampil instant
    final cached = await CacheService.get(CacheService.kMaterials);
    if (cached != null && mounted) {
      final mats = List<dynamic>.from(cached['materials'] ?? []);
      if (mats.isNotEmpty) {
        setState(() { _materials = mats; _loading = false; });
      }
    }
    // Background refresh
    try {
      final data = await ApiService.financeGetMaterials();
      if (!mounted) return;

      List<dynamic> mats = [];
      if (data['materials'] != null)
        mats = List<dynamic>.from(data['materials']);
      else if (data['items'] != null)
        mats = List<dynamic>.from(data['items']);
      else if (data['data'] != null)
        mats = List<dynamic>.from(data['data']);

      if (mats.isEmpty && _materials.isEmpty)
        throw 'Tidak ada data barang di gudang';

      await CacheService.set(CacheService.kMaterials, data);
      setState(() { _materials = mats; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_materials.isEmpty)
        uSnack(context, 'Gagal muat barang: $e', isError: true);
    }
  }

  // ── Helpers ────────────────────────────────────
  Map<String, dynamic>? get _selMat {
    if (_selId == null || _materials.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(_materials.firstWhere((m) {
        final mId = int.tryParse('${m['id']}') ?? m['id'];
        return mId == _selId || mId.toString() == _selId.toString();
      }));
    } catch (_) { return null; }
  }

  int    get _manualPrice => int.tryParse(
      _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _previewQty  => double.tryParse(_qtyCtrl.text.trim()) ?? 0;
  double get _previewSub  => _manualPrice * _previewQty;
  double get _subtotal    => _cart.fold(0.0, (s, c) => s + c.subtotal);
  double get _disc        =>
      _isBeli ? 0 : (double.tryParse(_discCtrl.text.trim()) ?? 0);
  double get _total       => (_subtotal - _disc).clamp(0, double.infinity);

  // ── Kontak ─────────────────────────────────────
  Future<void> _pickContact() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (!mounted) return;
        uSnack(context, 'Izin kontak ditolak', isError: true);
        return;
      }
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;
      final full = await FlutterContacts.getContact(contact.id,
          withProperties: true);
      if (full == null || !mounted) return;
      final phone = full.phones.isNotEmpty
          ? full.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '') : '';
      setState(() {
        if (_nameCtrl.text.isEmpty && full.displayName.isNotEmpty)
          _nameCtrl.text = full.displayName;
        if (phone.isNotEmpty) _phoneCtrl.text = phone;
      });
    } catch (_) { await _inputContactManual(); }
  }

  Future<void> _inputContactManual() async {
    final nC = TextEditingController(text: _nameCtrl.text);
    final pC = TextEditingController(text: _phoneCtrl.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: UColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          Text(_isBeli ? 'Info Supplier' : 'Info Customer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: nC,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: _isBeli ? 'Nama Supplier' : 'Nama Customer',
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: UColors.inputBg)),
          const SizedBox(height: 12),
          TextField(controller: pC,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'No. HP',
                  prefixIcon: const Icon(Icons.phone_rounded),
                  hintText: '08xxxxxxxxxx',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: UColors.inputBg)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _colorMid,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                setState(() {
                  _nameCtrl.text  = nC.text.trim();
                  _phoneCtrl.text = pC.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('Simpan', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Tambah Barang Baru ke Gudang ───────────────
  Future<void> _addNewMaterial() async {
    final nameCtrl  = TextEditingController();
    final unitCtrl  = TextEditingController(text: 'kg');
    final qtyCtrl   = TextEditingController();
    final priceCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          bool saving = false;
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: bottom + 24, left: 20, right: 20, top: 6),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 18),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _colorMid.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.add_box_rounded,
                        color: _colorMid, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tambah Barang Baru', style: TextStyle(
                        fontSize: _rfs(ctx, 16), fontWeight: FontWeight.w800)),
                    Text('Langsung masuk ke stok gudang', style: TextStyle(
                        fontSize: _rfs(ctx, 11),
                        color: const Color(0xFF90A4AE))),
                  ])),
                ]),
                const SizedBox(height: 20),

                // Nama
                _NewMatField(controller: nameCtrl,
                    label: 'Nama Barang *',
                    hint: 'Contoh: BC, TM, Ayam KW1',
                    icon: Icons.label_rounded,
                    color: _colorMid, autofocus: true),
                const SizedBox(height: 12),

                // Satuan
                _NewMatField(controller: unitCtrl,
                    label: 'Satuan',
                    hint: 'kg / liter / pcs',
                    icon: Icons.straighten_rounded,
                    color: _colorMid),
                const SizedBox(height: 16),

                // Stok awal
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Stok Awal (opsional)', style: TextStyle(
                        fontSize: _rfs(ctx, 11),
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _NewMatField(controller: qtyCtrl,
                      label: 'Jumlah Awal', hint: '0',
                      icon: Icons.inventory_2_rounded, color: _colorMid,
                      keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 10),
                  Expanded(child: _NewMatField(controller: priceCtrl,
                      label: _isBeli ? 'Harga Beli/kg' : 'HPP/kg',
                      hint: '0',
                      icon: Icons.price_check_rounded, color: _colorMid,
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                ]),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final name  = nameCtrl.text.trim();
                      final unit  = unitCtrl.text.trim().isEmpty
                          ? 'kg' : unitCtrl.text.trim();
                      final qty   = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      if (name.isEmpty) {
                        uSnack(context, 'Nama barang wajib diisi', isError: true);
                        return;
                      }
                      if (qty > 0 && price <= 0) {
                        uSnack(context,
                            'Harga beli wajib diisi jika ada stok awal',
                            isError: true);
                        return;
                      }
                      setS(() => saving = true);
                      try {
                        final result = await ApiService.financeAddMaterial(
                          name: name, unit: unit,
                          initQty: qty, initPrice: price,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          uSnack(context,
                              '✓ Barang "$name" ditambahkan ke gudang');
                          // Reload materials dan auto-pilih barang baru
                          await _loadMaterials();
                          final newId = result['material_id'] as int?;
                          if (newId != null && mounted) {
                            setState(() => _selId = newId);
                            // Auto-isi harga jika ada
                            if (price > 0 && _priceCtrl.text.isEmpty) {
                              _priceCtrl.text = '$price';
                            }
                          }
                        }
                      } catch (e) {
                        if (mounted) uSnack(context, e.toString(), isError: true);
                        setS(() => saving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _colorMid,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    child: saving
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                        : Row(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Simpan & Pilih Barang', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: _rfs(ctx, 14))),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Pengaturan Nota ────────────────────────────
  Future<void> _openNotaSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotaSettingsSheet(),
    );
  }

  // ── Tambah ke keranjang ────────────────────────
  void _addToCart() {
    if (_selMat == null) {
      uSnack(context, 'Pilih barang dulu', isError: true); return;
    }
    if (_previewQty <= 0) {
      uSnack(context, 'Qty harus lebih dari 0', isError: true); return;
    }
    if (_manualPrice <= 0) {
      uSnack(context,
          _isBeli ? 'Masukkan harga beli dulu' : 'Masukkan harga jual dulu',
          isError: true);
      return;
    }
    setState(() {
      final id  = int.tryParse('${_selMat!['id']}') ?? 0;
      final idx = _cart.indexWhere(
              (c) => c.productId == id && c.price == _manualPrice);
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + _previewQty);
      } else {
        _cart.add(CartItem(
          productId:   id,
          productName:
          '${_selMat!['name'] ?? _selMat!['material_name'] ?? 'Barang'}',
          price:       _manualPrice,
          qty:         _previewQty,
        ));
      }
      _qtyCtrl.text = '1';
      _priceCtrl.clear();
    });
    _saveDraft();
  }

  // ── Edit item ──────────────────────────────────
  Future<void> _editItem(int idx) async {
    final qC = TextEditingController(text: _fmtQty(_cart[idx].qty));
    final pC = TextEditingController(text: '${_cart[idx].price}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: Text(_cart[idx].productName,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: qC, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(labelText: 'Jumlah (kg)',
                  filled: true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 10),
          TextField(controller: pC,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                  labelText: _isBeli ? 'Harga Beli/kg' : 'Harga Jual/kg',
                  filled: true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _colorMid),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    final q = double.tryParse(qC.text.trim()) ?? 0;
    final p = int.tryParse(pC.text.trim()) ?? 0;
    setState(() {
      if (q <= 0) _cart.removeAt(idx);
      else _cart[idx] = _cart[idx].copyWith(
          qty: q, price: p > 0 ? p : null);
    });
    _saveDraft();
  }

  // ══════════════════════════════════════════════
  //  SUBMIT JUAL → createInvoice → print page
  // ══════════════════════════════════════════════
  Future<void> _submitJual() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      uSnack(context, 'Nama customer wajib diisi', isError: true); return;
    }
    setState(() => _submitting = true);

    // Generate nomor nota lokal — backend baru dipanggil saat
    // user pencet "Kirim ke DB" di print page
    final now = DateTime.now();
    final noNota = 'INV-'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    final snap  = List<CartItem>.from(_cart);
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pay   = _payMethod;
    final notes = _notesCtrl.text.trim();
    final disc  = _disc;
    final sub   = _subtotal;
    final total = _total;
    final paid  = _isPaid;

    // Hapus draft & reset form
    await _clearDraft();
    setState(() {
      _cart.clear(); _nameCtrl.clear(); _phoneCtrl.clear();
      _notesCtrl.clear(); _discCtrl.text = '0';
      _payMethod = 'CASH'; _isPaid = true; _submitting = false;
    });

    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => InvoicePrintPage(
        invoiceId:     0,
        invoiceNo:     noNota,
        customerName:  name,
        customerPhone: phone,
        paymentMethod: pay,
        notes:         notes,
        discount:      disc,
        subtotal:      sub,
        grandTotal:    total,
        items:         snap,
        isPaid:        paid,
        isBeli:        false,
      ),
    ));
  }

  // ══════════════════════════════════════════════
  //  SUBMIT BELI → financeBeli → tambah stok + HPP
  // ══════════════════════════════════════════════
  // ══════════════════════════════════════════════
  //  SUBMIT BELI → langsung ke print page
  //  Simpan ke database MANUAL dari print page
  // ══════════════════════════════════════════════
  Future<void> _submitBeli() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    setState(() => _submitting = true);
    try {
      // Kumpulkan semua data SEBELUM clear
      final snap      = List<CartItem>.from(_cart);
      final beliItems = _cart.map((c) => {
        'material_id':  c.productId,
        'qty_kg':       c.qty,
        'price_per_kg': c.price,
      }).toList();
      final supplier  = _nameCtrl.text.trim();
      final phone     = _phoneCtrl.text.trim();
      final notes     = _notesCtrl.text.trim();
      final sub       = _subtotal;
      final paid      = _isPaid;

      // Generate nomor nota beli lokal
      final now = DateTime.now();
      final noNota = 'BELI-'
          '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      // Reset form
      await _clearDraft();
      setState(() {
        _cart.clear(); _nameCtrl.clear(); _phoneCtrl.clear();
        _notesCtrl.clear(); _isPaid = true; _submitting = false;
        _priceCtrl.clear(); _qtyCtrl.text = '1'; _selId = null;
      });

      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InvoicePrintPage(
          invoiceId:     0,
          invoiceNo:     noNota,
          customerName:  supplier.isNotEmpty ? supplier : 'Supplier',
          customerPhone: phone,
          paymentMethod: paid ? 'LUNAS' : 'BELUM LUNAS',
          notes:         notes,
          discount:      0,
          subtotal:      sub,
          grandTotal:    sub,
          items:         snap,
          isPaid:        paid,
          isBeli:        true,
          beliRawItems:  beliItems,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
      setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: UColors.surface,
        appBar: UAppBar(title: 'Nota Transaksi'),
        body: const Center(
            child: CircularProgressIndicator(color: UColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: UAppBar(title: 'Nota Transaksi'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ══════════════════════════════════════
          //  BANNER + MODE SWITCHER
          // ══════════════════════════════════════
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 200) _switchMode(true);   // geser kanan → BELI
              if (v < -200) _switchMode(false);  // geser kiri  → JUAL
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_colorDark, _colorLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(
                    color: _colorMid.withOpacity(0.30),
                    blurRadius: 18, offset: const Offset(0, 7))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        _isBeli
                            ? Icons.shopping_basket_rounded
                            : Icons.receipt_long_rounded,
                        color: Colors.white, size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBeli
                                ? 'Nota Pembelian'
                                : 'Nota Penjualan',
                            style: const TextStyle(color: Colors.white70,
                                fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _isBeli
                                  ? 'Catat & Tambah Stok'
                                  : 'Buat & Cetak Langsung',
                              key: ValueKey(_isBeli),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isBeli
                                ? 'Stok & HPP diperbarui otomatis'
                                : 'Thermal 58/80mm · Bluetooth · PDF',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10),
                          ),
                        ])),
                    // ── Tombol Pengaturan Nota ──
                    GestureDetector(
                      onTap: _openNotaSettings,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3))),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(height: 2),
                            Text('Nota', style: TextStyle(
                                color: Colors.white, fontSize: 7,
                                fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── MODE TOGGLE ──────────────
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      _ModeTab(
                        label: '← JUAL',
                        icon: Icons.sell_rounded,
                        active: !_isBeli,
                        onTap: () => _switchMode(false),
                      ),
                      _ModeTab(
                        label: 'BELI →',
                        icon: Icons.add_shopping_cart_rounded,
                        active: _isBeli,
                        onTap: () => _switchMode(true),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _isBeli
                          ? 'Geser kiri untuk Nota Jual'
                          : 'Geser kanan untuk Nota Beli',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ══════════════════════════════════════
          //  INFO CUSTOMER / SUPPLIER
          // ══════════════════════════════════════
          USectionHeader(
              title: _isBeli ? 'Info Supplier' : 'Info Customer'),
          const SizedBox(height: 12),
          _InvCard(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: UField(
                controller: _nameCtrl,
                label: _isBeli
                    ? 'Nama Supplier (opsional)'
                    : 'Nama Customer *',
                hint: _isBeli ? 'Pak Budi / Agen' : 'Budi Santoso',
                prefixIcon: _isBeli
                    ? Icons.store_rounded
                    : Icons.person_rounded,
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickContact,
                child: Container(
                  height: 52, width: 52,
                  decoration: BoxDecoration(
                    color: _colorMid.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _colorMid.withOpacity(0.2)),
                  ),
                  child: Icon(
                    _isBeli
                        ? Icons.contacts_rounded
                        : Icons.person_add_rounded,
                    color: _colorMid, size: 22,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            UField(
              controller: _phoneCtrl,
              label: _isBeli ? 'No. HP Supplier (opsional)' : 'No. HP (opsional)',
              hint: '08xxxxxxxxxx',
              prefixIcon: Icons.phone_rounded,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Status lunas / hutang
            Row(children: [
              Expanded(child: Text(
                _isBeli ? 'Status Bayar ke Supplier' : 'Status Pembayaran',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UColors.textMid),
              )),
              GestureDetector(
                onTap: () => setState(() => _isPaid = !_isPaid),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_isPaid ? UColors.success : UColors.warning)
                        .withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _isPaid ? UColors.success : UColors.warning),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _isPaid
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      color: _isPaid
                          ? UColors.success : UColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPaid
                          ? (_isBeli ? 'SUDAH BAYAR' : 'LUNAS')
                          : (_isBeli ? 'BELUM BAYAR' : 'BELUM LUNAS'),
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _isPaid
                              ? UColors.success : UColors.warning),
                    ),
                  ]),
                ),
              ),
            ]),

            // Metode pembayaran — HANYA untuk JUAL
            if (!_isBeli) ...[
              const SizedBox(height: 14),
              const Text('Metode Pembayaran', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: UColors.textMid)),
              const SizedBox(height: 8),
              Row(children: [
                for (final m in [
                  {'v': 'CASH',     'l': 'Tunai',
                    'i': Icons.money},
                  {'v': 'TRANSFER', 'l': 'Transfer',
                    'i': Icons.account_balance_rounded},
                  {'v': 'QRIS',     'l': 'QRIS',
                    'i': Icons.qr_code_scanner_rounded},
                ])
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() =>
                    _payMethod = m['v'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: EdgeInsets.only(
                          right: m['v'] != 'QRIS' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _payMethod == m['v']
                            ? UColors.primary : UColors.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _payMethod == m['v']
                              ? UColors.primary
                              : UColors.primary.withOpacity(0.12),
                        ),
                      ),
                      child: Column(children: [
                        Icon(m['i'] as IconData,
                            color: _payMethod == m['v']
                                ? Colors.white : UColors.textMid,
                            size: 20),
                        const SizedBox(height: 4),
                        Text(m['l'] as String, style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _payMethod == m['v']
                                ? Colors.white : UColors.textMid)),
                      ]),
                    ),
                  )),
              ]),
            ],
          ]),
          const SizedBox(height: 20),

          // ══════════════════════════════════════
          //  TAMBAH BARANG
          // ══════════════════════════════════════
          USectionHeader(
              title: _isBeli ? 'Barang yang Dibeli' : 'Tambah Barang'),
          const SizedBox(height: 12),
          _InvCard(children: [
            const Text('Nama Barang', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: UColors.textMid)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: UColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _colorMid.withOpacity(0.18))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _materials.any((m) =>
                  (int.tryParse('${m['id']}') ?? 0) == _selId)
                      ? _selId : null,
                  isExpanded: true,
                  hint: const Text('Pilih barang'),
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: _colorMid),
                  items: _materials.map((m) {
                    final id   = int.tryParse('${m['id']}') ?? 0;
                    final nm   = '${m['name'] ?? m['material_name'] ?? '-'}';
                    final stok = double.tryParse(
                        '${m['qty_kg'] ?? m['stock'] ?? 0}') ?? 0.0;
                    // Untuk BELI: tampilkan stok saat ini (info)
                    // Untuk JUAL: stok harus cukup
                    final stokStr = '${stok.toStringAsFixed(1)} kg';
                    final stokColor = _isBeli
                        ? _colorMid
                        : (stok > 0 ? UColors.success : UColors.danger);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Row(children: [
                        Expanded(child: Text(nm,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stokColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(stokStr, style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: stokColor)),
                        ),
                      ]),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selId = v),
                ),
              ),
            ),

            // Tombol tambah barang baru
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: GestureDetector(
                onTap: _addNewMaterial,
                child: Row(children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: _colorMid, size: _rfs(context, 14)),
                  const SizedBox(width: 5),
                  Text(
                    'Barang belum ada? Tambah barang baru',
                    style: TextStyle(
                        fontSize: _rfs(context, 11),
                        color: _colorMid,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),

            // Info stok
            if (_selMat != null) Builder(builder: (_) {
              final stok = double.tryParse(
                  '${_selMat!['qty_kg'] ?? _selMat!['stock'] ?? 0}') ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(
                    _isBeli ? Icons.add_box_rounded : Icons.inventory_2_rounded,
                    color: _isBeli ? _colorMid : UColors.success,
                    size: _rfs(context, 13),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isBeli
                        ? 'Stok saat ini: ${stok.toStringAsFixed(1)} kg → akan bertambah'
                        : 'Stok tersedia: ${stok.toStringAsFixed(1)} kg',
                    style: TextStyle(
                        fontSize: _rfs(context, 11),
                        color: _isBeli ? _colorMid : UColors.success,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              );
            }),

            // Harga
            UField(
              controller: _priceCtrl,
              label: _isBeli ? 'Harga Beli / kg *' : 'Harga Jual / kg *',
              hint: 'Contoh: 150000',
              prefixIcon: _isBeli
                  ? Icons.price_check_rounded
                  : Icons.price_change_rounded,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 12),

            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jumlah (kg)', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: UColors.textMid)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: UColors.textDark),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: Icon(Icons.numbers_rounded,
                          color: _colorMid, size: 18),
                      suffixText: (_previewQty > 0 && _manualPrice > 0)
                          ? '= ${_rp(_previewSub)}' : null,
                      suffixStyle: TextStyle(fontSize: 12,
                          color: _colorMid,
                          fontWeight: FontWeight.w700),
                      filled: true, fillColor: UColors.inputBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: _colorMid.withOpacity(0.18))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: _colorMid.withOpacity(0.18))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: _colorMid, width: 1.5)),
                    ),
                  ),
                ],
              )),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _addToCart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 50, width: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_colorDark, _colorLight]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: _colorMid.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isBeli
                            ? Icons.add_shopping_cart_rounded
                            : Icons.add_shopping_cart_rounded,
                        color: Colors.white, size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text('Tambah', style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 20),

          // ══════════════════════════════════════
          //  KERANJANG
          // ══════════════════════════════════════
          Row(children: [
            Expanded(child: USectionHeader(
                title: _isBeli ? 'Daftar Barang Beli' : 'Keranjang')),
            if (_cart.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() => _cart.clear());
                  _saveDraft();
                },
                child: const Text('Hapus Semua', style: TextStyle(
                    fontSize: 12, color: UColors.danger,
                    fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 12),

          if (_cart.isEmpty)
            Container(
              height: 80,
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _colorMid.withOpacity(0.10))),
              child: Center(child: Column(
                  mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _isBeli
                      ? Icons.shopping_basket_outlined
                      : Icons.shopping_cart_outlined,
                  color: UColors.textLight, size: 26,
                ),
                const SizedBox(height: 5),
                Text(
                  _isBeli ? 'Belum ada barang beli' : 'Belum ada barang',
                  style: const TextStyle(color: UColors.textLight,
                      fontSize: 12),
                ),
              ])),
            )
          else
            Container(
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: _colorMid.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4))]),
              child: Column(children: [
                ...List.generate(_cart.length, (i) {
                  final item = _cart[i];
                  return Column(children: [
                    if (i > 0) Divider(height: 1,
                        color: _colorMid.withOpacity(0.08)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(children: [
                        Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                                color: _colorMid.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: Center(child: Text('${i + 1}',
                                style: TextStyle(
                                    color: _colorMid, fontSize: 10,
                                    fontWeight: FontWeight.w800)))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: UColors.textDark)),
                              Text(
                                '${_rp(item.price)}/kg × '
                                    '${_fmtQty(item.qty)} = '
                                    '${_rp(item.subtotal)}',
                                style: const TextStyle(fontSize: 11,
                                    color: UColors.textMid),
                              ),
                            ])),
                        Text(_rp(item.subtotal), style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: _colorMid)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _editItem(i),
                          child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  color: _colorMid.withOpacity(0.08),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.edit_rounded,
                                  size: 13, color: _colorMid)),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() => _cart.removeAt(i));
                            _saveDraft();
                          },
                          child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  color: UColors.danger.withOpacity(0.08),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  size: 13, color: UColors.danger)),
                        ),
                      ]),
                    ),
                  ]);
                }),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _colorMid.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16)),
                  ),
                  child: Row(children: [
                    Text('${_cart.length} item',
                        style: const TextStyle(fontSize: 12,
                            color: UColors.textMid)),
                    const Spacer(),
                    Text(_isBeli ? 'Total Beli  ' : 'Subtotal  ',
                        style: const TextStyle(fontSize: 13,
                            color: UColors.textMid)),
                    Text(_rp(_subtotal), style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: _colorDark)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 20),

          // ══════════════════════════════════════
          //  RINGKASAN — hanya untuk JUAL
          // ══════════════════════════════════════
          if (!_isBeli) ...[
            const USectionHeader(title: 'Ringkasan Pembayaran'),
            const SizedBox(height: 12),
            _InvCard(children: [
              const Text('Diskon (Rp)', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: UColors.textMid)),
              const SizedBox(height: 6),
              TextField(
                controller: _discCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: const Icon(Icons.discount_rounded,
                      color: UColors.primary, size: 18),
                  filled: true, fillColor: UColors.inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: UColors.primary.withOpacity(0.15))),
                ),
              ),
              const SizedBox(height: 12),
              UField(controller: _notesCtrl,
                  label: 'Catatan (opsional)',
                  hint: 'Terima kasih sudah belanja!',
                  prefixIcon: Icons.note_alt_outlined, maxLines: 2),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: UColors.primary.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: UColors.primary.withOpacity(0.10)),
                ),
                child: Column(children: [
                  _SumRow('Subtotal', _rp(_subtotal)),
                  if (_disc > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('Diskon', '− ${_rp(_disc)}',
                        color: UColors.danger),
                  ],
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                          color: UColors.primary.withOpacity(0.15),
                          height: 1)),
                  Row(children: [
                    const Text('TOTAL', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: UColors.primaryDark)),
                    const Spacer(),
                    Text(_rp(_total), style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: UColors.primary)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.payment_rounded, size: 13,
                        color: UColors.textLight),
                    const SizedBox(width: 5),
                    Text(_payMethod, style: const TextStyle(
                        fontSize: 12, color: UColors.textMid)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_isPaid
                            ? UColors.success : UColors.warning)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: (_isPaid
                                ? UColors.success
                                : UColors.warning).withOpacity(0.3)),
                      ),
                      child: Text(
                          _isPaid ? 'LUNAS' : 'BELUM LUNAS',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _isPaid
                                  ? UColors.success : UColors.warning)),
                    ),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
          ],

          // Catatan untuk BELI
          if (_isBeli) ...[
            _InvCard(children: [
              UField(controller: _notesCtrl,
                  label: 'Catatan Pembelian (opsional)',
                  hint: 'Contoh: kualitas bagus, barang dari Pak Budi',
                  prefixIcon: Icons.note_alt_outlined, maxLines: 2),
              if (_cart.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cBeliMid.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _cBeliMid.withOpacity(0.18)),
                  ),
                  child: Row(children: [
                    const SizedBox(height: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Modal Beli',
                              style: TextStyle(fontSize: 11,
                                  color: UColors.textMid)),
                          Text(_rp(_subtotal),
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _cBeliDark)),
                        ]),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_isPaid ? '✓ Sudah Dibayar' : '⏳ Belum Dibayar',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _isPaid
                                      ? UColors.success : UColors.warning)),
                          const SizedBox(height: 2),
                          Text('${_cart.length} jenis barang',
                              style: const TextStyle(fontSize: 10,
                                  color: UColors.textLight)),
                        ]),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 12),
          ],

          // ══════════════════════════════════════
          //  TOMBOL SUBMIT
          // ══════════════════════════════════════
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_colorDark, _colorLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: _colorMid.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _submitting
                    ? null
                    : (_isBeli ? _submitBeli : _submitJual),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBeli
                              ? Icons.add_shopping_cart_rounded
                              : Icons.print_rounded,
                          color: Colors.white, size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isBeli
                              ? 'Catat Pembelian & Tambah Stok'
                              : 'Buat & Cetak Nota',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
//  Helper: Ringkasan row di dialog beli
// ────────────────────────────────────────────
class _RingkasanRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final bool sub;
  final Color? color;
  const _RingkasanRow(this.label, this.value,
      {this.bold = false, this.sub = false, this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    if (sub) const SizedBox(width: 12),
    Expanded(child: Text(label, style: TextStyle(
        fontSize: sub ? 12 : 13,
        color: sub ? UColors.textMid : UColors.textDark,
        fontWeight: bold ? FontWeight.w800 : FontWeight.normal))),
    Text(value, style: TextStyle(
        fontSize: sub ? 12 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? (sub ? UColors.textMid : UColors.textDark))),
  ]);
}

// ────────────────────────────────────────────
class _InvCard extends StatelessWidget {
  final List<Widget> children;
  const _InvCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14, offset: const Offset(0, 4))]),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
}

class _SumRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _SumRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
        fontSize: 13, color: UColors.textMid)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color ?? UColors.textDark)),
  ]);
}

// ────────────────────────────────────────────
//  MODE TAB (JUAL / BELI)
// ────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       active;
  final VoidCallback onTap;
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [const BoxShadow(
              color: Color(0x22000000), blurRadius: 6,
              offset: Offset(0, 2))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? Colors.black87 : Colors.white70),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: active ? Colors.black87 : Colors.white70,
              )),
            ]),
      ),
    ),
  );
}

// ── Field helper untuk dialog barang baru ────────────────────
class _NewMatField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  const _NewMatField({
    required this.controller, required this.label,
    required this.hint, required this.icon, required this.color,
    this.keyboard, this.inputFormatters, this.autofocus = false,
  });
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
            fontSize: _rfs(context, 12), fontWeight: FontWeight.w700,
            color: const Color(0xFF4A5568))),
        const SizedBox(height: 6),
        TextField(
          controller: controller, autofocus: autofocus,
          keyboardType: keyboard, inputFormatters: inputFormatters,
          style: TextStyle(fontSize: _rfs(context, 13)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: const Color(0xFF90A4AE),
                fontSize: _rfs(context, 12)),
            prefixIcon: Icon(icon, color: color, size: _rfs(context, 18)),
            filled: true, fillColor: UColors.inputBg,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 14, vertical: _rfs(context, 12)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 1.5)),
          ),
        ),
      ]);
}

// ════════════════════════════════════════════
//  PENGATURAN NOTA — Bottom Sheet
// ════════════════════════════════════════════
class _NotaSettingsSheet extends StatefulWidget {
  const _NotaSettingsSheet();
  @override
  State<_NotaSettingsSheet> createState() => _NotaSettingsSheetState();
}

class _NotaSettingsSheetState extends State<_NotaSettingsSheet> {
  final _nameCtrl  = TextEditingController();
  final _addrCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _logoPath;
  bool    _saving  = false;

  static const _kColor = Color(0xFF1565C0);

  @override
  void initState() { super.initState(); _loadCurrentSettings(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addrCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    final name  = await readNotaSetting(kNotaName);
    final addr  = await readNotaSetting(kNotaAddr);
    final phone = await readNotaSetting(kNotaPhone);
    final logo  = await readNotaSetting(kNotaLogo);
    if (!mounted) return;
    setState(() {
      _nameCtrl.text  = name;
      _addrCtrl.text  = addr;
      _phoneCtrl.text = phone;
      _logoPath = logo.isEmpty ? null : logo;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final xfile = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
      if (xfile == null || !mounted) return;
      setState(() => _logoPath = xfile.path);
    } catch (e) {
      if (mounted) uSnack(context, 'Gagal pilih gambar: $e', isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await saveNotaSetting(kNotaName,  _nameCtrl.text.trim());
      await saveNotaSetting(kNotaAddr,  _addrCtrl.text.trim());
      await saveNotaSetting(kNotaPhone, _phoneCtrl.text.trim());
      await saveNotaSetting(kNotaLogo,  _logoPath ?? '');
      if (mounted) {
        Navigator.pop(context);
        uSnack(context, 'Pengaturan nota disimpan ✓');
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottom + 24, left: 20, right: 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _kColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.tune_rounded,
                    color: _kColor, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pengaturan Nota', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Tersimpan di perangkat ini', style: TextStyle(
                  fontSize: 11, color: Color(0xFF90A4AE))),
            ])),
          ]),
          const SizedBox(height: 22),

          // Logo
          const Align(alignment: Alignment.centerLeft,
              child: Text('Logo Perusahaan', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF4A5568)))),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kColor.withOpacity(0.2))),
              child: ClipRRect(borderRadius: BorderRadius.circular(13),
                  child: _logoPath != null && File(_logoPath!).existsSync()
                      ? Image.file(File(_logoPath!), fit: BoxFit.contain)
                      : const Icon(Icons.image_outlined,
                      color: Color(0xFF90A4AE), size: 32)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                      color: _kColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kColor.withOpacity(0.2))),
                  child: const Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_rounded,
                            color: _kColor, size: 16),
                        SizedBox(width: 8),
                        Text('Pilih dari Galeri',
                            style: TextStyle(color: _kColor,
                                fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                ),
              ),
              if (_logoPath != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _logoPath = null),
                  child: const Row(mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFC62828), size: 14),
                        SizedBox(width: 4),
                        Text('Hapus Logo', style: TextStyle(
                            color: Color(0xFFC62828), fontSize: 11,
                            fontWeight: FontWeight.w600)),
                      ]),
                ),
              ],
            ])),
          ]),
          const SizedBox(height: 18),

          _SettingsField(controller: _nameCtrl,
              label: 'Nama Perusahaan / Toko',
              hint: 'Contoh: Toko Maju Jaya',
              icon: Icons.store_rounded),
          const SizedBox(height: 12),
          _SettingsField(controller: _addrCtrl,
              label: 'Alamat',
              hint: 'Jl. Contoh No. 1, Kota',
              icon: Icons.location_on_rounded, maxLines: 2),
          const SizedBox(height: 12),
          _SettingsField(controller: _phoneCtrl,
              label: 'No. Telepon / WhatsApp',
              hint: '08xxxxxxxxxx',
              icon: Icons.phone_rounded,
              keyboard: TextInputType.phone),
          const SizedBox(height: 22),

          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Simpan Pengaturan', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800,
                        fontSize: 15)),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboard;
  const _SettingsField({
    required this.controller, required this.label,
    required this.hint, required this.icon,
    this.maxLines = 1, this.keyboard,
  });
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w700, color: Color(0xFF4A5568))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF1565C0), size: 18),
            filled: true, fillColor: const Color(0xFFF4F7FF),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: const Color(0xFF1565C0).withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: const Color(0xFF1565C0).withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF1E88E5), width: 1.5)),
          ),
        ),
      ]);
}