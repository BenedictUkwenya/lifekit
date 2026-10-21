part of 'api_service.dart';

/// Platform-admin endpoints (mirrors the web admin dashboard).
/// Every `/admin/*` route is guarded server-side by `adminMiddleware`.
extension AdminApi on ApiService {
  List<dynamic> _asList(dynamic data) => data is List ? data : const [];
  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};

  /// Whether the signed-in user is a platform admin (uses the cached profile).
  Future<bool> isPlatformAdmin() async {
    try {
      final data = await getUserProfile();
      final profile = data['profile'];
      return profile is Map && profile['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  // ── Overview & analytics ────────────────────────────────────────────────
  /// Counts for the admin home. Falls back to the older `/admin/stats`
  /// endpoint when talking to a backend that predates `/admin/overview`.
  Future<Map<String, dynamic>> adminOverview() async {
    try {
      return _asMap(await _authenticatedGet('/admin/overview'));
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      return _asMap(await _authenticatedGet('/admin/stats'));
    }
  }

  Future<Map<String, dynamic>> adminAnalytics() async =>
      _asMap(await _authenticatedGet('/admin/analytics'));

  /// [period] is one of `weekly`, `monthly`, `yearly`.
  Future<List<dynamic>> adminActivityChart(String period) async =>
      _asList(await _authenticatedGet('/admin/activities/chart?period=$period'));

  Future<void> adminWithdraw(double amount, String destination) =>
      _authenticatedPost('/admin/withdraw', {
        'amount': amount,
        'destination': destination,
      });

  // ── Service reviews ─────────────────────────────────────────────────────
  Future<List<dynamic>> adminServicesQueue() async =>
      _asList(await _authenticatedGet('/admin/services-queue'));

  /// [status] is `active` (approve) or `rejected`.
  Future<void> adminReviewService(String id, String status, {String? reason}) =>
      _authenticatedPut('/admin/review-service/$id', {
        'status': status,
        'reason': ?reason,
      });

  // ── Bookings ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> adminBookings({int limit = 100}) async =>
      _asMap(await _authenticatedGet('/admin/bookings/all?limit=$limit'));

  Future<void> adminNudgeBooking(String id) =>
      _authenticatedPost('/admin/bookings/$id/nudge', {});

  // ── Users ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> adminUsers() async =>
      _asList(await _authenticatedGet('/admin/users/all'));

  /// [status] is one of `active`, `suspended`, `blocked`.
  Future<void> adminSetUserStatus(String id, String status) =>
      _authenticatedPut('/admin/users/$id/status', {'status': status});

  Future<void> adminNotifyUser(String userId, String title, String message) =>
      _authenticatedPost('/admin/notifications/send', {
        'user_id': userId,
        'title': title,
        'message': message,
      });

  // ── Disputes ────────────────────────────────────────────────────────────
  Future<List<dynamic>> adminDisputes() async =>
      _asList(await _authenticatedGet('/admin/disputes'));

  /// [verdict] is `refund_client` or `pay_provider`.
  Future<void> adminResolveDispute(String bookingId, String verdict) =>
      _authenticatedPost('/admin/disputes/$bookingId/resolve', {
        'verdict': verdict,
      });

  // ── Support & reports ───────────────────────────────────────────────────
  Future<List<dynamic>> adminSupportTickets() async =>
      _asList(await _authenticatedGet('/admin/support'));

  Future<void> adminReplyTicket(String id, String reply) =>
      _authenticatedPut('/admin/support/$id/reply', {'reply': reply});

  Future<List<dynamic>> adminReports() async =>
      _asList(await _authenticatedGet('/admin/reports'));

  Future<void> adminResolveReport(String id) =>
      _authenticatedPut('/admin/reports/$id/resolve', {});

  // ── Categories & requests ───────────────────────────────────────────────
  Future<List<dynamic>> adminCategories() async =>
      _asList(await _authenticatedGet('/admin/categories'));

  Future<void> adminCreateCategory({
    required String name,
    String? description,
    String? parentId,
  }) => _authenticatedPost('/admin/categories', {
    'name': name,
    'description': ?description,
    'parent_id': ?parentId,
  });

  Future<void> adminDeleteCategory(String id) =>
      _authenticatedDelete('/admin/categories/$id');

  Future<List<dynamic>> adminCategoryRequests() async =>
      _asList(await _authenticatedGet('/admin/category-requests'));

  Future<void> adminApproveCategoryRequest(
    String id, {
    required String name,
    String? parentId,
  }) => _authenticatedPost('/admin/category-requests/$id/approve', {
    'name': name,
    'parent_id': ?parentId,
  });

  Future<void> adminRejectCategoryRequest(String id) =>
      _authenticatedDelete('/admin/category-requests/$id/reject');

  // ── Admin team ──────────────────────────────────────────────────────────
  Future<List<dynamic>> adminTeam() async =>
      _asList(await _authenticatedGet('/admin/users/admins'));

  Future<void> adminInvite({
    required String email,
    required String password,
    required String fullName,
  }) => _authenticatedPost('/admin/users/invite-admin', {
    'email': email,
    'password': password,
    'full_name': fullName,
  });

  Future<void> adminRemove(String id) =>
      _authenticatedDelete('/admin/users/admins/$id');

  // ── Content: events, posts, groups ──────────────────────────────────────
  Future<List<dynamic>> adminEvents() async =>
      _asList(await _authenticatedGet('/events'));

  Future<void> adminCreateEvent(Map<String, dynamic> event) async {
    await _authenticatedPost('/events', event);
    AppCache.instance.invalidate('events');
  }

  Future<void> adminSetEventActive(String id, bool isActive) =>
      _authenticatedPut('/events/$id/status', {'is_active': isActive});

  Future<void> adminSetEventFeatured(String id, bool isFeatured) =>
      _authenticatedPut('/events/$id/featured', {'is_featured': isFeatured});

  Future<void> adminDeleteEvent(String id) async {
    await _authenticatedDelete('/events/$id');
    AppCache.instance.invalidate('events');
  }

  /// Uncached — moderation must always see the live feed.
  Future<List<dynamic>> adminPosts() async =>
      _asList(await _authenticatedGet('/feeds/posts'));

  Future<void> adminDeletePost(String id) async {
    await _authenticatedDelete('/feeds/posts/$id');
    AppCache.instance.invalidate('feeds');
  }

  Future<List<dynamic>> adminGroups() async =>
      _asList(await _authenticatedGet('/feeds/groups'));

  Future<void> adminDeleteGroup(String id) =>
      _authenticatedDelete('/feeds/groups/admin/$id');
}
