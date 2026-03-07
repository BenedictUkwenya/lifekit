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

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
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
    final otherName = widget.isClient
        ? (_currentBooking['profiles']?['full_name'] ?? "Provider")
        : (_currentBooking['profiles']?['full_name'] ?? "Client");

    final bool iHaveConfirmed = widget.isClient
        ? (_currentBooking['client_confirmed'] ?? false)
        : (_currentBooking['provider_confirmed'] ?? false);

    final bool otherHasConfirmed = widget.isClient
        ? (_currentBooking['provider_confirmed'] ?? false)
        : (_currentBooking['client_confirmed'] ?? false);

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
            // 1. STATUS HEADER
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? Colors.green[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: status == 'completed' ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    status == 'completed' ? Icons.check_circle : Icons.pending,
                    size: 40,
                    color: status == 'completed' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    status == 'completed' ? "Service Completed" : "In Progress",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    status == 'completed'
                        ? "Funds have been released."
                        : "Waiting for confirmation.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            ),

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
                      Text(
                        "You have confirmed. Waiting for $otherName...",
                        style: GoogleFonts.poppins(),
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
            ],

            // 4. RATE PROVIDER BUTTON (Added Section)
            // This displays when the status is finally completed
            if (status == 'completed') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveReviewScreen(
                          bookingId: _currentBooking['id'],
                          serviceId: _currentBooking['service_id'],
                          providerId: _currentBooking['provider_id'],
                          serviceTitle: _currentBooking['services']['title'],
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Rate Provider",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
}
