import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// "Just now", "5m ago", "3h ago", "2d ago" — then a short date — in the
/// user's language.
String formatTimeAgo(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context);
  final local = date.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
  return DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(local);
}

/// Same as [formatTimeAgo] for raw timestamps; empty when unparseable.
String formatTimeAgoRaw(BuildContext context, Object? raw) {
  final dt = DateTime.tryParse('${raw ?? ''}');
  return dt == null ? '' : formatTimeAgo(context, dt);
}
