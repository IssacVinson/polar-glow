// lib/Screens/admin_dashboard.dart
// FIXED: Text overflow on cards (especially "Promote Accounts" → now wraps cleanly)
// Premium dark theme with glowing cards + fully responsive
// REMOVED: Track Employees button + AdminEmployeeListScreen (redundant — all info now elsewhere)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';

import 'admin_manage_bookings_screen.dart';
import 'admin_promotion_screen.dart';
import 'admin_schedule_calendar_screen.dart';
import 'admin_services_screen.dart';
import 'admin_payroll_overview_screen.dart';
import 'profile_screen.dart';
import 'admin_view_clients_screen.dart';
import 'admin_finance_screen.dart';
import 'reviews_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userName = auth.appUser?.displayName ?? 'Admin';
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenHeight < 700;

        return Scaffold(
          backgroundColor: Colors.grey[900],
          appBar: AppBar(
            title: const Text(
              'Admin Dashboard',
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
                // Welcome header
                Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 32, color: _accentColor),
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
                                ?.copyWith(color: Colors.white70),
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
                  'Admin Controls',
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
                    childAspectRatio: isSmallScreen ? 0.85 : 1.05,
                    children: [
                      _buildGlowCard(
                        context,
                        Icons.person_add_alt_1_rounded,
                        'Promote Accounts',
                        'Change roles & permissions',
                        Colors.teal,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminPromotionScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.calendar_today_rounded,
                        'Overall Schedule',
                        'All bookings at a glance',
                        Colors.deepPurple,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminScheduleCalendarScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.list_alt_rounded,
                        'Manage Services',
                        'Edit pricing & offerings',
                        Colors.purple,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminServicesScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.book_online_rounded,
                        'Manage Bookings',
                        'Assign, edit, cancel',
                        Colors.amber.shade700,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminManageBookingsScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.group_rounded,
                        'View Clients',
                        'Search name, email, phone',
                        Colors.blue,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminViewClientsScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.payments_rounded,
                        'Payroll Overview',
                        'Hours, earnings, payouts',
                        Colors.cyan,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminPayrollOverviewScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.account_balance_wallet_rounded,
                        'Finance Overview',
                        'All money in & out',
                        Colors.green,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminFinanceScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.rate_review_rounded,
                        'All Reviews',
                        'Customer feedback & ratings',
                        Colors.amber,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReviewsScreen())),
                      ),
                      _buildGlowCard(
                        context,
                        Icons.person_outline_rounded,
                        'My Profile',
                        'Edit name, phone & password',
                        Colors.purple,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                      ),
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

  Widget _buildGlowCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color accent,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 16,
        shadowColor: accent.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: accent),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5, // slightly smaller for better fit
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2, // allows wrapping
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
