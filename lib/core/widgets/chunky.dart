import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Duolingo-style "3D" button shape: a darker ledge along the bottom edge that
/// disappears while the button is pressed, so it feels like it sinks.
///
/// Filled buttons get a translucent dark ledge (works on any colour);
/// outlined buttons get a thick bottom border in their outline colour.
class LedgeBorder extends OutlinedBorder {
  final BorderRadiusGeometry borderRadius;

  /// Ledge height in logical pixels (capped to a share of the button height).
  final double depth;

  const LedgeBorder({
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.depth = 4,
    super.side,
  });

  RRect _rrect(Rect rect, TextDirection? dir) => borderRadius.resolve(dir).toRRect(rect);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection).deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rr = _rrect(rect, textDirection);
    final ledge = math.min(depth, rect.height * 0.11);
    if (ledge > 0.3) {
      canvas.save();
      canvas.clipRRect(rr);
      final color = side.style == BorderStyle.none
          ? const Color(0x38000000)
          : side.color;
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.bottom - ledge, rect.right, rect.bottom),
        Paint()..color = color,
      );
      canvas.restore();
    }
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRRect(rr.deflate(side.width / 2), side.toPaint());
    }
  }

  @override
  LedgeBorder copyWith({BorderSide? side, BorderRadiusGeometry? borderRadius, double? depth}) =>
      LedgeBorder(
        side: side ?? this.side,
        borderRadius: borderRadius ?? this.borderRadius,
        depth: depth ?? this.depth,
      );

  @override
  ShapeBorder scale(double t) => LedgeBorder(
        side: side.scale(t),
        borderRadius: borderRadius * t,
        depth: depth * t,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is LedgeBorder) {
      return LedgeBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, borderRadius, t)!,
        depth: lerpDouble(a.depth, depth, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is LedgeBorder) {
      return LedgeBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(borderRadius, b.borderRadius, t)!,
        depth: lerpDouble(depth, b.depth, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is LedgeBorder &&
      other.side == side &&
      other.borderRadius == borderRadius &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(side, borderRadius, depth);
}

/// Gives any button style the chunky press-down look. Keeps the style's own
/// corner radius and outline; leaves circles and other special shapes alone.
ButtonStyle chunky(ButtonStyle style) {
  final base = style.shape?.resolve(const <WidgetState>{});
  BorderRadiusGeometry radius = const BorderRadius.all(Radius.circular(16));
  var side = BorderSide.none;
  if (base is RoundedRectangleBorder) {
    radius = base.borderRadius;
    side = base.side;
  } else if (base is StadiumBorder) {
    radius = const BorderRadius.all(Radius.circular(999));
    side = base.side;
  } else if (base is LedgeBorder) {
    radius = base.borderRadius;
    side = base.side;
  } else if (base != null) {
    return style; // circle, beveled, etc.
  }
  return style.copyWith(
    animationDuration: const Duration(milliseconds: 90),
    shape: WidgetStateProperty.resolveWith((states) {
      final flat = states.contains(WidgetState.pressed) || states.contains(WidgetState.disabled);
      return LedgeBorder(borderRadius: radius, side: side, depth: flat ? 0 : 4);
    }),
  );
}
