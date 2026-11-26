import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifekit_frontend/core/theme/app_theme.dart';
import 'package:lifekit_frontend/features/bookings/widgets/booking_payment_card.dart';
import 'package:lifekit_frontend/features/profile/screens/payment_details_screen.dart';
import 'package:lifekit_frontend/l10n/app_localizations.dart';

const _iban = 'GE29NB0000000101904917';

Widget _app(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child)),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('IBAN', () {
    test('valid and invalid numbers', () {
      expect(isValidIban(_iban), isTrue);
      expect(isValidIban('ge29 nb00 0000 0101 9049 17'), isTrue); // spaces + lowercase
      expect(isValidIban('GE29NB0000000101904918'), isFalse); // checksum
      expect(isValidIban('GE29NB00000001019049'), isFalse); // Georgian IBANs are 22 chars
      expect(isValidIban('GB82WEST12345698765432'), isTrue); // foreign IBAN
      expect(isValidIban(''), isFalse);
    });
    test('formats in blocks of four', () {
      expect(formatIban('ge29nb0000000101904917'), 'GE29 NB00 0000 0101 9049 17');
    });
  });

  final pending = {'id': 'b1', 'status': 'pending', 'total_price': 25};
  final confirmed = {'id': 'b1', 'status': 'confirmed', 'total_price': 25};
  const methods = {'cash': true, 'card': false, 'transfer': true};
  const bank = {'bank_name': 'TBC Bank', 'account_holder': 'Nino Beridze', 'iban': _iban};

  for (final locale in const [Locale('en'), Locale('ka'), Locale('ru')]) {
    final lc = locale.languageCode;

    Future<AppLocalizations> pump(WidgetTester t, Map booking, bool isClient, Map<String, dynamic> data) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(locale, BookingPaymentCard(
          booking: booking, isClient: isClient, otherName: 'Nino', debugData: data)));
      await t.pump();
      expect(t.takeException(), isNull, reason: 'no overflow ($lc)');
      return AppLocalizations.delegate.load(locale);
    }

    testWidgets('client, pending: methods shown, bank hidden ($lc)', (t) async {
      final l = await pump(t, pending, true, {'methods': methods, 'bank': null, 'bank_hidden_reason': 'not_accepted'});
      expect(find.text(l.payMethodCash), findsOneWidget);
      expect(find.text(l.payMethodTransfer), findsOneWidget);
      expect(find.text(l.payBankAfterAccept('Nino')), findsOneWidget);
      expect(find.textContaining('GE29'), findsNothing);
      expect(find.byKey(const Key('pay_mark_paid')), findsNothing); // not before acceptance
    });

    testWidgets('client, accepted: bank details, copy, safety tip, I\'ve paid ($lc)', (t) async {
      final l = await pump(t, confirmed, true, {'methods': methods, 'bank': bank});
      expect(find.text('GE29 NB00 0000 0101 9049 17'), findsOneWidget);
      expect(find.text('Nino Beridze'), findsOneWidget);
      expect(find.byKey(const Key('pay_copy_iban')), findsOneWidget);
      expect(find.text(l.paySafetyTip), findsOneWidget);
      expect(find.byKey(const Key('pay_mark_paid')), findsOneWidget);
    });

    testWidgets('client marked paid, then provider confirmed ($lc)', (t) async {
      var l = await pump(t, confirmed, true, {'methods': methods, 'bank': bank, 'client_marked_paid_at': '2026-11-26T10:00:00Z'});
      expect(find.text(l.payMarkedPaid('Nino')), findsOneWidget);
      expect(find.byKey(const Key('pay_mark_paid')), findsNothing);
      l = await pump(t, confirmed, true, {'methods': methods, 'bank': null, 'bank_hidden_reason': 'paid',
          'client_marked_paid_at': '2026-11-26T10:00:00Z', 'provider_confirmed_paid_at': '2026-11-26T11:00:00Z'});
      expect(find.text(l.payConfirmedDone), findsOneWidget);
      expect(find.textContaining('GE29'), findsNothing);
    });

    testWidgets('provider without details is asked to add them ($lc)', (t) async {
      final l = await pump(t, confirmed, false, {'methods': {'cash': false, 'card': false, 'transfer': false}});
      expect(find.text(l.payAddYourDetails), findsOneWidget);
      expect(find.text(l.payAddDetailsButton), findsOneWidget);
      expect(find.byKey(const Key('pay_mark_received')), findsOneWidget);
    });

    testWidgets('provider sees the client says they paid ($lc)', (t) async {
      final l = await pump(t, confirmed, false, {'methods': methods, 'client_marked_paid_at': '2026-11-26T10:00:00Z'});
      expect(find.text(l.payClientSaysPaid('Nino')), findsOneWidget);
      expect(find.byKey(const Key('pay_mark_received')), findsOneWidget);
      expect(find.textContaining('GE29'), findsNothing); // providers don't get bank data back here
    });
  }
}
