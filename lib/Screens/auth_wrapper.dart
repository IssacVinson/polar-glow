import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart'; // for HomeScreen (customer)
import 'login_screen.dart';
import 'user_promotion_screen.dart'; // separate promotion screen
import 'employee_availability_screen.dart'; // availability screen
import 'admin_employee_list_screen.dart'; // Step 1 employee list
import 'employee_clock_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role =
                roleSnapshot.data?.get('role') as String? ?? 'customer';

            switch (role) {
              case 'admin':
                return const AdminDashboard();
              case 'employee':
                return const EmployeeDashboard();
              default:
                return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Admin Dashboard (menu with task cards)
// ──────────────────────────────────────────────

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              'Admin Tools',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                children: [
                  _buildTaskCard(
                    context,
                    icon: Icons.person_add_alt_1,
                    title: 'Promote Accounts',
                    subtitle: 'Search & change roles',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserPromotionScreen(),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.people_outline,
                    title: 'Track Employees',
                    subtitle: 'View & search all employees',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminEmployeeListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.calendar_today,
                    title: 'Manage Bookings',
                    subtitle: 'View, assign, cancel',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Manage Bookings – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.payments,
                    title: 'Payroll Overview',
                    subtitle: 'Earnings & payouts',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payroll Overview – coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Employee Dashboard (menu with task cards)
// ──────────────────────────────────────────────

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await auth.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              'Employee Tools',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                children: [
                  _buildTaskCard(
                    context,
                    icon: Icons.calendar_month,
                    title: 'Set My Availability',
                    subtitle: 'Update days & time blocks',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const EmployeeAvailabilityScreen(),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.location_on,
                    title: 'Set Regions',
                    subtitle: 'Anc, Wasilla, ER, Base',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Region selection – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.route,
                    title: 'Route Planning',
                    subtitle: 'View & optimize daily routes',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Route planning – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.beach_access,
                    title: 'PTO Request',
                    subtitle: 'Submit paid time off',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PTO request – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.directions_car,
                    title: 'Mileage Tracking',
                    subtitle: 'Log miles for reimbursement',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mileage tracking – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.timer,
                    title: 'Clock In/Out',
                    subtitle: 'Track work hours',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeClockScreen(),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.car_repair,
                    title: 'Daily Cars',
                    subtitle: 'Input make/model for each job',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Daily cars input – coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildTaskCard(
                    context,
                    icon: Icons.edit_calendar,
                    title: 'Edit Time Sheet',
                    subtitle: 'Current pay period (audit trail kept)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Time sheet editing – coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
