import 'package:flutter/material.dart';
import 'package:lifekit_frontend/core/widgets/app_lottie.dart';
import 'package:lifekit_frontend/core/widgets/celebrate.dart';
import 'package:lifekit_frontend/core/widgets/chunky.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/app_localizations.dart';

class LeaveReviewScreen extends StatefulWidget {
  final String bookingId;
  final String serviceId;
  // Who is being rated (provider_id when client rates, client_id when provider rates)
  final String revieweeId;
  // 'client' = client rating provider, 'provider' = provider rating client
  final String reviewerRole;
  // Display name of the person being rated
  final String revieweeName;

  const LeaveReviewScreen({
    super.key,
    required this.bookingId,
    required this.serviceId,
    required this.revieweeId,
    required this.reviewerRole,
    required this.revieweeName,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  // No default: a pre-filled 5 makes every rating look the same.
  int _rating = 0;
  final Set<String> _tags = {};
  bool _isLoading = false;

  bool get _ratingProvider => widget.reviewerRole == 'client';

  List<String> _tagOptions(AppLocalizations l10n) => _ratingProvider
      ? [
          l10n.reviewTagOnTime,
          l10n.reviewTagFriendly,
          l10n.reviewTagQuality,
          l10n.reviewTagValue,
          l10n.reviewTagProfessional,
        ]
      : [
          l10n.reviewTagOnTime,
          l10n.reviewTagRespectful,
          l10n.reviewTagCommunication,
          l10n.reviewTagEasy,
        ];

  String _ratingWord(AppLocalizations l10n) => switch (_rating) {
        1 => l10n.reviewRating1,
        2 => l10n.reviewRating2,
        3 => l10n.reviewRating3,
        4 => l10n.reviewRating4,
        5 => l10n.reviewRating5,
        _ => l10n.reviewTapToRate,
      };

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isLoading = true);
    // Tags go in front of the written comment so they show wherever reviews do.
    final text = _commentController.text.trim();
    final comment = [
      if (_tags.isNotEmpty) _tags.join(' · '),
      if (text.isNotEmpty) text,
    ].join('\n');
    try {
      await _apiService.submitReview(
        bookingId: widget.bookingId,
        serviceId: widget.serviceId,
        revieweeId: widget.revieweeId,
        reviewerRole: widget.reviewerRole,
        rating: _rating,
        comment: comment,
      );
      if (mounted) {
        await Celebrate.show(context, title: AppLocalizations.of(context).msgReviewSubmitted, anim: AppAnim.stars);
        if (mounted) Navigator.pop(context, true); // true = rated successfully
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, appErrorMessage(context, e));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = widget.revieweeName.trim().isEmpty ? '?' : widget.revieweeName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          _ratingProvider ? l10n.reviewRateProviderTitle : l10n.reviewRateClientTitle,
          style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Who + stars ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      decoration: _card,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              name.characters.first.toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ).popIn(),
                          const SizedBox(height: 14),
                          Text(l10n.txHowWasYourExperienceWith,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textGrey)),
                          const SizedBox(height: 4),
                          Text(name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 1; i <= 5; i++)
                                Semantics(
                                  button: true,
                                  label: '$i',
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _rating = i);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: AnimatedScale(
                                        scale: i <= _rating ? 1.12 : 1.0,
                                        duration: Motion.fast,
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                          size: 46,
                                          color: i <= _rating ? const Color(0xFFF5A524) : Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: Motion.fast,
                            child: Text(
                              _ratingWord(l10n),
                              key: ValueKey(_rating),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _rating == 0 ? Colors.grey[400] : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).fadeSlideIn(),

                    // ── Quick tags ─────────────────────────────────────────
                    const SizedBox(height: 22),
                    Text(l10n.reviewWhatStoodOut,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in _tagOptions(l10n))
                          FilterChip(
                            label: Text(tag),
                            selected: _tags.contains(tag),
                            onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                            showCheckmark: false,
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _tags.contains(tag) ? Colors.white : AppColors.textDark,
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary,
                            side: BorderSide(
                              color: _tags.contains(tag) ? AppColors.primary : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          ),
                      ],
                    ).fadeSlideIn(index: 1),

                    // ── Written review ─────────────────────────────────────
                    const SizedBox(height: 22),
                    Text(l10n.reviewTellMore,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: _card,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 5,
                        minLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
                        decoration: InputDecoration(
                          hintText: l10n.reviewCommentHint,
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                          border: InputBorder.none,
                          counterStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                        ),
                      ),
                    ).fadeSlideIn(index: 2),
                  ],
                ),
              ),
            ),

            // ── Submit, pinned to the bottom ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _rating == 0 || _isLoading ? null : _submit,
                  style: chunky(ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  )),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          l10n.reviewsSubmit,
                          style: GoogleFonts.poppins(
                            color: _rating == 0 ? Colors.grey.shade600 : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _card = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6)),
  ],
);
