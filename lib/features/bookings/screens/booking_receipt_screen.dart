import 'package:flutter/material.dart';
import 'package:lifekit_frontend/core/widgets/chunky.dart';
import '../../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/share_text.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/store_rules.dart';

class BookingReceiptScreen extends StatelessWidget {
  final dynamic booking;
  final bool isClient;

  const BookingReceiptScreen({
    super.key,
    required this.booking,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status'];
    final price = booking['total_price'];
    final dateObj = parseApiDate(booking['scheduled_time']);
    final dateStr = DateFormat('MMMM dd, yyyy').format(dateObj);
    final timeStr = DateFormat('hh:mm a').format(dateObj);
    final serviceName = booking['services']['title'];

    // Payment status. Only old wallet bookings had money held by LifeKit;
    // everything else is paid to the provider directly.
    final l10n = AppLocalizations.of(context);
    final paidInApp = StoreRules.heldInApp(Map<String, dynamic>.from(booking as Map));
    String escrowStatus = paidInApp ? "Funds held by Escrow" : l10n.directPayTitle;
    Color escrowColor = Colors.orange;
    IconData escrowIcon = paidInApp ? Icons.lock_clock : Icons.handshake_outlined;

    if (status == 'completed') {
      escrowStatus = paidInApp ? "Funds Released to Provider" : l10n.trackStepDone;
      escrowColor = Colors.green;
      escrowIcon = Icons.check_circle;
    } else if (status == 'cancelled') {
      escrowStatus = paidInApp ? "Funds Refunded to Client" : l10n.trackHdrCancelledTitle;
      escrowColor = Colors.red;
      escrowIcon = Icons.error;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          AppLocalizations.of(context).txTransactionReceipt,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // SUCCESS ICON
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "-\$$price",
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              AppLocalizations.of(context).txPaymentSuccessful,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // ESCROW BADGE
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: escrowColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: escrowColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(escrowIcon, color: escrowColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Status: ${status.toUpperCase()}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: escrowColor,
                          ),
                        ),
                        Text(
                          escrowStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // DETAILS
            _buildDetailRow("Service", serviceName),
            _buildDetailRow("Date", dateStr),
            _buildDetailRow("Time", timeStr),
            _buildDetailRow(
              "Booking ID",
              "#${booking['id'].toString().substring(0, 8)}",
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildDetailRow("Total Amount", "\$$price", isBold: true),

            const SizedBox(height: 40),

            OutlinedButton.icon(
              onPressed: () => shareText(
                context,
                'LifeKit receipt\n'
                'Service: $serviceName\n'
                'Date: $dateStr, $timeStr\n'
                'Status: $status\n'
                'Total: \$$price',
              ),
              icon: const Icon(Icons.ios_share, color: Colors.black),
              label: Text(
                AppLocalizations.of(context).txDownloadPdf,
                style: GoogleFonts.poppins(color: Colors.black),
              ),
              style: chunky(OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
