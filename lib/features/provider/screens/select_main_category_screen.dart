import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import 'select_sub_category_screen.dart';

class SelectMainCategoryScreen extends StatefulWidget {
  const SelectMainCategoryScreen({super.key});

  @override
  State<SelectMainCategoryScreen> createState() =>
      _SelectMainCategoryScreenState();
}

class _SelectMainCategoryScreenState extends State<SelectMainCategoryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> mainCategories = []; // Default list
  List<dynamic> searchResults = []; // Search results
  bool isLoading = true;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchMainCategories();
  }

  Future<void> _fetchMainCategories() async {
    try {
      final data = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          mainCategories = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print(e);
    }
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        isSearching = false;
        searchResults = [];
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final results = await _apiService.searchCategories(query);
      if (mounted) {
        setState(() => searchResults = results);
      }
    } catch (e) {
      print("Search Error: $e");
    }
  }

  // --- NAVIGATION LOGIC ---
  void _handleCategorySelection(dynamic cat) {
    String parentId;
    String parentName;

    // Check if the selected item is a Sub-Category (has a parent)
    if (cat['parent_category_id'] != null && cat['parent'] != null) {
      // It's a sub-category (e.g. Socket Repair)
      // We navigate to the Parent (Electrical) so the provider can see all options
      parentId = cat['parent_category_id'];
      parentName = cat['parent']['name'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Found inside '$parentName'. Opening..."),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // It's a Main Category
      parentId = cat['id'];
      parentName = cat['name'];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SelectSubCategoryScreen(parentId: parentId, parentName: parentName),
      ),
    );
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
    if (name.contains('plumb') ||
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

    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png'; // Default
  }

  // --- HELPER: Get Background Color ---
  Color _getCategoryColor(String name) {
    name = name.toLowerCase();
    if (name.contains('health')) return const Color(0xFFE3F2FD);
    if (name.contains('laundry')) return const Color(0xFFE8F5E9);
    if (name.contains('hair')) return const Color(0xFFF3E5F5);
    if (name.contains('care') || name.contains('family')) {
      return const Color(0xFFFFEBEE);
    }
    if (name.contains('clean')) return const Color(0xFFE0F7FA);
    if (name.contains('education')) return const Color(0xFFFFF3E0);
    if (name.contains('tech')) return const Color(0xFFECEFF1);
    if (name.contains('event')) return const Color(0xFFFCE4EC);
    return Colors.grey[100]!;
  }

  // --- NEW: REQUEST CATEGORY SHEET LOGIC ---
  // --- NEW: REQUEST CATEGORY SHEET LOGIC ---
  void _showRequestCategorySheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Needed for keyboard spacing
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          // 1. We ONLY put the viewInsets.bottom here to push the sheet above the keyboard
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // 2. Added SingleChildScrollView here to fix the overflow!
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              24,
            ), // Moved the standard padding here
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Request a Category",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Can't find your exact service? Let us know and our team will add it.",
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: "Category Name (e.g. Dog Walking)",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Brief description of the service...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _apiService.requestNewCategory(
                                nameCtrl.text.trim(),
                                descCtrl.text.trim(),
                              );
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Request sent successfully!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Submit Request",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Choose Category",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search e.g. Socket, Cleaning...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // 2. LIST
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: isSearching
                        ? searchResults.length
                        : mainCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cat = isSearching
                          ? searchResults[index]
                          : mainCategories[index];
                      return _buildCategoryTile(cat);
                    },
                  ),
          ),

          // 3. NEW: "CAN'T FIND IT?" BUTTON
          if (!isLoading)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _showRequestCategorySheet,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Can't find your service? Request it.",
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  Widget _buildCategoryTile(dynamic cat) {
    // If searching, show Parent Name for context (e.g. "Socket Repair (Electrical)")
    String displayName = cat['name'];
    String? subtitle;

    // Logic to show parent name if this is a subcategory result from search
    if (cat['parent'] != null) {
      subtitle = "in ${cat['parent']['name']}";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getCategoryColor(cat['name']),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CachedNetworkImage(
            imageUrl: _getCategoryImage(cat['name']),
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Icon(Icons.category, color: Colors.grey),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error, color: Colors.grey),
          ),
        ),
        title: Text(
          displayName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _handleCategorySelection(cat),
      ),
    );
  }
}
