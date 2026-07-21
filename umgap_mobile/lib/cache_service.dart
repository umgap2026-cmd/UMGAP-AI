import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CacheService {
  static const _storage = FlutterSecureStorage();

  static const kDashboard          = 'cache_dashboard_v1';
  static const kOwnerStats         = 'cache_owner_stats_v1';
  static const kMaterials          = 'cache_materials_v1';
  static const kReportDaily        = 'cache_report_daily_v1';
  static const kTrips              = 'cache_trips_v1';
  static const kKasirSummary       = 'cache_kasir_summary_v1';
  static const kAttendanceHistory  = 'cache_attendance_history_v1';
  static const kAttendanceAdmin    = 'cache_attendance_admin_v1';
  static const kAttendancePending  = 'cache_attendance_pending_v1';
  static const kAttendanceMyAdmin  = 'cache_attendance_my_admin_v1';
  static const kProfile            = 'cache_profile_v1';
  static const kNotifications      = 'cache_notifications_v1';
  static const kPoints             = 'cache_points_v1';
  static const kUsers              = 'cache_users_v1';
  static const kBuyPrices          = 'cache_buy_prices_v1';

  static String kPayroll(String m)    => 'cache_payroll_${m}_v1';
  static String kPayslip(String w)    => 'cache_payslip_${w}_v1';
  static String kStats(String k)      => 'cache_stats_${k}_v1';
  static String kOwnerStatsM(String m)=> 'cache_ownerstats_${m}_v1';
  static String kTripDetail(int id)   => 'cache_trip_${id}_v1';
  static String kReportWeekly(String w)=> 'cache_reportweek_${w}_v1';

  static Future<Map<String, dynamic>?> get(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      final w = jsonDecode(raw) as Map<String, dynamic>;
      return w['data'] as Map<String, dynamic>?;
    } catch (_) { return null; }
  }

  static Future<List<dynamic>?> getList(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      final w = jsonDecode(raw) as Map<String, dynamic>;
      final d = w['data'];
      return d is List ? d : null;
    } catch (_) { return null; }
  }

  static Future<void> set(String key, dynamic data) async {
    try {
      await _storage.write(key: key, value: jsonEncode({
        'data':     data,
        'saved_at': DateTime.now().toIso8601String(),
      }));
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    try { await _storage.delete(key: key); } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      for (final key in [
        kDashboard, kOwnerStats, kMaterials, kReportDaily, kTrips,
        kKasirSummary, kAttendanceHistory, kAttendanceAdmin,
        kAttendancePending, kAttendanceMyAdmin, kProfile,
        kNotifications, kPoints, kUsers, kBuyPrices,
      ]) { await _storage.delete(key: key); }
    } catch (_) {}
  }
}