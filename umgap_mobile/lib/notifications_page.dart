import 'package:flutter/material.dart';
import '../api_service.dart';
import 'u_kit.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool loading = true;
  List<dynamic> rows = [];
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final r = await ApiService.storage.read(key: 'role') ?? '';

    if (mounted) {
      setState(() => _role = r.trim().toLowerCase());
    }

    load();
  }

  bool get _isAdmin => _role == 'admin';
  bool get _isOwner => _role == 'owner';
  bool get _canPost => _isAdmin || _isOwner;

  Future<void> load() async {
    try {
      final result = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        rows = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await ApiService.markNotificationRead(id);
    } catch (_) {}
    load();
  }

  Future<void> _dismiss(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Notifikasi?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Pengumuman ini akan disembunyikan dari daftar kamu.\n'
              'Pengguna lain tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: UColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.dismissAnnouncement(id);
      if (!mounted) return;
      uSnack(context, 'Notifikasi dihapus');
      load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _adminDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus Pengumuman?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Pengumuman akan dihapus dan tidak terlihat semua karyawan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: UColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.deleteAnnouncement(id);
      if (!mounted) return;
      uSnack(context, 'Pengumuman dihapus');
      load();
    } catch (e) {
      if (mounted) uSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _showCreateSheet() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateSheet(
        titleCtrl: titleCtrl,
        bodyCtrl: bodyCtrl,
        onSend: (title, body) async {
          await ApiService.createAnnouncement(title: title, body: body);
          if (mounted) {
            uSnack(context, 'Pengumuman berhasil dikirim ✓');
            load();
          }
        },
      ),
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = rows.where((r) {
      final item = r as Map;
      return item['is_read'] == false || item['read_at'] == null;
    }).length;

    return Scaffold(
      backgroundColor: UColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                UColors.primaryDark,
                UColors.primary,
                UColors.primaryMid,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Pengumuman',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unread belum dibaca',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: UColors.primary,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'Tulis',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 4,
      )
          : null,
      body: loading
          ? const Center(
        child: CircularProgressIndicator(color: UColors.primary),
      )
          : rows.isEmpty
          ? RefreshIndicator(
        color: UColors.primary,
        onRefresh: load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            UEmptyState(
              icon: Icons.campaign_rounded,
              title: 'Tidak ada pengumuman',
              subtitle: 'Belum ada notifikasi baru',
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: UColors.primary,
        onRefresh: load,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final item = Map<String, dynamic>.from(rows[i]);
            final isRead =
                item['is_read'] == true || item['read_at'] != null;
            final id = item['id'] as int;

            return Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                if (_canPost) {
                  await _adminDelete(id);
                } else {
                  await _dismiss(id);
                }
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: UColors.danger,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              child: GestureDetector(
                onTap: isRead ? null : () => _markRead(id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isRead
                        ? null
                        : Border.all(
                      color:
                      UColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: UColors.primary.withOpacity(
                          isRead ? 0.04 : 0.10,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 90,
                          color: isRead
                              ? UColors.textLight
                              : UColors.primary,
                        ),
                        Container(
                          width: 56,
                          height: 90,
                          color: (isRead
                              ? UColors.textLight
                              : UColors.primary)
                              .withOpacity(0.07),
                          child: Center(
                            child: Icon(
                              Icons.campaign_rounded,
                              color: isRead
                                  ? UColors.textLight
                                  : UColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                            const EdgeInsets.fromLTRB(12, 12, 8, 12),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['title'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w800,
                                          color: UColors.textDark,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration:
                                        const BoxDecoration(
                                          color: UColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['message'] ?? item['body'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: UColors.textMid,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${item['created_at'] ?? item['created_at_wib'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: UColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              if (!_canPost && !isRead)
                                _ActionBtn(
                                  icon: Icons.check_rounded,
                                  color: UColors.success,
                                  tooltip: 'Tandai Dibaca',
                                  onTap: () => _markRead(id),
                                ),
                              if (!_canPost && !isRead)
                                const SizedBox(height: 6),
                              _ActionBtn(
                                icon: Icons.close_rounded,
                                color: UColors.danger,
                                tooltip:
                                _canPost ? 'Hapus Semua' : 'Hapus',
                                onTap: () => _canPost
                                    ? _adminDelete(id)
                                    : _dismiss(id),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    ),
  );
}

class _CreateSheet extends StatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final Future<void> Function(String, String) onSend;

  const _CreateSheet({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.onSend,
  });

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16, top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: UColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tulis Pengumuman',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: UColors.textDark,
                  ),
                ),
                Text(
                  'Notifikasi dikirim ke semua karyawan',
                  style: TextStyle(
                    fontSize: 11,
                    color: UColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        UField(
          controller: widget.titleCtrl,
          label: 'Judul *',
          hint: 'Contoh: Libur Lebaran 2026',
          prefixIcon: Icons.title_rounded,
        ),
        const SizedBox(height: 14),
        const Text(
          'Isi Pengumuman *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UColors.textMid,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.bodyCtrl,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Tulis pengumuman di sini...',
            hintStyle: const TextStyle(color: UColors.textLight),
            filled: true,
            fillColor: UColors.inputBg,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: UColors.primary.withOpacity(0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: UColors.primary.withOpacity(0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: UColors.primaryMid,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _sending
              ? null
              : () async {
            final title = widget.titleCtrl.text.trim();
            final body = widget.bodyCtrl.text.trim();

            if (title.isEmpty) {
              uSnack(context, 'Judul wajib diisi', isError: true);
              return;
            }

            if (body.isEmpty) {
              uSnack(context, 'Isi pengumuman wajib diisi',
                  isError: true);
              return;
            }

            setState(() => _sending = true);

            try {
              await widget.onSend(title, body);
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) {
                setState(() => _sending = false);
                uSnack(context, e.toString(), isError: true);
              }
            }
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: _sending
                  ? const LinearGradient(
                colors: [
                  Color(0xFFB0BEC5),
                  Color(0xFFCFD8DC),
                ],
              )
                  : const LinearGradient(
                colors: [
                  UColors.primaryDark,
                  UColors.primaryMid,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _sending
                  ? []
                  : [
                BoxShadow(
                  color: UColors.primary.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: _sending
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Kirim Pengumuman',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}