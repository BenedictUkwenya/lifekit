import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lifekit_frontend/features/provider/screens/my_services_list_screen.dart';
import 'package:lifekit_frontend/features/provider/screens/provider_dashboard_screen.dart';
import 'package:lifekit_frontend/features/provider/screens/subscription_plans_screen.dart';

// --- CORE ---
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart';

// --- SCREENS ---
import '../../auth/screens/login_screen.dart';
import '../../bookings/screens/bookings_screen.dart';
import 'edit_profile_screen.dart';
import 'wallet_screen.dart';
import 'share_profile_screen.dart';
import 'settings_sub_screens.dart';
import '../../onboarding/screens/ai_onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool _isBalanceVisible = false;
  bool _isWalletLoading = true;
  bool _isUsageLoading = true;
  double? _walletBalance;
  int _activeServicesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile({bool showPageLoader = true}) async {
    if (mounted && showPageLoader) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final data = await _apiService.getUserProfile();
      final backendProfileRaw = data['profile'];
      final backendProfile = backendProfileRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(backendProfileRaw)
          : Map<String, dynamic>.from(data);
      backendProfile['subscription_tier'] =
          (backendProfile['subscription_tier'] ?? 'free').toString();
      backendProfile['subscription_expiry'] =
          backendProfile['subscription_expiry']?.toString();
      if (mounted) {
        setState(() {
          profile = backendProfile;
          isLoading = false;
          _isWalletLoading = true;
          _isUsageLoading = true;
        });
      }
      _fetchMonetizationData();
    } catch (e) {
      if (mounted && showPageLoader) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMonetizationData() async {
    try {
      final walletData = await _apiService.getWallet();
      final rawBalance = walletData['balance'];
      final parsedBalance = rawBalance is num
          ? rawBalance.toDouble()
          : double.tryParse(rawBalance?.toString() ?? '');
      if (mounted) {
        setState(() {
          _walletBalance = parsedBalance;
          _isWalletLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletBalance = null;
          _isWalletLoading = false;
        });
      }
    }

    try {
      final services = await _apiService.getMyServices();
      final activeCount = services
          .where((service) => service['status'] == 'active')
          .length;
      if (mounted) {
        setState(() {
          _activeServicesCount = activeCount;
          _isUsageLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeServicesCount = 0;
          _isUsageLoading = false;
        });
      }
    }
  }

  void _logout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
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
    if (isLoading) return const Scaffold(body: Center(child: LifeKitLoader()));

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

    final String name = profile!['full_name'] ?? 'User';
    final String bio = profile!['bio'] ?? 'No bio added';
    final String? pic = profile!['profile_picture_url'];
    final String tierKey = (profile!['subscription_tier'] ?? 'free')
        .toString()
        .toLowerCase();
    final String tierLabel =
        "${tierKey.isNotEmpty ? tierKey[0].toUpperCase() : 'F'}${tierKey.length > 1 ? tierKey.substring(1) : ''}";
    final bool isBusinessTier = tierKey == 'business';
    final DateTime? subscriptionExpiry = DateTime.tryParse(
      (profile!['subscription_expiry'] ?? '').toString(),
    )?.toLocal();
    final bool showRenewalCountdown =
        tierKey != 'free' && subscriptionExpiry != null;
    final int renewalDays = showRenewalCountdown
        ? (() {
            final diff = subscriptionExpiry.difference(DateTime.now());
            if (diff.isNegative) return 0;
            return ((diff.inHours + 23) ~/ 24);
          })()
        : 0;
    final int? tierServiceLimit = switch (tierKey) {
      'plus' => 1,
      'pro' => 5,
      'business' => null,
      _ => 0,
    };
    final String usageText = _isUsageLoading
        ? "Loading usage..."
        : tierServiceLimit == null
        ? "Slots Used: $_activeServicesCount/∞ (Includes Drafts & Pending)"
        : "Slots Used: $_activeServicesCount/$tierServiceLimit (Includes Drafts & Pending)";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _fetchProfile(showPageLoader: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "Profile",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Wallet Balance",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _isWalletLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isBalanceVisible = !_isBalanceVisible;
                                    });
                                  },
                            icon: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _isWalletLoading
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Loading wallet...",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _isBalanceVisible
                                  ? "\$${(_walletBalance ?? 0).toStringAsFixed(2)}"
                                  : "****",
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Account Usage",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    usageText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (showRenewalCountdown) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "Renews in $renewalDays days",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: renewalDays <= 3
                                            ? Colors.orange.shade700
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubscriptionPlansScreen(
                                      currentTier: tierKey,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                _fetchProfile();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF89273B),
                                      Color(0xFFA83B52),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(
                                        0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  "Upgrade Plan",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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

                const SizedBox(height: 16),

                // 1. PROFILE CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.1),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey[100],
                          backgroundImage: pic != null
                              ? CachedNetworkImageProvider(pic)
                              : null,
                          child: pic == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 30,
                                )
                              : null,
                        ),
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
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBusinessTier
                                        ? const Color(
                                            0xFF10B981,
                                          ).withOpacity(0.14)
                                        : AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    tierLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isBusinessTier
                                          ? const Color(0xFF059669)
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (isBusinessTier) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: Color(0xFF059669),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bio,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.ios_share, size: 22),
                        color: AppColors.primary,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShareProfileScreen(profile: profile!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // 2. BUSINESS TOOLS (Redesigned with Grid)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF89273B), Color(0xFFA03348)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF89273B).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Business Tools",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // FLEXIBLE GRID LAYOUT
                      Wrap(
                        spacing: 20, // Horizontal space
                        runSpacing: 20, // Vertical space
                        alignment: WrapAlignment.start,
                        children: [
                          _buildToolItem(
                            Icons.dashboard_outlined,
                            "Dashboard",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProviderDashboardScreen(),
                              ),
                            ),
                          ),
                          _buildToolItem(
                            Icons.add_circle_outline,
                            "Services",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyServicesListScreen(),
                              ),
                            ),
                          ),
                          _buildToolItem(
                            Icons.account_balance_wallet_outlined,
                            "Wallet",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            ),
                          ),
                          _buildToolItem(
                            Icons.edit_outlined,
                            "Edit Profile",
                            () async {
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
                          _buildToolItem(
                            Icons.auto_awesome_rounded,
                            "AI Premium",
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("AI Premium Tools coming soon!"),
                              ),
                            ),
                          ),
                          _buildToolItem(
                            Icons.card_giftcard,
                            "Rewards",
                            () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Rewards coming soon!"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 3. SETTINGS SECTION
                _buildSectionHeader("General Settings"),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        Icons.calendar_month_rounded,
                        "My Bookings",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookingsScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.auto_awesome,
                        "AI Setup Guide",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIOnboardingScreen(),
                          ),
                        ),
                        iconColor: AppColors.primary,
                        subtitle: "Generate your 7-Day Success Plan",
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.person_outline,
                        "Personal Information",
                        () async {
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
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.lock_outline,
                        "Password & Security",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SecurityScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.notifications_none_rounded,
                        "Notifications",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.language,
                        "Language",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LanguageScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                _buildSectionHeader("Support"),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingTile(
                        Icons.help_outline_rounded,
                        "Help Center",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen(),
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildSettingTile(
                        Icons.logout_rounded,
                        "Log Out",
                        _logout,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
    Color? iconColor,
    String? subtitle,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : iconColor != null
              ? iconColor.withOpacity(0.1)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : iconColor ?? Colors.grey[700],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey[400],
        size: 22,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[100],
      indent: 20,
      endIndent: 20,
    );
  }
}
