import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

// --- CORE IMPORTS ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

// --- NEW IMPORT ---
import '../../profile/screens/provider_profile_screen.dart';

// =============================================================================
// 1. INPUT BOTTOM SHEET
// =============================================================================

class SkillSwapBottomSheet extends StatefulWidget {
  const SkillSwapBottomSheet({super.key});

  @override
  State<SkillSwapBottomSheet> createState() => _SkillSwapBottomSheetState();
}

class _SkillSwapBottomSheetState extends State<SkillSwapBottomSheet> {
  final ApiService _apiService = ApiService();

  // --- STATE ---
  List<dynamic> myServices = [];
  Map<String, dynamic>? selectedMyService;
  Map<String, dynamic>? selectedTargetSubCategory;
  String selectedServiceType = "Home";

  bool isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchMyServices();
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
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
        elevation: 4,
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
    } catch (e) {
      if (mounted) setState(() => isLoadingData = false);
    }
  }

  void _startSearch() {
    if (selectedMyService == null) {
      _showModernSnackBar(
        "Please select a service you want to offer.",
        isError: true,
      );
      return;
    }
    if (selectedTargetSubCategory == null) {
      _showModernSnackBar(
        "Please select a skill you are looking for.",
        isError: true,
      );
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
          child: CircularProgressIndicator(color: Color(0xFF89273B)),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
            child: Column(
              children: [
                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF89273B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Select skill & enter any other to get matched with a suitable skill swap partner",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Cards Area
                SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.2,
                        child: _buildCardImage(
                          selectedMyService?['image_urls'] ?? [],
                          Colors.orange,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(40, 0),
                        child: Transform.rotate(
                          angle: 0.2,
                          child: _buildCardImage(
                            [],
                            Colors.blueAccent,
                            isTarget: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Selection Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChip(
                      selectedMyService?['title'] ?? "Select Yours",
                      const Color(0xFF89273B),
                      Colors.white,
                      () => _showMyServicesPicker(),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.sync, color: Colors.grey),
                    ),
                    _buildChip(
                      selectedTargetSubCategory?['name'] ?? "Select Target",
                      const Color(0xFFFFF0F3),
                      Colors.black,
                      () => _showCategoryPicker(),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Search Field
                GestureDetector(
                  onTap: () => _showCategoryPicker(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedTargetSubCategory?['name'] ??
                                "Search for a skill...",
                            style: GoogleFonts.poppins(
                              color: selectedTargetSubCategory == null
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.send, color: Color(0xFF89273B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Service Type
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select service type",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _serviceTypeOption("Default", Icons.fingerprint),
                          const SizedBox(width: 10),
                          _serviceTypeOption("Home", Icons.home_filled),
                          const SizedBox(width: 10),
                          _serviceTypeOption("Outdoor", Icons.chair_alt),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Column(
                    children: [
                      Text(
                        "Skill Swap",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Eng. by LifeKit",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // FAB
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _startSearch,
              backgroundColor: const Color(0xFF89273B),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS & PICKERS ---
  Widget _buildCardImage(List urls, Color color, {bool isTarget = false}) {
    String? imageUrl = (!isTarget && urls.isNotEmpty) ? urls[0] : null;
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 3),
        image: imageUrl != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: isTarget
          ? const Center(
              child: Icon(Icons.question_mark, color: Colors.white, size: 40),
            )
          : null,
    );
  }

  Widget _buildChip(String label, Color bg, Color txt, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 140),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: txt,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _serviceTypeOption(String label, IconData icon) {
    bool isSelected = selectedServiceType == label;
    return GestureDetector(
      onTap: () => setState(() => selectedServiceType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF89273B) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF89273B) : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyServicesPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select a skill to offer",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: myServices.length,
                itemBuilder: (context, index) {
                  final s = myServices[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (s['image_urls'] as List).isNotEmpty
                          ? CachedNetworkImageProvider(s['image_urls'][0])
                          : null,
                    ),
                    title: Text(s['title'], style: GoogleFonts.poppins()),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Skill Category",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: cats.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(
                        cats[i]['name'],
                        style: GoogleFonts.poppins(),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
    } catch (e) {
      print("Error: $e");
    }
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
    } catch (e) {
      setState(() => selectedTargetSubCategory = parentCat);
    }
  }

  void _showSubCategoryPicker(List subs, String parentName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select specific skill in $parentName",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: subs.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(
                    subs[index]['name'],
                    style: GoogleFonts.poppins(),
                  ),
                  onTap: () {
                    setState(() => selectedTargetSubCategory = subs[index]);
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

// =============================================================================
// 2. ANIMATION SCREEN (CUSTOM "HIT" ANIMATION)
// =============================================================================

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
      duration: const Duration(seconds: 2), // The slide in duration
      vsync: this,
    );

    // Left card slides from -200 to -30 (Near center)
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

    // Start animation
    _controller.forward().then((_) {
      // 1. Show "Match Found" Visuals
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isMatched = true);

        // 2. TRIGGER CUSTOM SLIDE TRANSITION HERE
        Timer(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SkillSwapResultsScreen(
                      myService: widget.myService,
                      targetCategoryId: widget.targetCategoryId,
                      targetCategoryName: widget.targetCategoryName,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0); // Start from bottom
                      const end = Offset.zero; // End at center
                      const curve =
                          Curves.easeOutQuart; // Smooth Apple-like curve

                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
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
    String? myImg = (widget.myService['image_urls'] as List).isNotEmpty
        ? widget.myService['image_urls'][0]
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Left Card
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(_leftPosition.value, 0),
                  child: Transform.rotate(
                    angle: -0.15,
                    child: _buildCard(myImg, Colors.orange, false),
                  ),
                ),
              );
            },
          ),

          // Right Card
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: Offset(_rightPosition.value, 0),
                  child: Transform.rotate(
                    angle: 0.15,
                    child: _buildCard(null, Colors.blueAccent, true),
                  ),
                ),
              );
            },
          ),

          // Match Text
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isMatched
                  ? Column(
                      key: const ValueKey(2),
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Match Found!",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey(1),
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF89273B),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Finding match...",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
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

// =============================================================================
// 3. RESULTS SCREEN (Interactive Similar Matches)
// =============================================================================

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

  List<dynamic> allMatches = []; // Store ALL matches here
  Map<String, dynamic>? primaryMatch; // The one currently shown in big card

  String currentUserName = "Me";
  String? currentUserId;
  String? currentUserPic;
  List<Map<String, dynamic>> realAvailableDates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _showModernSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    Color bgColor = isError
        ? Colors.red.shade600
        : (isSuccess ? Colors.green.shade600 : const Color(0xFF333333));
    IconData icon = isError
        ? Icons.error_outline
        : (isSuccess ? Icons.check_circle_outline : Icons.info_outline);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
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
        currentUserName = profileData['profile']['full_name'] ?? "Me";
        currentUserId = profileData['profile']['id'];
        currentUserPic = profileData['profile']['profile_picture_url'];

        // Filter out my own services
        List<dynamic> candidates = results[0] as List<dynamic>;
        allMatches = candidates
            .where((s) => s['provider_id'] != currentUserId)
            .toList();

        if (allMatches.isNotEmpty) {
          _selectMatch(allMatches[0]); // Default to first
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- NEW: Function to Switch Provider ---
  void _selectMatch(dynamic match) {
    setState(() {
      primaryMatch = match;
      realAvailableDates = []; // Clear old dates while loading
      // Fetch schedule for this new provider
      _fetchAndCalculateDates(primaryMatch!['provider_id']);
    });
  }

  Future<void> _fetchAndCalculateDates(String providerId) async {
    // Show partial loading state for calendar if needed, or just refresh
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
      DateTime now = DateTime.now();
      for (int i = 1; i <= 14; i++) {
        DateTime dateToCheck = now.add(Duration(days: i));
        String weekDayName = _getDayName(dateToCheck.weekday);
        var scheduleForDay = schedule.firstWhere(
          (s) => s['day_of_week'] == weekDayName,
          orElse: () => null,
        );
        if (scheduleForDay != null && scheduleForDay['is_active'] == true) {
          calculatedDates.add({
            'day': weekDayName,
            'date':
                "${_getMonthName(dateToCheck.month)} ${dateToCheck.day}, ${scheduleForDay['start_time']} - ${scheduleForDay['end_time']}",
            'realDateObj': dateToCheck.toIso8601String(),
            'isSelected': false,
          });
        }
        if (calculatedDates.length >= 3) break;
      }
      if (mounted)
        setState(() {
          realAvailableDates = calculatedDates;
          isLoading = false; // Data fully loaded
        });
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _sendSwapRequest() async {
    var selectedDateMap = realAvailableDates.firstWhere(
      (d) => d['isSelected'] == true,
      orElse: () => {},
    );
    if (realAvailableDates.isNotEmpty && selectedDateMap.isEmpty) {
      _showModernSnackBar("Please select a date.", isError: true);
      return;
    }
    if (realAvailableDates.isEmpty) {
      _showModernSnackBar("No available dates.", isError: true);
      return;
    }
    setState(() => isSending = true);
    try {
      await _apiService.createBooking(
        serviceId: primaryMatch!['id'],
        scheduledTime: selectedDateMap['realDateObj'],
        locationDetails: "Skill Swap (Offered: ${widget.myService['title']})",
        totalPrice: 0.0,
      );
      if (mounted) {
        _showModernSnackBar("Request Sent Successfully!", isSuccess: true);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      _showModernSnackBar("Error sending request: $e", isError: true);
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  String _getDayName(int w) => [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ][w - 1];
  String _getMonthName(int m) => [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ][m - 1];

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF89273B)),
        ),
      );
    if (primaryMatch == null)
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("No providers found.")),
      );

    final providerName = primaryMatch!['profiles']?['full_name'] ?? "Unknown";
    final providerPic = primaryMatch!['profiles']?['profile_picture_url'];
    final providerId = primaryMatch!['provider_id'];
    final double rating = (primaryMatch!['average_rating'] is int)
        ? (primaryMatch!['average_rating'] as int).toDouble()
        : (primaryMatch!['average_rating'] ?? 0.0);

    // List of OTHER matches (exclude current primary)
    final similarList = allMatches
        .where((s) => s['id'] != primaryMatch!['id'])
        .toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const SizedBox(),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close, color: Colors.black),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
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
                          (widget.myService['image_urls'] as List).isNotEmpty
                              ? widget.myService['image_urls'][0]
                              : null,
                          Colors.grey,
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
              const SizedBox(height: 20),

              // Me Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: currentUserPic != null
                              ? CachedNetworkImageProvider(currentUserPic!)
                              : null,
                          child: currentUserPic == null
                              ? const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.myService['title'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "$currentUserName (Me)",
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Me",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Center(
                      child: Icon(
                        Icons.swap_vert_circle,
                        color: Color(0xFF89273B),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Target Card (Dynamic)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProviderProfileScreen(
                                          providerId: providerId,
                                          providerName: providerName,
                                          providerPic: providerPic,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: providerPic != null
                                            ? CachedNetworkImageProvider(
                                                providerPic,
                                              )
                                            : null,
                                        child: providerPic == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              primaryMatch!['title'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              providerName,
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
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
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _showModernSnackBar(
                                      "Sharing...",
                                      isSuccess: false,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.ios_share,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              Text(
                                rating == 0 ? " New" : " $rating",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Availability",
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          realAvailableDates.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    "No availability set.",
                                    style: GoogleFonts.poppins(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: realAvailableDates
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              for (var d
                                                  in realAvailableDates) {
                                                d['isSelected'] = false;
                                              }
                                              realAvailableDates[e
                                                      .key]['isSelected'] =
                                                  true;
                                            });
                                          },
                                          child: _buildAvailabilityRow(
                                            e.value['day'],
                                            e.value['date'],
                                            e.value['isSelected'],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- SIMILAR MATCHES SECTION ---
              if (similarList.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Similar matches",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      "See all",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90, // Increased height for names
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: similarList.length,
                    itemBuilder: (context, index) {
                      final s = similarList[index];
                      final sName = s['profiles']?['full_name'] ?? "User";
                      final sPic = s['profiles']?['profile_picture_url'];
                      // Use provider pic if available, or service image
                      final img =
                          sPic ??
                          ((s['image_urls'] as List).isNotEmpty
                              ? s['image_urls'][0]
                              : null);

                      return GestureDetector(
                        onTap: () => _selectMatch(s), // CLICK TO SWITCH!
                        child: Container(
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: img != null
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            img,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: Colors.grey[200],
                                ),
                                child: img == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  sName.split(' ')[0],
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
                        ),
                      );
                    },
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "No other providers found.",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isSending ? null : _sendSwapRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89273B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Send Request",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        image: url != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
              )
            : null,
        color: color,
      ),
    );
  }

  Widget _buildAvailabilityRow(String day, String date, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            Icon(
              Icons.check_circle,
              color: isSelected ? const Color(0xFF89273B) : Colors.grey[300],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
