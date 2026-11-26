import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// How money works in the app, in one place.
///
/// [inAppPayments]: LifeKit does not take or hold payments yet. Clients book
/// in the app and pay the provider directly (cash, card machine or bank
/// transfer). Holding money in a wallet needs a payment licence in Georgia and
/// Stripe can't pay out to Georgian providers. When a licensed partner is
/// integrated, flip this together with IN_APP_PAYMENTS on the backend.
///
/// [showUpgrades]: paid plans and boosts were bought from the wallet, so they
/// are hidden while in-app payments are off. Apple also requires them to be
/// sold through In-App Purchase on iOS (guideline 3.1.1).
///
/// Note for later: adding Google sign-in on iOS also requires adding
/// Sign in with Apple (guideline 4.8).
class StoreRules {
  static const bool inAppPayments = false;

  static bool get showUpgrades =>
      inAppPayments && (kIsWeb || !Platform.isIOS);

  /// True when this booking's money was held in LifeKit wallets (bookings made
  /// before direct payments). Those keep their refund / payout wording.
  static bool heldInApp(Map<String, dynamic>? booking) =>
      booking?['payment_method'] == 'wallet' &&
      (double.tryParse('${booking?['total_price']}') ?? 0) > 0;
}
