import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'cache_service.dart';

const _kPrimary     = Color(0xFF1565C0);
const _kPrimaryMid  = Color(0xFF1E88E5);
const _kPrimaryDark = Color(0xFF0D47A1);
const _kAccent      = Color(0xFF00B0FF);
const _kSurface     = Color(0xFFF4F7FF);
const _kTextDark    = Color(0xFF0D1B3E);
const _kTextMid     = Color(0xFF4A5568);
const _kTextLight   = Color(0xFF90A4AE);

class AdminAttendanceApprovalPage extends StatefulWidget {
  const AdminAttendanceApprovalPage({super.key});

  @override
  State<AdminAttendanceApprovalPage> createState() => _AdminAttendanceApprovalPageState();
}

class _AdminAttendanceApprovalPageState extends State<AdminAttendanceApprovalPage> {
  bool loading = true;
  List<dynamic> attendanceList = [];

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    final cached = await CacheService.getList(CacheService.kAttendancePending);
    if (cached != null && mounted) setState(() { attendanceList = cached; loading = false; });
    try {
      final result = await ApiService.getPendingAttendanceList();
      if (!mounted) return;
      await CacheService.set(CacheService.kAttendancePending, result);
      setState(() { attendanceList = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (attendanceList.isEmpty) _showSnack("Gagal load pending absensi: $e", isError: true);
    }
  }

  String readValue(Map item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  Future<void> approveItem(Map<String, dynamic> item) async {
    try {
      final result = await ApiService.approvePendingAttendance(item["id"], userId: item["user_id"]);
      if (!mounted) return;
      _showSnack(result["message"] ?? "Absensi berhasil disetujui");
      await loadAttendance();
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal approve: $e", isError: true);
    }
  }

  Future<void> rejectItem(Map<String, dynamic> item) async {
    final reasonController = TextEditingController();

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RejectBottomSheet(controller: reasonController),
    );

    if (reason == null || !mounted) return;

    try {
      final result = await ApiService.rejectPendingAttendance(item["id"], reason: reason);
      if (!mounted) return;
      _showSnack(result["message"] ?? "Absensi berhasil ditolak");
      await loadAttendance();
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal reject: $e", isError: true);
    }
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
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: const Text("Persetujuan Absensi",
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
          : attendanceList.isEmpty
          ? _EmptyState(
        icon: Icons.fact_check_rounded,
        message: "Tidak ada absensi pending",
        subtitle: "Semua absensi sudah diproses",
      )
          : RefreshIndicator(
        color: _kPrimary,
        onRefresh: loadAttendance,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Summary badge
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFF6A1B9A), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "${attendanceList.length} absensi menunggu persetujuan",
                    style: const TextStyle(
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ]),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final item = attendanceList[index] as Map<String, dynamic>;
                    return _ApprovalCard(
                      item: item,
                      readValue: readValue,
                      onApprove: () => approveItem(item),
                      onReject: () => rejectItem(item),
                      onMap: openMap,
                    );
                  },
                  childCount: attendanceList.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Approval Card ───────────────────────────
class _ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(Map, List<String>) readValue;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final void Function(String) onMap;

  const _ApprovalCard({
    required this.item, required this.readValue,
    required this.onApprove, required this.onReject, required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final userName    = readValue(item, ["user_name", "name_input"]);
    final arrivalType = readValue(item, ["arrival_type"]);
    final note        = readValue(item, ["note"]);
    final workDate    = readValue(item, ["work_date"]);
    final createdAt   = readValue(item, ["created_at"]);
    final photoUrl    = readValue(item, ["photo_url"]);
    final mapUrl      = readValue(item, ["map_url"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimaryDark.withOpacity(0.05), _kPrimaryMid.withOpacity(0.02)],
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _kPrimary.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kPrimaryDark, _kPrimaryMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark)),
                    const SizedBox(height: 2),
                    Text("Dikirim: $createdAt", style: const TextStyle(fontSize: 11, color: _kTextLight)),
                  ]),
                ),
                _Badge("PENDING", const Color(0xFF6A1B9A)),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info chips row
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _InfoChip(Icons.fingerprint_rounded, arrivalType, _kPrimary),
                  _InfoChip(Icons.calendar_today_rounded, workDate, const Color(0xFF00838F)),
                ]),

                if (note != "-" && note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: _kTextMid),
                      const SizedBox(width: 8),
                      Expanded(child: Text(note, style: const TextStyle(fontSize: 12, color: _kTextMid, height: 1.4))),
                    ]),
                  ),
                ],

                if (photoUrl != "-" && photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120, color: const Color(0xFFF0F4FF),
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: _kTextLight, size: 32)),
                      ),
                    ),
                  ),
                ],

                if (mapUrl != "-" && mapUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => onMap(mapUrl),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kPrimary.withOpacity(0.15)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.location_on_rounded, color: _kPrimary, size: 16),
                        const SizedBox(width: 6),
                        const Text("Lihat Lokasi di Maps", style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onReject,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.close_rounded, color: Color(0xFFC62828), size: 18),
                          const SizedBox(width: 6),
                          const Text("Tolak", style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onApprove,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          const Text("Setujui", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
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
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Reject Bottom Sheet ─────────────────────
class _RejectBottomSheet extends StatelessWidget {
  final TextEditingController controller;
  const _RejectBottomSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Tolak Absensi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextDark)),
          ]),
          const SizedBox(height: 6),
          const Text("Masukkan alasan penolakan untuk karyawan", style: TextStyle(fontSize: 13, color: _kTextMid)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: _kTextDark),
            decoration: InputDecoration(
              hintText: "Contoh: Foto tidak jelas, lokasi tidak valid...",
              hintStyle: const TextStyle(color: _kTextLight, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF4F7FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kPrimary.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kPrimaryMid, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kPrimary.withOpacity(0.2)),
                  ),
                  child: const Center(child: Text("Batal", style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, controller.text),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Center(child: Text("Tolak", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message, subtitle;
  const _EmptyState({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 48, color: _kPrimary.withOpacity(0.3)),
      ),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTextDark)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 13, color: _kTextMid)),
    ]),
  );
}