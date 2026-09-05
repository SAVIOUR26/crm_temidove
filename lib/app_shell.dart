import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/auth/auth_state.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/departments/departments_screen.dart';
import 'features/payments/payments_dashboard_screen.dart';
import 'features/staff/staff_screen.dart';
import 'features/students/students_screen.dart';
import 'features/import/import_screen.dart';
import 'theme/app_colors.dart';

/// Left nav + content area. The nav rail carries the app's branding at
/// the top and the signed-in user (with logout) at the bottom, so there's
/// exactly one place users look for "who am I / how do I leave" rather
/// than repeating it on every screen.
///
/// Staff/Import are gated to admin accounts — see AuthState.isAdmin and
/// the client's ask that only an admin adds other staff. Everything else
/// (dashboard, payments, departments, students) is visible to any signed-in
/// staff member.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isAdmin = auth.isAdmin;

    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.space_dashboard_outlined),
        selectedIcon: Icon(Icons.space_dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments),
        label: Text('Payments'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: Text('Departments'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Students'),
      ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: Text('Staff'),
        ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.upload_file_outlined),
          selectedIcon: Icon(Icons.upload_file),
          label: Text('Import'),
        ),
    ];

    final screens = <Widget>[
      const DashboardScreen(),
      const PaymentsDashboardScreen(),
      const DepartmentsScreen(),
      const StudentsScreen(),
      if (isAdmin) const StaffScreen(),
      if (isAdmin) const ImportScreen(),
    ];

    // If the admin-only tabs just disappeared out from under a selected
    // index (shouldn't normally happen mid-session, but keeps this safe),
    // fall back to the dashboard rather than index out of range.
    final selected = _index < screens.length ? _index : 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            leading: const _BrandMark(),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _UserMenu(auth: auth),
              ),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: screens[selected]),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.accentCyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.school, color: Colors.white, size: 24),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  final AuthState auth;
  const _UserMenu({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PopupMenuButton<String>(
        tooltip: '${user.fullName} (${user.role})',
        offset: const Offset(72, 0),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('@${user.username} · ${user.role}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.neutral)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18),
                SizedBox(width: 8),
                Text('Sign out'),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'logout') auth.logout();
        },
        child: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
          child: Text(
            _initials(user.fullName),
            style: const TextStyle(
                color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
