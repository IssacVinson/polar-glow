import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';
import 'customer_feedback_screen.dart';
import 'customer_my_bookings_screen.dart';
import 'customer_services_screen.dart';
import 'profile_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().appUser?.displayName;
    final first = (name == null || name.trim().isEmpty)
        ? 'there'
        : name.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.shortName),
        actions: [
          IconButton(
            tooltip: 'Call Polar Glow',
            onPressed: launchAppPhone,
            icon: const Icon(Icons.phone_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 108,
                        height: 108,
                        fit: BoxFit.contain,
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scaleXY(begin: 0.92, end: 1),
                    ),
                    const SizedBox(height: 8),
                    const GlowSectionLabel('Eagle River, Alaska'),
                    const SizedBox(height: 10),
                    Text(
                      'Hi $first — ready for a fresh interior?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mobile detailing in Eagle River, Anchorage, Palmer, Wasilla, and JBER. We come to you. Every interior detail includes shampoo.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlowPrimaryButton(
                      label: 'Book an appointment',
                      icon: Icons.calendar_month_outlined,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerServicesScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    GlowOutlineButton(
                      label: 'Call ${AppConstants.phoneDisplay}',
                      icon: Icons.phone_outlined,
                      onPressed: launchAppPhone,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _InfoChip(
                          icon: Icons.schedule,
                          label: AppConstants.hoursWeekday,
                        ),
                        _InfoChip(
                          icon: Icons.event_busy_outlined,
                          label: AppConstants.hoursSunday,
                        ),
                        _InfoChip(
                          icon: Icons.map_outlined,
                          label: AppConstants.serviceAreaCopy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const GlowSectionLabel('Your account'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.12,
                      children: [
                        DashboardActionTile(
                          icon: Icons.event_note_outlined,
                          title: 'My bookings',
                          subtitle: 'Upcoming and past appointments',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerMyBookingsScreen(),
                              ),
                            );
                          },
                        ),
                        DashboardActionTile(
                          icon: Icons.rate_review_outlined,
                          title: 'Give feedback',
                          subtitle: 'Rate a completed detail',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CustomerFeedbackScreen(),
                              ),
                            );
                          },
                        ),
                        DashboardActionTile(
                          icon: Icons.person_outline,
                          title: 'My profile',
                          subtitle: 'Name, phone, password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                        DashboardActionTile(
                          icon: Icons.star_outline,
                          title: 'Reviews',
                          subtitle: 'See what customers say',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReviewsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const GlowSectionLabel('Why Polar Glow'),
                    const SizedBox(height: 12),
                    const GlowCard(
                      accentBar: true,
                      child: Column(
                        children: [
                          _WhyRow(
                            title: 'Shampoo included',
                            body:
                                'Every interior detail includes shampoo and extraction.',
                          ),
                          SizedBox(height: 14),
                          _WhyRow(
                            title: 'We come to you',
                            body:
                                'Home, office, or base — no drop-off required.',
                          ),
                          SizedBox(height: 14),
                          _WhyRow(
                            title: 'Satisfaction guaranteed',
                            body: 'Not happy? We come back and make it right.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.cyan),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyRow extends StatelessWidget {
  const _WhyRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.cyan, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
