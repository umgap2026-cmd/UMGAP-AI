import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'u_kit.dart';

// Cek versi + dialog download&install APK di dalam app -- dipakai dari
// splash (otomatis tiap buka app) MAUPUN dipanggil manual (mis. tombol
// "Update Sekarang" di detail pengumuman "Update Aplikasi Tersedia"),
// supaya user tidak cuma baca teks tapi bisa langsung update dari situ.
class UpdateService {
  UpdateService._();

  /// Bandingkan 2 versi "major.minor.patch" scr numerik (bukan string
  /// exact-match) -- exact-match rentan false-positive kalau device
  /// melaporkan versi dgn format sedikit beda (spasi, jumlah segmen,
  /// dll), yg bikin popup update muncul terus walau app sudah versi
  /// terbaru. Return >0 kalau [a] lebih baru dari [b].
  static int _versionCompare(String a, String b) {
    final pa = a.trim().split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final pb = b.trim().split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  /// Return true kalau ada update WAJIB (force_update) yang barusan
  /// ditampilkan -- splash pakai ini utk tahu apa boleh lanjut navigasi.
  static Future<bool> checkAndPrompt(BuildContext context,
      {bool silent = false}) async {
    try {
      final packageInfo    = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final data           = await ApiService.checkVersion();
      final forceUpdate    = data['force_update'] == true;
      final latestVersion  = data['latest_version'] ?? currentVersion;
      final updateUrl      = data['update_url'] ?? '';
      final message        = data['message'] ?? 'Silakan update aplikasi.';

      if (_versionCompare(latestVersion, currentVersion) > 0) {
        if (!context.mounted) return forceUpdate;
        await showUpdateDialog(context,
            message: message, updateUrl: updateUrl, force: forceUpdate);
        return forceUpdate;
      } else if (!silent && context.mounted) {
        uSnack(context, '✓ Aplikasi sudah versi terbaru');
      }
    } catch (e) {
      if (!silent && context.mounted) {
        uSnack(context, 'Gagal cek update: $e', isError: true);
      }
    }
    return false;
  }

  static Future<void> showUpdateDialog(
    BuildContext context, {
    required String message,
    required String updateUrl,
    required bool force,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(
        message: message, updateUrl: updateUrl, force: force,
      ),
    );
  }
}

// StatefulWidget SUNGGUHAN (bukan StatefulBuilder dgn var lokal di dalam
// builder) -- var lokal di dalam builder StatefulBuilder ke-RESET tiap
// kali setState dipanggil (builder-nya dieksekusi ulang dari awal), jadi
// tombol "Update Sekarang" kelihatan tidak merespon sama sekali walau
// proses download-nya sbnrnya jalan di background. State di sini pakai
// field State yg beneran persisten antar rebuild.
class _UpdateDialog extends StatefulWidget {
  final String message;
  final String updateUrl;
  final bool force;

  const _UpdateDialog({
    required this.message,
    required this.updateUrl,
    required this.force,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _doUpdate() async {
    if (widget.updateUrl.isEmpty) {
      setState(() => _error = 'Link update belum tersedia.');
      return;
    }

    // Install APK dari dalam app butuh izin khusus Android "Izinkan dari
    // sumber ini" -- kalau belum aktif, OpenFile.open() nanti gagal diam2
    // dgn error permission_denied. Minta izinnya DULU (buka halaman
    // Pengaturan otomatis); baru lanjut download setelah user kembali &
    // izinnya aktif.
    if (Platform.isAndroid) {
      var installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        setState(() {
          _error = 'Mengarahkan ke Pengaturan -- aktifkan "Izinkan dari '
              'sumber ini" utk lanjut update.';
        });
        installStatus = await Permission.requestInstallPackages.request();
        if (!mounted) return;
        if (!installStatus.isGranted) {
          setState(() {
            _error = 'Izin install APK belum diaktifkan. Tap "Update '
                'Sekarang" lagi setelah mengizinkannya.';
          });
          return;
        }
      }
    }

    setState(() { _downloading = true; _error = null; _progress = null; });
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/umgap-update.apk';
      await Dio().download(
        widget.updateUrl,
        savePath,
        onReceiveProgress: (recv, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = recv / total);
          }
        },
      );
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done) {
        throw result.message.isNotEmpty
            ? result.message
            : 'Gagal membuka installer.';
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _downloading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.force,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Color(0xFF1565C0), size: 40),
            ),
            const SizedBox(height: 16),
            Text(widget.force ? 'Update Diperlukan' : 'Update Tersedia',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF4A5568))),
            if (_downloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: _progress, minHeight: 8),
              ),
              const SizedBox(height: 6),
              Text(
                _progress != null
                    ? 'Mengunduh... ${(_progress! * 100).toStringAsFixed(0)}%'
                    : 'Mengunduh...',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF90A4AE)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFC62828))),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!widget.force && !_downloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 12),
            ),
            onPressed: _downloading ? null : _doUpdate,
            child: _downloading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Update Sekarang',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
