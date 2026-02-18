import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- CORE IMPORTS ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

import 'category_items_screen.dart';
import 'skill_swap_screens.dart'; // Ensure this exists
import '../../home/screens/search_results_screen.dart'; // Import Search Screen

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> categories = [];
  bool isLoading = true;
  bool isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    // Auto-expand animation on load
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => isFabExpanded = true);
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          categories = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- HELPER: Get Image for Category ---
  String _getCategoryImage(String name) {
    name = name.toLowerCase();

    if (name.contains('health') || name.contains('wellness')) {
      return 'https://cdn-icons-png.flaticon.com/512/2966/2966334.png';
    }
    if (name.contains('laundry') || name.contains('ironing')) {
      return 'https://cdn-icons-png.flaticon.com/512/2954/2954888.png';
    }
    if (name.contains('hair') ||
        name.contains('beauty') ||
        name.contains('salon')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050257.png';
    }
    if (name.contains('family') ||
        name.contains('care') ||
        name.contains('companion') ||
        name.contains('baby')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050226.png';
    }
    if (name.contains('plumbing') ||
        name.contains('maintenance') ||
        name.contains('handyman')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050239.png';
    }
    if (name.contains('home') || name.contains('lifestyle')) {
      return 'https://cdn-icons-png.flaticon.com/512/619/619153.png';
    }
    if (name.contains('tech') ||
        name.contains('digital') ||
        name.contains('computer')) {
      return 'https://cdn-icons-png.flaticon.com/512/1055/1055687.png';
    }
    if (name.contains('clean')) {
      return 'https://cdn-icons-png.flaticon.com/512/995/995016.png';
    }
    if (name.contains('education') ||
        name.contains('tutor') ||
        name.contains('guidance')) {
      return 'https://cdn-icons-png.flaticon.com/512/2232/2232688.png';
    }
    if (name.contains('communication') ||
        name.contains('language') ||
        name.contains('translat')) {
      return 'https://cdn-icons-png.flaticon.com/512/3898/3898082.png';
    }
    if (name.contains('event') ||
        name.contains('party') ||
        name.contains('photo')) {
      return 'https://cdn-icons-png.flaticon.com/512/3132/3132084.png';
    }

    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

  // --- HELPER: Get Background Color ---
  Color _getCategoryColor(String name) {
    name = name.toLowerCase();
    if (name.contains('health')) return const Color(0xFFE3F2FD);
    if (name.contains('laundry')) return const Color(0xFFE8F5E9);
    if (name.contains('hair')) return const Color(0xFFF3E5F5);
    if (name.contains('care') || name.contains('family'))
      return const Color(0xFFFFEBEE);
    if (name.contains('clean')) return const Color(0xFFE0F7FA);
    if (name.contains('education')) return const Color(0xFFFFF3E0);
    if (name.contains('tech')) return const Color(0xFFECEFF1);
    if (name.contains('event')) return const Color(0xFFFCE4EC);
    return Colors.grey[100]!;
  }

  // --- ACTION: Search ---
  void _onSearch(String query) {
    if (query.trim().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchResultsScreen(query: query)),
      );
    }
  }

  // --- ACTION: Menu ---
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Sort Categories",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text("Name (A-Z)"),
              onTap: () {
                setState(
                  () =>
                      categories.sort((a, b) => a['name'].compareTo(b['name'])),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text("Most Popular"),
              onTap: () {
                // Mock logic: Reverse for now
                setState(() => categories = categories.reversed.toList());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Services",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: _showSortMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Search service providers",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // 2. Category List
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : categories.isEmpty
                    ? Center(
                        child: Text(
                          "No categories found",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return _buildCategoryTile(cat);
                        },
                      ),
              ),
            ],
          ),

          // 3. ANIMATED FAB (FIXED OVERFLOW)
          Positioned(
            bottom: 30,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() => isFabExpanded = !isFabExpanded);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const SkillSwapBottomSheet(),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 56, // Slightly taller
                width: isFabExpanded ? 150 : 56, // Adjusted width
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28), // Perfectly round
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Ensures tight wrap
                  children: [
                    const Icon(Icons.swap_horiz, color: Colors.white, size: 24),
                    if (isFabExpanded) ...[
                      const SizedBox(width: 8),
                      // Flexible prevents overflow if text is too long
                      Flexible(
                        child: Text(
                          "Skill Swap",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow
                              .clip, // Prevent ellipsis visual glitch
                          softWrap: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(dynamic category) {
    String price = "min. \$12"; // Mock price
    String imageUrl = _getCategoryImage(category['name']);
    Color bgColor = _getCategoryColor(category['name']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryItemsScreen(
              categoryId: category['id'],
              categoryName: category['name'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            // Custom Icon Box
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['name'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Overlapping Avatars (Provider Preview)
            SizedBox(
              width: 60,
              height: 30,
              child: Stack(
                children: [
                  _buildMiniAvatar(0, 'https://i.pravatar.cc/150?img=1'),
                  _buildMiniAvatar(15, 'https://i.pravatar.cc/150?img=2'),
                  _buildMiniAvatar(30, 'https://i.pravatar.cc/150?img=3'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar(double left, String url) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
    );
  }
}
