import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // CONFIGURATION: Switches between local and production automatically
  final String baseUrl = kIsWeb
      ? "http://localhost:3000"
      : "http://10.0.2.2:3000";

  // UNCOMMENT FOR PRODUCTION
  //final String baseUrl = "https://lifekit-api.onrender.com";

  final storage = const FlutterSecureStorage();

  // ===========================================================================
  // INTERNAL AUTH HELPERS (The "Engine")
  // ===========================================================================

  Future<void> _saveTokens(String access, String refresh) async {
    await storage.write(key: 'jwt_token', value: access);
    await storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> _refreshToken() async {
    try {
      final refresh = await storage.read(key: 'refresh_token');
      if (refresh == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": refresh}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access_token'], data['refresh_token']);
        return data['access_token'];
      }
      await storage.deleteAll(); // Force logout if refresh fails
      return null;
    } catch (e) {
      return null;
    }
  }

  // Wrapper for GET requests that need a token
  Future<dynamic> _authenticatedGet(String endpoint) async {
    String? token = await storage.read(key: 'jwt_token');
    var response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      String? newToken = await _refreshToken();
      if (newToken != null) {
        response = await http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Authorization': 'Bearer $newToken'},
        );
      } else {
        throw Exception("Session Expired");
      }
    }
    return _processResponse(response);
  }

  // Wrapper for POST requests that need a token
  Future<dynamic> _authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    String? token = await storage.read(key: 'jwt_token');
    var response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      String? newToken = await _refreshToken();
      if (newToken != null) {
        response = await http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode(body),
        );
      } else {
        throw Exception("Session Expired");
      }
    }
    return _processResponse(response);
  }

  // Wrapper for PUT requests that need a token
  Future<dynamic> _authenticatedPut(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    String? token = await storage.read(key: 'jwt_token');
    var response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      String? newToken = await _refreshToken();
      if (newToken != null) {
        response = await http.put(
          Uri.parse('$baseUrl$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode(body),
        );
      } else {
        throw Exception("Session Expired");
      }
    }
    return _processResponse(response);
  }

  // Wrapper for DELETE requests
  Future<dynamic> _authenticatedDelete(String endpoint) async {
    String? token = await storage.read(key: 'jwt_token');
    var response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      String? newToken = await _refreshToken();
      if (newToken != null) {
        response = await http.delete(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Authorization': 'Bearer $newToken'},
        );
      } else {
        throw Exception("Session Expired");
      }
    }
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    // Keep your debug print so you can see what's happening in the console
    print("SERVER RESPONSE [${response.statusCode}]: ${response.body}");

    // 1. Parse the body safely
    Map<String, dynamic>? bodyData;
    try {
      // We try to decode once at the top to avoid repeating jsonDecode calls
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        bodyData = decoded;
      }
    } catch (_) {
      // If body isn't JSON (like an HTML error page), bodyData remains null
    }

    // 2. Handle Success (200 - 299)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return bodyData;
    }

    // 3. Handle Errors (Extract the specific message from backend)
    // Fallback to a generic status code message if the JSON 'error' key is missing
    String errorMessage =
        bodyData?['error'] ?? "Server Error: ${response.statusCode}";

    // 4. Smart Session Handling
    // Special case for 401/403: If the error message does NOT contain the word "password",
    // we assume the JWT token is invalid or expired.
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        !errorMessage.toLowerCase().contains("password")) {
      throw Exception("Session Expired. Please login again.");
    }

    // 5. Throw specific exception
    // This allows your UI to catch and show messages like "Incorrect current password"
    throw Exception(errorMessage);
  }
  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "full_name": name,
        "email": email,
        "password": password,
      }),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );
    final data = _processResponse(response);
    if (data.containsKey('session')) {
      await _saveTokens(
        data['session']['access_token'],
        data['session']['refresh_token'],
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "token": token}),
    );
    final data = _processResponse(response);
    if (data.containsKey('session')) {
      await _saveTokens(
        data['session']['access_token'],
        data['session']['refresh_token'],
      );
    }
    return data;
  }

  // ===========================================================================
  // PROFILE & USER
  // ===========================================================================

  Future<Map<String, dynamic>> getUserProfile() async {
    return await _authenticatedGet('/users/profile');
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

  // ===========================================================================
  // HOME & SERVICES (PUBLIC & SEARCH)
  // ===========================================================================

  Future<List<dynamic>> getOffers() async {
    final response = await http.get(Uri.parse('$baseUrl/home/offers'));
    final data = _processResponse(response);
    return data['offers'] ?? [];
  }

  Future<List<dynamic>> getCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/home/categories'));
    final data = _processResponse(response);
    return data['categories'] ?? [];
  }

  Future<List<dynamic>> getPopularServices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/popular-services'),
    );
    final data = _processResponse(response);
    return data['services'] ?? [];
  }

  Future<List<dynamic>> getRecentSearches() async {
    final data = await _authenticatedGet('/home/recent-searches');
    return data['recent_searches'] ?? [];
  }

  Future<List<dynamic>> getServicesByCategory(String categoryId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/category/$categoryId'),
    );
    final data = _processResponse(response);
    return data['services'] ?? [];
  }

  Future<Map<String, dynamic>> getProviderServices(String providerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/provider/$providerId'),
    );
    return _processResponse(response);
  }

  Future<List<dynamic>> getSubCategories(String parentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/categories/children/$parentId'),
    );
    final data = _processResponse(response);
    return data['categories'] ?? [];
  }

  Future<Map<String, dynamic>> search(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/search?query=$query'),
    );
    return _processResponse(response);
  }

  Future<List<dynamic>> searchCategories(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/home/categories/search/dropdown?query=$query'),
    );
    final data = _processResponse(response);
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

  Future<List<dynamic>> getReviews(String serviceId) async {
    return (await _authenticatedGet('/reviews/$serviceId'))['reviews'] ?? [];
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

  Future<void> sendMessage(String bookingId, String content) async {
    await _authenticatedPost('/chats/message', {
      "booking_id": bookingId,
      "content": content,
    });
  }

  // ===========================================================================
  // SOCIAL FEEDS & EVENTS
  // ===========================================================================

  Future<List<dynamic>> getFeeds() async {
    final response = await http.get(Uri.parse('$baseUrl/feeds/posts'));
    return _processResponse(response);
  }

  Future<List<dynamic>> getEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/feeds/events'));
    return _processResponse(response);
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

  Future<void> toggleLike(String postId) async {
    await _authenticatedPost('/feeds/posts/$postId/like', {});
  }

  Future<List<dynamic>> getComments(String postId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/feeds/posts/$postId/comments'),
    );
    return _processResponse(response);
  }

  Future<dynamic> postComment(String postId, String content) async {
    return await _authenticatedPost('/feeds/posts/$postId/comments', {
      "content": content,
    });
  }

  // Inside ApiService class...

  Future<void> changePassword(String oldPassword, String newPassword) async {
    String? token = await storage.read(key: 'jwt_token');

    final response = await http.put(
      Uri.parse('$baseUrl/auth/update-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "current_password": oldPassword, // Added this
        "new_password": newPassword, // Added this
      }),
    );

    _processResponse(response);
  }

  // Get Nearby Places (Auto-fills from Google/OSM)
  Future<List<dynamic>> getNearbyPlaces(double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/places/nearby?lat=$lat&lng=$lng'),
    );
    final data = _processResponse(response);
    return data['places'] ?? [];
  }

  Future<List<dynamic>> getPopularPlaces(double lat, double lng) async {
    final response = await http.get(
      Uri.parse('$baseUrl/places/popular?lat=$lat&lng=$lng'),
    );
    final data = _processResponse(response);
    return data['places'] ?? [];
  }
}
