import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'motion.dart';

enum _ToastType { success, error, info }

/// Animated top toast used across the app.
/// `AppToast.success(context, msg)` / `.error` / `.info`.
/// Only one toast shows at a time; swipe up or tap to dismiss.
class AppToast {
  static OverlayEntry? _current;

  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastType.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastType.info);

  static void _show(BuildContext context, String message, _ToastType type) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _current?.remove();
    type == _ToastType.error
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.lightImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _slide = Tween<double>(begin: -40, end: 0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 3500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _toastConfig(widget.type);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slide.value + _drag),
          child: Opacity(opacity: _fade.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          onTap: _dismiss,
          onVerticalDragUpdate: (d) {
            if (d.delta.dy < 0 || _drag < 0) {
              setState(() => _drag = (_drag + d.delta.dy).clamp(-80.0, 0.0));
            }
          },
          onVerticalDragEnd: (_) {
            if (_drag < -24) {
              _dismiss();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cfg.bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cfg.borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: cfg.shadowColor.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cfg.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cfg.icon, color: cfg.iconColor, size: 20),
                  ).popIn(delay: const Duration(milliseconds: 120)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cfg.textColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: cfg.textColor.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastConfig {
  final Color bgColor, borderColor, shadowColor, iconBg, iconColor, textColor;
  final IconData icon;

  const _ToastConfig({
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

_ToastConfig _toastConfig(_ToastType type) {
  switch (type) {
    case _ToastType.success:
      return const _ToastConfig(
        bgColor: Color(0xFFEDFDF5),
        borderColor: Color(0xFFABEFC4),
        shadowColor: Color(0xFF12B76A),
        iconBg: Color(0xFFD1FADF),
        iconColor: Color(0xFF039855),
        textColor: Color(0xFF054F31),
        icon: Icons.check_circle_outline_rounded,
      );
    case _ToastType.error:
      return const _ToastConfig(
        bgColor: Color(0xFFFFF1F0),
        borderColor: Color(0xFFFFCCC7),
        shadowColor: Color(0xFFFF4D4F),
        iconBg: Color(0xFFFFE2E0),
        iconColor: Color(0xFFD92D20),
        textColor: Color(0xFF7A1B17),
        icon: Icons.error_outline_rounded,
      );
    case _ToastType.info:
      return const _ToastConfig(
        bgColor: Color(0xFFF0F5FF),
        borderColor: Color(0xFFADC6FF),
        shadowColor: Color(0xFF1D4ED8),
        iconBg: Color(0xFFDBEAFE),
        iconColor: Color(0xFF1D4ED8),
        textColor: Color(0xFF1E3A5F),
        icon: Icons.info_outline_rounded,
      );
  }
}
