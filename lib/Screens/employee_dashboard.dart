// lib/screens/employee_dashboard.dart
// FIXED: Updated import and widget reference from old mileage screen → new reimbursement screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';
import 'employee_clock_screen.dart';
import 'employee_calendar_view.dart';
import 'employee_hours_pay_screen.dart';
import 'employee_finances_screen.dart';
import 'profile_screen.dart';
import 'employee_reimbursement_screen.dart'; // ← Reimbursement screen (formerly mileage)
import 'reviews_screen.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.appUser?.displayName ?? 'Team Member';
        final currentUserId = auth.user!.uid;

        return Scaffold(
          backgroundColor: Colors.grey[900],
          appBar: AppBar(
            title: const Text(
              'Employee Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            elevation: 4,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign out',
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.waving_hand_rounded,
                        size: 32, color: _accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          Text(
                            userName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Polar Glow Detailing',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.15,
                    children: [
                      _buildPremiumCard(context, Icons.access_time_filled,
                          'Clock In / Out', _accentColor, () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EmployeeClockScreen()));
                      }),
                      _buildPremiumCard(context, Icons.calendar_today,
                          'My Schedule', const Color(0xFF06B67F), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EmployeeCalendarView()));
                      }),
                      _buildPremiumCard(context, Icons.directions_car,
                          'Reimbursement', const Color(0xFFFFA726), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const EmployeeReimbursementScreen()));
                      }),
                      _buildPremiumCard(context, Icons.attach_money,
                          'Hours & Pay', const Color(0xFF4CAF50), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EmployeeHoursPayScreen(
                                    employeeId: currentUserId)));
                      }),
                      _buildPremiumCard(context, Icons.account_balance_wallet,
                          'My Finances', const Color(0xFF00B0FF), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EmployeeFinancesScreen(
                                    employeeId: currentUserId)));
                      }),
                      _buildPremiumCard(context, Icons.rate_review_rounded,
                          'My Reviews', const Color(0xFFFFD700), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReviewsScreen()));
                      }),
                      _buildPremiumCard(context, Icons.person_outline,
                          'Profile', const Color(0xFF9C27B0), () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()));
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

  Widget _buildPremiumCard(
    BuildContext context,
    IconData icon,
    String title,
    Color accent,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 12,
        shadowColor: accent.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.grey[850],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: accent),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
