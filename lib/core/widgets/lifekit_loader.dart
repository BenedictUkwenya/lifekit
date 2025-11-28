import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LifeKitLoader extends StatefulWidget {
  const LifeKitLoader({super.key});

  @override
  State<LifeKitLoader> createState() => _LifeKitLoaderState();
}

class _LifeKitLoaderState extends State<LifeKitLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Create the controller (repeats every 1.5 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Reverses makes it "breathe" in and out

    // 2. Scale Animation (Grow from 80% to 100% size)
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 3. Opacity Animation (Fade from 50% to 100% opacity)
    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
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
                  // If you don't have a logo image yet, this Circle works as a placeholder
                  // color: AppColors.primary,
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
                  // REPLACE 'assets/images/logo_white.png' WITH YOUR ACTUAL LOGO PATH
                  // If you want to use an Icon instead:
                  // child: Icon(Icons.water_drop, color: Colors.white, size: 30),
                  child: Image.asset(
                    'assets/images/forloading.png', // Make sure this exists!
                    // Tint the logo if it's black/white
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
