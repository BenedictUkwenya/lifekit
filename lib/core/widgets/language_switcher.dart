import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

/// A compact three-button language toggle (EN | KA | RU).
///
/// Drop it anywhere — app bar, settings screen, drawer, etc.
///
/// Example:
///   const LanguageSwitcher()
///   LanguageSwitcher(variant: LanguageSwitcherVariant.light) // on dark bg
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({
    super.key,
    this.variant = LanguageSwitcherVariant.dark,
  });

  final LanguageSwitcherVariant variant;

  static const _langs = [
    _LangOption('en', 'EN', 'English'),
    _LangOption('ka', 'KA', 'ქართული'),
    _LangOption('ru', 'RU', 'Русский'),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final current  = provider.locale.languageCode;
    final theme    = Theme.of(context);
    const primary  = Color(0xFF89273B);

    final bgColor = variant == LanguageSwitcherVariant.light
        ? Colors.white.withOpacity(0.15)
        : Colors.grey.shade100;

    final activeText = variant == LanguageSwitcherVariant.light
        ? Colors.black87
        : Colors.white;

    final activeBg = variant == LanguageSwitcherVariant.light
        ? Colors.white
        : primary;

    final inactiveText = variant == LanguageSwitcherVariant.light
        ? Colors.white.withOpacity(0.7)
        : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _langs.map((lang) {
          final isActive = current == lang.code;
          return GestureDetector(
            onTap: () {
              context.read<LocaleProvider>().setLocale(Locale(lang.code));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                lang.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeText : inactiveText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

enum LanguageSwitcherVariant { light, dark }

class _LangOption {
  const _LangOption(this.code, this.label, this.nativeLabel);
  final String code;
  final String label;
  final String nativeLabel;
}
