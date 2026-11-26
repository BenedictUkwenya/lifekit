import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/chunky.dart';
import '../../../core/widgets/lifekit_loader.dart';
import '../../../l10n/app_localizations.dart';

/// IBAN check (format + ISO 13616 mod-97), mirrored on the backend.
/// Georgian IBANs are 22 characters, e.g. GE29NB0000000101904917.
String normalizeIban(String v) => v.replaceAll(RegExp(r'\s+'), '').toUpperCase();

bool isValidIban(String raw) {
  final iban = normalizeIban(raw);
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(iban)) return false;
  if (iban.startsWith('GE') && iban.length != 22) return false;
  final rearranged = iban.substring(4) + iban.substring(0, 4);
  var rem = 0;
  for (final ch in rearranged.split('')) {
    final code = ch.codeUnitAt(0);
    final digits = code >= 65 ? (code - 55).toString() : ch;
    for (final d in digits.split('')) {
      rem = (rem * 10 + int.parse(d)) % 97;
    }
  }
  return rem == 1;
}

/// "GE29NB0000000101904917" -> "GE29 NB00 0000 0101 9049 17"
String formatIban(String iban) {
  final s = normalizeIban(iban);
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && i % 4 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

/// Where a provider says how clients can pay them. LifeKit never handles the
/// money; bank details are shown only to the client of an accepted booking.
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _api = ApiService();
  final _bank = TextEditingController();
  final _holder = TextEditingController();
  final _iban = TextEditingController();
  bool _cash = false, _card = false, _transfer = false;
  bool _loading = true, _saving = false, _showErrors = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.getMyPaymentDetails();
      final m = (d['methods'] as Map?) ?? const {};
      final b = (d['bank'] as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        _cash = m['cash'] == true;
        _card = m['card'] == true;
        _transfer = m['transfer'] == true;
        _bank.text = '${b['bank_name'] ?? ''}';
        _holder.text = '${b['account_holder'] ?? ''}';
        _iban.text = b['iban'] == null ? '' : formatIban('${b['iban']}');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  @override
  void dispose() {
    _bank.dispose();
    _holder.dispose();
    _iban.dispose();
    super.dispose();
  }

  String? _ibanError(AppLocalizations l10n) {
    if (!_transfer) return null;
    final v = _iban.text.trim();
    if (v.isEmpty || !isValidIban(v)) return l10n.payIbanInvalid;
    return null;
  }

  String? _holderError(AppLocalizations l10n) =>
      _transfer && _holder.text.trim().isEmpty ? l10n.payHolderRequired : null;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _showErrors = true);
    if (!_cash && !_card && !_transfer) {
      AppToast.info(context, l10n.payPickOne);
      return;
    }
    if (_ibanError(l10n) != null || _holderError(l10n) != null) return;
    setState(() => _saving = true);
    try {
      await _api.savePaymentDetails(
        cash: _cash,
        card: _card,
        transfer: _transfer,
        bankName: _transfer ? _bank.text.trim() : null,
        accountHolder: _transfer ? _holder.text.trim() : null,
        iban: _transfer ? normalizeIban(_iban.text) : null,
      );
      if (!mounted) return;
      AppToast.success(context, l10n.paySaved);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, appErrorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: Text(l10n.payDetailsTitle)),
      body: _loading
          ? const Center(child: LifeKitLoader(showSlowHint: false))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(l10n.payDetailsIntro,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                  const SizedBox(height: 22),
                  _heading(l10n.payMethodsHeading),
                  _box(Column(children: [
                    _method(Icons.payments_outlined, l10n.payMethodCash, _cash, (v) => setState(() => _cash = v)),
                    const Divider(height: 1),
                    _method(Icons.credit_card_rounded, l10n.payMethodCard, _card, (v) => setState(() => _card = v)),
                    const Divider(height: 1),
                    _method(Icons.account_balance_outlined, l10n.payMethodTransfer, _transfer,
                        (v) => setState(() => _transfer = v)),
                  ])),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: !_transfer
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _heading(l10n.payBankHeading),
                                _field(_holder, l10n.payAccountHolder,
                                    error: _showErrors ? _holderError(l10n) : null,
                                    caps: TextCapitalization.words),
                                const SizedBox(height: 12),
                                _field(_iban, l10n.payIban,
                                    hint: l10n.payIbanHint,
                                    error: _showErrors ? _ibanError(l10n) : null,
                                    caps: TextCapitalization.characters,
                                    formatters: [_IbanFormatter()]),
                                const SizedBox(height: 12),
                                _field(_bank, l10n.payBankName, caps: TextCapitalization.words),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.lock_outline_rounded, size: 15, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(l10n.payPrivacyNote,
                                          style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey[600], height: 1.45)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('pay_details_save'),
                      onPressed: _saving ? null : _save,
                      style: chunky(ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      )),
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(l10n.txSaveChanges,
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _box(Widget child) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );

  Widget _method(IconData icon, String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    String? error,
    TextCapitalization caps = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) =>
      TextField(
        controller: c,
        textCapitalization: caps,
        inputFormatters: formatters,
        onChanged: (_) {
          if (_showErrors) setState(() {});
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      );
}

/// Upper-cases and groups the IBAN in blocks of four while typing.
class _IbanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = normalizeIban(newValue.text).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped = raw.length > 34 ? raw.substring(0, 34) : raw;
    final text = formatIban(clipped);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
