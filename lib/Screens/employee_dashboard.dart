import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';
import 'employee_clock_screen.dart';
import 'calendar_view.dart';
import 'admin_hours_pay_screen.dart';
import 'profile_screen.dart';
import 'employee_mileage_screen.dart'; // ← NEW

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

                // Clock In/Out Card
                Card(
                  elevation: 6,
                  color: Colors.blueGrey[800],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const Icon(Icons.access_time_filled,
                        size: 50, color: Colors.cyanAccent),
                    title: const Text('Clock In / Out',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Track your work hours',
                        style: TextStyle(fontSize: 15)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white70),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EmployeeClockScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),

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
                            builder: (_) =>
                                AdminHoursPayScreen(employeeId: currentUserId),
                          ),
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
