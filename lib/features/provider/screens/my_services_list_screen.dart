import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'select_main_category_screen.dart'; // Next screen
import 'edit_service_screen.dart'; // Edit screen
import '../../../core/widgets/lifekit_loader.dart';

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
          ? const Center(child: const LifeKitLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Placeholder for the 3 cards illustration
                        const Icon(Icons.layers, size: 60, color: Colors.blue),
                        const SizedBox(height: 16),
                        Text(
                          "Reach a wider demand varied at your Skill Expertise and know how.",
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

                  // List of Services
                  ...myServices.map((service) => _buildServiceItem(service)),
                ],
              ),
            ),
    );
  }

  Widget _buildServiceItem(dynamic service) {
    String imgUrl =
        (service['image_urls'] != null &&
            (service['image_urls'] as List).isNotEmpty)
        ? service['image_urls'][0].toString()
        : "https://via.placeholder.com/150";

    return GestureDetector(
      onTap: () {
        // If it's a draft (price 0), go to edit directly? Or always go to edit?
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
                  Text(
                    service['description'] ?? "No description",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
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
            if (service['status'] == 'pending' || service['price'] == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Draft",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
