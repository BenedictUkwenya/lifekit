import 'package:flutter/material.dart';
import '../../../core/utils/error_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../wallet/screens/add_money_screen.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  final String? currentTier;

  const SubscriptionPlansScreen({super.key, this.currentTier});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final ApiService _apiService = ApiService();
  String? _selectedTier;
  final Set<String> _loadingTiers = {};

  // Plans are now built inside `build()` so they can pull localized strings.
  List<Map<String, dynamic>> _buildPlans(AppLocalizations l10n) => [
    {
      "name": l10n.planNameFree,
      "tier": "free",
      "price": l10n.subscriptionPerMonth("\$0"),
      "highlight": false,
      "features": [
        l10n.planFreeFeature1,
        l10n.planFreeFeature2,
        l10n.planFreeFeature3,
      ],
    },
    {
      "name": l10n.planNamePlus,
      "tier": "plus",
      "price": l10n.subscriptionPerMonth("\$6.99"),
      "highlight": false,
      "features": [
        l10n.planPlusFeature1,
        l10n.planPlusFeature2,
        l10n.planPlusFeature3,
      ],
    },
    {
      "name": l10n.planNamePro,
      "tier": "pro",
      "price": l10n.subscriptionPerMonth("\$17.99"),
      "highlight": true,
      "features": [
        l10n.planProFeature1,
        l10n.planProFeature2,
        l10n.planProFeature3,
      ],
    },
    {
      "name": l10n.planNameBusiness,
      "tier": "business",
      "price": l10n.subscriptionPerMonth("\$44.99"),
      "highlight": false,
      "features": [
        l10n.planBusinessFeature1,
        l10n.planBusinessFeature2,
        l10n.planBusinessFeature3,
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    final currentTier = widget.currentTier?.toLowerCase();
    if (currentTier != null && currentTier.isNotEmpty) {
      _selectedTier = currentTier;
    }
    _syncCurrentTier();
  }

  Future<void> _syncCurrentTier() async {
    try {
      final tier = await _apiService.getCurrentSubscriptionTier();
      if (!mounted) return;
      setState(() => _selectedTier = tier);
    } catch (_) {}
  }

  Future<void> _buyPlan(String tier) async {
    setState(() => _loadingTiers.add(tier));
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _apiService.buySubscription(tier);
      if (!mounted) return;
      setState(() => _selectedTier = tier);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.subscriptionActiveUntil(
              (result['subscription_expiry'] ?? '').toString(),
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 402) {
        await _showInsufficientFundsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorMessage(context, e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTiers.remove(tier));
      }
    }
  }

  Future<void> _showInsufficientFundsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.subscriptionInsufficientFundsTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.subscriptionInsufficientFundsBody,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.subscriptionCancel,
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMoneyScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              l10n.subscriptionAddMoney,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plans = _buildPlans(l10n);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          l10n.subscriptionPlansTitle,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subscriptionGoPremium,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.subscriptionGoPremiumSubtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...plans.map((plan) => _buildPlanCard(plan, l10n)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, AppLocalizations l10n) {
    final String name = plan["name"];
    final String tier = plan["tier"];
    final bool isHighlighted = plan["highlight"] == true;
    final bool isFree = tier == "free";
    final bool isLoading = _loadingTiers.contains(tier);
    final bool isCurrent = _selectedTier == tier;
    final List<String> features = (plan["features"] as List).cast<String>();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : Colors.grey.shade200,
          width: isHighlighted ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.subscriptionPopular,
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan["price"],
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isFree || isLoading || isCurrent
                  ? null
                  : () => _buyPlan(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isCurrent
                          ? l10n.subscriptionCurrentPlan
                          : (isFree
                                ? l10n.subscriptionFreePlan
                                : l10n.subscriptionUpgrade),
                      style: GoogleFonts.poppins(
                        color: isFree || isCurrent
                            ? Colors.grey.shade700
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
