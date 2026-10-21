import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../home/screens/home_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import '../../../l10n/app_localizations.dart';

// ── Header slider data ─────────────────────────────────────
class _LoginSlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _LoginSlideData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

List<_LoginSlideData> _buildLoginSlides(AppLocalizations l10n) => [
  _LoginSlideData(
    icon: Icons.waving_hand_rounded,
    title: l10n.loginSlideWelcomeBackTitle,
    subtitle: l10n.loginSlideWelcomeBackSubtitle,
  ),
  _LoginSlideData(
    icon: Icons.trending_up_rounded,
    title: l10n.loginSlideProgressTitle,
    subtitle: l10n.loginSlideProgressSubtitle,
  ),
  _LoginSlideData(
    icon: Icons.auto_awesome_rounded,
    title: l10n.loginSlideAITitle,
    subtitle: l10n.loginSlideAISubtitle,
  ),
  _LoginSlideData(
    icon: Icons.people_outline_rounded,
    title: l10n.loginSlideCommunityTitle,
    subtitle: l10n.loginSlideCommunitySubtitle,
  ),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool isLoading = false;
  bool isPasswordVisible = false;
  StreamSubscription<AuthState>? _oauthSub;

  late final PageController _sliderCtrl;
  int _sliderIndex = 0;
  Timer? _sliderTimer;

  late final AnimationController _entryCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0.0, 0.07), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
          ),
        );
    _sliderCtrl = PageController();
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_sliderIndex + 1) % 4;
      _sliderCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _sliderCtrl.dispose();
    _entryCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
          AppToast.success(context, AppLocalizations.of(context)!.welcomeBackToast);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
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
        AppToast.error(context, 'Sign-in failed. Please try again.');
      }
    }
  }

  Future<void> handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // ── Client-side validation first ───────────────────────
    if (email.isEmpty) {
      AppToast.error(context, l10n.errorEmailRequired);
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      AppToast.error(context, l10n.errorEmailInvalid);
      return;
    }
    if (password.isEmpty) {
      AppToast.error(context, l10n.errorPasswordRequired);
      return;
    }

    setState(() => isLoading = true);

    try {
      await _apiService.login(email, password);
      if (mounted) {
        AppToast.success(context, l10n.welcomeBackToast);
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final headerH = (mq.size.height * 0.40).clamp(240.0, 320.0);
    final l10n = AppLocalizations.of(context)!;
    final slides = _buildLoginSlides(l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
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
                        bottomLeft: Radius.circular(48),
                        bottomRight: Radius.circular(48),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: -48,
                    right: -40,
                    child: _DecoCircle(size: 180, opacity: 0.08),
                  ),
                  const Positioned(
                    bottom: -20,
                    left: -60,
                    child: _DecoCircle(size: 220, opacity: 0.06),
                  ),
                  const Positioned(
                    top: 70,
                    left: 30,
                    child: _DecoCircle(size: 60, opacity: 0.10),
                  ),
                  Positioned.fill(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          // Logo badge with entry animation
                          AnimatedBuilder(
                            animation: _entryCtrl,
                            builder: (_, child) => FadeTransition(
                              opacity: _logoFade,
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: child!,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo_black.png',
                                height: 36,
                              ),
                            ),
                          ),
                          // Auto-scroll slides
                          Expanded(
                            child: PageView.builder(
                              controller: _sliderCtrl,
                              itemCount: slides.length,
                              onPageChanged: (i) =>
                                  setState(() => _sliderIndex = i),
                              itemBuilder: (_, i) {
                                final s = slides[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        s.icon,
                                        color: Colors.white.withOpacity(0.90),
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            s.title,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 19,
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
                                            fontSize: 12,
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
                          // Dot indicators
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                slides.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────
            FadeTransition(
              opacity: _formFade,
              child: SlideTransition(
                position: _formSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LoginTextField(
                        controller: _emailController,
                        hintText: l10n.emailPlaceholder,
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _LoginTextField(
                        controller: _passwordController,
                        hintText: l10n.passwordPlaceholder,
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isVisible: isPasswordVisible,
                        onVisibilityToggle: () => setState(
                          () => isPasswordVisible = !isPasswordVisible,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            l10n.forgotPassword,
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _AnimatedPrimaryButton(
                        text: l10n.loginButton,
                        isLoading: isLoading,
                        onTap: handleLogin,
                      ),
                      // ── social buttons (coming soon) ──────────
                      // _SocialButton(Google), _SocialButton(Apple)
                      const SizedBox(height: 36),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: '${l10n.noAccountPrompt} ',
                            style: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: l10n.registerButton,
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupFlowWrapper(),
                                    ),
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: mq.padding.bottom + 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────────────

class _LoginTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isPassword;
  final bool isVisible;
  final VoidCallback? onVisibilityToggle;
  final TextInputType keyboardType;
  final IconData? prefixIcon;

  const _LoginTextField({
    required this.controller,
    required this.hintText,
    this.isPassword = false,
    this.isVisible = false,
    this.onVisibilityToggle,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
  });

  @override
  State<_LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<_LoginTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
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
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.isPassword && !widget.isVisible,
        keyboardType: widget.keyboardType,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  size: 20,
                  color: _focused ? AppColors.primary : Colors.grey[400],
                )
              : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    widget.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: widget.onVisibilityToggle,
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

class _AnimatedPrimaryButton extends StatefulWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  const _AnimatedPrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<_AnimatedPrimaryButton>
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
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
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

class _DecoCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecoCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
