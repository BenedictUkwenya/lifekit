import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet.
///
/// Always passes [sharePositionOrigin]: iPad — and iPhone on iOS 26, where the
/// share sheet is a popover — refuses to open without an on-screen anchor, so
/// a plain `Share.share(text)` silently did nothing there. [context] should be
/// the tapped widget (or its card); its box becomes the anchor.
Future<void> shareText(BuildContext context, String text, {String? subject}) async {
  HapticFeedback.selectionClick();
  Rect? origin;
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.size != Size.zero) {
    origin = box.localToGlobal(Offset.zero) & box.size;
  }
  // Fall back to the middle of the screen so the rect is never empty.
  if (origin == null || origin.isEmpty) {
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
    origin = Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
  }
  await Share.share(text.trim(), subject: subject, sharePositionOrigin: origin);
}
