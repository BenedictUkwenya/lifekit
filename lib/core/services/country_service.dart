import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Works out which country the user is in right now (for the header flag).
///
/// Order: three free IP-geolocation services (each can rate-limit or time
/// out), then the phone's region setting. The last answer is cached so the
/// flag shows instantly on the next launch and is then refreshed.
class CountryService {
  CountryService._();

  static const _prefsKey = 'current_country_code';
  static String? _session; // resolved this app run
  static Future<String>? _inFlight;

  /// Last known code (cache or device region) without any network call.
  static Future<String> cached() async {
    if (_session != null) return _session!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (_valid(saved)) return saved!;
    } catch (_) {}
    return _deviceRegion() ?? 'GE';
  }

  /// Current country code, looked up once per app run.
  static Future<String> current() {
    if (_session != null) return Future.value(_session);
    return _inFlight ??= _resolve().whenComplete(() => _inFlight = null);
  }

  static Future<String> _resolve() async {
    final lookups = <Future<String?> Function()>[
      () => _fetch('https://ipapi.co/json/?fields=country_code', 'country_code'),
      () => _fetch('https://api.country.is/', 'country'),
      () => _fetch('https://ipwho.is/?fields=country_code', 'country_code'),
    ];
    String? code;
    for (final lookup in lookups) {
      code = await lookup();
      if (code != null) break;
    }
    code ??= await cached();
    _session = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
    return code;
  }

  static Future<String?> _fetch(String url, String field) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final code = (jsonDecode(res.body) as Map<String, dynamic>)[field]
          ?.toString()
          .toUpperCase()
          .trim();
      return _valid(code) ? code : null;
    } catch (_) {
      return null;
    }
  }

  static String? _deviceRegion() {
    final code = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    return _valid(code) ? code : null;
  }

  static bool _valid(String? c) =>
      c != null && c.length == 2 && c.codeUnits.every((u) => u >= 0x41 && u <= 0x5A);

  /// "NG" -> 🇳🇬
  static String flagEmoji(String code) {
    final c = _valid(code.toUpperCase()) ? code.toUpperCase() : 'GE';
    return String.fromCharCodes(c.codeUnits.map((u) => u - 0x41 + 0x1F1E6));
  }
}
