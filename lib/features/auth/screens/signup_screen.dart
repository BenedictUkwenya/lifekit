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

// ─────────────────────────────────────────────────────────────
//  ERROR MESSAGE SANITIZER
//  Converts raw backend/exception strings into friendly copy
// ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
//  BEAUTIFUL TOAST HELPER
//  Call anywhere: AppToast.show(context, ...)
// ─────────────────────────────────────────────────────────────
enum _ToastType { success, error, info }

class AppToast {
  static void success(BuildContext context, String message) =>
      _show(context, message, _ToastType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _ToastType.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _ToastType.info);

  static void _show(BuildContext context, String message, _ToastType type) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final _ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnim = Tween<double>(
      begin: -20,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Auto-dismiss after 3.5 s
    Future.delayed(const Duration(milliseconds: 3500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _toastConfig(widget.type);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        ),
        child: GestureDetector(
          onTap: _dismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cfg.bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cfg.borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: cfg.shadowColor.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cfg.iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cfg.icon, color: cfg.iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: cfg.textColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: cfg.textColor.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastConfig {
  final Color bgColor, borderColor, shadowColor, iconBg, iconColor, textColor;
  final IconData icon;

  const _ToastConfig({
    required this.bgColor,
    required this.borderColor,
    required this.shadowColor,
    required this.iconBg,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

_ToastConfig _toastConfig(_ToastType type) {
  switch (type) {
    case _ToastType.success:
      return const _ToastConfig(
        bgColor: Color(0xFFEDFDF5),
        borderColor: Color(0xFFABEFC4),
        shadowColor: Color(0xFF12B76A),
        iconBg: Color(0xFFD1FADF),
        iconColor: Color(0xFF039855),
        textColor: Color(0xFF054F31),
        icon: Icons.check_circle_outline_rounded,
      );
    case _ToastType.error:
      return const _ToastConfig(
        bgColor: Color(0xFFFFF1F0),
        borderColor: Color(0xFFFFCCC7),
        shadowColor: Color(0xFFFF4D4F),
        iconBg: Color(0xFFFFE2E0),
        iconColor: Color(0xFFD92D20),
        textColor: Color(0xFF7A1B17),
        icon: Icons.error_outline_rounded,
      );
    case _ToastType.info:
      return const _ToastConfig(
        bgColor: Color(0xFFF0F5FF),
        borderColor: Color(0xFFADC6FF),
        shadowColor: Color(0xFF1D4ED8),
        iconBg: Color(0xFFDBEAFE),
        iconColor: Color(0xFF1D4ED8),
        textColor: Color(0xFF1E3A5F),
        icon: Icons.info_outline_rounded,
      );
  }
}

// ─────────────────────────────────────────────────────────────
//  SIGNUP FLOW
// ─────────────────────────────────────────────────────────────

class SignupFlowWrapper extends StatefulWidget {
  const SignupFlowWrapper({super.key});

  @override
  State<SignupFlowWrapper> createState() => _SignupFlowWrapperState();
}

class _SignupFlowWrapperState extends State<SignupFlowWrapper> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();

  String fullName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  File? _imageFile;
  bool isLoading = false;

  void nextPage() => _pageController.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  void previousPage() => _pageController.previousPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  // ── Use AppToast everywhere — no raw SnackBar ──
  void showError(dynamic e) => AppToast.error(context, _friendlyError(e));

  void showSuccess(String msg) => AppToast.success(context, msg);

  void showInfo(String msg) => AppToast.info(context, msg);

  Future<void> submitDetailsAndPass() async {
    setState(() => isLoading = true);
    try {
      await _apiService.signup(fullName, email, password);
      if (mounted) {
        setState(() => isLoading = false);
        nextPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError(e);
      }
    }
  }

  Future<void> resendOtp() async {
    setState(() => isLoading = true);
    try {
      await _apiService.signup(fullName, email, password);
      if (mounted) {
        setState(() => isLoading = false);
        showSuccess('New code sent! Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError('Could not resend code. Please try again.');
      }
    }
  }

  Future<void> verifyOtp(String code) async {
    setState(() => isLoading = true);
    try {
      await _apiService.verifyOtp(email, code);
      if (mounted) {
        setState(() => isLoading = false);
        nextPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError(e);
      }
    }
  }

  Future<void> uploadAndFinish() async {
    setState(() => isLoading = true);
    try {
      if (_imageFile != null) {
        await _apiService.uploadProfilePic(_imageFile!);
      }
      showSuccess("You're all set! Welcome to LifeKit 🎉");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Profile pic upload failing shouldn't block access
      showInfo('Profile picture skipped — you can add it later.');
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

  // ── SCREEN 1: DETAILS ──────────────────────────────────────
  Widget _buildDetailsScreen() {
    return _BaseAuthLayout(
      title: 'Hi, Welcome to LifeKit',
      subtitle: 'Complete the info below to create your account',
      onBack: () => Navigator.of(context).pop(),
      children: [
        _CustomTextField(
          label: 'Full Name',
          initialValue: fullName,
          onChanged: (v) => fullName = v,
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          label: 'Email Address',
          initialValue: email,
          onChanged: (v) => email = v,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 30),
        _PrimaryButton(
          text: 'Continue',
          onTap: () {
            if (fullName.trim().isEmpty) {
              showError('Please enter your full name.');
              return;
            }
            if (email.trim().isEmpty ||
                !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim())) {
              showError('Please enter a valid email address.');
              return;
            }
            nextPage();
          },
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('or', style: TextStyle(color: Colors.grey[400])),
        ),
        const SizedBox(height: 24),
        _SocialButton(icon: Icons.g_mobiledata, text: 'Continue with Google'),
        const SizedBox(height: 16),
        _SocialButton(icon: Icons.apple, text: 'Continue with Apple'),
        const Spacer(),
        Center(
          child: RichText(
            text: TextSpan(
              text: 'Already have an account? ',
              style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: 'Sign In',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── SCREEN 2: PASSWORD ────────────────────────────────────
  Widget _buildPasswordScreen() {
    return _BaseAuthLayout(
      title: 'Choose a password',
      subtitle: 'Pick something secure — at least 6 characters',
      onBack: previousPage,
      children: [
        _CustomTextField(
          label: 'Enter password',
          initialValue: password,
          isPassword: true,
          onChanged: (v) => password = v,
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          label: 'Confirm your password',
          isPassword: true,
          onChanged: (v) => confirmPassword = v,
        ),
        const SizedBox(height: 30),
        isLoading
            ? const Center(child: LifeKitLoader())
            : _PrimaryButton(
                text: 'Submit',
                onTap: () {
                  if (password.isEmpty) {
                    showError('Please enter a password.');
                    return;
                  }
                  if (password.length < 6) {
                    showError('Password must be at least 6 characters.');
                    return;
                  }
                  if (confirmPassword.isEmpty) {
                    showError('Please confirm your password.');
                    return;
                  }
                  if (password != confirmPassword) {
                    showError("Passwords don't match. Please try again.");
                    return;
                  }
                  submitDetailsAndPass();
                },
              ),
        const Spacer(),
      ],
    );
  }

  // ── SCREEN 3: OTP ─────────────────────────────────────────
  Widget _buildOtpScreen() {
    return _BaseAuthLayout(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code sent to $email',
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
              isLoading ? 'Sending...' : "Didn't get a code? Resend",
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (isLoading) const Center(child: LifeKitLoader()),
        const Spacer(),
      ],
    );
  }

  // ── SCREEN 4: PROFILE PIC ─────────────────────────────────
  Widget _buildProfileScreen() {
    return _BaseAuthLayout(
      title: 'Almost done!',
      subtitle: 'Add a profile picture — you can always skip this',
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
                    final XFile? image = await ImagePicker().pickImage(
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
            ? const Center(child: LifeKitLoader())
            : _PrimaryButton(text: 'Finish', onTap: uploadAndFinish),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS (unchanged API, same as before)
// ─────────────────────────────────────────────────────────────

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
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
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
        obscureText: _obscure,
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
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
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
