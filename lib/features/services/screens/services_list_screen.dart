import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifekit_frontend/features/services/screens/category_items_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'sub_category_selection_screen.dart'; // Ensure this file exists from the previous step

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> categories = [];
  bool isLoading = true;

  // Animation State for the Floating Button
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
      // This calls GET /home/categories which returns ONLY Parent Categories
      final data = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          categories = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error fetching categories: $e");
    }
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
            onPressed: () {},
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

          // 3. ANIMATED FLOATING BUTTON (Skill Swap)
          Positioned(
            bottom: 30,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() => isFabExpanded = !isFabExpanded);
                // Add navigation to Skill Swap screen here if needed
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 50,
                width: isFabExpanded ? 140 : 50, // Expands width
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swap_horiz, color: Colors.white),
                    if (isFabExpanded) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Skill Swap",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    // Note: 'min. $12' is currently static/mock data as per design.
    // In a real app, you might fetch "lowest price" from backend.
    String price = "min. \$12";

    return GestureDetector(
      onTap: () {
        // DIRECT NAVIGATION TO PROVIDER LIST
        // (Skipping the sub-category screen completely)
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue[50], // Light blue bg
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grid_view_rounded, // Generic category icon
                color: Colors.blue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['name'], // e.g., "Hair & Beauty"
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

            // Arrow
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
