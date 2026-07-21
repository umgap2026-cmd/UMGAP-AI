import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

// ════════════════════════════════════════════
//  BIOFINGER MAPPING PAGE
//  Admin bisa mapping PIN mesin fingerprint
//  ke karyawan UMGAP
// ════════════════════════════════════════════
class BiofingerMappingPage extends StatefulWidget {
  const BiofingerMappingPage({super.key});

  @override
  State<BiofingerMappingPage> createState() => _BiofingerMappingPageState();
}

class _BiofingerMappingPageState extends State<BiofingerMappingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;

  List<dynamic> _mappings     = [];
  List<dynamic> _unmappedPins = [];
  List<dynamic> _unmappedUsers = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getBiofingerMappings();
      if (!mounted) return;
      setState(() {
        _mappings      = List<dynamic>.from(data['mappings']      ?? []);
        _unmappedUsers = List<dynamic>.from(data['unmapped_users'] ?? []);
        _loading       = false;
      });
      // Ambil juga PIN yang belum di-mapping
      try {
        final un = await ApiService.getBiofingerUnmapped();
        if (mounted) setState(() => _unmappedPins = List<dynamic>.from(un['unmapped'] ?? []));
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  // ── Tambah mapping manual ──────────────────
  Future<void> _addMapping({String? prefillPin, String? prefillNama}) async {
    final pinCtrl  = TextEditingController(text: prefillPin ?? '');
    final snCtrl   = TextEditingController();
    int?  selectedUserId;
    String selectedUserName = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                margin: const EdgeInsets.only(bottom: 16, top: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              )),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: UColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.fingerprint_rounded, color: UColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tambah Mapping PIN', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: UColors.textDark)),
                  Text(prefillNama != null ? 'Nama di mesin: $prefillNama' : 'Hubungkan PIN mesin ke karyawan',
                      style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                ]),
              ]),
              const SizedBox(height: 20),

              UField(controller: pinCtrl, label: 'PIN / User ID di Mesin *', hint: 'Contoh: 9337',
                  prefixIcon: Icons.tag_rounded, keyboard: TextInputType.number),
              const SizedBox(height: 14),

              // Pilih karyawan
              const Text('Karyawan UMGAP *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UColors.textMid)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: UColors.inputBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UColors.primary.withOpacity(0.15)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedUserId,
                    isExpanded: true,
                    hint: const Text('Pilih karyawan...', style: TextStyle(color: UColors.textLight, fontSize: 13)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: UColors.primary),
                    items: [
                      ..._unmappedUsers.map((u) => DropdownMenuItem<int>(
                        value: u['id'] as int,
                        child: Text('${u['name']}  •  ${u['email']}',
                            style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                      )),
                      // Juga tampilkan semua karyawan (yang sudah mapped juga, untuk re-assign)
                      ..._mappings
                          .where((m) => !_unmappedUsers.any((u) => u['id'] == m['user_id']))
                          .map((m) => DropdownMenuItem<int>(
                        value: m['user_id'] as int,
                        child: Text('${m['user_name']} (sudah mapped)',
                            style: const TextStyle(fontSize: 13, color: UColors.textMid)),
                      )),
                    ],
                    onChanged: (v) {
                      setSheet(() { selectedUserId = v; });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () async {
                  final pin = pinCtrl.text.trim();
                  if (pin.isEmpty || selectedUserId == null) {
                    uSnack(context, 'PIN dan karyawan wajib dipilih', isError: true);
                    return;
                  }
                  try {
                    await ApiService.addBiofingerMapping(
                      pinMesin:  pin,
                      userId:    selectedUserId!,
                      namaMesin: prefillNama ?? '',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      uSnack(context, 'Mapping berhasil disimpan ✓');
                      _load();
                    }
                  } catch (e) {
                    if (mounted) uSnack(context, e.toString(), isError: true);
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [UColors.primaryDark, UColors.primaryMid],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Simpan Mapping', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ])),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    pinCtrl.dispose();
    snCtrl.dispose();
  }

  // ── Hapus mapping ──────────────────────────
  Future<void> _deleteMapping(int id, String userName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Mapping?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Mapping PIN untuk $userName akan dinonaktifkan.\nKaryawan tidak akan terabsen otomatis dari mesin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteBiofingerMapping(id);
      if (mounted) { uSnack(context, 'Mapping dihapus'); _load(); }
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [UColors.primaryDark, UColors.primary, UColors.primaryMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context)),
                const Expanded(child: Text('Fingerprint Mapping',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
                // Badge unmapped
                if (_unmappedPins.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: UColors.danger.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_unmappedPins.length} belum mapped',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(icon: const Icon(Icons.link_rounded, size: 16), text: 'Mapping (${_mappings.length})'),
                Tab(icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    text: 'Belum Mapped (${_unmappedPins.length})'),
              ],
            ),
          ])),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMapping,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : TabBarView(controller: _tab, children: [
        // ─── Tab 1: Mapping aktif ──────
        RefreshIndicator(
          color: UColors.primary,
          onRefresh: _load,
          child: _mappings.isEmpty
              ? ListView(children: const [
            SizedBox(height: 80),
            UEmptyState(icon: Icons.fingerprint_rounded,
                title: 'Belum ada mapping',
                subtitle: 'Tap tombol Tambah untuk menghubungkan\nPIN mesin ke karyawan'),
          ])
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _mappings.length,
            itemBuilder: (_, i) {
              final m = Map<String, dynamic>.from(_mappings[i]);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.07),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  // Avatar
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: UColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Center(child: Text(
                        '${m['user_name']}'.isNotEmpty ? '${m['user_name']}'[0].toUpperCase() : '?',
                        style: const TextStyle(color: UColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
                      ))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['user_name']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UColors.textDark)),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: UColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('PIN: ${m['pin_mesin']}',
                            style: const TextStyle(fontSize: 11, color: UColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      if ((m['nama_mesin'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('(${m['nama_mesin']})', style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                      ],
                    ]),
                    Text('${m['email']}', style: const TextStyle(fontSize: 11, color: UColors.textLight)),
                  ])),
                  // Ikon fingerprint aktif
                  const Icon(Icons.fingerprint_rounded, color: UColors.success, size: 20),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _deleteMapping(m['id'] as int, '${m['user_name']}'),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: UColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.link_off_rounded, color: UColors.danger, size: 16),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),

        // ─── Tab 2: PIN belum mapped ───
        RefreshIndicator(
          color: UColors.primary,
          onRefresh: _load,
          child: _unmappedPins.isEmpty
              ? ListView(children: const [
            SizedBox(height: 80),
            UEmptyState(icon: Icons.check_circle_rounded,
                title: 'Semua PIN sudah di-mapping',
                subtitle: 'Tidak ada PIN mesin yang belum terhubung'),
          ])
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _unmappedPins.length,
            itemBuilder: (_, i) {
              final p = Map<String, dynamic>.from(_unmappedPins[i]);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: UColors.warning.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: UColors.warning.withOpacity(0.08),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: UColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.fingerprint_rounded, color: UColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['disp_nm']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UColors.textDark)),
                    Text('PIN: ${p['pin_mesin']}  •  ${p['scan_count']}x scan',
                        style: const TextStyle(fontSize: 11, color: UColors.textMid)),
                    Text('Terakhir: ${p['last_scan'] ?? '-'}',
                        style: const TextStyle(fontSize: 10, color: UColors.textLight)),
                  ])),
                  GestureDetector(
                    onTap: () => _addMapping(
                      prefillPin: '${p['pin_mesin']}',
                      prefillNama: '${p['disp_nm']}',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: UColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Text('Mapping', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}