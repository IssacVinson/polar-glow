// lib/Screens/employee_dashboard.dart
// UPDATED FILE — Replace your entire employee_dashboard.dart with this exact code

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';
import 'employee_clock_screen.dart';
import 'calendar_view.dart';
import 'employee_hours_pay_screen.dart';
import 'employee_finances_screen.dart';
import 'profile_screen.dart';
import 'employee_mileage_screen.dart';
import 'reviews_screen.dart'; // ← NEW: Reviews feature for employees

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.appUser?.displayName ?? 'Team Member';
        final currentUserId = auth.user!.uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Employee Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Polar Glow Detailing',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      // Clock In/Out — now first in top-left, same style as others
                      _buildCard(context, Icons.access_time_filled,
                          'Clock In / Out', Colors.cyanAccent, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EmployeeClockScreen()),
                        );
                      }),

                      _buildCard(context, Icons.calendar_today, 'My Schedule',
                          Colors.teal, () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CalendarView()));
                      }),
                      _buildCard(context, Icons.directions_car,
                          'Mileage Reimbursement', Colors.orange, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EmployeeMileageScreen()),
                        );
                      }),
                      _buildCard(context, Icons.attach_money, 'Hours & Pay',
                          Colors.green, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EmployeeHoursPayScreen(
                                  employeeId: currentUserId)),
                        );
                      }),
                      _buildCard(context, Icons.account_balance_wallet,
                          'My Finances', Colors.cyan, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EmployeeFinancesScreen(
                                  employeeId: currentUserId)),
                        );
                      }),
                      // ── NEW: My Reviews card ──
                      _buildCard(context, Icons.rate_review_rounded,
                          'My Reviews', Colors.amber, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReviewsScreen()),
                        );
                      }),
                      _buildCard(context, Icons.person_outline, 'Profile',
                          Colors.purple, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.blueGrey[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
