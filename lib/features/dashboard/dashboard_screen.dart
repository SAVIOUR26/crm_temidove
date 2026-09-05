import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_state.dart';

/// The landing tab: an at-a-glance overview of the whole school —
/// students, batches, collections, and overdue payments — so staff don't
/// have to visit every other tab just to answer "how are we doing".
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = context.read<AppDatabase>();
    setState(() {
      _future = db.dashboardDao.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final greetingName = auth.currentUser?.fullName.split(' ').first ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $greetingName',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(color: AppColors.neutral),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cross = constraints.maxWidth > 1100
                        ? 4
                        : constraints.maxWidth > 700
                            ? 2
                            : 1;
                    final cards = [
                      _StatCard(
                        icon: Icons.people_alt,
                        color: AppColors.primaryBlue,
                        label: 'Total students',
                        value: '${stats.totalStudents}',
                      ),
                      _StatCard(
                        icon: Icons.groups_2,
                        color: AppColors.accentCyan,
                        label: 'Active batches',
                        value: '${stats.activeBatches}',
                      ),
                      _StatCard(
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        label: 'Overdue payments',
                        value: '${stats.overdueCount}',
                        sublabel: stats.overdueCount == 0
                            ? 'All caught up'
                            : '${currency.format(stats.overdueOutstanding)} outstanding',
                      ),
                      _StatCard(
                        icon: Icons.trending_up,
                        color: AppColors.success,
                        label: 'Collected this month',
                        value: currency.format(stats.monthCollected),
                        sublabel:
                            'of ${currency.format(stats.monthExpected)} expected',
                      ),
                    ];
                    return GridView.count(
                      crossAxisCount: cross,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: cross == 1 ? 2.6 : 1.6,
                      children: cards,
                    );
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CollectionProgressCard(
                          stats: stats, currency: currency),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _StudentStatusCard(stats: stats),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.school,
                        label: 'Departments',
                        value: '${stats.totalDepartments}',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.badge,
                        label: 'Staff members',
                        value: '${stats.totalStaff}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? sublabel;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.neutral, fontSize: 13)),
            if (sublabel != null) ...[
              const SizedBox(height: 2),
              Text(
                sublabel!,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionProgressCard extends StatelessWidget {
  final DashboardStats stats;
  final NumberFormat currency;
  const _CollectionProgressCard({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final pct = (stats.collectionRate * 100).toStringAsFixed(0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month\'s collection rate',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.collectionRate,
                minHeight: 12,
                backgroundColor: AppColors.surfaceTint,
                valueColor: const AlwaysStoppedAnimation(AppColors.accentCyan),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$pct% collected · ${currency.format(stats.monthCollected)} of '
              '${currency.format(stats.monthExpected)}',
              style: const TextStyle(color: AppColors.neutral),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentStatusCard extends StatelessWidget {
  final DashboardStats stats;
  const _StudentStatusCard({required this.stats});

  static const _statusColors = {
    'waiting': AppColors.warning,
    'started': AppColors.accentCyan,
    'completed': AppColors.success,
    'cancelled': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Students by status',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final entry in stats.studentsByStatus.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColors[entry.key] ?? AppColors.neutral,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.key)),
                    Text('${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.neutral)),
          ],
        ),
      ),
    );
  }
}
