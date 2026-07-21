import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';

// ════════════════════════════════════════════
//  UpdateService
//  Cek versi dari backend → tampilkan dialog
//  → download APK → install otomatis
//
//  CARA PAKAI di home_page.dart initState:
//  WidgetsBinding.instance.addPostFrameCallback((_) {
//    UpdateService.check(context);
//  });
// ════════════════════════════════════════════

class UpdateService {
  static const _baseUrl = 'https://umgap-ai.onrender.com';
  static const _versionEndpoint = '$_baseUrl/api/mobile/version';

  // ── Cek update ───────────────────────────────
  static Future<void> check(BuildContext context) async {
    try {
      // Versi app saat ini
      final info    = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.1.0"

      // Cek ke server
      final res = await http.get(Uri.parse(_versionEndpoint))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;

      final data          = jsonDecode(res.body) as Map<String, dynamic>;
      final latestVersion = (data['latest_version'] ?? '').toString();
      final minVersion    = (data['min_version']    ?? '').toString();
      final forceUpdate   = data['force_update']    == true;
      final updateUrl     = (data['update_url']     ?? '').toString();
      final message       = (data['message']        ?? '').toString();

      if (latestVersion.isEmpty || updateUrl.isEmpty) return;

      // Bandingkan versi
      final isOutdated       = _isOlderThan(current, latestVersion);
      final belowMin         = _isOlderThan(current, minVersion);
      final mustForce        = forceUpdate || belowMin;

      if (!isOutdated) return; // sudah terbaru

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: !mustForce,
        builder: (_) => _UpdateDialog(
          currentVersion: current,
          latestVersion:  latestVersion,
          message:        message,
          updateUrl:      updateUrl,
          forceUpdate:    mustForce,
        ),
      );
    } catch (_) {
      // Gagal cek — diam saja, tidak ganggu user
    }
  }

  // ── Bandingkan versi semver ─────────────────
  /// Return true jika [current] lebih tua dari [latest]
  static bool _isOlderThan(String current, String latest) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final l = latest.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final lv = i < l.length ? l[i] : 0;
        if (cv < lv) return true;
        if (cv > lv) return false;
      }
      return false; // sama
    } catch (_) { return false; }
  }

  // ── Download APK & install ──────────────────
  static Future<void> downloadAndInstall({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String error) onError,
  }) async {
    try {
      // Minta izin install APK dari sumber tidak dikenal
      final installPerm = await Permission.requestInstallPackages.status;
      if (!installPerm.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          onError('Izin install aplikasi ditolak.\n'
              'Aktifkan di Pengaturan → Keamanan → '
              'Izin install sumber tidak dikenal.');
          return;
        }
      }

      // Folder temp untuk simpan APK
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/umgap_update.apk');

      // Hapus APK lama jika ada
      if (await file.exists()) await file.delete();

      // Download dengan progress
      final request  = http.Request('GET', Uri.parse(url));
      final response = await request.send()
          .timeout(const Duration(minutes: 5));

      final total    = response.contentLength ?? 0;
      int   received = 0;
      final sink     = file.openWrite();

      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress(received / total);
        return chunk;
      }).pipe(sink);

      await sink.flush();
      await sink.close();

      // Buka installer Android
      final result = await OpenFile.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        onError('Gagal buka installer: ${result.message}');
      }
    } on SocketException {
      onError('Tidak ada koneksi internet. Coba lagi.');
    } on TimeoutException {
      onError('Download timeout. Periksa koneksi internet.');
    } catch (e) {
      onError('Gagal download: $e');
    }
  }
}

// ════════════════════════════════════════════
//  Dialog Update
// ════════════════════════════════════════════
class _UpdateDialog extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String message;
  final String updateUrl;
  final bool   forceUpdate;

  const _UpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
    required this.message,
    required this.updateUrl,
    required this.forceUpdate,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool   _downloading = false;
  double _progress    = 0;
  String _errorMsg    = '';

  static const _kPrimary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Kalau force update, tombol back HP tidak bisa dismiss
      canPop: !widget.forceUpdate && !_downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded,
                color: _kPrimary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Tersedia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('v${widget.currentVersion} → v${widget.latestVersion}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF90A4AE),
                      fontWeight: FontWeight.w500)),
            ],
          )),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),

          // Changelog / message
          if (widget.message.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kPrimary.withOpacity(0.12)),
              ),
              child: Text(widget.message,
                  style: const TextStyle(
                      fontSize: 12, height: 1.6,
                      color: Color(0xFF334155))),
            ),

          // Force update warning
          if (widget.forceUpdate) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE65100).withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Update wajib — aplikasi tidak bisa digunakan sebelum update.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 16),

          // Progress bar
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE3EAFF),
                valueColor: const AlwaysStoppedAnimation(_kPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.download_rounded,
                  color: _kPrimary, size: 14),
              const SizedBox(width: 5),
              Text(
                _progress >= 1
                    ? 'Membuka installer...'
                    : 'Mengunduh... ${(_progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 11, color: _kPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 12),
          ],

          // Error message
          if (_errorMsg.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFC62828), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFC62828)))),
                  ]),
            ),
            const SizedBox(height: 12),
          ],
        ]),

        actions: _downloading
            ? const []  // sembunyikan tombol saat download
            : [
          if (!widget.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Nanti',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
            onPressed: _startDownload,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.download_rounded,
                  color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('Update Sekarang',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _errorMsg = ''; _progress = 0; });

    await UpdateService.downloadAndInstall(
      url: widget.updateUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onError: (err) {
        if (mounted) setState(() { _downloading = false; _errorMsg = err; });
      },
    );

    // Jika berhasil (installer terbuka), biarkan user di dialog
    // sampai mereka selesai install — dialog tidak di-pop otomatis
  }
}