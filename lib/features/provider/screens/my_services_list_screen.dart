import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'select_main_category_screen.dart';
import 'edit_service_screen.dart';

class MyServicesListScreen extends StatefulWidget {
  const MyServicesListScreen({super.key});

  @override
  State<MyServicesListScreen> createState() => _MyServicesListScreenState();
}

class _MyServicesListScreenState extends State<MyServicesListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> myServices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyServices();
  }

  Future<void> _fetchMyServices() async {
    try {
      final data = await _apiService.getMyServices();
      if (mounted) {
        setState(() {
          myServices = data;
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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Service Lists",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Create Button Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.layers, size: 60, color: Colors.blue),
                        const SizedBox(height: 16),
                        Text(
                          "Reach a wider demand varied at your Skill Expertise.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SelectMainCategoryScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Create a new service",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (myServices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        "No services created yet.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),

                  ...myServices.map((service) => _buildServiceItem(service)),
                ],
              ),
            ),
    );
  }

  Widget _buildServiceItem(dynamic service) {
    // IMAGE LOGIC
    String imgUrl = "https://via.placeholder.com/150";
    if (service['image_urls'] != null &&
        service['image_urls'] is List &&
        (service['image_urls'] as List).isNotEmpty) {
      var first = (service['image_urls'] as List)[0];
      if (first is String)
        imgUrl = first;
      else if (first is List && first.isNotEmpty)
        imgUrl = first[0];
    }

    // STATUS BADGE LOGIC
    String status = service['status'] ?? 'draft';
    bool isDraft = service['price'] == 0;

    Color badgeColor = Colors.grey;
    String badgeText = status;

    if (isDraft) {
      badgeColor = Colors.orange;
      badgeText = "Draft";
    } else if (status == 'pending') {
      badgeColor = Colors.blue;
      badgeText = "In Review";
    } else if (status == 'rejected') {
      badgeColor = Colors.red;
      badgeText = "Rejected";
    } else if (status == 'active') {
      badgeColor = Colors.green;
      badgeText = "Active";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditServiceScreen(service: service),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imgUrl,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['title'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  if (service['price'] != 0)
                    Text(
                      "USD ${service['price']}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // STATUS BADGE UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
