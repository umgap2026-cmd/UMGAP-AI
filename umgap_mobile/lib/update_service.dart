import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import 'u_kit.dart';

// Cek versi + dialog download&install APK di dalam app -- dipakai dari
// splash (otomatis tiap buka app) MAUPUN dipanggil manual (mis. tombol
// "Update Sekarang" di detail pengumuman "Update Aplikasi Tersedia"),
// supaya user tidak cuma baca teks tapi bisa langsung update dari situ.
class UpdateService {
  UpdateService._();

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

      if (currentVersion != latestVersion) {
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
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          bool downloading = false;
          double? progress;
          String? error;

          Future<void> doUpdate() async {
            if (updateUrl.isEmpty) {
              setDialogState(() => error = 'Link update belum tersedia.');
              return;
            }
            setDialogState(() { downloading = true; error = null; progress = null; });
            try {
              final dir = await getTemporaryDirectory();
              final savePath = '${dir.path}/umgap-update.apk';
              await Dio().download(
                updateUrl,
                savePath,
                onReceiveProgress: (recv, total) {
                  if (total > 0) {
                    setDialogState(() => progress = recv / total);
                  }
                },
              );
              final result = await OpenFile.open(savePath);
              if (result.type != ResultType.done) {
                throw result.message.isNotEmpty
                    ? result.message
                    : 'Gagal membuka installer.';
              }
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            } catch (e) {
              setDialogState(() { downloading = false; error = '$e'; });
            }
          }

          return PopScope(
            canPop: !force,
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
                  Text(force ? 'Update Diperlukan' : 'Update Tersedia',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4A5568))),
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: progress, minHeight: 8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress != null
                          ? 'Mengunduh... ${(progress! * 100).toStringAsFixed(0)}%'
                          : 'Mengunduh...',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF90A4AE)),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFC62828))),
                  ],
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                if (!force && !downloading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
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
                  onPressed: downloading ? null : doUpdate,
                  child: downloading
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
        },
      ),
    );
  }
}
