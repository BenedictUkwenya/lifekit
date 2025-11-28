import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // CHANGE THIS TO YOUR IP IF USING PHYSICAL DEVICE (e.g., "http://192.168.1.5:3000")
  //final String baseUrl = "http://10.0.2.2:3000";
  final String baseUrl = "https://lifekit-api.onrender.com";

  final storage = const FlutterSecureStorage();

  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  // 1. Signup
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

  // 2. Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );

    final data = _processResponse(response);

    if (data.containsKey('session')) {
      await storage.write(
        key: 'jwt_token',
        value: data['session']['access_token'],
      );
    }
    return data;
  }

  // 3. Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String email, String token) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "token": token}),
    );

    final data = _processResponse(response);
    if (data.containsKey('session')) {
      await storage.write(
        key: 'jwt_token',
        value: data['session']['access_token'],
      );
    }
    return data;
  }

  // ===========================================================================
  // PROFILE & USER
  // ===========================================================================

  // 4. Get User Profile
  Future<Map<String, dynamic>> getUserProfile() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _processResponse(response);
  }

  // 5. Update Profile (UPDATED for new fields)
  Future<void> updateProfile({
    String? fullName,
    String? imageUrl,
    String? username,
    String? phone,
    String? bio,
  }) async {
    String? token = await storage.read(key: 'jwt_token');

    // Build body dynamically
    final Map<String, dynamic> body = {};
    if (fullName != null) body['full_name'] = fullName;
    if (imageUrl != null) body['profile_picture_url'] = imageUrl;
    if (username != null) body['username'] = username;
    if (phone != null) body['phone_number'] = phone;
    if (bio != null) body['bio'] = bio;

    if (body.isEmpty) return; // Nothing to update

    final response = await http.put(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw Exception('Failed to update profile');
    }
  }

  // 6. Upload Profile Picture (Two steps: Upload -> Update Profile DB)
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
      String imageUrl = responseData['url'];
      // Update the profile with the new URL
      await updateProfile(imageUrl: imageUrl);
    } else {
      throw Exception('Failed to upload image');
    }
  }

  // 7. Onboard as Provider
  Future<void> onboardAsProvider() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.put(
      Uri.parse('$baseUrl/users/onboard-provider'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _processResponse(response);
  }

  // ===========================================================================
  // HOME & SERVICES (PUBLIC)
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
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/home/recent-searches'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
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
      Uri.parse('$baseUrl/home/categories/$parentId'),
    );
    final data = _processResponse(response);
    return data['categories'] ?? [];
  }

  // ===========================================================================
  // PROVIDER MANAGEMENT
  // ===========================================================================

  Future<List<dynamic>> getMyServices() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/services/my-services'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['services'] ?? [];
  }

  Future<void> createDraftServices(List<String> categoryIds) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/services'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"category_ids": categoryIds, "currency": "USD"}),
    );
    _processResponse(response);
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

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }

  // ===========================================================================
  // BOOKINGS
  // ===========================================================================

  Future<void> createBooking({
    required String serviceId,
    required String scheduledTime,
    required String locationDetails,
    required double totalPrice,
  }) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "service_id": serviceId,
        "scheduled_time": scheduledTime,
        "location_details": locationDetails,
        "total_price": totalPrice,
      }),
    );
    _processResponse(response);
  }

  Future<List<dynamic>> getClientBookings() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/bookings/client'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['bookings'] ?? [];
  }

  Future<List<dynamic>> getProviderRequests() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/bookings/provider'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['requests'] ?? [];
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"status": status}),
    );
    _processResponse(response);
  }

  Future<void> completeBooking(String bookingId) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.put(
      Uri.parse('$baseUrl/bookings/$bookingId/complete'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _processResponse(response);
  }

  // ===========================================================================
  // WALLET & PAYMENTS
  // ===========================================================================

  Future<Map<String, dynamic>> getWallet() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/wallet'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> initDeposit(double amount) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/wallet/deposit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"amount": amount}),
    );
    return _processResponse(response);
  }

  Future<void> confirmDeposit(String paymentIntentId) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/wallet/confirm-deposit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"paymentIntentId": paymentIntentId}),
    );
    _processResponse(response);
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<List<dynamic>> getNotifications() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/users/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['notifications'] ?? [];
  }

  // ===========================================================================
  // HELPER
  // ===========================================================================

  dynamic _processResponse(http.Response response) {
    print("SERVER RESPONSE [${response.statusCode}]: ${response.body}");

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Unknown Server Error');
      } catch (e) {
        throw Exception("Server Error: ${response.statusCode}");
      }
    }
  }

  // ... inside ApiService class

  // ===========================================================================
  // CHAT
  // ===========================================================================

  Future<List<dynamic>> getConversations() async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/chats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['conversations'] ?? [];
  }

  Future<List<dynamic>> getMessages(String bookingId) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/chats/$bookingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _processResponse(response);
    return data['messages'] ?? [];
  }

  Future<void> sendMessage(String bookingId, String content) async {
    String? token = await storage.read(key: 'jwt_token');
    await http.post(
      Uri.parse('$baseUrl/chats/message'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"booking_id": bookingId, "content": content}),
    );
  }

  // ... in ApiService class

  // Get messages for multiple bookings (Grouped chat)
  Future<List<dynamic>> getChatHistory(List<String> bookingIds) async {
    String? token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/chats/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"booking_ids": bookingIds}),
    );
    final data = _processResponse(response);
    return data['messages'] ?? [];
  }

  // ... existing sendMessage and getConversations remain similar
}
