import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class ApiService {
  // ── Production backend ───────────────────────────────────────────────────
  // To switch back to production, replace with:
  //   "https://lifekitbackend.vercel.app"
  final String baseUrl = Platform.isAndroid
      ? "http://10.0.2.2:3000"
      : "http://localhost:3000";

  // ── Secure storage with encryptedSharedPreferences for hardware compat ───
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  Future<String?>? _refreshingToken;

  Future<void> _saveTokens(String access, String refresh) async {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
    await storage.write(key: 'jwt_token', value: access);
    await storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> _performTokenRefresh() async {
    try {
      final refresh =
          _cachedRefreshToken ?? await storage.read(key: 'refresh_token');
      if (refresh == null) {
        await storage.deleteAll();
        _cachedAccessToken = null;
        _cachedRefreshToken = null;
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

      await storage.deleteAll();
      _cachedAccessToken = null;
      _cachedRefreshToken = null;
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

  Future<String?> _refreshToken() async {
    if (_refreshingToken != null) {
      return _refreshingToken!;
    }
    _refreshingToken = _performTokenRefresh();
    try {
      return await _refreshingToken;
    } finally {
      _refreshingToken = null;
    }
  }

  Future<dynamic> _authenticatedGet(String endpoint) async {
    return _withNetworkGuard(() async {
      String? token =
          _cachedAccessToken ?? await storage.read(key: 'jwt_token');
      if (token == null) {
        token = await _refreshToken();
        if (token == null) {
          throw Exception("Session Expired. Please login again.");
        }
      }
      var response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 401) {
        String? newToken = await _refreshToken();
        if (newToken != null) {
          response = await http
              .get(
                Uri.parse('$baseUrl$endpoint'),
                headers: {'Authorization': 'Bearer $newToken'},
              )
              .timeout(_kRequestTimeout);
        } else {
          throw Exception("Session Expired");
        }
      }
      return await _processResponse(response);
    });
  }

  Future<dynamic> _authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _withNetworkGuard(() async {
      String? token =
          _cachedAccessToken ?? await storage.read(key: 'jwt_token');
      if (token == null) {
        token = await _refreshToken();
        if (token == null) {
          throw Exception("Session Expired. Please login again.");
        }
      }
      var response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 401) {
        String? newToken = await _refreshToken();
        if (newToken != null) {
          response = await http
              .post(
                Uri.parse('$baseUrl$endpoint'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $newToken',
                },
                body: jsonEncode(body),
              )
              .timeout(_kRequestTimeout);
        } else {
          throw Exception("Session Expired");
        }
      }
      return await _processResponse(response);
    });
  }

  Future<dynamic> _authenticatedPut(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _withNetworkGuard(() async {
      String? token =
          _cachedAccessToken ?? await storage.read(key: 'jwt_token');
      if (token == null) {
        token = await _refreshToken();
        if (token == null) {
          throw Exception("Session Expired. Please login again.");
        }
      }
      var response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 401) {
        String? newToken = await _refreshToken();
        if (newToken != null) {
          response = await http
              .put(
                Uri.parse('$baseUrl$endpoint'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $newToken',
                },
                body: jsonEncode(body),
              )
              .timeout(_kRequestTimeout);
        } else {
          throw Exception("Session Expired");
        }
      }
      return await _processResponse(response);
    });
  }

  Future<dynamic> _authenticatedDelete(String endpoint) async {
    return _withNetworkGuard(() async {
      String? token =
          _cachedAccessToken ?? await storage.read(key: 'jwt_token');
      if (token == null) {
        token = await _refreshToken();
        if (token == null) {
          throw Exception("Session Expired. Please login again.");
        }
      }
      var response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_kRequestTimeout);

      if (response.statusCode == 401) {
        String? newToken = await _refreshToken();
        if (newToken != null) {
          response = await http
              .delete(
                Uri.parse('$baseUrl$endpoint'),
                headers: {'Authorization': 'Bearer $newToken'},
              )
              .timeout(_kRequestTimeout);
        } else {
          throw Exception("Session Expired");
        }
      }
      return await _processResponse(response);
    });
  }

  Future<dynamic> _processResponse(http.Response response) async {
    print("SERVER RESPONSE [${response.statusCode}]: ${response.body}");

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMessage = "Server Error: ${response.statusCode}";
    if (decoded is Map && decoded.containsKey('error')) {
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
        await storage.deleteAll();
        _cachedAccessToken = null;
        _cachedRefreshToken = null;
        throw Exception("Session Expired. Please login again.");
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ApiException(response.statusCode, errorMessage);
    }

    throw ApiException(response.statusCode, errorMessage);
  } // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    return _withNetworkGuard(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "full_name": name,
          "email": email,
          "password": password,
        }),
      );
      return await _processResponse(response);
    });
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _withNetworkGuard(() async {
      final response = await http.post(
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
      final response = await http.post(
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
    return await _authenticatedGet('/users/profile');
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
  }

  Future<void> uploadProfilePic(File imageFile) async {
    String? token = await storage.read(key: 'jwt_token');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/storage/upload/profiles'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    final mimeTypeData =
        lookupMimeType(imageFile.path)?.split('/') ?? ['image', 'jpeg'];
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ),
    );
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      await updateProfile(imageUrl: responseData['url']);
    } else if (response.statusCode == 401) {
      // Manual retry for Multipart
      String? newToken = await _refreshToken();
      if (newToken != null) await uploadProfilePic(imageFile);
    }
  }

  Future<void> onboardAsProvider() async {
    await _authenticatedPut('/users/onboard-provider', {});
  }

  Future<Map<String, dynamic>> getUnreadCounts() async {
    return await _authenticatedGet('/users/counts');
  }

  Future<void> deleteAccount() async {
    await _authenticatedDelete('/users/profile');
    await storage.deleteAll();
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
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

  // ===========================================================================
  // HOME & SERVICES (PUBLIC & SEARCH)
  // ===========================================================================

  Future<List<dynamic>> getOffers() async {
    final response = await http.get(Uri.parse('$baseUrl/home/offers'));
    final data = await _processResponse(response);
    return data['offers'] ?? [];
  }

  Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/home/categories'));
    final data = await _processResponse(response);
    return data['categories'] ?? [];
  }

  Future<List<dynamic>> getPopularServices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/popular-services'),
    );
    final data = await _processResponse(response);
    return data['services'] ?? [];
  }

  Future<Map<String, dynamic>> getExplore() async {
    final response = await http.get(Uri.parse('$baseUrl/home/explore'));
    return await _processResponse(response);
  }

  Future<List<dynamic>> getRecentSearches() async {
    final data = await _authenticatedGet('/home/recent-searches');
    return data['recent_searches'] ?? [];
  }

  Future<List<dynamic>> getServicesByCategory(String categoryId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/category/$categoryId'),
    );
    final data = await _processResponse(response);
    return data['services'] ?? [];
  }

  Future<Map<String, dynamic>> getProviderServices(String providerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/provider/$providerId'),
    );
    return await _processResponse(response);
  }

  Future<List<dynamic>> getSubCategories(String parentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/categories/children/$parentId'),
    );
    final data = await _processResponse(response);
    return data['categories'] ?? [];
  }

  Future<Map<String, dynamic>> search(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/search?query=$query'),
    );
    return await _processResponse(response);
  }

  Future<List<dynamic>> searchCategories(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/categories/search/dropdown?query=$query'),
    );
    final data = await _processResponse(response);
    return data['categories'] ?? [];
  }

  // ===========================================================================
  // PROVIDER MANAGEMENT
  // ===========================================================================

  Future<List<dynamic>> getMyServices() async {
    final data = await _authenticatedGet('/services/my-services');
    return data['services'] ?? [];
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
  }

  Future<void> deleteService(String serviceId) async {
    await _authenticatedDelete('/services/$serviceId');
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

  Future<String> uploadServiceImage(File imageFile) async {
    String? token = await storage.read(key: 'jwt_token');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/storage/upload/services'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    final mimeTypeData =
        lookupMimeType(imageFile.path)?.split('/') ?? ['image', 'jpeg'];
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ),
    );
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) return jsonDecode(response.body)['url'];
    throw Exception('Upload Failed');
  }

  Future<List<dynamic>> getProviderSchedule(String providerId) async {
    return (await _authenticatedGet(
          '/users/schedule/$providerId',
        ))['schedule'] ??
        [];
  }

  Future<Map<String, dynamic>> getProviderStats() async {
    return await _authenticatedGet('/users/provider-stats');
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
    return (await _authenticatedGet('/bookings/client'))['bookings'] ?? [];
  }

  Future<List<dynamic>> getProviderRequests() async {
    return (await _authenticatedGet('/bookings/provider'))['requests'] ?? [];
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _authenticatedPut('/bookings/$bookingId/status', {"status": status});
  }

  Future<void> completeBooking(String bookingId) async {
    await _authenticatedPut('/bookings/$bookingId/complete', {});
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
    required String providerId,
    required int rating,
    required String comment,
  }) async {
    await _authenticatedPost('/reviews', {
      "booking_id": bookingId,
      "service_id": serviceId,
      "provider_id": providerId,
      "rating": rating,
      "comment": comment,
    });
  }

  // ===========================================================================
  // WALLET & PAYMENTS
  // ===========================================================================

  Future<Map<String, dynamic>> getWallet() async {
    return await _authenticatedGet('/wallet');
  }

  Future<Map<String, dynamic>> onboardStripeConnect() async {
    return await _authenticatedPost('/wallet/onboard-connect', {});
  }

  Future<Map<String, dynamic>> getStripeLoginLink() async {
    return await _authenticatedPost('/wallet/login-link', {});
  }

  Future<void> withdrawFromWallet(double amount) async {
    await _authenticatedPost('/wallet/withdraw', {"amount": amount});
  }

  Future<Map<String, dynamic>> initDeposit(double amount) async {
    return await _authenticatedPost('/wallet/deposit', {"amount": amount});
  }

  Future<void> confirmDeposit(String paymentIntentId) async {
    await _authenticatedPost('/wallet/confirm-deposit', {
      "paymentIntentId": paymentIntentId,
    });
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<List<dynamic>> getNotifications() async {
    return (await _authenticatedGet('/users/notifications'))['notifications'] ??
        [];
  }

  Future<void> markNotificationRead(String id) async {
    await _authenticatedPut('/users/notifications/$id/read', {});
  }

  Future<void> markAllNotificationsRead() async {
    await _authenticatedPut('/users/notifications/read-all', {});
  }

  Future<void> deleteNotification(String id) async {
    await _authenticatedDelete('/users/notifications/$id');
  }

  // ===========================================================================
  // CHAT
  // ===========================================================================

  Future<List<dynamic>> getConversations() async {
    return (await _authenticatedGet('/chats'))['conversations'] ?? [];
  }

  Future<List<dynamic>> getMessages(String bookingId) async {
    return (await _authenticatedGet('/chats/$bookingId'))['messages'] ?? [];
  }

  Future<void> markChatAsRead(String bookingId) async {
    await _authenticatedPut('/chats/$bookingId/read', {});
  }

  Future<void> sendMessage(String bookingId, String content) async {
    await _authenticatedPost('/chats/message', {
      "booking_id": bookingId,
      "content": content,
    });
  }

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
    return (await _authenticatedGet('/swap-requests/incoming'))['swaps'] ?? [];
  }

  Future<List<dynamic>> getOutgoingSwaps() async {
    return (await _authenticatedGet('/swap-requests/outgoing'))['swaps'] ?? [];
  }

  Future<List<dynamic>> getSwapBoard() async {
    return (await _authenticatedGet('/swap-requests/board'))['board'] ?? [];
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

  Future<Map<String, dynamic>> acceptSwap(
    String swapId, {
    String? targetServiceId,
    String? scheduledTime,
  }) async {
    return await _authenticatedPut('/swap-requests/$swapId/accept', {
      if (targetServiceId != null) 'target_service_id': targetServiceId,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
    });
  }

  Future<void> declineSwap(String swapId) async {
    await _authenticatedPut('/swap-requests/$swapId/decline', {});
  }

  Future<void> cancelSwap(String swapId) async {
    await _authenticatedPut('/swap-requests/$swapId/cancel', {});
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

  Future<List<dynamic>> getFeeds() async {
    final data = await _authenticatedGet('/feeds/posts');
    return data is List ? data : [];
  }

  Future<List<dynamic>> getEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/feeds/events'));
    return await _processResponse(response); // Now returns the List correctly
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
    final response = await http.get(
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

  // Inside ApiService class...

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _withNetworkGuard(() async {
      String? token = await storage.read(key: 'jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/auth/update-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "current_password": oldPassword,
          "new_password": newPassword,
        }),
      );

      await _processResponse(response);
    });
  }

  // Get Nearby Places (Auto-fills from Google/OSM)
  Future<List<dynamic>> getNearbyPlaces(double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/places/nearby?lat=$lat&lng=$lng'),
    );
    final data = await _processResponse(response);
    return data['places'] ?? [];
  }

  Future<List<dynamic>> getPopularPlaces(double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/places/popular?lat=$lat&lng=$lng'),
    );
    final data = await _processResponse(response);
    return data['places'] ?? [];
  }

  Future<List<dynamic>> getGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/feeds/groups'));
    return await _processResponse(response);
  }

  Future<void> joinGroup(String groupId) async {
    await _authenticatedPost('/feeds/groups/$groupId/join', {});
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
  //   final response = await http.get(
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
  }

  // Delete a group post
  Future<void> deleteGroupPost(String postId) async {
    await _authenticatedDelete('/feeds/groups/posts/$postId');
  }

  // Delete a feed post (owner or admin)
  Future<void> deletePost(String postId) async {
    await _authenticatedDelete('/feeds/posts/$postId');
  }

  // Delete own comment on a feed post
  Future<void> deleteComment(String postId, String commentId) async {
    await _authenticatedDelete('/feeds/posts/$postId/comments/$commentId');
  }

  // Delete own comment on a group post
  Future<void> deleteGroupComment(String postId, String commentId) async {
    await _authenticatedDelete('/feeds/groups/posts/$postId/comments/$commentId');
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
      print("Error getting current user ID: $e");
      return null;
    }
  }

  // ADD THIS METHOD to your ApiService class in api_service.dart
  // Place it right next to your existing buyEventTicket method
  // (around line 290 in your file, in the SOCIAL FEEDS & EVENTS section)

  Future<Map<String, dynamic>> buyTicket({
    required String eventId,
    required int quantity,
    required double totalPrice,
  }) async {
    return await _authenticatedPost('/feeds/events/buy-ticket', {
      "event_id": eventId,
      "quantity": quantity,
      "total_price": totalPrice,
    });
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
    return await _authenticatedGet('/ai/opportunities');
  }

  // Module 2.5/2.6 — AI Discovery Engine
  Future<Map<String, dynamic>> getAiDiscovery() async {
    return await _authenticatedGet('/ai/discovery');
  }

  // Module 2.5/2.7 — AI City Pulse
  Future<Map<String, dynamic>> getCityPulse({
    double? lat,
    double? lng,
    required String city,
    required String localTime,
  }) async {
    return await _authenticatedPost('/ai/city-pulse', {
      'lat': lat,
      'lng': lng,
      'city': city,
      'local_time': localTime,
    });
  }
}
