import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifekit_frontend/core/providers/cart_provider.dart';
import 'package:lifekit_frontend/core/theme/app_theme.dart';
import 'package:lifekit_frontend/features/bookings/screens/payment_screen.dart';
import 'package:lifekit_frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final locale in const [Locale('en'), Locale('ka'), Locale('ru')]) {
    testWidgets('checkout asks clients to pay the provider directly (${locale.languageCode})', (t) async {
      // iPhone 13/14 width, iPhone SE height — the tightest common screen.
      t.view.physicalSize = const Size(390 * 3, 667 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);

      final item = CartItem(
        id: '1',
        serviceId: 'svc',
        title: 'Professional Home & Office Cleaning Services',
        price: 25,
        imageUrl: '',
        providerId: 'p',
        date: DateTime.now().add(const Duration(days: 2)),
        time: const TimeOfDay(hour: 10, minute: 0),
        serviceType: 'Default',
      );

      await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: MaterialApp(
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaymentScreen(itemsToBook: [item]),
        ),
      ));
      await t.pump(const Duration(milliseconds: 300));

      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.text(l10n.directPayTitle), findsOneWidget);
      expect(find.text(l10n.directPayBody), findsOneWidget);
      expect(find.text(l10n.checkoutSendRequest), findsOneWidget);
      expect(find.text(l10n.checkoutTitle), findsOneWidget);
      // No wallet anywhere on the screen.
      expect(find.text(l10n.txLifekitWallet), findsNothing);
      expect(find.textContaining('Balance'), findsNothing);
      // No layout overflow.
      expect(t.takeException(), isNull);
    });
  }
}
