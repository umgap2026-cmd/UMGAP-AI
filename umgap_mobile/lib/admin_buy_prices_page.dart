import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'cache_service.dart';
import 'api_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kPrimaryMid = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kAccent = Color(0xFF00B0FF);
const _kSurface = Color(0xFFF4F7FF);
const _kTextDark = Color(0xFF0D1B3E);
const _kTextMid = Color(0xFF4A5568);
const _kTextLight = Color(0xFF90A4AE);

class AdminBuyPricesPage extends StatefulWidget {
  const AdminBuyPricesPage({super.key});

  @override
  State<AdminBuyPricesPage> createState() => _AdminBuyPricesPageState();
}

class _AdminBuyPricesPageState extends State<AdminBuyPricesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addCustomMaterialController =
  TextEditingController();
  final TextEditingController _addGradeController = TextEditingController();
  final TextEditingController _addPriceController =
  TextEditingController(text: '0');
  final TextEditingController _addUnitController =
  TextEditingController(text: 'kg');
  final TextEditingController _addNoteController = TextEditingController();

  bool _loading = true;
  bool _addIsActive = true;
  bool _saving = false;
  String _selectedMaterial = 'all';
  String _search = '';
  String _statusText = 'Klik item untuk edit harga';
  String _statusType = 'idle';
  String _landingApi = '/api/buy-prices';
  String _addMaterial = 'Tembaga';

  List<Map<String, dynamic>> _rows = [];

  static const List<String> _baseMaterials = [
    'Tembaga',
    'Kuningan',
    'Aluminium',
    'Stainless',
    'Timah & Aki',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _addCustomMaterialController.dispose();
    _addGradeController.dispose();
    _addPriceController.dispose();
    _addUnitController.dispose();
    _addNoteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await CacheService.get(CacheService.kBuyPrices);
    if (cached != null && mounted) {
      final rows = (cached['rows'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _rows = rows;
        _landingApi = (cached['landing_page_api'] ?? '/api/buy-prices').toString();
        _loading = false;
        _setStatus('ok', 'Data harga beli terhubung ke landing page.');
      });
    }
    try {
      final data = await ApiService.getBuyPriceGroups();
      final rows = (data['rows'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      await CacheService.set(CacheService.kBuyPrices, data);
      setState(() {
        _rows = rows;
        _landingApi = (data['landing_page_api'] ?? '/api/buy-prices').toString();
        _loading = false;
        _setStatus('ok', 'Data harga beli terhubung ke landing page.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_rows.isEmpty) _showSnack('Gagal memuat harga beli: $e', isError: true);
      if (_rows.isEmpty) _setStatus('err', 'Gagal memuat data');
    }
  }

  void _setStatus(String type, String text) {
    if (!mounted) return;
    setState(() {
      _statusType = type;
      _statusText = text;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFC62828) : _kPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<String> get _materialTabs {
    final set = <String>{'all', ..._baseMaterials};
    for (final row in _rows) {
      final mat = (row['material'] ?? '').toString().trim();
      if (mat.isNotEmpty) set.add(mat);
    }
    return set.toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedRows {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in _rows) {
      final material = (row['material'] ?? '').toString();
      final grade = (row['grade'] ?? '').toString().toLowerCase();
      final materialLower = material.toLowerCase();
      final matchMaterial =
          _selectedMaterial == 'all' || material == _selectedMaterial;
      final matchSearch = _search.isEmpty ||
          grade.contains(_search) ||
          materialLower.contains(_search);
      if (!matchMaterial || !matchSearch) continue;
      map.putIfAbsent(material, () => []).add(row);
    }
    return map;
  }

  int get _activeCount => _rows.where((e) => e['is_active'] == true).length;

  Future<void> _saveAdd() async {
    final material = _addMaterial == 'Lainnya'
        ? _addCustomMaterialController.text.trim()
        : _addMaterial;
    final grade = _addGradeController.text.trim();
    final unit = _addUnitController.text.trim().isEmpty
        ? 'kg'
        : _addUnitController.text.trim();
    final note = _addNoteController.text.trim();
    final price = double.tryParse(_addPriceController.text.trim()) ?? 0;

    if (material.isEmpty) {
      _showSnack('Kategori material wajib diisi', isError: true);
      return;
    }
    if (grade.isEmpty) {
      _showSnack('Nama barang / grade wajib diisi', isError: true);
      return;
    }

    setState(() => _saving = true);
    _setStatus('ld', 'Menambahkan harga beli...');
    try {
      final data = await ApiService.addBuyPrice(
        material: material,
        grade: grade,
        unit: unit,
        price: price,
        note: note,
        isActive: _addIsActive,
      );
      final row = Map<String, dynamic>.from(data['row'] as Map);
      if (!mounted) return;
      setState(() {
        _rows.add(row);
        _selectedMaterial = row['material'].toString();
        _addCustomMaterialController.clear();
        _addGradeController.clear();
        _addPriceController.text = '0';
        _addUnitController.text = 'kg';
        _addNoteController.clear();
        _addIsActive = true;
      });
      _setStatus('ok', 'Harga beli baru berhasil ditambahkan.');
      _showSnack('Data berhasil ditambahkan');
    } catch (e) {
      _setStatus('err', 'Gagal menambah data');
      _showSnack('Gagal menambah harga beli: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final gradeController =
    TextEditingController(text: (row['grade'] ?? '').toString());
    final priceController =
    TextEditingController(text: '${row['price'] ?? 0}');
    final noteController =
    TextEditingController(text: (row['note'] ?? '').toString());
    bool isActive = row['is_active'] == true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _kTextLight.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const Text(
                      'Edit Barang',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row['material']} • / ${row['unit'] ?? 'kg'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Detail Barang'),
                    const SizedBox(height: 10),
                    _StyledTextField(
                      controller: gradeController,
                      hint: 'Nama barang / grade',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 12),
                    _StyledTextField(
                      controller: priceController,
                      hint: 'Harga beli',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _StyledTextField(
                      controller: noteController,
                      hint: 'Catatan opsional',
                      icon: Icons.note_alt_outlined,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border:
                        Border.all(color: _kPrimary.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_rounded,
                              color: _kPrimary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tampilkan di landing page',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _kTextDark,
                              ),
                            ),
                          ),
                          Switch(
                            value: isActive,
                            onChanged: (v) =>
                                setModalState(() => isActive = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineButton(
                            label: 'Hapus',
                            icon: Icons.delete_outline_rounded,
                            onPressed: () async {
                              Navigator.pop(context);
                              await _deleteRow(row);
                            },
                            danger: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OutlineButton(
                            label: 'Share WA',
                            icon: Icons.share_rounded,
                            onPressed: () async {
                              final draftRow = {
                                ...row,
                                'price': double.tryParse(
                                    priceController.text.trim()) ??
                                    0,
                                'note': noteController.text.trim(),
                                'is_active': isActive,
                              };
                              await _shareWhatsAppSingle(draftRow);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GradientButton(
                      label: 'Simpan Perubahan',
                      onPressed: () async {
                        Navigator.pop(context);
                        await _updateRow(
                          row,
                          grade: gradeController.text.trim(),
                          price: double.tryParse(
                              priceController.text.trim()) ??
                              0,
                          note: noteController.text.trim(),
                          isActive: isActive,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateRow(
      Map<String, dynamic> row, {
        required String grade,
        required double price,
        required String note,
        required bool isActive,
      }) async {
    _setStatus('ld', 'Menyimpan perubahan...');
    try {
      final cleanGrade = grade.trim();
      if (cleanGrade.isEmpty) {
        _showSnack('Nama barang / grade wajib diisi', isError: true);
        _setStatus('err', 'Nama barang wajib diisi');
        return;
      }

      final data = await ApiService.updateBuyPrice(
        id: int.parse('${row['id']}'),
        material: row['material']?.toString(),
        grade: cleanGrade,
        unit: row['unit']?.toString(),
        price: price,
        note: note,
        isActive: isActive,
      );
      final updated = Map<String, dynamic>.from(data['row'] as Map);
      final index = _rows.indexWhere((e) => e['id'] == row['id']);
      if (index >= 0) {
        setState(() => _rows[index] = updated);
      }
      _setStatus(
          'ok', 'Harga berhasil diperbarui dan otomatis live ke landing page.');
      _showSnack('Perubahan berhasil disimpan');
      await _sharePrompt(updated);
    } catch (e) {
      _setStatus('err', 'Gagal menyimpan perubahan');
      _showSnack('Gagal memperbarui harga beli: $e', isError: true);
    }
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    _setStatus('ld', 'Menghapus data...');
    try {
      await ApiService.deleteBuyPrice(int.parse('${row['id']}'));
      if (!mounted) return;
      setState(() => _rows.removeWhere((e) => e['id'] == row['id']));
      _setStatus('ok', 'Data berhasil dihapus.');
      _showSnack('Data berhasil dihapus');
    } catch (e) {
      _setStatus('err', 'Gagal menghapus data');
      _showSnack('Gagal menghapus harga beli: $e', isError: true);
    }
  }

  Future<void> _sharePrompt(Map<String, dynamic> row) async {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Bagikan ke WhatsApp'),
        content: const Text(
          'Harga sudah tersimpan. Bagikan update harga ini ke WhatsApp sekarang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
            const Text('Bagikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (share == true) {
      await _shareWhatsAppSingle(row);
    }
  }

  Future<void> _shareWhatsAppSingle(Map<String, dynamic> row) async {
    final text = _buildWhatsAppTextSingle(row);
    await _launchWhatsAppText(text);
  }

  Future<void> _shareWhatsAppAll() async {
    final activeRows =
    _rows.where((e) => (e['is_active'] ?? true) == true).toList();

    if (activeRows.isEmpty) {
      _showSnack('Tidak ada barang aktif untuk dibagikan', isError: true);
      return;
    }

    final text = _buildWhatsAppTextAll(activeRows);
    await _launchWhatsAppText(text);
  }

  Future<void> _launchWhatsAppText(String text) async {
    final encoded = Uri.encodeComponent(text);
    final waScheme = Uri.parse('whatsapp://send?text=$encoded');
    final waWeb    = Uri.parse('https://wa.me/?text=$encoded');

    // 1️⃣ Coba WhatsApp native (intent langsung)
    if (await canLaunchUrl(waScheme)) {
      await launchUrl(waScheme, mode: LaunchMode.externalApplication);
      return;
    }

    // 2️⃣ Coba via wa.me (browser → buka WA)
    if (await canLaunchUrl(waWeb)) {
      await launchUrl(waWeb, mode: LaunchMode.externalApplication);
      return;
    }

    // 3️⃣ Fallback: share sheet sistem — works di semua HP
    //    User bisa pilih WA, Telegram, SMS, email, dll.
    await Share.share(
      text,
      subject: 'Harga Beli Scrap UMGAP',
    );
  }

  String _waHeaderDate() {
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  String _buildWhatsAppTextSingle(Map<String, dynamic> row) {
    final price = _formatPrice((row['price'] as num?)?.toDouble() ?? 0);
    final unit = ((row['unit'] ?? 'kg').toString()).trim().isEmpty
        ? 'kg'
        : (row['unit'] ?? 'kg').toString();
    final note = (row['note'] ?? '').toString().trim();

    return '''*Update Harga Beli ${_waHeaderDate()} ARV LOGAM*

*${row['material']}*
• ${row['grade']} — $price/$unit${note.isEmpty ? '' : ' ($note)'}

Tidak menerima barang yang bertentangan dengan HUKUM! arvlogam.my.id''';
  }

  String _buildWhatsAppTextAll(List<Map<String, dynamic>> rows) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final material = (row['material'] ?? 'Lainnya').toString();
      grouped.putIfAbsent(material, () => []);
      grouped[material]!.add(row);
    }

    final buffer = StringBuffer();
    buffer.writeln('*Update Harga Beli ${_waHeaderDate()} ARV LOGAM*');
    buffer.writeln('');

    for (final material in grouped.keys) {
      buffer.writeln('*$material*');
      for (final item in grouped[material]!) {
        final grade = (item['grade'] ?? '-').toString();
        final unit = ((item['unit'] ?? 'kg').toString()).trim().isEmpty
            ? 'kg'
            : (item['unit'] ?? 'kg').toString();
        final note = (item['note'] ?? '').toString().trim();
        final price = (item['price'] as num?)?.toDouble() ?? 0;

        buffer.write('• $grade — ${_formatPrice(price)}/$unit');
        if (note.isNotEmpty) {
          buffer.write(' ($note)');
        }
        buffer.writeln();
      }
      buffer.writeln();
    }

    buffer.writeln('*(TIDAK MENERIMA BARANG YANG BERTENTANGAN DENGAN HUKUM!)* arvlogam.my.id');

    return buffer.toString().trim();
  }

  String _formatPrice(double value) {
    if (value <= 0) return 'Hubungi kami';
    final fixed = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => '.',
    );
    return parts.length > 1 && parts[1] != '0'
        ? 'Rp $whole,${parts[1]}'
        : 'Rp $whole';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [_buildListTab(), _buildAddTab()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(220),
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Harga Beli Scrap',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Share semua',
                      onPressed: _shareWhatsAppAll,
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _TopStat(label: 'Total Barang', value: '${_rows.length}'),
                          _TopDivider(),
                          _TopStat(label: 'Aktif', value: '$_activeCount'),
                          _TopDivider(),
                          const Expanded(
                            child: _TopInfoLabel(label: 'Live ke landing page'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kPrimaryDark, _kPrimaryMid],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          overlayColor: MaterialStateProperty.all(Colors.transparent),
                          splashBorderRadius: BorderRadius.circular(14),
                          labelColor: Colors.white,
                          unselectedLabelColor: _kPrimaryDark,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(height: 52, text: 'Daftar Harga'),
                            Tab(height: 52, text: 'Tambah Baru'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTab() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimary),
      );
    }

    final groups = _groupedRows;
    final tabs = _materialTabs;

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBar(type: _statusType, text: _statusText),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:
              const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E6CC2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.price_change_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harga aktif otomatis tampil di Website',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Harga LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const _SectionHeader(title: 'Cari & Filter'),
          const SizedBox(height: 10),
          _StyledTextField(
            controller: _searchController,
            hint: 'Cari nama barang atau material...',
            icon: Icons.search_rounded,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final item = tabs[index];
                      final selected = item == _selectedMaterial;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedMaterial = item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? _materialColor(item) : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _materialColor(item).withOpacity(selected ? 1 : 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _materialColor(item).withOpacity(selected ? 0.25 : 0.08),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              item == 'all' ? 'Semua' : item,
                              style: TextStyle(
                                color: selected ? Colors.white : _materialColor(item),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const _EmptyState(message: 'Tidak ada barang ditemukan')
          else
            ...groups.entries.map(
                  (entry) => _MaterialGroup(
                material: entry.key,
                rows: entry.value,
                color: _materialColor(entry.key),
                formatPrice: _formatPrice,
                onTap: _openEdit,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBar(type: _statusType, text: _statusText),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Tambah Barang Baru'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _addMaterial,
                items: const [
                  DropdownMenuItem(
                      value: 'Tembaga', child: Text('Tembaga')),
                  DropdownMenuItem(
                      value: 'Kuningan', child: Text('Kuningan')),
                  DropdownMenuItem(
                      value: 'Aluminium', child: Text('Aluminium')),
                  DropdownMenuItem(
                      value: 'Stainless', child: Text('Stainless')),
                  DropdownMenuItem(
                      value: 'Timah & Aki', child: Text('Timah & Aki')),
                  DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya...')),
                ],
                decoration:
                _inputDecoration('Kategori material', Icons.category_rounded),
                onChanged: (value) =>
                    setState(() => _addMaterial = value ?? 'Tembaga'),
              ),
              if (_addMaterial == 'Lainnya') ...[
                const SizedBox(height: 12),
                _StyledTextField(
                  controller: _addCustomMaterialController,
                  hint: 'Nama kategori baru',
                  icon: Icons.create_new_folder_outlined,
                ),
              ],
              const SizedBox(height: 12),
              _StyledTextField(
                controller: _addGradeController,
                hint: 'Nama barang / grade',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StyledTextField(
                      controller: _addPriceController,
                      hint: 'Harga beli',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StyledTextField(
                      controller: _addUnitController,
                      hint: 'Satuan',
                      icon: Icons.straighten_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StyledTextField(
                controller: _addNoteController,
                hint: 'Catatan opsional',
                icon: Icons.note_alt_outlined,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kPrimary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded,
                        color: _kPrimary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tampilkan barang baru di landing page',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                    ),
                    Switch(
                      value: _addIsActive,
                      onChanged: (value) =>
                          setState(() => _addIsActive = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _GradientButton(
                label: _saving ? 'Menyimpan...' : 'Tambah Barang',
                onPressed: _saving ? null : _saveAdd,
                loading: _saving,
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
      prefixIcon: Icon(icon, color: _kPrimary, size: 18),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _kPrimaryMid, width: 1.5),
      ),
    );
  }

  Color _materialColor(String material) {
    switch (material) {
      case 'Tembaga':
        return const Color(0xFFB87333);
      case 'Kuningan':
        return const Color(0xFFB8860B);
      case 'Aluminium':
        return const Color(0xFF6B7280);
      case 'Stainless':
        return const Color(0xFF607D8B);
      case 'Timah & Aki':
        return const Color(0xFF6366F1);
      default:
        return _kPrimary;
    }
  }
}

class _TopStat extends StatelessWidget {
  final String label;
  final String value;
  const _TopStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _TopInfoLabel extends StatelessWidget {
  final String label;
  const _TopInfoLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TopDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: Colors.white24);
}

class _StatusBar extends StatelessWidget {
  final String type;
  final String text;
  const _StatusBar({required this.type, required this.text});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    switch (type) {
      case 'ok':
        color = const Color(0xFF2E7D32);
        bg = color.withOpacity(0.10);
        break;
      case 'err':
        color = const Color(0xFFC62828);
        bg = color.withOpacity(0.10);
        break;
      case 'ld':
        color = _kPrimaryDark;
        bg = color.withOpacity(0.10);
        break;
      default:
        color = _kTextMid;
        bg = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
            BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialGroup extends StatelessWidget {
  final String material;
  final List<Map<String, dynamic>> rows;
  final Color color;
  final String Function(double) formatPrice;
  final Future<void> Function(Map<String, dynamic>) onTap;

  const _MaterialGroup({
    required this.material,
    required this.rows,
    required this.color,
    required this.formatPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    material,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kTextDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rows.length} barang',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((row) {
            final price = (row['price'] as num?)?.toDouble() ?? 0;
            final note = (row['note'] ?? '').toString();
            final active = row['is_active'] == true;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onTap(row),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active ? color.withOpacity(0.10) : const Color(0xFFFFE1E1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (row['grade'] ?? '-').toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: active ? _kTextDark : _kTextMid,
                                  decoration: active ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _kTextMid,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatPrice(price),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: price > 0 ? _kPrimary : _kTextMid,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: active ? color.withOpacity(0.10) : const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${row['unit'] ?? 'kg'} • ${active ? 'Live' : 'Hidden'}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: active ? color : const Color(0xFFC62828),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.edit_rounded, size: 14, color: _kTextLight),
                        SizedBox(width: 6),
                        Text(
                          'Tap untuk edit',
                          style: TextStyle(
                            fontSize: 11,
                            color: _kTextLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: _kPrimary.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: _kTextMid)),
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
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _kPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kPrimaryDark,
          ),
        ),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
        prefixIcon: Icon(icon, color: _kPrimary, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _kPrimaryMid, width: 1.5),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  const _OutlineButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC62828) : _kPrimary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.28), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _GradientButton({
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(
            colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)],
          )
              : const LinearGradient(
            colors: [_kPrimaryDark, _kPrimaryMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? []
              : [
            BoxShadow(
              color: _kPrimary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          )
              : Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}