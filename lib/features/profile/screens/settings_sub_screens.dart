import 'package:flutter/material.dart';
import '../../../core/utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/api_service.dart';
import 'blocked_users_screen.dart';
import '../../auth/screens/forgot_password_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../l10n/app_localizations.dart';

// =============================================================================
// 1. MODERN SECURITY SCREEN
// =============================================================================
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final ApiService _apiService = ApiService();

  // Controllers
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // Visibility State
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Biometrics State (Mock)
  bool _biometricsEnabled = false;
  bool isLoading = false;

  Future<void> _updatePassword() async {
    final l10n = AppLocalizations.of(context);
    if (_currentPassController.text.isEmpty) {
      _showSnackBar(l10n.securityEnterCurrent, isError: true);
      return;
    }
    if (_newPassController.text.length < 6) {
      _showSnackBar(l10n.securityPasswordTooShort, isError: true);
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      _showSnackBar(l10n.securityPasswordMismatch, isError: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      await _apiService.changePassword(
        _currentPassController.text,
        _newPassController.text,
      );

      if (mounted) {
        _showSnackBar(l10n.securityPasswordUpdated, isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(appErrorMessage(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.securityDeleteAccount,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          l10n.securityDeleteWarning,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.securityCancel, style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.securityDelete,
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteAccount();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          appErrorMessage(context, e),
          isError: true,
        );
      }
    }
  }

  // Helper for consistent SnackBar styling
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          l10n.settingsSecurity,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(l10n.securityLoginDetails),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildPasswordField(
                    l10n.securityCurrentPassword,
                    _currentPassController,
                    _obscureCurrent,
                    () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    l10n.securityNewPassword,
                    _newPassController,
                    _obscureNew,
                    () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    l10n.securityConfirmPassword,
                    _confirmPassController,
                    _obscureConfirm,
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              l10n.securityChangePassword,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: Text(
                        l10n.securityForgotPassword,
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            _buildSectionTitle(l10n.securityAdvanced),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      l10n.securityBiometric,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      l10n.securityBiometricSubtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    value: _biometricsEnabled,
                    secondary: const Icon(Icons.fingerprint),
                    onChanged: (v) => setState(() => _biometricsEnabled = v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phonelink_lock),
                    title: Text(
                      l10n.securityTwoFactor,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.security2FAComingSoon)),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: Text(
                      l10n.blockedUsersTitle,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      l10n.blockedUsersSubtitle,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmDeleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.securityDeleteAccount,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback toggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}

// =============================================================================
// 2. MODERN NOTIFICATIONS SCREEN
// =============================================================================
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool push = true;
  bool email = true;
  bool promo = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          l10n.settingsNotifications,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSwitch(
                l10n.notifPush,
                l10n.notifPushSubtitle,
                push,
                (v) => setState(() => push = v),
              ),
              const Divider(height: 1),
              _buildSwitch(
                l10n.notifEmail,
                l10n.notifEmailSubtitle,
                email,
                (v) => setState(() => email = v),
              ),
              const Divider(height: 1),
              _buildSwitch(
                l10n.notifPromo,
                l10n.notifPromoSubtitle,
                promo,
                (v) => setState(() => promo = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool val,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
      value: val,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}

// =============================================================================
// 3. MODERN LANGUAGE SCREEN
// =============================================================================
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final current = localeProvider.locale.languageCode;

    final options = [
      _LangOption(locale: const Locale('en'), label: l10n.langEnglish, nativeLabel: 'English'),
      _LangOption(locale: const Locale('ka'), label: l10n.langGeorgian, nativeLabel: 'ქართული'),
      _LangOption(locale: const Locale('ru'), label: l10n.langRussian, nativeLabel: 'Русский'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          l10n.settingsLanguage,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final opt = options[index];
          final isSelected = current == opt.locale.languageCode;
          return GestureDetector(
            onTap: () => context.read<LocaleProvider>().setLocale(opt.locale),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.nativeLabel,
                        style: GoogleFonts.poppins(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      if (opt.nativeLabel != opt.label)
                        Text(
                          opt.label,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LangOption {
  _LangOption({
    required this.locale,
    required this.label,
    required this.nativeLabel,
  });
  final Locale locale;
  final String label;
  final String nativeLabel;
}

// =============================================================================
// 4. HELP CENTER (Modern Placeholder)
// =============================================================================
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final ApiService _apiService = ApiService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<dynamic> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final data = await _apiService.getMyTickets();
      if (mounted) {
        setState(() {
          _tickets = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          appErrorMessage(context, e),
          isError: true,
        );
      }
    }
  }

  Future<void> _submitTicket() async {
    final l10n = AppLocalizations.of(context);
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      _showSnackBar(l10n.helpFillBoth, isError: true);
      return;
    }
    try {
      await _apiService.createTicket(
        _subjectController.text.trim(),
        _messageController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        _subjectController.clear();
        _messageController.clear();
        _fetchTickets();
        _showSnackBar(l10n.helpTicketSubmitted, isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          appErrorMessage(context, e),
          isError: true,
        );
      }
    }
  }

  void _openCreateTicketSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.helpContactSupport,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: l10n.helpSubject,
                  labelStyle: GoogleFonts.poppins(fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.helpMessage,
                  labelStyle: GoogleFonts.poppins(fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.helpSubmitTicket,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    return "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          l10n.settingsHelp,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTicketSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.support_agent, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  l10n.helpMyTickets,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                if (_tickets.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.support_agent,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.helpNoTickets,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._tickets.map(
                    (ticket) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket['subject'] ?? l10n.helpSupportTicketDefault,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (ticket['status'] == 'closed')
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (ticket['status'] ?? 'open')
                                      .toString()
                                      .toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: (ticket['status'] == 'closed')
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ticket['message'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (ticket['admin_reply'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ticket['admin_reply'],
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(ticket['created_at']),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildFaqItem(
                  l10n.helpFaqCancelQuestion,
                  l10n.helpFaqCancelAnswer,
                ),
                const SizedBox(height: 10),
                _buildFaqItem(
                  l10n.helpFaqRefundQuestion,
                  l10n.helpFaqRefundAnswer,
                ),
              ],
            ),
    );
  }

  Widget _buildFaqItem(String q, String a) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          q,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              a,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
