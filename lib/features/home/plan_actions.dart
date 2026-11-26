import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/store_rules.dart';
import '../../core/widgets/app_toast.dart';
import '../../l10n/app_localizations.dart';
import '../bookings/screens/bookings_screen.dart';
import '../groups/screens/communities_screen.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../profile/screens/payment_details_screen.dart';
import '../profile/screens/wallet_screen.dart';
import '../provider/screens/my_services_list_screen.dart';
import '../provider/screens/select_main_category_screen.dart';
import '../services/screens/services_list_screen.dart';
import 'screens/feeds_screen.dart';

/// Every screen a 7-day-plan task can open (must match the backend list).
const planRoutes = {
  'profile',
  'create_service',
  'my_services',
  'explore',
  'feeds',
  'communities',
  'bookings',
  'payment_details',
};

/// Old plans told providers to "set up your wallet". LifeKit doesn't hold
/// money any more, so those tasks become "add your payment details".
bool isLegacyWalletTask(String route, String task) =>
    !StoreRules.inAppPayments &&
    (route == 'wallet' || RegExp(r'wallet|საფულ|кошел', caseSensitive: false).hasMatch(task));

/// The screen a task should open. Tasks Gracy left without a link ("none")
/// get a best guess from their wording, so every task can be acted on.
String resolvePlanRoute(String route, String task) {
  if (isLegacyWalletTask(route, task)) return 'payment_details';
  if (route == 'wallet' && StoreRules.inAppPayments) return 'wallet';
  if (planRoutes.contains(route)) return route;
  final t = task.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(['payment', 'bank', 'iban', 'გადახდ', 'оплат', 'реквизит'])) return 'payment_details';
  if (has(['availability', 'performance', 'your service', 'listing', 'price', 'update your', 'სერვის', 'услуг', 'расписан'])) {
    return 'my_services';
  }
  if (has(['create', 'first service', 'შექმენი', 'создай'])) return 'create_service';
  if (has(['community', 'communities', 'group', 'introduce', 'join', 'საზოგადოებ', 'сообществ', 'групп'])) return 'communities';
  if (has(['reach out', 'post', 'share', 'feed', 'clients', 'partners', 'გამოაქვეყნ', 'опубликуй', 'клиент'])) return 'feeds';
  if (has(['booking', 'request', 'ჯავშ', 'брон'])) return 'bookings';
  if (has(['profile', 'photo', 'bio', 'პროფილ', 'профил'])) return 'profile';
  if (has(['explore', 'discover', 'browse', 'find', 'იპოვე', 'найди'])) return 'explore';
  return 'none';
}

/// Task text to show: old "set up your wallet" tasks read as payment details.
String planTaskText(BuildContext context, String route, String task) =>
    isLegacyWalletTask(route, task) ? AppLocalizations.of(context).planTaskPaymentDetails : task;

/// Whether a plan task has a screen to jump to.
bool planActionAvailable(String route, [String task = '']) =>
    resolvePlanRoute(route, task) != 'none';

/// Opens the screen for a 7-day-plan task.
///
/// The profile editor is always opened with the user's *real* profile —
/// opening it empty and saving would wipe their name, username and bio.
Future<void> openPlanAction(BuildContext context, String route, [String task = '']) async {
  final nav = Navigator.of(context);
  Widget? screen;
  switch (resolvePlanRoute(route, task)) {
    case 'profile':
      try {
        final data = await ApiService().getUserProfile();
        final profile = data['profile'];
        if (profile is! Map) throw Exception('Profile not found');
        screen = EditProfileScreen(profile: Map<String, dynamic>.from(profile));
      } catch (e) {
        if (context.mounted) AppToast.error(context, appErrorMessage(context, e));
        return;
      }
    case 'create_service':
      screen = const SelectMainCategoryScreen();
    case 'my_services':
      screen = const MyServicesListScreen();
    case 'explore':
      screen = const ServicesListScreen();
    case 'feeds':
      screen = const FeedsScreen();
    case 'communities':
      screen = const CommunitiesScreen();
    case 'bookings':
      screen = const BookingsScreen();
    case 'payment_details':
      screen = const PaymentDetailsScreen();
    case 'wallet':
      screen = const WalletScreen();
  }
  if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen!));
}
