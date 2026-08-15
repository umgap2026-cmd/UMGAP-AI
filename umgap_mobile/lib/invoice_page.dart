import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';
import 'invoice_print_page.dart';
import 'nota_history_page.dart';

// ── Responsive font size ──────────────────────────────────────
double _rfs(BuildContext context, double base) {
  final w = MediaQuery.of(context).size.width;
  if (w < 360) return base * 0.88;
  if (w > 430) return base * 1.08;
  return base;
}

// ════════════════════════════════════════════
//  Storage helpers — flutter_secure_storage (draft nota)
// ════════════════════════════════════════════
const _notaStorage = FlutterSecureStorage();

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
  final bool   isReturn;
  final String? note;

  double get subtotal => price * qty;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
    this.isReturn = false,
    this.note,
  });

  CartItem copyWith({double? qty, int? price, bool? isReturn, String? note}) => CartItem(
    productId:   productId,
    productName: productName,
    price:       price ?? this.price,
    qty:         qty   ?? this.qty,
    isReturn:    isReturn ?? this.isReturn,
    note:        note ?? this.note,
  );
}

// ════════════════════════════════════════════
//  ADJUSTMENT — baris "Potongan & Biaya" (DP/Ongkir),
//  mirror section yg sama di web (invoice_form.html).
// ════════════════════════════════════════════
class _AdjRow {
  String type;   // 'DP' | 'ONGKIR'
  String mode;   // 'BEBAN' | 'POTONGAN' -- cuma relevan utk ONGKIR
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController categoryCtrl = TextEditingController();

  _AdjRow({this.type = 'DP', this.mode = 'BEBAN'});

  double get amount => double.tryParse(amountCtrl.text.trim()) ?? 0;

  void dispose() {
    amountCtrl.dispose();
    categoryCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    if (type == 'ONGKIR') 'mode': mode,
    if (type == 'ONGKIR' && mode == 'BEBAN' && categoryCtrl.text.trim().isNotEmpty)
      'category': categoryCtrl.text.trim(),
  };
}

String _fmtQty(double q) {
  if (q == q.truncateToDouble()) return q.toInt().toString();
  // Buang nol berlebih di belakang koma (0.50 -> 0.5, bukan tetap 0.50).
  return q.toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String _fmtDatePretty(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
  final int? editTxnId;

  const InvoicePage({
    super.key,
    this.initName,
    this.initPhone,
    this.initPayMethod,
    this.initNotes,
    this.initDiscount,
    this.initIsPaid,
    this.initCart,
    this.editTxnId,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage>
    with SingleTickerProviderStateMixin {
  bool _loading    = true;
  bool _submitting = false;
  bool get _isEditMode => widget.editTxnId != null;
  String _editInvoiceNo = '';

  // ── Mode: false = JUAL, true = BELI ──────────
  bool _isBeli = false;

  // Animasi transisi mode
  late AnimationController _modeAnim;
  late Animation<double>   _modeProgress;

  List<dynamic> _materials = [];
  int?          _selId;

  final _qtyCtrl   = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _itemNoteCtrl = TextEditingController();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _discCtrl;
  final _nameFocus = FocusNode();

  late String       _payMethod;
  late bool         _isPaid;
  late List<CartItem> _cart;
  bool _addAsReturn = false;

  // ── Potongan & Biaya (DP/Ongkir) — kedua mode ──
  final List<_AdjRow> _adjustments = [];

  // ── Saldo hutang/piutang pihak (dipakai sbg DP) ──
  double  _creditAvailable = 0;
  String? _creditPartyName;
  final _creditCtrl = TextEditingController();
  bool    _creditChecking = false;
  double get _creditApplied => _creditCtrl.text.trim().isEmpty
      ? 0 : (double.tryParse(_creditCtrl.text.trim()) ?? 0);

  // ── Daftar saldo terbuka (chip "klik utk pilih", proaktif) ──
  List<Map<String, dynamic>> _partyBalances = [];
  bool _loadingBalances = false;

  // ── Tanggal nota (opsional, manual) ──
  bool      _autoDate   = true;
  DateTime? _manualDate;

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

    // Cek saldo hutang/piutang pihak begitu nama selesai diisi
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _checkPartyCredit();
    });

    // Load materials, lalu: mode edit → tarik data nota; else cek draft
    // lokal (hanya jika bukan dari initCart).
    _loadMaterials().then((_) {
      if (_isEditMode) {
        _loadEditData();
      } else if (widget.initCart == null || widget.initCart!.isEmpty) {
        _loadDraft();
      }
    });
    if (!_isEditMode) _loadPartyBalances();
  }

  @override
  void dispose() {
    _modeAnim.dispose();
    _qtyCtrl.dispose();  _priceCtrl.dispose(); _itemNoteCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _nameFocus.dispose();
    _notesCtrl.dispose(); _discCtrl.dispose(); _creditCtrl.dispose();
    for (final a in _adjustments) a.dispose();
    super.dispose();
  }

  void _switchMode(bool toBeli) {
    // Jenis nota (Jual/Beli) tidak bisa diubah saat edit -- sudah ditentukan
    // sejak nota dibuat.
    if (_isEditMode) return;
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
        _addAsReturn = false;
      });
      _saveDraft();
    }
    // Arah saldo (HUTANG/PIUTANG) berbeda per mode -- cek ulang.
    _checkPartyCredit();
    _loadPartyBalances();
  }

  // ── Cek saldo hutang/piutang pihak (dipakai sbg DP) ──
  // Mode Jual → cek HUTANG (saldo customer di kita). Mode Beli → cek
  // PIUTANG (saldo kita di supplier). Mirror invoice_form.html:1662-1666.
  Future<void> _checkPartyCredit() async {
    final party = _nameCtrl.text.trim();
    if (party.isEmpty) {
      if (mounted) setState(() { _creditAvailable = 0; _creditPartyName = null; _creditCtrl.clear(); });
      return;
    }
    setState(() => _creditChecking = true);
    try {
      final res = await ApiService.financeCheckPartyCredit(
        partyName: party,
        creditType: _isBeli ? 'PIUTANG' : 'HUTANG',
      );
      if (!mounted) return;
      final avail = (res['available'] as num?)?.toDouble() ?? 0;
      setState(() {
        _creditAvailable = avail;
        _creditPartyName = avail > 0 ? party : null;
        if (avail <= 0) _creditCtrl.clear();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _creditChecking = false);
    }
  }

  // ── Daftar saldo terbuka (proaktif, tampil sbg chip klik) ──
  // Mode Jual → HUTANG (titipan dana orang lain ke kita). Mode Beli →
  // PIUTANG (saldo kita di supplier). Mirror open_hutang/open_piutang di
  // invoice_form.html web.
  Future<void> _loadPartyBalances() async {
    setState(() => _loadingBalances = true);
    try {
      // Tidak difilter by reason -- tampilkan SEMUA saldo terbuka (spt di
      // Finance), krn saldo lama/manual sblm kolom `reason` ada belum tentu
      // ke-tag 'TITIP_DANA' oleh backfill, jangan sampai hilang dari daftar.
      final list = await ApiService.financeListPartyBalances(
        creditType: _isBeli ? 'PIUTANG' : 'HUTANG',
      );
      if (!mounted) return;
      setState(() => _partyBalances = List<Map<String, dynamic>>.from(list));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingBalances = false);
    }
  }

  // ── Riwayat nama (semua pihak yg pernah dipakai) + search ──
  List<String>? _partyNamesCache;

  Future<void> _pickFromPartyHistory() async {
    try {
      _partyNamesCache ??= (await ApiService.financeListPartyNames())
          .map((e) => '$e').toList();
    } catch (e) {
      if (mounted) uSnack(context, 'Gagal memuat riwayat nama: $e', isError: true);
      return;
    }
    if (!mounted) return;
    final picked = await uShowNamePicker(context,
        title: 'Riwayat Nama', names: _partyNamesCache!,
        allLabel: 'Ketik nama baru');
    if (picked != null && picked.isNotEmpty) {
      setState(() => _nameCtrl.text = picked);
      _checkPartyCredit();
    }
  }

  void _pickPartyBalance(String name) {
    setState(() => _nameCtrl.text = name);
    _checkPartyCredit();
  }

  // ══════════════════════════════════════════════
  //  DRAFT — Auto-save & restore
  // ══════════════════════════════════════════════
  static const _kDraft = 'invoice_draft_v1';

  // ── Snapshot form saat ini (dipakai draft lokal MAUPUN draft
  //  bersama server) ──
  Map<String, dynamic> _buildDraftSnapshot() => {
    'name':    _nameCtrl.text,
    'phone':   _phoneCtrl.text,
    'notes':   _notesCtrl.text,
    'disc':    _discCtrl.text,
    'pay':     _payMethod,
    'isPaid':  _isPaid,
    'isBeli':  _isBeli,
    'savedAt': DateTime.now().toIso8601String(),
    'cart':    _cart.map((c) => {
      'id':       c.productId,
      'name':     c.productName,
      'price':    c.price,
      'qty':      c.qty,
      'isReturn': c.isReturn,
      'note':     c.note,
    }).toList(),
    'adjustments': _adjustments.map((a) => {
      'type': a.type, 'mode': a.mode,
      'amount': a.amountCtrl.text, 'category': a.categoryCtrl.text,
    }).toList(),
    'creditApplied': _creditCtrl.text,
    'autoDate': _autoDate,
    'manualDate': _manualDate?.toIso8601String(),
  };

  // ── Terapkan snapshot draft (lokal ATAU dari server) ke form ──
  void _applyDraftSnapshot(Map<String, dynamic> d) {
    final cartData = d['cart'] as List? ?? [];
    final draftCart = cartData.map((i) => CartItem(
      productId:   ((i['id'] as num?) ?? 0).toInt(),
      productName: i['name'] as String? ?? '-',
      price:       ((i['price'] as num?) ?? 0).toInt(),
      qty:         ((i['qty'] as num?) ?? 0).toDouble(),
      isReturn:    i['isReturn'] == true,
      note:        (i['note'] as String?)?.isNotEmpty == true ? i['note'] as String : null,
    )).toList();

    final adjData = d['adjustments'] as List? ?? [];
    final draftAdjustments = adjData.map((a) {
      final row = _AdjRow(
        type: (a['type'] as String?) ?? 'DP',
        mode: (a['mode'] as String?) ?? 'BEBAN',
      );
      row.amountCtrl.text = (a['amount'] as String?) ?? '';
      row.categoryCtrl.text = (a['category'] as String?) ?? '';
      return row;
    }).toList();

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
      for (final a in _adjustments) a.dispose();
      _adjustments..clear()..addAll(draftAdjustments);
      _creditCtrl.text = (d['creditApplied'] as String?) ?? '';
      _autoDate   = d['autoDate'] as bool? ?? true;
      final md    = d['manualDate'] as String?;
      _manualDate = (md != null && md.isNotEmpty) ? DateTime.tryParse(md) : null;
    });
    _checkPartyCredit();
  }

  // ── Mode edit: tarik data nota yg sudah tersimpan lalu isi form ──
  // (tanggal & pakai-saldo TIDAK bisa diubah lewat edit, sama spt web --
  // adjustments DP/Ongkir disintesis dari dp_amount/ongkir_potongan_amount
  // krn rincian per-baris aslinya tidak disimpan terpisah, sama persis
  // pola invoice_form.html:530-536.)
  Future<void> _loadEditData() async {
    try {
      final res = await ApiService.invoiceFullDetail(widget.editTxnId!);
      final invoice = Map<String, dynamic>.from(res['invoice'] ?? {});
      final items = List<dynamic>.from(res['items'] ?? []);
      final isBeli = '${invoice['nota_type'] ?? 'JUAL'}' == 'BELI';

      final cart = items.map((it) {
        final m = Map<String, dynamic>.from(it);
        final note = '${m['note'] ?? ''}';
        return {
          'id':       m['material_id'],
          'name':     m['product_name'] ?? '-',
          'price':    m['price'],
          'qty':      m['qty'],
          'isReturn': m['is_return'] == true,
          'note':     note.isNotEmpty ? note : null,
        };
      }).toList();

      final dpAmount    = (invoice['dp_amount'] as num?)?.toDouble() ?? 0;
      final ongkirPotongan = (invoice['ongkir_potongan_amount'] as num?)?.toDouble() ?? 0;
      final adjustments = [
        if (dpAmount > 0)
          {'type': 'DP', 'mode': 'BEBAN', 'amount': dpAmount.toStringAsFixed(0), 'category': ''},
        if (ongkirPotongan > 0)
          {'type': 'ONGKIR', 'mode': 'POTONGAN', 'amount': ongkirPotongan.toStringAsFixed(0), 'category': ''},
      ];

      if (!mounted) return;
      setState(() => _editInvoiceNo = '${invoice['invoice_no'] ?? ''}');
      _applyDraftSnapshot({
        'name':    invoice['customer_name'] ?? '',
        'phone':   invoice['customer_phone'] ?? '',
        'notes':   invoice['notes'] ?? '',
        'disc':    '0',
        'pay':     invoice['payment_method'] ?? 'CASH',
        'isPaid':  invoice['is_paid'] ?? true,
        'isBeli':  isBeli,
        'cart':    cart,
        'adjustments': adjustments,
        'creditApplied': '',
        'autoDate': true,
        'manualDate': null,
      });
    } catch (e) {
      if (!mounted) return;
      uSnack(context, 'Gagal memuat data nota: $e', isError: true);
    }
  }

  Future<void> _saveDraft() async {
    // Mode edit tidak ikut nimpa draft nota-baru yg mgkn sedang tersimpan
    if (_isEditMode) return;
    // Tidak perlu simpan kalau kosong
    if (_cart.isEmpty &&
        _nameCtrl.text.isEmpty &&
        _phoneCtrl.text.isEmpty) {
      await _notaStorage.delete(key: _kDraft);
      return;
    }
    try {
      await _notaStorage.write(
          key: _kDraft, value: jsonEncode(_buildDraftSnapshot()));
    } catch (_) {}
  }

  // ── Simpan sbg Draft Bersama (server, kelihatan semua admin) ──
  Future<void> _saveSharedDraft() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    final nameCtrl = TextEditingController(
        text: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Simpan Draft Bersama'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Draft ini akan bisa dilihat & dilanjutkan oleh semua admin.',
              style: TextStyle(fontSize: 12, color: UColors.textMid)),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Nama draft (opsional)',
                  hintText: 'Kosongkan utk otomatis',
                  filled: true, fillColor: UColors.inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _colorMid),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeSaveNotaDraft(
        notaType: _isBeli ? 'BELI' : 'JUAL',
        draftName: nameCtrl.text.trim(),
        formData: _buildDraftSnapshot(),
      );
      if (mounted) uSnack(context, 'Draft tersimpan, bisa dilihat semua admin ✓');
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  // ── Buka daftar Draft Bersama (dari server, semua admin) ──
  Future<void> _openSharedDrafts() async {
    List<dynamic> drafts = [];
    bool loading = true;
    String? err;
    try {
      drafts = await ApiService.financeListNotaDrafts();
      loading = false;
    } catch (e) {
      err = e.toString();
      loading = false;
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (sheetCtx, setModalState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.35, maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4))),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('📂 Draft Bersama (semua admin)', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: UColors.textDark)),
              ),
              const Divider(height: 1),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: UColors.primary))
                    : err != null
                        ? Center(child: Text('Gagal memuat: $err',
                            style: const TextStyle(color: UColors.danger)))
                        : drafts.isEmpty
                            ? const Center(child: Text('Belum ada draft bersama',
                                style: TextStyle(color: UColors.textLight)))
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: drafts.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                                itemBuilder: (ctx, i) {
                                  final d = Map<String, dynamic>.from(drafts[i]);
                                  final isBeli = '${d['nota_type']}' == 'BELI';
                                  return ListTile(
                                    leading: Text(isBeli ? '📦' : '🛒', style: const TextStyle(fontSize: 18)),
                                    title: Text('${d['draft_name'] ?? '-'}', style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13)),
                                    subtitle: Text(
                                        'oleh ${d['created_by_name'] ?? '-'} • ${d['updated_at_wib'] ?? ''}',
                                        style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                                    trailing: GestureDetector(
                                      onTap: () async {
                                        final delOk = await showDialog<bool>(
                                          context: ctx,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Hapus draft ini?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: UColors.danger),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (delOk == true) {
                                          try {
                                            await ApiService.financeDeleteNotaDraft(
                                                int.tryParse('${d['id']}') ?? 0);
                                            setModalState(() => drafts.removeAt(i));
                                          } catch (e) {
                                            if (mounted) uSnack(context, e.toString(), isError: true);
                                          }
                                        }
                                      },
                                      child: const Icon(Icons.delete_outline_rounded, color: UColors.danger, size: 20),
                                    ),
                                    onTap: () {
                                      Navigator.pop(sheetCtx);
                                      final formData = Map<String, dynamic>.from(d['form_data'] ?? {});
                                      _applyDraftSnapshot(formData);
                                    },
                                  );
                                },
                              ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _loadDraft() async {
    try {
      final raw = await _notaStorage.read(key: _kDraft);
      if (raw == null || raw.isEmpty || !mounted) return;

      final d = jsonDecode(raw) as Map<String, dynamic>;
      final cartData = d['cart'] as List? ?? [];
      if (cartData.isEmpty && (d['name'] ?? '').toString().isEmpty) return;

      final draftCartLen = cartData.length;

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
                '$draftCartLen barang'
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
                _applyDraftSnapshot(d);
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

  // ── Modal pencarian barang (search + kategori + HPP) ──
  // Meniru pola LOV di web (templates/invoice_form.html): search nama +
  // chip kategori, tiap baris tampilkan stok & HPP supaya admin tidak
  // salah pilih barang di gudang yang isinya banyak jenis.
  void _showMaterialPicker() {
    String query = '';
    String selectedCat = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setModalState) {
          final cats = <String>{};
          for (final m in _materials) {
            final c = '${m['category'] ?? ''}'.trim();
            if (c.isNotEmpty) cats.add(c);
          }
          final catList = cats.toList()..sort();

          final filtered = _materials.where((m) {
            final name =
                '${m['name'] ?? m['material_name'] ?? ''}'.toLowerCase();
            final cat = '${m['category'] ?? ''}'.trim();
            final matchQ = query.trim().isEmpty ||
                name.contains(query.trim().toLowerCase());
            final matchCat = selectedCat.isEmpty || cat == selectedCat;
            return matchQ && matchCat;
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Pilih Barang Gudang',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: UColors.textDark)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama barang…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: UColors.inputBg,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                  ),
                  if (catList.isNotEmpty) Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: selectedCat.isEmpty,
                        onSelected: (_) => setModalState(() => selectedCat = ''),
                      ),
                      ...catList.map((c) => ChoiceChip(
                        label: Text(c),
                        selected: selectedCat == c,
                        onSelected: (_) =>
                            setModalState(() => selectedCat = selectedCat == c ? '' : c),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text('Barang tidak ditemukan',
                                style: TextStyle(color: UColors.textLight)))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              final m = filtered[i];
                              final id = int.tryParse('${m['id']}') ?? 0;
                              final nm = '${m['name'] ?? m['material_name'] ?? '-'}';
                              final stok = double.tryParse(
                                  '${m['qty_kg'] ?? m['stock'] ?? 0}') ?? 0.0;
                              final hpp = double.tryParse(
                                  '${m['avg_cost_per_kg'] ?? 0}') ?? 0.0;
                              final unit = '${m['unit'] ?? 'kg'}';
                              final stokColor = _isBeli
                                  ? UColors.textMid
                                  : (stok > 0 ? UColors.success : UColors.danger);
                              return ListTile(
                                title: Text(nm, style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                                subtitle: Text(
                                  'Stok ${stok.toStringAsFixed(1)} $unit'
                                  '${hpp > 0 ? ' · HPP ${_rp(hpp)}' : ''}',
                                  style: TextStyle(fontSize: 12, color: stokColor),
                                ),
                                onTap: () {
                                  setState(() => _selId = id);
                                  Navigator.pop(sheetCtx);
                                },
                              );
                            },
                          ),
                  ),
                ]),
              );
            },
          );
        });
      },
    );
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
  // Stok barang yg sedang dipilih (di list materials, disinkronkan tiap
  // kali _addStockForSelected() berhasil, tanpa perlu reload seluruh list).
  double get _selStock => double.tryParse(
      '${_selMat?['qty_kg'] ?? _selMat?['stock'] ?? 0}') ?? 0.0;
  // Arah stok berkurang: JUAL normal, atau BELI yg ditandai "barang balik"
  // (kita jual balik ke pemasok) -- sama seperti aturan warna stok di
  // picker (baris ~867-869).
  bool get _isStockDecreasing => _isBeli == _addAsReturn;
  // Label barang arah-kebalik dinilai dari arah EKONOMI sebenarnya (spt di
  // hasil cetak nota) -- di nota Jual, barang arah-kebalik itu kita BELI
  // dari customer; di nota Beli, itu kita JUAL ke pemasok. Beda dari
  // "barang balik" (kotoran/susutan), jangan dipakai istilah yg sama.
  String get _reverseLabel => _isBeli ? 'Jual' : 'Beli';
  bool get _showStockWarning  =>
      _selMat != null && _isStockDecreasing && _previewQty > _selStock;
  double get _previewSub  => _manualPrice * _previewQty;
  double get _subtotal    =>
      _cart.where((c) => !c.isReturn).fold(0.0, (s, c) => s + c.subtotal);
  double get _revSubtotal =>
      _cart.where((c) => c.isReturn).fold(0.0, (s, c) => s + c.subtotal);
  double get _disc        =>
      _isBeli ? 0 : (double.tryParse(_discCtrl.text.trim()) ?? 0);
  // ── Potongan & Biaya (DP/Ongkir) ──
  double get _adjDpTotal => _adjustments
      .where((a) => a.type == 'DP').fold(0.0, (s, a) => s + a.amount);
  double get _adjOngkirPotongan => _adjustments
      .where((a) => a.type == 'ONGKIR' && a.mode == 'POTONGAN')
      .fold(0.0, (s, a) => s + a.amount);
  double get _adjOngkirBeban => _adjustments
      .where((a) => a.type == 'ONGKIR' && a.mode == 'BEBAN')
      .fold(0.0, (s, a) => s + a.amount);
  // Total sebelum saldo dipotong (dipakai buat batas atas input saldo)
  double get _rawTotal =>
      (_subtotal - _disc - _revSubtotal - _adjDpTotal - _adjOngkirPotongan)
          .clamp(0, double.infinity);
  double get _total       =>
      (_rawTotal - _creditApplied).clamp(0, double.infinity);
  // "YYYY-MM-DD" kalau diatur manual, null = otomatis hari ini
  String? get _notaDateStr => (!_autoDate && _manualDate != null)
      ? '${_manualDate!.year.toString().padLeft(4,'0')}-'
        '${_manualDate!.month.toString().padLeft(2,'0')}-'
        '${_manualDate!.day.toString().padLeft(2,'0')}'
      : null;

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

  // ── Tambah Stok barang yang sedang dipilih (qty > stok tersedia) ──
  Future<void> _addStockForSelected() async {
    final mat = _selMat;
    if (mat == null) return;
    final materialId = int.tryParse('${mat['id']}') ?? 0;
    final matName = '${mat['name'] ?? mat['material_name'] ?? 'Barang'}';
    final avgCost = double.tryParse('${mat['avg_cost_per_kg'] ?? 0}') ?? 0.0;

    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController(
        text: avgCost > 0 ? avgCost.toStringAsFixed(0) : '');

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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFC2410C).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFFC2410C), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tambah Stok $matName', style: TextStyle(
                        fontSize: _rfs(ctx, 16), fontWeight: FontWeight.w800)),
                    Text('Qty melebihi stok yang tersedia', style: TextStyle(
                        fontSize: _rfs(ctx, 11),
                        color: const Color(0xFF90A4AE))),
                  ])),
                ]),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(child: _NewMatField(controller: qtyCtrl,
                      label: 'Jumlah Tambahan *', hint: '0',
                      icon: Icons.add_circle_rounded, color: _colorMid,
                      keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 10),
                  Expanded(child: _NewMatField(controller: priceCtrl,
                      label: 'Harga/Biaya per kg *', hint: '0',
                      icon: Icons.price_check_rounded, color: _colorMid,
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                ]),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final qty   = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                      final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      if (qty <= 0) {
                        uSnack(context, 'Jumlah tambahan harus lebih dari 0',
                            isError: true);
                        return;
                      }
                      if (price <= 0) {
                        uSnack(context, 'Harga/biaya per kg wajib diisi',
                            isError: true);
                        return;
                      }
                      setS(() => saving = true);
                      try {
                        final result = await ApiService.financeAddMaterialStock(
                          materialId: materialId, qty: qty, price: price,
                          note: 'Tambah stok saat buat nota',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {
                            final idx = _materials.indexWhere((m) =>
                                (int.tryParse('${m['id']}') ?? -1) == materialId);
                            if (idx >= 0) {
                              _materials[idx] = {
                                ..._materials[idx],
                                'qty_kg': result['qty_kg'],
                                'avg_cost_per_kg': result['avg_cost_per_kg'],
                              };
                            }
                          });
                          uSnack(context, '✓ Stok "$matName" berhasil ditambah');
                        }
                      } catch (e) {
                        if (mounted) uSnack(context, e.toString(), isError: true);
                        setS(() => saving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC2410C),
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
                      Text('Tambah Stok Sekarang', style: TextStyle(
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
      final note = _itemNoteCtrl.text.trim();
      // Item dgn catatan tidak digabung ke baris lain spy catatannya
      // tetap jelas per baris (bukan tercampur ke qty gabungan).
      final idx = note.isEmpty ? _cart.indexWhere(
              (c) => c.productId == id && c.price == _manualPrice
                  && c.isReturn == _addAsReturn && (c.note ?? '').isEmpty) : -1;
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(qty: _cart[idx].qty + _previewQty);
      } else {
        _cart.add(CartItem(
          productId:   id,
          productName:
          '${_selMat!['name'] ?? _selMat!['material_name'] ?? 'Barang'}',
          price:       _manualPrice,
          qty:         _previewQty,
          isReturn:    _addAsReturn,
          note:        note.isEmpty ? null : note,
        ));
      }
      _qtyCtrl.text = '1';
      _priceCtrl.clear();
      _itemNoteCtrl.clear();
      _addAsReturn = false;
    });
    _saveDraft();
  }

  // ── Edit item ──────────────────────────────────
  Future<void> _editItem(int idx) async {
    final qC = TextEditingController(text: _fmtQty(_cart[idx].qty));
    final pC = TextEditingController(text: '${_cart[idx].price}');
    final nC = TextEditingController(text: _cart[idx].note ?? '');
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
          const SizedBox(height: 10),
          TextField(controller: nC,
              decoration: InputDecoration(
                  labelText: 'Catatan barang (opsional)',
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
    final n = nC.text.trim();
    setState(() {
      if (q <= 0) _cart.removeAt(idx);
      else _cart[idx] = _cart[idx].copyWith(
          qty: q, price: p > 0 ? p : null, note: n.isEmpty ? null : n);
    });
    _saveDraft();
  }

  // ── Payload helpers (dipakai submit & preview) ──
  List<Map<String, dynamic>> _buildItemsPayload() => _cart.map((c) => {
    'material_id': c.productId,
    'qty':         c.qty,
    'price':       c.price,
    'note':        c.note ?? '',
    'is_return':   c.isReturn,
  }).toList();

  List<Map<String, dynamic>> _buildAdjustmentsPayload() {
    final list = _adjustments
        .where((a) => a.amount > 0)
        .map((a) => a.toJson())
        .toList();
    if (!_isBeli && _disc > 0) list.add({'type': 'DP', 'amount': _disc});
    return list;
  }

  void _resetFormAfterSubmit() {
    for (final a in _adjustments) a.dispose();
    _cart.clear(); _nameCtrl.clear(); _phoneCtrl.clear();
    _notesCtrl.clear(); _discCtrl.text = '0';
    _payMethod = 'CASH'; _isPaid = true; _submitting = false;
    _priceCtrl.clear(); _itemNoteCtrl.clear();
    _qtyCtrl.text = '1'; _selId = null; _addAsReturn = false;
    _adjustments.clear();
    _creditCtrl.clear(); _creditAvailable = 0; _creditPartyName = null;
    _autoDate = true; _manualDate = null;
  }

  Future<bool> _confirmSubmit({
    required String title, required String content,
    required String btnLabel, required Color color, required IconData icon,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ]),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(btnLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ══════════════════════════════════════════════
  //  SUBMIT JUAL → langsung simpan ke database, baru
  //  pindah ke halaman cetak (nota sudah tersimpan).
  // ══════════════════════════════════════════════
  Future<void> _submitJual() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      uSnack(context, 'Nama customer wajib diisi', isError: true); return;
    }
    final name = _nameCtrl.text.trim();
    final ok = await _confirmSubmit(
      title: 'Buat & Simpan Nota?',
      content: 'Nota penjualan untuk "$name" sebesar ${_rp(_total)} '
          'akan langsung tersimpan ke laporan keuangan.',
      btnLabel: 'Buat Nota', color: _cJualMid,
      icon: Icons.receipt_long_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    final snap   = List<CartItem>.from(_cart);
    final phone  = _phoneCtrl.text.trim();
    final pay    = _payMethod;
    final notes  = _notesCtrl.text.trim();
    final disc   = _disc + _adjDpTotal + _adjOngkirPotongan + _creditApplied;
    final sub    = _subtotal;
    final revSub = _revSubtotal;
    final total  = _total;
    final paid   = _isPaid;

    try {
      final result = await ApiService.financeCreateInvoice(
        header: {
          'customer_name':  name,
          'customer_phone': phone,
          'payment_method': pay,
          'notes':          notes,
          'discount':       0,
          'is_paid':        paid ? '1' : '0',
          'adjustments':    _buildAdjustmentsPayload(),
          'credit_applied': _creditApplied,
          'nota_date':      _notaDateStr,
        },
        items: _buildItemsPayload(),
      );
      await _clearDraft();
      if (!mounted) return;
      setState(_resetFormAfterSubmit);

      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InvoicePrintPage(
          invoiceId:     result['invoice_id'],
          invoiceNo:     '${result['invoice_no'] ?? ''}',
          customerName:  name,
          customerPhone: phone,
          paymentMethod: pay,
          notes:         notes,
          discount:      disc,
          subtotal:      sub,
          reverseSubtotal: revSub,
          grandTotal:    total,
          dpExcess:      (result['dp_excess'] as num?)?.toDouble() ?? 0,
          items:         snap,
          isPaid:        paid,
          isBeli:        false,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
      setState(() => _submitting = false);
    }
  }

  // ══════════════════════════════════════════════
  //  SUBMIT BELI → langsung simpan ke database (nota
  //  BELI resmi via /finance/purchase-invoice), baru
  //  pindah ke halaman cetak.
  // ══════════════════════════════════════════════
  Future<void> _submitBeli() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    final supplier = _nameCtrl.text.trim();
    final displayName = supplier.isNotEmpty ? supplier : 'Pembelian Umum';
    final ok = await _confirmSubmit(
      title: 'Catat Pembelian?',
      content: 'Pembelian dari "$displayName" senilai ${_rp(_total)} akan '
          'langsung tersimpan & menambah stok gudang.',
      btnLabel: 'Catat', color: _cBeliMid,
      icon: Icons.add_box_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      final snap   = List<CartItem>.from(_cart);
      final phone  = _phoneCtrl.text.trim();
      final notes  = _notesCtrl.text.trim();
      final sub    = _subtotal;
      final revSub = _revSubtotal;
      final total  = _total;
      final paid   = _isPaid;
      final disc   = _adjDpTotal + _adjOngkirPotongan + _creditApplied;

      final result = await ApiService.financeCreatePurchaseInvoice(
        header: {
          'supplier_name':  supplier,
          'supplier_phone': phone,
          'payment_method': 'CASH',
          'notes':          notes,
          'is_paid':        paid ? '1' : '0',
          'adjustments':    _buildAdjustmentsPayload(),
          'credit_applied': _creditApplied,
          'nota_date':      _notaDateStr,
        },
        items: _buildItemsPayload(),
      );

      await _clearDraft();
      if (!mounted) return;
      setState(_resetFormAfterSubmit);

      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => InvoicePrintPage(
          invoiceId:     result['invoice_id'],
          invoiceNo:     '${result['invoice_no'] ?? ''}',
          customerName:  displayName,
          customerPhone: phone,
          paymentMethod: paid ? 'LUNAS' : 'BELUM LUNAS',
          notes:         notes,
          discount:      disc,
          subtotal:      sub,
          reverseSubtotal: revSub,
          grandTotal:    total,
          dpExcess:      (result['dp_excess'] as num?)?.toDouble() ?? 0,
          items:         snap,
          isPaid:        paid,
          isBeli:        true,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
      setState(() => _submitting = false);
    }
  }

  // ══════════════════════════════════════════════
  //  SUBMIT EDIT — simpan perubahan ke nota yg sudah
  //  ada (tanggal & pakai-saldo tidak bisa diubah).
  // ══════════════════════════════════════════════
  Future<void> _submitEdit() async {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    if (!_isBeli && _nameCtrl.text.trim().isEmpty) {
      uSnack(context, 'Nama customer wajib diisi', isError: true); return;
    }
    final ok = await _confirmSubmit(
      title: 'Simpan Perubahan Nota?',
      content: '$_editInvoiceNo akan diperbarui — stok & HPP lama otomatis '
          'dibalik lalu diterapkan ulang sesuai barang yang baru.',
      btnLabel: 'Simpan Perubahan', color: _colorMid,
      icon: Icons.edit_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      final result = await ApiService.editNotaInvoice(
        txnId: widget.editTxnId!,
        header: {
          'customer_name':  _nameCtrl.text.trim(),
          'customer_phone': _phoneCtrl.text.trim(),
          'payment_method': _payMethod,
          'notes':          _notesCtrl.text.trim(),
          'is_paid':        _isPaid ? '1' : '0',
          'adjustments':    _buildAdjustmentsPayload(),
        },
        items: _buildItemsPayload(),
      );
      if (!mounted) return;
      uSnack(context, 'Nota ${result['invoice_no'] ?? ''} berhasil diperbarui ✓');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      uSnack(context, e.toString(), isError: true);
      setState(() => _submitting = false);
    }
  }

  // ══════════════════════════════════════════════
  //  PREVIEW — ringkasan nota sebelum disimpan
  //  (murni dari state form saat ini, tanpa panggil API)
  // ══════════════════════════════════════════════
  void _showPreview() {
    if (_cart.isEmpty) {
      uSnack(context, 'Keranjang masih kosong', isError: true); return;
    }
    final party = _nameCtrl.text.trim().isEmpty
        ? (_isBeli ? 'Pembelian Umum' : '-') : _nameCtrl.text.trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Icon(Icons.visibility_rounded, color: _colorMid, size: 18),
                const SizedBox(width: 8),
                Text('Preview Nota — belum tersimpan', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: UColors.textDark)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(_isBeli ? 'Supplier' : 'Customer', style: const TextStyle(
                      fontSize: 11, color: UColors.textLight)),
                  Text(party, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(_autoDate
                      ? 'Tanggal: hari ini'
                      : 'Tanggal: ${_manualDate != null ? _fmtDatePretty(_manualDate!) : '-'}',
                      style: const TextStyle(fontSize: 11, color: UColors.textMid)),
                  const SizedBox(height: 14),
                  ..._cart.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.productName +
                                (c.isReturn ? ' ($_reverseLabel)' : ''),
                                style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                            Text('${_fmtQty(c.qty)} kg × ${_rp(c.price)}'
                                '${(c.note ?? '').isNotEmpty ? ' — ${c.note}' : ''}',
                                style: const TextStyle(fontSize: 11,
                                    color: UColors.textMid)),
                          ])),
                      Text((c.isReturn ? '− ' : '') + _rp(c.subtotal),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: c.isReturn ? const Color(0xFFC2410C) : UColors.textDark)),
                    ]),
                  )),
                  const Divider(height: 24),
                  _RingkasanRow('Subtotal', _rp(_subtotal)),
                  if (_revSubtotal > 0)
                    _RingkasanRow('🔁 Barang $_reverseLabel', '− ${_rp(_revSubtotal)}'),
                  if (!_isBeli && _disc > 0)
                    _RingkasanRow('Diskon', '− ${_rp(_disc)}'),
                  for (final a in _adjustments.where((a) => a.amount > 0))
                    _RingkasanRow(
                      a.type == 'DP' ? 'DP' : 'Ongkir (${a.mode == 'BEBAN' ? 'Beban' : 'Potongan'})',
                      a.mode == 'BEBAN' && a.type == 'ONGKIR'
                          ? _rp(a.amount) : '− ${_rp(a.amount)}',
                    ),
                  if (_creditApplied > 0)
                    _RingkasanRow('Pakai saldo ${_creditPartyName ?? party}',
                        '− ${_rp(_creditApplied)}'),
                  const SizedBox(height: 8),
                  _RingkasanRow('TOTAL', _rp(_total), bold: true),
                  const SizedBox(height: 4),
                  Text(_isPaid ? '✓ LUNAS' : '⏳ BELUM LUNAS', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: _isPaid ? UColors.success : UColors.warning)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Baris "Potongan & Biaya" (DP/Ongkir) ──────
  Widget _buildAdjRow(int i) {
    final row = _adjustments[i];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: UColors.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _colorMid.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: row.type,
              isDense: true,
              decoration: const InputDecoration(
                  isDense: true, border: InputBorder.none,
                  labelText: 'Jenis'),
              items: const [
                DropdownMenuItem(value: 'DP', child: Text('DP')),
                DropdownMenuItem(value: 'ONGKIR', child: Text('Ongkir')),
              ],
              onChanged: (v) => setState(() => row.type = v ?? 'DP'),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _adjustments[i].dispose();
              _adjustments.removeAt(i);
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: UColors.danger.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: UColors.danger),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: row.amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Jumlah (Rp)', isDense: true,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (row.type == 'ONGKIR') ...[
          const SizedBox(height: 8),
          Row(children: [
            for (final m in ['BEBAN', 'POTONGAN'])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => row.mode = m),
                child: Container(
                  margin: EdgeInsets.only(right: m == 'BEBAN' ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: row.mode == m ? _colorMid : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _colorMid.withOpacity(0.3)),
                  ),
                  child: Center(child: Text(
                      m == 'BEBAN' ? 'Beban (Pengeluaran)' : 'Potongan Total',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: row.mode == m ? Colors.white : UColors.textMid))),
                ),
              )),
          ]),
          if (row.mode == 'BEBAN') ...[
            const SizedBox(height: 8),
            TextField(
              controller: row.categoryCtrl,
              decoration: InputDecoration(
                labelText: 'Kategori (opsional, mis. BBM/Transportasi)',
                isDense: true, filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ]),
    );
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
      appBar: UAppBar(
        title: _isEditMode ? 'Edit Nota $_editInvoiceNo' : 'Nota Transaksi',
        actions: [
          if (!_isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.folder_shared_rounded, color: Colors.white),
              tooltip: 'Draft Bersama',
              onPressed: _openSharedDrafts,
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              tooltip: 'Riwayat Nota',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotaHistoryPage(),
              )),
            ),
          ],
        ],
      ),
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
                        label: 'JUAL',
                        icon: Icons.sell_rounded,
                        active: !_isBeli,
                        onTap: () => _switchMode(false),
                      ),
                      _ModeTab(
                        label: 'BELI',
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
            if (_partyBalances.isNotEmpty) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isBeli
                      ? '💰 Ada Saldo Terbuka ke Pemasok Ini — klik nama utk pilih otomatis:'
                      : '💰 Ada Saldo Terbuka dari Orang Ini — klik nama utk pilih otomatis:',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: UColors.textMid),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _partyBalances.map((p) {
                  final name = '${p['party_name'] ?? ''}';
                  final remaining = (p['remaining'] as num?)?.toDouble() ?? 0;
                  final selected = _nameCtrl.text.trim().toLowerCase() == name.trim().toLowerCase();
                  return GestureDetector(
                    onTap: () => _pickPartyBalance(name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? _colorMid : _colorMid.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _colorMid.withOpacity(0.3)),
                      ),
                      child: Text('$name · ${_rp(remaining)}', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _colorMid)),
                    ),
                  );
                }).toList()),
              ]),
            ),
            if (_loadingBalances) const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: UField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickFromPartyHistory,
                child: Container(
                  height: 52, width: 52,
                  decoration: BoxDecoration(
                    color: _colorMid.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _colorMid.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.history_rounded, color: _colorMid, size: 22),
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

            // ── Saldo hutang/piutang pihak — bisa dipakai sbg DP ──
            // (disembunyikan saat edit -- kredit tidak bisa diubah lewat edit)
            if (!_isEditMode && _creditChecking) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Cek saldo…', style: TextStyle(
                    fontSize: 11, color: UColors.textLight)),
              ]),
            ),
            if (!_isEditMode && !_creditChecking && _creditAvailable > 0) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.savings_rounded, color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                        'Saldo tersedia ${_isBeli ? 'kita di' : ''} ${_creditPartyName ?? ''}'
                        '${_isBeli ? '' : ' ke kita'}: ${_rp(_creditAvailable)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFF047857)))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _creditCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Pakai berapa? (maks ${_rp(_creditAvailable)})',
                        isDense: true,
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF10B981).withOpacity(0.3))),
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _creditCtrl.text =
                          _creditAvailable.clamp(0, _rawTotal).toStringAsFixed(0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text('Pakai Semua', style: TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),

            // ── Tanggal nota (tidak bisa diubah lewat edit) ──
            if (!_isEditMode) ...[
            const SizedBox(height: 14),
            Text('Tanggal Nota', style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: UColors.textMid)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _autoDate = true; _manualDate = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _autoDate ? _colorMid : UColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text('Otomatis (Hari Ini)', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _autoDate ? Colors.white : UColors.textMid))),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _manualDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() { _autoDate = false; _manualDate = picked; });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_autoDate ? _colorMid : UColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(
                      !_autoDate && _manualDate != null
                          ? _fmtDatePretty(_manualDate!)
                          : 'Atur Manual',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: !_autoDate ? Colors.white : UColors.textMid))),
                ),
              )),
            ]),
            ],

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
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showMaterialPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                    color: UColors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _colorMid.withOpacity(0.18))),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: _colorMid, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selMat != null
                          ? '${_selMat!['name'] ?? _selMat!['material_name'] ?? '-'}'
                          : 'Cari & pilih barang…',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selMat != null
                              ? FontWeight.w700 : FontWeight.w400,
                          color: _selMat != null
                              ? UColors.textDark : UColors.textLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: _colorMid),
                ]),
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

            // Info stok + HPP
            if (_selMat != null) Builder(builder: (_) {
              final stok = double.tryParse(
                  '${_selMat!['qty_kg'] ?? _selMat!['stock'] ?? 0}') ?? 0.0;
              final hpp = double.tryParse(
                  '${_selMat!['avg_cost_per_kg'] ?? 0}') ?? 0.0;
              final unit = '${_selMat!['unit'] ?? 'kg'}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(
                      _isBeli ? Icons.add_box_rounded : Icons.inventory_2_rounded,
                      color: _isBeli ? _colorMid : UColors.success,
                      size: _rfs(context, 13),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isBeli
                          ? 'Stok saat ini: ${stok.toStringAsFixed(1)} $unit → akan bertambah'
                          : 'Stok tersedia: ${stok.toStringAsFixed(1)} $unit',
                      style: TextStyle(
                          fontSize: _rfs(context, 11),
                          color: _isBeli ? _colorMid : UColors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                  if (hpp > 0) Padding(
                    padding: const EdgeInsets.only(top: 3, left: 19),
                    child: Text(
                      'HPP (harga pokok rata-rata): ${_rp(hpp)} / $unit',
                      style: TextStyle(
                          fontSize: _rfs(context, 11),
                          color: UColors.textMid,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              );
            }),

            // Toggle arah kebalik — cuma relevan kalau sudah ada barang
            // lain di nota ini (baris pertama selalu arah normal).
            if (_cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _addAsReturn = !_addAsReturn),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _addAsReturn
                          ? const Color(0xFFFFF7ED)
                          : UColors.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _addAsReturn
                              ? const Color(0xFFEA580C).withOpacity(0.4)
                              : _colorMid.withOpacity(0.12)),
                    ),
                    child: Row(children: [
                      Checkbox(
                        value: _addAsReturn,
                        activeColor: const Color(0xFFEA580C),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) =>
                            setState(() => _addAsReturn = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _isBeli
                              ? 'Barang ini arah TERBALIK (kita JUAL balik ke pemasok)'
                              : 'Barang ini arah TERBALIK (kita BELI balik dari customer)',
                          style: TextStyle(
                            fontSize: _rfs(context, 11),
                            fontWeight: FontWeight.w700,
                            color: _addAsReturn
                                ? const Color(0xFFC2410C)
                                : UColors.textMid,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

            // Harga
            UField(
              controller: _priceCtrl,
              label: _isBeli
                  ? (_addAsReturn ? 'Harga Jual / kg *' : 'Harga Beli / kg *')
                  : (_addAsReturn ? 'Harga Beli / kg *' : 'Harga Jual / kg *'),
              hint: 'Contoh: 150000',
              prefixIcon: _isBeli
                  ? Icons.price_check_rounded
                  : Icons.price_change_rounded,
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 12),
            UField(
              controller: _itemNoteCtrl,
              label: 'Catatan barang (opsional)',
              hint: 'Contoh: barang kotor, sisa lot kemarin',
              prefixIcon: Icons.note_alt_outlined,
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
            if (_showStockWarning) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFC2410C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                      'Qty melebihi stok tersedia (${_selStock.toStringAsFixed(1)} kg)',
                      style: const TextStyle(fontSize: 12,
                          color: Color(0xFFC2410C),
                          fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addStockForSelected,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2410C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('+ Tambah Stok', style: TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ],
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
                              Row(children: [
                                if (item.isReturn) Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDD5),
                                      borderRadius: BorderRadius.circular(5)),
                                  child: Text('🔁 $_reverseLabel',
                                      style: const TextStyle(fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFC2410C))),
                                ),
                                Expanded(child: Text(item.productName,
                                    style: const TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: UColors.textDark))),
                              ]),
                              Text(
                                '${_rp(item.price)}/kg × '
                                    '${_fmtQty(item.qty)} = '
                                    '${_rp(item.subtotal)}',
                                style: const TextStyle(fontSize: 11,
                                    color: UColors.textMid),
                              ),
                              if ((item.note ?? '').isNotEmpty)
                                Text('📝 ${item.note}',
                                    style: const TextStyle(fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: UColors.textLight)),
                            ])),
                        Text(
                            (item.isReturn ? '− ' : '') + _rp(item.subtotal),
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800,
                                color: item.isReturn
                                    ? const Color(0xFFC2410C) : _colorMid)),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(children: [
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
                    if (_revSubtotal > 0) Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          '🔁 Barang $_reverseLabel  − ${_rp(_revSubtotal)}',
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2410C))),
                    ),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 20),

          // ══════════════════════════════════════
          //  POTONGAN & BIAYA — DP, Ongkir, dll (kedua mode)
          // ══════════════════════════════════════
          USectionHeader(title: 'Potongan & Biaya (DP, Ongkir, dll)'),
          const SizedBox(height: 12),
          _InvCard(children: [
            if (_adjustments.isEmpty)
              Text('Belum ada potongan/biaya tambahan.', style: TextStyle(
                  fontSize: 12, color: UColors.textLight)),
            for (int i = 0; i < _adjustments.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildAdjRow(i),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _adjustments.add(_AdjRow())),
              child: Row(children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: _colorMid, size: 16),
                const SizedBox(width: 6),
                Text('Tambah Baris Potongan/Biaya', style: TextStyle(
                    fontSize: 12, color: _colorMid,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline)),
              ]),
            ),
          ]),
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
                  if (_revSubtotal > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('🔁 Barang $_reverseLabel', '− ${_rp(_revSubtotal)}',
                        color: const Color(0xFFC2410C)),
                  ],
                  if (_disc > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('Diskon', '− ${_rp(_disc)}',
                        color: UColors.danger),
                  ],
                  if (_adjDpTotal > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('DP', '− ${_rp(_adjDpTotal)}', color: UColors.danger),
                  ],
                  if (_adjOngkirPotongan > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('Ongkir (Potongan)', '− ${_rp(_adjOngkirPotongan)}',
                        color: UColors.danger),
                  ],
                  if (_creditApplied > 0) ...[
                    const SizedBox(height: 8),
                    _SumRow('Pakai Saldo', '− ${_rp(_creditApplied)}',
                        color: const Color(0xFF059669)),
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
                          Text(_rp(_total),
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _cBeliDark)),
                          if (_revSubtotal > 0) Text(
                              '🔁 Barang $_reverseLabel − ${_rp(_revSubtotal)}',
                              style: const TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC2410C))),
                          if (_adjDpTotal + _adjOngkirPotongan > 0) Text(
                              'DP/Potongan − ${_rp(_adjDpTotal + _adjOngkirPotongan)}',
                              style: const TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: UColors.danger)),
                          if (_creditApplied > 0) Text(
                              'Pakai saldo − ${_rp(_creditApplied)}',
                              style: const TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669))),
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
          //  TOMBOL PREVIEW & SIMPAN DRAFT
          // ══════════════════════════════════════
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _showPreview,
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _colorMid.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: Icon(Icons.visibility_rounded, color: _colorMid, size: 18),
                label: Text('Preview', style: TextStyle(
                    color: _colorMid, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )),
            if (!_isEditMode) ...[
            const SizedBox(width: 10),
            Expanded(child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _saveSharedDraft,
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _colorMid.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: Icon(Icons.save_rounded, color: _colorMid, size: 18),
                label: Text('Simpan Draft', style: TextStyle(
                    color: _colorMid, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )),
            ],
          ]),

          // ══════════════════════════════════════
          //  TOMBOL SUBMIT
          // ══════════════════════════════════════
          const SizedBox(height: 10),
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
                    : (_isEditMode
                        ? _submitEdit
                        : (_isBeli ? _submitBeli : _submitJual)),
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
                          _isEditMode
                              ? Icons.save_rounded
                              : (_isBeli
                                  ? Icons.add_shopping_cart_rounded
                                  : Icons.print_rounded),
                          color: Colors.white, size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isEditMode
                              ? 'Simpan Perubahan'
                              : (_isBeli
                                  ? 'Catat Pembelian & Tambah Stok'
                                  : 'Buat & Cetak Nota'),
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
  Uint8List? _logoBytes;   // logo tersimpan (dari server) atau baru dipilih
  String?    _logoMime;
  bool       _loadingProfile = true;
  bool       _saving  = false;

  static const _kColor = Color(0xFF1565C0);

  @override
  void initState() { super.initState(); _loadCurrentSettings(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addrCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  // Profil umum (bukan per akun) — sumber tunggal dipakai bareng web.
  Future<void> _loadCurrentSettings() async {
    try {
      final p = await ApiService.getCompanyProfile();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text  = (p['company_name'] ?? '').toString();
        _addrCtrl.text  = (p['address'] ?? '').toString();
        _phoneCtrl.text = (p['phone'] ?? '').toString();
        final uri = (p['logo_data_uri'] ?? '').toString();
        if (uri.startsWith('data:') && uri.contains('base64,')) {
          try { _logoBytes = base64Decode(uri.split('base64,').last); } catch (_) {}
        }
        _loadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfile = false);
        uSnack(context, 'Gagal muat profil: $e', isError: true);
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final xfile = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _logoBytes = bytes;
        _logoMime  = xfile.mimeType ?? 'image/png';
      });
    } catch (e) {
      if (mounted) uSnack(context, 'Gagal pilih gambar: $e', isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateCompanyProfile(
        name:      _nameCtrl.text.trim(),
        address:   _addrCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
        logoBytes: _logoBytes,
        logoMime:  _logoMime,
      );
      if (mounted) {
        Navigator.pop(context);
        uSnack(context, 'Pengaturan nota disimpan (berlaku utk semua akun) ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        uSnack(context, 'Gagal simpan: $e', isError: true);
      }
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
              Text('Umum — berlaku di semua akun & perangkat', style: TextStyle(
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
                  child: _loadingProfile
                      ? const Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_logoBytes != null
                          ? Image.memory(_logoBytes!, fit: BoxFit.contain)
                          : const Icon(Icons.image_outlined,
                              color: Color(0xFF90A4AE), size: 32))),
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
              if (_logoBytes != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _logoBytes = null),
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