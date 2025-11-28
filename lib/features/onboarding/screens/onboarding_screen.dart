import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/screens/signup_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // DATA: The content for your 4 slides
  final List<Map<String, String>> _onboardingData = [
    {
      "image": "assets/images/onboarding1.png",
      "title": "Offer Your Skills.\nEarn on Your Terms",
      "desc":
          "Turn your talent into income by offering your services to a vibrant community that values what you do.",
    },
    {
      "image": "assets/images/onboarding2.png",
      "title": "Offer Your Skills.\nEarn on Your Terms",
      "desc":
          "Turn your talent into income by offering your services to a vibrant community that values what you do.",
    },
    {
      "image": "assets/images/onboarding3.png",
      "title": "Book Trusted\nServices Anytime,\nAnywhere",
      "desc":
          "Get access to reliable services near you, from beauty to home repairs, wellness, personal care, and more - all in one app.",
    },
    {
      "image": "assets/images/onboarding4.png",
      "title": "Where Community\nMeets Opportunity",
      "desc": "Connect, share, and grow with people who get you.",
    },
  ];

  // Action: Finish Onboarding and Save State
  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignupFlowWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP BAR (Logo + Skip)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Small Logo Icon
                  Image.asset(
                    'assets/images/logo_black.png',
                    width: 30,
                    height: 30,
                  ),

                  // Skip Button
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      "Skip",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. PAGE VIEW (Images & Text)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double screenHeight = constraints.maxHeight;
                        // Adjust image height relative to screen space
                        double imageHeight = screenHeight * 0.75;

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- UPDATED IMAGE SECTION ---
                              Center(
                                child: SizedBox(
                                  height: imageHeight,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Layer 1: The Background Blob (#89273B1F)
                                      // Make sure to add this image to your assets folder!
                                      Image.asset(
                                        'assets/images/background_bg.png',
                                        height:
                                            imageHeight, // Matches container height
                                        width: double.infinity,
                                        fit: BoxFit
                                            .contain, // Ensures the blob fits nicely
                                      ),

                                      // Layer 2: The Main Illustration
                                      Image.asset(
                                        _onboardingData[index]['image']!,
                                        height:
                                            imageHeight *
                                            0.8, // Slightly smaller to sit "inside" the blob
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // -----------------------------
                              const SizedBox(height: 32),

                              // Title
                              Text(
                                _onboardingData[index]['title']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  height: 1.2,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Description
                              Text(
                                _onboardingData[index]['desc']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColors.textGrey,
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // 3. BOTTOM CONTROLS (Dots + Next Button)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Dots Indicator
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => buildDot(index: index),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentIndex == _onboardingData.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Next",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

  // Helper to build the animated dots
  Widget buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 6),
      height: 6,
      width: _currentIndex == index ? 24 : 6,
      decoration: BoxDecoration(
        color: _currentIndex == index
            ? AppColors.primary
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
