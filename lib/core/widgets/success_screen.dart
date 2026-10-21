import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/// Full-screen celebration: a self-drawing check mark inside a growing
/// circle, a confetti burst, then a title, subtitle and up to two actions.
class SuccessScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const SuccessScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _check.forward();
      _burst.forward();
    });
  }

  @override
  void dispose() {
    _check.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) (widget.onSecondary ?? widget.onPrimary)();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _burst,
                        builder: (_, _) => CustomPaint(
                          size: const Size(220, 220),
                          painter: _ConfettiPainter(_burst.value),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _check,
                        builder: (_, _) => CustomPaint(
                          size: const Size(120, 120),
                          painter: _CheckPainter(_check.value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ).fadeSlideIn(index: 6),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14.5, color: Colors.grey[600], height: 1.5),
                ).fadeSlideIn(index: 7),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(onPressed: widget.onPrimary, child: Text(widget.primaryLabel)),
                ).fadeSlideIn(index: 8),
                if (widget.secondaryLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: widget.onSecondary, child: Text(widget.secondaryLabel!))
                      .fadeSlideIn(index: 8),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Circle grows with a slight overshoot during the first half
    final circleT = Curves.easeOutBack.transform((t * 1.8).clamp(0.0, 1.0));
    canvas.drawCircle(c, r * circleT, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(
      c,
      r * circleT + 10 * (1 - circleT),
      Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.18 * circleT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    // Check mark draws itself in the second half
    final checkT = Curves.easeOut.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));
    if (checkT <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * checkT),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    AppColors.primary,
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final rnd = math.Random(7); // fixed seed: same pleasing pattern every time
    final eased = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < 26; i++) {
      final angle = (i / 26) * 2 * math.pi + rnd.nextDouble() * 0.4;
      final dist = (70 + rnd.nextDouble() * 40) * eased;
      final pos = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist + 30 * t * t);
      final paint = Paint()..color = _colors[i % _colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + t * 6);
      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -2.5, 10, 5), const Radius.circular(2)),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 3.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
