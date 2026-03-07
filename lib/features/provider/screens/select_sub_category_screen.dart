import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'my_services_list_screen.dart';
import 'edit_service_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> subCategories = [];
  List<dynamic> filteredCategories = [];
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
          subCategories.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
          filteredCategories = subCategories; // Init filtered list
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      filteredCategories = subCategories
          .where(
            (c) => c['name'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  Future<void> _createServices() async {
    if (_selectedIds.isEmpty) return;

    setState(() => isLoading = true);
    try {
      final response = await _apiService.createDraftServices(
        _selectedIds.toList(),
      );

      if (!mounted) return;

      final List createdServices = response['services'] ?? [];

      if (createdServices.length == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditServiceScreen(service: createdServices[0]),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
      setState(() => isLoading = false);
    }
  }

  // --- SMART ICON HELPER ---
  String _getSubCategoryIcon(String name) {
    name = name.toLowerCase();

    // Fitness
    if (name.contains('gym') || name.contains('fitness')) {
      return 'https://cdn-icons-png.flaticon.com/512/2964/2964514.png';
    }
    if (name.contains('run')) {
      return 'https://cdn-icons-png.flaticon.com/512/553/553979.png';
    }
    if (name.contains('tennis') || name.contains('sport')) {
      return 'https://cdn-icons-png.flaticon.com/512/1165/1165187.png';
    }

    // Plumbing
    if (name.contains('sink') || name.contains('faucet')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050239.png';
    }
    if (name.contains('leak') || name.contains('drain')) {
      return 'https://cdn-icons-png.flaticon.com/512/3143/3143636.png';
    }
    if (name.contains('toilet') || name.contains('shower')) {
      return 'https://cdn-icons-png.flaticon.com/512/2200/2200326.png';
    }

    // Beauty
    if (name.contains('braid') || name.contains('cornrow')) {
      return 'https://cdn-icons-png.flaticon.com/512/3712/3712169.png';
    }
    if (name.contains('wig') || name.contains('hair')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050257.png';
    }
    if (name.contains('nail') || name.contains('manicure')) {
      return 'https://cdn-icons-png.flaticon.com/512/1940/1940922.png';
    }
    if (name.contains('makeup')) {
      return 'https://cdn-icons-png.flaticon.com/512/3050/3050215.png';
    }

    // Education
    if (name.contains('tutor') || name.contains('assignment')) {
      return 'https://cdn-icons-png.flaticon.com/512/2232/2232688.png';
    }
    if (name.contains('research') || name.contains('thesis')) {
      return 'https://cdn-icons-png.flaticon.com/512/2921/2921222.png';
    }

    // Electrical
    if (name.contains('light') ||
        name.contains('wire') ||
        name.contains('socket')) {
      return 'https://cdn-icons-png.flaticon.com/512/2919/2919600.png';
    }

    // Cleaning
    if (name.contains('clean')) {
      return 'https://cdn-icons-png.flaticon.com/512/995/995016.png';
    }

    // Default
    return 'https://cdn-icons-png.flaticon.com/512/1055/1055685.png';
  }

  // Helper: Group list by first letter
  Map<String, List<dynamic>> _groupCategories() {
    Map<String, List<dynamic>> groups = {};
    for (var cat in filteredCategories) {
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
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9FB),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: "Search services..",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        suffixIcon: _selectedIds.isNotEmpty
                            ? TextButton(
                                onPressed: () =>
                                    setState(() => _selectedIds.clear()),
                                child: Text(
                                  "Deselect all",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // 2. Grouped List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      String letter = sortedKeys[index];
                      List<dynamic> items = groupedData[letter]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8,
                              left: 4,
                              top: 10,
                            ),
                            child: Text(
                              letter,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
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

                // 3. Bottom Action Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedIds.isEmpty ? null : _createServices,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF89273B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Next (${_selectedIds.length})",
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
    bool isSelected = _selectedIds.contains(item['id']);
    // Use smart icon helper here
    String imgUrl = _getSubCategoryIcon(item['name']);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(item['id']);
          } else {
            _selectedIds.add(item['id']);
          }
        });
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    placeholder: (c, u) =>
                        const Icon(Icons.circle, size: 24, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),

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

                // Custom Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
              color: Color(0xFFF5F7FA),
            ),
        ],
      ),
    );
  }
}
