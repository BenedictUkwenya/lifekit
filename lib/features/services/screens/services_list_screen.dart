import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'category_items_screen.dart'; // We will create this next

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> categories = [];
  bool isLoading = true;

  // Animation State
  bool isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    // Auto-expand animation on load (optional, based on your description)
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
              // Search Bar
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

              // List
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
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

          // ANIMATED FLOATING BUTTON (Bottom Right)
          Positioned(
            bottom: 30,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() => isFabExpanded = !isFabExpanded);
                // Navigate to Skill Swap if needed
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
    // Randomize mock data for visual fidelity if API data is sparse
    String price = "min. \$12";

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
                color:
                    Colors.blue[50], // You can map this color from DB ideally
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.blue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Text
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

            // Avatar Stack (Mock for visual)
            SizedBox(
              width: 60,
              height: 30,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: AssetImage(
                        'assets/images/onboarding1.png',
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 15,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundImage: AssetImage(
                        'assets/images/onboarding2.png',
                      ),
                    ),
                  ),
                  Positioned(
                    left: 30,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
