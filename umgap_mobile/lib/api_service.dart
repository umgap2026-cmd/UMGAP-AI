import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

class ApiService {
  static const String baseUrl = "https://umgap-ai.onrender.com";
  static const FlutterSecureStorage storage = FlutterSecureStorage();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        "Accept": "application/json",
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  static Future<String?> getToken() async {
    return await storage.read(key: "token");
  }

  static Future<Map<String, String>> _headers() async {
    final token = await storage.read(key: "token");
    return {
      "Authorization": "Bearer $token",
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  static String _message(dynamic resData, [String fallback = "Terjadi kesalahan"]) {
    final map = _asMap(resData);
    return (map["message"] ?? fallback).toString();
  }

  static void _ensureOk(Response res, [String fallback = "Request gagal"]) {
    final body = _asMap(res.data);
    if (res.statusCode == 401) {
      throw "Session habis, silakan login lagi";
    }
    if (body["ok"] != true) {
      throw _message(body, fallback);
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await dio.post(
      "/api/mobile/login",
      data: {
        "email": email,
        "password": password,
      },
    );

    _ensureOk(res, "Login gagal");

    final body = _asMap(res.data);
    final data = _asMap(body["data"]);

    await storage.write(key: "token", value: (data["token"] ?? "").toString());
    await storage.write(key: "role", value: _asMap(data["user"])["role"]?.toString() ?? "");
    await storage.write(key: "name", value: _asMap(data["user"])["name"]?.toString() ?? "");

    return data;
  }

  static Future<Map<String, dynamic>> googleLogin({required String idToken}) async {
    final res = await dio.post(
      "/api/mobile/login/google",
      data: {"id_token": idToken},
    );

    _ensureOk(res, "Login Google gagal");

    final body = _asMap(res.data);
    final data = _asMap(body["data"]);

    await storage.write(key: "token", value: (data["token"] ?? "").toString());
    await storage.write(key: "role",  value: _asMap(data["user"])["role"]?.toString() ?? "");
    await storage.write(key: "name",  value: _asMap(data["user"])["name"]?.toString() ?? "");

    return data;
  }

  static Future<void> logout() async {
    try {
      final headers = await _headers();
      await dio.post(
        "/api/mobile/logout",
        options: Options(headers: headers),
      );
    } catch (_) {}
    await storage.deleteAll();
  }


  // ── Profile ──────────────────────────────────
  static Future<Map<String, dynamic>> getMyProfile() async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/profile",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal memuat profil");
    return _asMap(_asMap(res.data)["data"]["profile"]);
  }

  static Future<void> updateMyProfile(Map<String, dynamic> data) async {
    final headers = await _headers();
    final res = await dio.put("/api/mobile/profile",
        data: data, options: Options(headers: headers));
    _ensureOk(res, "Gagal update profil");
  }

  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/profile/$userId",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal memuat profil user");
    return _asMap(_asMap(res.data)["data"]["profile"]);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/me",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat profil");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/dashboard",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat dashboard");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<List<dynamic>> getNotifications() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/notifications",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat notifikasi");
    return _asList(_asMap(_asMap(res.data)["data"])["notifications"]);
  }

  static Future<Map<String, dynamic>> markNotificationRead(int annId) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/notifications/read/$annId",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menandai notifikasi");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/device/register",
      data: {
        "fcm_token": token,
        "platform": platform,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal mendaftarkan token device");
    return _asMap(res.data);
  }

  static Future<List<dynamic>> getAttendanceHistory() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/attendance",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat riwayat absensi");
    return _asList(_asMap(_asMap(res.data)["data"])["attendance"]);
  }

  static Future<List<dynamic>> getMyAttendanceHistory() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/attendance/me",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat riwayat absensi saya");
    return _asList(_asMap(_asMap(res.data)["data"])["attendance"]);
  }

  static Future<List<dynamic>> getAdminAttendanceList() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/attendance",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat data absensi admin");
    return _asList(_asMap(_asMap(res.data)["data"])["attendance"]);
  }

  static Future<Map<String, dynamic>> submitAttendance({
    required String attendanceType,
    required double latitude,
    required double longitude,
    required File selfieFile,
    String note = "",
  }) async {
    final headers = await _headers();

    final formData = FormData.fromMap({
      "attendance_type": attendanceType,
      "latitude": latitude,
      "longitude": longitude,
      "note": note,
      "device_id": "android",
      "selfie": await MultipartFile.fromFile(
        selfieFile.path,
        filename: selfieFile.path.split("/").last,
      ),
    });

    final res = await dio.post(
      "/api/mobile/attendance",
      data: formData,
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal kirim absensi");
    return _asMap(res.data);
  }

  static Future<List<dynamic>> getPendingAttendanceList() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/attendance/pending",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat pending attendance");
    return _asList(_asMap(_asMap(res.data)["data"])["attendance"]);
  }

  static Future<Map<String, dynamic>> approvePendingAttendance(
      int id, {
        dynamic userId,
      }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/attendance/pending/$id/approve",
      data: {"user_id": userId},
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal approve absensi");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> rejectPendingAttendance(
      int id, {
        String reason = "",
      }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/attendance/pending/$id/reject",
      data: {"reason": reason},
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal reject absensi");
    return _asMap(res.data);
  }

  // ============================================================
// TAMBAHKAN FUNGSI INI KE DALAM CLASS ApiService
// di file: api_service.dart
// Taruh setelah fungsi rejectPendingAttendance
// ============================================================

  /// Admin mengabsenkan karyawan tertentu secara manual.
  /// [userId]       : ID karyawan yang diabsenkan
  /// [arrivalType]  : "ONTIME" | "LATE" | "SICK" | "LEAVE" | "ABSENT"
  /// [note]         : catatan opsional
  /// [manualCheckin]: jam format "HH:MM" — null = jam otomatis server (WIB)
  static Future<Map<String, dynamic>> adminSubmitAttendanceForEmployee({
    required int userId,
    required String arrivalType,
    String note = "",
    String? manualCheckin,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/attendance/admin-add",
      data: {
        "user_id":        userId,
        "arrival_type":   arrivalType,
        "note":           note,
        if (manualCheckin != null && manualCheckin.isNotEmpty)
          "manual_checkin": manualCheckin,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal catat absensi karyawan");
    return _asMap(res.data);
  }

  static Future<List<dynamic>> getProducts() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/products",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat produk");
    return _asList(_asMap(_asMap(res.data)["data"])["products"]);
  }

  static Future<List<dynamic>> getGlobalProducts() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/products/global",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat produk global");
    return _asList(_asMap(_asMap(res.data)["data"])["products"]);
  }

  static Future<Map<String, dynamic>> addProduct({
    required String name,
    required int price,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/products",
      data: {
        "name": name,
        "price": price,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menambah produk");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> updateProduct({
    required int id,
    required String name,
    required int price,
  }) async {
    final headers = await _headers();
    final res = await dio.put(
      "/api/mobile/products/$id",
      data: {
        "name": name,
        "price": price,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal mengubah produk");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    final headers = await _headers();
    final res = await dio.delete(
      "/api/mobile/products/$id",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menghapus produk");
    return _asMap(res.data);
  }

  static Future<List<dynamic>> getSalesList() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/sales",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat sales");
    return _asList(_asMap(_asMap(res.data)["data"])["sales"]);
  }

  static Future<Map<String, dynamic>> submitSale({
    required int productId,
    required int qty,
    String note = "",
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/sales",
      data: {
        "product_id": productId,
        "qty": qty,
        "note": note,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal mengirim sales");
    return _asMap(res.data);
  }

  // COMPATIBILITY (biar sales_page.dart tidak error)
  static Future<List<dynamic>> getSales() async {
    return getSalesList();
  }

  static Future<Map<String, dynamic>> approveSale(
      int sid, {
        String adminNote = "",
      }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/sales/$sid/approve",
      data: {"admin_note": adminNote},
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal approve sales");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> rejectSale(
      int sid, {
        String adminNote = "",
      }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/sales/$sid/reject",
      data: {"admin_note": adminNote},
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal reject sales");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> getSalesMonitor() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/sales/monitor",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat monitor sales");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<List<dynamic>> getUsers() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/admin/users",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat user");
    return _asList(_asMap(_asMap(res.data)["data"])["users"]);
  }

  // COMPATIBILITY VERSION (pakai payload seperti di users_page.dart)
  static Future<Map<String, dynamic>> createUser(dynamic payload) async {
    final map = _asMap(payload);

    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/admin/users",
      data: {
        "name": map["name"],
        "email": map["email"],
        "password": map["password"],
        "role": map["role"] ?? "employee",
        "daily_salary": map["daily_salary"] ?? 0,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal membuat user");
    return _asMap(res.data);
  }

  // COMPATIBILITY VERSION (pakai payload seperti di users_page.dart)
  static Future<Map<String, dynamic>> updateUser(int id, dynamic payload) async {
    final map = _asMap(payload);

    final headers = await _headers();
    final res = await dio.put(
      "/api/mobile/admin/users/$id",
      data: {
        "name": map["name"],
        "email": map["email"],
        "role": map["role"] ?? "employee",
        "daily_salary": map["daily_salary"] ?? 0,
        "new_password": map["new_password"] ?? "",
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal update user");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> deleteUser(int id) async {
    final headers = await _headers();
    final res = await dio.delete(
      "/api/mobile/admin/users/$id",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal hapus user");
    return _asMap(res.data);
  }

  static Future<Map<String, dynamic>> getInvoiceProducts() async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/invoice/products",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal memuat produk");
    return _asMap(_asMap(res.data)['data']);
  }

  static Future<Map<String, dynamic>> createInvoice({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    final authHeaders = await _headers();
    final formData = FormData.fromMap({
      'customer_name':  (header['customer_name']  ?? '').toString(),
      'customer_phone': (header['customer_phone'] ?? '').toString(),
      'payment_method': (header['payment_method'] ?? 'CASH').toString(),
      'notes':          (header['notes']          ?? '').toString(),
      'discount':       (header['discount']       ?? 0).toString(),
      'is_paid':        (header['is_paid']        ?? '1').toString(),
      'items_json':     jsonEncode(items),
    });
    final res = await dio.post("/api/mobile/invoice",
        data: formData,
        options: Options(headers: authHeaders,
            contentType: 'multipart/form-data'));
    _ensureOk(res, "Gagal membuat nota");
    return _asMap(_asMap(res.data)['data']);
  }

  static Future<Map<String, dynamic>> getInvoiceDetail(int invoiceId) async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/invoice/$invoiceId",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal memuat invoice");
    return _asMap(_asMap(res.data)['data']);
  }

  static Future<void> markInvoicePaid(int invoiceId,
      {bool isPaid = true}) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/invoice/$invoiceId/mark-paid",
        data: {'is_paid': isPaid},
        options: Options(headers: headers));
    _ensureOk(res, "Gagal update status bayar");
  }

  static Future<Map<String, dynamic>> getPayroll({String? month}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/payroll",
      queryParameters: month == null ? null : {"month": month},
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat payroll");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> getStats({
    String? month,      // legacy, tetap didukung
    String? dateFrom,   // YYYY-MM-DD
    String? dateTo,     // YYYY-MM-DD
  }) async {
    final headers = await _headers();
    final params  = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo   != null) params['date_to']   = dateTo;
    if (month    != null && dateFrom == null) params['month'] = month;

    final res = await dio.get(
      "/api/mobile/stats",
      queryParameters: params.isEmpty ? null : params,
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat statistik");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> getPoints() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/points",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat poin");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> addPoints({
    required int userId,
    required int delta,
    String note = "",
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/points/add",
      data: {
        "user_id": userId,
        "delta": delta,
        "note": note,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menambah poin");
    return _asMap(res.data);
  }
  // ── Pengumuman: create & delete (admin) ──
  // Menggunakan endpoint baru /api/mobile/announcements
  // Endpoint baca tetap pakai getNotifications() yang sudah ada

  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/announcements",
      data: {"title": title, "body": body},
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal membuat pengumuman");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<void> deleteAnnouncement(int id) async {
    final headers = await _headers();
    final res = await dio.delete(
      "/api/mobile/announcements/$id",
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menghapus pengumuman");
  }

  /// User menyembunyikan pengumuman dari listnya sendiri (tidak hapus dari DB)
  static Future<void> dismissAnnouncement(int id) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/announcements/$id/dismiss",
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menyembunyikan pengumuman");
  }
  // ── Download Excel statistik ──────────────
  static Future<List<int>> downloadStatsExcel({
    String? dateFrom,
    String? dateTo,
    String? month,
  }) async {
    final token = await storage.read(key: "token");

    final params = <String, String>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo   != null) params['date_to']   = dateTo;
    if (month    != null && dateFrom == null) params['month'] = month;

    final uri = Uri.parse('$baseUrl/api/mobile/stats/export').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );

    final httpClient = HttpClient();
    final req  = await httpClient.getUrl(uri);
    req.headers.set('Authorization', 'Bearer $token');
    final resp = await req.close();

    if (resp.statusCode != 200) {
      throw 'Gagal mengunduh Excel (\${resp.statusCode})';
    }

    final List<int> bytes = [];
    await for (final chunk in resp) { bytes.addAll(chunk); }
    httpClient.close();
    return bytes;
  }

  // ── BioFinger Fingerprint Mapping ─────────
  static Future<Map<String, dynamic>> getBiofingerMappings() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/biofinger/mapping",
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal memuat mapping fingerprint");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> getBiofingerUnmapped() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/biofinger/unmapped",
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal memuat PIN unmapped");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<void> addBiofingerMapping({
    required String pinMesin,
    required int    userId,
    String namaMesin = '',
    String snMesin   = '',
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/biofinger/mapping",
      data: {
        "pin_mesin":  pinMesin,
        "user_id":    userId,
        "nama_mesin": namaMesin,
        "snmesin":    snMesin,
      },
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menyimpan mapping");
  }

  static Future<void> deleteBiofingerMapping(int id) async {
    final headers = await _headers();
    final res = await dio.delete(
      "/api/mobile/biofinger/mapping",
      data: {"id": id},
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menghapus mapping");
  }

  static Future<Map<String, dynamic>> calculateHppAi({
    required String productName,
    required int batchSize,
    required double packagingCost,
    required double overheadCost,
    required double laborCost,
    required double otherCost,
    required double targetMarginPercent,
    required double desiredSellingPrice,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/hpp-ai",
      data: {
        "product_name": productName,
        "batch_size": batchSize,
        "packaging_cost": packagingCost,
        "overhead_cost": overheadCost,
        "labor_cost": laborCost,
        "other_cost": otherCost,
        "target_margin_percent": targetMarginPercent,
        "desired_selling_price": desiredSellingPrice,
        "items": items,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menghitung HPP AI");
    return _asMap(_asMap(res.data)["data"]);
  }



  static Future<Map<String, dynamic>> getBuyPriceGroups() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/buy-prices",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memuat harga beli");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> addBuyPrice({
    required String material,
    required String grade,
    required String unit,
    required double price,
    String note = "",
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/buy-prices",
      data: {
        "material": material,
        "grade": grade,
        "unit": unit,
        "price": price,
        "note": note,
        "is_active": isActive,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menambah harga beli");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> updateBuyPrice({
    required int id,
    String? material,
    String? grade,
    String? unit,
    required double price,
    String note = "",
    bool isActive = true,
  }) async {
    final headers = await _headers();
    final res = await dio.put(
      "/api/mobile/buy-prices/$id",
      data: {
        if (material != null) "material": material,
        if (grade != null) "grade": grade,
        if (unit != null) "unit": unit,
        "price": price,
        "note": note,
        "is_active": isActive,
      },
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal memperbarui harga beli");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<void> deleteBuyPrice(int id) async {
    final headers = await _headers();
    final res = await dio.delete(
      "/api/mobile/buy-prices/$id",
      options: Options(headers: headers),
    );

    _ensureOk(res, "Gagal menghapus harga beli");
  }

  static Future<Map<String, dynamic>> getMyPayslip({required String week}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/my-payslip",
      queryParameters: {"week": week},
      options: Options(headers: headers),
    );
    return _asMap(res.data['data']);
  }

  // ════════════════════════════════════════════
//  TAMBAHKAN METHOD INI KE api_service.dart
//  Letakkan sebelum method checkVersion()
// ════════════════════════════════════════════

  // ── Finance: Materials & Stock ─────────────
  static Future<Map<String, dynamic>> financeGetMaterials() async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/finance/materials",
        options: Options(headers: headers));
    return _asMap(res.data['data']);
  }


  /// Tambah material/barang baru ke gudang.
  /// [initQty] dan [initPrice] opsional — jika diisi, stok awal
  /// langsung masuk via transaksi BELI.
  static Future<Map<String, dynamic>> financeAddMaterial({
    required String name,
    String unit = 'kg',
    double initQty = 0,
    int initPrice = 0,
    String note = '',
  }) async {
    final authHeaders = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/materials",
      data: {
        "name":       name,
        "unit":       unit,
        "init_qty":   initQty,
        "init_price": initPrice,
        "note":       note,
      },
      options: Options(headers: authHeaders),
    );
    _ensureOk(res, "Gagal menambah barang");
    return _asMap(_asMap(res.data)['data']);
  }

  // ── Finance: Beli dari orang ───────────────
  static Future<Map<String, dynamic>> financeBeli({
    required String partyName,
    required bool   isDebt,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/buy",
      data: {
        "party_name": partyName,
        "is_debt":    isDebt,
        "note":       note ?? "",
        "items":      items,
      },
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menyimpan transaksi beli");
    return _asMap(res.data['data']);
  }

  // ── Finance: Jual ke orang ─────────────────
  static Future<Map<String, dynamic>> financeJual({
    required String partyName,
    required bool   isDebt,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/sell",
      data: {
        "party_name": partyName,
        "is_debt":    isDebt,
        "note":       note ?? "",
        "items":      items,
      },
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menyimpan transaksi jual");
    return _asMap(res.data['data']);
  }

  // ── Finance: Pengeluaran ───────────────────
  static Future<void> financeExpense({
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/expense",
      data: {"note": note ?? "", "items": items},
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menyimpan pengeluaran");
  }

  // ── Finance: Laporan harian ────────────────
  static Future<Map<String, dynamic>> financeReportDaily({String? date}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/finance/report/daily",
      queryParameters: date != null ? {"date": date} : {},
      options: Options(headers: headers),
    );
    return _asMap(res.data['data']);
  }

  // ── Finance: Laporan mingguan ──────────────
  static Future<Map<String, dynamic>> financeReportWeekly({required String week}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/finance/report/weekly",
      queryParameters: {"week": week},
      options: Options(headers: headers),
    );
    return _asMap(res.data['data']);
  }

  // ── Finance: Hutang & Piutang ──────────────
  static Future<Map<String, dynamic>> financeGetDebts() async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/finance/debts",
        options: Options(headers: headers));
    return _asMap(res.data['data']);
  }

  // ── Finance: Bayar hutang/piutang ─────────
  static Future<Map<String, dynamic>> financePayDebt({
    required int    debtId,
    required double amount,
  }) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/debts/$debtId/pay",
      data: {"amount": amount},
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal memproses pembayaran");
    return _asMap(res.data['data']);
  }


  // ── Finance: Buat Invoice dari stok gudang ──
  static Future<Map<String, dynamic>> financeCreateInvoice({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    final authHeaders = await _headers();
    final res = await dio.post(
      "/api/mobile/finance/invoice",
      data: {
        "header": header,
        "items":  items,
      },
      options: Options(headers: authHeaders),
    );
    _ensureOk(res, "Gagal membuat nota");
    return _asMap(_asMap(res.data)['data']);
  }

// ════════════════════════════════════════════
//  TAMBAHKAN ke api_service.dart
//  Letakkan setelah financePayDebt()
// ════════════════════════════════════════════

  // ── Trip: Buka perjalanan baru ─────────────
  static Future<Map<String, dynamic>> financeTripNew({String? note}) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/new",
        data: {"note": note ?? "", "trip_date": DateTime.now().toString().substring(0, 10)},
        options: Options(headers: headers));
    _ensureOk(res, "Gagal membuka perjalanan");
    return _asMap(res.data['data']);
  }

  // ── Trip: List semua perjalanan ────────────
  static Future<Map<String, dynamic>> financeGetTrips() async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/finance/trips",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal memuat perjalanan");
    // Response: {"ok":true, "data": {"trips": [...]}}
    final body = _asMap(res.data);
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    // Fallback jika data langsung di root
    if (body['trips'] is List) return body;
    return <String, dynamic>{"trips": []};
  }

  // ── Trip: Detail 1 perjalanan ──────────────
  static Future<Map<String, dynamic>> financeTripDetail({required int tripId}) async {
    final headers = await _headers();
    final res = await dio.get("/api/mobile/finance/trips/$tripId",
        options: Options(headers: headers));
    return _asMap(res.data['data']);
  }

  // ── Trip: Jual ke lapak ────────────────────
  static Future<Map<String, dynamic>> financeTripSell({
    required int    tripId,
    int?            partyId,
    String?         partyName,
    required String paymentType,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/sell",
        data: {
          if (partyId != null) "party_id": partyId,
          if (partyName != null && partyName.isNotEmpty) "party_name": partyName,
          "payment_type": paymentType,
          "items": items,
        },
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menyimpan penjualan");
    return _asMap(res.data['data']);
  }

  // ── Trip: Beli di Jakarta ──────────────────
  static Future<Map<String, dynamic>> financeTripBuy({
    required int tripId,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/buy",
        data: {"items": items},
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menyimpan pembelian");
    return _asMap(res.data['data']);
  }

  // ── Trip: Pengeluaran ──────────────────────
  static Future<void> financeTripExpense({
    required int tripId,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/expense",
        data: {"items": items},
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menyimpan pengeluaran");
  }

  // ── Trip: Balikan barang ───────────────────
  static Future<void> financeTripReturn({
    required int tripId,
    required List<Map<String, dynamic>> items,
  }) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/return",
        data: {"items": items},
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menyimpan balikan");
  }

  // ── Trip: Tutup perjalanan ─────────────────
  static Future<Map<String, dynamic>> financeTripClose({required int tripId}) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/close",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menutup perjalanan");
    return _asMap(res.data['data']);
  }

  static Future<void> financeTripCancel({required int tripId}) async {
    final headers = await _headers();
    final res = await dio.post("/api/mobile/finance/trips/$tripId/cancel",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal membatalkan perjalanan");
  }

  static Future<void> financeTripDelete({required int tripId}) async {
    final headers = await _headers();
    final res = await dio.delete("/api/mobile/finance/trips/$tripId",
        options: Options(headers: headers));
    _ensureOk(res, "Gagal menghapus perjalanan");
  }

  static Future<Map<String, dynamic>> getOwnerInsight() async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/owner/insight",
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal memuat insight owner");
    return _asMap(_asMap(res.data)["data"]);
  }

  static Future<Map<String, dynamic>> getOwnerStats({String? month}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/owner/stats",
      queryParameters: month != null ? {"month": month} : {},
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal memuat statistik");
    return _asMap(_asMap(res.data)['data']);
  }

  static Future<Uint8List> downloadOwnerStatsExcel({String? month}) async {
    final headers = await _headers();
    final res = await dio.get(
      "/api/mobile/owner/export/excel",
      queryParameters: month != null ? {"month": month} : {},
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
      ),
    );
    if (res.statusCode != 200) {
      throw Exception("Gagal export: ${res.statusCode}");
    }
    return Uint8List.fromList(res.data as List<int>);
  }

  static Future<Map<String, dynamic>> getOwnerAiReview(Map<String, dynamic> insight) async {
    final headers = await _headers();
    final res = await dio.post(
      "/api/mobile/owner/ai-review",
      data: insight,
      options: Options(headers: headers),
    );
    _ensureOk(res, "Gagal menjalankan AI Review");
    return _asMap(_asMap(res.data)["data"]);
  }

  // ── Version Check ─────────────────────────────────
  // Tidak perlu token — endpoint public
  static Future<Map<String, dynamic>> checkVersion() async {
    final res = await dio.get(
      "/api/mobile/version",
      options: Options(
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout:    const Duration(seconds: 8),
      ),
    );
    return _asMap(res.data);
  }

}