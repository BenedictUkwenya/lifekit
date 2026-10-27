import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_cache.dart';

part 'admin_api.dart';

// ── Custom exceptions ──────────────────────────────────────────────────────
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thrown when the Vercel server cold-start or slow network causes a timeout.
class UserFriendlyTimeoutException implements Exception {
  static const message =
      'The network is taking too long. Please check your signal and try again.';

  @override
  String toString() => message;
}

/// Thrown when the backend returns 403 with requires_upgrade: true.
/// The UI should navigate the user to SubscriptionPlansScreen.
class UpgradeRequiredException implements Exception {
  static const message = 'AI features require a Pro or Business subscription.';

  @override
  String toString() => message;
}

// ── Timeout constants ──────────────────────────────────────────────────────
const _kRequestTimeout = Duration(seconds: 30);

/// package:http with the standard timeout applied to every call.
class _TimedHttp {
  const _TimedHttp();

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      http.get(url, headers: headers).timeout(_kRequestTimeout);

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.post(url, headers: headers, body: body).timeout(_kRequestTimeout);

  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) =>
      http.put(url, headers: headers, body: body).timeout(_kRequestTimeout);
}

const _net = _TimedHttp();

class ApiService {
  // ── Backend URL ──────────────────────────────────────────────────────────
  // Resolution order:
  //   1. --dart-define=API_BASE_URL=...   (CI / store builds)
  //   2. API_BASE_URL in .env
  //   3. Release builds → production; debug builds → local dev server
  //      (Android emulator reaches the host's localhost via 10.0.2.2).
  static const String _prodBaseUrl = 'https://lifekitbackend.vercel.app';
  static final String _resolvedBaseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    final fromEnv = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (kReleaseMode) return _prodBaseUrl;
    return Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  }

  String get baseUrl => _resolvedBaseUrl;

  // ── Language for Accept-Language header ──────────────────────────────────
  static String _lang = 'en';

  /// Call this whenever the user changes language (e.g. from LocaleProvider).
  /// Also clears any cached responses so the next fetch returns localised data.
  static void setLang(String languageCode) {
    _lang = ['en', 'ka', 'ru'].contains(languageCode) ? languageCode : 'en';
    AppCache.instance.clear();
  }

  /// Public getter so callers (cache keys, etc) can read the current language.
  static String get currentLang => _lang;

  /// Header used for public (unauthenticated) GETs to send the language hint.
  Map<String, String> _langHeader() => {'Accept-Language': _lang};

  /// Bearer-only header (GET / DELETE)
  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
    'Accept-Language': _lang,
  };

  /// Bearer + JSON header (POST / PUT)
  Map<String, String> _authJsonHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'Accept-Language': _lang,
  };

  // ── Secure storage with encryptedSharedPreferences for hardware compat ───
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Token state is static: the app creates many ApiService instances, and
  // Supabase refresh tokens are single-use — per-instance caches let two
  // screens refresh concurrently and the loser would log the user out.
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;
  static Future<String?>? _refreshingToken;

  Future<void> _saveTokens(String access, String refresh) async {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
    await storage.write(key: 'jwt_token', value: access);
    await storage.write(key: 'refresh_token', value: refresh);
  }

  /// Optional async hook run at the start of [clearSession]; set by PushService.
  static Future<void> Function()? beforeSessionCleared;

  Future<void> registerPushToken(String token, String platform) =>
      _authenticatedPost('/push/register', {'token': token, 'platform': platform});

  Future<void> unregisterPushToken(String token) =>
      _authenticatedPost('/push/unregister', {'token': token});

  /// True when a stored access token exists (doesn't validate it).
  Future<bool> hasSession() async {
    final token = _cachedAccessToken ?? await storage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }

  /// Wipes the session everywhere (secure storage, in-memory tokens, cache,
  /// and any Supabase OAuth session so social sign-in can't silently resume).
  Future<void> clearSession() async {
    // Runs while we're still authenticated (e.g. push unregister).
    final hook = beforeSessionCleared;
    if (hook != null) {
      try {
        await hook().timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await storage.deleteAll();
    AppCache.instance.clear();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  Future<String?> _performTokenRefresh() async {
    try {
      final refresh =
          _cachedRefreshToken ?? await storage.read(key: 'refresh_token');
      if (refresh == null) {
        await clearSession();
        return null;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({"refresh_token": refresh}),
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access_token'], data['refresh_token']);
        return data['access_token'];
      }

      // Only wipe tokens when the server explicitly rejects the refresh (401/403).
      // A 5xx server error is transient — keep tokens so the next launch can retry.
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearSession();
      }
      return null;
    } on SocketException {
      throw Exception('NO_INTERNET');
    } on http.ClientException {
      throw Exception('NO_INTERNET');
    } catch (e) {
      return null;
    }
  }

  Future<T> _withNetworkGuard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      throw UserFriendlyTimeoutException();
    } on SocketException {
      throw Exception('NO_INTERNET');
    } on http.ClientException {
      throw Exception('NO_INTERNET');
    }
  }

  Future<String?> _refreshToken() {
    return _refreshingToken ??= _performTokenRefresh().whenComplete(
      () => _refreshingToken = null,
    );
  }

  Future<String> _requireToken() async {
    final token =
        _cachedAccessToken ??
        await storage.read(key: 'jwt_token') ??
        await _refreshToken();
    if (token == null) throw Exception("Session Expired. Please login again.");
    _cachedAccessToken = token;
    return token;
  }

  /// Sends an authenticated request, transparently refreshing the access
  /// token once on a 401.
  Future<dynamic> _authenticatedRequest(
    String method,
    String endpoint, [
    Map<String, dynamic>? body,
  ]) {
    return _withNetworkGuard(() async {
      Future<http.Response> send(String token) {
        final uri = Uri.parse('$baseUrl$endpoint');
        final Future<http.Response> request;
        switch (method) {
          case 'GET':
            request = http.get(uri, headers: _authHeaders(token));
          case 'DELETE':
            request = http.delete(uri, headers: _authHeaders(token));
          case 'PUT':
            request = http.put(
              uri,
              headers: _authJsonHeaders(token),
              body: jsonEncode(body ?? const {}),
            );
          default:
            request = http.post(
              uri,
              headers: _authJsonHeaders(token),
              body: jsonEncode(body ?? const {}),
            );
        }
        return request.timeout(_kRequestTimeout);
      }

      var response = await send(await _requireToken());
      if (response.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken == null) throw Exception("Session Expired");
        response = await send(newToken);
      }
      return _processResponse(response);
    });
  }

  Future<dynamic> _authenticatedGet(String endpoint) =>
      _authenticatedRequest('GET', endpoint);

  Future<dynamic> _authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) => _authenticatedRequest('POST', endpoint, body);

  Future<dynamic> _authenticatedPut(
    String endpoint,
    Map<String, dynamic> body,
  ) => _authenticatedRequest('PUT', endpoint, body);

  Future<dynamic> _authenticatedDelete(String endpoint) =>
      _authenticatedRequest('DELETE', endpoint);

  /// Uploads an image to `/storage/upload/<folder>` and returns its public URL.
  Future<String> _uploadFile(String folder, File file) {
    return _withNetworkGuard(() async {
      Future<http.Response> send(String token) async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/storage/upload/$folder'),
        )..headers.addAll(_authHeaders(token));
        final mimeTypeData =
            lookupMimeType(file.path)?.split('/') ?? ['image', 'jpeg'];
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
          ),
        );
        final streamed = await request.send().timeout(
          const Duration(seconds: 60),
        );
        return http.Response.fromStream(streamed);
      }

      var response = await send(await _requireToken());
      if (response.statusCode == 401) {
        final newToken = await _refreshToken();
        if (newToken == null) throw Exception("Session Expired");
        response = await send(newToken);
      }
      final data = await _processResponse(response);
      final url = data is Map ? data['url'] : null;
      if (url is! String) throw Exception('Upload failed');
      return url;
    });
  }

  Future<dynamic> _processResponse(http.Response response) async {
    if (kDebugMode) {
      final body = response.body;
      debugPrint(
        "SERVER RESPONSE [${response.statusCode}]: "
        "${body.length > 500 ? '${body.substring(0, 500)}…' : body}",
      );
    }

    // Proxies / cold starts can return HTML or an empty body — never let a
    // FormatException leak to the UI.
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    String errorMessage = "Server Error: ${response.statusCode}";
    if (decoded is Map && decoded['error'] is String) {
      errorMessage = decoded['error'];
    }

    // AI paywall: 403 with requires_upgrade flag → dedicated exception
    if (response.statusCode == 403 &&
        decoded is Map &&
        decoded['requires_upgrade'] == true) {
      throw UpgradeRequiredException();
    }

    final lowerError = errorMessage.toLowerCase();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        !lowerError.contains("password") &&
        !lowerError.contains("credentials") &&
        !lowerError.contains("invalid login")) {
      final isAuthRelated =
          response.statusCode == 401 ||
          lowerError.contains("session") ||
          lowerError.contains("token") ||
          lowerError.contains("expired") ||
          lowerError.contains("jwt") ||
          lowerError.contains("not authenticated");
      if (isAuthRelated) {
        await clearSession();
        throw Exception("Session Expired. Please login again.");
      }
    }

    throw ApiException(response.statusCode, errorMessage);
  }

  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password, {
    String? language,
  }) async {
    return _withNetworkGuard(() async {
      final response = await _net.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "full_name": name,
          "email": email,
          "password": password,
          if (language != null) "language": language,
        }),
      );
      return await _processResponse(response);
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _withNetworkGuard(() async {
      final response = await _net.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "password": password}),
      );
      final data = await _processResponse(response);
      if (data.containsKey('session')) {
        await _saveTokens(
          data['session']['access_token'],
          data['session']['refresh_token'],
        );
      }
      return data;
    });
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String token) async {
    return _withNetworkGuard(() async {
      final response = await _net.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "token": token}),
      );
      final data = await _processResponse(response);
      if (data.containsKey('session')) {
        await _saveTokens(
          data['session']['access_token'],
          data['session']['refresh_token'],
        );
      }
      return data;
    });
  }

  // ===========================================================================
  // PROFILE & USER
  // ===========================================================================

  Future<Map<String, dynamic>> getUserProfile() async {
    const key = 'user_profile';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/users/profile');
    AppCache.instance.set(key, data, ttl: AppCache.ttlLong);
    return data;
  }

  Future<String> getCurrentSubscriptionTier() async {
    final data = await getUserProfile();
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) return 'free';
    return (profile['subscription_tier'] ?? 'free').toString().toLowerCase();
  }

  Future<void> updateProfile({
    String? fullName,
    String? imageUrl,
    String? username,
    String? phone,
    String? bio,
  }) async {
    final Map<String, dynamic> body = {};
    if (fullName != null) body['full_name'] = fullName;
    if (imageUrl != null) body['profile_picture_url'] = imageUrl;
    if (username != null) body['username'] = username;
    if (phone != null) body['phone_number'] = phone;
    if (bio != null) body['bio'] = bio;
    if (body.isEmpty) return;
    await _authenticatedPut('/users/profile', body);
    AppCache.instance.invalidate('user_profile');
  }

  Future<void> uploadProfilePic(File imageFile) async {
    final url = await _uploadFile('profiles', imageFile);
    AppCache.instance.invalidate('user_profile');
    await updateProfile(imageUrl: url);
  }

  Future<void> onboardAsProvider() async {
    await _authenticatedPut('/users/onboard-provider', {});
  }

  Future<Map<String, dynamic>> getUnreadCounts() async {
    const key = 'unread_counts';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/users/counts');
    AppCache.instance.set(key, data, ttl: AppCache.ttlShort);
    return data;
  }

  Future<void> deleteAccount() async {
    await _authenticatedDelete('/users/profile');
    await clearSession();
  }

  // ===========================================================================
  // SUPPORT
  // ===========================================================================

  Future<Map<String, dynamic>> createTicket(
    String subject,
    String message,
  ) async {
    return await _authenticatedPost('/support', {
      "subject": subject,
      "message": message,
    });
  }

  Future<List<dynamic>> getMyTickets() async {
    final data = await _authenticatedGet('/support/my-tickets');
    return data['tickets'] ?? [];
  }

  Future<Map<String, dynamic>> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    return await _authenticatedPost('/support/report', {
      "reported_user_id": reportedUserId,
      "reason": reason,
      "details": details,
    });
  }

  /// Blocks [userId]: their posts disappear from my feed and mine from theirs.
  Future<void> blockUser(String userId) async {
    await _authenticatedPost('/users/blocks/$userId', {});
    AppCache.instance.invalidate('feeds');
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final data = await _authenticatedGet('/users/blocks');
    return data is List ? data.whereType<Map<String, dynamic>>().toList() : [];
  }

  Future<void> unblockUser(String userId) async {
    await _authenticatedDelete('/users/blocks/$userId');
    AppCache.instance.invalidate('feeds');
  }

  // ===========================================================================
  // HOME & SERVICES (PUBLIC & SEARCH)
  // ===========================================================================

  Future<List<dynamic>> getOffers() async {
    final response = await _net.get(
      Uri.parse('$baseUrl/home/offers'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    return data['offers'] ?? [];
  }

  Future<List<dynamic>> getCategories() async {
    final key = 'categories_${_lang}';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final response = await _net.get(
      Uri.parse('$baseUrl/home/categories'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    final result = data['categories'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlStatic);
    return result;
  }

  Future<List<dynamic>> getPopularServices() async {
    final response = await _net.get(
      Uri.parse('$baseUrl/home/popular-services'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    return data['services'] ?? [];
  }

  Future<Map<String, dynamic>> getExplore() async {
    final key = 'explore_${_lang}';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final response = await _net.get(
      Uri.parse('$baseUrl/home/explore'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    AppCache.instance.set(key, data, ttl: AppCache.ttlMedium);
    return data;
  }

  Future<List<dynamic>> getRecentSearches() async {
    final data = await _authenticatedGet('/home/recent-searches');
    return data['recent_searches'] ?? [];
  }

  Future<List<dynamic>> getServicesByCategory(String categoryId) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/services/category/$categoryId'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    return data['services'] ?? [];
  }

  Future<Map<String, dynamic>> getProviderServices(String providerId) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/services/provider/$providerId'),
      headers: _langHeader(),
    );
    return await _processResponse(response);
  }

  Future<List<dynamic>> getSubCategories(String parentId) async {
    final key = 'subcategories_${_lang}_$parentId';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final response = await _net.get(
      Uri.parse('$baseUrl/home/categories/children/$parentId'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    final result = data['categories'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlStatic);
    return result;
  }

  Future<Map<String, dynamic>> search(String query) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/home/search?query=$query'),
      headers: _langHeader(),
    );
    return await _processResponse(response);
  }

  Future<List<dynamic>> searchCategories(String query) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/home/categories/search/dropdown?query=$query'),
      headers: _langHeader(),
    );
    final data = await _processResponse(response);
    return data['categories'] ?? [];
  }

  // ===========================================================================
  // PROVIDER MANAGEMENT
  // ===========================================================================

  Future<List<dynamic>> getMyServices() async {
    const key = 'my_services';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/services/my-services');
    final result = data['services'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<Map<String, dynamic>> createDraftServices(
    List<String> categoryIds,
  ) async {
    return await _authenticatedPost('/services', {
      "category_ids": categoryIds,
      "currency": "USD",
    });
  }

  Future<void> updateService(
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    await _authenticatedPut('/services/$serviceId', data);
    AppCache.instance.invalidate('my_services');
  }

  Future<void> deleteService(String serviceId) async {
    await _authenticatedDelete('/services/$serviceId');
    AppCache.instance.invalidate('my_services');
  }

  Future<Map<String, dynamic>> buySubscription(String tier) async {
    return await _authenticatedPost('/upgrades/subscribe', {"tier": tier});
  }

  Future<Map<String, dynamic>> buyBoost({
    required String targetId,
    required String boostDuration,
  }) async {
    return await _authenticatedPost('/upgrades/boost', {
      "target_id": targetId,
      "boost_duration": boostDuration,
    });
  }

  Future<String> uploadServiceImage(File imageFile) => _uploadFile('services', imageFile);

  Future<List<dynamic>> getProviderSchedule(String providerId) async {
    return (await _authenticatedGet(
          '/users/schedule/$providerId',
        ))['schedule'] ??
        [];
  }

  Future<Map<String, dynamic>> getProviderStats() async {
    const key = 'provider_stats';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/users/provider-stats');
    AppCache.instance.set(key, data, ttl: AppCache.ttlMedium);
    return data;
  }

  // ===========================================================================
  // BOOKINGS & REVIEWS
  // ===========================================================================

  Future<void> createBooking({
    required String serviceId,
    required String scheduledTime,
    required String locationDetails,
    required double totalPrice,
    String? serviceType,
    String? comments,
  }) async {
    await _authenticatedPost('/bookings', {
      "service_id": serviceId,
      "scheduled_time": scheduledTime,
      "location_details": locationDetails,
      "total_price": totalPrice,
      "service_type": serviceType,
      "comments": comments,
    });
  }

  Future<List<dynamic>> getClientBookings() async {
    const key = 'client_bookings';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result =
        (await _authenticatedGet('/bookings/client'))['bookings'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<List<dynamic>> getProviderRequests() async {
    const key = 'provider_requests';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result =
        (await _authenticatedGet('/bookings/provider'))['requests'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _authenticatedPut('/bookings/$bookingId/status', {"status": status});
    AppCache.instance.invalidate('client_bookings');
    AppCache.instance.invalidate('provider_requests');
  }

  Future<void> completeBooking(String bookingId) async {
    await _authenticatedPut('/bookings/$bookingId/complete', {});
    AppCache.instance.invalidate('client_bookings');
    AppCache.instance.invalidate('provider_requests');
  }

  Future<void> openBookingDispute(String bookingId, String reason) async {
    await _authenticatedPost('/bookings/$bookingId/dispute', {
      "reason": reason,
    });
  }

  Future<Map<String, dynamic>> getReviews(String serviceId) async {
    return await _authenticatedGet('/reviews/$serviceId');
  }

  Future<void> submitReview({
    required String bookingId,
    required String serviceId,
    required String revieweeId,
    required String reviewerRole, // 'client' or 'provider'
    required int rating,
    required String comment,
  }) async {
    await _authenticatedPost('/reviews', {
      "booking_id": bookingId,
      "service_id": serviceId,
      "reviewee_id": revieweeId,
      "reviewer_role": reviewerRole,
      "rating": rating,
      "comment": comment,
    });
  }

  // ===========================================================================
  // WALLET & PAYMENTS
  // ===========================================================================

  Future<Map<String, dynamic>> getWallet() async {
    const key = 'wallet';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/wallet');
    AppCache.instance.set(key, data, ttl: AppCache.ttlLong);
    return data;
  }

  Future<Map<String, dynamic>> onboardStripeConnect() async {
    return await _authenticatedPost('/wallet/onboard-connect', {});
  }

  Future<Map<String, dynamic>> getStripeLoginLink() async {
    return await _authenticatedPost('/wallet/login-link', {});
  }

  Future<void> withdrawFromWallet(double amount) async {
    await _authenticatedPost('/wallet/withdraw', {"amount": amount});
    AppCache.instance.invalidate('wallet');
  }

  Future<Map<String, dynamic>> initDeposit(double amount) async {
    return await _authenticatedPost('/wallet/deposit', {"amount": amount});
  }

  Future<void> confirmDeposit(String paymentIntentId) async {
    await _authenticatedPost('/wallet/confirm-deposit', {
      "paymentIntentId": paymentIntentId,
    });
    AppCache.instance.invalidate('wallet');
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<List<dynamic>> getNotifications() async {
    const key = 'notifications';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result =
        (await _authenticatedGet('/users/notifications'))['notifications'] ??
        [];
    AppCache.instance.set(key, result, ttl: const Duration(seconds: 45));
    return result;
  }

  Future<void> markNotificationRead(String id) async {
    await _authenticatedPut('/users/notifications/$id/read', {});
    AppCache.instance.invalidate('notifications');
    AppCache.instance.invalidate('unread_counts');
  }

  Future<void> markAllNotificationsRead() async {
    await _authenticatedPut('/users/notifications/read-all', {});
    AppCache.instance.invalidate('notifications');
    AppCache.instance.invalidate('unread_counts');
  }

  Future<void> deleteNotification(String id) async {
    await _authenticatedDelete('/users/notifications/$id');
    AppCache.instance.invalidate('notifications');
    AppCache.instance.invalidate('unread_counts');
  }

  // ===========================================================================
  // CHAT
  // ===========================================================================

  Future<List<dynamic>> getConversations() async {
    const key = 'conversations';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result = (await _authenticatedGet('/chats'))['conversations'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlShort);
    return result;
  }

  Future<List<dynamic>> getMessages(String bookingId) async {
    return (await _authenticatedGet('/chats/$bookingId'))['messages'] ?? [];
  }

  Future<void> markChatAsRead(String bookingId) async {
    await _authenticatedPut('/chats/$bookingId/read', {});
  }

  Future<void> sendMessage(String bookingId, String content, {String? imageUrl}) async {
    await _authenticatedPost('/chats/message', {
      "booking_id": bookingId,
      "content": content,
      if (imageUrl != null) "image_url": imageUrl,
    });
  }

  Future<String> uploadChatImage(File imageFile) => _uploadFile('chats', imageFile);

  // ===========================================================================
  // SKILL SWAP
  // ===========================================================================

  Future<Map<String, dynamic>> createSwapRequest({
    required String proposerServiceId,
    required String targetUserId,
    String? targetServiceId,
    String? targetCategoryId,
    String? targetCategoryName,
    String serviceType = 'Default',
    String? notes,
    String? scheduledTime,
    double aiMatchScore = 0,
    String aiMatchReason = '',
  }) async {
    return await _authenticatedPost('/swap-requests', {
      'proposer_service_id': proposerServiceId,
      'target_user_id': targetUserId,
      if (targetServiceId != null) 'target_service_id': targetServiceId,
      if (targetCategoryId != null) 'target_category_id': targetCategoryId,
      if (targetCategoryName != null)
        'target_category_name': targetCategoryName,
      'service_type': serviceType,
      if (notes != null) 'notes': notes,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      'ai_match_score': aiMatchScore,
      'ai_match_reason': aiMatchReason,
    });
  }

  Future<List<dynamic>> getIncomingSwaps() async {
    const key = 'incoming_swaps';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result =
        (await _authenticatedGet('/swap-requests/incoming'))['swaps'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<List<dynamic>> getOutgoingSwaps() async {
    const key = 'outgoing_swaps';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final result =
        (await _authenticatedGet('/swap-requests/outgoing'))['swaps'] ?? [];
    AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<List<dynamic>> getSwapBoard() async {
    return (await _authenticatedGet('/swap-requests/board'))['board'] ?? [];
  }

  Future<List<dynamic>> getSwapAvailableServices() async {
    return (await _authenticatedGet(
          '/swap-requests/available-services',
        ))['services'] ??
        [];
  }

  Future<List<dynamic>> getAiRankedSwapBoard() async {
    return (await _authenticatedGet(
          '/swap-requests/board/ai-ranked',
        ))['board'] ??
        [];
  }

  Future<Map<String, dynamic>> getSwapRequest(String swapId) async {
    return (await _authenticatedGet('/swap-requests/$swapId'))['swap'] ?? {};
  }

  Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    return (await _authenticatedGet('/bookings/$bookingId'))['booking'] ?? {};
  }

  Future<Map<String, dynamic>> acceptSwap(
    String swapId, {
    String? targetServiceId,
    String? scheduledTime,
  }) async {
    final result = await _authenticatedPut('/swap-requests/$swapId/accept', {
      if (targetServiceId != null) 'target_service_id': targetServiceId,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
    });
    AppCache.instance.invalidate('incoming_swaps');
    AppCache.instance.invalidate('outgoing_swaps');
    AppCache.instance.invalidate('client_bookings');
    AppCache.instance.invalidate('provider_requests');
    return result;
  }

  Future<void> declineSwap(String swapId) async {
    await _authenticatedPut('/swap-requests/$swapId/decline', {});
    AppCache.instance.invalidate('incoming_swaps');
    AppCache.instance.invalidate('outgoing_swaps');
  }

  Future<void> cancelSwap(String swapId) async {
    await _authenticatedPut('/swap-requests/$swapId/cancel', {});
    AppCache.instance.invalidate('incoming_swaps');
    AppCache.instance.invalidate('outgoing_swaps');
  }

  Future<List<dynamic>> getAiSkillSwapMatches({
    required String myServiceId,
    required String targetCategoryId,
  }) async {
    return (await _authenticatedPost('/ai/skill-swap-matches', {
          'my_service_id': myServiceId,
          'target_category_id': targetCategoryId,
        }))['matches'] ??
        [];
  }

  static const feedPageSize = 20;

  /// One page of the ranked feed. Only the first page is cached; [force]
  /// skips the cache (pull-to-refresh).
  Future<List<dynamic>> getFeeds({int offset = 0, bool force = false}) async {
    const key = 'feeds';
    if (offset == 0 && !force) {
      final cached = AppCache.instance.get<List<dynamic>>(key);
      if (cached != null) return cached;
    }
    final data = await _authenticatedGet('/feeds/posts?limit=$feedPageSize&offset=$offset');
    final result = data is List ? data : [];
    if (offset == 0) AppCache.instance.set(key, result, ttl: AppCache.ttlMedium);
    return result;
  }

  Future<String> uploadPostImage(File imageFile) => _uploadFile('posts', imageFile);

  Future<String> uploadGroupImage(File imageFile) => _uploadFile('groups', imageFile);

  Future<Map<String, dynamic>> createPost({
    required String content,
    String? title,
    List<String>? imageUrls,
    String tag = 'general',
  }) async {
    final safeUrls = (imageUrls ?? []).take(3).toList();
    final result = await _authenticatedPost('/feeds/posts', {
      'content': content,
      if (title != null && title.isNotEmpty) 'title': title,
      if (safeUrls.isNotEmpty) 'image_url': safeUrls.first,
      if (safeUrls.isNotEmpty) 'image_urls': safeUrls,
      'tag': tag,
    });
    AppCache.instance.invalidate('feeds');
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getEvents() async {
    const key = 'events';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final response = await _net.get(Uri.parse('$baseUrl/feeds/events'));
    final result = await _processResponse(response);
    final list = result is List ? result : [];
    AppCache.instance.set(key, list, ttl: AppCache.ttlMedium);
    return list;
  }

  Future<Map<String, dynamic>> buyEventTicket({
    required String eventId,
    required int quantity,
    required double totalPrice,
  }) async {
    return await _authenticatedPost('/events/buy-ticket', {
      "event_id": eventId,
      "quantity": quantity,
      "total_price": totalPrice,
    });
  }

  Future<Map<String, dynamic>> toggleLike(String postId) async {
    final result = await _authenticatedPost('/feeds/posts/$postId/like', {});
    return result is Map<String, dynamic> ? result : {};
  }

  Future<Map<String, dynamic>> shareServiceToFeed(String serviceId) async {
    final result = await _authenticatedPost(
      '/feeds/posts/share-service/$serviceId',
      {},
    );
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getComments(String postId) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/feeds/posts/$postId/comments'),
    );
    return await _processResponse(response);
  }

  Future<dynamic> postComment(String postId, String content) async {
    return await _authenticatedPost('/feeds/posts/$postId/comments', {
      "content": content,
    });
  }

  // ─────────────────────────────────────────────
  // EVENT SOCIAL (likes + comments)
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getEventMeta(String eventId) async {
    return await _authenticatedGet('/feeds/events/$eventId/meta');
  }

  Future<void> toggleEventLike(String eventId) async {
    await _authenticatedPost('/feeds/events/$eventId/like', {});
  }

  Future<List<dynamic>> getEventComments(String eventId) async {
    final data = await _authenticatedGet('/feeds/events/$eventId/comments');
    return data is List ? data : [];
  }

  Future<void> postEventComment(String eventId, String content) async {
    await _authenticatedPost('/feeds/events/$eventId/comments', {
      "content": content,
    });
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _authenticatedPut('/auth/update-password', {
      "current_password": oldPassword,
      "new_password": newPassword,
    });
  }

  Future<void> forgotPassword(String email, {String? language}) async {
    await _withNetworkGuard(() async {
      final response = await _net.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email,
          "source": "mobile",
          if (language != null) "language": language,
        }),
      );
      await _processResponse(response);
    });
  }

  /// Saves OAuth tokens from a Supabase social sign-in.
  Future<void> saveOAuthTokens(String accessToken, String refreshToken) async {
    await _saveTokens(accessToken, refreshToken);
  }

  /// Upserts the profile row for a social (OAuth) user.
  Future<void> ensureSocialProfile(String accessToken) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/auth/ensure-social-profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Non-blocking — profile creation failures don't stop sign-in
    }
  }

  // Get Nearby Places (Auto-fills from Google/OSM)
  Future<List<dynamic>> getNearbyPlaces(double lat, double lng) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/places/nearby?lat=$lat&lng=$lng'),
    );
    final data = await _processResponse(response);
    return data['places'] ?? [];
  }

  Future<List<dynamic>> getPopularPlaces(double lat, double lng) async {
    final response = await _net.get(
      Uri.parse('$baseUrl/places/popular?lat=$lat&lng=$lng'),
    );
    final data = await _processResponse(response);
    return data['places'] ?? [];
  }

  Future<List<dynamic>> getGroups() async {
    const key = 'groups';
    final cached = AppCache.instance.get<List<dynamic>>(key);
    if (cached != null) return cached;
    final response = await _net.get(Uri.parse('$baseUrl/feeds/groups'));
    final result = await _processResponse(response);
    final list = result is List ? result : [];
    AppCache.instance.set(key, list, ttl: AppCache.ttlMedium);
    return list;
  }

  Future<void> joinGroup(String groupId) async {
    await _authenticatedPost('/feeds/groups/$groupId/join', {});
    AppCache.instance.invalidate('groups');
  }

  Future<void> createGroup({
    required String name,
    required String description,
    String? imageUrl,
    bool anyoneCanPost = true,
  }) async {
    await _authenticatedPost('/feeds/groups', {
      "name": name,
      "description": description,
      "image_url": imageUrl,
      "anyone_can_post": anyoneCanPost,
    });
  }
  // Future<List<dynamic>> getGroupPosts(String groupId) async {
  //   final response = await _net.get(
  //     Uri.parse('$baseUrl/feeds/groups/$groupId/posts'),
  //   );
  //   return _processResponse(response);
  // }

  Future<void> updateGroupSettings(String groupId, bool anyoneCanPost) async {
    await _authenticatedPut('/feeds/groups/$groupId/settings', {
      "anyone_can_post": anyoneCanPost,
    });
  }

  Future<void> removeGroupMember(String groupId, String targetUserId) async {
    await _authenticatedDelete('/feeds/groups/$groupId/members/$targetUserId');
  }

  Future<Map<String, dynamic>> getGroupDetail(String groupId) async {
    return await _authenticatedGet('/feeds/groups/$groupId');
  }

  Future<List<dynamic>> getGroupPosts(String groupId) async {
    return await _authenticatedGet('/feeds/groups/$groupId/posts');
  }

  Future<void> createGroupPost(
    String groupId,
    String content,
    String? imageUrl, {
    String? serviceId,
    String? parentId,
  }) async {
    await _authenticatedPost('/feeds/groups/$groupId/posts', {
      "content": content,
      "image_url": imageUrl,
      "service_id": serviceId,
      "parent_id": parentId,
    });
  }

  // NEW/CORRECT
  Future<List<dynamic>> getGroupMembers(String groupId) async {
    // _authenticatedGet automatically adds the Bearer Token for you
    return await _authenticatedGet('/feeds/groups/$groupId/members');
  }

  Future<void> toggleMemberAdmin(
    String groupId,
    String userId,
    bool status,
  ) async {
    // Use a specific route or update the membership record
    await _authenticatedPut('/feeds/groups/$groupId/members/$userId/admin', {
      "is_admin": status,
    });
  }

  Future<void> kickMember(String groupId, String userId) async {
    await _authenticatedDelete('/feeds/groups/$groupId/members/$userId');
  }

  Future<void> toggleGroupPostLike(String postId) async {
    await _authenticatedPost('/feeds/groups/posts/$postId/like', {});
  }

  Future<List<dynamic>> getGroupPostComments(String postId) async {
    final response = await _authenticatedGet(
      '/feeds/groups/posts/$postId/comments',
    );
    return response;
  }

  Future<void> postGroupComment(String postId, String content) async {
    await _authenticatedPost('/feeds/groups/posts/$postId/comments', {
      "content": content,
    });
  }

  Future<void> leaveGroup(String groupId) async {
    await _authenticatedDelete('/feeds/groups/$groupId/leave');
  }

  // 1. Toggle Admin Status for a member
  Future<void> toggleGroupAdmin(
    String groupId,
    String userId,
    bool isAdmin,
  ) async {
    await _authenticatedPut('/feeds/groups/$groupId/members/$userId/admin', {
      "is_admin": isAdmin,
    });
  }

  // 2. Permanently delete a group (Creator only)
  Future<void> deleteGroup(String groupId) async {
    await _authenticatedDelete('/feeds/groups/$groupId');
    AppCache.instance.invalidate('groups');
  }

  // 3. Update group profile (name, description, image_url, anyone_can_post, is_private)
  Future<Map<String, dynamic>> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? imageUrl,
    bool? anyoneCanPost,
    bool? isPrivate,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (anyoneCanPost != null) body['anyone_can_post'] = anyoneCanPost;
    if (isPrivate != null) body['is_private'] = isPrivate;
    final result = await _authenticatedPut('/feeds/groups/$groupId', body);
    return result is Map<String, dynamic> ? result : {};
  }

  // Delete a group post
  Future<void> deleteGroupPost(String postId) async {
    await _authenticatedDelete('/feeds/groups/posts/$postId');
  }

  // Delete a feed post (owner or admin)
  Future<void> deletePost(String postId) async {
    await _authenticatedDelete('/feeds/posts/$postId');
    AppCache.instance.invalidate('feeds');
  }

  // Delete own comment on a feed post
  Future<void> deleteComment(String postId, String commentId) async {
    await _authenticatedDelete('/feeds/posts/$postId/comments/$commentId');
  }

  // Delete own comment on a group post
  Future<void> deleteGroupComment(String postId, String commentId) async {
    await _authenticatedDelete(
      '/feeds/groups/posts/$postId/comments/$commentId',
    );
  }

  // Saved posts (bookmarks)
  Future<Map<String, dynamic>> toggleBookmark(String postId) async {
    final result = await _authenticatedPost('/feeds/toggle-bookmark', {
      "postId": postId,
    });
    return result is Map<String, dynamic> ? result : {};
  }

  Future<List<dynamic>> getSavedPosts() async {
    final data = await _authenticatedGet('/feeds/saved-posts');
    return data is List ? data : [];
  }

  // Helper to get the logged-in user's ID
  Future<String?> getCurrentUserId() async {
    try {
      final profileData = await getUserProfile();
      return profileData['profile']['id'];
    } catch (e) {
      debugPrint("Error getting current user ID: $e");
      return null;
    }
  }

  Future<void> requestNewCategory(String name, String description) async {
    await _authenticatedPost('/services/request-category', {
      "category_name": name,
      "description": description,
    });
  }

  // ===========================================================================
  // AI — Module 2.4: Service Creation Assistant
  // ===========================================================================

  Future<Map<String, dynamic>> generateServiceWithAI(String prompt) async {
    return await _authenticatedPost('/ai/generate-service', {"prompt": prompt});
  }

  // AI Swap Proposal Generator — Pro/Business only
  Future<String> generateSwapProposal({
    required String myServiceTitle,
    required String targetServiceTitle,
    required String targetUserName,
  }) async {
    final data = await _authenticatedPost('/ai/generate-swap-proposal', {
      'my_service_title': myServiceTitle,
      'target_service_title': targetServiceTitle,
      'target_user_name': targetUserName,
    });
    return (data['proposal'] as String?) ?? '';
  }

  // Module 2.1 — LifeKit AI Assistant (core chat engine)
  Future<Map<String, dynamic>> sendAiChatMessage(
    String message,
    List<Map<String, String>> history,
  ) async {
    return await _authenticatedPost('/ai/chat', {
      "message": message,
      "history": history,
    });
  }

  // Module 2.2 — AI Onboarding Engine
  Future<Map<String, dynamic>> generateOnboardingPlan(
    String goals,
    String skills,
    String interests,
  ) async {
    return await _authenticatedPost('/ai/onboarding-plan', {
      "goals": goals,
      "skills": skills,
      "interests": interests,
    });
  }

  // Module 2.3 — AI Opportunity Engine
  Future<Map<String, dynamic>> getAiOpportunities() async {
    const key = 'ai_opportunities';
    final cached = AppCache.instance.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;
    final data = await _authenticatedGet('/ai/opportunities');
    AppCache.instance.set(key, data, ttl: const Duration(minutes: 10));
    return data;
  }

  // Module 2.5/2.6 — AI Discovery Engine (cached 6h — each call costs an AI request)
  Future<Map<String, dynamic>> getAiDiscovery({bool force = false}) async {
    final key = 'ai_discovery_$_lang';
    if (!force) {
      final cached = AppCache.instance.get<Map<String, dynamic>>(key);
      if (cached != null) return cached;
    }
    final data = await _authenticatedGet('/ai/discovery');
    AppCache.instance.set(key, data, ttl: const Duration(hours: 6));
    return data;
  }

  /// Runs [fetch] at most once per day per user + language, keeping the
  /// result on the device. Used for AI content that only changes daily.
  Future<Map<String, dynamic>> _oncePerDay(
    String name,
    Future<dynamic> Function() fetch,
  ) async {
    final now = DateTime.now();
    final user = await getCurrentUserId() ?? 'anon';
    final key =
        'daily_${name}_${user}_${_lang}_${now.year}-${now.month}-${now.day}';
    final prefs = await SharedPreferences.getInstance();
    final hit = prefs.getString(key);
    if (hit != null) {
      try {
        return Map<String, dynamic>.from(jsonDecode(hit) as Map);
      } catch (_) {}
    }
    final raw = await fetch();
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    // Drop earlier days for this item so storage doesn't grow.
    final stale = prefs
        .getKeys()
        .where((k) => k.startsWith('daily_${name}_') && k != key)
        .toList();
    for (final k in stale) {
      await prefs.remove(k);
    }
    await prefs.setString(key, jsonEncode(data));
    return data;
  }

  /// Marks a day of Gracia's 7-day plan done (or not). Returns the updated
  /// plan in the user's language.
  Future<List<dynamic>> setPlanDayDone(int day, bool done) async {
    final data = await _authenticatedPost('/users/onboarding-plan/progress', {
      'day': day,
      'done': done,
    });
    AppCache.instance.invalidate('user_profile');
    return (data['onboarding_plan'] as List?) ?? const [];
  }

  // Home greeting bubble — one AI call per user per day.
  Future<String> getAiGreeting() async {
    final data = await _oncePerDay(
      'greeting',
      () => _authenticatedGet('/ai/greeting?hour=${DateTime.now().hour}'),
    );
    return (data['message'] ?? '').toString();
  }

  // Module 2.5/2.7 — AI City Pulse (one per user per day)
  Future<Map<String, dynamic>> getCityPulse({
    double? lat,
    double? lng,
    required String city,
    required String localTime,
  }) {
    return _oncePerDay(
      'city_pulse',
      () => _authenticatedPost('/ai/city-pulse', {
        'lat': lat,
        'lng': lng,
        'city': city,
        'local_time': localTime,
      }),
    );
  }
}
