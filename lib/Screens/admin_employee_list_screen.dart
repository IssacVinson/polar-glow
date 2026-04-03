// lib/Screens/admin_employee_list_screen.dart
// UPGRADED: Premium dark theme with glowing cards + cyan accents
// Fully consistent with EmployeeDashboard, AdminDashboard, and AdminPromotionScreen

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_employee_details_screen.dart';

class AdminEmployeeListScreen extends StatefulWidget {
  const AdminEmployeeListScreen({super.key});

  @override
  State<AdminEmployeeListScreen> createState() =>
      _AdminEmployeeListScreenState();
}

class _AdminEmployeeListScreenState extends State<AdminEmployeeListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.toLowerCase().trim(),
      );
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
          'Track Employees',
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
                  labelText: 'Search by email',
                  labelStyle: TextStyle(color: Colors.white70),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No employees found',
                          style: TextStyle(color: Colors.white70)));
                }

                final employees = snapshot.data!.docs.where((doc) {
                  final email = doc['email']?.toString().toLowerCase() ?? '';
                  return email.contains(_searchQuery);
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
                    final email = doc['email'] ?? 'No email';
                    final role = doc['role'] ?? 'employee';
                    final createdAt = doc['createdAt'] != null
                        ? DateFormat('MMM d, yyyy')
                            .format((doc['createdAt'] as Timestamp).toDate())
                        : 'Unknown join date';

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
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: _accentColor.withOpacity(0.2),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: _accentColor,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Joined: $createdAt',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminEmployeeDetailsScreen(
                                employeeId: doc.id,
                                email: email,
                                role: role,
                                createdAt: doc['createdAt'] as Timestamp?,
                              ),
                            ),
                          );
                        },
                      ),
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
