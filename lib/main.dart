import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'database/database.dart';
import 'features/auth/auth_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<AuthState>(create: (_) => AuthState(db)),
      ],
      child: const TemidoveCrmApp(),
    ),
  );
}
