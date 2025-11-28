import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Make sure to add this package
import 'package:cached_network_image/cached_network_image.dart';

class ShareProfileScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  const ShareProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background as per Figma
      appBar: AppBar(
        title: Text(
          "Share your profile",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile['full_name'] ?? 'User',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                profile['username'] != null
                    ? "@${profile['username']}"
                    : "No username",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              QrImageView(
                data: "lifekit://profile/${profile['id']}",
                version: QrVersions.auto,
                size: 200.0,
                // embeddedImage: const AssetImage('assets/images/logo_white.png'), // Optional logo in middle
              ),

              const SizedBox(height: 24),
              const Text("Scan to connect with this user on LifeKit"),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareAction(Icons.ios_share, "Share"),
                  _buildShareAction(Icons.copy, "Copy"),
                  _buildShareAction(Icons.download, "Save"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareAction(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ],
    );
  }
}
