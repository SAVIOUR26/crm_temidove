import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';
import 'theme/app_theme.dart';

class TemidoveCrmApp extends StatelessWidget {
  const TemidoveCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temidove CRM',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
