import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'my_services_list_screen.dart';

class ProviderOnboardingIntroScreen extends StatefulWidget {
  const ProviderOnboardingIntroScreen({super.key});

  @override
  State<ProviderOnboardingIntroScreen> createState() =>
      _ProviderOnboardingIntroScreenState();
}

class _ProviderOnboardingIntroScreenState
    extends State<ProviderOnboardingIntroScreen> {
  final ApiService _apiService = ApiService();
  bool isLoading = false;

  Future<void> _upgradeAccount() async {
    setState(() => isLoading = true);
    try {
      await _apiService.onboardAsProvider();
      if (mounted) {
        // Navigate to the Provider Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyServicesListScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.black)),
        ),
        leadingWidth: 80,
        title: Text(
          "Change account setup",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: isLoading ? null : _upgradeAccount,
            child: Text(
              "Next",
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 100,
              color: AppColors.primary,
            ),
            const SizedBox(height: 40),
            Text(
              "Changing account setup allows that you're about to migrate your account info, groups, and settings from your current account to a business account.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
