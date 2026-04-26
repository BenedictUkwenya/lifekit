import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';

/// Shows a beautiful bottom sheet asking the user to Book or Skill Swap.
///
/// [isSwappable] – the service has is_skill_swap_available == true.
/// [preferSwap]  – visually emphasise the Swap option (used inside Swap Hub).
/// [onBook]      – callback when user picks "Book Service".
/// [onSwap]      – callback when user picks "Skill Swap".
void showServiceActionSheet({
  required BuildContext context,
  required String serviceTitle,
  required String providerName,
  String? coverImageUrl,
  required bool isSwappable,
  bool preferSwap = false,
  required VoidCallback onBook,
  required VoidCallback onSwap,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ServiceActionSheet(
      serviceTitle: serviceTitle,
      providerName: providerName,
      coverImageUrl: coverImageUrl,
      isSwappable: isSwappable,
      preferSwap: preferSwap,
      onBook: onBook,
      onSwap: onSwap,
    ),
  );
}

class _ServiceActionSheet extends StatelessWidget {
  final String serviceTitle;
  final String providerName;
  final String? coverImageUrl;
  final bool isSwappable;
  final bool preferSwap;
  final VoidCallback onBook;
  final VoidCallback onSwap;

  const _ServiceActionSheet({
    required this.serviceTitle,
    required this.providerName,
    required this.coverImageUrl,
    required this.isSwappable,
    required this.preferSwap,
    required this.onBook,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    // Which card comes first / is bigger
    final swapFirst = preferSwap && isSwappable;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── drag handle ──
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── service preview row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: coverImageUrl != null && coverImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverImageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by $providerName',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSwappable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A020).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔄 Swappable',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE8A020),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Divider(height: 1),
          ),

          // ── headline ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              'What would you like to do?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),

          // ── action cards ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: swapFirst
                ? Column(
                    children: [
                      _SwapCard(
                        onTap: () {
                          Navigator.pop(context);
                          onSwap();
                        },
                      ),
                      const SizedBox(height: 10),
                      _BookCard(
                        onTap: () {
                          Navigator.pop(context);
                          onBook();
                        },
                        slim: true,
                      ),
                    ],
                  )
                : isSwappable
                ? Row(
                    children: [
                      Expanded(
                        child: _BookCard(
                          onTap: () {
                            Navigator.pop(context);
                            onBook();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SwapCard(
                          onTap: () {
                            Navigator.pop(context);
                            onSwap();
                          },
                        ),
                      ),
                    ],
                  )
                // Not swappable — only book
                : _BookCard(
                    full: true,
                    onTap: () {
                      Navigator.pop(context);
                      onBook();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.home_repair_service_rounded,
      color: AppColors.primary.withOpacity(0.4),
      size: 24,
    ),
  );
}

// ── Book card ──────────────────────────────────────────────
class _BookCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool slim;
  final bool full;
  const _BookCard({required this.onTap, this.slim = false, this.full = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: slim ? 56 : null,
        width: full ? double.infinity : null,
        padding: slim
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: slim
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Book Service',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Book Service',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Pay & schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Swap card ──────────────────────────────────────────────
class _SwapCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SwapCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8A020), Color(0xFFF5C842)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8A020).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✨ No cash',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Skill Swap',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'Trade skills, no money',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
