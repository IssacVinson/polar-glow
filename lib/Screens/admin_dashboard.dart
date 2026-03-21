import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_manage_bookings_screen.dart';
import 'admin_promotion_screen.dart.dart'; // Promote Accounts
import 'admin_employee_list_screen.dart'; // Track Employees
import 'admin_schedule_calendar_screen.dart'; // Overall Schedule + Manage Bookings
import 'admin_services_screen.dart'; // Manage Services
import 'admin_payroll_overview_screen.dart'; // Payroll Overview
import 'profile_screen.dart'; // ← NEW: Profile screen (same one employees use)

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Admin Controls',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage users, schedules & more',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.05,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _TaskCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Promote Accounts',
                      subtitle: 'Change roles & permissions',
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPromotionScreen()),
                      ),
                    ),
                    _TaskCard(
                      icon: Icons.people_alt_rounded,
                      title: 'Track Employees',
                      subtitle: 'View & search staff',
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminEmployeeListScreen()),
                      ),
                    ),
                    _TaskCard(
                      icon: Icons.calendar_today_rounded,
                      title: 'Overall Schedule',
                      subtitle: 'All bookings at a glance',
                      color: Colors.deepPurple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const AdminScheduleCalendarScreen()),
                      ),
                    ),
                    _TaskCard(
                      icon: Icons.list_alt_rounded,
                      title: 'Manage Services',
                      subtitle: 'Edit pricing & offerings',
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminServicesScreen()),
                      ),
                    ),
                    _TaskCard(
                      icon: Icons.book_online_rounded,
                      title: 'Manage Bookings',
                      subtitle: 'Assign, edit, cancel',
                      color: Colors.amber.shade700,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminManageBookingsScreen()),
                      ),
                    ),
                    _TaskCard(
                      icon: Icons.payments_rounded,
                      title: 'Payroll Overview',
                      subtitle: 'Hours, earnings, payouts',
                      color: Colors.cyan,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPayrollOverviewScreen()),
                      ),
                    ),
                    // ==================== NEW: PROFILE CARD ====================
                    _TaskCard(
                      icon: Icons.person_outline_rounded,
                      title: 'My Profile',
                      subtitle: 'Edit name, phone & password',
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Signed out successfully'),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sign out failed: ${e.toString().split('\n')[0]}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TaskCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 3,
      shadowColor: color.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.12),
        highlightColor: color.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
