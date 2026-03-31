import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
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

  final List<Map<String, dynamic>> _plans = [
    {
      "name": "Free",
      "tier": "free",
      "price": "\$0/mo",
      "highlight": false,
      "features": ["0 services", "Max 1 community", "Basic visibility"],
    },
    {
      "name": "Plus",
      "tier": "plus",
      "price": "\$6.99/mo",
      "highlight": false,
      "features": [
        "1 service",
        "Max 3 communities",
        "Priority listing boost ready",
      ],
    },
    {
      "name": "Pro",
      "tier": "pro",
      "price": "\$17.99/mo",
      "highlight": true,
      "features": [
        "5 services",
        "Max 5 communities",
        "Best for growing providers",
      ],
    },
    {
      "name": "Business",
      "tier": "business",
      "price": "\$44.99/mo",
      "highlight": false,
      "features": [
        "Unlimited services",
        "Unlimited communities",
        "Top-tier monetization access",
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
    try {
      final result = await _apiService.buySubscription(tier);
      if (!mounted) return;
      setState(() => _selectedTier = tier);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Subscription active until ${result['subscription_expiry'] ?? ''}",
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
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTiers.remove(tier));
      }
    }
  }

  Future<void> _showInsufficientFundsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Insufficient Funds",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Your wallet balance is too low for this purchase. Add money to continue.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
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
              "Add Money",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Subscription Plans",
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
                  "Go Premium",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Unlock more services, more communities, and faster growth.",
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
          ..._plans.map((plan) => _buildPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
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
                    "Popular",
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
                          ? "Current Plan"
                          : (isFree ? "Free Plan" : "Upgrade"),
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
