import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'cache_service.dart';

// ── Color tokens ─────────────────────────────
const _navy     = Color(0xFF0B1733);
const _navyMid  = Color(0xFF14275C);
const _blue     = Color(0xFF1565C0);
const _blueMid  = Color(0xFF1E88E5);
const _cyan     = Color(0xFF29B6F6);
const _green    = Color(0xFF00C853);
const _surface  = Color(0xFFF2F5FC);
const _white    = Colors.white;
const _textDark = Color(0xFF0D1B3E);
const _textMid  = Color(0xFF4A5568);
const _textSoft = Color(0xFF8FA3BF);

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with TickerProviderStateMixin {
  late TabController       _tabCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // ── Form state ────────────────────────────
  String  selectedType    = "ONTIME";
  final   noteCtrl        = TextEditingController();
  bool    loading         = false;
  bool    locationLoading = false;
  String  locationText    = "Belum diambil";
  double? latitude;
  double? longitude;
  File?   selfieFile;
  final   picker          = ImagePicker();

  // ── History & profil ──────────────────────
  bool                 historyLoading = true;
  List<dynamic>        histories      = [];
  Map<String, dynamic> _meUser        = {};

  // ── Check-out ──────────────────────────────
  bool checkoutLoading = false;

  // ── Tipe kehadiran ────────────────────────
  final List<Map<String, dynamic>> _types = [
    {"value":"ONTIME", "label":"Hadir",      "icon":Icons.check_circle_rounded,    "color":Color(0xFF2E7D32)},
    {"value":"LATE",   "label":"Terlambat",  "icon":Icons.schedule_rounded,        "color":Color(0xFFE65100)},
    {"value":"SICK",   "label":"Sakit",      "icon":Icons.medical_services_rounded,"color":Color(0xFFAD1457)},
    {"value":"LEAVE",  "label":"Izin",       "icon":Icons.beach_access_rounded,    "color":Color(0xFF0277BD)},
    {"value":"ABSENT", "label":"Tidak Hadir","icon":Icons.cancel_rounded,          "color":Color(0xFFC62828)},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl   = TabController(length: 2, vsync: this);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    getLocation();
    loadHistory();
    _loadMe();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pulseCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //  DATA METHODS  (semua fungsi dipertahankan)
  // ══════════════════════════════════════════

  Future<void> loadHistory() async {
    final cached = await CacheService.getList(CacheService.kAttendanceHistory);
    if (cached != null && mounted) setState(() { histories = cached; historyLoading = false; });
    try {
      final r = await ApiService.getAttendanceHistory();
      if (!mounted) return;
      await CacheService.set(CacheService.kAttendanceHistory, r);
      setState(() { histories = r; historyLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => historyLoading = false);
      if (histories.isEmpty) _snack("Gagal load riwayat: $e", isError: true);
    }
  }

  Future<void> _loadMe() async {
    try {
      final r = await ApiService.getMe();
      if (!mounted) return;
      final u = r['user'] != null
          ? Map<String, dynamic>.from(r['user'] as Map)
          : Map<String, dynamic>.from(r);
      setState(() => _meUser = u);
    } catch (_) {}
  }

  Future<void> getLocation() async {
    setState(() => locationLoading = true);
    bool svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) {
      _snack("GPS belum aktif", isError: true);
      setState(() => locationLoading = false); return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _snack("Izin lokasi ditolak", isError: true);
      setState(() => locationLoading = false); return;
    }
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      latitude     = pos.latitude;
      longitude    = pos.longitude;
      locationText = "${pos.latitude.toStringAsFixed(5)}, "
          "${pos.longitude.toStringAsFixed(5)}";
      locationLoading = false;
    });
  }

  Future<void> takeSelfie() async {
    HapticFeedback.lightImpact();
    final f = await picker.pickImage(
      source:               ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality:          70,
    );
    if (f == null) return;
    setState(() => selfieFile = File(f.path));
    HapticFeedback.mediumImpact();
  }

  Future<void> submitAttendance() async {
    if (latitude == null || longitude == null) {
      HapticFeedback.vibrate();
      _snack("Ambil lokasi GPS dulu", isError: true); return;
    }
    if (selfieFile == null) {
      HapticFeedback.vibrate();
      _snack("Ambil foto selfie dulu", isError: true); return;
    }
    HapticFeedback.heavyImpact();
    setState(() => loading = true);
    try {
      final res = await ApiService.submitAttendance(
        attendanceType: selectedType,
        latitude:       latitude!,
        longitude:      longitude!,
        selfieFile:     selfieFile!,
        note:           noteCtrl.text,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _snack(res["message"] ?? "Absensi berhasil");
      setState(() { noteCtrl.clear(); selfieFile = null; });
      await loadHistory();
      _tabCtrl.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      _snack("Gagal: $e", isError: true);
    }
    if (mounted) setState(() => loading = false);
  }

  /// Data absensi hari ini dari `histories` (kalau sudah check-in & disetujui).
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
    HapticFeedback.mediumImpact();
    setState(() => checkoutLoading = true);
    try {
      final res = await ApiService.checkOut();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _snack(res["message"]?.toString() ?? "Check-out berhasil");
      await loadHistory();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      _snack("Gagal: $e", isError: true);
    }
    if (mounted) setState(() => checkoutLoading = false);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior:        SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFC62828) : _blue,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin:          const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: _surface,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildFormTab(), _buildHistoryTab()],
          ),
        ),
      ]),
    );
  }

  // ── HEADER ─────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyMid, _blue],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _white, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
              const Expanded(
                child: Text('Absensi', style: TextStyle(
                    color: _white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:         Colors.white.withOpacity(0.10),
                  borderRadius:  BorderRadius.circular(20),
                  border:        Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded, color: _cyan, size: 12),
                  const SizedBox(width: 5),
                  Text(_shortDate(), style: const TextStyle(
                      color: _white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller:           _tabCtrl,
            indicatorColor:       _cyan,
            indicatorWeight:      3,
            indicatorSize:        TabBarIndicatorSize.label,
            labelColor:           _white,
            unselectedLabelColor: Colors.white54,
            labelStyle:           const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [Tab(text: "Form Absen"), Tab(text: "Riwayat")],
          ),

        ]),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  FORM TAB — Premium Stepper Experience
  // ══════════════════════════════════════════
  Widget _buildFormTab() {
    final selType  = _types.firstWhere((t) => t["value"] == selectedType);
    final selColor = selType["color"] as Color;
    final stepLoc  = latitude != null;
    final stepSelf = selfieFile != null;
    final canSubmit = stepLoc && stepSelf && !loading;

    final todayRow      = _todayRow;
    final todayCheckout = todayRow != null ? readValue(todayRow, ["checkout_at"]) : "-";
    final hasCheckedOut = todayCheckout != "-";
    final canCheckout   = todayRow != null;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [

        // ── CHECK-OUT CARD ────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: _green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Check-out", style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 2),
                Text(
                  !canCheckout
                      ? "Absen masuk dulu & tunggu disetujui admin"
                      : hasCheckedOut
                      ? "Sudah check-out jam $todayCheckout"
                      : "Sudah check-in — siap check-out",
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
              ],
            )),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (!canCheckout || checkoutLoading) ? null : checkOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: _white,
                disabledBackgroundColor: _textSoft.withOpacity(0.25),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: checkoutLoading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: _white))
                  : Text(hasCheckedOut ? "Perbarui" : "Check-out",
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),

        // ── STEP 1: Tipe Kehadiran ────────────
        _StepCard(
          step: 1, title: "Tipe Kehadiran", done: true,
          child: Column(children: [
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection:  Axis.horizontal,
                itemCount:        _types.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final t          = _types[i];
                  final isSelected = t["value"] == selectedType;
                  final color      = t["color"] as Color;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => selectedType = t["value"] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 78,
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          colors: [color, color.withOpacity(0.75)],
                          begin:  Alignment.topLeft,
                          end:    Alignment.bottomRight,
                        ) : null,
                        color:        isSelected ? null : _white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : color.withOpacity(0.22),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.35),
                            blurRadius: 16, offset: const Offset(0, 6))]
                            : [BoxShadow(color: Colors.black.withOpacity(0.04),
                            blurRadius: 6)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.20)
                                  : color.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(t["icon"] as IconData,
                                color: isSelected ? _white : color, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(t["label"] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:      isSelected ? _white : color,
                                fontSize:   10,
                                fontWeight: FontWeight.w800,
                                height:     1.2,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Selected summary pill
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key:    ValueKey(selectedType),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        selColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: selColor.withOpacity(0.20)),
                ),
                child: Row(children: [
                  Icon(selType["icon"] as IconData, color: selColor, size: 16),
                  const SizedBox(width: 8),
                  Text('Dipilih: ${selType["label"]}',
                      style: TextStyle(color: selColor,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32), size: 16),
                ]),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── STEP 2: Catatan ───────────────────
        _StepCard(
          step: 2, title: "Catatan (Opsional)", done: true,
          child: TextField(
            controller: noteCtrl,
            maxLines:   3,
            style:      const TextStyle(fontSize: 14, color: _textDark),
            decoration: InputDecoration(
              hintText:  "Contoh: macet, izin keluarga, dll...",
              hintStyle: const TextStyle(color: _textSoft, fontSize: 13),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: _blue, size: 20),
              filled:    true,
              fillColor: const Color(0xFFF0F4FF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _blue.withOpacity(0.15))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _blue.withOpacity(0.15))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blueMid, width: 1.5)),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── STEP 3: Lokasi GPS ────────────────
        _StepCard(
          step: 3, title: "Lokasi GPS", done: stepLoc,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: stepLoc
                    ? const Color(0xFF2E7D32).withOpacity(0.06)
                    : locationLoading
                    ? _blue.withOpacity(0.04)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: stepLoc
                      ? const Color(0xFF2E7D32).withOpacity(0.25)
                      : locationLoading
                      ? _blue.withOpacity(0.15)
                      : const Color(0xFFE65100).withOpacity(0.20),
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                if (locationLoading)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: _pulse.value,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: _blue.withOpacity(0.12),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.location_searching_rounded,
                            color: _blue, size: 22),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: stepLoc
                          ? const Color(0xFF2E7D32).withOpacity(0.12)
                          : const Color(0xFFE65100).withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      stepLoc
                          ? Icons.location_on_rounded
                          : Icons.location_off_rounded,
                      color: stepLoc
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationLoading
                          ? "Mengambil lokasi..."
                          : stepLoc
                          ? "Lokasi berhasil diambil"
                          : "Lokasi belum diambil",
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color: locationLoading ? _blue
                            : stepLoc ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                    if (stepLoc && !locationLoading) ...[
                      const SizedBox(height: 2),
                      Text("📍 $locationText",
                          style: const TextStyle(fontSize: 11, color: _textMid)),
                    ],
                    if (!stepLoc && !locationLoading) ...[
                      const SizedBox(height: 2),
                      const Text("Tap tombol di bawah untuk ambil lokasi",
                          style: TextStyle(fontSize: 11, color: _textSoft)),
                    ],
                  ],
                )),
                if (stepLoc)
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF2E7D32), size: 22),
              ]),
            ),
            const SizedBox(height: 10),
            _PremiumOutlineBtn(
              label:     locationLoading
                  ? "Mengambil lokasi..."
                  : stepLoc ? "Perbarui Lokasi" : "Ambil Lokasi GPS",
              icon:      locationLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.my_location_rounded,
              color:     stepLoc ? _blue : const Color(0xFF2E7D32),
              onPressed: locationLoading ? null : () {
                HapticFeedback.mediumImpact();
                getLocation();
              },
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── STEP 4: Foto Selfie ───────────────
        _StepCard(
          step: 4, title: "Foto Selfie", done: stepSelf,
          child: Column(children: [
            if (selfieFile != null) ...[
              // Preview premium
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(selfieFile!,
                      height: 240, width: double.infinity,
                      fit: BoxFit.cover),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Badge siap
                Positioned(bottom: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.90),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded, color: _white, size: 14),
                      SizedBox(width: 4),
                      Text("Foto siap", style: TextStyle(
                          color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                // Hapus
                Positioned(top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => selfieFile = null);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: _white, size: 16),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _PremiumOutlineBtn(
                label: "Ganti Foto", icon: Icons.camera_alt_rounded,
                color: _blue, onPressed: takeSelfie,
              ),
            ] else ...[
              // Camera placeholder — camera-viewfinder style
              GestureDetector(
                onTap: takeSelfie,
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    color:         const Color(0xFFF0F4FF),
                    borderRadius:  BorderRadius.circular(18),
                    border:        Border.all(
                        color: _blue.withOpacity(0.18), width: 1.5),
                  ),
                  child: Stack(children: [
                    // Corner brackets
                    Positioned(top: 14, left: 14,   child: _CornerBracket(top: true,  left: true)),
                    Positioned(top: 14, right: 14,  child: _CornerBracket(top: true,  left: false)),
                    Positioned(bottom: 14, left: 14, child: _CornerBracket(top: false, left: true)),
                    Positioned(bottom: 14, right: 14,child: _CornerBracket(top: false, left: false)),
                    // Content
                    Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Transform.scale(
                              scale: 0.92 + _pulse.value * 0.08, child: child),
                          child: Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                _blue.withOpacity(0.14), _cyan.withOpacity(0.08)]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_front_rounded,
                                color: _blue, size: 30),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Tap untuk ambil selfie",
                            style: TextStyle(color: _textMid, fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text("Gunakan kamera depan",
                            style: TextStyle(color: _textSoft, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 22),

        // ── CHECKLIST SYARAT ─────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: canSubmit
                ? const Color(0xFF2E7D32).withOpacity(0.06)
                : _blue.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canSubmit
                  ? const Color(0xFF2E7D32).withOpacity(0.25)
                  : _blue.withOpacity(0.12),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              canSubmit ? "Semua syarat terpenuhi ✓" : "Syarat yang harus dipenuhi:",
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: canSubmit ? const Color(0xFF2E7D32) : _textMid,
              ),
            ),
            const SizedBox(height: 8),
            _CheckRow(label: "Lokasi GPS diambil",  done: stepLoc),
            const SizedBox(height: 4),
            _CheckRow(label: "Foto selfie diambil", done: stepSelf),
          ]),
        ),

        const SizedBox(height: 16),

        // ── SUBMIT BUTTON ────────────────────
        GestureDetector(
          onTap: canSubmit ? submitAttendance : () {
            HapticFeedback.vibrate();
            if (!stepLoc)  _snack("Ambil lokasi GPS dulu", isError: true);
            else if (!stepSelf) _snack("Ambil foto selfie dulu", isError: true);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              gradient: canSubmit
                  ? const LinearGradient(
                  colors: [_navy, _blue],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : const LinearGradient(
                  colors: [Color(0xFFB0BEC5), Color(0xFFCFD8DC)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: canSubmit
                  ? [BoxShadow(color: _blue.withOpacity(0.40),
                  blurRadius: 22, offset: const Offset(0, 8))]
                  : [],
            ),
            child: Center(child: loading
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: _white, strokeWidth: 2.5))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                canSubmit
                    ? Icons.fingerprint_rounded
                    : Icons.lock_outline_rounded,
                color: _white, size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                canSubmit ? "Kirim Absensi" : "Lengkapi data dulu",
                style: const TextStyle(color: _white, fontSize: 15,
                    fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
            ])),
          ),
        ),

        if (!canSubmit && !loading) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              !stepLoc  ? "⚠ Lokasi GPS belum diambil"
                  : !stepSelf ? "⚠ Foto selfie belum diambil" : "",
              style: const TextStyle(color: Color(0xFFE65100),
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════
  //  HISTORY TAB  (semua fungsi utuh)
  // ══════════════════════════════════════════

  String readValue(Map item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains("ONTIME") || up.contains("APPROVED") || up.contains("PRESENT"))
      return const Color(0xFF2E7D32);
    if (up.contains("LATE") || up.contains("SICK")) return const Color(0xFFE65100);
    if (up.contains("ABSENT") || up.contains("REJECTED")) return const Color(0xFFC62828);
    if (up.contains("LEAVE"))   return const Color(0xFF0277BD);
    if (up.contains("PENDING")) return const Color(0xFF6A1B9A);
    return _textSoft;
  }

  Map<String, int> get _thisMonthStats {
    final now   = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2,'0')}';
    int present=0, sick=0, leave=0, absent=0, late=0;
    for (final r in histories) {
      final wd  = readValue(r as Map, ['work_date']);
      if (!wd.startsWith(month)) continue;
      final st  = readValue(r, ['status']).toUpperCase();
      final arr = readValue(r, ['arrival_type']).toUpperCase();
      if (st == 'PRESENT') { present++; if (arr == 'LATE') late++; }
      else if (st == 'SICK')   sick++;
      else if (st == 'LEAVE')  leave++;
      else if (st == 'ABSENT') absent++;
    }
    return {'present':present,'sick':sick,'leave':leave,'absent':absent,'late':late};
  }

  int get _gajiEstimasi {
    final s   = _thisMonthStats;
    final d   = (_meUser['daily_salary']   as num?)?.toInt() ?? 0;
    final m   = (_meUser['monthly_salary'] as num?)?.toInt() ?? 0;
    final typ = '${_meUser['salary_type'] ?? 'daily'}';
    if (typ == 'monthly') return m;
    return ((s['present']??0) + (s['sick']??0) + (s['leave']??0)) * d;
  }

  String _rpFormat(int v) {
    if (v == 0) return 'Rp -';
    return 'Rp ${v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Widget _buildHistoryTab() {
    if (historyLoading)
      return const Center(child: CircularProgressIndicator(color: _blue));

    final stats  = _thisMonthStats;
    final now    = DateTime.now();
    const months = ['','Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'];

    return RefreshIndicator(
      color:     _blue,
      onRefresh: () async { await loadHistory(); await _loadMe(); },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // Summary card
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _navyMid, Color(0xFF1A3A7A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: _navy.withOpacity(0.28),
                  blurRadius: 22, offset: const Offset(0, 8))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: Colors.white54, size: 13),
                  const SizedBox(width: 6),
                  Text('${months[now.month]} ${now.year}',
                      style: const TextStyle(color: Colors.white54,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _green.withOpacity(0.3)),
                    ),
                    child: Text('${stats['present']} Hadir',
                        style: const TextStyle(color: _green,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _SumChip('Hadir',  stats['present']!, const Color(0xFF81C784)),
                  _VSep(),
                  _SumChip('Sakit',  stats['sick']!,    const Color(0xFF64B5F6)),
                  _VSep(),
                  _SumChip('Izin',   stats['leave']!,   const Color(0xFFCE93D8)),
                  _VSep(),
                  _SumChip('Absen',  stats['absent']!,  const Color(0xFFEF9A9A)),
                  _VSep(),
                  _SumChip('Telat',  stats['late']!,    const Color(0xFFFFCC80)),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(height: 1,
                      color: Colors.white.withOpacity(0.10)),
                ),
                Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white54, size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Estimasi Gaji Bulan Ini',
                        style: TextStyle(color: Colors.white60,
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  Text(_rpFormat(_gajiEstimasi),
                      style: const TextStyle(color: _white,
                          fontSize: 17, fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 18),

          if (histories.isEmpty) ...[
            const SizedBox(height: 40),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    color: _blue.withOpacity(0.06), shape: BoxShape.circle),
                child: Icon(Icons.history_rounded,
                    size: 44, color: _blue.withOpacity(0.25)),
              ),
              const SizedBox(height: 16),
              const Text("Belum ada riwayat absensi",
                  style: TextStyle(color: _textMid, fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ])),
          ] else
            ...histories.map((item) {
              final m       = item as Map<String, dynamic>;
              final type    = readValue(m, ["arrival_type","attendance_type"]);
              final status  = readValue(m, ["status","approval_status"]);
              final date    = readValue(m, ["work_date"]);
              final time    = readValue(m, ["checkin_at","created_at"]);
              final coTime  = readValue(m, ["checkout_at"]);
              final coAuto  = m["checkout_auto"] == true;
              final note    = readValue(m, ["note","notes"]);
              return _HistoryCard(
                type: type, status: status, date: date, time: time,
                checkoutTime: coTime == "-" ? null : coTime, checkoutAuto: coAuto,
                note: note,
                statusColor: _statusColor(type), badgeColor: _statusColor(status),
              );
            }),
        ],
      ),
    );
  }

  String _shortDate() {
    final n = DateTime.now();
    const m = ['','Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'];
    return "${n.day} ${m[n.month]} ${n.year}";
  }
}

// ════════════════════════════════════════════
//  STEP CARD
// ════════════════════════════════════════════
class _StepCard extends StatelessWidget {
  final int step; final String title; final bool done; final Widget child;
  const _StepCard({required this.step, required this.title,
    required this.done, required this.child});
  @override
  Widget build(BuildContext context) {
    final doneColor  = const Color(0xFF2E7D32);
    final accentColor = done ? doneColor : _blue;

    return Container(
      decoration: BoxDecoration(
        color:         _white,
        borderRadius:  BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.10),
              blurRadius: 16, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Left accent bar ──────────────────
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: done
                      ? [doneColor, const Color(0xFF43A047)]
                      : [_navy, _blue],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
            // ── Content ──────────────────────────
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
                  decoration: BoxDecoration(
                    color: done
                        ? doneColor.withOpacity(0.04)
                        : _blue.withOpacity(0.03),
                    border: Border(bottom: BorderSide(
                        color: accentColor.withOpacity(0.10))),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: done
                              ? [doneColor, const Color(0xFF43A047)]
                              : [_navy, _blue],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: done
                          ? const Icon(Icons.check_rounded, color: _white, size: 14)
                          : Text('$step', style: const TextStyle(
                          color: _white, fontSize: 12,
                          fontWeight: FontWeight.w900))),
                    ),
                    const SizedBox(width: 10),
                    Text(title, style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w800,
                        color:      done ? doneColor : _navy)),
                    const Spacer(),
                    if (done)
                      Text("Selesai ✓", style: TextStyle(
                          color: doneColor, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: child,
                ),
              ]),
            ),
          ]),
        ), // IntrinsicHeight
      ),
    );
  }
}

// ════════════════════════════════════════════
//  CAMERA CORNER BRACKET
// ════════════════════════════════════════════
class _CornerBracket extends StatelessWidget {
  final bool top, left;
  const _CornerBracket({required this.top, required this.left});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22, height: 22,
    child: CustomPaint(painter: _BracketPainter(top: top, left: left)),
  );
}

class _BracketPainter extends CustomPainter {
  final bool top, left;
  _BracketPainter({required this.top, required this.left});
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color       = _blue.withOpacity(0.40)
      ..strokeWidth = 2.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    final x = left ? 0.0 : s.width;
    final y = top  ? 0.0 : s.height;
    final ex = left ?  s.width : -s.width;
    final ey = top  ?  s.height : -s.height;
    // Horizontal arm
    c.drawLine(Offset(x, y), Offset(x + ex, y), p);
    // Vertical arm
    c.drawLine(Offset(x, y), Offset(x, y + ey), p);
  }
  @override bool shouldRepaint(_) => false;
}

// ════════════════════════════════════════════
//  CHECKLIST ROW
// ════════════════════════════════════════════
class _CheckRow extends StatelessWidget {
  final String label; final bool done;
  const _CheckRow({required this.label, required this.done});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(
      done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
      color: done ? const Color(0xFF2E7D32) : _textSoft,
      size:  16,
    ),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(
        fontSize:   12,
        color:      done ? const Color(0xFF2E7D32) : _textSoft,
        fontWeight: done ? FontWeight.w600 : FontWeight.w400)),
  ]);
}

// ════════════════════════════════════════════
//  PREMIUM OUTLINE BUTTON
// ════════════════════════════════════════════
class _PremiumOutlineBtn extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback? onPressed;
  const _PremiumOutlineBtn({required this.label, required this.icon,
    required this.color, this.onPressed});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: onPressed != null
            ? color.withOpacity(0.06) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: onPressed != null
                ? color.withOpacity(0.30) : _textSoft.withOpacity(0.15),
            width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: onPressed != null ? color : _textSoft, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color:      onPressed != null ? color : _textSoft,
            fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════
//  HISTORY CARD
// ════════════════════════════════════════════
class _HistoryCard extends StatelessWidget {
  final String type, status, date, time, note;
  final String? checkoutTime;
  final bool checkoutAuto;
  final Color  statusColor, badgeColor;
  const _HistoryCard({required this.type, required this.status,
    required this.date, required this.time, required this.note,
    this.checkoutTime, this.checkoutAuto = false,
    required this.statusColor, required this.badgeColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:         _white,
        borderRadius:  BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left accent bar — stretches dengan konten
            Container(width: 5, color: statusColor),
            // Icon area
            Container(
              width: 56,
              color: statusColor.withOpacity(0.07),
              child: Center(child: Icon(Icons.fingerprint_rounded,
                  color: statusColor, size: 24)),
            ),
            // Content
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(type, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _textDark))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        badgeColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: badgeColor.withOpacity(0.3)),
                    ),
                    child: Text(status, style: TextStyle(
                        color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 7),
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 11, color: _blue.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(date, style: const TextStyle(fontSize: 11, color: _textMid)),
                  const SizedBox(width: 10),
                  Icon(Icons.login_rounded, size: 11, color: _blue.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(time, style: const TextStyle(fontSize: 11, color: _textMid)),
                ]),
                if (checkoutTime != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.logout_rounded, size: 11, color: _green.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      checkoutAuto ? "$checkoutTime (otomatis)" : checkoutTime!,
                      style: const TextStyle(fontSize: 11, color: _textMid),
                    ),
                  ]),
                ],
                if (note != "-" && note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.note_alt_outlined, size: 11, color: _blue.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(note,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _textMid))),
                  ]),
                ],
              ]),
            )),
          ]),
        ),  // IntrinsicHeight
      ),
    );
  }
}

// ════════════════════════════════════════════
//  TINY HELPERS
// ════════════════════════════════════════════
class _SumChip extends StatelessWidget {
  final String label; final int value; final Color color;
  const _SumChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
        color: value == 0 ? Colors.white24 : color)),
    const SizedBox(height: 3),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54,
        fontWeight: FontWeight.w500)),
  ]));
}

class _VSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, color: Colors.white.withOpacity(0.10));
}