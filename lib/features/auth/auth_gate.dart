import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_shell.dart';
import '../splash/splash_screen.dart';
import 'auth_state.dart';
import 'login_screen.dart';
import 'setup_admin_screen.dart';

/// Picks the right top-level screen based on AuthState — splash while
/// checking, first-run admin setup, login, or the real app shell. Also
/// enforces a minimum splash duration so it reads as an intentional
/// branded moment rather than a flash of blue on a fast PC.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!_minSplashElapsed || auth.status == AuthStatus.checking) {
      return const SplashScreen();
    }
    return switch (auth.status) {
      AuthStatus.needsSetup => const SetupAdminScreen(),
      AuthStatus.loggedOut => const LoginScreen(),
      AuthStatus.loggedIn => const AppShell(),
      AuthStatus.checking => const SplashScreen(),
    };
  }
}
