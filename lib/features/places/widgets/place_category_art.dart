import 'package:flutter/material.dart';

/// Icon + colour for a place category (shown instead of stock photos).
class PlaceCategoryStyle {
  final IconData icon;
  final Color color;
  const PlaceCategoryStyle(this.icon, this.color);
}

PlaceCategoryStyle placeCategoryStyle(String? category) {
  switch (category) {
    case 'Restaurant':
      return const PlaceCategoryStyle(Icons.restaurant_rounded, Color(0xFFC0485F));
    case 'Fast Food':
      return const PlaceCategoryStyle(Icons.lunch_dining_rounded, Color(0xFFD9772B));
    case 'Café':
      return const PlaceCategoryStyle(Icons.local_cafe_rounded, Color(0xFF8A5A44));
    case 'Bar & Pub':
      return const PlaceCategoryStyle(Icons.local_bar_rounded, Color(0xFF7B3FA0));
    case 'Hotel':
      return const PlaceCategoryStyle(Icons.hotel_rounded, Color(0xFF3B6FB6));
    case 'Attraction':
      return const PlaceCategoryStyle(Icons.account_balance_rounded, Color(0xFF89273B));
    case 'Park':
      return const PlaceCategoryStyle(Icons.park_rounded, Color(0xFF2E8B57));
    case 'Health':
      return const PlaceCategoryStyle(Icons.local_pharmacy_rounded, Color(0xFF1F9D8B));
    case 'Finance':
      return const PlaceCategoryStyle(Icons.account_balance_wallet_rounded, Color(0xFF4A5A6A));
    case 'Worship':
      return const PlaceCategoryStyle(Icons.church_rounded, Color(0xFF8C6D1F));
    default:
      return const PlaceCategoryStyle(Icons.place_rounded, Color(0xFF89273B));
  }
}

/// Neutral, honest artwork for a place with no real photo: a soft gradient in
/// the category colour with its icon (no stock photo pretending to be it).
class PlaceCategoryArt extends StatelessWidget {
  final PlaceCategoryStyle style;
  final double height;
  const PlaceCategoryArt({super.key, required this.style, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.color.withValues(alpha: 0.18), style.color.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -18,
          bottom: -22,
          child: Icon(style.icon, size: height * 1.05, color: style.color.withValues(alpha: 0.10)),
        ),
        Center(child: Icon(style.icon, size: height * 0.36, color: style.color.withValues(alpha: 0.85))),
      ]),
    );
  }
}
