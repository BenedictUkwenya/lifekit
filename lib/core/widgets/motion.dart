import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared motion vocabulary so the whole app moves the same way.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;

  /// Delay for the [index]-th item of a staggered list (capped so long lists
  /// don't make the user wait).
  static Duration stagger(int index, {int stepMs = 55}) =>
      Duration(milliseconds: (index.clamp(0, 8)) * stepMs);
}

extension MotionX on Widget {
  /// Fade + rise into place. Use [index] for staggered lists.
  Widget fadeSlideIn({int index = 0, double dy = 0.08}) => animate(
        delay: Motion.stagger(index),
      )
          .fadeIn(duration: Motion.medium, curve: Motion.curve)
          .slideY(begin: dy, end: 0, duration: Motion.medium, curve: Motion.curve);

  /// Pop in with a gentle overshoot — for icons, badges, success marks.
  Widget popIn({Duration delay = Duration.zero}) => animate(delay: delay)
      .fadeIn(duration: Motion.fast)
      .scale(
        begin: const Offset(0.6, 0.6),
        end: const Offset(1, 1),
        duration: Motion.slow,
        curve: Curves.elasticOut,
      );
}

/// Shrinks slightly while pressed and gives a light haptic tick — makes any
/// card or tile feel tactile. Pass [onTap] = null to disable.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onLongPress: widget.onLongPress,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

/// A number that counts up/down smoothly when [value] changes.
class AnimatedCount extends StatelessWidget {
  final double value;
  final String Function(double v) format;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.slow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Motion.curve,
      builder: (_, v, _) => Text(format(v), style: style),
    );
  }
}

/// Soft infinite pulse — draws attention to "your turn" states.
class Pulse extends StatelessWidget {
  final Widget child;
  final bool active;

  const Pulse({super.key, required this.child, this.active = true});

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }
}
