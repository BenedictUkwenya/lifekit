import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import 'category_items_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
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
    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

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

  Future<void> _openCategory(dynamic category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemsScreen(
          categoryId: category['id'],
          categoryName: category['name'],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(dynamic cat) {
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
          cat['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _openCategory(cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "All Categories",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _buildCategoryTile(categories[index]),
            ),
    );
  }
}
