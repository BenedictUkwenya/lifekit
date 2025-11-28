import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'wallet_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'share_profile_screen.dart';
import 'settings_sub_screens.dart';
import '../../../core/widgets/lifekit_loader.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _apiService.getUserProfile();
      if (mounted) {
        setState(() {
          profile = data['profile'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile: $e"); // Debug print
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _logout() async {
    final storage =
        const FlutterSecureStorage(); // Import this if needed or reuse from ApiService
    await storage.deleteAll(); // Clear token

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. LOADING STATE
    if (isLoading) {
      return const Center(child: const LifeKitLoader());
    }

    // 2. ERROR STATE (Fix for the Crash)
    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text("Failed to load profile", style: GoogleFonts.poppins()),
              TextButton(
                onPressed: () {
                  setState(() => isLoading = true);
                  _fetchProfile();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // 3. SUCCESS STATE (Safe to use profile!)
    final String name = profile!['full_name'] ?? 'User';
    final String bio = profile!['bio'] ?? 'No bio added';
    final String? pic = profile!['profile_picture_url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Profile",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // PROFILE CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: pic != null
                          ? CachedNetworkImageProvider(pic)
                          : null,
                      child: pic == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bio,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.ios_share),
                      onPressed: () {
                        // Safe because we checked profile == null above
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShareProfileScreen(profile: profile!),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // BUSINESS TOOLS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF89273B), // Maroon
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Business tools",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildToolIcon(Icons.person_outline, "Profile", () {}),
                        _buildToolIcon(
                          Icons.add_circle_outline,
                          "Services",
                          () {
                            // Navigate to Services List logic here
                          },
                        ),
                        _buildToolIcon(
                          Icons.account_balance_wallet_outlined,
                          "Wallet",
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          },
                        ),
                        _buildToolIcon(Icons.card_giftcard, "Rewards", () {}),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // GENERAL SETTINGS
              Text(
                "General setting",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      Icons.lock_outline,
                      "Personal Information",
                      () async {
                        // Re-fetch on return to update the UI with new name/bio
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditProfileScreen(profile: profile!),
                          ),
                        );
                        _fetchProfile();
                      },
                    ),
                    _buildSettingTile(
                      Icons.security,
                      "Password & Security",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SecurityScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingTile(
                      Icons.notifications_none,
                      "Notification Preferences",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildSettingTile(Icons.language, "Languages", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageScreen(),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // OTHER
              Text(
                "Other",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildSettingTile(Icons.help_outline, "Help Center", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      );
                    }),
                    _buildSettingTile(
                      Icons.logout,
                      "Logout",
                      _logout,
                      isRed: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isRed = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.withOpacity(0.1) : const Color(0xFFFFF0F3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isRed ? Colors.red : const Color(0xFF89273B),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
