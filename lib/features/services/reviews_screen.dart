import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/lifekit_loader.dart'; // Ensure you have this widget

class ReviewsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceTitle; // Added context for the review screen

  const ReviewsScreen({
    super.key,
    required this.serviceId,
    required this.serviceTitle,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> reviews = [];
  bool isLoading = true;
  double averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      // Fetch reviews directly here
      final data = await _apiService.getReviews(widget.serviceId);

      if (mounted) {
        setState(() {
          reviews = data;

          // Calculate average locally
          if (reviews.isNotEmpty) {
            double sum = 0;
            for (var r in reviews) {
              final rating = r['rating'];
              if (rating is int) {
                sum += rating.toDouble();
              } else if (rating is double) {
                sum += rating;
              }
            }
            averageRating = sum / reviews.length;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          reviews = []; // Handle error case
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Reviews",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: LifeKitLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reviews for",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  Text(
                    widget.serviceTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                Icons.star,
                                color: index < averageRating.round()
                                    ? Colors.amber
                                    : Colors.grey[300],
                                size: 20,
                              ),
                            ),
                          ),
                          Text(
                            "Based on ${reviews.length} reviews",
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // List
                  if (reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          "No reviews yet.",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...reviews.map((r) => _buildReviewItem(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildReviewItem(dynamic r) {
    // Handling the nested 'profiles' data structure correctly
    final user = r['profiles'];
    final name = user?['full_name'] ?? 'Anonymous';
    final pic = user?['profile_picture_url'];
    final rating = r['rating'] ?? 5;
    final comment = r['comment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: pic != null
                ? CachedNetworkImageProvider(pic)
                : null,
            radius: 20,
            backgroundColor: Colors.grey[200],
            child: pic == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    // Optional: Add date here if your API returns created_at
                    /*
                    Text(
                      "2 days ago",
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                    ),
                    */
                  ],
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      size: 12,
                      color: index < rating ? Colors.amber : Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
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
    );
  }
}
