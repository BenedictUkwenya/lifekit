import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import 'login_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';

class SignupFlowWrapper extends StatefulWidget {
  const SignupFlowWrapper({super.key});

  @override
  State<SignupFlowWrapper> createState() => _SignupFlowWrapperState();
}

class _SignupFlowWrapperState extends State<SignupFlowWrapper> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();

  // --- STATE DATA ---
  String fullName = "";
  String email = "";
  String password = "";
  String confirmPassword = ""; // 1. Added this variable
  File? _imageFile;
  bool isLoading = false;

  // --- ACTIONS ---

  void nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void showError(String message) {
    if (!mounted) return;
    // 2. CLEAN THE ERROR MESSAGE (Remove "Exception: ")
    String cleanMessage = message.replaceAll("Exception: ", "");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cleanMessage), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // 1. Submit Details (Signup)
  Future<void> submitDetailsAndPass() async {
    setState(() => isLoading = true);
    try {
      await _apiService.signup(fullName, email, password);
      if (mounted) {
        setState(() => isLoading = false);
        nextPage(); // Go to OTP Screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError(e.toString());
      }
    }
  }

  // 2. Resend OTP
  Future<void> resendOtp() async {
    setState(() => isLoading = true);
    try {
      await _apiService.signup(fullName, email, password);
      if (mounted) {
        setState(() => isLoading = false);
        showSuccess("Code resent successfully! Check your email.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError("Could not resend code. Please try again.");
      }
    }
  }

  // 3. Verify OTP
  Future<void> verifyOtp(String code) async {
    setState(() => isLoading = true);
    try {
      await _apiService.verifyOtp(email, code);
      if (mounted) {
        setState(() => isLoading = false);
        nextPage(); // Go to Profile Pic Screen
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError(e.toString());
      }
    }
  }

  // 4. Upload & Finish
  Future<void> uploadAndFinish() async {
    setState(() => isLoading = true);
    try {
      if (_imageFile != null) {
        await _apiService.uploadProfilePic(_imageFile!);
      }

      showSuccess("Account Created! Redirecting...");
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      showError("Profile setup failed, but account is active.");
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildDetailsScreen(),
          _buildPasswordScreen(),
          _buildOtpScreen(),
          _buildProfileScreen(),
        ],
      ),
    );
  }

  // --- SCREEN 1: DETAILS ---
  Widget _buildDetailsScreen() {
    return _BaseAuthLayout(
      title: "Hi, Welcome to LifeKit",
      subtitle:
          "Please complete all information to create your LifeKit account",
      onBack: () => Navigator.of(context).pop(),
      children: [
        _CustomTextField(
          label: "Full Name",
          initialValue: fullName,
          onChanged: (val) => fullName = val,
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          label: "Email Address",
          initialValue: email,
          onChanged: (val) => email = val,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 30),
        _PrimaryButton(
          text: "Continue",
          onTap: () {
            if (fullName.isNotEmpty && email.isNotEmpty) {
              nextPage();
            } else {
              showError("Please fill all fields");
            }
          },
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text("or", style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 24),
        _SocialButton(icon: Icons.g_mobiledata, text: "Continue with Google"),
        const SizedBox(height: 16),
        _SocialButton(icon: Icons.apple, text: "Continue with Apple"),
        const Spacer(),
        Center(
          child: RichText(
            text: TextSpan(
              text: "Already have an account? ",
              style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: "Sign In",
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- SCREEN 2: PASSWORD ---
  Widget _buildPasswordScreen() {
    return _BaseAuthLayout(
      title: "Choose a password",
      subtitle: "Input your preferred password to access your account",
      onBack: previousPage,
      children: [
        _CustomTextField(
          label: "Enter password",
          initialValue: password,
          isPassword: true,
          onChanged: (val) => password = val,
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          label: "Confirm your password",
          isPassword: true,
          // 3. STORE CONFIRM PASSWORD
          onChanged: (val) => confirmPassword = val,
        ),
        const SizedBox(height: 30),
        isLoading
            ? const Center(child: const LifeKitLoader())
            : _PrimaryButton(
                text: "Submit",
                onTap: () {
                  // 4. VALIDATE PASSWORDS MATCH
                  if (password != confirmPassword) {
                    showError("Passwords do not match");
                    return;
                  }

                  if (password.length > 6) {
                    submitDetailsAndPass();
                  } else {
                    showError("Password must be at least 6 characters");
                  }
                },
              ),
        const Spacer(),
      ],
    );
  }

  // --- SCREEN 3: OTP ---
  Widget _buildOtpScreen() {
    return _BaseAuthLayout(
      title: "Verify Email",
      subtitle: "Code has been sent to $email",
      onBack: previousPage,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Pinput(
            length: 6,
            defaultPinTheme: PinTheme(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFF9F9F9),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            onCompleted: (pin) => verifyOtp(pin),
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : resendOtp,
            child: Text(
              isLoading ? "Sending..." : "Didn't get OTP Code? Resend Code",
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (isLoading) const Center(child: const LifeKitLoader()),
        const Spacer(),
      ],
    );
  }

  // --- SCREEN 4: PROFILE PIC ---
  Widget _buildProfileScreen() {
    return _BaseAuthLayout(
      title: "Profile Setup",
      subtitle: "Please enter your name and an optional profile picture",
      onBack: null,
      children: [
        const SizedBox(height: 40),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : null,
                child: _imageFile == null
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() => _imageFile = File(image.path));
                    }
                  },
                  child: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 18,
                    child: Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              fullName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const Spacer(),
        isLoading
            ? const Center(child: const LifeKitLoader())
            : _PrimaryButton(text: "Finish", onTap: uploadAndFinish),
        const SizedBox(height: 30),
      ],
    );
  }
}

// --- REUSABLE WIDGETS ---

class _BaseAuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  const _BaseAuthLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (onBack != null)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, size: 18),
                              onPressed: onBack,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          if (onBack == null) const SizedBox(height: 48),

                          const SizedBox(height: 10),
                          Center(
                            child: Image.asset(
                              'assets/images/logo_black.png',
                              height: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- THE FIXED CUSTOM TEXT FIELD ---
// Keeps the stateful logic so the eye icon works
class _CustomTextField extends StatefulWidget {
  final String label;
  final Function(String) onChanged;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? initialValue;

  const _CustomTextField({
    required this.label,
    required this.onChanged,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.initialValue,
  });

  @override
  State<_CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<_CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        initialValue: widget.initialValue,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.label,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SocialButton({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
