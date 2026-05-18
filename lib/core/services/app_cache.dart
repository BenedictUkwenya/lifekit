/// Simple in-memory TTL cache for API responses.
///
/// Usage:
///   AppCache.instance.set('user_profile', data, ttl: Duration(minutes: 5));
///   final cached = AppCache.instance.get<Map>('user_profile');
///   AppCache.instance.invalidate('user_profile');
class AppCache {
  AppCache._();
  static final AppCache instance = AppCache._();

  final Map<String, _CacheEntry> _store = {};

  // ── Default TTLs ──────────────────────────────────────────────────────────
  static const Duration ttlShort = Duration(minutes: 1); // counts, chats
  static const Duration ttlMedium = Duration(minutes: 3); // feeds, stats
  static const Duration ttlLong = Duration(minutes: 5); // profile, wallet
  static const Duration ttlStatic = Duration(minutes: 30); // categories

  // ── Core API ──────────────────────────────────────────────────────────────

  void set(String key, dynamic value, {Duration ttl = ttlLong}) {
    _store[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  /// Returns the cached value, or null if missing/expired.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  bool has(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  void invalidate(String key) => _store.remove(key);

  /// Removes all keys that start with [prefix].
  void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Clears everything (e.g. on logout).
  void clear() => _store.clear();
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
