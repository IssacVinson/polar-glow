import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import 'admin_hours_pay_screen.dart';

class AdminPayrollOverviewScreen extends StatefulWidget {
  const AdminPayrollOverviewScreen({super.key});

  @override
  State<AdminPayrollOverviewScreen> createState() =>
      _AdminPayrollOverviewScreenState();
}

class _AdminPayrollOverviewScreenState
    extends State<AdminPayrollOverviewScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final FirestoreService _firestore = FirestoreService();

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
          () => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Payroll Overview',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Premium glowing search bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shadowColor: _accentColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Colors.grey[850],
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Search by name or email',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: _accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),

          // Employee list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'employee')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No employees found',
                          style: TextStyle(color: Colors.white70)));
                }

                final employees = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ??
                          data['fullName'] ??
                          data['name'] ??
                          data['email'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

                if (employees.isEmpty) {
                  return const Center(
                      child: Text('No matching employees',
                          style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final doc = employees[index];
                    final employeeId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final displayName = data['displayName'] ??
                        data['fullName'] ??
                        data['name'] ??
                        data['email'] ??
                        'Unknown';

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _firestore.calculateEmployeePay(
                        employeeId,
                        DateTime.now(),
                      ),
                      builder: (context, summarySnapshot) {
                        if (summarySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 20),
                            elevation: 12,
                            shadowColor: _accentColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            color: Colors.grey[850],
                            child: const ListTile(
                              contentPadding: EdgeInsets.all(24),
                              title: Text('Loading payroll data...',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          );
                        }

                        final summary = summarySnapshot.data ??
                            {
                              'unpaidHours': 0.0,
                              'projectedPayout': 0.0,
                              'hourlyRate': 0.0,
                            };

                        final unpaidHours = summary['unpaidHours'] as double;
                        final projectedPayout =
                            summary['projectedPayout'] as double;
                        final rate = summary['hourlyRate'] as double;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 20),
                          elevation: 16,
                          shadowColor: _accentColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          color: Colors.grey[850],
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 20 : 24,
                                vertical: isSmallScreen ? 12 : 16),
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundColor: _accentColor.withOpacity(0.2),
                              child: Icon(Icons.person_outline_rounded,
                                  color: _accentColor, size: 32),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            subtitle: Text(
                              'Unpaid Hours: ${unpaidHours.toStringAsFixed(1)} h',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${projectedPayout.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                                Text(
                                  '\$${rate.toStringAsFixed(2)}/hr',
                                  style: const TextStyle(
                                      fontSize: 12.5, color: Colors.white54),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AdminHoursPayScreen(
                                        employeeId: employeeId)),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
