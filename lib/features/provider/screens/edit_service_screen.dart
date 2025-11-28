import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

class EditServiceScreen extends StatefulWidget {
  final dynamic service; // The draft service object

  const EditServiceScreen({super.key, required this.service});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final ApiService _apiService = ApiService();

  // Controllers
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // State
  File? _imageFile;
  String _serviceType = "Default (Home Service)";
  bool _isVisible = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing an existing service
    if (widget.service['price'] != null && widget.service['price'] != 0) {
      _priceController.text = widget.service['price'].toString();
    }
    _descController.text = widget.service['description'] ?? "";
  }

  // --- ACTIONS ---

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  void _showServiceTypeModal() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Service type",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildRadioOption("Default (Home Service)"),
              _buildRadioOption("Default (Outdoor Service)"),
              _buildRadioOption("Both (Home & Outdoor)"),
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
      groupValue: _serviceType,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) {
        setState(() => _serviceType = val.toString());
        Navigator.pop(context);
      },
    );
  }

  Future<void> _saveService() async {
    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a price")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> imageUrls = [];

      // 1. Upload Image if selected
      if (_imageFile != null) {
        String url = await _apiService.uploadServiceImage(_imageFile!);
        imageUrls.add(url);
      } else {
        // Keep existing images if no new one picked
        if (widget.service['image_urls'] != null) {
          imageUrls = List<String>.from(widget.service['image_urls']);
        }
      }

      // 2. Update Service Data via API
      // We use a direct HTTP PUT here since ApiService needs a specific update method
      // Or add 'updateService' to ApiService. For now, I'll simulate the logic here.

      String? token = await _apiService.storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('${_apiService.baseUrl}/services/${widget.service['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "title": widget.service['title'], // Keep original title
          "description": _descController.text,
          "price": double.parse(_priceController.text),
          "service_type": _serviceType,
          "image_urls": imageUrls,
          "status": _isVisible ? "active" : "draft", // Publish if visible
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Service Saved!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to list
        }
      } else {
        throw Exception("Failed to update");
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
        centerTitle: true,
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
          ? const Center(child: const LifeKitLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. IMAGE PICKER
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

                  // 2. SERVICE TITLE (Read Only)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.service['title'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. PRICE INPUTS
                  _buildLabel("Fixed price"),
                  _buildTextField(
                    _priceController,
                    "Price (per hour)",
                    isNumber: true,
                  ),

                  const SizedBox(height: 16),

                  // 4. DESCRIPTION
                  _buildLabel("Description"),
                  Container(
                    height: 120,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Describe your service...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. SERVICE TYPE
                  GestureDetector(
                    onTap: _showServiceTypeModal,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Service type",
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                          Row(
                            children: [
                              Text(
                                _serviceType.split(' ')[0],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. VISIBILITY TOGGLE
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        "Not visible to public",
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      subtitle: Text(
                        "When you hide an item, customers won't see it in your catalog.",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      value: !_isVisible, // Logic inverted based on UI text
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _isVisible = !val);
                      },
                    ),
                  ),

                  const SizedBox(height: 40),

                  // DELETE BUTTON (Optional)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Handle delete logic
                      },
                      child: Text(
                        "Delete Service",
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                  ),
                ],
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
        ),
      ),
    );
  }
}
