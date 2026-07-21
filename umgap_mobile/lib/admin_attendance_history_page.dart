import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'cache_service.dart';

const _kPrimary     = Color(0xFF1565C0);
const _kPrimaryMid  = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kSurface     = Color(0xFFF4F7FF);
const _kInputBg     = Color(0xFFF0F4FF);
const _kTextDark    = Color(0xFF0D1B3E);
const _kTextMid     = Color(0xFF4A5568);
const _kTextLight   = Color(0xFF90A4AE);

class AdminAttendanceHistoryPage extends StatefulWidget {
  const AdminAttendanceHistoryPage({super.key});

  @override
  State<AdminAttendanceHistoryPage> createState() => _AdminAttendanceHistoryPageState();
}

class _AdminAttendanceHistoryPageState extends State<AdminAttendanceHistoryPage> {
  bool loading = true;
  List<dynamic> attendanceList = [];
  final searchController = TextEditingController();
  String selectedArrival = "SEMUA";

  final _arrivalTypes = [
    {"value": "SEMUA",  "label": "Semua",  "color": _kPrimary},
    {"value": "ONTIME", "label": "Ontime", "color": Color(0xFF2E7D32)},
    {"value": "LATE",   "label": "Late",   "color": Color(0xFFE65100)},
    {"value": "SICK",   "label": "Sakit",  "color": Color(0xFFAD1457)},
    {"value": "LEAVE",  "label": "Izin",   "color": Color(0xFF0277BD)},
    {"value": "ABSENT", "label": "Absen",  "color": Color(0xFFC62828)},
  ];

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadAttendance() async {
    final cached = await CacheService.getList(CacheService.kAttendanceAdmin);
    if (cached != null && mounted) setState(() { attendanceList = cached; loading = false; });
    else setState(() => loading = true);
    try {
      final result = await ApiService.getAdminAttendanceList();
      if (!mounted) return;
      await CacheService.set(CacheService.kAttendanceAdmin, result);
      setState(() { attendanceList = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (attendanceList.isEmpty) _showSnack("Gagal load riwayat: $e", isError: true);
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

  // ── FIX UTAMA: API admin mengembalikan "employee_name", bukan "user_name" ──
  String readValue(Map item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty && v.toString() != 'null') {
        return v.toString();
      }
    }
    return "-";
  }

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains("ONTIME") || up.contains("APPROVED") || up.contains("PRESENT")) return const Color(0xFF2E7D32);
    if (up.contains("LATE"))    return const Color(0xFFE65100);
    if (up.contains("SICK"))    return const Color(0xFFAD1457);
    if (up.contains("ABSENT") || up.contains("REJECTED")) return const Color(0xFFC62828);
    if (up.contains("LEAVE"))   return const Color(0xFF0277BD);
    if (up.contains("PENDING")) return const Color(0xFF6A1B9A);
    return _kTextLight;
  }

  Future<void> openMap(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnack("Tidak bisa membuka lokasi", isError: true);
    }
  }

  List<dynamic> get _filtered {
    return attendanceList.where((e) {
      final item = e as Map<String, dynamic>;
      // FIX: API admin pakai "employee_name", bukan "user_name"
      final name    = readValue(item, ["employee_name", "user_name"]).toLowerCase();
      final arrival = readValue(item, ["arrival_type"]).toUpperCase();
      final matchName    = name.contains(searchController.text.trim().toLowerCase());
      final matchArrival = selectedArrival == "SEMUA" || arrival == selectedArrival;
      return matchName && matchArrival;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimaryDark, _kPrimary, _kPrimaryMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: const Text("Riwayat Absensi",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: loadAttendance,
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : Column(children: [
        // ── Search + Filter ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(children: [
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14, color: _kTextDark),
              decoration: InputDecoration(
                hintText: "Cari nama karyawan...",
                hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _kPrimary, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kTextLight, size: 18),
                  onPressed: () { searchController.clear(); setState(() {}); },
                )
                    : null,
                filled: true,
                fillColor: _kInputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kPrimary.withOpacity(0.15))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimaryMid, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _arrivalTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = _arrivalTypes[i];
                  final isSelected = selectedArrival == t["value"];
                  final color = t["color"] as Color;
                  return GestureDetector(
                    onTap: () => setState(() => selectedArrival = t["value"] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: 1.5),
                        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : [],
                      ),
                      child: Text(t["label"] as String,
                          style: TextStyle(color: isSelected ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            Text("${filtered.length} data ditemukan",
                style: const TextStyle(fontSize: 12, color: _kTextMid, fontWeight: FontWeight.w500)),
          ]),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: _kPrimary.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text("Tidak ada data yang cocok",
                style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w500)),
          ]))
              : RefreshIndicator(
            color: _kPrimary,
            onRefresh: loadAttendance,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index] as Map<String, dynamic>;
                return _HistoryCard(
                  item: item,
                  readValue: readValue,
                  statusColor: _statusColor,
                  onMap: openMap,
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(Map, List<String>) readValue;
  final Color Function(String) statusColor;
  final void Function(String) onMap;

  const _HistoryCard({
    required this.item,
    required this.readValue,
    required this.statusColor,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: gunakan "employee_name" sebagai key utama
    final userName    = readValue(item, ["employee_name", "user_name"]);
    final workDate    = readValue(item, ["work_date"]);
    final checkinAt   = readValue(item, ["checkin_at"]);
    final status      = readValue(item, ["status"]);
    final arrivalType = readValue(item, ["arrival_type"]);
    final note        = readValue(item, ["note"]);
    final photoUrl    = readValue(item, ["photo_url"]);
    final mapUrl      = readValue(item, ["map_url"]);

    final aColor = statusColor(arrivalType);
    final sColor = statusColor(status);

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
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: aColor.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty && userName != "-" ? userName[0].toUpperCase() : "?",
                      style: TextStyle(color: aColor, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(userName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: _kTextLight),
                      const SizedBox(width: 4),
                      Text(workDate, style: const TextStyle(fontSize: 11, color: _kTextLight)),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_rounded, size: 11, color: _kTextLight),
                      const SizedBox(width: 4),
                      Text(checkinAt, style: const TextStyle(fontSize: 11, color: _kTextLight)),
                    ]),
                  ]),
                ),
              ]),

              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Badge(arrivalType, aColor),
                _Badge(status, sColor),
              ]),

              if (note != "-" && note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.note_alt_outlined, size: 13, color: _kTextLight),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note,
                      style: const TextStyle(fontSize: 12, color: _kTextMid, height: 1.4))),
                ]),
              ],

              if (photoUrl != "-" && photoUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photoUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 80, color: const Color(0xFFF0F4FF),
                      child: const Center(child: Icon(Icons.broken_image_rounded, color: _kTextLight)),
                    ),
                  ),
                ),
              ],

              if (mapUrl != "-" && mapUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => onMap(mapUrl),
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
                      const Text("Lihat Lokasi",
                          style: TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}