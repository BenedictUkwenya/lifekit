import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../profile/screens/provider_profile_screen.dart';

// ═══════════════════════════════════════════════════════════
// 1. INPUT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class SkillSwapBottomSheet extends StatefulWidget {
  const SkillSwapBottomSheet({super.key});

  @override
  State<SkillSwapBottomSheet> createState() => _SkillSwapBottomSheetState();
}

class _SkillSwapBottomSheetState extends State<SkillSwapBottomSheet> {
  final ApiService _apiService = ApiService();

  List<dynamic> myServices = [];
  Map<String, dynamic>? selectedMyService;
  Map<String, dynamic>? selectedTargetSubCategory;
  String selectedServiceType = 'Home';
  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchMyServices();
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
      MaterialPageRoute(
        builder: (_) => FindingMatchAnimationScreen(
          myService: selectedMyService!,
          targetCategoryId: selectedTargetSubCategory!['id'],
          targetCategoryName: selectedTargetSubCategory!['name'],
          serviceType: selectedServiceType,
        ),
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
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
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
                        'Eng. by LifeKit',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
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

          // ── Scrollable body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cards visual ──
                  Center(
                    child: SizedBox(
                      height: 130,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Left card (my service)
                          Positioned(
                            left: 10,
                            child: Transform.rotate(
                              angle: -0.2,
                              child: _buildCardTile(
                                imageUrls:
                                    selectedMyService?['image_urls'] ?? [],
                                color: const Color(0xFFE8A020),
                                isTarget: false,
                              ),
                            ),
                          ),
                          // Right card (target — always question)
                          Positioned(
                            right: 10,
                            child: Transform.rotate(
                              angle: 0.2,
                              child: _buildCardTile(
                                imageUrls: [],
                                color: Colors.blueAccent,
                                isTarget: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Selection chips ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSelectionChip(
                        label: selectedMyService?['title'] ?? 'Select Yours',
                        filled: true,
                        onTap: _showMyServicesPicker,
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
                      _buildSelectionChip(
                        label:
                            selectedTargetSubCategory?['name'] ??
                            'Select Target',
                        filled: false,
                        onTap: _showCategoryPicker,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── "Looking for" skill field — FIXED ──
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
                                  'Search for a skill…',
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

                  // ── Service type ──
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

                  const SizedBox(height: 12),

                  // ── Tip card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
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
                          child: Text(
                            'Select your skill & choose a target to get matched with a suitable swap partner.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Start button ──
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
                          Text(
                            'Find Match',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card visual tile ──
  Widget _buildCardTile({
    required List imageUrls,
    required Color color,
    required bool isTarget,
  }) {
    final String? imageUrl = (!isTarget && imageUrls.isNotEmpty)
        ? imageUrls[0]
        : null;
    return Container(
      width: 80,
      height: 105,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
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

  // ── Chip ──
  Widget _buildSelectionChip({
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 140),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
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

  // ── Service type button ──
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

  // ── Pickers ──
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
              child: ListView.separated(
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
// 2. ANIMATION SCREEN — KEPT INTACT, POLISHED SLIGHTLY
// ═══════════════════════════════════════════════════════════

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftPosition;
  late Animation<double> _rightPosition;
  late Animation<double> _scaleAnimation;

  bool _isMatched = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _leftPosition = Tween<double>(
      begin: -200,
      end: -50,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _rightPosition = Tween<double>(
      begin: 200,
      end: 50,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isMatched = true);

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
                transitionsBuilder: (_, animation, __, child) {
                  return SlideTransition(
                    position:
                        Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                            .chain(CurveTween(curve: Curves.easeOutQuart))
                            .animate(animation),
                    child: child,
                  );
                },
              ),
            );
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? myImg = (widget.myService['image_urls'] as List).isNotEmpty
        ? widget.myService['image_urls'][0]
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle background circle
          Positioned(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),

          // Left card
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(_leftPosition.value, 0),
                child: Transform.rotate(
                  angle: -0.15,
                  child: _buildCard(myImg, const Color(0xFFE8A020), false),
                ),
              ),
            ),
          ),

          // Right card
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(_rightPosition.value, 0),
                child: Transform.rotate(
                  angle: 0.15,
                  child: _buildCard(null, Colors.blueAccent, true),
                ),
              ),
            ),
          ),

          // Status text (below cards)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.28,
            left: 40,
            right: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isMatched
                  ? Column(
                      key: const ValueKey(2),
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Match Found!',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Loading your results…',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey(1),
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Finding best match…',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This will only take a moment',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Skill name badge at top
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12,
            child: Column(
              children: [
                Text(
                  'Matching you for',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.targetCategoryName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
      width: 100,
      height: 130,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
          ? const Center(
              child: Icon(Icons.question_mark, color: Colors.white, size: 50),
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
  bool isSending = false;

  List<dynamic> allMatches = [];
  Map<String, dynamic>? primaryMatch;
  String currentUserName = 'Me';
  String? currentUserId;
  String? currentUserPic;
  List<Map<String, dynamic>> realAvailableDates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    final Color bg = isError
        ? Colors.red.shade600
        : (isSuccess ? Colors.green.shade600 : const Color(0xFF333333));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : (isSuccess
                        ? Icons.check_circle_outline
                        : Icons.info_outline),
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
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadAllData() async {
    try {
      final results = await Future.wait([
        _apiService.getServicesByCategory(widget.targetCategoryId),
        _apiService.getUserProfile(),
      ]);
      if (mounted) {
        final profileData = results[1] as Map<String, dynamic>;
        currentUserName = profileData['profile']['full_name'] ?? 'Me';
        currentUserId = profileData['profile']['id'];
        currentUserPic = profileData['profile']['profile_picture_url'];

        List<dynamic> candidates = results[0] as List<dynamic>;
        allMatches = candidates
            .where((s) => s['provider_id'] != currentUserId)
            .toList();

        if (allMatches.isNotEmpty) {
          _selectMatch(allMatches[0]);
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _selectMatch(dynamic match) {
    setState(() {
      primaryMatch = match;
      realAvailableDates = [];
    });
    _fetchAndCalculateDates(primaryMatch!['provider_id']);
  }

  Future<void> _fetchAndCalculateDates(String providerId) async {
    try {
      final token = await _apiService.storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/users/schedule/$providerId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      List<dynamic> schedule = response.statusCode == 200
          ? jsonDecode(response.body)['schedule'] ?? []
          : [];

      List<Map<String, dynamic>> calculatedDates = [];
      final now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        final d = now.add(Duration(days: i));
        final dName = _getDayName(d.weekday);
        final sched = schedule.firstWhere(
          (s) => s['day_of_week'] == dName,
          orElse: () => null,
        );
        if (sched != null && sched['is_active'] == true) {
          calculatedDates.add({
            'day': dName,
            'date': '${_getMonthName(d.month)} ${d.day}',
            'time': '${sched['start_time']} – ${sched['end_time']}',
            'realDateObj': d.toIso8601String(),
            'isSelected': false,
          });
        }
        if (calculatedDates.length >= 3) break;
      }
      if (mounted) {
        setState(() {
          realAvailableDates = calculatedDates;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendSwapRequest() async {
    final selectedDate = realAvailableDates.firstWhere(
      (d) => d['isSelected'] == true,
      orElse: () => {},
    );
    if (realAvailableDates.isNotEmpty && selectedDate.isEmpty) {
      _showSnack('Please select a date.', isError: true);
      return;
    }
    if (realAvailableDates.isEmpty) {
      _showSnack('No available dates.', isError: true);
      return;
    }
    setState(() => isSending = true);
    try {
      await _apiService.createBooking(
        serviceId: primaryMatch!['id'],
        scheduledTime: selectedDate['realDateObj'],
        locationDetails: 'Skill Swap (Offered: ${widget.myService['title']})',
        totalPrice: 0.0,
      );
      if (mounted) {
        _showSnack('Request Sent Successfully!', isSuccess: true);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  String _getDayName(int w) => [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][w - 1];
  String _getMonthName(int m) => [
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
                'Skill Swap Match',
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
              // ── Swap card ──────────────────────
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
                            offset: const Offset(-20, 0),
                            child: Transform.rotate(
                              angle: -0.15,
                              child: _buildImgCard(
                                (widget.myService['image_urls'] as List)
                                        .isNotEmpty
                                    ? widget.myService['image_urls'][0]
                                    : null,
                                const Color(0xFFE8A020),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(20, 0),
                            child: Transform.rotate(
                              angle: 0.15,
                              child: _buildImgCard(
                                (primaryMatch!['image_urls'] as List).isNotEmpty
                                    ? primaryMatch!['image_urls'][0]
                                    : null,
                                Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Me row
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

                    // Target provider row
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

              const SizedBox(height: 14),

              // ── Availability ───────────────────
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Select Date',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    realAvailableDates.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No availability set',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Column(
                            children: realAvailableDates.asMap().entries.map((
                              e,
                            ) {
                              final selected = e.value['isSelected'] as bool;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  for (var d in realAvailableDates) {
                                    d['isSelected'] = false;
                                  }
                                  realAvailableDates[e.key]['isSelected'] =
                                      true;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary.withOpacity(0.07)
                                        : const Color(0xFFF7F7F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
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
                                              e.value['day'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: selected
                                                    ? AppColors.primary
                                                    : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              '${e.value['date']} · ${e.value['time']}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        selected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: selected
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
                  ],
                ),
              ),

              // ── Similar matches ────────────────
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Similar matches',
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
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: similarList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) {
                            final s = similarList[i];
                            final name = s['profiles']?['full_name'] ?? 'User';
                            final pic = s['profiles']?['profile_picture_url'];
                            final img =
                                pic ??
                                ((s['image_urls'] as List).isNotEmpty
                                    ? s['image_urls'][0]
                                    : null);
                            final isSelected = s['id'] == primaryMatch!['id'];

                            return GestureDetector(
                              onTap: () => _selectMatch(s),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      color: Colors.grey[200],
                                      image: img != null
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                img,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: img == null
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
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 58,
                                    child: Text(
                                      name.split(' ')[0],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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

              // ── Send button ────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSending ? null : _sendSwapRequest,
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
                      : Text(
                          'Send Swap Request',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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
      width: 70,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
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
