// lib/screens/employee/employee_finances_screen.dart
// FIXED & ALIGNED WITH NEW UNIFIED FINANCE SYSTEM
// - Now uses top-level 'reimbursements' collection
// - Uses FirestoreService + ReimbursementModel
// - Premium Polar Glow dark theme preserved
// - Removed unused 'status' variable (lint warning fixed)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/reimbursement_model.dart';
import '../../core/services/firestore_service.dart';

class EmployeeFinancesScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeFinancesScreen({super.key, required this.employeeId});

  @override
  State<EmployeeFinancesScreen> createState() => _EmployeeFinancesScreenState();
}

class _EmployeeFinancesScreenState extends State<EmployeeFinancesScreen> {
  final FirestoreService _firestore = FirestoreService();

  List<ReimbursementModel> _reimbursements = [];
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
      final reimbList = await _firestore.getEmployeeReimbursements(
        widget.employeeId,
      );

      double approvedTotal = 0.0;
      double pendingTotal = 0.0;

      for (var claim in reimbList) {
        if (claim.isApproved || claim.isPaid) {
          approvedTotal += claim.amount;
        } else if (claim.isPending) {
          pendingTotal += claim.amount;
        }
      }

      if (mounted) {
        setState(() {
          _reimbursements = reimbList;
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
                                    .format(claim.dateSubmitted);

                                Color statusColor = Colors.orange;
                                String statusText = 'Submitted';

                                if (claim.isApproved || claim.isPaid) {
                                  statusColor = Colors.green;
                                  statusText = 'Approved';
                                } else if (claim.isDenied) {
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
                                      claim.title,
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
                                          '\$${claim.amount.toStringAsFixed(2)}',
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
