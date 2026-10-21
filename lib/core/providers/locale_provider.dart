import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Holds the currently active [Locale] for the whole app.
///
/// Usage in a widget:
///   final localeProvider = context.read<LocaleProvider>();
///   localeProvider.setLocale(const Locale('ka'));
///
/// The choice is persisted in SharedPreferences under the key 'app_locale'
/// so it survives app restarts.
class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'app_locale';
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ka'),
    Locale('ru'),
  ];

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// Call this once during app startup to restore the saved preference.
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final l = Locale(saved);
      if (supportedLocales.contains(l)) {
        _locale = l;
        ApiService.setLang(l.languageCode);
        notifyListeners();
      }
    }
  }

  /// Change the active locale and persist the preference.
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    _locale = locale;
    ApiService.setLang(locale.languageCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
  }

  /// Returns a human-readable label for the current locale.
  String get currentLanguageLabel {
    switch (_locale.languageCode) {
      case 'ka':
        return 'ქართული';
      case 'ru':
        return 'Русский';
      default:
        return 'English';
    }
  }

  /// Returns a short code label (EN / KA / RU).
  String get currentLanguageCode => _locale.languageCode.toUpperCase();
}
