import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import 'select_sub_category_screen.dart';

class SelectMainCategoryScreen extends StatefulWidget {
  const SelectMainCategoryScreen({super.key});

  @override
  State<SelectMainCategoryScreen> createState() =>
      _SelectMainCategoryScreenState();
}

class _SelectMainCategoryScreenState extends State<SelectMainCategoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      // API now returns only PARENT categories
      final data = await _apiService.getCategories();
      if (mounted) setState(() => categories = data);
    } catch (e) {
      print(e);
    }
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
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category, color: Colors.blue),
            ),
            title: Text(
              cat['name'],
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SelectSubCategoryScreen(
                    parentId: cat['id'],
                    parentName: cat['name'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
