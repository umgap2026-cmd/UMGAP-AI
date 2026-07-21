import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});
  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, dynamic> data = {};
  late TabController _tab;
  final _rankKey = GlobalKey();
  bool _sharing  = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> load() async {
    final cached = await CacheService.get(CacheService.kPoints);
    if (cached != null && mounted) setState(() { data = cached; loading = false; });
    try {
      final result = await ApiService.getPoints();
      if (!mounted) return;
      await CacheService.set(CacheService.kPoints, result);
      setState(() { data = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (data.isEmpty) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> addPoint(int userId, String userName) async {
    final delta = TextEditingController(text: '1');
    final note  = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: UColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.star_rounded, color: UColors.warning, size: 22)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tambah Poin', style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: UColors.textDark)),
                    Text(userName, style: const TextStyle(fontSize: 12, color: UColors.textMid)),
                  ]),
                ]),
                const SizedBox(height: 18),
                UField(controller: delta, label: 'Delta Poin',
                    prefixIcon: Icons.add_circle_outline_rounded,
                    keyboard: TextInputType.number),
                const SizedBox(height: 12),
                UField(controller: note, label: 'Catatan',
                    prefixIcon: Icons.note_alt_outlined, maxLines: 2),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: UButton(label: 'Batal', outlined: true,
                      onPressed: () => Navigator.pop(context, false))),
                  const SizedBox(width: 12),
                  Expanded(child: UButton(label: 'Simpan',
                      onPressed: () => Navigator.pop(context, true),
                      color: UColors.warning)),
                ]),
              ]),
        ),
      ),
    );
    if (ok != true) return;
    await ApiService.addPoints(userId: userId,
        delta: int.tryParse(delta.text) ?? 0, note: note.text);
    await load();
    if (mounted) uSnack(context, 'Poin berhasil ditambahkan');
  }

  Future<void> _shareRanking() async {
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _rankKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image   = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/umgap_ranking.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Top 5 Poin Karyawan UMGAP',
        text: '🏆 Leaderboard Poin UMGAP!',
      );
    } catch (e) {
      if (mounted) uSnack(context, 'Gagal share: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = List<dynamic>.from(data['employees'] ?? []);
    final logs      = List<dynamic>.from(data['logs'] ?? []);
    final sorted    = [...employees]
      ..sort((a,b) => (b['points_admin'] as num? ?? 0)
          .compareTo(a['points_admin'] as num? ?? 0));
    final top5 = sorted.take(5).toList();

    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [UColors.primaryDark, UColors.primary, UColors.primaryMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Poin Karyawan',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 18))),

                ])),
            TabBar(controller: _tab, indicatorColor: Colors.white,
                indicatorWeight: 3, labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [Tab(text: ' Ranking'),
                  Tab(text: 'Karyawan'), Tab(text: 'Log Poin')]),
          ])),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: UColors.primary))
          : TabBarView(controller: _tab, children: [

        // ════ TAB 1: RANKING ════
        RefreshIndicator(color: UColors.primary, onRefresh: load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [
              RepaintBoundary(
                  key: _rankKey,
                  child: _RankingCard(topList: top5)),
              const SizedBox(height: 16),
              // Share button
              GestureDetector(
                onTap: _sharing ? null : _shareRanking,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE65100), UColors.warning]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: UColors.warning.withOpacity(0.35),
                          blurRadius: 14, offset: const Offset(0, 5))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sharing)
                          const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                        else ...[
                          const Icon(Icons.download_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text('Download & Share Ranking',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ]),
                ),
              ),
              if (sorted.length > 5) ...[
                const SizedBox(height: 24),
                _Divider('Semua Karyawan'),
                const SizedBox(height: 12),
                ...sorted.asMap().entries.map((e) => _RankRow(
                    item: Map<String, dynamic>.from(e.value),
                    rank: e.key + 1)),
              ],
            ]),
          ),
        ),

        // ════ TAB 2: KARYAWAN ════
        RefreshIndicator(color: UColors.primary, onRefresh: load,
            child: employees.isEmpty
                ? const UEmptyState(icon: Icons.people_rounded,
                title: 'Tidak ada karyawan')
                : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: employees.length,
                itemBuilder: (_, i) {
                  final item = Map<String, dynamic>.from(employees[i]);
                  // Ambil id dengan aman — bisa int atau String
                  final rawId  = item['id'];
                  final userId = rawId is int ? rawId
                      : int.tryParse('$rawId') ?? 0;
                  final name   = '${item['name'] ?? ''}';
                  if (userId == 0) return const SizedBox.shrink();
                  return _EmpCard(
                      item: item,
                      rank: sorted.indexWhere((e) =>
                      (e['id'] is int ? e['id'] : int.tryParse('${e['id']}') ?? -1)
                          == userId) + 1,
                      onAdd: () => addPoint(userId, name));
                })),

        // ════ TAB 3: LOG POIN ════
        RefreshIndicator(color: UColors.primary, onRefresh: load,
            child: logs.isEmpty
                ? const UEmptyState(icon: Icons.history_rounded,
                title: 'Tidak ada log poin')
                : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final item = Map<String, dynamic>.from(logs[i]);
                  final delta = int.tryParse('${item['delta']}') ?? 0;
                  final isPos = delta >= 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: UColors.primary.withOpacity(0.06),
                            blurRadius: 12, offset: const Offset(0, 3))]),
                    child: Padding(padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: (isPos ? UColors.success : UColors.danger)
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: Icon(
                                  isPos ? Icons.add_rounded : Icons.remove_rounded,
                                  color: isPos ? UColors.success : UColors.danger,
                                  size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['user_name']}', style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: UColors.textDark)),
                                Text('${item['note'] ?? ''} • ${item['admin_name']}',
                                    style: const TextStyle(fontSize: 11,
                                        color: UColors.textMid)),
                                Text('${item['created_at']}', style: const TextStyle(
                                    fontSize: 10, color: UColors.textLight)),
                              ])),
                          Text('${isPos ? '+' : ''}$delta',
                              style: TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isPos ? UColors.success : UColors.danger)),
                        ])),
                  );
                })),
      ]),
    );
  }
}


// ════════════════════════════════════════════
//  RANKING CARD — yang di-capture jadi PNG
// ════════════════════════════════════════════
class _RankingCard extends StatelessWidget {
  final List<dynamic> topList;
  const _RankingCard({required this.topList});

  static const _medals  = ['🥇','🥈','🥉','4️⃣','5️⃣'];
  static const _colors  = [
    Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32),
    Color(0xFF78909C), Color(0xFF90A4AE),
  ];
  static const _bgColors = [
    Color(0xFFFFFDE7), Color(0xFFF5F5F5), Color(0xFFFFF3E0),
    Color(0xFFF5F5F5), Color(0xFFF5F5F5),
  ];

  String _month() {
    final n = DateTime.now();
    const m = ['','Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'];
    return '${m[n.month]} ${n.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B1733), Color(0xFF1565C0)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              blurRadius: 24, offset: const Offset(0, 8))]),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🏆', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Top 5 Poin Karyawan',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text('UMGAP • ${_month()}',
                style: TextStyle(color: Colors.white.withOpacity(0.5),
                    fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 16),

        if (topList.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('Belum ada data poin',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))))
        else
          ...topList.asMap().entries.map((e) {
            final i    = e.key;
            final item = Map<String, dynamic>.from(e.value);
            final name = '${item['name'] ?? '?'}';
            final pts  = (item['points_admin'] as num?)?.toInt() ?? 0;
            final top  = i == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: top ? 14 : 10),
              decoration: BoxDecoration(
                  color: _bgColors[i],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _colors[i].withOpacity(0.4), width: top ? 2 : 1),
                  boxShadow: top ? [BoxShadow(
                      color: _colors[i].withOpacity(0.25),
                      blurRadius: 12, offset: const Offset(0,4))] : []),
              child: Row(children: [
                SizedBox(width: 36,
                    child: Text(_medals[i],
                        style: TextStyle(fontSize: top ? 24 : 20),
                        textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                Container(
                    width: top ? 40 : 34, height: top ? 40 : 34,
                    decoration: BoxDecoration(
                        color: _colors[i].withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: _colors[i].withOpacity(0.5),
                            width: 1.5)),
                    child: Center(child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: _colors[i],
                            fontWeight: FontWeight.w800,
                            fontSize: top ? 16 : 13)))),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: TextStyle(
                    fontSize: top ? 15 : 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E)))),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _colors[i].withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, color: _colors[i],
                          size: top ? 16 : 13),
                      const SizedBox(width: 3),
                      Text('$pts', style: TextStyle(color: _colors[i],
                          fontWeight: FontWeight.w800,
                          fontSize: top ? 16 : 13)),
                    ])),
              ]),
            );
          }),

        const SizedBox(height: 8),
        Text('UMGAP • Manajemen Karyawan Modern',
            style: TextStyle(color: Colors.white.withOpacity(0.3),
                fontSize: 10)),
      ]),
    );
  }
}


// ════════════════════════════════════════════
//  SUB-WIDGETS
// ════════════════════════════════════════════
class _RankRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  const _RankRow({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final name = '${item['name'] ?? '?'}';
    final pts  = (item['points_admin'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: UColors.primary.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0,2))]),
      child: Row(children: [
        SizedBox(width: 30, child: Text('#$rank', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800,
            color: rank <= 3 ? UColors.warning : UColors.textMid))),
        Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: UColors.warning.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Center(child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: UColors.warning,
                    fontWeight: FontWeight.w800, fontSize: 13)))),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: UColors.textDark))),
        Row(children: [
          const Icon(Icons.star_rounded, color: UColors.warning, size: 13),
          const SizedBox(width: 3),
          Text('$pts', style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: UColors.warning)),
        ]),

      ]),
    );
  }
}

class _EmpCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int rank;
  final VoidCallback onAdd;
  const _EmpCard({required this.item, required this.rank, required this.onAdd});

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return UColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final name = '${item['name'] ?? '?'}';
    final pts  = (item['points_admin'] as num?)?.toInt() ?? 0;
    final medal = _medals[rank];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: rank <= 3 ? Border.all(
              color: _rankColor.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(
              color: (rank <= 3 ? _rankColor : UColors.primary).withOpacity(0.08),
              blurRadius: 14, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Rank / Medal
          SizedBox(
              width: 36,
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 22),
                  textAlign: TextAlign.center)
                  : Text('#$rank', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: UColors.textMid),
                  textAlign: TextAlign.center)),

          // Avatar
          Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _rankColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _rankColor.withOpacity(0.3), width: 1.5)),
              child: Center(child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: _rankColor,
                      fontWeight: FontWeight.w800, fontSize: 15)))),
          const SizedBox(width: 12),

          // Name + poin
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: UColors.textDark)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.star_rounded, color: _rankColor, size: 13),
              const SizedBox(width: 3),
              Text('$pts poin', style: TextStyle(
                  fontSize: 12, color: _rankColor,
                  fontWeight: FontWeight.w700)),
            ]),
          ])),

          // Tambah poin button
          GestureDetector(
            onTap: onAdd,
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), UColors.warning]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: UColors.warning.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Poin', style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 12)),
                ])),
          ),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider(this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: Colors.grey.shade200)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: TextStyle(fontSize: 12,
            color: Colors.grey.shade400, fontWeight: FontWeight.w600))),
    Expanded(child: Divider(color: Colors.grey.shade200)),
  ]);
}