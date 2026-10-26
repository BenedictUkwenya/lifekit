import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/error_handler.dart';
import '../../core/widgets/app_toast.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../profile/screens/wallet_screen.dart';
import '../provider/screens/select_main_category_screen.dart';
import '../services/screens/services_list_screen.dart';

/// Whether a plan task has a screen to jump to.
bool planActionAvailable(String route) =>
    const {'profile', 'create_service', 'explore', 'wallet'}.contains(route);

/// Opens the screen for a 7-day-plan task's `action_route`.
///
/// The profile editor is always opened with the user's *real* profile —
/// opening it empty and saving would wipe their name, username and bio.
Future<void> openPlanAction(BuildContext context, String route) async {
  final nav = Navigator.of(context);
  Widget? screen;
  switch (route) {
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
    case 'explore':
      screen = const ServicesListScreen();
    case 'wallet':
      screen = const WalletScreen();
  }
  if (screen != null) nav.push(MaterialPageRoute(builder: (_) => screen!));
}
