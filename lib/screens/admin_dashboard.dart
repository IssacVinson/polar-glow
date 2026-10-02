import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/widgets/app_widgets.dart';
import 'admin_manage_bookings_screen.dart';
import 'admin_promotion_screen.dart';
import 'admin_schedule_calendar_screen.dart';
import 'admin_services_screen.dart';
import 'admin_payroll_overview_screen.dart';
import 'profile_screen.dart';
import 'admin_view_clients_screen.dart';
import 'admin_finance_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.appUser?.displayName ?? 'Admin';
        final width = MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 720 ? 3 : 2;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin'),
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
                        const GlowSectionLabel('Polar Glow Detailing'),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back, $userName',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          AppConstants.serviceAreaCopy,
                          style: TextStyle(color: Color(0x99FFFFFF)),
                        ),
                        const SizedBox(height: 20),
                        const GlowSectionLabel('Admin controls'),
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
                      childAspectRatio: width < 360 ? 0.92 : 1.05,
                    ),
                    delegate: SliverChildListDelegate([
                      DashboardActionTile(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Promote accounts',
                        subtitle: 'Change roles & permissions',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPromotionScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'Overall schedule',
                        subtitle: 'All bookings at a glance',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminScheduleCalendarScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.list_alt_outlined,
                        title: 'Manage services',
                        subtitle: 'Edit pricing & offerings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminServicesScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.book_online_outlined,
                        title: 'Manage bookings',
                        subtitle: 'Assign, edit, cancel',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminManageBookingsScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.group_outlined,
                        title: 'View clients',
                        subtitle: 'Search name, email, phone',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminViewClientsScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.payments_outlined,
                        title: 'Payroll overview',
                        subtitle: 'Hours, earnings, payouts',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPayrollOverviewScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Finance overview',
                        subtitle: 'All money in & out',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminFinanceScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.rate_review_outlined,
                        title: 'All reviews',
                        subtitle: 'Customer feedback & ratings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReviewsScreen(),
                          ),
                        ),
                      ),
                      DashboardActionTile(
                        icon: Icons.person_outline,
                        title: 'My profile',
                        subtitle: 'Edit name, phone & password',
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
