import 'package:flutter/material.dart';
import 'api_service.dart';
import 'admin_attendance_history_page.dart';

const _kPrimary     = Color(0xFF1565C0);
const _kPrimaryMid  = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kAccent      = Color(0xFF00B0FF);
const _kSurface     = Color(0xFFF4F7FF);
const _kInputBg     = Color(0xFFF0F4FF);
const _kTextDark    = Color(0xFF0D1B3E);
const _kTextMid     = Color(0xFF4A5568);
const _kTextLight   = Color(0xFF90A4AE);

class AdminSubmitAttendancePage extends StatefulWidget {
  const AdminSubmitAttendancePage({super.key});

  @override
  State<AdminSubmitAttendancePage> createState() => _AdminSubmitAttendancePageState();
}

class _AdminSubmitAttendancePageState extends State<AdminSubmitAttendancePage> {
  bool loadingEmployees = true;
  bool submitting       = false;

  List<dynamic> employees      = [];
  Map<String, dynamic>? selectedEmployee;
  String selectedType          = "ONTIME";
  final noteController         = TextEditingController();
  TimeOfDay? manualTime;
  TimeOfDay? manualCheckoutTime;

  final List<Map<String, dynamic>> _types = [
    {"value": "ONTIME",  "label": "Tepat Waktu",  "icon": Icons.check_circle_rounded,    "color": Color(0xFF2E7D32)},
    {"value": "LATE",    "label": "Terlambat",    "icon": Icons.schedule_rounded,         "color": Color(0xFFE65100)},
    {"value": "SICK",    "label": "Sakit",        "icon": Icons.medical_services_rounded, "color": Color(0xFFAD1457)},
    {"value": "LEAVE",   "label": "Izin",         "icon": Icons.beach_access_rounded,     "color": Color(0xFF0277BD)},
    {"value": "ABSENT",  "label": "Tidak Masuk",  "icon": Icons.cancel_rounded,           "color": Color(0xFFC62828)},
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final result = await ApiService.getUsers();
      if (!mounted) return;
      final emp = result.where((e) {
        final m = Map<String, dynamic>.from(e);
        return (m['role'] ?? '') == 'employee';
      }).toList();
      setState(() {
        employees        = emp;
        selectedEmployee = emp.isNotEmpty ? Map<String, dynamic>.from(emp.first) : null;
        loadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingEmployees = false);
      _showSnack("Gagal load karyawan: $e", isError: true);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: manualTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => manualTime = picked);
  }

  Future<void> _pickCheckoutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: manualCheckoutTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => manualCheckoutTime = picked);
  }

  Future<void> _submit() async {
    if (selectedEmployee == null) {
      _showSnack("Pilih karyawan terlebih dahulu", isError: true);
      return;
    }

    setState(() => submitting = true);

    try {
      String? manualCheckin;
      if (manualTime != null) {
        final h = manualTime!.hour.toString().padLeft(2, '0');
        final m = manualTime!.minute.toString().padLeft(2, '0');
        manualCheckin = "$h:$m";
      }

      String? manualCheckout;
      if (manualCheckoutTime != null) {
        final h = manualCheckoutTime!.hour.toString().padLeft(2, '0');
        final m = manualCheckoutTime!.minute.toString().padLeft(2, '0');
        manualCheckout = "$h:$m";
      }

      await ApiService.adminSubmitAttendanceForEmployee(
        userId:         selectedEmployee!['id'] as int,
        arrivalType:    selectedType,
        note:           noteController.text.trim(),
        manualCheckin:  manualCheckin,
        manualCheckout: manualCheckout,
      );

      if (!mounted) return;

      // Tampilkan konfirmasi sukses dengan dialog, lalu langsung buka history
      // supaya admin bisa verifikasi data tersimpan
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
              ),
              const SizedBox(height: 14),
              Text(
                "Absensi ${selectedEmployee!['name']} berhasil dicatat!",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark),
              ),
              const SizedBox(height: 6),
              const Text(
                "Buka riwayat untuk memverifikasi data?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _kTextMid),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Tutup"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Buka history page sehingga admin bisa langsung verifikasi
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AdminAttendanceHistoryPage(),
                    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  ),
                );
              },
              child: const Text("Lihat Riwayat", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      // Reset form setelah dialog ditutup
      if (mounted) {
        setState(() {
          noteController.clear();
          manualTime         = null;
          manualCheckoutTime = null;
          selectedType       = "ONTIME";
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal: $e", isError: true);
    }

    if (mounted) setState(() => submitting = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFC62828) : _kPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimaryDark, _kPrimary, _kPrimaryMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: const Text("Absen Karyawan",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: loadingEmployees
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimaryDark, _kPrimaryMid],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 7))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Absenkan Karyawan", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 2),
                  Text("Untuk karyawan yang tidak punya HP",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 22),

          // ── Pilih Karyawan ──
          _SectionLabel("Pilih Karyawan"),
          const SizedBox(height: 10),
          employees.isEmpty
              ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_rounded, color: Color(0xFFC62828), size: 20),
              SizedBox(width: 10),
              Text("Tidak ada karyawan ditemukan",
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )
              : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedEmployee?['id'] as int?,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kPrimary),
                items: employees.map((e) {
                  final emp = Map<String, dynamic>.from(e);
                  return DropdownMenuItem<int>(
                    value: emp['id'] as int,
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '${emp['name']}'.isNotEmpty ? '${emp['name']}'[0].toUpperCase() : '?',
                            style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${emp['name']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
                          Text('${emp['email']}',
                              style: const TextStyle(fontSize: 11, color: _kTextLight),
                              overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  );
                }).toList(),
                onChanged: (id) {
                  final emp = employees.firstWhere((e) => (Map<String, dynamic>.from(e))['id'] == id);
                  setState(() => selectedEmployee = Map<String, dynamic>.from(emp));
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Jam Kehadiran ──
          _SectionLabel("Jam Kehadiran (Opsional)"),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: manualTime != null ? _kPrimary.withOpacity(0.5) : _kPrimary.withOpacity(0.15)),
                boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (manualTime != null ? _kPrimary : _kTextLight).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.access_time_rounded,
                      color: manualTime != null ? _kPrimary : _kTextLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      manualTime != null
                          ? "${manualTime!.hour.toString().padLeft(2,'0')}:${manualTime!.minute.toString().padLeft(2,'0')}"
                          : "Kosongkan untuk jam otomatis (WIB)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: manualTime != null ? FontWeight.w700 : FontWeight.w400,
                        color: manualTime != null ? _kTextDark : _kTextLight,
                      ),
                    ),
                    if (manualTime == null)
                      const Text("Tap untuk pilih jam", style: TextStyle(fontSize: 11, color: _kTextLight)),
                  ]),
                ),
                if (manualTime != null)
                  GestureDetector(
                    onTap: () => setState(() => manualTime = null),
                    child: const Icon(Icons.close_rounded, color: _kTextLight, size: 18),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── Jam Keluar ──
          _SectionLabel("Jam Keluar (Opsional)"),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickCheckoutTime,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: manualCheckoutTime != null ? const Color(0xFF2E7D32).withOpacity(0.5) : _kPrimary.withOpacity(0.15)),
                boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (manualCheckoutTime != null ? const Color(0xFF2E7D32) : _kTextLight).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded,
                      color: manualCheckoutTime != null ? const Color(0xFF2E7D32) : _kTextLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      manualCheckoutTime != null
                          ? "${manualCheckoutTime!.hour.toString().padLeft(2,'0')}:${manualCheckoutTime!.minute.toString().padLeft(2,'0')}"
                          : "Kosongkan kalau belum pulang",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: manualCheckoutTime != null ? FontWeight.w700 : FontWeight.w400,
                        color: manualCheckoutTime != null ? _kTextDark : _kTextLight,
                      ),
                    ),
                    if (manualCheckoutTime == null)
                      const Text("Isi kalau mau catat jam pulang sekaligus", style: TextStyle(fontSize: 11, color: _kTextLight)),
                  ]),
                ),
                if (manualCheckoutTime != null)
                  GestureDetector(
                    onTap: () => setState(() => manualCheckoutTime = null),
                    child: const Icon(Icons.close_rounded, color: _kTextLight, size: 18),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── Tipe Kehadiran ──
          _SectionLabel("Tipe Kehadiran"),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t          = _types[i];
                final isSelected = t["value"] == selectedType;
                final color      = t["color"] as Color;
                return GestureDetector(
                  onTap: () => setState(() => selectedType = t["value"] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? color : color.withOpacity(0.25), width: 1.5),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 12, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(t["icon"] as IconData,
                          color: isSelected ? Colors.white : color, size: 22),
                      const SizedBox(height: 5),
                      Text(t["label"] as String,
                          style: TextStyle(
                              color: isSelected ? Colors.white : color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Catatan ──
          _SectionLabel("Catatan (Opsional)"),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: _kTextDark),
            decoration: InputDecoration(
              hintText: "Contoh: absen oleh admin, alasan...",
              hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: _kPrimary, size: 18),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimaryMid, width: 1.5)),
            ),
          ),

          const SizedBox(height: 28),

          // ── Submit ──
          GestureDetector(
            onTap: submitting || employees.isEmpty ? null : _submit,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: (submitting || employees.isEmpty)
                    ? const LinearGradient(colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)])
                    : const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: (submitting || employees.isEmpty)
                    ? []
                    : [BoxShadow(color: _kPrimary.withOpacity(0.32), blurRadius: 18, offset: const Offset(0, 7))],
              ),
              child: Center(
                child: submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("Submit Absensi",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 4, height: 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kPrimaryDark, _kAccent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kPrimaryDark)),
  ]);
}