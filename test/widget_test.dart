// Smoke test for the app shell: boots TemidoveCrmApp against an in-memory
// database (so it doesn't touch the real filesystem via path_provider) and
// checks that all nav destinations are present and switch screens.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:temidove_crm/app.dart';
import 'package:temidove_crm/database/database.dart';

void main() {
  testWidgets('App shell shows all nav destinations and switches screens',
      (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: const TemidoveCrmApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payments due'), findsOneWidget);
    expect(find.text('Departments'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);

    // Payments dashboard starts selected — empty database means "all caught up".
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
    expect(find.text('No staff yet — add one.'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an Excel payment tracker (.xlsx)'), findsOneWidget);
  });
}
