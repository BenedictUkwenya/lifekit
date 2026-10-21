import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/reset_password_screen.dart';

/// Listens for Supabase password-recovery deep links and opens the reset screen.
class AuthRecoveryListener extends StatefulWidget {
  const AuthRecoveryListener({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<AuthRecoveryListener> createState() => _AuthRecoveryListenerState();
}

class _AuthRecoveryListenerState extends State<AuthRecoveryListener> {
  StreamSubscription<AuthState>? _sub;
  bool _handlingRecovery = false;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
  }

  void _onAuthChange(AuthState data) {
    if (data.event != AuthChangeEvent.passwordRecovery || _handlingRecovery) return;
    _handlingRecovery = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = widget.navigatorKey.currentState;
      if (nav == null) {
        _handlingRecovery = false;
        return;
      }

      nav.push(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      ).whenComplete(() => _handlingRecovery = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
