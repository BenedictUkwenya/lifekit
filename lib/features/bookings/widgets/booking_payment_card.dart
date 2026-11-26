import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/chunky.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/screens/payment_details_screen.dart';

/// "How to pay" for a direct booking. LifeKit never moves the money: this
/// shows how the provider accepts payment, reveals their bank details to the
/// client once the booking is accepted, and keeps a shared "I've paid" /
/// "Payment received" record.
class BookingPaymentCard extends StatefulWidget {
  final Map booking;
  final bool isClient;
  final String otherName;

  /// Tests only: render with this data instead of calling the API.
  @visibleForTesting
  final Map<String, dynamic>? debugData;

  const BookingPaymentCard({
    super.key,
    required this.booking,
    required this.isClient,
    required this.otherName,
    this.debugData,
  });

  @override
  State<BookingPaymentCard> createState() => _BookingPaymentCardState();
}

class _BookingPaymentCardState extends State<BookingPaymentCard> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _busy = false;

  String get _id => '${widget.booking['id']}';
  String get _status => '${widget.booking['status'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BookingPaymentCard old) {
    super.didUpdateWidget(old);
    if ('${old.booking['status']}' != _status || old.debugData != widget.debugData) _load();
  }

  Future<void> _load() async {
    if (widget.debugData != null) {
      setState(() => _data = widget.debugData);
      return;
    }
    try {
      final d = await _api.getBookingPaymentDetails(_id);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // Non-critical: the booking still works without this card.
      if (mounted) setState(() => _data = const {});
    }
  }

  Future<void> _markPaid() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isClient ? l10n.payMarkPaidTitle : l10n.payReceivedTitle),
        content: Text(widget.isClient ? l10n.payMarkPaidBody(widget.otherName) : l10n.payReceivedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isClient ? l10n.payIvePaid : l10n.payReceivedButton),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.markBookingPaid(_id);
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, appErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final methods = (d['methods'] as Map?) ?? const {};
    final bank = d['bank'] as Map?;
    final hasAnyMethod = methods.values.any((v) => v == true);
    final clientPaid = d['client_marked_paid_at'] != null;
    final providerConfirmed = d['provider_confirmed_paid_at'] != null;
    final canRecord = const {'confirmed', 'completed', 'disputed'}.contains(_status);

    final methodLabels = [
      if (methods['cash'] == true) l10n.payMethodCash,
      if (methods['card'] == true) l10n.payMethodCard,
      if (methods['transfer'] == true) l10n.payMethodTransfer,
    ];

    final children = <Widget>[
      Row(children: [
        const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(l10n.payHowToPay, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
    ];

    if (hasAnyMethod) {
      children.add(Wrap(spacing: 6, runSpacing: 6, children: [
        for (final m in methodLabels) _chip(m),
      ]));
    } else if (widget.isClient) {
      children.add(_text(l10n.payHowToPayNoDetails(widget.otherName)));
    } else {
      children.addAll([
        _text(l10n.payAddYourDetails),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final saved = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()));
            if (saved == true) _load();
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.payAddDetailsButton),
        ),
      ]);
    }

    // Bank details: client only, once accepted and until paid.
    if (widget.isClient && methods['transfer'] == true) {
      if (bank != null) {
        children.addAll([
          const SizedBox(height: 14),
          _bankBox(l10n, bank),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 15, color: Colors.orange[800]),
            const SizedBox(width: 6),
            Expanded(child: _text(l10n.paySafetyTip, size: 11.5, color: Colors.orange[900])),
          ]),
        ]);
      } else if (d['bank_hidden_reason'] == 'not_accepted') {
        children.addAll([const SizedBox(height: 10), _text(l10n.payBankAfterAccept(widget.otherName), size: 12)]);
      }
    }

    // Shared payment record.
    if (canRecord) {
      children.add(const SizedBox(height: 14));
      if (providerConfirmed) {
        children.add(_statusPill(l10n.payConfirmedDone, Colors.green));
      } else if (widget.isClient) {
        children.add(clientPaid
            ? _statusPill(l10n.payMarkedPaid(widget.otherName), Colors.blue)
            : _button(l10n.payIvePaid, 'pay_mark_paid'));
      } else {
        children.addAll([
          _text(clientPaid ? l10n.payClientSaysPaid(widget.otherName) : l10n.payWaitingClient, size: 12.5),
          const SizedBox(height: 10),
          _button(l10n.payReceivedButton, 'pay_mark_received'),
        ]);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _text(String s, {double size = 13, Color? color}) =>
      Text(s, style: GoogleFonts.poppins(fontSize: size, color: color ?? Colors.grey[700], height: 1.45));

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
      );

  Widget _statusPill(String label, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _button(String label, String key) => SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          key: Key(key),
          onPressed: _busy ? null : _markPaid,
          style: chunky(ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          )),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : Text(label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _bankBox(AppLocalizations l10n, Map bank) {
    final iban = '${bank['iban']}';
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 110,
              child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            ),
            Expanded(
              child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF7F4F5), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((bank['account_holder'] ?? '').toString().isNotEmpty)
          row(l10n.payAccountHolder, '${bank['account_holder']}'),
        if ((bank['bank_name'] ?? '').toString().isNotEmpty) row(l10n.payBankName.split(' (').first, '${bank['bank_name']}'),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: SelectableText(formatIban(iban),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          ),
          TextButton.icon(
            key: const Key('pay_copy_iban'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: iban));
              if (mounted) AppToast.success(context, l10n.payCopied);
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l10n.payCopy),
          ),
        ]),
      ]),
    );
  }
}
