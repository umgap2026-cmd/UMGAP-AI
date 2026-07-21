import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'cache_service.dart';

const _kPrimary     = Color(0xFF1565C0);
const _kPrimaryMid  = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kAccent      = Color(0xFF00B0FF);
const _kSurface     = Color(0xFFF4F7FF);
const _kInputBg     = Color(0xFFF0F4FF);
const _kTextDark    = Color(0xFF0D1B3E);
const _kTextMid     = Color(0xFF4A5568);
const _kTextLight   = Color(0xFF90A4AE);

class AdminMyAttendancePage extends StatefulWidget {
  const AdminMyAttendancePage({super.key});

  @override
  State<AdminMyAttendancePage> createState() => _AdminMyAttendancePageState();
}

class _AdminMyAttendancePageState extends State<AdminMyAttendancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String selectedType = "ONTIME";
  final noteController = TextEditingController();

  bool loading        = false;
  bool locationLoading = false;
  String locationText = "Lokasi belum diambil";
  double? latitude;
  double? longitude;
  File? selfieFile;
  final ImagePicker picker = ImagePicker();

  bool historyLoading = true;
  List<dynamic> histories = [];

  bool checkoutLoading = false;

  final List<Map<String, dynamic>> _types = [
    {"value": "ONTIME", "label": "Hadir",       "icon": Icons.check_circle_rounded,    "color": Color(0xFF2E7D32)},
    {"value": "LATE",   "label": "Terlambat",   "icon": Icons.schedule_rounded,         "color": Color(0xFFE65100)},
    {"value": "SICK",   "label": "Sakit",        "icon": Icons.medical_services_rounded, "color": Color(0xFFAD1457)},
    {"value": "LEAVE",  "label": "Izin",         "icon": Icons.beach_access_rounded,     "color": Color(0xFF0277BD)},
    {"value": "ABSENT", "label": "Tidak Hadir", "icon": Icons.cancel_rounded,           "color": Color(0xFFC62828)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    getLocation();
    loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    final cached = await CacheService.getList(CacheService.kAttendanceMyAdmin);
    if (cached != null && mounted) setState(() { histories = cached; historyLoading = false; });
    try {
      final result = await ApiService.getMyAttendanceHistory();
      if (!mounted) return;
      await CacheService.set(CacheService.kAttendanceMyAdmin, result);
      setState(() { histories = result; historyLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => historyLoading = false);
      if (histories.isEmpty) _showSnack("Gagal load riwayat: $e", isError: true);
    }
  }

  Future<void> getLocation() async {
    setState(() => locationLoading = true);
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack("GPS belum aktif", isError: true);
      setState(() => locationLoading = false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showSnack("Izin lokasi ditolak", isError: true);
      setState(() => locationLoading = false);
      return;
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      locationText = "📍 ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
      locationLoading = false;
    });
  }

  Future<void> takeSelfie() async {
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );
    if (photo == null) return;
    setState(() => selfieFile = File(photo.path));
  }

  Future<void> submitAttendance() async {
    if (latitude == null || longitude == null) { _showSnack("Ambil lokasi dulu", isError: true); return; }
    if (selfieFile == null) { _showSnack("Ambil selfie dulu", isError: true); return; }

    setState(() => loading = true);
    try {
      final result = await ApiService.submitAttendance(
        attendanceType: selectedType, latitude: latitude!, longitude: longitude!,
        selfieFile: selfieFile!, note: noteController.text,
      );
      if (!mounted) return;
      _showSnack(result["message"] ?? "Absensi berhasil");
      setState(() { noteController.clear(); selfieFile = null; });
      await loadHistory();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal absensi: $e", isError: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic>? get _todayRow {
    final n = DateTime.now();
    final todayStr = "${n.year.toString().padLeft(4, '0')}-"
        "${n.month.toString().padLeft(2, '0')}-"
        "${n.day.toString().padLeft(2, '0')}";
    for (final h in histories) {
      final m = h as Map;
      if (readValue(m, ["work_date"]) == todayStr) {
        return Map<String, dynamic>.from(m);
      }
    }
    return null;
  }

  Future<void> checkOut() async {
    setState(() => checkoutLoading = true);
    try {
      final res = await ApiService.checkOut();
      if (!mounted) return;
      _showSnack(res["message"]?.toString() ?? "Check-out berhasil");
      await loadHistory();
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal: $e", isError: true);
    }
    if (mounted) setState(() => checkoutLoading = false);
  }

  Future<void> openMap(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnack("Tidak bisa membuka lokasi", isError: true);
    }
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

  String readValue(Map item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains("ONTIME") || up.contains("APPROVED") || up.contains("PRESENT")) return const Color(0xFF2E7D32);
    if (up.contains("LATE"))   return const Color(0xFFE65100);
    if (up.contains("SICK"))   return const Color(0xFFAD1457);
    if (up.contains("ABSENT") || up.contains("REJECTED")) return const Color(0xFFC62828);
    if (up.contains("LEAVE"))  return const Color(0xFF0277BD);
    if (up.contains("PENDING")) return const Color(0xFF6A1B9A);
    return _kTextLight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimaryDark, _kPrimary, _kPrimaryMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text("Absen Saya",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                ]),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                tabs: const [Tab(text: "Form Absen"), Tab(text: "Riwayat Saya")],
              ),
            ]),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [buildFormTab(), buildHistoryTab()],
      ),
    );
  }

  Widget buildFormTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Absensi Admin", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(_formatDate(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(_formatTime(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // Check-out card
        Builder(builder: (context) {
          final todayRow      = _todayRow;
          final todayCheckout = todayRow != null ? readValue(todayRow, ["checkout_at"]) : "-";
          final hasCheckedOut = todayCheckout != "-";
          final canCheckout   = todayRow != null;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded, color: Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Check-out", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                const SizedBox(height: 2),
                Text(
                  !canCheckout ? "Absen masuk dulu & tunggu disetujui admin"
                      : hasCheckedOut ? "Sudah check-out jam $todayCheckout"
                      : "Sudah check-in — siap check-out",
                  style: const TextStyle(fontSize: 11, color: _kTextMid),
                ),
              ])),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (!canCheckout || checkoutLoading) ? null : checkOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kTextLight.withOpacity(0.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: checkoutLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : Text(hasCheckedOut ? "Perbarui" : "Check-out", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          );
        }),

        const SizedBox(height: 20),

        // Type selector
        _SectionLabel("Tipe Kehadiran"),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = _types[i];
              final isSelected = t["value"] == selectedType;
              final color = t["color"] as Color;
              return GestureDetector(
                onTap: () => setState(() => selectedType = t["value"]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? color : color.withOpacity(0.2), width: 1.5),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(t["icon"] as IconData, color: isSelected ? Colors.white : color, size: 22),
                    const SizedBox(height: 5),
                    Text(t["label"] as String, style: TextStyle(
                      color: isSelected ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w700,
                    )),
                  ]),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        _SectionLabel("Catatan"),
        const SizedBox(height: 10),
        _StyledTextField(controller: noteController, hint: "Catatan opsional...", maxLines: 3, icon: Icons.note_alt_outlined),

        const SizedBox(height: 20),

        _SectionLabel("Lokasi GPS"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: latitude != null ? const Color(0xFF2E7D32).withOpacity(0.3) : _kPrimary.withOpacity(0.1)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (latitude != null ? const Color(0xFF2E7D32) : _kPrimary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                latitude != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
                color: latitude != null ? const Color(0xFF2E7D32) : _kPrimary, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(locationText, style: TextStyle(
              fontSize: 13,
              color: latitude != null ? const Color(0xFF2E7D32) : _kTextMid,
              fontWeight: FontWeight.w500,
            ))),
          ]),
        ),
        const SizedBox(height: 10),
        _OutlineBtn(label: locationLoading ? "Mengambil lokasi..." : "Perbarui Lokasi", icon: Icons.my_location_rounded, onTap: locationLoading ? null : getLocation),

        const SizedBox(height: 20),

        _SectionLabel("Foto Selfie"),
        const SizedBox(height: 10),
        if (selfieFile != null)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(selfieFile!, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(top: 8, right: 8,
              child: GestureDetector(
                onTap: () => setState(() => selfieFile = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ])
        else
          GestureDetector(
            onTap: takeSelfie,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kPrimary.withOpacity(0.2), width: 1.5),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _kPrimary.withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: _kPrimary, size: 28),
                ),
                const SizedBox(height: 10),
                const Text("Tap untuk ambil selfie", style: TextStyle(color: _kTextMid, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        _OutlineBtn(label: "Ambil Selfie", icon: Icons.camera_front_rounded, onTap: takeSelfie),

        const SizedBox(height: 28),
        _GradBtn(label: "Kirim Absensi", onTap: loading ? null : submitAttendance, loading: loading),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildHistoryTab() {
    if (historyLoading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    if (histories.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, size: 60, color: _kPrimary.withOpacity(0.2)),
        const SizedBox(height: 12),
        const Text("Belum ada riwayat absen saya", style: TextStyle(color: _kTextMid)),
      ]));
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: loadHistory,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: histories.length,
        itemBuilder: (context, index) {
          final item       = histories[index] as Map<String, dynamic>;
          final arrivalType = readValue(item, ["arrival_type"]);
          final status     = readValue(item, ["status"]);
          final workDate   = readValue(item, ["work_date"]);
          final checkinAt  = readValue(item, ["checkin_at"]);
          final checkoutAt = readValue(item, ["checkout_at"]);
          final checkoutAuto = item["checkout_auto"] == true;
          final note       = readValue(item, ["note"]);
          final photoUrl   = readValue(item, ["photo_url"]);
          final mapUrl     = readValue(item, ["map_url"]);
          final aColor     = _statusColor(arrivalType);
          final sColor     = _statusColor(status);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 4, color: aColor),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(arrivalType, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark))),
                      _SmBadge(status, sColor),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: _kPrimary.withOpacity(0.6)),
                      const SizedBox(width: 5),
                      Text(workDate, style: const TextStyle(fontSize: 12, color: _kTextMid)),
                      const SizedBox(width: 14),
                      Icon(Icons.login_rounded, size: 13, color: _kPrimary.withOpacity(0.6)),
                      const SizedBox(width: 5),
                      Text(checkinAt, style: const TextStyle(fontSize: 12, color: _kTextMid)),
                    ]),
                    if (checkoutAt != "-") ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.logout_rounded, size: 13, color: const Color(0xFF2E7D32).withOpacity(0.7)),
                        const SizedBox(width: 5),
                        Text(
                          checkoutAuto ? "$checkoutAt (otomatis)" : checkoutAt,
                          style: const TextStyle(fontSize: 12, color: _kTextMid),
                        ),
                      ]),
                    ],
                    if (note != "-" && note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.note_alt_outlined, size: 13, color: _kPrimary.withOpacity(0.5)),
                        const SizedBox(width: 5),
                        Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: _kTextMid))),
                      ]),
                    ],
                    if (photoUrl != "-" && photoUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(photoUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(height: 80, color: _kSurface,
                              child: const Center(child: Icon(Icons.broken_image_rounded, color: _kTextLight))),
                        ),
                      ),
                    ],
                    if (mapUrl != "-" && mapUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => openMap(mapUrl),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: _kPrimary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kPrimary.withOpacity(0.15)),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.location_on_rounded, color: _kPrimary, size: 14),
                            const SizedBox(width: 6),
                            const Text("Lihat Lokasi", style: TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    const days   = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
    const months = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return "${days[d.weekday % 7]}, ${d.day} ${months[d.month]} ${d.year}";
  }
  String _formatTime(DateTime d) => "${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}";
}

// ─── Mini helpers ────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 16, decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_kPrimaryDark, _kAccent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      borderRadius: BorderRadius.circular(2),
    )),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kPrimaryDark)),
  ]);
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final IconData icon;
  const _StyledTextField({required this.controller, required this.hint, this.maxLines = 1, required this.icon});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, maxLines: maxLines,
    style: const TextStyle(fontSize: 14, color: _kTextDark),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
      prefixIcon: Icon(icon, color: _kPrimary, size: 18),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimaryMid, width: 1.5)),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.3), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _kPrimary, size: 18), const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    ),
  );
}

class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _GradBtn({required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onTap == null
            ? const LinearGradient(colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)])
            : const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: onTap == null ? [] : [BoxShadow(color: _kPrimary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Center(child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
      ),
    ),
  );
}

class _SmBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}