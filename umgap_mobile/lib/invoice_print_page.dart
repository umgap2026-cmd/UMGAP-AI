import 'dart:io';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api_service.dart';
import 'invoice_page.dart';

// ════════════════════════════════════════════
//  TOP-LEVEL HELPERS
// ════════════════════════════════════════════

String _fmtQ(double q) =>
    q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

String _rp(num v) =>
    'Rp ${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

String _rpNoPrefix(num v) =>
    v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

PdfColor _pdfAlpha(PdfColor c, double alpha) =>
    PdfColor(c.red, c.green, c.blue, alpha);

// ── PDF Colors ────────────────────────────────
const _pdfWhite   = PdfColor(1, 1, 1);
const _pdfWhite60 = PdfColor(1, 1, 1, 0.60);
const _pdfWhite24 = PdfColor(1, 1, 1, 0.24);
const _pdfBlue    = PdfColor(0.085, 0.396, 0.753);
const _pdfBlueDk  = PdfColor(0.051, 0.278, 0.631);
const _pdfBlueLt  = PdfColor(0.890, 0.941, 1.000);
const _pdfGrey    = PdfColor(0.957, 0.969, 1.000);
const _pdfBorder  = PdfColor(0.886, 0.910, 0.941);
const _pdfTextMid = PdfColor(0.290, 0.337, 0.471);
const _pdfTextLt  = PdfColor(0.565, 0.643, 0.682);
const _pdfSuccess = PdfColor(0.180, 0.490, 0.196);
const _pdfDanger  = PdfColor(0.776, 0.157, 0.157);
const _pdfOrange  = PdfColor(0.900, 0.400, 0.000);

// ── Flutter Colors ────────────────────────────
const _kPrimary     = Color(0xFF1565C0);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kPrimaryMid  = Color(0xFF1E88E5);
const _kSurface     = Color(0xFFF4F7FF);
const _kTextDark    = Color(0xFF0D1B3E);

// ════════════════════════════════════════════
//  InvoicePrintPage
// ════════════════════════════════════════════
class InvoicePrintPage extends StatefulWidget {
  final dynamic       invoiceId;
  final String        invoiceNo;
  final String        customerName;
  final String        customerPhone;
  final String        paymentMethod;
  final String        notes;
  final double        discount;
  final double        subtotal;
  final double        grandTotal;
  final List<CartItem> items;
  final bool          isPaid;
  // ── Nota Beli ──
  final bool                         isBeli;
  final List<Map<String, dynamic>>?  beliRawItems; // material_id, qty_kg, price_per_kg

  const InvoicePrintPage({
    super.key,
    required this.invoiceId,
    required this.invoiceNo,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMethod,
    required this.notes,
    required this.discount,
    required this.subtotal,
    required this.grandTotal,
    required this.items,
    this.isPaid      = true,
    this.isBeli      = false,
    this.beliRawItems,
  });

  @override
  State<InvoicePrintPage> createState() => _InvoicePrintPageState();
}

class _InvoicePrintPageState extends State<InvoicePrintPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int     _paperWidth = 80;
  bool    _btPrinting = false;
  String? _connectedBt;
  bool    _dbSaved    = false; // mencegah double-save ke DB

  // Company info
  String     _companyName  = '';
  String     _companyAddr  = '';
  String     _companyPhone = '';
  String     _logoPath     = '';
  Uint8List? _logoBytes;

  static const _disclaimer = 'Tidak menerima barang yang bertentangan dengan hukum!';
  static const _poweredBy  = 'Powered by UMGAP';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  // ── Load dari FlutterSecureStorage, fallback ke API ──
  Future<void> _loadSettings() async {
    // 1. Coba dari secure storage (prioritas)
    try {
      final name  = await readNotaSetting(kNotaName);
      final addr  = await readNotaSetting(kNotaAddr);
      final phone = await readNotaSetting(kNotaPhone);
      final logo  = await readNotaSetting(kNotaLogo);

      if (mounted && (name.isNotEmpty || addr.isNotEmpty)) {
        setState(() {
          if (name.isNotEmpty)  _companyName  = name;
          if (addr.isNotEmpty)  _companyAddr  = addr;
          if (phone.isNotEmpty) _companyPhone = phone;
          _logoPath = logo;
        });
      }

      // Load logo bytes untuk PDF
      if (logo.isNotEmpty) {
        final f = File(logo);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (mounted) setState(() => _logoBytes = bytes);
        }
      }
    } catch (_) {}

    // 2. Jika nama masih kosong, fallback ke API profile
    if (_companyName.isEmpty) {
      try {
        final p = await ApiService.getMyProfile();
        if (!mounted) return;
        setState(() {
          if (_companyName.isEmpty)
            _companyName = (p['company_name'] ?? p['full_name'] ?? '')
                .toString().trim();
          if (_companyAddr.isEmpty)
            _companyAddr = (p['address'] ?? p['alamat'] ?? '')
                .toString().trim();
          if (_companyPhone.isEmpty)
            _companyPhone = (p['phone'] ?? p['hp'] ?? '')
                .toString().trim();
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _dateStr {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2,'0')}/'
        '${n.month.toString().padLeft(2,'0')}/'
        '${n.year}  '
        '${n.hour.toString().padLeft(2,'0')}:'
        '${n.minute.toString().padLeft(2,'0')}';
  }

  String get _dateOnly {
    final n = DateTime.now();
    const months = ['','Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'];
    return '${n.day} ${months[n.month]} ${n.year}';
  }

  // ══════════════════════════════════════════
  //  PROFESSIONAL A4 PDF
  // ══════════════════════════════════════════
  Future<Uint8List> _buildProfessionalPdf() async {
    final doc = pw.Document();

    // Logo image untuk PDF
    pw.MemoryImage? logoImg;
    if (_logoBytes != null) {
      logoImg = pw.MemoryImage(_logoBytes!);
    }

    // Warna & teks cap sesuai mode
    final stampColor = widget.isBeli
        ? _pdfSuccess  // teal/hijau untuk BELI
        : (widget.isPaid ? _pdfSuccess : _pdfOrange);
    final stampText1 = widget.isBeli
        ? 'BELI'
        : (widget.isPaid ? 'LUNAS' : 'BELUM');
    final stampText2 = widget.isBeli
        ? null
        : (widget.isPaid ? null : 'LUNAS');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Stack(
        children: [

          // ── CAP LUNAS / BELUM LUNAS di tengah ──
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: -0.38, // ~-22°
                child: pw.Opacity(
                  opacity: 0.22,
                  child: pw.Container(
                    width: 190,
                    height: 190,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(
                        color: stampColor,
                        width: 7,
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            stampText1,
                            style: pw.TextStyle(
                              fontSize: widget.isPaid ? 44 : 32,
                              fontWeight: pw.FontWeight.bold,
                              color: stampColor,
                              letterSpacing: 2,
                            ),
                          ),
                          if (stampText2 != null)
                            pw.Text(
                              stampText2,
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: stampColor,
                                letterSpacing: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── KONTEN UTAMA ────────────────────────
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── HEADER ──
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _pdfBlue,
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Kiri: logo + info perusahaan
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImg != null) ...[
                          pw.Container(
                            height: 48,
                            child: pw.Image(logoImg,
                                fit: pw.BoxFit.contain),
                          ),
                          pw.SizedBox(height: 8),
                        ],
                        pw.Text(
                          _companyName.isNotEmpty
                              ? _companyName.toUpperCase()
                              : 'PERUSAHAAN',
                          style: pw.TextStyle(
                            color: _pdfWhite,
                            fontSize: logoImg != null ? 16 : 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        if (_companyAddr.isNotEmpty)
                          pw.Text(_companyAddr,
                              style: pw.TextStyle(
                                  color: _pdfWhite60, fontSize: 9)),
                        if (_companyPhone.isNotEmpty)
                          pw.Text('Telp: $_companyPhone',
                              style: pw.TextStyle(
                                  color: _pdfWhite60, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text(_poweredBy,
                            style: pw.TextStyle(
                                color: _pdfWhite24, fontSize: 8)),
                      ],
                    ),
                    // Kanan: INVOICE label + no
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            widget.isBeli ? 'NOTA BELI' : 'INVOICE',
                            style: pw.TextStyle(
                                color: _pdfWhite, fontSize: 26,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 3)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: _pdfWhite24,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(widget.invoiceNo,
                              style: pw.TextStyle(
                                  color: _pdfWhite, fontSize: 11,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: _pdfAlpha(stampColor, 0.25),
                            borderRadius: pw.BorderRadius.circular(6),
                            border: pw.Border.all(
                              color: _pdfAlpha(stampColor, 0.7),
                            ),
                          ),
                          child: pw.Text(
                            widget.isBeli
                                ? (widget.isPaid ? '✓  SUDAH BAYAR' : '⏳  BELUM BAYAR')
                                : (widget.isPaid ? '✓  LUNAS' : '⏳  BELUM LUNAS'),
                            style: pw.TextStyle(
                              color: stampColor,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ── DETAIL INVOICE + CUSTOMER ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Detail invoice (kiri)
                  pw.Expanded(child: pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: _pdfGrey,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: _pdfBorder),
                    ),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DETAIL INVOICE',
                              style: pw.TextStyle(fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfTextLt, letterSpacing: 1)),
                          pw.SizedBox(height: 8),
                          _infoRow('Tanggal',    _dateOnly),
                          pw.SizedBox(height: 4),
                          _infoRow('No. Invoice', widget.invoiceNo),
                          pw.SizedBox(height: 4),
                          _infoRow('Pembayaran', widget.paymentMethod),
                        ]),
                  )),
                  pw.SizedBox(width: 14),
                  // Customer/Supplier (kanan)
                  pw.Expanded(child: pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: _pdfBlueLt,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                          color: _pdfAlpha(_pdfBlue, 0.3)),
                    ),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                              widget.isBeli ? 'SUPPLIER' : 'TAGIHAN KEPADA',
                              style: pw.TextStyle(fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfBlue, letterSpacing: 1)),
                          pw.SizedBox(height: 8),
                          pw.Text(widget.customerName,
                              style: pw.TextStyle(fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfBlueDk)),
                          if (widget.customerPhone.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(widget.customerPhone,
                                style: pw.TextStyle(
                                    fontSize: 10, color: _pdfTextMid)),
                          ],
                        ]),
                  )),
                ],
              ),

              pw.SizedBox(height: 22),

              // ── TABEL ITEM ──
              pw.Text(
                  widget.isBeli ? 'RINCIAN PEMBELIAN' : 'RINCIAN PEMBELIAN',
                  style: pw.TextStyle(fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfTextLt, letterSpacing: 1)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder(
                  bottom: pw.BorderSide(color: _pdfBorder),
                  horizontalInside: pw.BorderSide(
                      color: _pdfBorder, width: 0.5),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.5),
                  1: pw.FlexColumnWidth(3.5),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.8),
                  4: pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: _pdfBlue),
                    children: [
                      _th('#'),
                      _th(widget.isBeli ? 'Nama Barang' : 'Nama Barang'),
                      _th('Qty', align: pw.TextAlign.center),
                      _th(widget.isBeli ? 'Harga Beli/kg' : 'Harga/kg',
                          align: pw.TextAlign.right),
                      _th('Subtotal', align: pw.TextAlign.right),
                    ],
                  ),
                  ...List.generate(widget.items.length, (i) {
                    final item   = widget.items[i];
                    final isEven = i % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: isEven ? _pdfWhite : _pdfGrey),
                      children: [
                        _td('${i + 1}', color: _pdfTextLt),
                        _td(item.productName, bold: true),
                        _td('${_fmtQ(item.qty)} kg',
                            align: pw.TextAlign.center),
                        _td(_rp(item.price),
                            align: pw.TextAlign.right),
                        _td(_rp(item.subtotal),
                            align: pw.TextAlign.right, bold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 18),

              // ── TOTAL + CATATAN ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Catatan
                  pw.Expanded(
                    child: widget.notes.isNotEmpty
                        ? pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _pdfGrey,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: _pdfBorder),
                      ),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CATATAN',
                                style: pw.TextStyle(fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _pdfTextLt, letterSpacing: 1)),
                            pw.SizedBox(height: 6),
                            pw.Text(widget.notes,
                                style: pw.TextStyle(
                                    fontSize: 10,
                                    color: _pdfTextMid)),
                          ]),
                    )
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(width: 20),
                  // Totals
                  pw.SizedBox(
                    width: 210,
                    child: pw.Column(children: [
                      _totalRow('Subtotal', _rp(widget.subtotal)),
                      if (widget.discount > 0) ...[
                        pw.Divider(color: _pdfBorder, height: 8),
                        _totalRowColor('Diskon',
                            '− ${_rp(widget.discount)}', _pdfDanger),
                      ],
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(14),
                        decoration: pw.BoxDecoration(
                          color: _pdfBlue,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL',
                                style: pw.TextStyle(color: _pdfWhite,
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(_rp(widget.grandTotal),
                                style: pw.TextStyle(color: _pdfWhite,
                                    fontSize: 15,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── FOOTER ──
              pw.Divider(color: _pdfBorder),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('UMGAP — Sistem Manajemen UMKM',
                      style: pw.TextStyle(
                          fontSize: 8, color: _pdfTextLt)),
                  pw.Text('Dicetak: $_dateStr',
                      style: pw.TextStyle(
                          fontSize: 8, color: _pdfTextLt)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Terima kasih atas kepercayaan Anda!',
                    style: pw.TextStyle(fontSize: 10, color: _pdfBlue,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(_disclaimer,
                    style: pw.TextStyle(
                        fontSize: 8, color: _pdfTextLt)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(_poweredBy,
                    style: pw.TextStyle(
                        fontSize: 8, color: _pdfTextLt)),
              ),
            ],
          ),
        ],
      ),
    ));

    return doc.save();
  }

  // ── PDF Table Helpers ──
  static pw.Widget _th(String text,
      {pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(text,
            textAlign: align ?? pw.TextAlign.left,
            style: pw.TextStyle(color: _pdfWhite, fontSize: 9,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _td(String text,
      {pw.TextAlign? align, bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text,
            textAlign: align ?? pw.TextAlign.left,
            style: pw.TextStyle(fontSize: 9,
                fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? _pdfBlueDk)),
      );

  static pw.Widget _infoRow(String label, String value) =>
      pw.Row(children: [
        pw.SizedBox(
            width: 75,
            child: pw.Text('$label  ',
                style: pw.TextStyle(fontSize: 9, color: _pdfTextLt))),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9, color: _pdfTextMid,
                fontWeight: pw.FontWeight.bold)),
      ]);

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 10, color: _pdfTextMid)),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 10, color: _pdfBlueDk,
                  fontWeight: pw.FontWeight.bold)),
        ]),
  );

  static pw.Widget _totalRowColor(
      String label, String value, PdfColor vc) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontSize: 10, color: _pdfTextMid)),
              pw.Text(value,
                  style: pw.TextStyle(fontSize: 10, color: vc,
                      fontWeight: pw.FontWeight.bold)),
            ]),
      );

  // ══════════════════════════════════════════
  //  THERMAL PDF (58/80mm roll)
  // ══════════════════════════════════════════
  Future<Uint8List> _buildThermalPdf() async {
    final doc = pw.Document();
    final pageW = _paperWidth == 58
        ? PdfPageFormat(58 * PdfPageFormat.mm, double.infinity,
        marginAll: 3 * PdfPageFormat.mm)
        : PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
        marginAll: 3 * PdfPageFormat.mm);

    pw.MemoryImage? logoImg;
    if (_logoBytes != null) logoImg = pw.MemoryImage(_logoBytes!);

    doc.addPage(pw.Page(
      pageFormat: pageW,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo
          if (logoImg != null) ...[
            pw.Center(
              child: pw.SizedBox(
                height: 45,
                child: pw.Image(logoImg, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 6),
          ],
          pw.Center(child: pw.Text(
            _companyName.isNotEmpty
                ? _companyName.toUpperCase() : 'NOTA TRANSAKSI',
            style: pw.TextStyle(fontSize: 13,
                fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          )),
          if (_companyAddr.isNotEmpty)
            pw.Center(child: pw.Text(_companyAddr,
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center)),
          if (_companyPhone.isNotEmpty)
            pw.Center(child: pw.Text('Telp: $_companyPhone',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center)),
          pw.Divider(),
          pw.Center(child: pw.Text('NOTA TRANSAKSI',
              style: pw.TextStyle(fontSize: 10,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center)),
          pw.Center(child: pw.Text(_dateStr,
              style: pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center)),
          pw.Divider(),
          if (widget.customerName.isNotEmpty)
            pw.Text('Kepada  : ${widget.customerName}',
                style: pw.TextStyle(fontSize: 9)),
          if (widget.customerPhone.isNotEmpty)
            pw.Text('HP      : ${widget.customerPhone}',
                style: pw.TextStyle(fontSize: 8)),
          pw.Text('No. Nota: ${widget.invoiceNo}',
              style: pw.TextStyle(fontSize: 8)),
          pw.Divider(),
          ...widget.items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.productName,
                      style: pw.TextStyle(fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Row(
                      mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '${_fmtQ(item.qty)} kg x ${_rp(item.price)}',
                            style: pw.TextStyle(fontSize: 8)),
                        pw.Text(_rp(item.subtotal),
                            style: pw.TextStyle(fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
                      ]),
                ]),
          )),
          pw.Divider(),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal',
                    style: pw.TextStyle(fontSize: 8)),
                pw.Text(_rp(widget.subtotal),
                    style: pw.TextStyle(fontSize: 8)),
              ]),
          if (widget.discount > 0)
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Diskon',
                      style: pw.TextStyle(fontSize: 8)),
                  pw.Text('- ${_rp(widget.discount)}',
                      style: pw.TextStyle(fontSize: 8)),
                ]),
          pw.Divider(thickness: 1.5),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(_rp(widget.grandTotal),
                    style: pw.TextStyle(fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
              ]),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Bayar',
                    style: pw.TextStyle(fontSize: 8)),
                pw.Text(widget.paymentMethod,
                    style: pw.TextStyle(fontSize: 8)),
              ]),
          if (widget.notes.isNotEmpty) ...[
            pw.Divider(),
            pw.Center(child: pw.Text(widget.notes,
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center)),
          ],
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              widget.isPaid ? '*** LUNAS ***' : '[ BELUM LUNAS ]',
              style: pw.TextStyle(fontSize: 10,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('-- Terima Kasih --',
              style: pw.TextStyle(fontSize: 9,
                  fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(_disclaimer,
              style: pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text(_poweredBy,
              style: pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center)),
          pw.SizedBox(height: 4),
        ],
      ),
    ));

    return doc.save();
  }

  // ══════════════════════════════════════════
  //  ESC/POS BYTES untuk Bluetooth
  //  ATURAN PRINT AMAN:
  //  • feed(3) sebelum cut
  //  • cut(mode: PosCutMode.full)
  //  • delay(1500ms) sebelum disconnect
  //  • guard _btPrinting
  // ══════════════════════════════════════════
  Future<List<int>> _buildEscPosBytes() async {
    final profile   = await CapabilityProfile.load();
    final generator = Generator(
      _paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );

    final W = _paperWidth == 58 ? 32 : 48;

    String lr(String left, String right) {
      final sp = W - left.length - right.length;
      return sp > 0 ? left + ' ' * sp + right : '$left $right';
    }
    String dash(String ch) => ch * W;

    List<String> wrap(String t) {
      if (t.length <= W) return [t];
      final words = t.split(' ');
      final lines = <String>[];
      var line = '';
      for (final w in words) {
        if ((line.isEmpty ? w : '$line $w').length <= W) {
          line = line.isEmpty ? w : '$line $w';
        } else {
          if (line.isNotEmpty) lines.add(line);
          line = w;
        }
      }
      if (line.isNotEmpty) lines.add(line);
      return lines;
    }

    final name = _companyName.isNotEmpty ? _companyName : 'Perusahaan';

    List<int> bytes = [];
    bytes += generator.setGlobalCodeTable('CP1252');

    // ── HEADER ──────────────────────────────
    // Nama perusahaan — PosAlign.center tanpa manual padding
    // (size2 = double width, jadi biarkan printer yang center)
    bytes += generator.text(name.toUpperCase(),
        styles: const PosStyles(
            align: PosAlign.center, bold: true,
            height: PosTextSize.size2, width: PosTextSize.size2));

    bytes += generator.feed(1);

    if (_companyAddr.isNotEmpty) {
      for (final l in wrap(_companyAddr)) {
        bytes += generator.text(l,
            styles: const PosStyles(align: PosAlign.center));
      }
    }
    if (_companyPhone.isNotEmpty) {
      bytes += generator.text('Telp: $_companyPhone',
          styles: const PosStyles(align: PosAlign.center));
    }

    bytes += generator.text(dash('='));

    bytes += generator.text(
      widget.isBeli ? 'NOTA PEMBELIAN' : 'NOTA TRANSAKSI',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(_dateStr,
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.text(dash('-'));

    // ── CUSTOMER ─────────────────────────────
    if (widget.customerName.isNotEmpty) {
      bytes += generator.text(
        widget.isBeli
            ? 'Supplier : ${widget.customerName}'
            : 'Kepada   : ${widget.customerName}',
      );
    }
    if (widget.customerPhone.isNotEmpty) {
      bytes += generator.text('HP      : ${widget.customerPhone}');
    }
    if (widget.invoiceNo.isNotEmpty) {
      bytes += generator.text('No. Nota: ${widget.invoiceNo}');
    }
    bytes += generator.text(dash('-'));

    // ── ITEMS ────────────────────────────────
    for (final item in widget.items) {
      final nameStr = item.productName.length > W
          ? '${item.productName.substring(0, W - 2)}..'
          : item.productName;
      bytes += generator.text(nameStr,
          styles: const PosStyles(bold: true));
      final left  = '  ${_fmtQ(item.qty)}kg x ${_rpNoPrefix(item.price)}';
      final right = _rpNoPrefix(item.subtotal);
      bytes += generator.text(lr(left, right));
    }
    bytes += generator.text(dash('-'));

    // ── SUBTOTAL ─────────────────────────────
    bytes += generator.text(lr('Subtotal', _rp(widget.subtotal)));
    if (widget.discount > 0) {
      bytes += generator.text(lr('Diskon', '- ${_rp(widget.discount)}'));
    }
    bytes += generator.text(dash('='));

    // ── TOTAL (2x size) ─── pakai PosAlign.center, tanpa manual pad
    bytes += generator.text('TOTAL',
        styles: const PosStyles(
            align: PosAlign.left, bold: true,
            height: PosTextSize.size2, width: PosTextSize.size2));
    // Total amount di baris berikut, rata kanan
    final totalStr = _rp(widget.grandTotal);
    final totalPad = W - totalStr.length;
    bytes += generator.text(
        totalPad > 0 ? ' ' * totalPad + totalStr : totalStr,
        styles: const PosStyles(bold: true));

    bytes += generator.text(dash('-'));
    bytes += generator.text(lr('Bayar', widget.paymentMethod));

    // ── CATATAN ──────────────────────────────
    if (widget.notes.isNotEmpty) {
      bytes += generator.text(dash('-'));
      for (final l in wrap(widget.notes)) {
        bytes += generator.text(l,
            styles: const PosStyles(align: PosAlign.center));
      }
    }

    // ── STATUS ───────────────────────────────
    bytes += generator.text(dash('='));
    bytes += generator.text(
      widget.isPaid ? '*** LUNAS ***' : '[ BELUM LUNAS ]',
      styles: const PosStyles(
          align: PosAlign.center, bold: true),
    );
    bytes += generator.text(dash('='));

    // ── FOOTER ───────────────────────────────
    bytes += generator.feed(1);
    bytes += generator.text('-- Terima Kasih --',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);
    for (final l in wrap(_disclaimer)) {
      bytes += generator.text(l,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.feed(1);
    bytes += generator.text(_poweredBy,
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(3);
    bytes += generator.cut(mode: PosCutMode.full);

    return bytes;
  }

  // ── Print via Bluetooth ───────────────────
  Future<void> _showBtSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BtSheet(
        onPrint: (mac, name) => _printViaBt(mac, name),
      ),
    );
  }

  Future<void> _printViaBt(String mac, String deviceName) async {
    if (_btPrinting) return;
    setState(() => _btPrinting = true);
    try {
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(const Duration(milliseconds: 300));

      final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: mac);
      if (!connected) throw 'Gagal terhubung ke $deviceName';

      final isConn = await PrintBluetoothThermal.connectionStatus;
      if (!isConn) throw 'Printer tidak merespons';

      final bytes = await _buildEscPosBytes();
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      if (!result) throw 'Gagal mengirim data ke printer';

      await Future.delayed(const Duration(milliseconds: 1500));
      await PrintBluetoothThermal.disconnect;

      if (!mounted) return;
      setState(() { _connectedBt = deviceName; _btPrinting = false; });
      _snack('Berhasil cetak ke $deviceName ✓');
    } catch (e) {
      if (!mounted) return;
      await PrintBluetoothThermal.disconnect;
      setState(() => _btPrinting = false);
      _snack('Gagal cetak: $e', isError: true);
    }
  }

  // ── Warna tema: Beli = teal, Jual = biru ─────
  Color get _themeColor => widget.isBeli
      ? const Color(0xFF00796B) : const Color(0xFF1565C0);
  Color get _themeDark  => widget.isBeli
      ? const Color(0xFF00695C) : const Color(0xFF0D47A1);
  Color get _themeLight => widget.isBeli
      ? const Color(0xFF00897B) : const Color(0xFF1E88E5);

  // ══════════════════════════════════════════════
  //  CATAT KE DATABASE (manual button)
  //  JUAL  → financeJual (kirim ke laporan)
  //  BELI  → financeBeli (tambah stok + HPP)
  // ══════════════════════════════════════════════
  Future<void> _sendToDb() async {
    if (_dbSaved) {
      _snack('Sudah pernah dicatat ke database');
      return;
    }

    final isBeli  = widget.isBeli;
    final title   = isBeli ? 'Catat ke Stok Gudang?' : 'Kirim ke Laporan?';
    final icon    = isBeli ? Icons.add_box_rounded : Icons.account_balance_wallet_rounded;
    final color   = isBeli ? const Color(0xFF00796B) : const Color(0xFF1565C0);
    final content = isBeli
        ? 'Stok gudang & HPP akan diperbarui untuk ${widget.items.length} '
        'barang senilai ${_rp(widget.grandTotal)}.\n\n'
        'Supplier: ${widget.customerName}'
        : 'Catat penjualan "${widget.customerName.isNotEmpty
        ? widget.customerName : 'Customer'}" '
        'sebesar ${_rp(widget.grandTotal)} ke laporan keuangan?';
    final btnLabel = isBeli ? 'Catat ke Gudang' : 'Kirim';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),  // ← tambah Expanded
        ]),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(btnLabel,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      if (isBeli) {
        // ── BELI: tambah stok + HPP via financeBeli ──
        final rawItems = widget.beliRawItems ?? widget.items.map((i) => {
          'material_id':  i.productId,
          'qty_kg':       i.qty,
          'price_per_kg': i.price,
        }).toList();

        await ApiService.financeBeli(
          partyName: widget.customerName.isNotEmpty
              ? widget.customerName : 'Supplier',
          isDebt: !widget.isPaid,
          note:   '${widget.invoiceNo} - ${widget.paymentMethod}',
          items:  rawItems,
        );
        if (!mounted) return;
        setState(() => _dbSaved = true);
        _snack('✓ Stok & HPP gudang berhasil diperbarui');
      } else {
        // ── JUAL: buat invoice + kurangi stok ──
        await ApiService.financeCreateInvoice(
          header: {
            'customer_name':  widget.customerName,
            'customer_phone': widget.customerPhone,
            'payment_method': widget.paymentMethod,
            'notes':          widget.notes,
            'discount':       widget.discount.toInt(),
            'is_paid':        widget.isPaid ? '1' : '0',
          },
          items: widget.items.map((i) => {
            'material_id': i.productId,
            'qty':         i.qty,
            'price':       i.price,
          }).toList(),
        );
        if (!mounted) return;
        setState(() => _dbSaved = true);
        _snack('✓ Berhasil dicatat ke laporan keuangan');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal catat: $e', isError: true);
    }
  }

  Future<void> _shareProfessionalPdf() async {
    try {
      final bytes = await _buildProfessionalPdf();
      await Printing.sharePdf(
          bytes: bytes,
          filename: 'Invoice_${widget.invoiceNo}.pdf');
    } catch (e) {
      if (mounted) _snack('Gagal buat PDF: $e', isError: true);
    }
  }

  Future<void> _previewProfessionalPdf() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(widget.invoiceNo),
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _shareProfessionalPdf,
            ),
          ],
        ),
        body: PdfPreview(
          build: (_) => _buildProfessionalPdf(),
          allowPrinting: false,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
        ),
      ),
    ));
  }

  Future<void> _shareThermalPdf() async {
    try {
      final bytes = await _buildThermalPdf();
      await Printing.sharePdf(
          bytes: bytes,
          filename: 'Thermal_${widget.invoiceNo}.pdf');
    } catch (e) {
      if (mounted) _snack('Gagal buat PDF: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFC62828) : _kPrimary,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════
  //  THERMAL TEXT PREVIEW (Flutter widget)
  // ══════════════════════════════════════════
  Widget _buildThermalPreview() {
    final charW = _paperWidth == 58 ? 32 : 48;
    final pxW   = _paperWidth == 58 ? 216.0 : 290.0;
    final fSz   = _paperWidth == 58 ? 7.5 : 8.5;

    String lr(String l, String r) {
      final sp = charW - l.length - r.length;
      return sp > 0 ? l + ' ' * sp + r : '$l $r';
    }
    String dash(String ch) => ch * charW;
    List<String> wrap(String t) {
      if (t.length <= charW) return [t];
      final words = t.split(' ');
      final lines = <String>[];
      var line = '';
      for (final w in words) {
        if ((line.isEmpty ? w : '$line $w').length <= charW) {
          line = line.isEmpty ? w : '$line $w';
        } else {
          if (line.isNotEmpty) lines.add(line);
          line = w;
        }
      }
      if (line.isNotEmpty) lines.add(line);
      return lines;
    }

    final name = _companyName.isNotEmpty ? _companyName : 'Perusahaan';

    // Buat daftar baris untuk monospace preview
    final lines = <_ThermalLine>[
      _ThermalLine('', size: 1),
      _ThermalLine(name.toUpperCase(),
          bold: true, size: 2, isCenter: true),
      _ThermalLine('', size: 1),
      if (_companyAddr.isNotEmpty)
        ...wrap(_companyAddr).map((l) =>
            _ThermalLine(l, isCenter: true)),
      if (_companyPhone.isNotEmpty)
        _ThermalLine('Telp: $_companyPhone', isCenter: true),
      _ThermalLine(dash('='), bold: true),
      _ThermalLine(
        widget.isBeli ? 'NOTA PEMBELIAN' : 'NOTA TRANSAKSI',
        bold: true, isCenter: true,
      ),
      _ThermalLine(_dateStr, isCenter: true),
      _ThermalLine(dash('-')),
      if (widget.customerName.isNotEmpty)
        _ThermalLine(
          widget.isBeli
              ? 'Supplier : ${widget.customerName}'
              : 'Kepada   : ${widget.customerName}',
        ),
      if (widget.customerPhone.isNotEmpty)
        _ThermalLine('HP       : ${widget.customerPhone}'),
      if (widget.invoiceNo.isNotEmpty)
        _ThermalLine('No. Nota : ${widget.invoiceNo}'),
      _ThermalLine(dash('-')),
      ...widget.items.expand((item) {
        final n = item.productName.length > charW
            ? '${item.productName.substring(0, charW - 2)}..'
            : item.productName;
        final left  = '  ${_fmtQ(item.qty)}kg x ${_rpNoPrefix(item.price)}';
        final right = _rpNoPrefix(item.subtotal);
        return [
          _ThermalLine(n, bold: true),
          _ThermalLine(lr(left, right)),
        ];
      }),
      _ThermalLine(dash('-')),
      _ThermalLine(lr('Subtotal', _rp(widget.subtotal))),
      if (widget.discount > 0)
        _ThermalLine(lr('Diskon', '- ${_rp(widget.discount)}')),
      _ThermalLine(dash('=')),
      // TOTAL baris sendiri
      _ThermalLine('TOTAL', bold: true, size: 2, isCenter: false),
      _ThermalLine(_rp(widget.grandTotal), bold: true, size: 2, isRight: true),
      _ThermalLine(dash('-')),
      _ThermalLine(lr('Bayar', widget.paymentMethod)),
      if (widget.notes.isNotEmpty) ...[
        _ThermalLine(dash('-')),
        ...wrap(widget.notes).map((l) =>
            _ThermalLine(l, isCenter: true)),
      ],
      _ThermalLine(dash('=')),
      _ThermalLine(
        widget.isPaid ? '*** LUNAS ***' : '[ BELUM LUNAS ]',
        bold: true, isCenter: true,
      ),
      _ThermalLine(dash('=')),
      _ThermalLine('', size: 1),
      _ThermalLine('-- Terima Kasih --', bold: true, isCenter: true),
      _ThermalLine('', size: 1),
      ...wrap(_disclaimer).map((l) =>
          _ThermalLine(l, isCenter: true, small: true)),
      _ThermalLine('', size: 1),
      _ThermalLine(_poweredBy, isCenter: true, small: true),
      _ThermalLine('', size: 1),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final maxW  = constraints.maxWidth.isInfinite
          ? 320.0 : constraints.maxWidth;
      final cardW = pxW.clamp(0.0, maxW);

      return Center(
        child: ClipRect(
          child: Container(
            width: cardW,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 12,
                  offset: Offset(0, 4))],
            ),
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo di atas
                if (_logoBytes != null) ...[
                  Center(
                    child: SizedBox(
                      height: 52,
                      child: Image.memory(
                        _logoBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (_logoPath.isNotEmpty &&
                    File(_logoPath).existsSync()) ...[
                  Center(
                    child: SizedBox(
                      height: 52,
                      child: Image.file(
                        File(_logoPath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Baris-baris teks
                ...lines.map((line) {
                  final fs = line.small
                      ? fSz - 1.5
                      : (line.size == 2 ? fSz + 3.5 : fSz);
                  TextAlign align = TextAlign.left;
                  if (line.isCenter) align = TextAlign.center;
                  if (line.isRight)  align = TextAlign.right;

                  return SizedBox(
                    width: cardW - 20,
                    child: Text(
                      // strip leading spaces untuk isCenter
                      // agar TextAlign.center bekerja benar
                      line.isCenter ? line.text.trim() : line.text,
                      overflow: line.isCenter || line.size == 2
                          ? TextOverflow.visible
                          : TextOverflow.clip,
                      softWrap: line.isCenter || line.size == 2,
                      textAlign: align,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: fs,
                        height: line.size == 2 ? 2.0 : 1.5,
                        color: Colors.black87,
                        fontWeight: line.bold
                            ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_themeDark, _themeColor, _themeLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.invoiceNo.isNotEmpty
                          ? widget.invoiceNo : 'Cetak Nota',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(children: [
                      Text(
                        widget.isBeli ? '🛒 NOTA BELI' :
                        (widget.isPaid ? '✓ LUNAS' : '⏳ BELUM LUNAS'),
                        style: TextStyle(
                          color: widget.isBeli
                              ? Colors.white70
                              : (widget.isPaid
                              ? Colors.greenAccent
                              : Colors.orangeAccent),
                          fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_dbSaved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('✓ Tersimpan',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ],
                )),
                // ── Tombol Catat ke DB (manual) ──────
                IconButton(
                  icon: Icon(
                    widget.isBeli
                        ? Icons.add_box_rounded
                        : Icons.send_rounded,
                    color: _dbSaved
                        ? Colors.white38
                        : Colors.white,
                    size: 20,
                  ),
                  tooltip: widget.isBeli
                      ? (_dbSaved ? 'Sudah dicatat' : 'Catat ke Stok Gudang')
                      : (_dbSaved ? 'Sudah dikirim' : 'Kirim ke Laporan'),
                  onPressed: _dbSaved ? null : _sendToDb,
                ),
                // ── Edit nota ────────────────────────
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 20),
                  tooltip: 'Edit Nota',
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoicePage(
                        initName:      widget.customerName,
                        initPhone:     widget.customerPhone,
                        initPayMethod: widget.paymentMethod,
                        initNotes:     widget.notes,
                        initDiscount:  widget.discount,
                        initIsPaid:    widget.isPaid,
                        initCart:      widget.items,
                      ),
                    ),
                  ),
                ),
                if (_connectedBt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.bluetooth_connected_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(_connectedBt!, style: const TextStyle(
                          color: Colors.white, fontSize: 10)),
                    ]),
                  ),
              ]),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(icon: Icon(Icons.print_rounded, size: 18),
                    text: 'Thermal'),
                Tab(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  text: widget.isBeli ? 'Nota PDF' : 'Invoice PDF',
                ),
              ],
            ),
          ])),
        ),
      ),

      body: TabBarView(
        controller: _tab,
        children: [
          // ─── TAB 1: THERMAL ──────────────────
          Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.straighten_rounded,
                    color: _kPrimary, size: 18),
                const SizedBox(width: 8),
                const Text('Ukuran Kertas',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: _kTextDark, fontSize: 14)),
                const Spacer(),
                _PaperBtn(
                    label: '58 mm',
                    selected: _paperWidth == 58,
                    onTap: () =>
                        setState(() => _paperWidth = 58)),
                const SizedBox(width: 8),
                _PaperBtn(
                    label: '80 mm',
                    selected: _paperWidth == 80,
                    onTap: () =>
                        setState(() => _paperWidth = 80)),
              ]),
            ),
            Expanded(child: Container(
              color: const Color(0xFFDDDDDD),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _buildThermalPreview(),
              ),
            )),
            _ActionBar(children: [
              Expanded(flex: 3, child: _ActionBtn(
                icon: _btPrinting ? null : Icons.bluetooth_rounded,
                label: _btPrinting ? 'Mencetak...' : 'Cetak\nBluetooth',
                color: _kPrimary,
                loading: _btPrinting,
                onTap: _btPrinting ? null : _showBtSheet,
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _ActionBtn(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF\nThermal',
                color: const Color(0xFF00838F),
                onTap: _shareThermalPdf,
              )),
            ]),
          ]),

          // ─── TAB 2: PDF PROFESIONAL ──────────
          Column(children: [
            Expanded(child: Container(
              color: const Color(0xFFCCCCCC),
              child: PdfPreview(
                build: (_) => _buildProfessionalPdf(),
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                initialPageFormat: PdfPageFormat.a4,
              ),
            )),
            _ActionBar(children: [
              Expanded(child: _ActionBtn(
                icon: Icons.share_rounded,
                label: 'Share\nPDF',
                color: const Color(0xFFE65100),
                onTap: _shareProfessionalPdf,
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(
                icon: Icons.visibility_rounded,
                label: 'Preview\nFullscreen',
                color: _kPrimary,
                onTap: _previewProfessionalPdf,
              )),
            ]),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
//  BLUETOOTH BOTTOM SHEET
// ════════════════════════════════════════════
class _ThermalLine {
  final String text;
  final bool   bold;
  final bool   isCenter;
  final bool   isRight;
  final bool   small;
  final int    size;
  const _ThermalLine(this.text, {
    this.bold     = false,
    this.isCenter = false,
    this.isRight  = false,
    this.small    = false,
    this.size     = 1,
  });
}

class _BtSheet extends StatefulWidget {
  final Future<void> Function(String mac, String name) onPrint;
  const _BtSheet({required this.onPrint});

  @override
  State<_BtSheet> createState() => _BtSheetState();
}

class _BtSheetState extends State<_BtSheet> {
  bool    _loading  = true;
  bool    _printing = false;
  String? _selected;
  String? _errorMsg;
  List<BluetoothInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    setState(() { _loading = true; _devices = []; _errorMsg = null; });

    try {
      bool granted = false;

      if (Platform.isAndroid) {
        final statuses = await [
          Permission.bluetooth,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.location,
        ].request();

        final btConnect = statuses[Permission.bluetoothConnect];
        final btScan    = statuses[Permission.bluetoothScan];
        final bt        = statuses[Permission.bluetooth];

        granted = (btConnect?.isGranted ?? false) ||
            (btScan?.isGranted    ?? false) ||
            (bt?.isGranted        ?? false);
      } else {
        granted = true;
      }

      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading  = false;
          _errorMsg = 'Izin Bluetooth ditolak.\n'
              'Buka Pengaturan → Izin Aplikasi → aktifkan Bluetooth.';
        });
        return;
      }

      final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btEnabled) {
        if (!mounted) return;
        setState(() {
          _loading  = false;
          _errorMsg = 'Bluetooth tidak aktif.\n'
              'Aktifkan Bluetooth di HP terlebih dahulu.';
        });
        return;
      }

      final paired = await PrintBluetoothThermal.pairedBluetooths;
      if (!mounted) return;
      setState(() { _devices = paired; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      // Maksimal 75% layar supaya tidak overflow di HP manapun
      constraints: BoxConstraints(maxHeight: screenH * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24)),
      ),
      // Column: header (fixed) + list (scrollable flex) + button (fixed)
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          )),

          // ── Header: title + refresh ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bluetooth_rounded,
                    color: _kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pilih Printer Bluetooth',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text('Pastikan printer sudah di-pair di Pengaturan HP',
                        style: TextStyle(fontSize: 11,
                            color: Color(0xFF90A4AE))),
                  ])),
              IconButton(
                onPressed: _loading ? null : _requestPermissionsAndScan,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPrimary))
                    : const Icon(Icons.refresh_rounded, color: _kPrimary),
              ),
            ]),
          ),

          const Divider(height: 1),

          // ── Daftar device — SCROLLABLE ────────────
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(20), child: Center(
                      child: Column(children: [
                        CircularProgressIndicator(color: _kPrimary),
                        SizedBox(height: 10),
                        Text('Meminta izin & mencari printer...',
                            style: TextStyle(color: Color(0xFF90A4AE))),
                      ]),
                    ))
                  else if (_errorMsg != null)
                    Padding(padding: const EdgeInsets.all(8), child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFC62828).withOpacity(0.3)),
                      ),
                      child: Column(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFC62828), size: 32),
                        const SizedBox(height: 8),
                        Text(_errorMsg!, textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFC62828), fontSize: 12,
                                height: 1.5)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _requestPermissionsAndScan,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Coba Lagi'),
                        ),
                      ]),
                    ))
                  else if (_devices.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Column(children: [
                            Icon(Icons.bluetooth_disabled_rounded,
                                color: Color(0xFF90A4AE), size: 36),
                            SizedBox(height: 8),
                            Text('Tidak ada printer ditemukan',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                                'Pair printer terlebih dahulu di\n'
                                    'Pengaturan → Bluetooth HP Anda',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFF90A4AE), fontSize: 12)),
                          ])))
                    else
                      ..._devices.map((d) {
                        final isSelected = _selected == d.macAdress;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selected = d.macAdress),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _kPrimary.withOpacity(0.08)
                                  : const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _kPrimary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(children: [
                              Icon(Icons.print_rounded,
                                  color: isSelected
                                      ? _kPrimary : const Color(0xFF90A4AE),
                                  size: 22),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name, style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? _kPrimary : _kTextDark)),
                                    Text(d.macAdress,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF90A4AE))),
                                  ])),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: _kPrimary, size: 20),
                            ]),
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),

          // ── Tombol Cetak — SELALU TERLIHAT ────────
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 10, 20,
                MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(
                  color: Colors.grey.shade100)),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, -3),
              )],
            ),
            child: GestureDetector(
              onTap: (_selected == null || _printing) ? null : () async {
                setState(() => _printing = true);
                final dev = _devices.firstWhere(
                        (d) => d.macAdress == _selected);
                Navigator.pop(context);
                await widget.onPrint(dev.macAdress, dev.name);
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: (_selected == null || _printing)
                      ? const LinearGradient(
                      colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)])
                      : const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_selected == null || _printing) ? [] : [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Center(child: _printing
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : Row(
                    mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.print_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _selected == null
                        ? 'Pilih printer dulu'
                        : 'Cetak Sekarang',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────

class _ActionBar extends StatelessWidget {
  final List<Widget> children;
  const _ActionBar({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -3))]),
    child: Row(children: children),
  );
}

class _PaperBtn extends StatelessWidget {
  final String        label;
  final bool          selected;
  final VoidCallback  onTap;
  const _PaperBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _kPrimary : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected ? _kPrimary : _kPrimary.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(
          color: selected ? Colors.white : _kPrimary,
          fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData?    icon;
  final String       label;
  final Color        color;
  final VoidCallback? onTap;
  final bool         loading;
  const _ActionBtn({
    this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Center(child: loading
          ? const SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5))
          : Column(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, color: Colors.white, size: 22),
        if (icon != null) const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w700, height: 1.3)),
      ])),
    ),
  );
}