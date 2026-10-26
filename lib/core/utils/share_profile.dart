import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';

/// Opens the system share sheet to recommend a provider on LifeKit.
Future<void> shareProviderProfile(BuildContext context, String? name) async {
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final who = (name ?? '').trim().isEmpty ? l10n.blockedUserFallbackName : name!.trim();
  final box = context.findRenderObject() as RenderBox?;
  await Share.share(
    l10n.shareProviderText(who, 'https://www.lifekithub.com'),
    subject: l10n.shareProviderSubject(who),
    // iPad needs an anchor for the share popover.
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}
