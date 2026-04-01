import 'dart:async';
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _showHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

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
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Image.asset('assets/images/forloading.png'),
                    ),
                  ),
                ),
              );
            },
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
