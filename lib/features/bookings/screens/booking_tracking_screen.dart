import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../reviews/screens/leave_review_screen.dart';
// TODO: Import your LeaveReviewScreen here
// import 'path/to/leave_review_screen.dart';

class BookingTrackingScreen extends StatefulWidget {
  final dynamic booking;
  final bool isClient; // True if I am the customer, False if I am the provider

  const BookingTrackingScreen({
    super.key,
    required this.booking,
    required this.isClient,
  });

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  final ApiService _apiService = ApiService();
  late dynamic _currentBooking;
  bool _isLoading = false;
  bool _isDisputeSubmitting = false;
  bool _hasRated = false;
  final TextEditingController _disputeReasonController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  @override
  void dispose() {
    _disputeReasonController.dispose();
    super.dispose();
  }

  void _openDisputeSheet() {
    _disputeReasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    "Report Issue",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _disputeReasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Describe the issue",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isDisputeSubmitting
                          ? null
                          : () async {
                              final reason = _disputeReasonController.text
                                  .trim();
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Please enter a reason."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => _isDisputeSubmitting = true);
                              try {
                                await _apiService.openBookingDispute(
                                  _currentBooking['id'],
                                  reason,
                                );
                                if (mounted) {
                                  setSheetState(
                                    () => _isDisputeSubmitting = false,
                                  );
                                  setState(() {
                                    _currentBooking['status'] = 'disputed';
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Dispute submitted."),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(
                                  () => _isDisputeSubmitting = false,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isDisputeSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Submit Dispute",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // CALL THE NEW BACKEND ENDPOINT
  Future<void> _markAsComplete() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.completeBooking(_currentBooking['id']);

      // Refresh logic (In a real app, re-fetch booking details here)
      // For now, let's manually update UI based on logic
      setState(() {
        if (widget.isClient) {
          _currentBooking['client_confirmed'] = true;
        } else {
          _currentBooking['provider_confirmed'] = true;
        }

        // If both are true locally, set status to completed
        if (_currentBooking['client_confirmed'] == true &&
            _currentBooking['provider_confirmed'] == true) {
          _currentBooking['status'] = 'completed';
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Confirmation Sent!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentBooking['status'];
    final isSwap = (_currentBooking['total_price'] == 0);
    final bool isOverdue = _isOverdueBooking(_currentBooking);
    final otherName = widget.isClient
        ? (_currentBooking['profiles']?['full_name'] ?? "Provider")
        : (_currentBooking['profiles']?['full_name'] ?? "Client");

    final bool iHaveConfirmed = widget.isClient
        ? (_currentBooking['client_confirmed'] ?? false)
        : (_currentBooking['provider_confirmed'] ?? false);

    final bool otherHasConfirmed = widget.isClient
        ? (_currentBooking['provider_confirmed'] ?? false)
        : (_currentBooking['client_confirmed'] ?? false);

    // Report/dispute is always available while the booking is still active
    final bool canReportIssue =
        status == 'confirmed' || status == 'pending' || status == 'accepted';

    // True when the provider has confirmed but the client hasn't yet acted —
    // the 48-hour auto-release clock is now running.
    final bool providerConfirmed =
        _currentBooking['provider_confirmed'] == true;
    final bool clientConfirmed = _currentBooking['client_confirmed'] == true;
    final bool showEscrowWarning =
        widget.isClient &&
        providerConfirmed &&
        !clientConfirmed &&
        (status == 'confirmed' || status == 'pending');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Booking Details",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── 48-hour auto-release warning (provider confirmed, client hasn't) ──
            if (showEscrowWarning) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3E0), Color(0xFFFFEBEE)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade400),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      color: Colors.orange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "⚠️ Action Required",
                            style: GoogleFonts.poppins(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "The provider marked this job as done. If you do not confirm or report an issue, funds will be automatically released in 48 hours.",
                            style: GoogleFonts.poppins(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (isOverdue) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This service is past its deadline. Please confirm if the work was completed or report a dispute to hold the funds.",
                        style: GoogleFonts.poppins(
                          color: Colors.red[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // 1. STATUS HEADER
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? Colors.green[50]
                    : isOverdue
                    ? Colors.red[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status == 'completed'
                      ? Colors.green
                      : isOverdue
                      ? Colors.red
                      : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.pending,
                    size: 40,
                    color: status == 'completed'
                        ? Colors.green
                        : isOverdue
                        ? Colors.red
                        : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status == 'completed'
                        ? "Service Completed"
                        : isOverdue
                        ? "Service Overdue"
                        : "In Progress",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    status == 'completed'
                        ? "Funds have been released."
                        : isOverdue
                        ? "Resolution needed before releasing funds."
                        : "Waiting for confirmation.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            ),

            if (status == 'disputed') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Under Admin Review",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // 2. TRACKING STEPS
            _buildStep(
              title: "Booking Confirmed",
              subtitle: "Request accepted by provider",
              isActive: true,
              isDone: true,
            ),
            _buildLine(true),
            _buildStep(
              title: "Service Delivery",
              subtitle:
                  "Date: ${DateFormat('MMM dd, hh:mm a').format(DateTime.parse(_currentBooking['scheduled_time']))}",
              isActive: true,
              isDone: true,
            ),
            _buildLine(true),
            _buildStep(
              title: "Client Confirmation",
              subtitle: widget.isClient
                  ? (iHaveConfirmed
                        ? "You confirmed receipt"
                        : "Tap button below to confirm")
                  : (otherHasConfirmed
                        ? "Client confirmed receipt"
                        : "Waiting for client"),
              isActive: true,
              isDone: widget.isClient ? iHaveConfirmed : otherHasConfirmed,
            ),
            _buildLine(widget.isClient ? iHaveConfirmed : otherHasConfirmed),
            _buildStep(
              title: "Provider Confirmation",
              subtitle: !widget.isClient
                  ? (iHaveConfirmed
                        ? "You confirmed work done"
                        : "Tap button below to confirm")
                  : (otherHasConfirmed
                        ? "Provider confirmed work done"
                        : "Waiting for provider"),
              isActive: true,
              isDone: !widget.isClient ? iHaveConfirmed : otherHasConfirmed,
            ),

            const SizedBox(height: 40),

            // 3. ACTION BUTTON (Only show if not completed yet)
            if (status != 'completed') ...[
              if (iHaveConfirmed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: Colors.green),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "You have confirmed. Waiting for $otherName...",
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _markAsComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.isClient
                                ? "Mark Service Received"
                                : "Mark Job Done",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

              const SizedBox(height: 10),
              if (isSwap)
                Text(
                  "ℹ️ This is a Skill Swap. Confirming marks it as successful.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                )
              else
                Text(
                  "ℹ️ Funds will be held until both parties confirm.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),

              // ── Dispute shortcut (visible when escrow clock is ticking) ──
              if (showEscrowWarning && !iHaveConfirmed) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _openDisputeSheet,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Report an Issue (Dispute)",
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // 4. RATE button — visible once you've confirmed your side (or fully completed), hidden after rating
            if (!_hasRated && (iHaveConfirmed || status == 'completed')) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () async {
                    final revieweeId = widget.isClient
                        ? _currentBooking['provider_id']?.toString() ?? ''
                        : _currentBooking['client_id']?.toString() ?? '';
                    final reviewerRole = widget.isClient
                        ? 'client'
                        : 'provider';
                    final rated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveReviewScreen(
                          bookingId: _currentBooking['id'],
                          serviceId: _currentBooking['service_id'] ?? '',
                          revieweeId: revieweeId,
                          reviewerRole: reviewerRole,
                          revieweeName: otherName,
                        ),
                      ),
                    );
                    if (rated == true && mounted) {
                      setState(() => _hasRated = true);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.isClient ? "Rate Provider" : "Rate Client",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],

            if (canReportIssue) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _openDisputeSheet,
                  icon: Icon(
                    isOverdue
                        ? Icons.report_problem_rounded
                        : Icons.flag_outlined,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: Text(
                    "Report an Issue",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green
                    : (isActive ? AppColors.primary : Colors.grey[300]),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.black : Colors.grey,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLine(bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 11),
      height: 30,
      width: 2,
      color: isActive ? Colors.green : Colors.grey[300],
    );
  }

  bool _isOverdueBooking(dynamic booking) {
    if (booking['is_overdue'] == true) return true;
    final status = (booking['status'] ?? '').toString().toLowerCase();
    if (status != 'confirmed') return false;
    final rawTime = booking['scheduled_time'];
    if (rawTime == null) return false;
    final scheduledTime = DateTime.tryParse(rawTime.toString());
    if (scheduledTime == null) return false;
    return scheduledTime.isBefore(DateTime.now());
  }
}
