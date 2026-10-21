import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../services/api_service.dart';

/// What went wrong, independent of language.
enum AppErrorKind {
  noInternet,
  timeout,
  wrongCredentials,
  emailTaken,
  userNotFound,
  invalidEmail,
  weakPassword,
  sessionExpired,
  invalidCode,
  insufficientFunds,
  server,
  other,
}

String _clean(Object? raw) =>
    (raw ?? '').toString().replaceAll('Exception: ', '').trim();

AppErrorKind classifyError(Object? raw) {
  if (raw is UserFriendlyTimeoutException) return AppErrorKind.timeout;
  if (raw is ApiException && raw.statusCode == 402) {
    return AppErrorKind.insufficientFunds;
  }

  final msg = _clean(raw).toLowerCase();
  if (msg == 'no_internet') return AppErrorKind.noInternet;
  if (msg.contains('insufficient') && (msg.contains('balance') || msg.contains('funds'))) {
    return AppErrorKind.insufficientFunds;
  }
  if (msg.contains('invalid login credentials') ||
      msg.contains('wrong password') ||
      msg.contains('incorrect password')) {
    return AppErrorKind.wrongCredentials;
  }
  if (msg.contains('email already') ||
      msg.contains('already registered') ||
      msg.contains('already in use')) {
    return AppErrorKind.emailTaken;
  }
  if (msg.contains('user not found') || msg.contains('no user')) {
    return AppErrorKind.userNotFound;
  }
  if (msg.contains('invalid email') || msg.contains('email format')) {
    return AppErrorKind.invalidEmail;
  }
  if (msg.contains('weak password') || msg.contains('password too short')) {
    return AppErrorKind.weakPassword;
  }
  if (msg.contains('session expired') ||
      msg.contains('unauthorized') ||
      msg.contains('jwt expired')) {
    return AppErrorKind.sessionExpired;
  }
  if (msg.contains('otp') || msg.contains('verification code')) {
    return AppErrorKind.invalidCode;
  }
  if (msg.contains('timeout') || msg.contains('taking too long')) {
    return AppErrorKind.timeout;
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('clientexception')) {
    return AppErrorKind.noInternet;
  }
  if (msg.contains('server error') ||
      msg.contains('internal') ||
      (raw is ApiException && raw.statusCode >= 500)) {
    return AppErrorKind.server;
  }
  return AppErrorKind.other;
}

/// True when [text] reads like a sentence meant for people (e.g. a backend
/// validation message) rather than a stack trace or exception dump.
bool _isHumanReadable(String text) =>
    text.isNotEmpty &&
    text.length < 140 &&
    !RegExp(r'exception|error:|dart:|\{|\}|null check|type .* is not', caseSensitive: false)
        .hasMatch(text);

/// Translated, user-facing message for any error. Prefer this in UI code.
String appErrorMessage(BuildContext context, Object? error) {
  final l10n = AppLocalizations.of(context);
  switch (classifyError(error)) {
    case AppErrorKind.noInternet:
      return l10n.errNoInternet;
    case AppErrorKind.timeout:
      return l10n.errTimeout;
    case AppErrorKind.wrongCredentials:
      return l10n.errWrongCredentials;
    case AppErrorKind.emailTaken:
      return l10n.errEmailTaken;
    case AppErrorKind.userNotFound:
      return l10n.errUserNotFound;
    case AppErrorKind.invalidEmail:
      return l10n.errInvalidEmail;
    case AppErrorKind.weakPassword:
      return l10n.errWeakPassword;
    case AppErrorKind.sessionExpired:
      return l10n.errSessionExpired;
    case AppErrorKind.invalidCode:
      return l10n.errInvalidCode;
    case AppErrorKind.insufficientFunds:
      return l10n.errInsufficientFunds;
    case AppErrorKind.server:
      return l10n.errServer;
    case AppErrorKind.other:
      final text = _clean(error);
      return _isHumanReadable(text) ? text : l10n.errGeneric;
  }
}

/// English-only variant for code without a BuildContext.
String friendlyError(dynamic raw) {
  switch (classifyError(raw)) {
    case AppErrorKind.noInternet:
      return 'No internet connection. Please check your network and try again.';
    case AppErrorKind.timeout:
      return 'The request timed out. Please try again.';
    case AppErrorKind.wrongCredentials:
      return 'Wrong email or password. Please try again.';
    case AppErrorKind.emailTaken:
      return 'This email is already registered. Try signing in instead.';
    case AppErrorKind.userNotFound:
      return "We couldn't find an account with that email.";
    case AppErrorKind.invalidEmail:
      return 'Please enter a valid email address.';
    case AppErrorKind.weakPassword:
      return 'Your password is too weak. Try something longer.';
    case AppErrorKind.sessionExpired:
      return 'Your session expired. Please sign in again.';
    case AppErrorKind.invalidCode:
      return 'That code is invalid or expired. Please request a new one.';
    case AppErrorKind.insufficientFunds:
      return 'Not enough money in your wallet. Top up and try again.';
    case AppErrorKind.server:
      return 'Something went wrong on our end. Please try again shortly.';
    case AppErrorKind.other:
      final text = _clean(raw);
      return _isHumanReadable(text) ? text : 'Something went wrong. Please try again.';
  }
}
