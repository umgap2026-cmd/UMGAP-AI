import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'u_kit.dart';
import 'cache_service.dart';
import 'finance_trip_detail_page.dart';

// ════════════════════════════════════════════
//  PERJALANAN JAKARTA — list semua trip
// ════════════════════════════════════════════
class FinanceTripPage extends StatefulWidget {
  const FinanceTripPage({super.key});
  @override State<FinanceTripPage> createState() => _FinanceTripPageState();
}

class _FinanceTripPageState extends State<FinanceTripPage> {
  bool  _loading = true;
  List<dynamic> _trips = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Cache dulu
    final cached = await CacheService.get(CacheService.kTrips);
    if (cached != null && mounted) {
      final trips = cached['trips'] ?? cached;
      setState(() {
        _trips   = trips is List ? List<dynamic>.from(trips) : [];
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }
    // Background refresh
    try {
      final res = await ApiService.financeGetTrips();
      if (!mounted) return;
      await CacheService.set(CacheService.kTrips, res);
      final trips = res['trips'] ?? [];
      setState(() {
        _trips   = trips is List ? List<dynamic>.from(trips) : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_trips.isEmpty) uSnack(context, 'Gagal memuat: $e', isError: true);
    }
  }

  Future<void> _newTrip() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Perjalanan Baru'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Buka catatan perjalanan Jakarta baru.',
              style: TextStyle(fontSize: 13, color: UColors.textSoft)),
          const SizedBox(height: USpace.base),
          TextField(controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Keterangan (opsional)',
                hintText: 'Contoh: Jakarta April Minggu 1',
                filled: true, fillColor: UColors.inputBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(URadius.md),
                    borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
              )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buka', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      HapticFeedback.mediumImpact();
      final res = await ApiService.financeTripNew(note: noteCtrl.text.trim());
      if (!mounted) return;
      final tripId = int.tryParse('${res['id']}') ?? 0;
      await Navigator.push(context,
          uRoute(FinanceTripDetailPage(tripId: tripId)));
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
    noteCtrl.dispose();
  }

  Future<void> _showTripOptions(Map<String, dynamic> t, int tripId) async {
    final isOpen = '${t['status']}' == 'OPEN';
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: UColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${t['note'] ?? 'Perjalanan #$tripId'}',
                style: UText.h5),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded, color: UColors.primary),
            title: const Text('Buka Detail'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  uRoute(FinanceTripDetailPage(tripId: tripId)))
                  .then((_) => _load());
            },
          ),
          if (isOpen) ListTile(
            leading: const Icon(Icons.cancel_outlined, color: UColors.warning),
            title: const Text('Batalkan Perjalanan'),
            onTap: () async {
              Navigator.pop(context);
              await _cancelTrip(tripId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: UColors.danger),
            title: const Text('Hapus Perjalanan',
                style: TextStyle(color: UColors.danger)),
            onTap: () async {
              Navigator.pop(context);
              await _deleteTrip(tripId, t['note'] ?? 'Perjalanan #$tripId');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _cancelTrip(int tripId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Batalkan Perjalanan?'),
        content: const Text('Status akan diubah menjadi CANCELLED.\nSemua transaksi tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.warning,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeTripCancel(tripId: tripId);
      uSnack(context, 'Perjalanan dibatalkan');
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _deleteTrip(int tripId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.xl)),
        title: const Text('Hapus Perjalanan?'),
        content: Text('Hapus "$name"?\nSemua data transaksi dalam perjalanan ini akan ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: UColors.danger,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService.financeTripDelete(tripId: tripId);
      uSnack(context, 'Perjalanan dihapus');
      _load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UColors.surface,
      body: Column(children: [
        UHeader(child: Padding(
          padding: const EdgeInsets.fromLTRB(
              USpace.sm, USpace.sm, USpace.base, USpace.xl),
          child: Row(children: [
            UBackButton(), const SizedBox(width: USpace.md),
            const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Perjalanan Jakarta', style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Catat jual, beli & biaya perjalanan',
                  style: TextStyle(color: Colors.white54,
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
            UHeaderIconBtn(icon: Icons.add_rounded, onTap: _newTrip),
          ]),
        )),

        if (_loading) const Expanded(child: Center(
            child: CircularProgressIndicator(color: UColors.primary)))
        else Expanded(child: RefreshIndicator(
          color: UColors.primary, onRefresh: _load,
          child: _trips.isEmpty
              ? ListView(children: [
            const SizedBox(height: 60),
            UEmptyState(
              icon: Icons.local_shipping_rounded,
              title: 'Belum ada perjalanan',
              subtitle: 'Tap + untuk buka perjalanan baru',
              action: UButton(
                label: 'Buka Perjalanan Baru',
                onPressed: _newTrip,
                icon: Icons.add_rounded,
              ),
            ),
          ])
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                USpace.base, USpace.base, USpace.base, 40),
            itemCount: _trips.length + 1,
            itemBuilder: (_, i) {
              if (i == _trips.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: USpace.sm),
                  child: Center(child: Text(
                    'Tekan lama untuk batal/hapus perjalanan',
                    style: UText.caption.copyWith(color: UColors.textLight),
                  )),
                );
              }
              final t      = _trips[i] as Map<String, dynamic>;
              final isOpen = '${t['status']}' == 'OPEN';
              final net    = (double.tryParse('${t['net_result'] ?? 0}') ?? 0).toInt();
              final income = (double.tryParse('${t['total_income'] ?? 0}') ?? 0).toInt();
              final tripId = int.tryParse('${t['id']}') ?? 0;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context,
                      uRoute(FinanceTripDetailPage(tripId: tripId)))
                      .then((_) => _load());
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showTripOptions(t, tripId);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: USpace.md),
                  decoration: BoxDecoration(
                    color: UColors.card,
                    borderRadius: BorderRadius.circular(URadius.lg),
                    boxShadow: UShadow.card,
                    border: Border.all(color: isOpen
                        ? UColors.primary.withOpacity(0.25)
                        : UColors.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(URadius.lg),
                    child: Row(children: [
                      // Accent bar
                      Container(width: 5,
                          color: isOpen ? UColors.primary : UColors.textLight),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(USpace.base),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(
                                  '${t['note'] ?? 'Perjalanan #$tripId'}',
                                  style: UText.h5)),
                              UBadge(isOpen ? 'BERLANGSUNG' : 'SELESAI'),
                            ]),
                            const SizedBox(height: 4),
                            Text('${t['trip_date'] ?? '-'}',
                                style: UText.caption),
                            if (!isOpen) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                _TripStat('Pemasukan', uRupiah(income), UColors.success),
                                const SizedBox(width: USpace.lg),
                                _TripStat('Hasil Bersih', uRupiah(net),
                                    net >= 0 ? UColors.success : UColors.danger),
                              ]),
                            ],
                          ]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(USpace.base),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: UColors.textSoft),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        )),
      ]),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTrip,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Perjalanan Baru',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final String label, value; final Color color;
  const _TripStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: UText.caption),
    Text(value, style: UText.bodyS.copyWith(
        color: color, fontWeight: FontWeight.w800)),
  ]);
}