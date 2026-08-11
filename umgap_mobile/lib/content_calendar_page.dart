import 'package:flutter/material.dart';
import 'api_service.dart';
import 'u_kit.dart';

// ════════════════════════════════════════════
//  KALENDER KONTEN — daftar rencana posting +
//  tandai selesai, mirror /content di web
//  (templates/content.html) -- gaya list, BUKAN
//  grid kalender visual, sesuai tampilan web.
// ════════════════════════════════════════════
class ContentCalendarPage extends StatefulWidget {
  const ContentCalendarPage({super.key});
  @override
  State<ContentCalendarPage> createState() => _ContentCalendarPageState();
}

class _ContentCalendarPageState extends State<ContentCalendarPage> {
  bool _loading = true;
  List<dynamic> _plans = [];

  static const _platforms = ['WhatsApp', 'Instagram', 'TikTok', 'Facebook'];
  static const _platformIcons = {
    'WhatsApp': '💬', 'Instagram': '📸', 'TikTok': '🎵', 'Facebook': '📘',
  };
  static const _types = ['Promo', 'Edukasi', 'Produk Baru', 'Testimoni', 'Reminder'];
  static const _typeIcons = {
    'Promo': '🔥', 'Edukasi': '📚', 'Produk Baru': '✨',
    'Testimoni': '⭐', 'Reminder': '🔔',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.contentPlansList();
      if (!mounted) return;
      setState(() { _plans = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _openAddSheet() async {
    DateTime date = DateTime.now();
    String platform = _platforms[0];
    String type = _types[0];
    final notesCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
              const Text('📆 Tambah ke Kalender', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const Text('Tanggal', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: UColors.textMid)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100),
                  );
                  if (picked != null) setS(() => date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: UColors.inputBg,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: UColors.primary),
                    const SizedBox(width: 10),
                    Text('${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/${date.year}'),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Platform', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: UColors.textMid)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _platforms.map((p) =>
                  _Chip(label: '${_platformIcons[p]} $p', active: platform == p,
                      onTap: () => setS(() => platform = p))).toList()),
              const SizedBox(height: 14),
              const Text('Jenis Konten', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: UColors.textMid)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) =>
                  _Chip(label: '${_typeIcons[t]} $t', active: type == t,
                      onTap: () => setS(() => type = t))).toList()),
              const SizedBox(height: 14),
              UField(controller: notesCtrl, label: 'Catatan (opsional)',
                  hint: 'Ide konten, caption draft, dll', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    setS(() => saving = true);
                    try {
                      final iso = '${date.year.toString().padLeft(4, '0')}-'
                          '${date.month.toString().padLeft(2, '0')}-'
                          '${date.day.toString().padLeft(2, '0')}';
                      await ApiService.contentPlanAdd(
                        planDate: iso, platform: platform, contentType: type,
                        notes: notesCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        uSnack(context, 'Rencana konten ditambahkan ✓');
                        _load();
                      }
                    } catch (e) {
                      if (mounted) uSnack(context, e.toString(), isError: true);
                      setS(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Tambah ke Kalender', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _toggleDone(Map plan) async {
    final id = int.tryParse('${plan['id']}') ?? 0;
    final isDone = plan['is_done'] == true;
    try {
      if (isDone) {
        await ApiService.contentPlanUndo(id);
      } else {
        await ApiService.contentPlanDone(id);
      }
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _delete(Map plan) async {
    final id = int.tryParse('${plan['id']}') ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus rencana ini?'),
        content: Text('${plan['content_type']} — ${plan['platform']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.contentPlanDelete(id);
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: UAppBar(title: '📆 Kalender Konten', actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : RefreshIndicator(
              color: UColors.primary,
              onRefresh: _load,
              child: _plans.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      UEmptyState(icon: Icons.event_note_rounded,
                          title: 'Belum ada rencana konten',
                          subtitle: 'Tekan + untuk menambah'),
                    ])
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _plans.length,
                      itemBuilder: (_, i) {
                        final p = Map<String, dynamic>.from(_plans[i]);
                        final isDone = p['is_done'] == true;
                        final platform = '${p['platform'] ?? ''}';
                        final type = '${p['content_type'] ?? ''}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: UColors.primary.withOpacity(0.06),
                                blurRadius: 12, offset: const Offset(0, 3))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(type.isEmpty ? 'Konten' : type,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                      color: UColors.textDark,
                                      decoration: isDone ? TextDecoration.lineThrough : null))),
                              if (isDone) Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: UColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('✓ Selesai', style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800, color: UColors.success)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              _MiniBadge('${_platformIcons[platform] ?? '📣'} $platform'),
                              _MiniBadge('${p['plan_date'] ?? ''}'),
                            ]),
                            if ('${p['notes'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${p['notes']}', style: const TextStyle(
                                  fontSize: 12, color: UColors.textMid)),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(
                                onPressed: () => _toggleDone(p),
                                style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: UColors.primary.withOpacity(0.3)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10))),
                                icon: Icon(isDone ? Icons.replay_rounded : Icons.check_rounded,
                                    size: 16, color: UColors.primary),
                                label: Text(isDone ? 'Batal Selesai' : 'Tandai Selesai',
                                    style: const TextStyle(fontSize: 12, color: UColors.primary)),
                              )),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _delete(p),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: UColors.danger.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.delete_outline_rounded,
                                      size: 16, color: UColors.danger),
                                ),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? UColors.primary : UColors.inputBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? UColors.primary : UColors.primary.withOpacity(0.15)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: active ? Colors.white : UColors.textMid)),
    ),
  );
}

class _MiniBadge extends StatelessWidget {
  final String label;
  const _MiniBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: UColors.inputBg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 10.5, color: UColors.textMid,
        fontWeight: FontWeight.w600)),
  );
}
