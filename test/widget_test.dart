// Smoke test for the whole app-open flow: boots TemidoveCrmApp against an
// in-memory database (so it doesn't touch the real filesystem via
// path_provider), goes through the first-run "create admin" screen (a
// fresh DB has no staff yet), and checks the app shell's nav destinations
// render and switch screens once logged in.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:temidove_crm/app.dart';
import 'package:temidove_crm/database/database.dart';
import 'package:temidove_crm/features/auth/auth_state.dart';

void main() {
  testWidgets('First-run setup, login-gated shell, and nav destinations',
      (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<AuthState>(create: (_) => AuthState(db)),
        ],
        child: const TemidoveCrmApp(),
      ),
    );

    // Splash screen shows first, with a minimum display timer — advance
    // past it (and let the "does any staff exist" check resolve) rather
    // than pumpAndSettle while its indeterminate spinner is on screen.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    // No staff exist yet in a fresh database -> first-run admin setup.
    expect(find.text('Welcome to Temidove CRM'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Full name'), 'Ada Admin');
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ada');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'password123');
    await tester.ensureVisible(find.text('Create administrator account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create administrator account'));
    await tester.pumpAndSettle();

    // Creating the first account logs it in immediately as admin, landing
    // on the app shell with every nav destination (including admin-only
    // Staff/Import) visible.
    // "Dashboard" and "Departments" each appear twice here (nav label +
    // this screen's own AppBar title / "Departments" stat label).
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Departments'), findsWidgets);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);

    // Dashboard starts selected.
    expect(find.text('Welcome back, Ada'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing due in the next 7 days. All caught up.'),
        findsOneWidget);

    await tester.tap(find.text('Departments'));
    await tester.pumpAndSettle();
    expect(find.text('No departments yet — import legacy data or add one.'),
        findsOneWidget);

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    expect(find.text('No students match — import legacy data or add one.'),
        findsOneWidget);

    await tester.tap(find.text('Staff'));
    await tester.pumpAndSettle();
    expect(find.text('@ada'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(
        find.text('Choose an Excel payment tracker (.xlsx)'), findsOneWidget);

    // Signing out returns to the login screen.
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
