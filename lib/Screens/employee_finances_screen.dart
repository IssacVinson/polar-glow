// lib/screens/employee_finances_screen.dart
// FIXED: Proper class name + distinct "My Finances" screen
// FULL PREMIUM UPGRADE: Polar Glow dark theme + luxurious layout
// - Clean financial overview (separate from Hours & Pay)
// - Total earnings, approved reimbursements, pending items
// - Reimbursement history with better visual breakdown

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeFinancesScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeFinancesScreen({super.key, required this.employeeId});

  @override
  State<EmployeeFinancesScreen> createState() => _EmployeeFinancesScreenState();
}

class _EmployeeFinancesScreenState extends State<EmployeeFinancesScreen> {
  List<Map<String, dynamic>> _reimbursements = [];
  double _totalApprovedReimbursements = 0.0;
  double _totalPendingReimbursements = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _loadFinancesData();
  }

  Future<void> _loadFinancesData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('reimbursements')
          .orderBy('submittedAt', descending: true)
          .get();

      final claims = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date':
              (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'amount': (data['amount'] ?? 0.0).toDouble(),
          'title': data['title'] ?? 'Reimbursement',
          'status': data['status'] ?? 'submitted',
        };
      }).toList();

      double approvedTotal = 0.0;
      double pendingTotal = 0.0;

      for (var claim in claims) {
        final amount = claim['amount'] as double;
        final status = claim['status'] as String;
        if (status == 'approved' || status == 'paid') {
          approvedTotal += amount;
        } else if (status == 'submitted') {
          pendingTotal += amount;
        }
      }

      if (mounted) {
        setState(() {
          _reimbursements = claims;
          _totalApprovedReimbursements = approvedTotal;
          _totalPendingReimbursements = pendingTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load finances: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _totalApprovedReimbursements;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'My Finances',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 17),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildFinanceCard(
                              'Approved',
                              '\$${_totalApprovedReimbursements.toStringAsFixed(2)}',
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFinanceCard(
                              'Pending',
                              '\$${_totalPendingReimbursements.toStringAsFixed(2)}',
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Grand Total
                      Card(
                        elevation: 16,
                        shadowColor: _accentColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        color: Colors.grey[850],
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Reimbursements',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '\$${grandTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Reimbursement History
                      Text(
                        'Reimbursement History',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _reimbursements.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No reimbursements yet',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reimbursements.length,
                              itemBuilder: (context, index) {
                                final claim = _reimbursements[index];
                                final dateStr = DateFormat('MMM d, yyyy')
                                    .format(claim['date']);
                                final status = claim['status'] as String;

                                Color statusColor = Colors.orange;
                                String statusText = 'Submitted';

                                if (status == 'approved' || status == 'paid') {
                                  statusColor = Colors.green;
                                  statusText = 'Approved';
                                } else if (status == 'denied') {
                                  statusColor = Colors.red;
                                  statusText = 'Denied';
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: Colors.grey[850],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Text(
                                      claim['title'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      dateStr,
                                      style: const TextStyle(
                                          color: Colors.white54),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${claim['amount'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFinanceCard(String title, String amount, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
