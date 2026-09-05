import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'database/database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  runApp(
    Provider<AppDatabase>.value(
      value: db,
      child: const TemidoveCrmApp(),
    ),
  );
}
