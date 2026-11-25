import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Brand-recoloured Lottie animations (see LOTTIE_CREDITS.md).
enum AppAnim {
  success('success'),
  confetti('confetti'),
  handshake('handshake'),
  stars('stars'),
  wallet('wallet'),
  emptyBox('empty_box'),
  chat('chat'),
  search('search'),
  cat('cat');

  final String file;
  const AppAnim(this.file);
  String get asset => 'assets/lottie/$file.json';
}

/// Plays an [AppAnim]. Respects the system "reduce motion" setting by showing
/// the final frame instead of animating.
class AppLottie extends StatelessWidget {
  final AppAnim anim;
  final double? size;
  final bool repeat;
  final BoxFit fit;

  const AppLottie(this.anim, {super.key, this.size, this.repeat = true, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Lottie.asset(
      anim.asset,
      width: size,
      height: size,
      fit: fit,
      repeat: repeat && !still,
      animate: !still,
      frameRate: FrameRate.max,
      // A broken file should never break the screen around it.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
