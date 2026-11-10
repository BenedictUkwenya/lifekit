import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// App Store rules that differ from Google Play.
///
/// [showUpgrades]: Apple requires paid plans, boosts and AI tools to be sold
/// through Apple In-App Purchase (guideline 3.1.1). Until that exists, the
/// iOS app neither sells nor advertises them. Flip this once it does.
///
/// Note for later: adding Google sign-in on iOS also requires adding
/// Sign in with Apple (guideline 4.8).
class StoreRules {
  static bool get showUpgrades => kIsWeb || !Platform.isIOS;
}
