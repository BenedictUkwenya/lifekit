import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  File? _imageFile;
  bool _anyoneCanPost = true;
  bool _isLoading = false;

  // --- CONTENT SAFETY FILTER (REUSABLE) ---
  bool _isSafe(String text) {
    final clean = text.toLowerCase().replaceAll(' ', '');
    // Regex for phone/email
    final hasEmail = clean.contains('@') || clean.contains('.com');
    final hasPhone = RegExp(r'\d{10,}').hasMatch(clean);
    final blacklist = [
      'whatsapp',
      'callme',
      'telegram',
      'zelle',
      'cashapp',
      'payme',
    ];
    final hasBlacklisted = blacklist.any((word) => clean.contains(word));

    return !hasEmail && !hasPhone && !hasBlacklisted;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  void _handleCreate() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || desc.isEmpty) {
      _showSnack("Please fill in all fields", isError: true);
      return;
    }

    if (!_isSafe(name) || !_isSafe(desc)) {
      _showSnack(
        "Safety Warning: Contact details or external payment keywords are not allowed.",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedUrl;
      if (_imageFile != null) {
        // Reuse your existing service image upload logic
        uploadedUrl = await _apiService.uploadServiceImage(_imageFile!);
      }

      await _apiService.createGroup(
        name: name,
        description: desc,
        imageUrl: uploadedUrl,
        anyoneCanPost: _anyoneCanPost,
      );

      if (mounted) {
        _showSnack("Group Created Successfully!", isSuccess: true);
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          "Start a Community",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: LifeKitLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. IMAGE PICKER
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
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
                                  Icons.add_a_photo_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Add Group Cover",
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 2. INPUTS
                  _buildLabel("Group Name"),
                  _buildTextField(
                    _nameController,
                    "e.g. Graphic Designers Hub",
                    1,
                  ),

                  const SizedBox(height: 20),

                  _buildLabel("Description"),
                  _buildTextField(
                    _descController,
                    "What is this group about?",
                    4,
                  ),

                  const SizedBox(height: 30),

                  // 3. PERMISSIONS TOGGLE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_open_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Open Posting",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "Allow all members to post in this group",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _anyoneCanPost,
                          activeColor: AppColors.primary,
                          onChanged: (val) =>
                              setState(() => _anyoneCanPost = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4. SUBMIT
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _handleCreate,
                      child: Text(
                        "Create Group",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      "By creating a group, you agree to follow LifeKit community guidelines.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey,
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
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    int maxLines,
  ) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.redAccent
            : (isSuccess ? Colors.green : Colors.black87),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
