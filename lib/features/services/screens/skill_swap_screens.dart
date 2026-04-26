import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/service_action_sheet.dart';
import '../../profile/screens/provider_profile_screen.dart';
import 'service_booking_detail_screen.dart';

// ═══════════════════════════════════════════════════════════
// COLOURS & CONSTANTS
// ═══════════════════════════════════════════════════════════
const _kGold = Color(0xFFE8A020);
const _kBlue = Color(0xFF3B82F6);

// ═══════════════════════════════════════════════════════════
// 1. INPUT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class SkillSwapBottomSheet extends StatefulWidget {
  final String? initialTargetCategoryId;
  final String? initialTargetCategoryName;
  final String? initialTargetCoverImageUrl;
  // Direct proposal — when opened from a specific service card
  final String? initialTargetServiceId;
  final String? initialTargetProviderId;
  final String? initialTargetProviderName;
  final String? initialTargetServiceTitle;
  final String? initialTargetProviderPic;
  const SkillSwapBottomSheet({
    super.key,
    this.initialTargetCategoryId,
    this.initialTargetCategoryName,
    this.initialTargetCoverImageUrl,
    this.initialTargetServiceId,
    this.initialTargetProviderId,
    this.initialTargetProviderName,
    this.initialTargetServiceTitle,
    this.initialTargetProviderPic,
  });

  @override
  State<SkillSwapBottomSheet> createState() => _SkillSwapBottomSheetState();
}

class _SkillSwapBottomSheetState extends State<SkillSwapBottomSheet>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<dynamic> myServices = [];
  Map<String, dynamic>? selectedMyService;
  Map<String, dynamic>? selectedTargetSubCategory;
  String selectedServiceType = 'Home';
  bool isLoadingData = true;
  String? _targetCoverImageUrl;

  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _fetchMyServices();
    // Pre-fill target if launched from a specific service card
    if (widget.initialTargetCategoryId != null &&
        widget.initialTargetCategoryName != null) {
      selectedTargetSubCategory = {
        'id': widget.initialTargetCategoryId!,
        'name': widget.initialTargetCategoryName!,
      };
    }
    _targetCoverImageUrl = widget.initialTargetCoverImageUrl;
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _fetchMyServices() async {
    try {
      final services = await _apiService.getMyServices();
      if (mounted) {
        setState(() {
          myServices = services;
          if (myServices.isNotEmpty) selectedMyService = myServices[0];
          isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingData = false);
    }
  }

  void _startSearch() {
    if (selectedMyService == null) {
      _showSnack('Please select a service you want to offer.', isError: true);
      return;
    }
    if (selectedTargetSubCategory == null) {
      _showSnack('Please select a skill you are looking for.', isError: true);
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FindingMatchAnimationScreen(
          myService: selectedMyService!,
          targetCategoryId: selectedTargetSubCategory!['id'],
          targetCategoryName: selectedTargetSubCategory!['name'],
          serviceType: selectedServiceType,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _startDirectProposal() {
    if (selectedMyService == null) {
      _showSnack('Please select a service you want to offer.', isError: true);
      return;
    }
    final targetMatch = {
      'id': widget.initialTargetServiceId,
      'provider_id': widget.initialTargetProviderId,
      'title':
          widget.initialTargetServiceTitle ??
          widget.initialTargetCategoryName ??
          'Service',
      'profiles': {
        'full_name': widget.initialTargetProviderName ?? 'Provider',
        'profile_picture_url': widget.initialTargetProviderPic,
      },
      'image_urls': widget.initialTargetCoverImageUrl != null
          ? [widget.initialTargetCoverImageUrl!]
          : [],
      'match_score': 100.0,
      'match_reason': 'Direct service selection',
      'average_rating': 0.0,
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SwapProposalSheet(
        myService: selectedMyService!,
        targetMatch: targetMatch,
        targetCategoryName:
            widget.initialTargetCategoryName ??
            widget.initialTargetServiceTitle ??
            'Service',
        onSent: () {
          Navigator.pop(context); // close proposal sheet
          Navigator.pop(context); // close skill swap sheet
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Skill Swap',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Powered by LifeKit AI',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated floating cards
                  Center(
                    child: AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, __) => SizedBox(
                        height: 150,
                        width: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 20 + _floatAnim.value,
                              child: Transform.rotate(
                                angle: -0.18,
                                child: _buildCardTile(
                                  imageUrls:
                                      selectedMyService?['image_urls'] ?? [],
                                  color: _kGold,
                                  isTarget: false,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 20 - _floatAnim.value,
                              child: Transform.rotate(
                                angle: 0.18,
                                child: _buildCardTile(
                                  imageUrls: _targetCoverImageUrl != null
                                      ? [_targetCoverImageUrl!]
                                      : [],
                                  color: _kBlue,
                                  isTarget: _targetCoverImageUrl == null,
                                ),
                              ),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.swap_horiz,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _buildSelectionChip(
                          label: selectedMyService?['title'] ?? 'Select Yours',
                          filled: true,
                          onTap: _showMyServicesPicker,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sync,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Flexible(
                        child: _buildSelectionChip(
                          label:
                              selectedTargetSubCategory?['name'] ??
                              'Select Target',
                          filled: false,
                          onTap: _showCategoryPicker,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Looking for a skill',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showCategoryPicker,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedTargetSubCategory != null
                              ? AppColors.primary.withOpacity(0.4)
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: selectedTargetSubCategory != null
                                ? AppColors.primary
                                : Colors.grey[400],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedTargetSubCategory?['name'] ??
                                  'Search for a skill\u2026',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: selectedTargetSubCategory != null
                                    ? Colors.black87
                                    : Colors.grey[400],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedTargetSubCategory != null)
                            GestureDetector(
                              onTap: () => setState(
                                () => selectedTargetSubCategory = null,
                              ),
                              child: Icon(
                                Icons.cancel,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            )
                          else
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Select service type',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _serviceTypeBtn('Default', Icons.fingerprint),
                      const SizedBox(width: 10),
                      _serviceTypeBtn('Home', Icons.home_rounded),
                      const SizedBox(width: 10),
                      _serviceTypeBtn('Outdoor', Icons.chair_alt_outlined),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08),
                          _kBlue.withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.55,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Bi-directional AI matching ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'finds providers who want what you offer AND offer what you want.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          // ── STICKY FOOTER BUTTONS ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.initialTargetServiceId != null) ...[
                  // PRIMARY: direct proposal to the specific provider
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _startDirectProposal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.handshake_outlined, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Propose Swap to ${widget.initialTargetProviderName ?? 'Provider'}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // SECONDARY: find other AI matches
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _startSearch,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome_mosaic_outlined,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Find Other AI Matches',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Generic flow: AI match is primary
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _startSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome_mosaic_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Find AI Match',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SwapBoardScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.dashboard_customize_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Browse Swap Board',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile({
    required List imageUrls,
    required Color color,
    required bool isTarget,
  }) {
    final String? imageUrl = (!isTarget && imageUrls.isNotEmpty)
        ? imageUrls[0]
        : null;
    return Container(
      width: 82,
      height: 108,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        image: imageUrl != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: isTarget
          ? const Center(
              child: Icon(Icons.question_mark, color: Colors.white, size: 38),
            )
          : null,
    );
  }

  Widget _buildSelectionChip({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 140),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: filled ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _serviceTypeBtn(String label, IconData icon) {
    final bool selected = selectedServiceType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedServiceType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.grey[500],
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyServicesPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 420,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a skill to offer',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: myServices.isEmpty
                  ? Center(
                      child: Text(
                        'No services found. Create a service first.',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: myServices.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (_, i) {
                        final s = myServices[i];
                        final isImg = (s['image_urls'] as List).isNotEmpty;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: isImg
                                ? CachedNetworkImageProvider(s['image_urls'][0])
                                : null,
                            child: !isImg
                                ? Text(
                                    s['title'][0],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            s['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: selectedMyService?['id'] == s['id']
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            setState(() => selectedMyService = s);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() async {
    try {
      final cats = await _apiService.getCategories();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Skill Category',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: cats.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        cats[i]['name'],
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 13,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _handleCategorySelect(cats[i]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  void _handleCategorySelect(dynamic parentCat) async {
    try {
      final subs = await _apiService.getSubCategories(parentCat['id']);
      if (!mounted) return;
      if (subs.isEmpty) {
        setState(() => selectedTargetSubCategory = parentCat);
      } else {
        _showSubCategoryPicker(subs, parentCat['name']);
      }
    } catch (_) {
      setState(() => selectedTargetSubCategory = parentCat);
    }
  }

  void _showSubCategoryPicker(List subs, String parentName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 420,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Specific skill in $parentName',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: subs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    subs[i]['name'],
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  onTap: () {
                    setState(() => selectedTargetSubCategory = subs[i]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. FINDING MATCH ANIMATION SCREEN
// ═══════════════════════════════════════════════════════════

class _Particle {
  double x, y, vx, vy, size, opacity;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class FindingMatchAnimationScreen extends StatefulWidget {
  final Map<String, dynamic> myService;
  final String targetCategoryId;
  final String targetCategoryName;
  final String serviceType;

  const FindingMatchAnimationScreen({
    super.key,
    required this.myService,
    required this.targetCategoryId,
    required this.targetCategoryName,
    required this.serviceType,
  });

  @override
  State<FindingMatchAnimationScreen> createState() =>
      _FindingMatchAnimationScreenState();
}

class _FindingMatchAnimationScreenState
    extends State<FindingMatchAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<double> _leftX, _rightX, _scale, _leftRot, _rightRot;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale, _pulseOpacity;

  late AnimationController _orbitCtrl;
  late AnimationController _sparkleCtrl;

  late AnimationController _scanCtrl;
  late Animation<double> _scanY;

  late AnimationController _textCtrl;
  int _searchTextIndex = 0;
  final List<String> _searchTexts = [
    'Scanning providers\u2026',
    'Analysing skill fit\u2026',
    'Calculating compatibility\u2026',
    'AI ranking matches\u2026',
    'Almost there\u2026',
  ];
  Timer? _textTimer;

  final List<_Particle> _particles = [];
  late AnimationController _particleCtrl;

  bool _isMatched = false;
  bool _showBurst = false;

  final List<IconData> _orbitIcons = [
    Icons.build_rounded,
    Icons.school_rounded,
    Icons.brush_rounded,
    Icons.restaurant_rounded,
    Icons.fitness_center_rounded,
    Icons.music_note_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _initParticles();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _leftX = Tween<double>(
      begin: -280,
      end: -58,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _rightX = Tween<double>(
      begin: 280,
      end: 58,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: const Interval(0.6, 1.0)),
    );
    _leftRot = Tween<double>(
      begin: 0.4,
      end: -0.15,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _rightRot = Tween<double>(
      begin: -0.4,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseScale = Tween<double>(
      begin: 0.7,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanY = Tween<double>(
      begin: -80,
      end: 80,
    ).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));

    _particleCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 50),
          )
          ..addListener(_updateParticles)
          ..repeat();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _textTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_isMatched || !mounted) return;
      _textCtrl.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() {
          _searchTextIndex = (_searchTextIndex + 1) % _searchTexts.length;
        });
        _textCtrl.reverse();
      });
    });

    _slideCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _isMatched = true;
            _showBurst = true;
          });
          _sparkleCtrl.forward();
          _textTimer?.cancel();
        }
        Timer(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, animation, __) => SkillSwapResultsScreen(
                  myService: widget.myService,
                  targetCategoryId: widget.targetCategoryId,
                  targetCategoryName: widget.targetCategoryName,
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                      position:
                          Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutQuart))
                              .animate(animation),
                      child: child,
                    ),
              ),
            );
          }
        });
      });
    });
  }

  void _initParticles() {
    final rng = math.Random();
    for (int i = 0; i < 35; i++) {
      _particles.add(
        _Particle(
          x: rng.nextDouble() * 400,
          y: rng.nextDouble() * 700,
          vx: (rng.nextDouble() - 0.5) * 1.2,
          vy: (rng.nextDouble() - 0.5) * 1.2,
          size: rng.nextDouble() * 4 + 1.5,
          opacity: rng.nextDouble() * 0.5 + 0.1,
          color: [
            AppColors.primary,
            _kGold,
            _kBlue,
            Colors.purpleAccent,
          ][rng.nextInt(4)],
        ),
      );
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    final rng = math.Random();
    setState(() {
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < 0) p.x = 400;
        if (p.x > 400) p.x = 0;
        if (p.y < 0) p.y = 700;
        if (p.y > 700) p.y = 0;
        p.opacity =
            0.1 +
            math.sin(_particleCtrl.value * math.pi * 2 + rng.nextDouble()) *
                0.2;
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _sparkleCtrl.dispose();
    _scanCtrl.dispose();
    _particleCtrl.dispose();
    _textCtrl.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? myImg = (widget.myService['image_urls'] as List).isNotEmpty
        ? widget.myService['image_urls'][0]
        : null;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Particle field
          ...(_particles.map(
            (p) => Positioned(
              left: p.x,
              top: p.y,
              child: Opacity(
                opacity: p.opacity.clamp(0.0, 1.0),
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          )),

          // Radial gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Pulse rings
          if (!_isMatched)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 200 * _pulseScale.value,
                height: 200 * _pulseScale.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(
                      _pulseOpacity.value.clamp(0.0, 1.0),
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),

          // Orbiting icons
          if (!_isMatched)
            AnimatedBuilder(
              animation: _orbitCtrl,
              builder: (_, __) => SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(_orbitIcons.length, (i) {
                    final angle =
                        _orbitCtrl.value * 2 * math.pi +
                        (i / _orbitIcons.length) * 2 * math.pi;
                    final r = 120.0;
                    final x = math.cos(angle) * r;
                    final y = math.sin(angle) * r;
                    return Positioned(
                      left: 130 + x - 14,
                      top: 130 + y - 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _orbitIcons[i],
                          color: AppColors.primary.withOpacity(0.7),
                          size: 14,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

          // Scanning line
          if (!_isMatched)
            AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, __) => Positioned(
                top: size.height * 0.4 + _scanY.value,
                left: 80,
                right: 80,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Left card
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (_, __) => Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(_leftX.value, 0),
                child: Transform.rotate(
                  angle: _leftRot.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: _buildCard(myImg, _kGold, false),
                  ),
                ),
              ),
            ),
          ),

          // Right card
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (_, __) => Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(_rightX.value, 0),
                child: Transform.rotate(
                  angle: _rightRot.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: _buildCard(null, _kBlue, true),
                  ),
                ),
              ),
            ),
          ),

          // Sparkle burst
          if (_showBurst)
            AnimatedBuilder(
              animation: _sparkleCtrl,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: List.generate(12, (i) {
                  final angle = (i / 12) * 2 * math.pi;
                  final r = _sparkleCtrl.value * 120;
                  final opacity = (1 - _sparkleCtrl.value).clamp(0.0, 1.0);
                  return Positioned(
                    left: size.width / 2 + math.cos(angle) * r - 6,
                    top: size.height / 2 + math.sin(angle) * r - 6,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: [
                            _kGold,
                            AppColors.primary,
                            _kBlue,
                            Colors.purpleAccent,
                          ][i % 4],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Status text
          Positioned(
            bottom: size.height * 0.2,
            left: 40,
            right: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _isMatched
                  ? Column(
                      key: const ValueKey('matched'),
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (_, v, __) => Transform.scale(
                            scale: v,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Match Found!',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Loading your results\u2026',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('searching'),
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _textCtrl,
                          builder: (_, __) => Opacity(
                            opacity: (1 - _textCtrl.value).clamp(0.0, 1.0),
                            child: Text(
                              _searchTexts[_searchTextIndex],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Top badge
          Positioned(
            top: size.height * 0.11,
            child: Column(
              children: [
                Text(
                  'AI matching for',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        _kBlue.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    widget.targetCategoryName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String? url, Color color, bool isQuestion) {
    return Container(
      width: 105,
      height: 138,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        image: url != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: isQuestion
          ? Center(
              child: Icon(
                Icons.auto_awesome,
                color: Colors.white.withOpacity(0.8),
                size: 48,
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 3. RESULTS SCREEN
// ═══════════════════════════════════════════════════════════

class SkillSwapResultsScreen extends StatefulWidget {
  final Map<String, dynamic> myService;
  final String targetCategoryId;
  final String targetCategoryName;

  const SkillSwapResultsScreen({
    super.key,
    required this.myService,
    required this.targetCategoryId,
    required this.targetCategoryName,
  });

  @override
  State<SkillSwapResultsScreen> createState() => _SkillSwapResultsScreenState();
}

class _SkillSwapResultsScreenState extends State<SkillSwapResultsScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  List<dynamic> allMatches = [];
  Map<String, dynamic>? primaryMatch;
  String? currentUserId;
  String currentUserName = 'Me';
  String? currentUserPic;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    final color = isError
        ? Colors.red.shade600
        : isSuccess
        ? Colors.green.shade600
        : const Color(0xFF333333);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _apiService.getAiSkillSwapMatches(
          myServiceId: widget.myService['id'],
          targetCategoryId: widget.targetCategoryId,
        ),
        _apiService.getUserProfile(),
      ]);
      if (mounted) {
        final profileData = results[1] as Map<String, dynamic>;
        currentUserName = profileData['profile']['full_name'] ?? 'Me';
        currentUserId = profileData['profile']['id'];
        currentUserPic = profileData['profile']['profile_picture_url'];
        allMatches = (results[0] as List<dynamic>)
            .where((s) => s['provider_id'] != currentUserId)
            .toList();
        setState(() {
          if (allMatches.isNotEmpty) primaryMatch = allMatches[0];
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _selectMatch(dynamic match) => setState(() => primaryMatch = match);

  void _sendProposal() {
    if (primaryMatch == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SwapProposalSheet(
        myService: widget.myService,
        targetMatch: primaryMatch!,
        targetCategoryName: widget.targetCategoryName,
        onSent: () {
          Navigator.pop(context);
          _showSnack('Swap Proposal Sent!', isSuccess: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (primaryMatch == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No providers found',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different skill category',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final providerName = primaryMatch!['profiles']?['full_name'] ?? 'Unknown';
    final providerPic = primaryMatch!['profiles']?['profile_picture_url'];
    final providerId = primaryMatch!['provider_id'];
    final double rating = (primaryMatch!['average_rating'] is int)
        ? (primaryMatch!['average_rating'] as int).toDouble()
        : (primaryMatch!['average_rating'] ?? 0.0);
    final double matchScore = (primaryMatch!['match_score'] is int)
        ? (primaryMatch!['match_score'] as int).toDouble()
        : (primaryMatch!['match_score'] ?? 50.0);
    final String matchReason =
        primaryMatch!['match_reason'] ?? 'Good complementary match';
    final similarList = allMatches
        .where((s) => s['id'] != primaryMatch!['id'])
        .toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: const SizedBox(),
          title: Column(
            children: [
              Text(
                'AI Matched',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                widget.targetCategoryName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              // AI Score banner
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      _kBlue.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'AI Match Score: ',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                '${matchScore.toStringAsFixed(0)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            matchReason,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ScoreRing(score: matchScore / 100),
                  ],
                ),
              ),

              // Swap card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Visual cards
                    SizedBox(
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(-22, 0),
                            child: Transform.rotate(
                              angle: -0.12,
                              child: _buildImgCard(
                                (widget.myService['image_urls'] as List)
                                        .isNotEmpty
                                    ? widget.myService['image_urls'][0]
                                    : null,
                                _kGold,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(22, 0),
                            child: Transform.rotate(
                              angle: 0.12,
                              child: _buildImgCard(
                                (primaryMatch!['image_urls'] as List).isNotEmpty
                                    ? primaryMatch!['image_urls'][0]
                                    : null,
                                _kBlue,
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildPartyRow(
                      pic: currentUserPic,
                      name: currentUserName,
                      serviceTitle: widget.myService['title'],
                      tag: 'Me',
                      tagColor: Colors.grey[100]!,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_vert,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                        ],
                      ),
                    ),

                    _buildPartyRow(
                      pic: providerPic,
                      name: providerName,
                      serviceTitle: primaryMatch!['title'],
                      tag: 'Match',
                      tagColor: AppColors.primary.withOpacity(0.1),
                      tagTextColor: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderProfileScreen(
                            providerId: providerId,
                            providerName: providerName,
                            providerPic: providerPic,
                          ),
                        ),
                      ),
                      trailing: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating == 0 ? 'New' : rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Similar matches
              if (similarList.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Other AI Matches',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${similarList.length} found',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: similarList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) {
                            final s = similarList[i];
                            final name = s['profiles']?['full_name'] ?? 'User';
                            final pic =
                                s['profiles']?['profile_picture_url'] ??
                                ((s['image_urls'] as List).isNotEmpty
                                    ? s['image_urls'][0]
                                    : null);
                            final isSelected = s['id'] == primaryMatch!['id'];
                            final double sScore = (s['match_score'] is int)
                                ? (s['match_score'] as int).toDouble()
                                : (s['match_score'] ?? 50.0);
                            return GestureDetector(
                              onTap: () => _selectMatch(s),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      color: Colors.grey[200],
                                      image: pic != null
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                pic,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: pic == null
                                        ? Center(
                                            child: Text(
                                              name[0].toUpperCase(),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name.split(' ')[0],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${sScore.toStringAsFixed(0)}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _sendProposal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.handshake_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Send Swap Proposal',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImgCard(String? url, Color color) {
    return Container(
      width: 72,
      height: 92,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        image: url != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

  Widget _buildPartyRow({
    required String? pic,
    required String name,
    required String serviceTitle,
    required String tag,
    required Color tagColor,
    Color? tagTextColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[200],
            backgroundImage: pic != null
                ? CachedNetworkImageProvider(pic)
                : null,
            child: pic == null
                ? Text(
                    name[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceTitle,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tagTextColor ?? Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.75
        ? Colors.green
        : score >= 0.5
        ? AppColors.primary
        : Colors.orange;
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
          ),
          Text(
            '${(score * 100).toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 4. SWAP PROPOSAL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class _SwapProposalSheet extends StatefulWidget {
  final Map<String, dynamic> myService;
  final Map<String, dynamic> targetMatch;
  final String targetCategoryName;
  final VoidCallback onSent;

  const _SwapProposalSheet({
    required this.myService,
    required this.targetMatch,
    required this.targetCategoryName,
    required this.onSent,
  });

  @override
  State<_SwapProposalSheet> createState() => _SwapProposalSheetState();
}

class _SwapProposalSheetState extends State<_SwapProposalSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesCtrl = TextEditingController();
  bool isSending = false;
  String? selectedDate;
  List<Map<String, dynamic>> availableDates = [];
  bool isLoadingDates = true;

  @override
  void initState() {
    super.initState();
    _fetchDates();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDates() async {
    try {
      final providerId = widget.targetMatch['provider_id'];
      final schedule = await _apiService.getProviderSchedule(providerId);
      final now = DateTime.now();
      final List<Map<String, dynamic>> dates = [];
      for (int i = 1; i <= 14; i++) {
        final d = now.add(Duration(days: i));
        final dName = _dayName(d.weekday);
        final sched = (schedule as List).firstWhere(
          (s) => s['day_of_week'] == dName,
          orElse: () => null,
        );
        if (sched != null && sched['is_active'] == true) {
          dates.add({
            'label': '$dName, ${_monthName(d.month)} ${d.day}',
            'time': '${sched['start_time']} \u2013 ${sched['end_time']}',
            'iso': d.toIso8601String(),
          });
        }
        if (dates.length >= 4) break;
      }
      if (mounted) {
        setState(() {
          availableDates = dates;
          if (dates.isNotEmpty) selectedDate = dates[0]['iso'];
          isLoadingDates = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingDates = false);
    }
  }

  String _dayName(int w) => [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][w - 1];
  String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  Future<void> _send() async {
    setState(() => isSending = true);
    try {
      final double score = (widget.targetMatch['match_score'] is int)
          ? (widget.targetMatch['match_score'] as int).toDouble()
          : (widget.targetMatch['match_score'] ?? 50.0);
      await _apiService.createSwapRequest(
        proposerServiceId: widget.myService['id'],
        targetUserId: widget.targetMatch['provider_id'],
        targetServiceId: widget.targetMatch['id'],
        targetCategoryName: widget.targetCategoryName,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scheduledTime: selectedDate,
        aiMatchScore: score,
        aiMatchReason: widget.targetMatch['match_reason'] ?? '',
      );
      widget.onSent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName =
        widget.targetMatch['profiles']?['full_name'] ?? 'Unknown';
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          _kBlue.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Swap Proposal',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'to $providerName',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You offer',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.myService['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'You receive',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.targetMatch['title'],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Preferred Date',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              isLoadingDates
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : availableDates.isEmpty
                  ? Text(
                      'No availability found \u2014 proposal will be sent without a date.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  : Column(
                      children: availableDates.map((d) {
                        final isSelected = selectedDate == d['iso'];
                        return GestureDetector(
                          onTap: () => setState(() => selectedDate = d['iso']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.07)
                                  : const Color(0xFFF7F7F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.4)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['label'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        d['time'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey[300],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

              const SizedBox(height: 16),

              Text(
                'Note (optional)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                maxLength: 250,
                decoration: InputDecoration(
                  hintText:
                      'E.g. "Happy to be flexible on timing, let me know!"',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                style: GoogleFonts.poppins(fontSize: 13),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Send Proposal',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 5. SWAP BOARD SCREEN
// ═══════════════════════════════════════════════════════════

class SwapBoardScreen extends StatefulWidget {
  const SwapBoardScreen({super.key});

  @override
  State<SwapBoardScreen> createState() => _SwapBoardScreenState();
}

class _SwapBoardScreenState extends State<SwapBoardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabCtrl;

  bool isLoadingBoard = true;
  bool isLoadingMine = true;
  List<dynamic> boardItems = []; // posted swap proposals
  List<dynamic> availableServices = []; // services open for swap
  List<dynamic> incomingSwaps = [];
  List<dynamic> outgoingSwaps = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([_loadBoard(), _loadMine()]);

  Future<void> _loadBoard() async {
    try {
      final results = await Future.wait([
        _apiService.getAiRankedSwapBoard(),
        _apiService.getSwapAvailableServices(),
        _apiService.getUserProfile(),
      ]);
      if (mounted) {
        setState(() {
          boardItems = results[0] as List<dynamic>;
          availableServices = results[1] as List<dynamic>;
          _currentUserId =
              (results[2] as Map<String, dynamic>)['profile']?['id']
                  ?.toString();
          isLoadingBoard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingBoard = false);
    }
  }

  Future<void> _loadMine() async {
    try {
      final results = await Future.wait([
        _apiService.getIncomingSwaps(),
        _apiService.getOutgoingSwaps(),
      ]);
      if (mounted) {
        setState(() {
          incomingSwaps = results[0] as List<dynamic>;
          outgoingSwaps = results[1] as List<dynamic>;
          isLoadingMine = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingMine = false);
    }
  }

  Future<void> _acceptSwap(String swapId) async {
    try {
      await _apiService.acceptSwap(swapId);
      _showSnack('Swap Accepted! Check your bookings.', isSuccess: true);
      _loadMine();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _declineSwap(String swapId) async {
    try {
      await _apiService.declineSwap(swapId);
      _showSnack('Swap declined.');
      _loadMine();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _cancelSwap(String swapId) async {
    try {
      await _apiService.cancelSwap(swapId);
      _showSnack('Swap proposal cancelled.');
      _loadMine();
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: isError
            ? Colors.red.shade600
            : isSuccess
            ? Colors.green.shade600
            : const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = incomingSwaps
        .where((s) => s['status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black87),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Swap Board',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'AI-ranked matches for you',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: [
            const Tab(text: 'Discover'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Incoming'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadBoard,
            child: isLoadingBoard
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : (boardItems.isEmpty && availableServices.isEmpty)
                ? _buildEmpty(
                    'No swaps yet',
                    'Enable Skill Swap on your services and others will appear here!',
                    Icons.dashboard_customize_outlined,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // ── Posted proposals ──────────────────────────
                      if (boardItems.isNotEmpty) ...[
                        _buildSectionHeader(
                          '📋 Swap Proposals',
                          'People actively looking to trade skills',
                        ),
                        ...boardItems.map((item) => _buildBoardCard(item)),
                        const SizedBox(height: 8),
                      ],
                      // ── Services open for swap ────────────────────
                      if (availableServices.isNotEmpty) ...[
                        _buildSectionHeader(
                          '🔄 Open for Swap',
                          'Services from providers willing to trade',
                        ),
                        ...availableServices.map(
                          (s) => _buildAvailableServiceCard(s),
                        ),
                      ],
                    ],
                  ),
          ),
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadMine,
            child: isLoadingMine
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : incomingSwaps.isEmpty
                ? _buildEmpty(
                    'No incoming proposals',
                    'Proposals will appear here',
                    Icons.inbox_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: incomingSwaps.length,
                    itemBuilder: (_, i) => _buildIncomingCard(incomingSwaps[i]),
                  ),
          ),
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadMine,
            child: isLoadingMine
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : outgoingSwaps.isEmpty
                ? _buildEmpty(
                    'No outgoing proposals',
                    'Start by finding a match!',
                    Icons.send_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: outgoingSwaps.length,
                    itemBuilder: (_, i) => _buildOutgoingCard(outgoingSwaps[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableServiceCard(dynamic service) {
    final provider = service['provider'] ?? {};
    final images = service['image_urls'] as List? ?? [];
    final img = images.isNotEmpty ? images.first.toString() : null;
    final categoryName = service['category']?['name']?.toString() ?? '';
    final price = service['price'];
    final pricingType = service['pricing_type']?.toString() ?? 'fixed';
    final priceLabel = price != null
        ? '\$${price.toString()}${pricingType == 'hourly' ? '/hr' : ''}'
        : 'Price on request';
    final pId = provider['id']?.toString();
    final isOwn = _currentUserId != null && pId == _currentUserId;

    return GestureDetector(
      onTap: () {
        if (isOwn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This is your service. Manage it from My Services.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: const Color(0xFF4F46E5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
        final sId = service['id']?.toString();
        final providerName = (service['provider']?['full_name'] ?? 'Provider')
            .toString();
        showServiceActionSheet(
          context: context,
          serviceTitle: service['title'] ?? 'Service',
          providerName: providerName,
          coverImageUrl: img,
          isSwappable: true,
          preferSwap: true,
          onBook: () {
            if (sId == null || pId == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceBookingDetailScreen(
                  serviceId: sId,
                  providerId: pId,
                  providerName: providerName,
                  providerPic: service['provider']?['profile_picture_url'],
                  serviceTitle: service['title'] ?? 'Service',
                ),
              ),
            );
          },
          onSwap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SkillSwapBottomSheet(
              initialTargetCategoryId:
                  service['category']?['id']?.toString() ??
                  service['category_id']?.toString(),
              initialTargetCategoryName:
                  (service['category']?['name'] ??
                          service['title'] ??
                          'Service')
                      .toString(),
              initialTargetCoverImageUrl: img,
              initialTargetServiceId: service['id']?.toString(),
              initialTargetProviderId: pId,
              initialTargetProviderName:
                  (service['provider']?['full_name'] ?? 'Provider').toString(),
              initialTargetServiceTitle: (service['title'] ?? 'Service')
                  .toString(),
              initialTargetProviderPic:
                  service['provider']?['profile_picture_url']?.toString(),
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isOwn ? 0.75 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOwn
                  ? const Color(0xFF6366F1).withOpacity(0.3)
                  : const Color(0xFFE8A020).withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Service image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    child: img != null
                        ? CachedNetworkImage(
                            imageUrl: img,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _swapPlaceholder(),
                          )
                        : _swapPlaceholder(),
                  ),
                  if (isOwn)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Yours',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isOwn)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Your Service',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (categoryName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE8A020,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryName,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE8A020),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service['title'] ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider['full_name'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            priceLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF059669),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8A020).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '🔄 Open',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE8A020),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    ); // end GestureDetector
  }

  Widget _swapPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.swap_horiz_rounded,
        color: Color(0xFFE8A020),
        size: 28,
      ),
    );
  }

  Widget _buildBoardCard(dynamic item) {
    final proposer = item['proposer'] ?? {};
    final service = item['proposer_service'] ?? {};
    final name = proposer['full_name'] ?? 'Unknown';
    final pic = proposer['profile_picture_url'];
    final images = service['image_urls'] as List? ?? [];
    final double relevance = (item['ai_relevance_score'] is int)
        ? (item['ai_relevance_score'] as int).toDouble()
        : (item['ai_relevance_score'] ?? 50.0);
    final String reason = item['ai_relevance_reason'] ?? 'Potential match';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: CachedNetworkImage(
                imageUrl: images[0],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(height: 120, color: Colors.grey[100]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: pic != null
                          ? CachedNetworkImageProvider(pic)
                          : null,
                      child: pic == null
                          ? Text(
                              name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _timeAgo(item['created_at']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${relevance.toStringAsFixed(0)}% match',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _offerWantChip(
                      '\u{1F4E6} Offers',
                      service['title'] ?? '\u2014',
                      _kGold,
                    ),
                    const SizedBox(width: 8),
                    _offerWantChip(
                      '\u{1F50D} Wants',
                      item['target_category_name'] ?? '\u2014',
                      _kBlue,
                    ),
                  ],
                ),

                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 13,
                          color: Color(0xFF1A78C2),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF1A2D40),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (item['notes'] != null &&
                    (item['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '"${item['notes']}"',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerWantChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCard(dynamic swap) {
    final proposer = swap['proposer'] ?? {};
    final service = swap['proposer_service'] ?? {};
    final name = proposer['full_name'] ?? 'Unknown';
    final pic = proposer['profile_picture_url'];
    final status = swap['status'] ?? 'pending';
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isPending
            ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: pic != null
                    ? CachedNetworkImageProvider(pic)
                    : null,
                child: pic == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'wants to swap with you',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(status),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _offerWantChip(
                '\u{1F4E6} Their Offer',
                service['title'] ?? '\u2014',
                _kGold,
              ),
              const SizedBox(width: 8),
              _offerWantChip(
                '\u{1F50D} Wants',
                swap['target_category_name'] ?? '\u2014',
                _kBlue,
              ),
            ],
          ),

          if (swap['notes'] != null &&
              (swap['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${swap['notes']}"',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineSwap(swap['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptSwap(swap['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Accept',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutgoingCard(dynamic swap) {
    final target = swap['target_user'] ?? {};
    final service = swap['proposer_service'] ?? {};
    final name = target['full_name'] ?? 'Unknown';
    final pic = target['profile_picture_url'];
    final status = swap['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: pic != null
                    ? CachedNetworkImageProvider(pic)
                    : null,
                child: pic == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _timeAgo(swap['created_at']),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(status),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              _offerWantChip(
                '\u{1F4E6} You Offered',
                service['title'] ?? '\u2014',
                _kGold,
              ),
              const SizedBox(width: 8),
              _offerWantChip(
                '\u{1F50D} Wanted',
                swap['target_category_name'] ?? '\u2014',
                _kBlue,
              ),
            ],
          ),

          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelSwap(swap['id']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel Proposal',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'accepted':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = '\u2713 Accepted';
        break;
      case 'declined':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = '\u2717 Declined';
        break;
      case 'cancelled':
        bg = Colors.grey.shade100;
        fg = Colors.grey;
        label = 'Cancelled';
        break;
      default:
        bg = AppColors.primary.withOpacity(0.1);
        fg = AppColors.primary;
        label = '\u23F3 Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String sub, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
