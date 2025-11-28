import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'my_services_list_screen.dart'; // Loops back to list to show drafts
import '../../../core/widgets/lifekit_loader.dart';

class SelectSubCategoryScreen extends StatefulWidget {
  final String parentId;
  final String parentName;

  const SelectSubCategoryScreen({
    super.key,
    required this.parentId,
    required this.parentName,
  });

  @override
  State<SelectSubCategoryScreen> createState() =>
      _SelectSubCategoryScreenState();
}

class _SelectSubCategoryScreenState extends State<SelectSubCategoryScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> subCategories = [];
  final Set<String> _selectedIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubCategories();
  }

  Future<void> _fetchSubCategories() async {
    try {
      final data = await _apiService.getSubCategories(widget.parentId);
      if (mounted) {
        setState(() {
          subCategories = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _createServices() async {
    if (_selectedIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      await _apiService.createDraftServices(_selectedIds.toList());
      // Go back to My Services List (which will now show the drafts)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
          (route) => route.isFirst, // Or manage navigation stack better
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.parentName,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select services",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedIds.clear()),
                  child: Text(
                    "Deselect all",
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: const LifeKitLoader())
                : ListView.builder(
                    itemCount: subCategories.length,
                    itemBuilder: (context, index) {
                      final cat = subCategories[index];
                      final isSelected = _selectedIds.contains(cat['id']);
                      return CheckboxListTile(
                        activeColor: AppColors.primary,
                        value: isSelected,
                        title: Text(cat['name'], style: GoogleFonts.poppins()),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(cat['id']);
                            } else {
                              _selectedIds.remove(cat['id']);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty ? null : _createServices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Next",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
