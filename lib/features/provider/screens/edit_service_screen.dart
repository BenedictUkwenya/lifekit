import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

// VERSION 2 PREMIUM: REFINED & PROFESSIONAL
// Features: Subtle colors, fixed overflows, clean sophisticated design

class EditServiceScreen extends StatefulWidget {
  final dynamic service;

  const EditServiceScreen({super.key, required this.service});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final ApiService _apiService = ApiService();

  // --- CONTROLLERS ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // --- IMAGE STATE ---
  List<File> _newImages = [];
  List<String> _existingImages = [];
  int _currentImageIndex = 0;

  // --- CONFIG STATE ---
  String _serviceLocation = "Home Service (HS)";
  String _pricingType = "fixed";
  bool _isVisible = true;
  bool _isLoading = false;

  // --- DYNAMIC CONFIGURATION ---
  List<String> _locationOptions = [];
  bool _isStandalone = false;

  List<Map<String, dynamic>> _serviceOptions = [];
  List<dynamic> _availableSubTasks = [];

  // --- AVAILABILITY STATE ---
  List<Map<String, dynamic>> _weeklySchedule = [
    {"day": "Monday", "active": false, "start": "09:00", "end": "17:00"},
    {"day": "Tuesday", "active": false, "start": "09:00", "end": "17:00"},
    {"day": "Wednesday", "active": false, "start": "09:00", "end": "17:00"},
    {"day": "Thursday", "active": false, "start": "09:00", "end": "17:00"},
    {"day": "Friday", "active": false, "start": "09:00", "end": "17:00"},
    {"day": "Saturday", "active": false, "start": "10:00", "end": "15:00"},
    {"day": "Sunday", "active": false, "start": "10:00", "end": "15:00"},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    _titleController.text = widget.service['title'] ?? "";
    _descController.text = widget.service['description'] ?? "";
    _locationController.text = widget.service['location_text'] ?? "";
    _serviceLocation = widget.service['service_type'] ?? "Home Service (HS)";
    _pricingType = widget.service['pricing_type'] ?? 'fixed';

    if (widget.service['price'] != null) {
      _basePriceController.text = widget.service['price'].toString();
    }

    if (widget.service['image_urls'] != null) {
      for (var img in widget.service['image_urls']) {
        if (img is String) _existingImages.add(img);
      }
    }

    if (widget.service['service_options'] != null &&
        (widget.service['service_options'] as List).isNotEmpty) {
      _serviceOptions = List<Map<String, dynamic>>.from(
        (widget.service['service_options'] as List).map(
          (x) => Map<String, dynamic>.from(x),
        ),
      );
    }

    if (widget.service['category_id'] != null) {
      await _fetchCategoryConfig(widget.service['category_id']);
    }

    await _fetchLiveSchedule();

    setState(() => _isLoading = false);
  }

  Future<void> _fetchCategoryConfig(String catId) async {
    try {
      final cats = await _apiService.getCategories();
      var category = cats.firstWhere(
        (c) => c['id'] == catId,
        orElse: () => null,
      );

      if (category != null) {
        if (category['location_options'] != null) {
          setState(() {
            _locationOptions = List<String>.from(category['location_options']);
            if (!_locationOptions.contains(_serviceLocation) &&
                _locationOptions.isNotEmpty) {
              _serviceLocation = _locationOptions[0];
            }
          });
        }

        bool isStandalone = category['is_standalone'] ?? false;
        if (isStandalone) {
          final subs = await _apiService.getSubCategories(catId);
          setState(() {
            _isStandalone = true;
            _availableSubTasks = subs;
          });
        }
      }
    } catch (e) {
      print("Config Fetch Error: $e");
    }
  }

  Future<void> _fetchLiveSchedule() async {
    try {
      String? token = await _apiService.storage.read(key: 'jwt_token');
      String providerId = widget.service['provider_id'];
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/users/schedule/$providerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> savedSchedule = data['schedule'] ?? [];

        if (savedSchedule.isNotEmpty) {
          for (var dbDay in savedSchedule) {
            var localDay = _weeklySchedule.firstWhere(
              (d) => d['day'] == dbDay['day_of_week'],
              orElse: () => {},
            );
            if (localDay.isNotEmpty) {
              localDay['active'] = dbDay['is_active'];
              localDay['start'] = dbDay['start_time'];
              localDay['end'] = dbDay['end_time'];
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching schedule: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _newImages.add(File(image.path)));
    }
  }

  Future<void> _selectTime(int index, bool isStart) async {
    if (!_weeklySchedule[index]['active']) return;

    String currentString = isStart
        ? _weeklySchedule[index]['start']
        : _weeklySchedule[index]['end'];
    List<String> parts = currentString.split(":");

    int initialHour = int.parse(parts[0]);
    int initialMinute = int.parse(parts[1]);

    _showIOSTimePicker(
      initialHour: initialHour,
      initialMinute: initialMinute,
      onTimeSelected: (hour, minute) {
        setState(() {
          String formattedTime =
              "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
          if (isStart) {
            _weeklySchedule[index]['start'] = formattedTime;
          } else {
            _weeklySchedule[index]['end'] = formattedTime;
          }
        });
      },
    );
  }

  void _showIOSTimePicker({
    required int initialHour,
    required int initialMinute,
    required Function(int, int) onTimeSelected,
  }) {
    int tempHour = initialHour;
    int tempMinute = initialMinute;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 320,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      "Select Time",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onTimeSelected(tempHour, tempMinute);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Done",
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // iOS-style Time Picker
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hours
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: tempHour,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempHour = index;
                        },
                        children: List.generate(24, (index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Separator
                    Text(
                      ":",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Minutes
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: tempMinute,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (index) {
                          tempMinute = index;
                        },
                        children: List.generate(60, (index) {
                          return Center(
                            child: Text(
                              index.toString().padLeft(2, '0'),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveService() async {
    if (_titleController.text.isEmpty) {
      _showSnackBar("Please enter a service title", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> finalImageUrls = [..._existingImages];
      for (var file in _newImages) {
        String url = await _apiService.uploadServiceImage(file);
        finalImageUrls.add(url);
      }

      double finalPrice = 0.0;
      if (_isStandalone && _serviceOptions.isNotEmpty) {
        finalPrice = _serviceOptions
            .map((e) => double.tryParse(e['price'].toString()) ?? 0.0)
            .reduce((a, b) => a < b ? a : b);
      } else {
        finalPrice = double.tryParse(_basePriceController.text) ?? 0.0;
      }

      await _apiService.updateService(widget.service['id'], {
        "title": _titleController.text,
        "description": _descController.text,
        "price": finalPrice,
        "service_type": _serviceLocation,
        "location_text": _locationController.text,
        "pricing_type": _pricingType,
        "image_urls": finalImageUrls,
        "status": _isVisible ? "active" : "draft",
        "availability": _weeklySchedule,
        "service_options": _isStandalone ? _serviceOptions : [],
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Service updated successfully!", isError: false);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Edit Service",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isLoading ? null : _saveService,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                disabledForegroundColor: Colors.grey.shade400,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Save",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Updating service...",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- IMAGE GALLERY SECTION ---
                  _buildImageGallerySection(),

                  // --- FORM FIELDS ---
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SERVICE TITLE ---
                        _buildSectionLabel("Service Title"),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _titleController,
                          hint: "e.g., Bridal Hair Styling",
                        ),
                        const SizedBox(height: 24),

                        // --- PRICING ---
                        _buildSectionLabel("Pricing"),
                        const SizedBox(height: 10),
                        if (_isStandalone) ...[
                          if (_serviceOptions.isEmpty)
                            _buildEmptyOptionCard()
                          else
                            ..._serviceOptions.asMap().entries.map((entry) {
                              return _buildServiceOptionCard(
                                entry.key,
                                entry.value,
                              );
                            }),
                          const SizedBox(height: 12),
                          _buildAddOptionButton(),
                        ] else ...[
                          _buildTextField(
                            controller: _basePriceController,
                            hint: _pricingType == 'fixed'
                                ? "Fixed price (e.g., 150)"
                                : "Hourly rate (e.g., 50)",
                            keyboardType: TextInputType.number,
                            prefix: Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 8,
                              ),
                              child: Text(
                                "\$",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // --- DESCRIPTION ---
                        _buildSectionLabel("Description"),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _descController,
                          hint:
                              "Describe your service, what's included, requirements...",
                          maxLines: 5,
                        ),
                        const SizedBox(height: 24),

                        // --- SERVICE TYPE ---
                        _buildSectionLabel("Service Type"),
                        const SizedBox(height: 10),
                        _buildServiceTypeSelector(),
                        const SizedBox(height: 24),

                        // --- LOCATION ---
                        _buildSectionLabel("Service Location (Optional)"),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _locationController,
                          hint: "Enter specific address or area",
                        ),
                        const SizedBox(height: 28),

                        // --- AVAILABILITY ---
                        _buildSectionLabel("Weekly Availability"),
                        const SizedBox(height: 12),
                        _buildAvailabilitySection(),
                        const SizedBox(height: 28),

                        // --- VISIBILITY ---
                        _buildVisibilityToggle(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildImageGallerySection() {
    final totalImages = _existingImages.length + _newImages.length;
    final hasImages = totalImages > 0;

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: hasImages
          ? Stack(
              children: [
                PageView.builder(
                  itemCount: totalImages,
                  onPageChanged: (index) =>
                      setState(() => _currentImageIndex = index),
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
                      child: index < _existingImages.length
                          ? Image.network(
                              _existingImages[index],
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                        color: AppColors.primary,
                                      ),
                                    );
                                  },
                            )
                          : Image.file(
                              _newImages[index - _existingImages.length],
                              fit: BoxFit.cover,
                            ),
                    );
                  },
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                // Image indicators
                if (hasImages && totalImages > 1)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalImages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Photo count badge
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$totalImages/5",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add photo button
                if (totalImages < 5)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Add Photo",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Add Service Photos",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Upload up to 5 photos to showcase your service",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_a_photo, size: 20),
                    label: Text(
                      "Choose Photos",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[400]),
          prefixIcon: prefix,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: prefix != null ? 0 : 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOptionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.none,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              "No service options added yet",
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceOptionCard(int index, Map<String, dynamic> option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "Price: ",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextFormField(
                        initialValue: option['price'].toString(),
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          prefixText: "\$ ",
                          prefixStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) => _serviceOptions[index]['price'] =
                            double.tryParse(val) ?? 0.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            onPressed: () => setState(() => _serviceOptions.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOptionButton() {
    return InkWell(
      onTap: _showAddOptionModal,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              "Add Service Option",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add Service Option",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_availableSubTasks.isNotEmpty) ...[
                Text(
                  "Suggested Options",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ..._availableSubTasks.map(
                  (task) =>
                      _buildOptionListTile(task['name'], Icons.star_border, () {
                        setState(() {
                          if (!_serviceOptions.any(
                            (e) => e['name'] == task['name'],
                          )) {
                            _serviceOptions.add({
                              "name": task['name'],
                              "price": 0.0,
                            });
                          }
                        });
                        Navigator.pop(context);
                      }),
                ),
                const Divider(height: 32, thickness: 1),
              ],
              _buildOptionListTile(
                "Create Custom Option",
                Icons.edit_outlined,
                () {
                  Navigator.pop(context);
                  setState(() {
                    _serviceOptions.add({
                      "name": "New Service Option",
                      "price": 0.0,
                    });
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionListTile(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.add_circle, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypeSelector() {
    return InkWell(
      onTap: _showServiceLocationModal,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _serviceLocation,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showServiceLocationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Service Type",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLocationOption("Default (Home Service)"),
            _buildLocationOption("Default (Outdoor Service)"),
            _buildLocationOption("Both (Home & Outdoor)"),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOption(String value) {
    bool isSelected = _serviceLocation.contains(value.split(" ")[0]);
    return InkWell(
      onTap: () {
        setState(() => _serviceLocation = value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _weeklySchedule.asMap().entries.map((entry) {
          return _buildAvailabilityRow(entry.key);
        }).toList(),
      ),
    );
  }

  Widget _buildAvailabilityRow(int index) {
    var dayData = _weeklySchedule[index];
    bool isActive = dayData['active'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: index < _weeklySchedule.length - 1
            ? Border(bottom: BorderSide(color: Colors.grey[200]!))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: isActive,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) =>
                      setState(() => _weeklySchedule[index]['active'] = val!),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 85,
                child: Text(
                  dayData['day'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isActive ? Colors.black87 : Colors.grey[400],
                  ),
                ),
              ),
              const Spacer(),
              if (!isActive)
                Text(
                  "Closed",
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildTimeBox(dayData['start'], () => _selectTime(index, true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ),
                _buildTimeBox(dayData['end'], () => _selectTime(index, false)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeBox(String time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isVisible ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Service Visibility",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isVisible
                          ? "Visible to all customers"
                          : "Hidden from your catalog",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _isVisible,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isVisible = val),
                ),
              ),
            ],
          ),
          if (!_isVisible) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This service is hidden and won't appear in your public catalog",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
