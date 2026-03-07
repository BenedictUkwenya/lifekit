import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../home/screens/home_screen.dart';
import 'signup_screen.dart'; // AppToast + _friendlyError live here now

String _friendlyError(dynamic raw) {
  final msg = raw
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll('exception: ', '')
      .toLowerCase()
      .trim();

  if (msg.contains('invalid login') ||
      msg.contains('invalid credentials') ||
      msg.contains('wrong password') ||
      msg.contains('incorrect password')) {
    return 'Wrong email or password. Please try again.';
  }
  if (msg.contains('email already') ||
      msg.contains('already registered') ||
      msg.contains('already in use') ||
      msg.contains('duplicate')) {
    return 'This email is already registered. Try signing in instead.';
  }
  if (msg.contains('user not found') || msg.contains('no user')) {
    return "We couldn't find an account with that email.";
  }
  if (msg.contains('invalid email') || msg.contains('email format')) {
    return 'Please enter a valid email address.';
  }
  if (msg.contains('weak password') || msg.contains('password too short')) {
    return 'Your password is too weak. Try something longer.';
  }
  if (msg.contains('otp') ||
      msg.contains('token') ||
      msg.contains('code') ||
      msg.contains('expired')) {
    return 'That code is invalid or expired. Please request a new one.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (msg.contains('timeout')) {
    return 'The request timed out. Please try again.';
  }
  if (msg.contains('session expired') || msg.contains('unauthorized')) {
    return 'Your session expired. Please sign in again.';
  }
  if (msg.contains('server error') ||
      msg.contains('500') ||
      msg.contains('internal')) {
    return 'Something went wrong on our end. Please try again shortly.';
  }

  // Last resort: capitalise the raw message if it's short enough to show
  final clean = raw.toString().replaceAll('Exception: ', '').trim();
  if (clean.length < 80) return clean;
  return 'Something went wrong. Please try again.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool isLoading = false;
  bool isPasswordVisible = false;

  Future<void> handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // ── Client-side validation first ───────────────────────
    if (email.isEmpty) {
      AppToast.error(context, 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      AppToast.error(context, 'That doesn\'t look like a valid email.');
      return;
    }
    if (password.isEmpty) {
      AppToast.error(context, 'Please enter your password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _apiService.login(email, password);
      if (mounted) {
        AppToast.success(context, 'Welcome back! 👋');
        await Future.delayed(const Duration(milliseconds: 800));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, _friendlyError(e));
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
      body: LayoutBuilder(
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
                        child: Center(
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo_black.png',
                                height: 50,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Sign in to LifeKit',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Good to have you back 👋',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      _LoginTextField(
                        controller: _emailController,
                        hintText: 'Email address',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _LoginTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        isPassword: true,
                        isVisible: isPasswordVisible,
                        onVisibilityToggle: () => setState(
                          () => isPasswordVisible = !isPasswordVisible,
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Forgot password
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 24),

                      Row(
                        children: const [
                          Expanded(child: Divider(color: Colors.grey)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _SocialButton(
                        icon: Icons.g_mobiledata,
                        text: 'Continue with Google',
                      ),
                      const SizedBox(height: 16),
                      _SocialButton(
                        icon: Icons.apple,
                        text: 'Continue with Apple',
                      ),

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
                        child: Center(
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SignupFlowWrapper(),
                                      ),
                                    ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final bool isVisible;
  final VoidCallback? onVisibilityToggle;
  final TextInputType keyboardType;

  const _LoginTextField({
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.isVisible = false,
    this.onVisibilityToggle,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
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
