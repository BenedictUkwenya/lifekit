import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/constants/legal_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import '../../onboarding/screens/ai_onboarding_screen.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../../../l10n/app_localizations.dart';

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
  bool _showNameHint = false;
  StreamSubscription<AuthState>? _oauthSub;

  // Resend-code cooldown so people don't spam the button (backend rate-limits too).
  static const _resendCooldown = 30;
  int _resendIn = 0;
  Timer? _resendTimer;

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _oauthSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSocialSignIn(OAuthProvider provider) async {
    _oauthSub?.cancel();
    _oauthSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _oauthSub?.cancel();
        _oauthSub = null;
        final session = data.session!;
        await _apiService.saveOAuthTokens(
          session.accessToken,
          session.refreshToken ?? '',
        );
        await _apiService.ensureSocialProfile(session.accessToken);
        if (mounted) {
          showSuccess(AppLocalizations.of(context).authWelcomeAboard);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AIOnboardingScreen()),
              (route) => false,
            );
          }
        }
      }
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.lifekit://login-callback',
      );
    } catch (e) {
      _oauthSub?.cancel();
      _oauthSub = null;
      if (mounted) {
        showError(AppLocalizations.of(context).authSocialFailed);
      }
    }
  }

  void nextPage() => _pageController.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  void previousPage() => _pageController.previousPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  // ── Use AppToast everywhere — no raw SnackBar ──
  void showError(dynamic e) {
    HapticFeedback.mediumImpact();
    AppToast.error(context, appErrorMessage(context, e));
  }

  void showSuccess(String msg) => AppToast.success(context, msg);

  void showInfo(String msg) => AppToast.info(context, msg);

  Future<void> submitDetailsAndPass() async {
    setState(() => isLoading = true);
    try {
      await _apiService.signup(
        fullName,
        email,
        password,
        language: Localizations.localeOf(context).languageCode,
      );
      if (mounted) {
        setState(() => isLoading = false);
        _startResendCooldown();
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
    if (_resendIn > 0) return;
    setState(() => isLoading = true);
    try {
      await _apiService.signup(
        fullName,
        email,
        password,
        language: Localizations.localeOf(context).languageCode,
      );
      if (mounted) {
        setState(() => isLoading = false);
        _startResendCooldown();
        showSuccess(AppLocalizations.of(context).authCodeSent);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        showError(AppLocalizations.of(context).authResendFailed);
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
      if (mounted) showSuccess(AppLocalizations.of(context).authWelcomeAboard);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        // Navigate to AI Onboarding so the user immediately sees
        // personalised service suggestions after sign-up.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AIOnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Profile pic upload failing shouldn't block access
      if (mounted) showInfo(AppLocalizations.of(context).authPhotoSkipped);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AIOnboardingScreen()),
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
    final l10n = AppLocalizations.of(context)!;
    return _BaseAuthLayout(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      onBack: () => Navigator.of(context).pop(),
      currentStep: 1,
      totalSteps: 4,
      children: [
        _CustomTextField(
          label: l10n.fullNameLabel,
          initialValue: fullName,
          icon: Icons.person_outline_rounded,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          onChanged: (v) {
            fullName = v;
            setState(() {
              _showNameHint = v.trim().isNotEmpty && !v.trim().contains(' ');
            });
          },
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showNameHint
              ? Padding(
                  key: const ValueKey('name-hint'),
                  padding: const EdgeInsets.only(top: 7, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n.authNameHint,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('name-hint-hidden')),
        ),
        const SizedBox(height: 16),
        _CustomTextField(
          label: l10n.emailLabel,
          initialValue: email,
          onChanged: (v) => email = v,
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline_rounded,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 30),
        _PrimaryButton(
          text: l10n.next,
          onTap: () {
            if (fullName.trim().isEmpty) {
              showError(l10n.errorNameRequired);
              return;
            }
            if (!fullName.trim().contains(' ')) {
              showError(l10n.authNameBoth);
              return;
            }
            if (email.trim().isEmpty ||
                !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim())) {
              showError(l10n.errorEmailInvalid);
              return;
            }
            nextPage();
          },
        ),
        const SizedBox(height: 24),
        // Center(
        //   child: Text('or', style: TextStyle(color: Colors.grey[400])),
        // ),
        // ── social buttons (coming soon) ──
        // _SocialButton(Google), _SocialButton(Apple)
        const SizedBox(height: 28),
        Center(
          child: RichText(
            text: TextSpan(
              text: '${l10n.haveAccountPrompt} ',
              style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: l10n.signIn,
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
    final l10n = AppLocalizations.of(context)!;
    return _BaseAuthLayout(
      title: l10n.signupPasswordTitle,
      subtitle: l10n.signupPasswordSubtitle,
      onBack: previousPage,
      currentStep: 2,
      totalSteps: 4,
      children: [
        _CustomTextField(
          label: l10n.passwordLabel,
          initialValue: password,
          isPassword: true,
          icon: Icons.lock_outline_rounded,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          onChanged: (v) => setState(() => password = v),
        ),
        _PasswordStrength(password: password),
        const SizedBox(height: 16),
        _CustomTextField(
          label: l10n.confirmPasswordLabel,
          isPassword: true,
          icon: Icons.lock_reset_rounded,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: (v) => confirmPassword = v,
        ),
        const SizedBox(height: 30),
        isLoading
            ? const Center(child: LifeKitLoader())
            : _PrimaryButton(
                text: l10n.submit,
                onTap: () {
                  if (password.isEmpty) {
                    showError(l10n.errorPasswordRequired);
                    return;
                  }
                  if (password.length < 6) {
                    showError(l10n.errorPasswordShort);
                    return;
                  }
                  if (confirmPassword.isEmpty) {
                    showError(l10n.errorConfirmPassword);
                    return;
                  }
                  if (password != confirmPassword) {
                    showError(l10n.errorPasswordMatch);
                    return;
                  }
                  submitDetailsAndPass();
                },
              ),
        const SizedBox(height: 16),
        const _TermsNotice(),
      ],
    );
  }

  // ── SCREEN 3: OTP ─────────────────────────────────────────
  Widget _buildOtpScreen() {
    final l10n = AppLocalizations.of(context)!;
    return _BaseAuthLayout(
      title: l10n.authVerifyTitle,
      subtitle: l10n.authVerifySub(email),
      onBack: previousPage,
      currentStep: 3,
      totalSteps: 4,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ).popIn(),
        ),
        const SizedBox(height: 24),
        Center(
          child: Builder(
            builder: (context) {
              final base = PinTheme(
                width: 48,
                height: 56,
                textStyle: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              );
              return Pinput(
                length: 6,
                autofocus: true,
                defaultPinTheme: base,
                focusedPinTheme: base.copyDecorationWith(
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ],
                ),
                submittedPinTheme: base.copyDecorationWith(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                hapticFeedbackType: HapticFeedbackType.lightImpact,
                onCompleted: (pin) => verifyOtp(pin),
              ).fadeSlideIn(index: 1);
            },
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: _resendIn > 0
                ? Text(
                    l10n.authResendIn(_resendIn),
                    key: const ValueKey('countdown'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  )
                : TextButton(
                    key: const ValueKey('resend'),
                    onPressed: isLoading ? null : resendOtp,
                    child: Text(
                      isLoading ? l10n.loading : l10n.authResend,
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.authCheckSpam,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        if (isLoading) const Center(child: LifeKitLoader()),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── SCREEN 4: PROFILE PIC ─────────────────────────────────
  Widget _buildProfileScreen() {
    final l10n = AppLocalizations.of(context)!;
    return _BaseAuthLayout(
      title: l10n.authAlmostTitle,
      subtitle: l10n.authAlmostSub,
      onBack: null,
      currentStep: 4,
      totalSteps: 4,
      children: [
        const SizedBox(height: 28),
        Center(
          child: Pressable(
            onTap: () async {
              final XFile? image = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                imageQuality: 85,
              );
              if (image != null && mounted) {
                setState(() => _imageFile = File(image.path));
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF89273B), Color(0xFFBF3F5E)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 62,
                    backgroundColor: Colors.white,
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      child: _imageFile != null
                          ? CircleAvatar(
                              key: ValueKey(_imageFile!.path),
                              radius: 58,
                              backgroundImage: FileImage(_imageFile!),
                            )
                          : CircleAvatar(
                              key: const ValueKey('empty'),
                              radius: 58,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              child: Text(
                                fullName.trim().isEmpty
                                    ? '?'
                                    : fullName.trim()[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ).popIn(),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _imageFile == null ? l10n.authAddPhoto : l10n.authChangePhoto,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
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
        const SizedBox(height: 16),
        isLoading
            ? const Center(child: LifeKitLoader())
            : _PrimaryButton(text: l10n.done, onTap: uploadAndFinish),
        if (_imageFile == null && !isLoading)
          Center(
            child: TextButton(
              onPressed: uploadAndFinish,
              child: Text(
                l10n.authSkipForNow,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS (unchanged API, same as before)
// ─────────────────────────────────────────────────────────────

class _AuthSlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _AuthSlideData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

List<_AuthSlideData> _buildSignupSlides(AppLocalizations l10n) => [
  _AuthSlideData(
    icon: Icons.auto_awesome_rounded,
    title: l10n.signupWelcomeTitle,
    subtitle: l10n.signupSlideWelcomeSubtitle,
  ),
  _AuthSlideData(
    icon: Icons.trending_up_rounded,
    title: l10n.signupSlideHabitsTitle,
    subtitle: l10n.signupSlideHabitsSubtitle,
  ),
  _AuthSlideData(
    icon: Icons.psychology_rounded,
    title: l10n.signupSlideAITitle,
    subtitle: l10n.signupSlideAISubtitle,
  ),
  _AuthSlideData(
    icon: Icons.people_outline_rounded,
    title: l10n.signupSlideCommunityTitle,
    subtitle: l10n.signupSlideCommunitySubtitle,
  ),
];

class _BaseAuthLayout extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  final int currentStep;
  final int totalSteps;

  const _BaseAuthLayout({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.currentStep = 0,
    this.totalSteps = 0,
  });

  @override
  State<_BaseAuthLayout> createState() => _BaseAuthLayoutState();
}

class _BaseAuthLayoutState extends State<_BaseAuthLayout>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  PageController? _sliderCtrl;
  int _sliderIndex = 0;
  Timer? _sliderTimer;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.25, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    if (widget.currentStep == 1) {
      _sliderCtrl = PageController();
      _sliderTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        final next = (_sliderIndex + 1) % 4;
        _sliderCtrl!.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _sliderCtrl?.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Widget _buildSliderContent(List<_AuthSlideData> slides) {
    return Column(
      children: [
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _entryCtrl,
          builder: (_, child) => FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(scale: _logoScale, child: child!),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset('assets/images/logo_black.png', height: 30),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _sliderCtrl!,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _sliderIndex = i),
            itemBuilder: (_, i) {
              final s = slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        s.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.78),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              slides.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _sliderIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _sliderIndex
                      ? Colors.white
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = _buildSignupSlides(l10n);
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerH = (constraints.maxHeight * 0.36).clamp(220.0, 280.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient header ──────────────────────────────
            SizedBox(
              height: headerH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF89273B), Color(0xFFBF3F5E)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(44),
                        bottomRight: Radius.circular(44),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: -40,
                    right: -30,
                    child: _DecoCircle(size: 160, opacity: 0.08, drift: 14),
                  ),
                  const Positioned(
                    bottom: -20,
                    left: -50,
                    child: _DecoCircle(size: 200, opacity: 0.06, drift: -16),
                  ),
                  Positioned.fill(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // back + progress dots row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                            child: Row(
                              children: [
                                if (widget.onBack != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: widget.onBack,
                                  )
                                else
                                  const SizedBox(width: 48),
                                const Spacer(),
                                if (widget.totalSteps > 0)
                                  _StepProgress(
                                    current: widget.currentStep,
                                    total: widget.totalSteps,
                                  ),
                                const Spacer(),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ),
                          // logo + title / carousel
                          Expanded(
                            child: widget.currentStep == 1
                                ? _buildSliderContent(slides)
                                : Center(
                                    child: AnimatedBuilder(
                                      animation: _entryCtrl,
                                      builder: (_, child) => FadeTransition(
                                        opacity: _logoFade,
                                        child: ScaleTransition(
                                          scale: _logoScale,
                                          child: child,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.15),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Image.asset(
                                              'assets/images/logo_black.png',
                                              height: 30,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            widget.title,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 19,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            child: Text(
                                              widget.subtitle,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.5,
                                                color: Colors.white.withOpacity(
                                                  0.78,
                                                ),
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
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...widget.children,
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  final IconData? icon;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;

  const _CustomTextField({
    this.icon,
    this.autofillHints,
    this.textInputAction,
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
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.primary.withOpacity(0.55)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? AppColors.primary.withOpacity(0.10)
                : Colors.black.withOpacity(0.05),
            blurRadius: _focused ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: widget.initialValue,
        focusNode: _focusNode,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        autocorrect: false,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: widget.label,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          prefixIcon: widget.icon == null
              ? null
              : Icon(
                  widget.icon,
                  size: 20,
                  color: _focused ? AppColors.primary : Colors.grey[400],
                ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
        ),
      ),
    );
  }
}

/// "By creating an account you agree to our Terms and Privacy Policy" —
/// both links open the hosted legal pages in an in-app browser.
class _TermsNotice extends StatelessWidget {
  const _TermsNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = GoogleFonts.poppins(
      fontSize: 12,
      color: Colors.grey[600],
      height: 1.5,
    );
    final link = base.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary.withValues(alpha: 0.4),
    );
    Widget linkText(String label, String url) => GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView),
      child: Text(label, style: link),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Text(l10n.signupAgreePrefix, style: base, textAlign: TextAlign.center),
        linkText(l10n.profileTermsOfService, LegalLinks.termsOfService),
        Text(l10n.signupAgreeAnd, style: base),
        linkText(l10n.profilePrivacyPolicy, LegalLinks.privacyPolicy),
      ],
    ).fadeSlideIn(index: 2);
  }
}

/// "Step 2 of 4" with a bar that fills as you move through signup.
class _StepProgress extends StatelessWidget {
  final int current;
  final int total;

  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context).authStepOf(current, total),
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 120,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: (current - 1) / total, end: current / total),
            duration: Motion.slow,
            curve: Motion.curve,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live 4-segment password strength meter.
class _PasswordStrength extends StatelessWidget {
  final String password;

  const _PasswordStrength({required this.password});

  static int score(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) ||
        (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)))
      s++;
    return s.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = score(password);
    const colors = [
      Color(0xFFDC2626),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
    ];
    final labels = [
      l10n.authPwWeak,
      l10n.authPwFair,
      l10n.authPwGood,
      l10n.authPwStrong,
    ];
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.curve,
      child: password.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Expanded(
                          child: AnimatedContainer(
                            duration: Motion.medium,
                            curve: Motion.curve,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i < s
                                  ? colors[s - 1]
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Text(
                          labels[s - 1],
                          key: ValueKey(s),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors[s - 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (s < 3) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.authPwTip,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF89273B), Color(0xFFBF3F5E)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF89273B).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _SocialButton({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black87, size: 22),
              const SizedBox(width: 12),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecoCircle extends StatelessWidget {
  final double size;
  final double opacity;

  /// Vertical drift in px; bubbles float slowly so the header feels alive.
  final double drift;

  const _DecoCircle({
    required this.size,
    required this.opacity,
    this.drift = 0,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
    if (drift == 0) return circle;
    return circle
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: drift,
          duration: 4.seconds,
          curve: Curves.easeInOut,
        );
  }
}
