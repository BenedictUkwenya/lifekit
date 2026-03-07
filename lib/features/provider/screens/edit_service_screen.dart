import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class EditServiceScreen extends StatefulWidget {
  final dynamic service;
  const EditServiceScreen({super.key, required this.service});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final ApiService _apiService = ApiService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final List<File> _newImages = [];
  final List<String> _existingImages = [];
  int _currentImageIndex = 0;

  String _serviceLocation = 'Home Service (HS)';
  String _pricingType = 'fixed';
  bool _isVisible = true;
  bool _isLoading = false;

  List<String> _locationOptions = [];
  bool _isStandalone = false;
  List<Map<String, dynamic>> _serviceOptions = [];
  List<dynamic> _availableSubTasks = [];

  final List<Map<String, dynamic>> _weeklySchedule = [
    {'day': 'Monday', 'active': false, 'start': '09:00', 'end': '17:00'},
    {'day': 'Tuesday', 'active': false, 'start': '09:00', 'end': '17:00'},
    {'day': 'Wednesday', 'active': false, 'start': '09:00', 'end': '17:00'},
    {'day': 'Thursday', 'active': false, 'start': '09:00', 'end': '17:00'},
    {'day': 'Friday', 'active': false, 'start': '09:00', 'end': '17:00'},
    {'day': 'Saturday', 'active': false, 'start': '10:00', 'end': '15:00'},
    {'day': 'Sunday', 'active': false, 'start': '10:00', 'end': '15:00'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _basePriceController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    _titleController.text = widget.service['title'] ?? '';
    _descController.text = widget.service['description'] ?? '';
    _locationController.text = widget.service['location_text'] ?? '';
    _serviceLocation = widget.service['service_type'] ?? 'Home Service (HS)';
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
        if (category['is_standalone'] ?? false) {
          final subs = await _apiService.getSubCategories(catId);
          setState(() {
            _isStandalone = true;
            _availableSubTasks = subs;
          });
        }
      }
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => _newImages.add(File(image.path)));
  }

  void _removeExistingImage(int index) => setState(() {
    _existingImages.removeAt(index);
    _currentImageIndex = 0;
  });

  void _removeNewImage(int index) => setState(() {
    _newImages.removeAt(index);
    _currentImageIndex = 0;
  });

  Future<void> _selectTime(int index, bool isStart) async {
    if (!_weeklySchedule[index]['active']) return;
    final parts =
        (isStart
                ? _weeklySchedule[index]['start']
                : _weeklySchedule[index]['end'])
            .split(':');
    _showIOSTimePicker(
      initialHour: int.parse(parts[0]),
      initialMinute: int.parse(parts[1]),
      onTimeSelected: (h, m) => setState(() {
        final t =
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        if (isStart) {
          _weeklySchedule[index]['start'] = t;
        } else {
          _weeklySchedule[index]['end'] = t;
        }
      }),
    );
  }

  void _showIOSTimePicker({
    required int initialHour,
    required int initialMinute,
    required Function(int, int) onTimeSelected,
  }) {
    int tempH = initialHour, tempM = initialMinute;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 320,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    'Select Time',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onTimeSelected(tempH, tempM);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: tempH,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempH = i,
                      children: List.generate(
                        24,
                        (i) => Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    ':',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: tempM,
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => tempM = i,
                      children: List.generate(
                        60,
                        (i) => Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

  Future<void> _saveService() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a service title', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      List<String> finalImageUrls = [..._existingImages];
      for (var file in _newImages) {
        finalImageUrls.add(await _apiService.uploadServiceImage(file));
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
        'title': _titleController.text,
        'description': _descController.text,
        'price': finalPrice,
        'service_type': _serviceLocation,
        'location_text': _locationController.text,
        'pricing_type': _pricingType,
        'image_urls': finalImageUrls,
        'status': _isVisible ? 'active' : 'draft',
        'availability': _weeklySchedule,
        'service_options': _isStandalone ? _serviceOptions : [],
      });
      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar('Service updated!', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoader() : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Edit Service',
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black87,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveService,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            'Updating service…',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Image gallery ─────────────────────
          _buildImageSection(),

          // ── Form ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  children: [
                    _buildSectionHeader('Service Title', Icons.title_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'e.g., Bridal Hair Styling',
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildCard(
                  children: [
                    _buildSectionHeader('Pricing', Icons.payments_outlined),
                    const SizedBox(height: 12),
                    if (_isStandalone) ...[
                      if (_serviceOptions.isEmpty) _buildEmptyOptions(),
                      ..._serviceOptions.asMap().entries.map(
                        (e) => _buildOptionTile(e.key, e.value),
                      ),
                      const SizedBox(height: 8),
                      _buildAddOptionBtn(),
                    ] else ...[
                      // Pricing type toggle
                      _buildPricingTypeToggle(),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _basePriceController,
                        hint: _pricingType == 'fixed'
                            ? 'Fixed price (e.g., 150)'
                            : 'Hourly rate (e.g., 50)',
                        keyboardType: TextInputType.number,
                        prefixWidget: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          child: Text(
                            '\$',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                _buildCard(
                  children: [
                    _buildSectionHeader(
                      'Description',
                      Icons.description_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descController,
                      hint:
                          'Describe your service, what\'s included, requirements…',
                      maxLines: 5,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildCard(
                  children: [
                    _buildSectionHeader('Service Details', Icons.tune_rounded),
                    const SizedBox(height: 16),
                    // Service type
                    _buildFieldLabel('Service Type'),
                    const SizedBox(height: 8),
                    _buildServiceTypeSelector(),
                    const SizedBox(height: 16),
                    // Location
                    _buildFieldLabel('Location (Optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _locationController,
                      hint: 'Specific address or area',
                      prefixWidget: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 6),
                        child: Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildCard(
                  children: [
                    _buildSectionHeader(
                      'Weekly Availability',
                      Icons.calendar_month_outlined,
                    ),
                    const SizedBox(height: 4),
                    _buildAvailabilitySection(),
                  ],
                ),

                const SizedBox(height: 14),

                _buildVisibilityCard(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // IMAGE SECTION
  // ─────────────────────────────────────────
  Widget _buildImageSection() {
    final total = _existingImages.length + _newImages.length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Main preview
          SizedBox(
            height: 260,
            width: double.infinity,
            child: total == 0
                ? _buildEmptyImageState()
                : _buildImageCarousel(total),
          ),
          // Thumbnail strip
          if (total > 0) _buildThumbnailStrip(total),
        ],
      ),
    );
  }

  Widget _buildEmptyImageState() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        color: const Color(0xFFF7F7F9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Service Photos',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to upload up to 5 photos',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel(int total) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: total,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (_, i) {
            if (i < _existingImages.length) {
              return Image.network(
                _existingImages[i],
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
              );
            }
            return Image.file(
              _newImages[i - _existingImages.length],
              fit: BoxFit.cover,
            );
          },
        ),
        // Gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
              ),
            ),
          ),
        ),
        // Photo count badge
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  '$total/5',
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
        // Delete current photo
        Positioned(
          top: 14,
          left: 14,
          child: GestureDetector(
            onTap: () {
              if (_currentImageIndex < _existingImages.length) {
                _removeExistingImage(_currentImageIndex);
              } else {
                _removeNewImage(_currentImageIndex - _existingImages.length);
              }
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        // Dot indicators
        if (total > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                total,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        // Add photo button
        if (total < 5)
          Positioned(
            bottom: 14,
            right: 14,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailStrip(int total) {
    return Container(
      height: 72,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total < 5 ? total + 1 : total, // +1 for add button
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          // Add new button at end
          if (i == total && total < 5) {
            return GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                  color: AppColors.primary.withOpacity(0.05),
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            );
          }
          // Thumbnail
          final isSelected = i == _currentImageIndex;
          return GestureDetector(
            onTap: () => setState(() => _currentImageIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: i < _existingImages.length
                    ? Image.network(_existingImages[i], fit: BoxFit.cover)
                    : Image.file(
                        _newImages[i - _existingImages.length],
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // CARD WRAPPER
  // ─────────────────────────────────────────
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (prefixWidget != null)
            Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
              child: prefixWidget,
            ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: prefixWidget != null ? 4 : 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // PRICING TYPE TOGGLE
  // ─────────────────────────────────────────
  Widget _buildPricingTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['fixed', 'hourly'].map((type) {
          final isSelected = _pricingType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _pricingType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == 'fixed' ? Icons.price_check : Icons.access_time,
                      size: 15,
                      color: isSelected ? Colors.white : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type == 'fixed' ? 'Fixed Price' : 'Hourly Rate',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SERVICE OPTIONS
  // ─────────────────────────────────────────
  Widget _buildEmptyOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.list_alt_outlined, size: 36, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No options added yet',
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index, Map<String, dynamic> option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 110,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextFormField(
                      initialValue: option['price'].toString(),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => _serviceOptions[index]['price'] =
                          double.tryParse(v) ?? 0.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            onPressed: () => setState(() => _serviceOptions.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOptionBtn() {
    return GestureDetector(
      onTap: _showAddOptionModal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Service Option',
              style: GoogleFonts.poppins(
                fontSize: 14,
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Option',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_availableSubTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'SUGGESTED',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              ..._availableSubTasks.map(
                (task) =>
                    _buildOptionListItem(task['name'], Icons.star_outline, () {
                      setState(() {
                        if (!_serviceOptions.any(
                          (e) => e['name'] == task['name'],
                        )) {
                          _serviceOptions.add({
                            'name': task['name'],
                            'price': 0.0,
                          });
                        }
                      });
                      Navigator.pop(context);
                    }),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
            ],
            _buildOptionListItem('Custom Option', Icons.edit_outlined, () {
              setState(
                () => _serviceOptions.add({
                  'name': 'New Service Option',
                  'price': 0.0,
                }),
              );
              Navigator.pop(context);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionListItem(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.add, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SERVICE TYPE SELECTOR
  // ─────────────────────────────────────────
  Widget _buildServiceTypeSelector() {
    return GestureDetector(
      onTap: _showServiceLocationModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _serviceLocation,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceLocationModal() {
    final options = _locationOptions.isNotEmpty
        ? _locationOptions
        : ['Home Service (HS)', 'Outdoor Service (OS)', 'Both (HS & OS)'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Service Type',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...options.map(
              (opt) => GestureDetector(
                onTap: () {
                  setState(() => _serviceLocation = opt);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _serviceLocation == opt
                        ? AppColors.primary.withOpacity(0.08)
                        : const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _serviceLocation == opt
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _serviceLocation == opt
                                ? AppColors.primary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (_serviceLocation == opt)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // AVAILABILITY
  // ─────────────────────────────────────────
  Widget _buildAvailabilitySection() {
    return Column(
      children: _weeklySchedule
          .asMap()
          .entries
          .map((e) => _buildDayRow(e.key))
          .toList(),
    );
  }

  Widget _buildDayRow(int index) {
    final day = _weeklySchedule[index];
    final active = day['active'] as bool;
    final isLast = index == _weeklySchedule.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Day toggle as a pill
              GestureDetector(
                onTap: () =>
                    setState(() => _weeklySchedule[index]['active'] = !active),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    day['day'].toString().substring(0, 3),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!active)
                Expanded(
                  child: Text(
                    'Closed',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              if (active) ...[
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildTimeChip(
                        day['start'],
                        () => _selectTime(index, true),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '–',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildTimeChip(
                        day['end'],
                        () => _selectTime(index, false),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _buildTimeChip(String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // VISIBILITY CARD
  // ─────────────────────────────────────────
  Widget _buildVisibilityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (_isVisible ? Colors.green : Colors.grey).withOpacity(
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _isVisible ? Colors.green[600] : Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Visibility',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _isVisible
                          ? 'Visible to all customers'
                          : 'Hidden from your catalog',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isVisible,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isVisible = v),
              ),
            ],
          ),
          if (!_isVisible) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This service won\'t appear in your public catalog',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[700],
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
