import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  File? _imageFile;
  String _serviceLocation = "Home Service (HS)"; // Matches Catalog
  String _pricingType = "fixed"; // 'fixed' or 'hourly'
  bool _isVisible = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill existing data
    _titleController.text = widget.service['title'] ?? "";
    if (widget.service['price'] != null && widget.service['price'] != 0) {
      _priceController.text = widget.service['price'].toString();
    }
    _descController.text = widget.service['description'] ?? "";

    // Load saved types if they exist
    _pricingType = widget.service['pricing_type'] ?? 'fixed';
    _serviceLocation = widget.service['service_type'] ?? "Home Service (HS)";
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  void _showServiceLocationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Service Location",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // SPECIFIC OPTIONS FOR CATALOG
              _buildRadioOption("Home Service (HS)"),
              _buildRadioOption("Out Service / Studio (OS)"),
              _buildRadioOption("Hybrid (Both Available)"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioOption(String value) {
    return RadioListTile(
      title: Text(value, style: GoogleFonts.poppins(fontSize: 14)),
      value: value,
      groupValue: _serviceLocation,
      activeColor: AppColors.primary,
      onChanged: (val) {
        setState(() => _serviceLocation = val.toString());
        Navigator.pop(context);
      },
    );
  }

  Future<void> _saveService() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
      return;
    }
    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a price")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> imageUrls = [];

      // Handle Image Upload
      if (_imageFile != null) {
        String url = await _apiService.uploadServiceImage(_imageFile!);
        imageUrls.add(url);
      } else {
        // Keep existing images if no new one selected
        if (widget.service['image_urls'] != null) {
          for (var img in widget.service['image_urls']) {
            if (img is String)
              imageUrls.add(img);
            else if (img is List && img.isNotEmpty)
              imageUrls.add(img[0]);
          }
        }
      }

      // Update Service via API
      await _apiService.updateService(widget.service['id'], {
        "title": _titleController.text,
        "description": _descController.text,
        "price": double.parse(_priceController.text),
        "service_type": _serviceLocation, // Saves "Home Service (HS)" etc.
        "pricing_type": _pricingType, // Saves "hourly" or "fixed"
        "image_urls": imageUrls,
        "status": _isVisible ? "active" : "draft",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Service Saved Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Edit Service",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveService,
            child: Text(
              "Save",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Add photos",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  _buildLabel("Service Title"),
                  _buildTextField(_titleController, "e.g. Luxury Hair Cut"),

                  const SizedBox(height: 16),

                  // Pricing Model Toggle (Fixed vs Hourly)
                  _buildLabel("Pricing Model"),
                  Row(
                    children: [
                      _buildPricingChip("Fixed Price", "fixed"),
                      const SizedBox(width: 10),
                      _buildPricingChip("Hourly Rate", "hourly"),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price Input
                  _buildLabel(
                    _pricingType == 'fixed' ? "Total Amount" : "Rate per Hour",
                  ),
                  _buildTextField(_priceController, "0.00", isNumber: true),

                  const SizedBox(height: 16),

                  // Description
                  _buildLabel("Description"),
                  _buildTextField(
                    _descController,
                    "Describe your service...",
                    maxLines: 5,
                  ),

                  const SizedBox(height: 16),

                  // Service Location (HS / OS)
                  _buildLabel("Service Location"),
                  GestureDetector(
                    onTap: _showServiceLocationModal,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_serviceLocation, style: GoogleFonts.poppins()),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Visibility Toggle
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        "Submit for Public Review",
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      subtitle: Text(
                        "Turn this on to publish.",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      value: _isVisible,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _isVisible = val);
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPricingChip(String label, String value) {
    bool isSelected = _pricingType == value;
    return GestureDetector(
      onTap: () => setState(() => _pricingType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: maxLines > 1 ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }
}
