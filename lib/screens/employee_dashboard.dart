import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/widgets/app_widgets.dart';
import 'employee_clock_screen.dart';
import 'employee_calendar_view.dart';
import 'employee_hours_pay_screen.dart';
import 'profile_screen.dart';
import 'employee_reimbursement_screen.dart';
import 'reviews_screen.dart';
import 'employee_bookings_screen.dart';
import 'employee_availability_screen.dart';
import 'settings_screen.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.appUser?.displayName ?? 'Team Member';
        final currentUserId = auth.user!.uid;
        final width = MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 720 ? 3 : 2;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Team'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign out',
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GlowSectionLabel(AppConstants.appName),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back, $userName',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Clock in, manage jobs, and keep your schedule current.',
                          style: TextStyle(color: Color(0x99FFFFFF)),
                        ),
                        const SizedBox(height: 20),
                        const GlowSectionLabel('Quick actions'),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: width < 360 ? 0.95 : 1.08,
                    ),
                    delegate: SliverChildListDelegate([
                      DashboardActionTile(
                        icon: Icons.access_time_filled,
                        title: 'Clock in / out',
                        subtitle: 'Track your shift',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeClockScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'My schedule',
                        subtitle: 'Calendar of assigned jobs',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeCalendarView(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.event_available_outlined,
                        title: 'Availability',
                        subtitle: 'Bulk hours, regions, overrides',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeAvailabilityScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.directions_car_outlined,
                        title: 'My bookings',
                        subtitle: 'Assigned jobs',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeBookingsScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Reimbursement',
                        subtitle: 'Submit mileage & supplies',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmployeeReimbursementScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.attach_money,
                        title: 'Hours & pay',
                        subtitle: 'Unpaid hours and payouts',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeHoursPayScreen(
                              employeeId: currentUserId,
                            ),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.rate_review_outlined,
                        title: 'My reviews',
                        subtitle: 'Customer ratings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReviewsScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        subtitle: 'Name, phone, password',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
