import 'package:flutter/material.dart';

import 'features/departments/departments_screen.dart';
import 'features/payments/payments_dashboard_screen.dart';
import 'features/staff/staff_screen.dart';
import 'features/students/students_screen.dart';
import 'features/import/import_screen.dart';

class TemidoveCrmApp extends StatelessWidget {
  const TemidoveCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temidove CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Brand colors carried over from the old PHP app's inline CSS
        // (README.md: "Primary Blue #1e3a8a, Cyan/Accent #06b6d4").
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF06B6D4),
        ),
      ),
      home: const AppShell(),
    );
  }
}

/// Left nav + content area. This is a starting shell — TODO(claude-code):
/// swap for go_router once there's enough screen depth (student detail,
/// batch detail, import preview) to want real navigation history/deep
/// links instead of a simple index switch.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Payments due'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: Text('Departments'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Students'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.badge_outlined),
      selectedIcon: Icon(Icons.badge),
      label: Text('Staff'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.upload_file_outlined),
      selectedIcon: Icon(Icons.upload_file),
      label: Text('Import'),
    ),
  ];

  static const _screens = [
    PaymentsDashboardScreen(),
    DepartmentsScreen(),
    StudentsScreen(),
    StaffScreen(),
    ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _screens[_index]),
        ],
      ),
    );
  }
}
