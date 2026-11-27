import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/share_text.dart';
import '../../../core/widgets/chunky.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/place_category_art.dart';

/// One place, with only real data (OpenStreetMap): address, opening hours,
/// phone, website and features when the map has them, plus actions that work —
/// directions, call, website, share. No invented ratings or reviews.
class PlaceDetailScreen extends StatelessWidget {
  final dynamic place;
  const PlaceDetailScreen({super.key, required this.place});

  String? _str(String key) {
    final v = place[key];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty || s == 'Nearby' || s == 'Detected' ? null : s;
  }

  Future<void> _open(Uri uri) async {
    HapticFeedback.selectionClick();
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri get _directions {
    final lat = place['latitude'], lng = place['longitude'];
    final name = Uri.encodeComponent('${place['name'] ?? ''}');
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$name');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = placeCategoryStyle(place['category']?.toString());
    final images = (place['image_urls'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final address = [_str('address'), _str('city')].whereType<String>().join(', ');
    final hours = _str('opening_hours');
    final phone = _str('phone');
    String? website = _str('website');
    if (website != null && !website.startsWith('http')) website = 'https://$website';
    final features = (place['features'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final description = _str('description');
    final distance = place['distance_km'] != null ? l10n.placesKmAway('${place['distance_km']}') : null;
    final hasDetails = address.isNotEmpty || hours != null || phone != null || website != null ||
        features.isNotEmpty || description != null;

    Widget action(IconData icon, String label, VoidCallback onTap, {bool primary = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: primary
                ? ElevatedButton.icon(
                    onPressed: onTap,
                    style: chunky(ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    )),
                    icon: Icon(icon, size: 18),
                    label: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  )
                : OutlinedButton.icon(
                    onPressed: onTap,
                    style: chunky(OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    )),
                    icon: Icon(icon, size: 18),
                    label: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ),
          ),
        );

    Widget infoRow(IconData icon, String title, String value, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: onTap != null ? AppColors.primary : AppColors.textDark)),
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: images.isNotEmpty ? 280 : 200,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            actions: [
              Builder(
                builder: (btn) => IconButton(
                  tooltip: l10n.placesShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => shareText(btn,
                      '${place['name']}${address.isNotEmpty ? '\n$address' : ''}\n${_directions.toString()}'),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: images.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox(height: 280, radius: 0),
                      errorWidget: (_, __, ___) => PlaceCategoryArt(style: style, height: 280),
                    )
                  : PlaceCategoryArt(style: style, height: 260),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(style.icon, size: 16, color: style.color),
                    const SizedBox(width: 6),
                    Text('${place['category'] ?? ''}',
                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: style.color)),
                    if (distance != null) ...[
                      const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                      Text(distance, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[700])),
                    ],
                  ]).fadeSlideIn(index: 0),
                  const SizedBox(height: 6),
                  Text('${place['name'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25))
                      .fadeSlideIn(index: 1),
                  const SizedBox(height: 18),
                  Row(children: [
                    action(Icons.directions_rounded, l10n.placesDirections, () => _open(_directions), primary: true),
                    if (phone != null)
                      action(Icons.call_rounded, l10n.placesCall,
                          () => _open(Uri.parse('tel:${phone.split(RegExp(r'[;,]')).first.replaceAll(' ', '')}'))),
                    if (website != null) action(Icons.language_rounded, l10n.placesWebsite, () => _open(Uri.parse(website!))),
                  ]).fadeSlideIn(index: 2),
                  const SizedBox(height: 22),
                  if (hasDetails)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(children: [
                        if (address.isNotEmpty) infoRow(Icons.location_on_outlined, l10n.placesAddress, address),
                        if (hours != null) infoRow(Icons.schedule_rounded, l10n.placesOpeningHours, hours),
                        if (phone != null)
                          infoRow(Icons.call_outlined, l10n.placesPhone, phone,
                              onTap: () => _open(Uri.parse('tel:${phone.split(RegExp(r'[;,]')).first.replaceAll(' ', '')}'))),
                        if (website != null)
                          infoRow(Icons.language_rounded, l10n.placesWebsite,
                              Uri.parse(website).host.replaceFirst('www.', ''), onTap: () => _open(Uri.parse(website!))),
                        if (description != null) infoRow(Icons.info_outline_rounded, l10n.placesAbout, description),
                      ]),
                    ).fadeSlideIn(index: 3)
                  else
                    Text(l10n.placesNoDetails, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in features)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(f, style: GoogleFonts.poppins(fontSize: 12)),
                        ),
                    ]).fadeSlideIn(index: 4),
                  ],
                  const SizedBox(height: 24),
                  // Required credit for OpenStreetMap data (ODbL).
                  GestureDetector(
                    onTap: () => _open(Uri.parse('https://www.openstreetmap.org/copyright')),
                    child: Text(l10n.placesDataCredit,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
