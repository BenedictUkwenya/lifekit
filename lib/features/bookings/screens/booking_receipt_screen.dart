import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

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
    final dateObj = DateTime.parse(booking['scheduled_time']);
    final dateStr = DateFormat('MMMM dd, yyyy').format(dateObj);
    final timeStr = DateFormat('hh:mm a').format(dateObj);
    final serviceName = booking['services']['title'];

    // Escrow Status Logic
    String escrowStatus = "Funds held by Escrow";
    Color escrowColor = Colors.orange;
    IconData escrowIcon = Icons.lock_clock;

    if (status == 'completed') {
      escrowStatus = "Funds Released to Provider";
      escrowColor = Colors.green;
      escrowIcon = Icons.check_circle;
    } else if (status == 'cancelled') {
      escrowStatus = "Funds Refunded to Client";
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
          "Transaction Receipt",
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
              "Payment Successful",
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

            // DOWNLOAD BUTTON (Mock)
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Receipt Downloaded to Files")),
                );
              },
              icon: const Icon(Icons.download, color: Colors.black),
              label: Text(
                "Download PDF",
                style: GoogleFonts.poppins(color: Colors.black),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
