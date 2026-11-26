import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen photos: swipe between them, pinch or double-tap to zoom,
/// swipe down (or tap ✕) to close.
class PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const PhotoViewer({super.key, required this.urls, this.initialIndex = 0});

  static Future<void> open(BuildContext context, List<String> urls, {int index = 0}) {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => PhotoViewer(urls: urls, initialIndex: index),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _zoom = TransformationController();
  double _dragY = 0;

  bool get _zoomed => _zoom.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails d) {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
    } else {
      // Zoom 2.5× around the tapped point.
      const s = 2.5;
      final p = d.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fade = (1 - (_dragY.abs() / 400)).clamp(0.3, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: fade),
      body: Stack(
        children: [
          GestureDetector(
            // Swipe down to dismiss (only when not zoomed in).
            onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _dragY += d.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    if (_dragY.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _dragY = 0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(0, _dragY),
              child: PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.urls.length,
                onPageChanged: (i) {
                  _zoom.value = Matrix4.identity();
                  setState(() => _index = i);
                },
                itemBuilder: (_, i) => GestureDetector(
                  onDoubleTapDown: _toggleZoom,
                  onDoubleTap: () {},
                  child: InteractiveViewer(
                    transformationController: i == _index ? _zoom : null,
                    minScale: 1,
                    maxScale: 4,
                    onInteractionEnd: (_) => setState(() {}),
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.urls[i],
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                        ),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (widget.urls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text('${_index + 1} / ${widget.urls.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
