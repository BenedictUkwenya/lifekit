import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../admin_strings.dart';

/// Design tokens shared with the web admin dashboard (tailwind.config.js).
class AdminPalette {
  static const primary = AppColors.primary; // #89273B
  static const primaryDark = Color(0xFF722030);
  static const canvas = Color(0xFFFAFAFA);
  static const border = Color(0xFFF1F1F3);
  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const textFaint = Color(0xFF9CA3AF);

  // Stat-card tints from the web dashboard
  static const tintRose = Color(0xFFF9E3E3);
  static const tintIndigo = Color(0xFFE3E6F9);
  static const tintAmber = Color(0xFFF9F3E3);
  static const tintMint = Color(0xFFE3F9E9);
  static const banner = Color(0xFFF3E8E8);

  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFA16207);
  static const warningBg = Color(0xFFFEF9C3);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE2E2);
  static const info = Color(0xFF1D4ED8);
  static const infoBg = Color(0xFFDBEAFE);
  static const neutral = Color(0xFF374151);
  static const neutralBg = Color(0xFFF3F4F6);
}

TextStyle adminText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AdminPalette.textDark,
  double? height,
}) => GoogleFonts.poppins(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

// ── Formatting helpers ──────────────────────────────────────────────────────
String adminMoney(dynamic value) {
  final n = value is num ? value : num.tryParse('$value') ?? 0;
  return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(n);
}

String adminCompact(dynamic value) {
  final n = value is num ? value : num.tryParse('$value') ?? 0;
  return NumberFormat.compact().format(n);
}

String adminDate(BuildContext context, dynamic iso, {bool withTime = false}) {
  final dt = iso == null ? null : DateTime.tryParse('$iso')?.toLocal();
  if (dt == null) return '—';
  final lang = Localizations.localeOf(context).languageCode;
  return DateFormat(withTime ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy', lang)
      .format(dt);
}

/// Short human reference for UUIDs, matching the web's `LYFxxxx` style.
String adminRef(dynamic id) {
  final s = '${id ?? ''}';
  return s.length < 4 ? '#$s' : 'LYF${s.substring(0, 4).toUpperCase()}';
}

String adminErrorText(Object e) => friendlyError(e);

// ── Feedback helpers ────────────────────────────────────────────────────────
void adminToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: adminText(13, color: Colors.white)),
        backgroundColor: error ? AdminPalette.danger : AdminPalette.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

/// Runs [action], showing a success or error toast. Returns true on success.
Future<bool> adminRun(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) adminToast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) adminToast(context, adminErrorText(e), error: true);
    return false;
  }
}

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final t = AdminStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: adminText(17, weight: FontWeight.w600)),
      content: Text(
        message,
        style: adminText(14, color: AdminPalette.textMuted, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('cancel'), style: adminText(14, color: AdminPalette.textMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AdminPalette.danger : AdminPalette.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: adminText(14, weight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    ),
  );
  return result == true;
}

/// Bottom sheet with a drag handle and title — the mobile equivalent of the
/// web dashboard's slide-over panels.
Future<T?> showAdminSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: adminText(18, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AdminPalette.textMuted,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: builder(ctx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Layout widgets ──────────────────────────────────────────────────────────
class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminPalette.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: AdminPalette.textDark,
        title: Text(title, style: adminText(18, weight: FontWeight.w700)),
        actions: actions,
        bottom: bottom,
        shape: const Border(bottom: BorderSide(color: AdminPalette.border)),
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminPalette.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AdminStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final String? caption;
  final VoidCallback? onTap;

  const AdminStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AdminPalette.textDark),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: adminText(22, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: adminText(12, color: AdminPalette.textMuted),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AdminPalette.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  caption!,
                  style: adminText(10, color: AdminPalette.textFaint),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Coloured status badge. Known statuses are translated; others shown as-is.
class AdminStatusPill extends StatelessWidget {
  final String status;
  final String? label;

  const AdminStatusPill(this.status, {super.key, this.label});

  static (Color, Color) colorsFor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'closed':
      case 'resolved':
      case 'success':
      case 'approved':
        return (AdminPalette.success, AdminPalette.successBg);
      case 'pending':
      case 'open':
      case 'overdue':
        return (AdminPalette.warning, AdminPalette.warningBg);
      case 'rejected':
      case 'cancelled':
      case 'blocked':
      case 'disputed':
      case 'failed':
        return (AdminPalette.danger, AdminPalette.dangerBg);
      case 'confirmed':
      case 'suspended':
      case 'featured':
        return (AdminPalette.info, AdminPalette.infoBg);
      default:
        return (AdminPalette.neutral, AdminPalette.neutralBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(status);
    final t = AdminStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label ?? t.status(status),
        style: adminText(11, weight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AdminAvatar extends StatelessWidget {
  final String? url;
  final String? name;
  final double radius;

  const AdminAvatar({super.key, this.url, this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initials = (name ?? '?')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final hasUrl = url != null && url!.startsWith('http');
    return CircleAvatar(
      radius: radius,
      backgroundColor: AdminPalette.tintRose,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      child: hasUrl
          ? null
          : Text(
              initials.isEmpty ? '?' : initials,
              style: adminText(
                radius * 0.7,
                weight: FontWeight.w600,
                color: AdminPalette.primary,
              ),
            ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const AdminEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AdminPalette.tintRose,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AdminPalette.primary),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: adminText(14, color: AdminPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: adminText(14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: adminText(14, color: AdminPalette.textFaint),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AdminPalette.textFaint,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminPalette.primary),
        ),
      ),
    );
  }
}

/// Horizontally scrolling single-select chips (key → label).
class AdminFilterBar extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(e.key),
              labelStyle: adminText(
                12,
                weight: FontWeight.w600,
                color: isSelected ? Colors.white : AdminPalette.textMuted,
              ),
              selectedColor: AdminPalette.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AdminPalette.primary : AdminPalette.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AdminSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AdminSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: adminText(16, weight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Labelled value used inside detail sheets (web: uppercase grey label).
class AdminField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const AdminField(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: adminText(
              10,
              weight: FontWeight.w600,
              color: AdminPalette.textFaint,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: adminText(
              15,
              weight: FontWeight.w600,
              color: valueColor ?? AdminPalette.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;

  const AdminTextInput({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: adminText(14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: adminText(13, color: AdminPalette.textMuted),
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AdminPalette.primary),
          ),
        ),
      ),
    );
  }
}

/// Primary / outlined / destructive action buttons used in sheets.
class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool destructive;
  final bool busy;
  final IconData? icon;

  const AdminButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.destructive = false,
    this.busy = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AdminPalette.danger : AdminPalette.primary;
    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? color : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(
                    14,
                    weight: FontWeight.w600,
                    color: outlined ? color : Colors.white,
                  ),
                ),
              ),
            ],
          );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const padding = EdgeInsets.symmetric(vertical: 14, horizontal: 16);
    return outlined
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.35)),
              shape: shape,
              padding: padding,
            ),
            child: child,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: shape,
              padding: padding,
            ),
            child: child,
          );
  }
}

/// Loads data with [load], showing a skeleton, an error with retry, and
/// pull-to-refresh. [builder] receives the data and a `reload` callback.
class AdminLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload)
  builder;

  const AdminLoader({super.key, required this.load, required this.builder});

  @override
  State<AdminLoader<T>> createState() => _AdminLoaderState<T>();
}

class _AdminLoaderState<T> extends State<AdminLoader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const _AdminSkeleton();
    if (_error != null && _data == null) {
      final t = AdminStrings.of(context);
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AdminPalette.textFaint,
          ),
          const SizedBox(height: 12),
          Text(
            adminErrorText(_error!),
            textAlign: TextAlign.center,
            style: adminText(14, color: AdminPalette.textMuted),
          ),
          const SizedBox(height: 16),
          Center(
            child: AdminButton(
              label: t('retry'),
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() => _loading = true);
                _reload();
              },
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: AdminPalette.primary,
      onRefresh: _reload,
      child: widget.builder(context, _data as T, _reload),
    );
  }
}

class _AdminSkeleton extends StatefulWidget {
  const _AdminSkeleton();

  @override
  State<_AdminSkeleton> createState() => _AdminSkeletonState();
}

class _AdminSkeletonState extends State<_AdminSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Container(
          height: i == 0 ? 110 : 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AdminPalette.border),
          ),
        ),
      ),
    );
  }
}
