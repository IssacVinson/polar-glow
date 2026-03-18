import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_hours_pay_screen.dart'; // Hours & Pay tab
import 'admin_schedule_calendar_screen.dart'; // Schedule tab (now real)

class AdminEmployeeDetailsScreen extends StatelessWidget {
  final String employeeId;
  final String email;
  final String role;
  final Timestamp? createdAt;

  const AdminEmployeeDetailsScreen({
    super.key,
    required this.employeeId,
    required this.email,
    required this.role,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final joinDate = createdAt != null
        ? DateFormat('MMM d, yyyy').format(createdAt!.toDate())
        : 'Unknown join date';

    return Scaffold(
      appBar: AppBar(
        title: Text(email.split('@').first), // e.g., "casso" from email
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(24),
              color: colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(email, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Role: $role • Joined: $joinDate',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Hours & Pay'),
                Tab(text: 'Schedule'),
                Tab(text: 'Products'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // Summary tab (placeholder)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard('Total Hours This Month', 'Coming soon'),
                        _buildStatCard('Bookings Completed', 'Coming soon'),
                        _buildStatCard('Average Rating', 'Coming soon'),
                        const SizedBox(height: 24),
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Recent bookings and actions will appear here',
                        ),
                      ],
                    ),
                  ),

                  // Hours & Pay tab – real
                  AdminHoursPayScreen(employeeId: employeeId),

                  // Schedule tab – now real!
                  AdminScheduleCalendarScreen(employeeId: employeeId),

                  // Products tab (placeholder)
                  const Center(
                    child: Text('Product assignment & usage – coming soon'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
