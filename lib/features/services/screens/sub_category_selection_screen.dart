import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'category_items_screen.dart'; // Navigate here on "Next"

class SubCategorySelectionScreen extends StatefulWidget {
  final String parentId;
  final String parentName;

  const SubCategorySelectionScreen({
    super.key,
    required this.parentId,
    required this.parentName,
  });

  @override
  State<SubCategorySelectionScreen> createState() =>
      _SubCategorySelectionScreenState();
}

class _SubCategorySelectionScreenState
    extends State<SubCategorySelectionScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  List<dynamic> subCategories = [];

  // State for Selection
  Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSubCategories();
  }

  Future<void> _fetchSubCategories() async {
    try {
      // Calls: GET /home/categories/:parentId
      final data = await _apiService.getSubCategories(widget.parentId);
      if (mounted) {
        setState(() {
          subCategories = data;
          // Sort alphabetically
          subCategories.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Group list by first letter
  Map<String, List<dynamic>> _groupCategories() {
    Map<String, List<dynamic>> groups = {};
    for (var cat in subCategories) {
      String name = cat['name'] ?? '';
      if (name.isEmpty) continue;
      String firstLetter = name[0].toUpperCase();
      if (!groups.containsKey(firstLetter)) {
        groups[firstLetter] = [];
      }
      groups[firstLetter]!.add(cat);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupCategories();
    final sortedKeys = groupedData.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Light grey bg like design
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Service Categories",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.parentName,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // 1. Search Bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search service..",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. "Deselect All" Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => selectedIds.clear()),
                        child: Text(
                          "Deselect all",
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Grouped List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      String letter = sortedKeys[index];
                      List<dynamic> items = groupedData[letter]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Letter Header (A, B, C...)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              letter,
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // White Card Container for the Group
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              children: items.asMap().entries.map((entry) {
                                int i = entry.key;
                                dynamic item = entry.value;
                                bool isLast = i == items.length - 1;
                                return _buildCheckItem(item, isLast);
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 4. Bottom Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to Providers, passing the selected sub-categories (or just the parent if none selected)
                        // For now, defaulting to standard view
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryItemsScreen(
                              categoryId: widget.parentId,
                              categoryName: widget.parentName,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF89273B), // Your Maroon
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Next",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCheckItem(dynamic item, bool isLast) {
    bool isSelected = selectedIds.contains(item['id']);
    String imgUrl = item['image_url'] ?? "https://via.placeholder.com/50";

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected)
            selectedIds.remove(item['id']);
          else
            selectedIds.add(item['id']);
        });
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Image
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: CachedNetworkImageProvider(imgUrl),
                ),
                const SizedBox(width: 16),

                // Name
                Expanded(
                  child: Text(
                    item['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Checkbox (Custom UI)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF89273B)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF89273B)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(
              height: 1,
              indent: 70,
              endIndent: 20,
              color: Color(0xFFF0F0F0),
            ),
        ],
      ),
    );
  }
}
