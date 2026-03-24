String friendlyError(dynamic raw) {
  final clean = raw.toString().replaceAll('Exception: ', '').trim();
  final msg = clean.toLowerCase();

  if (clean == 'NO_INTERNET' || msg == 'no_internet') {
    return 'No internet connection. Please check your network and try again.';
  }

  if (msg == 'invalid login credentials' ||
      msg.contains('invalid login credentials')) {
    return 'Wrong email or password. Please try again.';
  }

  if (msg.contains('wrong password') || msg.contains('incorrect password')) {
    return 'Wrong email or password. Please try again.';
  }

  if (msg.contains('email already') ||
      msg.contains('already registered') ||
      msg.contains('already in use') ||
      msg.contains('duplicate')) {
    return 'This email is already registered. Try signing in instead.';
  }

  if (msg.contains('user not found') || msg.contains('no user')) {
    return "We couldn't find an account with that email.";
  }

  if (msg.contains('invalid email') || msg.contains('email format')) {
    return 'Please enter a valid email address.';
  }

  if (msg.contains('weak password') || msg.contains('password too short')) {
    return 'Your password is too weak. Try something longer.';
  }

  if (msg.contains('session expired') ||
      msg.contains('unauthorized') ||
      msg.contains('jwt expired')) {
    return 'Your session expired. Please sign in again.';
  }

  if (msg.contains('token expired') ||
      msg.contains('otp expired') ||
      msg.contains('invalid otp') ||
      msg.contains('verification code') ||
      msg.contains('otp')) {
    return 'That code is invalid or expired. Please request a new one.';
  }

  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection') ||
      msg.contains('clientexception')) {
    return 'No internet connection. Please check your network and try again.';
  }

  if (msg.contains('timeout')) {
    return 'The request timed out. Please try again.';
  }

  if (msg.contains('server error') ||
      msg.contains('500') ||
      msg.contains('internal')) {
    return 'Something went wrong on our end. Please try again shortly.';
  }

  if (clean.length < 80) return clean;
  return 'Something went wrong. Please try again.';
}
