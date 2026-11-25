import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class LifeKitLoader extends StatefulWidget {
  /// When true, a "Connecting to secure server…" hint appears after 3 seconds.
  /// Useful on screens that perform a live network fetch (not cache-first).
  final bool showSlowHint;

  const LifeKitLoader({super.key, this.showSlowHint = true});

  @override
  State<LifeKitLoader> createState() => _LifeKitLoaderState();
}

class _LifeKitLoaderState extends State<LifeKitLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  bool _showHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
    _bounce = CurvedAnimation(parent: _controller, curve: Curves.linear);

    // After 3 s of spinning, hint the user the server is waking up
    if (widget.showSlowHint) {
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showHint = true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouncing logo: hops up, squashes on landing, shadow breathes below.
          SizedBox(
            width: 80,
            height: 96,
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) {
                final t = _bounce.value; // 0..1, one hop
                final height = math.sin(t * math.pi); // 0 at ground, 1 at top
                final squash = t < 0.12 || t > 0.88 ? 1 - (1 - height) * 0.18 : 1.0;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Shadow shrinks as the logo rises.
                    Container(
                      width: 44 - 18 * height,
                      height: 8 - 3 * height,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18 - 0.1 * height),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Positioned(
                      bottom: 6 + 30 * height,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(2 - squash, squash, 1),
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Image.asset('assets/images/forloading.png', width: 52, height: 52),
            ),
          ),

          // Slow-connection hint fades in after 3 s
          AnimatedOpacity(
            opacity: _showHint ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                children: [
                  Text(
                    'Connecting to secure server…',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This may take a few seconds on first load.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
