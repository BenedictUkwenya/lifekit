import 'package:flutter/material.dart';

/// Shimmering placeholder block. Wrap several in [SkeletonList] (or build
/// your own layout) to show the *shape* of content while it loads.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDF0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Applies a moving highlight across everything inside [child].
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(_c.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double t;
  const _SlideGradient(this.t);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// Ready-made list skeleton: [count] cards with an avatar/thumbnail and two
/// text lines — matches most list screens in the app.
class SkeletonList extends StatelessWidget {
  final int count;
  final double thumbSize;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.count = 6,
    this.thumbSize = 56,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SkeletonBox(width: thumbSize, height: thumbSize, radius: 14),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14, width: 160),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
